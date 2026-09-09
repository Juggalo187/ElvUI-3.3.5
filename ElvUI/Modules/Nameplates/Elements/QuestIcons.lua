local E, L, V, P, G = unpack(select(2, ...))
local NP = E:GetModule("NamePlates")
local LSM = E.Libs.LSM

local _G = _G
local pairs, ipairs, ceil, floor, tonumber = pairs, ipairs, ceil, floor, tonumber
local wipe, strmatch, strlower, strfind = wipe, strmatch, strlower, strfind

local CreateFrame = CreateFrame
local UnitExists = UnitExists
local UnitName = UnitName
local IsInInstance = IsInInstance
local UnitIsPlayer = UnitIsPlayer
local GetQuestLogSpecialItemInfo = GetQuestLogSpecialItemInfo
local GetQuestLogTitle = GetQuestLogTitle
local GetNumQuestLogEntries = GetNumQuestLogEntries
local C_Quest_GetQuestID = GenerateClosure(C_Quest.GetQuestID, C_Quest)
local ThreatTooltip = THREAT_TOOLTIP:gsub("%%d", "%%d-")

local questIcons = {
	iconTypes = {"Default", "Item", "Skull", "Chat"},
	indexByID = {},
	activeQuests = {},
	cache = {},
}

NP.QuestIcons = questIcons

local typesLocalized = {
	enUS = {
		KILL = {"slain", "destroy", "eliminate", "repel", "kill", "defeat"},
		CHAT = {"speak", "talk"}
	},
	deDE = {
		KILL = {"besiegen", "besiegt", "getötet", "töten", "tötet", "vernichtet", "zerstört", "genährt"},
		CHAT = {"befragt", "sprecht"}
	},
	ruRU = {
		KILL = {"убит", "уничтож", "разбомблен", "разбит", "сразит"},
		CHAT = {"поговорит", "спрашивать"}
	},
	esMX = {
		KILL = {"asesinad", "destrui", "elimin", "repel", "derrota"},
		CHAT = {"habla", "pídele"}
	},
	ptBR = {
		KILL = {"morto", "morta", "matar", "destrui", "elimin", "repel", "derrota"},
		CHAT = {"falar", "pedir"}
	},
	frFR = {
		KILL = {"tué", "tuer", "attaqué", "attaque", "abattre", "abattu", "détrui", "élimin", "repouss", "vaincu", "vaincre"},
		CHAT = {"parle", "demande"}
	},
	koKR = {
		KILL = {"쓰러뜨리기", "물리치기", "공격", "파괴"},
		CHAT = {"대화"}
	},
	zhCN = {
		KILL = {"消灭", "摧毁", "击败", "毁灭", "击退"},
		CHAT = {"交谈", "谈一谈"}
	},
	zhTW = {
		KILL = {"毀滅", "擊退", "殺死"},
		CHAT = {"交談", "說話"}
	},
}

local questTypes = typesLocalized[E.locale] or typesLocalized.enUS
local DEFAULT_QUEST_TEXTURE = [[Interface\GossipFrame\ActiveQuestIcon]]

local function CheckTextForQuest(text)
	local x, y = strmatch(text, "(%d+)/(%d+)")
	if x and y then
		local diff = floor(y - x)
		if diff > 0 then
			return diff
		end
	elseif not strmatch(text, ThreatTooltip) then
		local progress = tonumber(strmatch(text, "([%d%.]+)%%"))
		if progress and progress <= 100 then
			return ceil(100 - progress), true
		end
	end
end

questIcons.CheckTextForQuest = CheckTextForQuest

