local E, L, V, P, G = unpack(select(2, ...));
local NP = E:GetModule("NamePlates")

local _G = _G
local pairs, ipairs, ceil, floor, tonumber = pairs, ipairs, ceil, floor, tonumber
local wipe, strmatch, strlower, strfind, gsub = wipe, strmatch, strlower, strfind, string.gsub
local tinsert = tinsert

local IsInInstance = IsInInstance
local UnitIsPlayer = UnitIsPlayer
local GetQuestLogTitle = GetQuestLogTitle
local GetNumQuestLogEntries = GetNumQuestLogEntries
local UnitName = UnitName
local UnitExists = UnitExists
local UnitGUID = UnitGUID

local ThreatTooltip = THREAT_TOOLTIP:gsub('%%d', '%%d-')

hasNamePlateAPI = C_NamePlate and C_NamePlate.GetNamePlateForUnit and true or false
NP.HasQuestIconAPI = hasNamePlateAPI
E.hasNamePlateAPI = hasNamePlateAPI

local function IsAPIAvailable()
    return hasNamePlateAPI
end

local questIcons = {
    activeQuests = {},
    indexByID = {}
}
NP.QuestIcons = questIcons

NP.QuestCache = {}
NP.QuestCacheTTL = 5

local typesLocalized = {
    enUS = {
        KILL = {'slain', 'destroy', 'eliminate', 'repel', 'kill', 'defeat'},
        CHAT = {'speak', 'talk'},
        COLLECT = {'collect', 'gather', 'obtain', 'retrieve', 'recover', 'acquire', 'reclaim', 'return'}
    },
}

local questTypes = typesLocalized[E.locale] or typesLocalized.enUS

local DEFAULT_FONT = "FONTS\\FRIZQT__.TTF"

local function IsQuestIconsEnabled()
    if not hasNamePlateAPI then
        return false
    end
    return E.db.nameplates.questIcons and E.db.nameplates.questIcons.enable
end

-- Parse an objective line into a remaining count. Returns count, isPercent.
-- Mirrors the newer version's CheckTextForQuest.
local function CheckTextForQuest(text)
    local x, y = strmatch(text, "(%d+)/(%d+)")
    if x and y then
        local diff = floor(tonumber(y) - tonumber(x))
        if diff > 0 then
            return diff, false
        end
        return nil, false   -- completed x/y objective
    end

    if strmatch(text, ThreatTooltip) then
        return nil, false
    end

    local progress = tonumber(strmatch(text, "([%d%.]+)%%"))
    if progress then
        if progress < 100 then
            return ceil(100 - progress), true
        end
        return nil, false   -- completed percent objective
    end

    return nil, false
end

local function GetQuests(unitID)
    if not unitID then return nil end
    if strfind(unitID, "pet") or UnitIsUnit(unitID, "pet") then return nil end
    if IsInInstance() then return nil end

    local unitName = UnitName(unitID)
    if not unitName then return nil end

    E.ScanTooltip:SetOwner(_G.UIParent, 'ANCHOR_NONE')
    E.ScanTooltip:SetUnit(unitID)
    E.ScanTooltip:Show()

    local QuestList
    local activeID
    local notMyQuest = false

    -- Skip line 1 (name) and 2 (level/type). From line 3 on we may see the
    -- quest title followed by dashed objective lines.
    for i = 3, E.ScanTooltip:NumLines() do
        local str = _G['ElvUI_ScanTooltipTextLeft' .. i]
        local text = str and str:GetText()
        if not text or text == '' then break end

        if UnitIsPlayer(text) then
            -- If we hit someone else's name, stop trusting the rest of the tooltip.
            notMyQuest = text ~= E.myname
        elseif not notMyQuest then
            -- Quest title line -> remember which quest we're looking at.
            local activeQuest = questIcons.activeQuests[text]
            if activeQuest then
                activeID = activeQuest
            end

            -- Objective line: dashed prefix and/or progress count.
            local isTextObjective = strmatch(text, "^%s*%-%s*") ~= nil
            local count, isPercent = CheckTextForQuest(text)

			-- A dashed line with no count is a text objective (e.g. " - Speak to X").
			-- But if it has a count pattern and CheckTextForQuest rejected it, it's completed.
			local hasCountPattern = strmatch(text, "%d+%s*/%s*%d+") or strmatch(text, "[%d%.]+%%")
			if hasCountPattern then
				isTextObjective = false
			end

            if count or isTextObjective then
                local questType
                -- Try to classify by keyword if we have any text to work with.
                local lowerText = strlower(text)
                for _, word in ipairs(questTypes.KILL) do
                    if strfind(lowerText, word, nil, true) then
                        questType = "KILL"
                        break
                    end
                end
                if not questType then
                    for _, word in ipairs(questTypes.CHAT) do
                        if strfind(lowerText, word, nil, true) then
                            questType = "CHAT"
                            break
                        end
                    end
                end
                -- Fallback: if it has a x/y counter it's almost certainly a collect.
                if not questType and count then
                    questType = "COLLECT"
                end

                QuestList = QuestList or {}
                tinsert(QuestList, {
                    isPercent = isPercent,
                    itemTexture = nil,
                    objectiveCount = count or 0,
                    questType = questType or "DEFAULT",
                    objectiveText = text,
                    questID = activeID,
                })
            end
        end
    end

    E.ScanTooltip:Hide()

    return QuestList
