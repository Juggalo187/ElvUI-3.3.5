local E, L, V, P, G = unpack(ElvUI)
local UF = E:GetModule("UnitFrames")
local LSM = LibStub("LibSharedMedia-3.0")
local EP = LibStub("LibElvUIPlugin-1.0")
local addonName, ns = ...

local mod = E:NewModule("PartyDamage", "AceEvent-3.0")
local debugMode = false



local defaults = {
    enabled = true,
    font = "Homespun",
    
    damageFontSize = 16,
    damageFontOutline = "OUTLINE",
    damageFontShadow = true,
    damageFadeDuration = 2.0,
    damageXOffset = 0,
    damageYOffset = 0,
    damageShowBackdrop = true,
    damageIconSize = 16,
    damageIconPosition = "LEFT",
    damageIconSpacing = 4,
    damageAreaWidth = 50,
    
    iconsEnabled = true,
    iconSize = 26,
    iconSpacing = 2,
    iconsXOffset = -60,
    iconsYOffset = 0,
    iconsShowBackdrop = true,
    iconColumns = 1,
    maxIcons = 3,
}

local function GetSetting(key)
    if E.db.partyDamage and E.db.partyDamage[key] ~= nil then
        return E.db.partyDamage[key]
    end
    return defaults[key]
end

-- Default profile settings injected into ElvUI
P["partyDamage"] = {}
for k, v in pairs(defaults) do
    P["partyDamage"][k] = v
end

-- Tracking tables
local damageData = {}
local guidToUnit = {}
local unitToFrame = {}
local overlayRegistry = {} -- frame -> true; every frame that ever got an overlay (never wiped)
local dirtyIconUnits = {} -- units whose top-damage icons need a refresh (flushed by the poller)
local trackingActive = false -- combat log processing gate, maintained by the poller

local function FormatDamage(amount)
    if not amount or amount <= 0 then return "" end
    if amount >= 1000000 then
        return format("-%.1fM", amount / 1000000)
    elseif amount >= 1000 then
        return format("-%.1fK", amount / 1000)
    else
        return format("-%d", amount)
    end
end

local function AddTooltipSources(tooltip, sources)
    if not sources or next(sources) == nil then return end
    tooltip:AddLine(" ")
    tooltip:AddLine("Sources:", 1, 0.8, 0)
    local sortedSources = {}
    for name, dmg in pairs(sources) do
        table.insert(sortedSources, {name = name, dmg = dmg})
    end
    table.sort(sortedSources, function(a, b) return a.dmg > b.dmg end)
    for _, src in ipairs(sortedSources) do
        tooltip:AddDoubleLine(src.name, FormatDamage(src.dmg), 0.8, 0.8, 0.8, 1, 1, 1)
    end
end

local function GetFrameForUnit(targetUnit)
    if not targetUnit then return nil end
    local cached = unitToFrame[targetUnit]
    if cached and cached.unit and UnitIsUnit(cached.unit, targetUnit) and cached:IsShown() then
        return cached
    end

    local header = UF["party"]
    if header then
        for i = 1, header:GetNumChildren() do
            local group = select(i, header:GetChildren())
            if group then
                if group.unit and UnitIsUnit(group.unit, targetUnit) then
                    unitToFrame[targetUnit] = group
                    return group
                end
                if group.GetNumChildren then
                    for n = 1, group:GetNumChildren() do
                        local child = select(n, group:GetChildren())
                        if child and child.unit and UnitIsUnit(child.unit, targetUnit) then
                            unitToFrame[targetUnit] = child
                            return child
                        end
                    end
                end
            end
        end
    end
    return nil
end

