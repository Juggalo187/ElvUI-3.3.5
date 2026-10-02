local E, L, V, P, G = unpack(select(2, ...))
local NP = E:GetModule("NamePlates")

-- Default Profile Settings
P["nameplates"] = P["nameplates"] or {}
P["nameplates"]["questGiverIcon"] = {
    enable = true,
    size = 22,
    xOffset = 0,
    yOffset = 12,
}

-- Completed Quest Texture (?)
local QUEST_COMPLETE_ICON = [[Interface\GossipFrame\ActiveQuestIcon]]

-- Hidden tooltip for scanning unit quest status
local scanTooltip = CreateFrame("GameTooltip", "ElvUI_QuestIconScanTooltip", nil, "GameTooltipTemplate")
scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

-- Helper: Strip WoW color formatting (|cff... and |r) and whitespace
local function CleanString(str)
    if not str then return "" end
    local clean = str:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    clean = clean:match("^%s*(.-)%s*$") or ""
    return string.lower(clean)
end

-- Helper: Checks if the target NPC is a completed quest turn-in
local function IsNPCQuestTurnIn(frame, unit, rawNPCName)
    local cleanNPC = CleanString(rawNPCName)
    if cleanNPC == "" then return false end

    -- 1. Tooltip Scan (Most accurate when unit, target, or mouseover exists)
    local validUnit = nil
    if unit and UnitExists(unit) then
        validUnit = unit
    elseif UnitExists("target") and CleanString(UnitName("target")) == cleanNPC then
        validUnit = "target"
    elseif UnitExists("mouseover") and CleanString(UnitName("mouseover")) == cleanNPC then
        validUnit = "mouseover"
    end

    if validUnit then
        scanTooltip:ClearLines()
        scanTooltip:SetUnit(validUnit)
        for i = 1, scanTooltip:NumLines() do
            local line = _G["ElvUI_QuestIconScanTooltipTextLeft" .. i]
            if line then
                local text = line:GetText()
                if text then
                    -- Ensure tooltip explicitly states the quest or objective is complete
                    if string.find(text, "%(Completed%)") or string.find(text, "%(Complete%)") then
                        return true
                    end
                end
            end
        end
    end

    -- 2. Quest Log Fallback (STRICT: Only check if quest is marked complete in quest log)
    local numEntries = GetNumQuestLogEntries()
    if numEntries and numEntries > 0 then
        local savedSelection = GetQuestLogSelection()

        for i = 1, numEntries do
            local questTitle, _, _, _, isHeader, _, isComplete = GetQuestLogTitle(i)

            -- ONLY process if the quest is actually completed (isComplete == 1 or true)
            if not isHeader and (isComplete == 1 or isComplete == true) then
                -- Match Quest Title
                if questTitle and string.find(string.lower(questTitle), cleanNPC, 1, true) then
                    SelectQuestLogEntry(savedSelection)
                    return true
                end

                -- Match Quest Objectives Text (For talk-to / delivery quests)
                SelectQuestLogEntry(i)
                local _, questObjectives = GetQuestLogQuestText()
                if questObjectives and string.find(string.lower(questObjectives), cleanNPC, 1, true) then
                    SelectQuestLogEntry(savedSelection)
                    return true
                end

                -- Match Leaderboard Objective text
                local numObjectives = GetNumQuestLeaderBoards(i) or 0
                for j = 1, numObjectives do
                    local objText = GetQuestLogLeaderBoard(j, i)
                    if objText and string.find(string.lower(objText), cleanNPC, 1, true) then
                        SelectQuestLogEntry(savedSelection)
                        return true
                    end
                end
            end
        end

        SelectQuestLogEntry(savedSelection)
    end

    return false
end

-- 1. Construct Element Frame
function NP:Construct_QuestIcon(frame)
    if not frame then return end
    if frame.QuestIcon then return frame.QuestIcon end

    local questIcon = CreateFrame("Frame", nil, frame)
    questIcon:SetSize(22, 22)

    local texture = questIcon:CreateTexture(nil, "OVERLAY")
    texture:SetAllPoints()
    questIcon.Texture = texture

    questIcon:Hide()
    frame.QuestIcon = questIcon
    return questIcon
end

-- 2. Configure Placement & Size
function NP:Configure_QuestIcon(frame)
    if not frame then return end
    local questIcon = frame.QuestIcon
    if not questIcon then return end

    local db = (E.db and E.db.nameplates and E.db.nameplates.questGiverIcon) or P.nameplates.questGiverIcon
    if not db or not db.enable then
        questIcon:Hide()
        return
    end

    questIcon:ClearAllPoints()
    if frame.Health and frame.Health:IsShown() then
        questIcon:SetPoint("BOTTOM", frame.Health, "TOP", db.xOffset or 0, db.yOffset or 12)
    elseif frame.HealthBar and frame.HealthBar:IsShown() then
        questIcon:SetPoint("BOTTOM", frame.HealthBar, "TOP", db.xOffset or 0, db.yOffset or 12)
    elseif frame.Name and frame.Name:IsShown() then
        questIcon:SetPoint("BOTTOM", frame.Name, "TOP", db.xOffset or 0, db.yOffset or 12)
    else
        questIcon:SetPoint("BOTTOM", frame, "TOP", db.xOffset or 0, db.yOffset or 12)
    end

    questIcon:SetSize(db.size or 22, db.size or 22)
    questIcon:SetFrameLevel((frame:GetFrameLevel() or 10) + 10)
end

-- 3. Update State
function NP:Update_QuestIcon(frame)
    if not frame then return end

    if not frame.QuestIcon then
        self:Construct_QuestIcon(frame)
    end

    local questIcon = frame.QuestIcon
    if not questIcon then return end

    local db = (E.db and E.db.nameplates and E.db.nameplates.questGiverIcon) or P.nameplates.questGiverIcon
    if not db or not db.enable then
        questIcon:Hide()
        return
    end

    -- Ignore Player Nameplates
    if frame.UnitType == "FRIENDLY_PLAYER" or frame.UnitType == "ENEMY_PLAYER" then
        questIcon:Hide()
        return
    end

    -- Extract Nameplate NPC Name
    local unit = frame.unit
    local unitName = frame.UnitName
    if not unitName or unitName == "" then
        if frame.Name and frame.Name.GetText then
            unitName = frame.Name:GetText()
        end
    end

    -- Check turn-in status
    if IsNPCQuestTurnIn(frame, unit, unitName) then
        self:Configure_QuestIcon(frame)
        questIcon.Texture:SetTexture(QUEST_COMPLETE_ICON)
        questIcon:Show()
    else
        questIcon:Hide()
    end
end

-- Refresh Plates on Quest & Target/Mouseover Events
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
eventFrame:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
eventFrame:SetScript("OnEvent", function()
    if NP and NP.Initialized then
        if NP.ForEachVisiblePlate then
            NP:ForEachVisiblePlate("Update_QuestIcon")
        elseif NP.ForEachPlate then
            NP:ForEachPlate("Update_QuestIcon")
        end
    end
end)