end

local function GetCachedQuests(guid, unit)
    if not guid then guid = "no_guid" end

    local cached = NP.QuestCache[guid]
    local currentTime = GetTime()

    if cached and cached.timestamp and (currentTime - cached.timestamp) < NP.QuestCacheTTL then
        return cached.data, true
    end

    local data = GetQuests(unit)

    NP.QuestCache[guid] = {
        data = data,
        timestamp = currentTime
    }

    return data, false
end

local questIconOverlay = {}
local frameQuestData = {}

local activeTokens = {}

if hasNamePlateAPI then
    local npTracker = CreateFrame("Frame")
    npTracker:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    npTracker:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    npTracker:SetScript("OnEvent", function(_, event, unitToken)
        if event == "NAME_PLATE_UNIT_ADDED" then
            activeTokens[unitToken] = true
        else
            activeTokens[unitToken] = nil
        end
        NP:RefreshAllQuestIcons()
    end)
else
    print("|cFFFF0000QuestIcons:|r C_NamePlate API not detected -- falling back to target/mouseover-only quest icons.")
end

local function FindPlateToken(frame)
    if not hasNamePlateAPI then return nil end

    local plate = frame:GetParent()
    if not plate then return nil end

    for token in pairs(activeTokens) do
        if C_NamePlate.GetNamePlateForUnit(token) == plate then
            return token
        end
    end
end

function NP:GetQuestIconContainer(frame)
    if frame.QuestIconContainer then
        return frame.QuestIconContainer
    end

    local container = CreateFrame("Frame", nil, frame:GetParent())
    container:SetFrameStrata("BACKGROUND")
    container:SetFrameLevel(1)
    container:SetSize(1, 1)
    container:Show()

    frame.QuestIconContainer = container
    return container
end

function NP:Update_QuestIcons(frame)
    if not frame or not frame.UnitType then return end

    if not IsQuestIconsEnabled() then
        if questIconOverlay[frame] then
            for _, data in ipairs(questIconOverlay[frame]) do
                data.icon:Hide()
                data.text:Hide()
            end
        end
        frameQuestData[frame] = nil
        return
    end

    local plate = frame:GetParent()
    if not plate then
        if questIconOverlay[frame] then
            for _, data in ipairs(questIconOverlay[frame]) do
                data.icon:Hide()
                data.text:Hide()
            end
        end
        frameQuestData[frame] = nil
        return
    end

    local unit = frame.unit or FindPlateToken(frame)

    if not unit or not UnitExists(unit) then
        if questIconOverlay[frame] then
            for _, data in ipairs(questIconOverlay[frame]) do
                data.icon:Hide()
                data.text:Hide()
            end
        end
        frameQuestData[frame] = nil
        return
    end

    local guid = frame.guid or UnitGUID(unit) or "no_guid"
    local QuestList, wasCached = GetCachedQuests(guid, unit)

    if not QuestList or #QuestList == 0 then
        if questIconOverlay[frame] then
            for _, data in ipairs(questIconOverlay[frame]) do
                data.icon:Hide()
                data.text:Hide()
            end
        end
        frameQuestData[frame] = nil
        return
    end

    frameQuestData[frame] = QuestList

    local container = NP:GetQuestIconContainer(frame)

    if not questIconOverlay[frame] then
        questIconOverlay[frame] = {}
    end

    local dataList = questIconOverlay[frame]
    local db = E.db.nameplates.questIcons
    local iconSize = db.size or 20
    local spacing = db.spacing or 2

    while #dataList < #QuestList do
        local icon = container:CreateTexture(nil, "OVERLAY")
        icon:SetDrawLayer("OVERLAY", -1)
        icon:SetSize(iconSize, iconSize)
        icon:SetTexCoord(0, 1, 0, 1)
        icon:Hide()

        local text = container:CreateFontString(nil, "OVERLAY")
        text:SetFont(DEFAULT_FONT, 11, "OUTLINE")
        text:SetTextColor(1, 1, 1)
        text:SetDrawLayer("OVERLAY", -1)
        text:Hide()

        tinsert(dataList, {icon = icon, text = text})
    end

    for i = 1, #dataList do
        dataList[i].icon:SetSize(iconSize, iconSize)
    end

    self:PositionQuestIcons(frame)