-- Update icons inside IconsContainer based on sorted damage data
local function UpdateIcons(unit)
    local frame = GetFrameForUnit(unit)
    if not frame or not frame.PDOverlay then return end
    
    local overlay = frame.PDOverlay
    if not GetSetting("iconsEnabled") then
        if overlay.IconsContainer then overlay.IconsContainer:Hide() end
        return
    end
    local data = damageData[unit]
    
    -- Build a list of spells sorted by total damage
    local sortedSpells = {}
    if data then
        for spellId, info in pairs(data) do
            table.insert(sortedSpells, info)
        end
        table.sort(sortedSpells, function(a, b)
            return a.total > b.total
        end)
    end
    
    local maxIcons = math.floor(tonumber(GetSetting("maxIcons")) or 3)
    if maxIcons < 1 then maxIcons = 1 end
    
    local activeCount = 0
    for i = 1, maxIcons do
        local iconFrame = overlay.icons[i]
        if not iconFrame then
            iconFrame = CreateFrame("Button", nil, overlay.IconsContainer)
            iconFrame:SetTemplate("Default")
            
            local tex = iconFrame:CreateTexture(nil, "ARTWORK")
            tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            tex:SetAllPoints()
            iconFrame.texture = tex
            
            iconFrame:SetScript("OnEnter", function(self)
                if self.spellDamage then
                    if self.spellId and self.spellId > 0 then
                        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
                        GameTooltip:SetHyperlink("spell:" .. self.spellId)
                        GameTooltip:AddLine(" ")
                        GameTooltip:AddDoubleLine("Total Damage:", FormatDamage(self.spellDamage), 1, 0.2, 0.2, 1, 1, 1)
                        GameTooltip:AddDoubleLine("Hits:", tostring(self.spellCount), 1, 0.8, 0, 1, 1, 1)
                        AddTooltipSources(GameTooltip, self.spellSources)
                        GameTooltip:Show()
                    else
                        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
                        GameTooltip:ClearLines()
                        GameTooltip:AddLine(self.spellName or "Melee", 1, 1, 1)
                        GameTooltip:AddDoubleLine("Total Damage:", FormatDamage(self.spellDamage), 1, 0.2, 0.2, 1, 1, 1)
                        GameTooltip:AddDoubleLine("Hits:", tostring(self.spellCount), 1, 0.8, 0, 1, 1, 1)
                        AddTooltipSources(GameTooltip, self.spellSources)
                        GameTooltip:Show()
                    end
                end
            end)
            iconFrame:SetScript("OnLeave", function(self)
                GameTooltip:Hide()
            end)
            overlay.icons[i] = iconFrame
        end
        
        -- Force higher frame level to stay above IconsContainer backdrop template
        iconFrame:SetFrameLevel(overlay.IconsContainer:GetFrameLevel() + 2)
        
        local spellInfo = sortedSpells[i]
        if spellInfo and spellInfo.total > 0 then
            iconFrame.texture:SetTexture(spellInfo.icon)
            iconFrame.spellName = spellInfo.name
            iconFrame.spellDamage = spellInfo.total
            iconFrame.spellCount = spellInfo.count
            iconFrame.spellId = spellInfo.id
            iconFrame.spellSources = spellInfo.sources
            
            -- Apply template or remove backdrop based on option
            if GetSetting("iconsShowBackdrop") then
                iconFrame:SetTemplate("Default")
                if iconFrame.backdrop then iconFrame.backdrop:Show() end
            else
                iconFrame:SetBackdrop(nil)
                if iconFrame.backdrop then iconFrame.backdrop:Hide() end
            end
            
            iconFrame:Show()
            activeCount = activeCount + 1
        else
            iconFrame:Hide()
            iconFrame.spellName = nil
            iconFrame.spellDamage = nil
            iconFrame.spellCount = nil
            iconFrame.spellId = nil
            iconFrame.spellSources = nil
        end
    end
    
    -- Hide any extra icons that might have been created previously
    for i = maxIcons + 1, #overlay.icons do
        local iconFrame = overlay.icons[i]
        if iconFrame then
            iconFrame:Hide()
            iconFrame.spellName = nil
            iconFrame.spellDamage = nil
            iconFrame.spellCount = nil
            iconFrame.spellId = nil
            iconFrame.spellSources = nil
        end
    end
    
    if activeCount > 0 then
        overlay.IconsContainer:Show()
        
        local iconSize = math.floor(tonumber(GetSetting("iconSize")) or 26)
        local spacing = math.floor(tonumber(GetSetting("iconSpacing")) or 2)
        local cols = math.floor(tonumber(GetSetting("iconColumns")) or 1)
        if cols < 1 then cols = 1 end
        
        -- Use fixed columns and rows based on maxIcons and cols to keep columns aligned vertically across frames
        local numCols = cols
        local numRows = math.ceil(maxIcons / cols)
        
        local width = numCols * iconSize + (numCols - 1) * spacing
        local height = numRows * iconSize + (numRows - 1) * spacing
        
        overlay.IconsContainer:SetSize(width, height)
        
        -- Position the active icons in a vertical-first grid flowing column-by-column, from left to right
        local activeIndex = 0
        for i = 1, maxIcons do
            local iconFrame = overlay.icons[i]
            if iconFrame and iconFrame:IsShown() then
                activeIndex = activeIndex + 1
                local c = math.ceil(activeIndex / numRows)
                local r = (activeIndex - 1) % numRows + 1
                
                -- Calculate column index relative to right edge (since container anchors to the right)
                local cFromRight = numCols - c + 1
                
                iconFrame:ClearAllPoints()
                iconFrame:SetSize(iconSize, iconSize)
                iconFrame:SetPoint("TOPRIGHT", overlay.IconsContainer, "TOPRIGHT", -((cFromRight - 1) * (iconSize + spacing)), -((r - 1) * (iconSize + spacing)))
            end
        end
    else
        overlay.IconsContainer:Hide()
    end
end

-- Applied at configure time (AttachOverlay), NOT on every damage event
local function ApplyDamageFont(overlay)
    local text = overlay.damageText
    if not text then return end

    local fontPath = LSM:Fetch("font", GetSetting("font") or E.media.normFont)
    local fontSize = tonumber(GetSetting("damageFontSize")) or 16
    local outline = GetSetting("damageFontOutline") or "OUTLINE"
    
    text:SetFont(fontPath or E.media.normFont or "Fonts\\FRIZQT__.TTF", fontSize, outline)
    if GetSetting("damageFontShadow") then
        text:SetShadowColor(0, 0, 0, 1)
        text:SetShadowOffset(1, -1)
    else
        text:SetShadowColor(0, 0, 0, 0)
        text:SetShadowOffset(0, 0)
    end
end