local function GetQuests(unitID)
	if not unitID or IsInInstance() then return end

	E.ScanTooltip:SetOwner(_G.UIParent, "ANCHOR_NONE")
	E.ScanTooltip:SetUnit(unitID)
	E.ScanTooltip:Show()

	local QuestList, notMyQuest, activeID
	for i = 3, E.ScanTooltip:NumLines() do
		local str = _G["ElvUI_ScanTooltipTextLeft"..i]
		local text = str and str:GetText()
		if not text or text == "" then return end

		if UnitIsPlayer(text) then
			notMyQuest = text ~= E.myname
		elseif text and not notMyQuest then
			local count, percent = CheckTextForQuest(text)
			local activeQuest = questIcons.activeQuests[text]
			if activeQuest then activeID = activeQuest end

			if count then
				local questType, index, texture
				if activeID then
					index = questIcons.indexByID[activeID] or activeID
					_, texture = GetQuestLogSpecialItemInfo(index)
				end

				if texture then
					questType = "QUEST_ITEM"
				else
					local lowerText = strlower(text)

					for _, listText in ipairs(questTypes.KILL) do
						if strfind(lowerText, listText, nil, true) then
							questType = "KILL"
							break
						end
					end

					if not questType then
						for _, listText in ipairs(questTypes.CHAT) do
							if strfind(lowerText, listText, nil, true) then
								questType = "CHAT"
								break
							end
						end
					end
				end

				if not QuestList then QuestList = {} end
				QuestList[#QuestList + 1] = {
					isPercent = percent,
					itemTexture = texture,
					objectiveCount = count,
					questType = questType or "DEFAULT",
					questLogIndex = index,
					questID = activeID
				}
			end
		end
	end

	E.ScanTooltip:Hide()
	return QuestList
end

local function hideIcons(element)
	for _, object in pairs(questIcons.iconTypes) do
		local icon = element[object]
		icon:Hide()

		if icon.Text then
			icon.Text:SetText("")
		end
	end
end

local function showQuestIcons(element, QuestList)
	hideIcons(element)

	if not QuestList then
		element:Hide()
		return
	end

	element:Show()

	local shownCount
	for i = 1, #QuestList do
		local quest = QuestList[i]
		local objectiveCount = quest.objectiveCount
		local questType = quest.questType
		local isPercent = quest.isPercent

		if isPercent or objectiveCount > 0 then
			local icon
			if questType == "DEFAULT" then
				icon = element.Default
			elseif questType == "KILL" then
				icon = element.Skull
			elseif questType == "CHAT" then
				icon = element.Chat
			elseif questType == "QUEST_ITEM" then
				icon = element.Item
			end

			if icon and not icon:IsShown() then
				shownCount = (shownCount and shownCount + 1) or 0

				local size = icon.size or 25
				local setPosition = icon.position or "TOPLEFT"
				local newPosition = E.InversePoints[setPosition]
				local offset = shownCount * (5 + size)

				icon:Show()
				icon:ClearAllPoints()
				icon:Point(newPosition, element, newPosition, (strmatch(setPosition, "LEFT") and -offset) or offset, 0)

				if questType ~= "CHAT" and icon.Text and (isPercent or objectiveCount > 1) then
					icon.Text:SetText((isPercent and objectiveCount.."%") or objectiveCount)
				end

				if questType == "QUEST_ITEM" then
					element.Item:SetTexture(quest.itemTexture)
				end
			end
		end
	end
end

function NP:RefreshQuestLogCache()
	wipe(questIcons.indexByID)
	wipe(questIcons.activeQuests)
	wipe(questIcons.cache)

	for i = 1, GetNumQuestLogEntries() do
		local title, _, _, _, isHeader = GetQuestLogTitle(i)
		if title and not isHeader then
			local id = C_Quest_GetQuestID(i)
			if id and id > 0 then
				questIcons.indexByID[id] = i
				questIcons.activeQuests[title] = id
			else
				questIcons.activeQuests[title] = i
			end
		end
	end
end