end

function NP:PositionQuestIcons(frame)
    if not frame then return end

    local dataList = questIconOverlay[frame]
    if not dataList then return end

    local QuestList = frameQuestData[frame]
    local db = E.db.nameplates.questIcons

    if not QuestList or #QuestList == 0 or not db or not db.enable then
        for _, data in ipairs(dataList) do
            data.icon:Hide()
            data.text:Hide()
        end
        return
    end

    local iconSize = db.size or 20
    local spacing = db.spacing or 2
    local xOffset = db.xOffset or 0
    local yOffset = db.yOffset or 0
    local position = db.position or "CENTER"

    local killIconChoice = db.killIcon or "SKULL"
    local collectIconChoice = db.collectIcon or "BAG"

    local iconTextures = {
        KILL = {
            ["SKULL"] = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8",
            ["SWORD"] = "Interface\\Icons\\INV_Sword_04",
            ["CROSS"] = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_7",
            ["DIAMOND"] = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_3",
            ["STAR"] = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1"
        },
        COLLECT = {
            ["BAG"] = "Interface\\Icons\\INV_Misc_Bag_11",
            ["GEM"] = "Interface\\Icons\\INV_Misc_Gem_01",
            ["COIN"] = "Interface\\Icons\\INV_Misc_Coin_01",
            ["FLOWER"] = "Interface\\Icons\\INV_Misc_Flower_01",
            ["CHEST"] = "Interface\\Icons\\INV_Chest_Leather_08"
        }
    }

    local killTexture = iconTextures.KILL[killIconChoice] or iconTextures.KILL["SKULL"]
    local collectTexture = iconTextures.COLLECT[collectIconChoice] or iconTextures.COLLECT["BAG"]

    local shownCount = #QuestList
    if shownCount == 0 then
        for _, data in ipairs(dataList) do
            data.icon:Hide()
            data.text:Hide()
        end
        return
    end

    local container = NP:GetQuestIconContainer(frame)
    local totalWidth = (shownCount * iconSize) + ((shownCount - 1) * spacing)

    container:ClearAllPoints()

    local isNameOnly = frame.NameOnlyChanged == true
    local isIconOnly = frame.IconOnlyChanged == true

    local anchorElement
    local anchorPoint
    local offsetX = xOffset
    local offsetY = yOffset

    if isNameOnly or isIconOnly then
        anchorElement = frame
        anchorPoint = "CENTER"
        offsetX = -10
        offsetY = 25 + yOffset
    else
        if position == "LEFT" then
            anchorElement = frame.Health
            anchorPoint = "LEFT"
            offsetX = -5 + xOffset
            offsetY = yOffset
        elseif position == "RIGHT" then
            anchorElement = frame.Health
            anchorPoint = "RIGHT"
            offsetX = 5 + xOffset
            offsetY = yOffset
        else
            anchorElement = frame.Name
            anchorPoint = "TOP"
            offsetX = xOffset
            offsetY = 5 + yOffset
        end
    end

    if position == "LEFT" then
        container:SetPoint("RIGHT", anchorElement, anchorPoint, -5 + offsetX, offsetY)
    elseif position == "RIGHT" then
        container:SetPoint("LEFT", anchorElement, anchorPoint, 5 + offsetX, offsetY)
    else
        container:SetPoint("BOTTOM", anchorElement, anchorPoint, offsetX, offsetY)
    end

    container:SetSize(totalWidth, iconSize)
    container:Show()
    container:SetAlpha(1)

    local iconIndex = 0
    for i = 1, #QuestList do
        local quest = QuestList[i]
        local data = dataList[i]
        if not data then break end

        local iconType = quest.questType or "KILL"
        if iconType == "KILL" then
            data.icon:SetTexture(killTexture)
        elseif iconType == "COLLECT" then
            data.icon:SetTexture(collectTexture)
        elseif iconType == "CHAT" then
            data.icon:SetTexture("Interface\\WorldMap\\ChatBubble_64.PNG")
        elseif iconType == "QUEST_ITEM" and quest.itemTexture then
            data.icon:SetTexture(quest.itemTexture)
        else
            data.icon:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
        end

        data.icon:SetVertexColor(1, 1, 1)
        data.icon:ClearAllPoints()
        data.icon:SetPoint("LEFT", container, "LEFT", iconIndex * (iconSize + spacing), 0)
        data.icon:SetSize(iconSize, iconSize)
        data.icon:Show()
        data.icon:SetAlpha(1)

        data.text:ClearAllPoints()
        data.text:SetPoint("BOTTOM", data.icon, "TOP", 0, 2)
        data.text:SetFont(DEFAULT_FONT, iconSize * 0.5, "OUTLINE")
        data.text:SetTextColor(1, 1, 1)
        data.text:SetAlpha(1)

        if quest.isPercent then
            data.text:SetText(quest.objectiveCount..'%')
            data.text:Show()
        elseif quest.objectiveCount and quest.objectiveCount > 0 then
            data.text:SetText(quest.objectiveCount)
            data.text:Show()
        else
            data.text:Hide()
        end

        iconIndex = iconIndex + 1
    end

    for i = #QuestList + 1, #dataList do
        if dataList[i] then
            dataList[i].icon:Hide()
            dataList[i].text:Hide()
        end
    end

    container:Show()
    container:SetAlpha(1)