local function LayoutDamageContainer(overlay)
    local text = overlay.damageText
    local iconTex = overlay.damageIcon
    local container = overlay.DamageContainer
    if not text or not iconTex or not container then return end
    
    local fontSize = tonumber(GetSetting("damageFontSize")) or 16
    
    local textVal = text:GetText()
    if not textVal or textVal == "" or container:GetAlpha() == 0 then
        container:SetAlpha(0)
        return
    end
    
    local textWidth = text:GetStringWidth()
    local textHeight = text:GetStringHeight()
    if textHeight <= 0 then textHeight = fontSize end
    
    local iconSize = tonumber(GetSetting("damageIconSize")) or 16
    local spacing = tonumber(GetSetting("damageIconSpacing")) or 4
    local position = GetSetting("damageIconPosition") or "LEFT"
    
    iconTex:SetSize(iconSize, iconSize)
    text:ClearAllPoints()
    iconTex:ClearAllPoints()
    
    if not iconTex:IsShown() then
        container:SetSize(textWidth + 12, textHeight + 12)
        text:SetPoint("CENTER", container, "CENTER", 0, 0)
    else
        if position == "LEFT" then
            local totalW = iconSize + spacing + textWidth
            local totalH = math.max(iconSize, textHeight)
            container:SetSize(totalW + 12, totalH + 12)
            
            iconTex:SetPoint("LEFT", container, "LEFT", 6, 0)
            text:SetPoint("LEFT", iconTex, "RIGHT", spacing, 0)
        elseif position == "RIGHT" then
            local totalW = iconSize + spacing + textWidth
            local totalH = math.max(iconSize, textHeight)
            container:SetSize(totalW + 12, totalH + 12)
            
            text:SetPoint("LEFT", container, "LEFT", 6, 0)
            iconTex:SetPoint("LEFT", text, "RIGHT", spacing, 0)
        elseif position == "TOP" then
            local totalW = math.max(iconSize, textWidth)
            local totalH = iconSize + spacing + textHeight
            container:SetSize(totalW + 12, totalH + 12)
            
            iconTex:SetPoint("TOP", container, "TOP", 0, -6)
            text:SetPoint("TOP", iconTex, "BOTTOM", 0, -spacing)
        elseif position == "BOTTOM" then
            local totalW = math.max(iconSize, textWidth)
            local totalH = iconSize + spacing + textHeight
            container:SetSize(totalW + 12, totalH + 12)
            
            text:SetPoint("TOP", container, "TOP", 0, -6)
            iconTex:SetPoint("TOP", text, "BOTTOM", 0, -spacing)
        end
    end
end

-- Show damage text with OnUpdate fade animation and source icon
local function ShowDamageText(overlay, amount, icon, duration)
    local text = overlay.damageText
    local iconTex = overlay.damageIcon
    local container = overlay.DamageContainer
    if not text or not container then return end
    
    text:SetText(FormatDamage(amount))
    
    if iconTex and icon then
        iconTex:SetTexture(icon)
        iconTex:Show()
    elseif iconTex then
        iconTex:Hide()
    end
    
    container:SetAlpha(1)
    
    LayoutDamageContainer(overlay)
    
    container.fadeStart = GetTime()
    container.fadeDuration = tonumber(duration) or 2.0
    
    container:SetScript("OnUpdate", function(self, elapsed)
        local now = GetTime()
        local age = now - self.fadeStart
        if age >= self.fadeDuration then
            self:SetAlpha(0)
            self:SetScript("OnUpdate", nil)
        end
    end)
end

-- Rebuild GUID mappings for active party/player units
local function UpdateGroupGUIDs()
    table.wipe(guidToUnit)
    
    -- Player
    local playerGUID = UnitGUID("player")
    if playerGUID then
        guidToUnit[playerGUID] = "player"
    end
    
    -- Party members
    local numParty = GetNumPartyMembers()
    for i = 1, numParty do
        local unit = "party" .. i
        local guid = UnitGUID(unit)
        if guid then
            guidToUnit[guid] = unit
        end
    end

    -- Raid members (in case ElvUI party frames use raid unit IDs)
    local numRaid = GetNumRaidMembers()
    for i = 1, numRaid do
        local unit = "raid" .. i
        local guid = UnitGUID(unit)
        if guid then
            guidToUnit[guid] = unit
        end
    end
end

