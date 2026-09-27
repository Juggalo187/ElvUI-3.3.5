local E, L, V, P, G = unpack(select(2, ...))
local DT = E:GetModule("DataTexts")

local format, join = string.format, string.join
local PAPERDOLLFRAME_TOOLTIP_FORMAT = PAPERDOLLFRAME_TOOLTIP_FORMAT

local defenseRating = 0
local defenseTooltipText, defenseTooltipText2
local displayString = ""
local lastPanel

local function FindDefenseStatFrame()
    local statsPane = _G["CharacterStatsPane"]
    if not statsPane or not statsPane.Categories then return nil end

    for i = 1, #statsPane.Categories do
        local category = statsPane.Categories[i]
        if category and category.Category == "DEFENSES" then
            return category.Stats and category.Stats[2]
        end
    end
    return nil
end

local function GetDefenseValue()
    local statFrame = FindDefenseStatFrame()
    if not statFrame then return nil end

    local ok = pcall(PaperDollFrame_SetDefense, statFrame, "player")
    if not ok then return nil end

    local text = statFrame.Value and statFrame.Value:GetText()
    if text then
        text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        local value = tonumber(text)
        if value and value > 0 then
            -- Capture Blizzard's tooltip lines while we're here
            defenseTooltipText  = statFrame.tooltip
            defenseTooltipText2 = statFrame.tooltip2
            return value
        end
    end
    return nil
end

local function OnEvent(self)
    lastPanel = self

    local value = GetDefenseValue()
    if value then
        defenseRating = value
    end

    self.text:SetFormattedText(displayString, defenseRating)
end

local function OnEnter(self)
    DT:SetupTooltip(self)

    -- Header line: use the standard highlighted tooltip color
    DT.tooltip:AddLine(format("%s %d", format(PAPERDOLLFRAME_TOOLTIP_FORMAT, "Defense"), defenseRating), 1, 1, 1)

    -- Detail line(s): preserve any embedded color codes from Blizzard
    if defenseTooltipText2 then
        for line in defenseTooltipText2:gmatch("[^\n]+") do
            -- If the line already has a color code, don't override it
            if line:find("|c%x%x%x%x%x%x%x%x") then
                DT.tooltip:AddLine(line, nil, nil, nil, 1)
            else
                -- No color code: use a soft gray so it reads as secondary info
                DT.tooltip:AddLine(line, 0.8, 0.8, 0.8, 1)
            end
        end
    end

    if defenseRating == 0 then
        DT.tooltip:AddLine("Open your character sheet once to populate this value.", 1, 0.8, 0, 1)
    end

    DT.tooltip:Show()
end

local function ValueColorUpdate(hex)
    displayString = join("", "Defense", ": ", hex, "%d|r")
    if lastPanel ~= nil then OnEvent(lastPanel) end
end
E.valueColorUpdateFuncs[ValueColorUpdate] = true

DT:RegisterDatatext("Defense", {"PLAYER_ENTERING_WORLD", "COMBAT_RATING_UPDATE", "UNIT_DEFENSE", "PLAYER_EQUIPMENT_CHANGED"}, OnEvent, nil, nil, OnEnter, nil, "Defense")