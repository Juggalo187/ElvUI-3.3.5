local E, L, V, P, G = unpack(ElvUI)
local M = E:GetModule("Enhanced_Misc")

local _G = _G
local select = select

local GetItemInfo = GetItemInfo
local GetNumQuestChoices = GetNumQuestChoices
local GetQuestItemLink = GetQuestItemLink

local function SelectQuestReward(id)
	local button = _G["QuestInfoItem"..id]

	if button and button.type == "choice" then
		QuestInfoItem_OnClick(button)
	end
end

local function SetCoinIcon(button, show)
	if not button.ValueIconFrame then
		local coinFrame = CreateFrame("Frame", nil, button)
		coinFrame:Size(18, 18)
		coinFrame:SetFrameLevel(button:GetFrameLevel() + 10)
		coinFrame:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)

		local tex = coinFrame:CreateTexture(nil, "OVERLAY")
		tex:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
		tex:SetAllPoints()

		button.ValueIconFrame = coinFrame
	end

	if show then
		button.ValueIconFrame:Show()
	else
		button.ValueIconFrame:Hide()
	end
end

local function SetSelectionGlow(button, show)
	if not button.SelectionGlow then
		local glow = CreateFrame("Frame", nil, button)
		glow:SetFrameLevel(button:GetFrameLevel() + 5)
		glow:SetBackdrop({
			edgeFile = "Interface\\Buttons\\WHITE8X8",
			edgeSize = 1.5,
		})
		glow:SetBackdropBorderColor(1, 0.82, 0, 1)
		glow:SetPoint("TOPLEFT", button, "TOPLEFT", -1, 1)
		glow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)
		button.SelectionGlow = glow
	end

	if show then
		button.SelectionGlow:Show()
	else
		button.SelectionGlow:Hide()
	end
end

function M:UpdateQuestRewardHighlight()
	local numItems = GetNumQuestChoices()
	if numItems <= 0 then return end

	local maxItems = MAX_NUM_ITEMS or 10
	for i = 1, maxItems do
		local button = _G["QuestInfoItem"..i]
		if button then
			SetCoinIcon(button, false)
			SetSelectionGlow(button, false)
		end
	end

	local link
	local choiceID, maxPrice = nil, 0
	local hasMissingInfo = false

	for i = 1, numItems do
		local button = _G["QuestInfoItem"..i]
		if button then
			link = button.type and (QuestInfoFrame.questLog and GetQuestLogItemLink or GetQuestItemLink)(button.type, button:GetID())

			if link then
				local name, _, _, _, _, itemType, _, _, _, _, price = GetItemInfo(link)
				if name then
					if price and (itemType == "Armor" or itemType == "Weapon") then
						if price > maxPrice then
							maxPrice = price
							choiceID = i
						end
					end
				else
					hasMissingInfo = true
				end
			else
				hasMissingInfo = true
			end
		end
	end

	-- If there is only 1 choice, auto-select it anyway (convenience)
	if numItems == 1 then
		choiceID = 1
	end

	if hasMissingInfo then
		self:RegisterEvent("GET_ITEM_INFO_RECEIVED")
	else
		self:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
	end

	if choiceID and (maxPrice > 0 or numItems == 1) and (QuestFrameCompleteQuestButton:IsShown() or (QuestInfoFrame.chooseItems and not QuestInfoFrame.questLog)) then
		if not QuestInfoFrame.itemChoice or QuestInfoFrame.itemChoice == 0 then
			SelectQuestReward(choiceID)
		end
	end

	if choiceID and maxPrice > 0 then
		local button = _G["QuestInfoItem"..choiceID]
		if button then
			SetCoinIcon(button, true)
		end
	end

	local selectedID = QuestInfoFrame.itemChoice
	if selectedID and selectedID > 0 then
		local button = _G["QuestInfoItem"..selectedID]
		if button then
			SetSelectionGlow(button, true)
		end
	end
end

function M:GET_ITEM_INFO_RECEIVED()
	self:UpdateQuestRewardHighlight()
end

function M:QUEST_COMPLETE()
	self:UpdateQuestRewardHighlight()
end

function M:QuestInfoItem_OnClick(button)
	if button.type == "choice" then
		self:UpdateQuestRewardHighlight()
	end
end

function M:ToggleQuestReward()
	if E.private.general.selectQuestReward then
		self:RegisterEvent("QUEST_COMPLETE")
		if not self:IsHooked("QuestInfo_ShowRewards") then
			self:SecureHook("QuestInfo_ShowRewards", "UpdateQuestRewardHighlight")
		end
		if not self:IsHooked("QuestInfoItem_OnClick") then
			self:SecureHook("QuestInfoItem_OnClick", "QuestInfoItem_OnClick")
		end
	else
		self:UnregisterEvent("QUEST_COMPLETE")
		self:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
		if self:IsHooked("QuestInfo_ShowRewards") then
			self:Unhook("QuestInfo_ShowRewards")
		end
		if self:IsHooked("QuestInfoItem_OnClick") then
			self:Unhook("QuestInfoItem_OnClick")
		end
		local maxItems = MAX_NUM_ITEMS or 10
		for i = 1, maxItems do
			local button = _G["QuestInfoItem"..i]
			if button then
				if button.ValueIconFrame then
					button.ValueIconFrame:Hide()
				end
				if button.SelectionGlow then
					button.SelectionGlow:Hide()
				end
			end
		end
	end
end