-- Attach or update overlay position and elements for a unit frame
-- Attach or update overlay position and elements for a unit frame
function mod:AttachOverlay(frame)
    local unit = frame.unit
    if not unit then return end
    
    unitToFrame[unit] = frame
    
    if not GetSetting("enabled") then
        if frame.PDOverlay then
            frame.PDOverlay:Hide()
        end
        return
    end
    
    local height = frame:GetHeight()
    if height <= 0 then height = 30 end -- Fallback for uninitialized heights
    
    local iconsXOffset = tonumber(GetSetting("iconsXOffset")) or 0
    local iconsYOffset = tonumber(GetSetting("iconsYOffset")) or 0
    local damageXOffset = tonumber(GetSetting("damageXOffset")) or 0
    local damageYOffset = tonumber(GetSetting("damageYOffset")) or 0
    local spacing = tonumber(GetSetting("iconSpacing")) or 2
    
    if not frame.PDOverlay then
        -- Parented to the unit frame so the overlay inherits Show/Hide/alpha:
        -- when the party frame disappears the icons can no longer linger behind
        local overlay = CreateFrame("Frame", nil, frame)
        overlay:SetFrameStrata("BACKGROUND") -- Render at low strata
        frame.PDOverlay = overlay
        overlayRegistry[frame] = true
        
        -- Icons Container
        local iconsContainer = CreateFrame("Frame", nil, overlay)
        iconsContainer:SetTemplate("Transparent")
        overlay.IconsContainer = iconsContainer
        
        -- Create Icons
        overlay.icons = {}
        
        -- Damage Container
        local damageContainer = CreateFrame("Frame", nil, overlay)
        damageContainer:SetTemplate("Transparent")
        damageContainer:SetAlpha(0) -- Start completely hidden
        overlay.DamageContainer = damageContainer
        
        local damageText = damageContainer:CreateFontString(nil, "OVERLAY")
        damageText:SetFont(E.media.normFont or "Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
        damageText:SetTextColor(1, 0.2, 0.2)
        overlay.damageText = damageText

        local damageIcon = damageContainer:CreateTexture(nil, "ARTWORK")
        damageIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        overlay.damageIcon = damageIcon
        
        -- Initially hide
        overlay:Hide()
    end
    
    local overlay = frame.PDOverlay
    overlay:SetFrameStrata("BACKGROUND")
    
    -- Update backdrop templates based on configuration
    overlay.IconsContainer:SetBackdrop(nil)
    if overlay.IconsContainer.backdrop then overlay.IconsContainer.backdrop:Hide() end
    
    if GetSetting("damageShowBackdrop") then
        overlay.DamageContainer:SetTemplate("Transparent")
        if overlay.DamageContainer.backdrop then overlay.DamageContainer.backdrop:Show() end
    else
        overlay.DamageContainer:SetBackdrop(nil)
        if overlay.DamageContainer.backdrop then overlay.DamageContainer.backdrop:Hide() end
    end
    
    -- Update sizes and anchors
    overlay:SetSize(200, height)
    overlay:ClearAllPoints()
    overlay:SetPoint("TOPRIGHT", frame, "TOPLEFT", -4, 0)
    
    overlay.DamageContainer:ClearAllPoints()
    overlay.DamageContainer:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", damageXOffset, damageYOffset)
    
    overlay.IconsContainer:ClearAllPoints()
    overlay.IconsContainer:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", iconsXOffset, iconsYOffset)
    
    -- Apply strict rendering hierarchies
    local baseLevel = overlay:GetFrameLevel()
    overlay.DamageContainer:SetFrameLevel(baseLevel + 2)
    overlay.IconsContainer:SetFrameLevel(baseLevel + 5)
    
    ApplyDamageFont(overlay)
    LayoutDamageContainer(overlay)
    
    if GetSetting("iconsEnabled") then
        overlay.IconsContainer:Show()
        UpdateIcons(unit)
    else
        overlay.IconsContainer:Hide()
    end
end

-- Iterate active children of the ElvUI party header and configure overlays
-- Iterate active children of the ElvUI party header and configure overlays
local function FindPartyFrames()
    local header = UF["party"]
    if not header then
        if debugMode then print("PartyDamage: UF.party header not found!") end
        return
    end
    
    if debugMode then print("PartyDamage: Scanned party header children:", header:GetNumChildren()) end
    if header.GetNumChildren then
        for i = 1, header:GetNumChildren() do
            local frame = select(i, header:GetChildren())
            if frame and frame.Health and frame.unit then
                if debugMode then print("PartyDamage: Found child party frame:", frame:GetName(), "unit:", frame.unit) end
                if not frame.PDOverlay then
                    mod:AttachOverlay(frame)
                end
            elseif frame and frame.GetNumChildren then
                if debugMode then print("PartyDamage: Found group container:", frame:GetName(), "scanning children...") end
                for n = 1, frame:GetNumChildren() do
                    local child = select(n, frame:GetChildren())
                    if child and child.Health and child.unit then
                        if debugMode then print("PartyDamage: Found nested child party frame:", child:GetName(), "unit:", child.unit) end
                        if not child.PDOverlay then
                            mod:AttachOverlay(child)
                        end
                    end
                end
            end
        end
    end
end

-- Combat log event handler method
function mod:COMBAT_LOG_EVENT_UNFILTERED(event, ...)
    -- Not in a group (or addon disabled): skip all combat log work
    if not trackingActive then return end

    local timestamp, subevent, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags = ...
    
    -- Filter out events that aren't damage related
    if not subevent or not subevent:find("_DAMAGE", 1, true) then return end
    
    local unit = guidToUnit[destGUID]
    if not unit then return end
    
    local spellId, spellName, icon, amount
    
    if subevent == "SWING_DAMAGE" then
        amount = select(9, ...)
        spellId = 0
        spellName = "Melee"
        icon = "Interface\\Icons\\ability_meleedamage"
    elseif subevent == "SPELL_DAMAGE" or subevent == "SPELL_PERIODIC_DAMAGE" or subevent == "RANGE_DAMAGE" then
        spellId, spellName, _, amount = select(9, ...)
        if spellId then
            icon = select(3, GetSpellInfo(spellId))
        end
        icon = icon or "Interface\\Icons\\INV_Misc_QuestionMark"
    elseif subevent == "ENVIRONMENTAL_DAMAGE" then
        local envType
        envType, amount = select(9, ...)
        spellId = -1
        spellName = envType or "Environment"
        if envType == "Falling" then
            icon = "Interface\\Icons\\spell_magic_featherfall"
        elseif envType == "Drowning" then
            icon = "Interface\\Icons\\spell_shadow_demonbreath"
        elseif envType == "Fatigue" then
            icon = "Interface\\Icons\\spell_nature_sleep"
        elseif envType == "Fire" or envType == "Lava" then
            icon = "Interface\\Icons\\spell_fire_claster"
        elseif envType == "Slime" then
            icon = "Interface\\Icons\\spell_nature_corrosivebreath"
        else
            icon = "Interface\\Icons\\spell_shadow_corpsesurge"
        end
    end
    
    if amount and amount > 0 then
        if debugMode then
            print("PartyDamage: " .. tostring(destName) .. " took " .. tostring(amount) .. " from " .. tostring(spellName) .. " (" .. tostring(unit) .. ")")
        end
        self:ProcessDamage(unit, spellId, spellName, icon, amount, sourceName)
    end
end

function mod:ProcessDamage(unit, spellId, spellName, icon, amount, sourceName)
    if not damageData[unit] then
        damageData[unit] = {}
    end
    
    if not damageData[unit][spellId] then
        damageData[unit][spellId] = {
            total = 0,
            count = 0,
            icon = icon,
            name = spellName,
            id = spellId,
            sources = {},
        }
    end
    
    local entry = damageData[unit][spellId]
    entry.total = entry.total + amount
    entry.count = entry.count + 1
    entry.lastHit = GetTime()
    
    if sourceName then
        entry.sources[sourceName] = (entry.sources[sourceName] or 0) + amount
    end
    
    local frame = GetFrameForUnit(unit)
    if frame and frame.PDOverlay then
        ShowDamageText(frame.PDOverlay, amount, icon, GetSetting("damageFadeDuration"))
    end

    -- Icon refresh (sort + grid layout) is coalesced by the poller instead
    -- of running on every single damage event
    dirtyIconUnits[unit] = true
end

function mod:ResetAllData()
    table.wipe(damageData)
    table.wipe(guidToUnit)
    table.wipe(dirtyIconUnits)

    -- Clear every overlay that was ever created (iterated BEFORE any wipe;
    -- the old version wiped unitToFrame first and then iterated the freshly
    -- wiped table, so this cleanup never ran and icons lingered after
    -- leaving the group)
    for frame in pairs(overlayRegistry) do
        local overlay = frame.PDOverlay
        if overlay then
            overlay.damageText:SetText("")
            if overlay.damageIcon then
                overlay.damageIcon:Hide()
            end
            overlay.DamageContainer:SetAlpha(0)
            overlay.DamageContainer:SetScript("OnUpdate", nil)
            if overlay.icons then
                for _, iconFrame in ipairs(overlay.icons) do
                    iconFrame:Hide()
                    iconFrame.spellName = nil
                    iconFrame.spellDamage = nil
                    iconFrame.spellCount = nil
                    iconFrame.spellId = nil
                    iconFrame.spellSources = nil
                end
            end
            overlay.IconsContainer:Hide()
        end
    end

    table.wipe(unitToFrame)
end

local function CheckGroupState()
    local numParty = GetNumPartyMembers()
    local numRaid = GetNumRaidMembers()
    local header = UF["party"]
    local isForceShow = not not (header and header.forceShow)

    if numParty == 0 and numRaid == 0 and not isForceShow then
        mod:ResetAllData()
    end
end

-- Event functions
function mod:PLAYER_REGEN_DISABLED()
    self:ResetAllData()
end

function mod:GROUP_ROSTER_UPDATE()
    UpdateGroupGUIDs()
    FindPartyFrames()
    CheckGroupState()
    E:Delay(0.2, function()
        UpdateGroupGUIDs()
        FindPartyFrames()
        CheckGroupState()
    end)
    E:Delay(1.0, function()
        UpdateGroupGUIDs()
        FindPartyFrames()
        CheckGroupState()
    end)
end

function mod:PLAYER_ENTERING_WORLD()
    UpdateGroupGUIDs()
    FindPartyFrames()
    CheckGroupState()
    E:Delay(0.5, function()
        UpdateGroupGUIDs()
        FindPartyFrames()
        CheckGroupState()
    end)
    E:Delay(2.0, function()
        UpdateGroupGUIDs()
        FindPartyFrames()
        CheckGroupState()
    end)
end



-- Create options menu
function mod:InsertOptions()
    E.Options.args.partyDamage = {
        type = "group",
        name = "Party Damage",
        order = 100,
        args = {
            header = {
                order = 1,
                type = "header",
                name = "ElvUI Party Damage Options",
            },
            enabled = {
                order = 2,
                type = "toggle",
                name = "Enable Addon",
                get = function(info) return GetSetting("enabled") end,
                set = function(info, value) 
                    E.db.partyDamage.enabled = value
                    for frame in pairs(overlayRegistry) do
                        mod:AttachOverlay(frame)
                    end
                end,
            },
            font = {
                order = 3,
                type = "select",
                dialogControl = "LSM30_Font",
                name = "Shared Font",
                values = AceGUIWidgetLSMlists.font,
                get = function(info) return GetSetting("font") end,
                set = function(info, value)
                    E.db.partyDamage.font = value
                    for frame in pairs(overlayRegistry) do
                        mod:AttachOverlay(frame)
                    end
                end,
            },
            liveDamage = {
                order = 10,
                type = "group",
                name = "Live Damage Text",
                guiInline = true,
                args = {
                    showBackdrop = {
                        order = 1,
                        type = "toggle",
                        name = "Show Backdrop",
                        get = function(info) return GetSetting("damageShowBackdrop") end,
                        set = function(info, value)
                            E.db.partyDamage.damageShowBackdrop = value
                            for frame in pairs(overlayRegistry) do
                                mod:AttachOverlay(frame)
                            end
                        end,
                    },
                    fontSize = {
                        order = 2,
                        type = "range",
                        name = "Font Size",
                        min = 8, max = 32, step = 1,
                        get = function(info) return GetSetting("damageFontSize") end,
                        set = function(info, value)
                            E.db.partyDamage.damageFontSize = value
                            for frame in pairs(overlayRegistry) do
                                mod:AttachOverlay(frame)
                            end
                        end,
                    },
                    fontOutline = {
                        order = 3,
                        type = "select",
                        name = "Font Outline",
                        values = {
                            ["NONE"] = "None",
                            ["OUTLINE"] = "Outline",
                            ["THICKOUTLINE"] = "Thick Outline",
                            ["MONOCHROME"] = "Monochrome",
                        },
                        get = function(info) return GetSetting("damageFontOutline") end,
                        set = function(info, value)
                            E.db.partyDamage.damageFontOutline = value
                            for frame in pairs(overlayRegistry) do
                                mod:AttachOverlay(frame)
                            end
                        end,
                    },
                    fontShadow = {
                        order = 4,
                        type = "toggle",
                        name = "Font Shadow",
                        get = function(info) return GetSetting("damageFontShadow") end,
                        set = function(info, value)
                            E.db.partyDamage.damageFontShadow = value
                            for frame in pairs(overlayRegistry) do
                                mod:AttachOverlay(frame)
                            end
                        end,
                    },
                    fadeDuration = {
                        order = 5,
                        type = "range",
                        name = "Display Duration",
                        min = 0.5, max = 5.0, step = 0.1,
                        get = function(info) return GetSetting("damageFadeDuration") end,
                        set = function(info, value)
                            E.db.partyDamage.damageFadeDuration = value
                        end,
                    },
                    xOffset = {
                        order = 6,
                        type = "range",
                        name = "X Offset",
                        min = -200, max = 200, step = 1,
                        get = function(info) return GetSetting("damageXOffset") end,
                        set = function(info, value)
                            E.db.partyDamage.damageXOffset = value
                            for frame in pairs(overlayRegistry) do
                                mod:AttachOverlay(frame)
                            end
                        end,
                    },
                    yOffset = {
                        order = 7,
                        type = "range",
                        name = "Y Offset",
                        min = -200, max = 200, step = 1,
                        get = function(info) return GetSetting("damageYOffset") end,
                        set = function(info, value)
                            E.db.partyDamage.damageYOffset = value
                            for frame in pairs(overlayRegistry) do
                                mod:AttachOverlay(frame)
                            end
                        end,
                    },
                    iconSize = {
                        order = 8,
                        type = "range",
                        name = "Icon Size",
                        min = 8, max = 32, step = 1,
                        get = function(info) return GetSetting("damageIconSize") end,
                        set = function(info, value)
                            E.db.partyDamage.damageIconSize = value
                            for frame in pairs(overlayRegistry) do
                                mod:AttachOverlay(frame)
                            end
                        end,
                    },
                    iconPosition = {
                        order = 9,
                        type = "select",
                        name = "Icon Position",
                        values = {
                            ["LEFT"] = "Left",
                            ["RIGHT"] = "Right",
                            ["TOP"] = "Top",
                            ["BOTTOM"] = "Bottom",
                        },
                        get = function(info) return GetSetting("damageIconPosition") end,
                        set = function(info, value)
                            E.db.partyDamage.damageIconPosition = value
                            for frame in pairs(overlayRegistry) do
                                mod:AttachOverlay(frame)
                            end
                        end,
                    },
                    iconSpacing = {
                        order = 10,
                        type = "range",
                        name = "Icon Spacing",
                        min = 0, max = 20, step = 1,
                        get = function(info) return GetSetting("damageIconSpacing") end,
                        set = function(info, value)
                            E.db.partyDamage.damageIconSpacing = value
                            for frame in pairs(overlayRegistry) do
                                mod:AttachOverlay(frame)
                            end
                        end,
                    },
                },
            },
            topDamage = {
                order = 20,
                type = "group",
                name = "Top Damage Icons",
                guiInline = true,
                args = {
                    enabled = {
                        order = 1,
                        type = "toggle",
                        name = "Enable",
                        get = function(info) return GetSetting("iconsEnabled") end,
                        set = function(info, value)
                            E.db.partyDamage.iconsEnabled = value
                            for frame in pairs(overlayRegistry) do
                                mod:AttachOverlay(frame)
                            end
                        end,
                    },
                    showBackdrop = {
                        order = 2,
                        type = "toggle",
                        name = "Show Backdrop",
                        get = function(info) return GetSetting("iconsShowBackdrop") end,
                        set = function(info, value)
                            E.db.partyDamage.iconsShowBackdrop = value
                            for frame in pairs(overlayRegistry) do
                                mod:AttachOverlay(frame)
                            end
                        end,
                    },
                    iconSize = {
                        order = 3,
                        type = "range",
                        name = "Icon Size",
                        min = 10, max = 48, step = 1,
                        get = function(info) return GetSetting("iconSize") end,
                        set = function(info, value)
                            E.db.partyDamage.iconSize = value
                            for frame in pairs(overlayRegistry) do
                                mod:AttachOverlay(frame)
                            end
                        end,
                    },
                    iconSpacing = {
                        order = 4,
                        type = "range",
                        name = "Icon Spacing",
                        min = 0, max = 20, step = 1,
                        get = function(info) return GetSetting("iconSpacing") end,
                        set = function(info, value)
                            E.db.partyDamage.iconSpacing = value
                            for frame in pairs(overlayRegistry) do
                                mod:AttachOverlay(frame)
                            end
                        end,
                    },
                    iconColumns = {
                        order = 5,
                        type = "range",
                        name = "Icon Columns",
                        min = 1, max = 10, step = 1,
                        get = function(info) return GetSetting("iconColumns") end,
                        set = function(info, value)
                            E.db.partyDamage.iconColumns = value
                            for frame in pairs(overlayRegistry) do
                                mod:AttachOverlay(frame)
                            end
                        end,
                    },
                    maxIcons = {
                        order = 6,
                        type = "range",
                        name = "Max Icons",
                        min = 1, max = 15, step = 1,
                        get = function(info) return GetSetting("maxIcons") end,
                        set = function(info, value)
                            E.db.partyDamage.maxIcons = value
                            for frame in pairs(overlayRegistry) do
                                mod:AttachOverlay(frame)
                            end
                        end,
                    },
                    xOffset = {
                        order = 7,
                        type = "range",
                        name = "X Offset",
                        min = -200, max = 200, step = 1,
                        get = function(info) return GetSetting("iconsXOffset") end,
                        set = function(info, value)
                            E.db.partyDamage.iconsXOffset = value
                            for frame in pairs(overlayRegistry) do
                                mod:AttachOverlay(frame)
                            end
                        end,
                    },
                    yOffset = {
                        order = 8,
                        type = "range",
                        name = "Y Offset",
                        min = -200, max = 200, step = 1,
                        get = function(info) return GetSetting("iconsYOffset") end,
                        set = function(info, value)
                            E.db.partyDamage.iconsYOffset = value
                            for frame in pairs(overlayRegistry) do
                                mod:AttachOverlay(frame)
                            end
                        end,
                    },
                },
            },

        },
    }
end

function mod:Initialize()
    EP:RegisterPlugin(addonName, mod.InsertOptions)
    if debugMode then print("PartyDamage: Initializing module...") end
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("GROUP_ROSTER_UPDATE")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    
    hooksecurefunc(UF, "Configure_HealthBar", function(self, frame)
        if frame and frame.unitframeType == "party" and not frame.isChild then
            if debugMode then print("PartyDamage: Configure_HealthBar hooked for unit frame:", frame:GetName(), "unit:", frame.unit) end
            mod:AttachOverlay(frame)
        end
    end)
    
    UpdateGroupGUIDs()
    
    -- Slight delay to let ElvUI frames load
    E:Delay(0.5, function()
        if debugMode then print("PartyDamage: Finding party frames initially...") end
        FindPartyFrames()
    end)
    
    local function PopulateDummyData(unit)
        if not damageData[unit] then
            damageData[unit] = {}
        end
        local multiplier = 1 + (math.random(-20, 20) / 100)
        damageData[unit][116] = { -- Frostbolt
            total = math.floor(2450 * multiplier),
            count = math.floor(5 * multiplier),
            icon = "Interface\\Icons\\Spell_Frost_FrostBolt02",
            name = "Frostbolt",
            id = 116,
            sources = { ["Scarlet Scryer"] = math.floor(2450 * multiplier) }
        }
        damageData[unit][133] = { -- Fireball
            total = math.floor(4820 * multiplier),
            count = math.floor(4 * multiplier),
            icon = "Interface\\Icons\\Spell_Fire_FlameBolt",
            name = "Fireball",
            id = 133,
            sources = { ["B. Interrogator Vishas"] = math.floor(4820 * multiplier) }
        }
        damageData[unit][0] = { -- Melee
            total = math.floor(1200 * multiplier),
            count = math.floor(12 * multiplier),
            icon = "Interface\\Icons\\ability_meleedamage",
            name = "Melee",
            id = 0,
            sources = { ["Scarlet Torturer"] = math.floor(800 * multiplier), ["Scarlet Warder"] = math.floor(400 * multiplier) }
        }
        damageData[unit][172] = { -- Corruption
            total = math.floor(1800 * multiplier),
            count = math.floor(6 * multiplier),
            icon = "Interface\\Icons\\Spell_Shadow_AbominationExplosion",
            name = "Corruption",
            id = 172,
            sources = { ["Scarlet Torturer"] = math.floor(1800 * multiplier) }
        }
        damageData[unit][139] = { -- Renew
            total = math.floor(950 * multiplier),
            count = math.floor(5 * multiplier),
            icon = "Interface\\Icons\\Spell_Holy_Renew",
            name = "Renew",
            id = 139,
            sources = { ["Scarlet Chaplain"] = math.floor(950 * multiplier) }
        }
        damageData[unit][585] = { -- Smite
            total = math.floor(1500 * multiplier),
            count = math.floor(3 * multiplier),
            icon = "Interface\\Icons\\Spell_Holy_HealingNovelty",
            name = "Smite",
            id = 585,
            sources = { ["Scarlet Chaplain"] = math.floor(1500 * multiplier) }
        }
        damageData[unit][589] = { -- Shadow Word: Pain
            total = math.floor(1100 * multiplier),
            count = math.floor(4 * multiplier),
            icon = "Interface\\Icons\\Spell_Shadow_ShadowWordPain",
            name = "Shadow Word: Pain",
            id = 589,
            sources = { ["Scarlet Acolyte"] = math.floor(1100 * multiplier) }
        }
        damageData[unit][8921] = { -- Moonfire
            total = math.floor(1350 * multiplier),
            count = math.floor(3 * multiplier),
            icon = "Interface\\Icons\\Spell_Nature_StarFall",
            name = "Moonfire",
            id = 8921,
            sources = { ["Scarlet Beastmaster"] = math.floor(1350 * multiplier) }
        }
        damageData[unit][774] = { -- Rejuvenation
            total = math.floor(800 * multiplier),
            count = math.floor(8 * multiplier),
            icon = "Interface\\Icons\\Spell_Nature_Rejuvenation",
            name = "Rejuvenation",
            id = 774,
            sources = { ["Scarlet Druid"] = math.floor(800 * multiplier) }
        }
    end

    -- Taint-safe visibility/refresh poller (0.15s tick).
    -- Also flushes coalesced icon refreshes and gates combat log processing.
    local poller = CreateFrame("Frame")
    poller.elapsed = 0
    poller.syncElapsed = 0
    poller.wasForceShow = false
    poller.hadGroup = false
    poller:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        self.syncElapsed = self.syncElapsed + elapsed
        if self.elapsed < 0.15 then return end
        self.elapsed = 0

        -- Full quiescence when the addon is disabled: no roster scans, no
        -- icon flushes, no preview work (the CLEU handler is already gated)
        if not GetSetting("enabled") then
            trackingActive = false
            return
        end

        local numParty = GetNumPartyMembers()
        local numRaid = GetNumRaidMembers()
        local partyHeader = UF["party"]
        local isForceShow = not not (partyHeader and partyHeader.forceShow)
        local hasGroup = (numParty > 0 or numRaid > 0)

        -- Gate for the combat log handler: no group and no preview = no work
        trackingActive = (GetSetting("enabled") and (hasGroup or isForceShow)) and true or false

        if not hasGroup and not isForceShow then
            if self.hadGroup then
                mod:ResetAllData()
                self.hadGroup = false
            end
        else
            self.hadGroup = true
        end

        if isForceShow then
            FindPartyFrames()
        elseif self.wasForceShow then
            mod:ResetAllData()
        end
        self.wasForceShow = isForceShow

        if self.syncElapsed >= 1.0 then
            self.syncElapsed = 0
            if hasGroup then
                UpdateGroupGUIDs()
                FindPartyFrames()
            end
        end

        -- Flush coalesced icon refreshes (at most one sort/layout per unit per tick)
        if next(dirtyIconUnits) then
            for unit in pairs(dirtyIconUnits) do
                dirtyIconUnits[unit] = nil
                UpdateIcons(unit)
            end
        end

        local now = GetTime()

        -- Preview mode: sort active frames and designate a single flashing frame
        local activeFrames, flashingFrame
        if isForceShow then
            activeFrames = {}
            for unit, frame in pairs(unitToFrame) do
                if frame and frame.PDOverlay and frame:IsShown() then
                    table.insert(activeFrames, frame)
                end
            end
            table.sort(activeFrames, function(a, b)
                return a:GetName() < b:GetName()
            end)
            flashingFrame = activeFrames[1]
        end

        for unit, frame in pairs(unitToFrame) do
            local overlay = frame and frame.PDOverlay
            if overlay then
                local shouldShow = frame:IsShown() and (UnitExists(unit) or isForceShow)
                if shouldShow then
                    if not overlay:IsShown() then
                        overlay:Show()
                    end

                    if isForceShow then
                        if not damageData[unit] or next(damageData[unit]) == nil then
                            PopulateDummyData(unit)
                            UpdateIcons(unit)
                        end

                        -- Find frame index for this frame to pick a different spell for static text
                        local frameIdx = 1
                        for idx, f in ipairs(activeFrames) do
                            if f == frame then
                                frameIdx = idx
                                break
                            end
                        end

                        if frame == flashingFrame then
                            -- Staggered dummy hits per active frame (only for the flashing one)
                            frame.lastDummyHit = frame.lastDummyHit or 0
                            if now - frame.lastDummyHit >= 2.0 and math.random() < 0.02 then
                                frame.lastDummyHit = now
                                local amount = math.random(500, 1500)
                                local spellName, icon
                                if math.random() > 0.5 then
                                    spellName, icon = "Fireball", "Interface\\Icons\\Spell_Fire_FlameBolt"
                                else
                                    spellName, icon = "Frostbolt", "Interface\\Icons\\Spell_Frost_FrostBolt02"
                                end
                                ShowDamageText(frame.PDOverlay, amount, icon, GetSetting("damageFadeDuration"))
                            end
                        else
                            -- For non-flashing frames, display a static, stable damage number that doesn't fade
                            local textVal = frame.PDOverlay.damageText:GetText()
                            if not textVal or textVal == "" or frame.PDOverlay.DamageContainer:GetAlpha() == 0 then
                                local amount = 1000 + frameIdx * 100
                                local icon
                                if frameIdx % 3 == 1 then
                                    icon = "Interface\\Icons\\Spell_Fire_FlameBolt"
                                elseif frameIdx % 3 == 2 then
                                    icon = "Interface\\Icons\\Spell_Frost_FrostBolt02"
                                else
                                    icon = "Interface\\Icons\\ability_meleedamage"
                                end
                                ShowDamageText(frame.PDOverlay, amount, icon, 999999)
                            end
                        end
                    end
                elseif overlay:IsShown() then
                    -- Previously there was no else-branch here, so overlays that
                    -- lost their unit were never hidden
                    overlay:Hide()
                end
            end
        end
    end)
end

local function InitializeCallback()
    mod:Initialize()
end

E:RegisterModule(mod:GetName(), InitializeCallback)
