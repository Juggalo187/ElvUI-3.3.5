local E, L, V, P, G = unpack(select(2, ...))
local NP = E:GetModule("NamePlates")

-- Default Profile Settings
P["nameplates"]["questGiverIcon"] = {
    enable = true,
    size = 22,
    xOffset = 0,
    yOffset = 12,
}

-- Completed Quest Texture (?)
local QUEST_COMPLETE_ICON = [[Interface\GossipFrame\ActiveQuestIcon]]

-- Helper: Scans Quest Log for completed quests matching the NPC's name
local function PlayerHasCompletedQuestForNPC(npcName)
    if not npcName or npcName == "" then return false end

    local currentSelection = GetQuestLogSelection()
    local numEntries = GetNumQuestLogEntries()
    local isTurnInNPC = false

    for i = 1, numEntries do
        local questTitle, level, questTag, suggestedGroup, isHeader, isCollapsed, isComplete = GetQuestLogTitle(i)
        
        -- Process only finished quests (isComplete == 1)
        if not isHeader and isComplete == 1 then
            SelectQuestLogEntry(i)
            local questDescription, questObjectives = GetQuestLogQuestText()
            
            if (questObjectives and string.find(questObjectives, npcName, 1, true)) or 
               (questDescription and string.find(questDescription, npcName, 1, true)) then
                isTurnInNPC = true
                break
            end
        end
    end

    -- Restore previous quest log selection
    if currentSelection and currentSelection > 0 then
        SelectQuestLogEntry(currentSelection)
    end

    return isTurnInNPC
end

-- 1. Construct Element Frame
function NP:Construct_QuestIcon(frame)
    local questIcon = CreateFrame("Frame", nil, frame)
    questIcon:SetSize(22, 22)

    local texture = questIcon:CreateTexture(nil, "OVERLAY")
    texture:SetAllPoints()
    questIcon.Texture = texture

    questIcon:Hide()
    return questIcon
end

-- 2. Configure Placement & Size
function NP:Configure_QuestIcon(frame)
    local questIcon = frame.QuestIcon
    if not questIcon then return end

    local db = (NP.db and NP.db.questGiverIcon) or P.nameplates.questGiverIcon
    if not db.enable then
        questIcon:Hide()
        return
    end

    questIcon:ClearAllPoints()
    if frame.Health:IsShown() then
        questIcon:SetPoint("BOTTOM", frame.Health, "TOP", db.xOffset, db.yOffset)
    else
        questIcon:SetPoint("BOTTOM", frame.Name, "TOP", db.xOffset, db.yOffset)
    end

    questIcon:SetSize(db.size, db.size)
end

-- 3. Update State
function NP:Update_QuestIcon(frame)
    local questIcon = frame.QuestIcon
    if not questIcon then return end

    local db = (NP.db and NP.db.questGiverIcon) or P.nameplates.questGiverIcon

    -- Check if enabled and frame is a friendly NPC
    if not db.enable or frame.UnitType ~= "FRIENDLY_NPC" then
        questIcon:Hide()
        return
    end

    -- Turn-in Check
    if PlayerHasCompletedQuestForNPC(frame.UnitName) then
        questIcon.Texture:SetTexture(QUEST_COMPLETE_ICON)
        questIcon:Show()
    else
        questIcon:Hide()
    end
end