function NP:Update_QuestIcons(frame)
	local unitType = frame.UnitType
	if unitType ~= "FRIENDLY_NPC" and unitType ~= "ENEMY_NPC" then return end

	local db = self.db.units[unitType].questIcon
	local element = frame.QuestIcons
	if not db or not db.enable or not element then
		if element then
			element:Hide()
			hideIcons(element)
		end
		return
	end

	local unit = NP:ResolvePlateUnit(frame)
	local QuestList

	if unit then
		QuestList = GetQuests(unit)
		questIcons.cache[frame.UnitName] = QuestList
	else
		-- Try harder to find a unit for this NPC
		if frame.UnitName then
			-- Check all nameplate units
			for i = 1, 40 do
				local unitID = "nameplate" .. i
				if UnitExists(unitID) and UnitName(unitID) == frame.UnitName then
					QuestList = GetQuests(unitID)
					if QuestList then
						questIcons.cache[frame.UnitName] = QuestList
						break
					end
				end
			end
		end
		
		-- Fallback to cached data
		if not QuestList then
			QuestList = questIcons.cache[frame.UnitName]
		end
	end

	showQuestIcons(element, QuestList)
end

function NP:Configure_QuestIcons(frame)
	local unitType = frame.UnitType
	if unitType ~= "FRIENDLY_NPC" and unitType ~= "ENEMY_NPC" then return end

	local db = self.db.units[unitType].questIcon
	local element = frame.QuestIcons
	if not db or not element then return end

	if not db.enable then
		element:Hide()
		return
	end

	element:ClearAllPoints()
	element:Point(E.InversePoints[db.position], frame, db.position, db.xOffset, db.yOffset)

	for _, object in ipairs(questIcons.iconTypes) do
		local icon = element[object]
		icon:Size(db.size, db.size)
		icon:SetAlpha(db.hideIcon and 0 or 1)

		local xoffset = strfind(db.textPosition, "LEFT") and -2 or 2
		local yoffset = strfind(db.textPosition, "BOTTOM") and 2 or -2
		icon.Text:ClearAllPoints()
		icon.Text:Point("CENTER", icon, db.textPosition, xoffset, yoffset)
		icon.Text:FontTemplate(LSM:Fetch("font", db.font), db.fontSize, db.fontOutline)
		icon.Text:SetJustifyH("CENTER")

		icon.size = db.size
		icon.position = db.position
	end
end

function NP:Construct_QuestIcons(frame)
	local QuestIcons = CreateFrame("Frame", nil, frame)
	QuestIcons:Size(20)
	QuestIcons:Hide()

	for _, object in ipairs(questIcons.iconTypes) do
		local icon = QuestIcons:CreateTexture(nil, "OVERLAY", nil, 1)
		icon.Text = QuestIcons:CreateFontString(nil, "OVERLAY")
		icon.Text:FontTemplate()
		icon:Hide()

		QuestIcons[object] = icon
	end

	QuestIcons.Default:SetTexture(DEFAULT_QUEST_TEXTURE)
	QuestIcons.Skull:SetTexture(E.Media.Textures.SkullIcon)
	QuestIcons.Item:SetTexCoord(unpack(E.TexCoords))
	QuestIcons.Chat:SetTexture([[Interface\WorldMap\ChatBubble_64.PNG]])
	QuestIcons.Chat:SetTexCoord(0, 0.5, 0.5, 1)

	return QuestIcons
end

local cacheFrame = CreateFrame("Frame")
cacheFrame:RegisterEvent("QUEST_ACCEPTED")
cacheFrame:RegisterEvent("QUEST_REMOVED")
cacheFrame:RegisterEvent("QUEST_LOG_UPDATE")
cacheFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
cacheFrame:SetScript("OnEvent", function(_, event)
	NP:RefreshQuestLogCache()

	if event == "QUEST_LOG_UPDATE" or event == "QUEST_ACCEPTED" or event == "QUEST_REMOVED" then
		if NP.Update_QuestIcons then
			NP:ForEachVisiblePlate("Update_QuestIcons")
		end
	end
end)

NP:RefreshQuestLogCache()