end

-- Quest log tracking: we only need title -> index for "is this quest mine".
local tracker = CreateFrame("Frame")
tracker:RegisterEvent("QUEST_ACCEPTED")
tracker:RegisterEvent("QUEST_REMOVED")
tracker:RegisterEvent("PLAYER_ENTERING_WORLD")

local function UpdateQuestCache()
    wipe(questIcons.activeQuests)
    questIcons.indexByID = {}

    for i = 1, GetNumQuestLogEntries() do
        local title = GetQuestLogTitle(i)
        if title then
            questIcons.activeQuests[title] = i
            questIcons.indexByID[i] = i
        end
    end
    wipe(NP.QuestCache)
end

tracker:SetScript("OnEvent", function(self, event)
    UpdateQuestCache()

    if event == "PLAYER_ENTERING_WORLD" then
        NP:ScheduleTimer("RefreshAllQuestIcons", 0.5)
        NP:ScheduleTimer("RefreshAllQuestIcons", 1.5)
    else
        NP:RefreshAllQuestIcons()
    end
end)

function NP:QUEST_LOG_UPDATE()
    UpdateQuestCache()
    for frame in pairs(self.VisiblePlates) do
        if frame.UnitType and frame.UnitName then
            self:Update_QuestIcons(frame)
        end
    end
end

UpdateQuestCache()

local targetTracker = CreateFrame("Frame")
targetTracker:RegisterEvent("PLAYER_TARGET_CHANGED")
targetTracker:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
targetTracker:SetScript("OnEvent", function()
    NP:RefreshAllQuestIcons()
end)

function NP:RefreshAllQuestIcons()
    for frame in pairs(self.VisiblePlates) do
        if frame.UnitType and frame.UnitName then
            self:Update_QuestIcons(frame)
        end
    end
end

NP:ScheduleTimer("RefreshAllQuestIcons", 1.1)
NP:ScheduleRepeatingTimer("RefreshAllQuestIcons", 2)