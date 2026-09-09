local E, L, V, P, G = unpack(select(2, ...)); --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local mod = E:GetModule("DataBars")
local LSM = LibStub("LibSharedMedia-3.0")

--Lua functions
local max, min = math.max, math.min
local format = string.format
--WoW API
local GetNumQuestLogEntries = GetNumQuestLogEntries
local GetQuestLogRewardXP = GetQuestLogRewardXP
local GetQuestLogSelection = GetQuestLogSelection
local GetQuestLogTitle = GetQuestLogTitle
local GetXPExhaustion = GetXPExhaustion
local GetZoneText = GetZoneText
local IsXPUserDisabled = IsXPUserDisabled
local SelectQuestLogEntry = SelectQuestLogEntry
local UnitLevel = UnitLevel
local UnitXP = UnitXP
local UnitXPMax = UnitXPMax

-- GLOBALS: CreateFrame, GameTooltip, LeftChatPanel, ToggleDropDownMenu, XPRM

-- Add dropdown helper functions
local ToggleDropDownMenu = ToggleDropDownMenu
local CreateFrame = CreateFrame
local TARGET_REALM = "Triumvirate"
local currentRealm = GetRealmName()

local function IsTargetRealm()
    return currentRealm == TARGET_REALM
end

-- Helper function for chat messages
local function AddChatMessage(msg, r, g, b)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(msg, r or 1, g or 1, b or 1)
    end
end

-- Variables to track XP status
local weekendXPActive = false
local weekendXPMaxRate = 3
local weekendXPChecked = false
local isChecking = false
local pendingRateResponse = false
local currentXPRate = 0
local xpEnabled = true

-- Create timer frame for delayed operations (MUST be defined here BEFORE OnChatMessage)
local timerFrame = CreateFrame("Frame")
timerFrame:Hide()
timerFrame.elapsed = 0
timerFrame.delay = 0.5
timerFrame.callback = nil

timerFrame:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed >= self.delay then
        self.elapsed = 0
        self:Hide()
        if self.callback then
            self.callback()
            self.callback = nil
        end
    end
end)

local function getQuestXP(completedOnly, zoneOnly)
	local lastQuestLogID = GetQuestLogSelection()
	local zoneText = GetZoneText()
	local totalExp = 0
	local locationName

	for questIndex = 1, GetNumQuestLogEntries() do
		SelectQuestLogEntry(questIndex)
		local title, _, _, _, isHeader, _, isComplete, _, questID = GetQuestLogTitle(questIndex)

		if isHeader then
			locationName = title
		elseif (not completedOnly or isComplete) and (not zoneOnly or locationName == zoneText) then
			totalExp = totalExp + GetQuestLogRewardXP(questID)
		end
	end

	SelectQuestLogEntry(lastQuestLogID)

	return totalExp
end

-- Hook into chat frame to detect messages
local function OnChatMessage(self, event, msg, ...)
    -- Check for weekend XP messages
    if msg and string.find(msg, "Weekend XP") then
        local maxRate = string.match(msg, "up to (%d+)x")
        if maxRate then
            weekendXPMaxRate = tonumber(maxRate)
            weekendXPActive = true
            weekendXPChecked = true
            isChecking = false
            pendingRateResponse = false
            
            AddChatMessage(string.format("|cff00ff00[XP]|r Weekend XP ACTIVE! Max rate: %dx", weekendXPMaxRate), 1, 1, 1)
            
            if mod.expBar and mod.expBar.dropdown then
                mod.expBar.dropdown:initialize()
            end
        end
    end
    
    -- Check for current XP rate
    if msg and string.find(msg, "Your current XP rate is") then
        local rate = string.match(msg, "rate is (%d+)")
        if rate then
            currentXPRate = tonumber(rate)
        end
        
        if isChecking or pendingRateResponse then
            pendingRateResponse = true
        else
            if not weekendXPActive then
                weekendXPActive = false
                weekendXPMaxRate = 3
                weekendXPChecked = true
            end
        end
        
        if pendingRateResponse and isChecking then
            -- Use timer frame instead of C_Timer.After
            timerFrame.callback = function()
                if pendingRateResponse and isChecking then
                    weekendXPActive = false
                    weekendXPMaxRate = 3
                    weekendXPChecked = true
                    isChecking = false
                    pendingRateResponse = false
                    AddChatMessage("|cffff8800[XP]|r Weekend XP: Inactive", 1, 1, 1)
                    
                    if mod.expBar and mod.expBar.dropdown then
                        mod.expBar.dropdown:initialize()
                    end
                end
            end
            timerFrame.elapsed = 0
            timerFrame:Show()
        end
        
        -- Update menu with current rate
        if mod.expBar and mod.expBar.dropdown then
            mod.expBar.dropdown:initialize()
        end
    end
    
    -- Check for rate update
    if msg and string.find(msg, "You have updated your XP rate to") then
        local rate = string.match(msg, "to (%d+)")
        if rate then
            currentXPRate = tonumber(rate)
            AddChatMessage(string.format("|cff00ff00[XP]|r XP rate set to %dx", currentXPRate), 1, 1, 1)
            
            if mod.expBar and mod.expBar.dropdown then
                mod.expBar.dropdown:initialize()
            end
        end
    end
    
    -- Check for XP disable
    if msg and string.find(msg, "You have disabled your XP gain") then
        xpEnabled = false
        AddChatMessage("|cffff0000[XP]|r XP gain DISABLED", 1, 1, 1)
        
        if mod.expBar and mod.expBar.dropdown then
            mod.expBar.dropdown:initialize()
        end
    end
    
    -- Check for XP enable
    if msg and string.find(msg, "You have enabled your XP gain") then
        xpEnabled = true
        AddChatMessage("|cff00ff00[XP]|r XP gain ENABLED", 1, 1, 1)
        
        if mod.expBar and mod.expBar.dropdown then
            mod.expBar.dropdown:initialize()
        end
    end
end

-- Register chat event handler
local chatFrame = CreateFrame("Frame")
chatFrame:RegisterEvent("CHAT_MSG_SYSTEM")
chatFrame:RegisterEvent("CHAT_MSG_SAY")
chatFrame:RegisterEvent("CHAT_MSG_YELL")
chatFrame:RegisterEvent("CHAT_MSG_EMOTE")
chatFrame:RegisterEvent("CHAT_MSG_WHISPER")
chatFrame:RegisterEvent("CHAT_MSG_CHANNEL")
chatFrame:SetScript("OnEvent", OnChatMessage)

-- Function to check weekend status on addon load
function mod:CheckWeekendStatusOnLoad()
    if IsTargetRealm() and not weekendXPChecked then
        isChecking = true
        pendingRateResponse = false
        SendChatMessage(".xp view", "SAY")
    end
end

function mod:ExperienceBar_QuestXPUpdate(event)
	if event == "ZONE_CHANGED_NEW_AREA" and not self.db.experience.questXP.questCurrentZoneOnly then return end

	self.questTotalXP = getQuestXP(self.db.experience.questXP.questCompletedOnly, self.db.experience.questXP.questCurrentZoneOnly)

	if self.questTotalXP > 0 then
		self.expBar.questBar:SetMinMaxValues(0, self.expBar.maxExp)
		self.expBar.questBar:SetValue(min(self.expBar.curExp + self.questTotalXP, self.expBar.maxExp))
		self.expBar.questBar:Show()
	else
		self.expBar.questBar:Hide()
	end
end

function mod:ExperienceBar_Update(event)
	if not mod.db.experience.enable then return end

	local bar = self.expBar
	local hideBar = (self.playerLevel == self.maxExpansionLevel and self.db.experience.hideAtMaxLevel) or self.expDisabled

	if hideBar or (event == "PLAYER_REGEN_DISABLED" and self.db.experience.hideInCombat) then
		E:DisableMover(bar.mover:GetName())
		bar:Hide()
	elseif not hideBar and (not self.db.experience.hideInCombat or not self.inCombatLockdown) then
		E:EnableMover(bar.mover:GetName())
		bar:Show()

		if self.db.experience.hideInVehicle then
			E:RegisterObjectForVehicleLock(bar, E.UIParent)
		else
			E:UnregisterObjectForVehicleLock(bar)
		end

		local textFormat = self.db.experience.textFormat
		local curExp = UnitXP("player")
		local maxExp = max(1, UnitXPMax("player"))
		local rested = GetXPExhaustion()
		bar.curExp = curExp
		bar.maxExp = maxExp

		bar.statusBar:SetMinMaxValues(min(0, curExp), maxExp)
	--	bar.statusBar:SetValue(curExp - 1 >= 0 and curExp - 1 or 0)
		bar.statusBar:SetValue(curExp)

		if rested and rested > 0 then
			bar.rested:SetMinMaxValues(0, maxExp)
			bar.rested:SetValue(min(curExp + rested, maxExp))

			if textFormat == "PERCENT" then
				bar.text:SetFormattedText("%d%% R:%d%%", curExp / maxExp * 100, rested / maxExp * 100)
			elseif textFormat == "CURMAX" then
				bar.text:SetFormattedText("%s - %s R:%s", E:ShortValue(curExp), E:ShortValue(maxExp), E:ShortValue(rested))
			elseif textFormat == "CURPERC" then
				bar.text:SetFormattedText("%s - %d%% R:%s [%d%%]", E:ShortValue(curExp), curExp / maxExp * 100, E:ShortValue(rested), rested / maxExp * 100)
			elseif textFormat == "CUR" then
				bar.text:SetFormattedText("%s R:%s", E:ShortValue(curExp), E:ShortValue(rested))
			elseif textFormat == "REM" then
				bar.text:SetFormattedText("%s R:%s", E:ShortValue(maxExp - curExp), E:ShortValue(rested))
			elseif textFormat == "CURREM" then
				bar.text:SetFormattedText("%s - %s R:%s", E:ShortValue(curExp), E:ShortValue(maxExp - curExp), E:ShortValue(rested))
			elseif textFormat == "CURPERCREM" then
				bar.text:SetFormattedText("%s - %d%% (%s) R:%s", E:ShortValue(curExp), curExp / maxExp * 100, E:ShortValue(maxExp - curExp), E:ShortValue(rested))
			end
		else
			bar.rested:SetMinMaxValues(0, 1)
			bar.rested:SetValue(0)

			if textFormat == "PERCENT" then
				bar.text:SetFormattedText("%d%%", curExp / maxExp * 100)
			elseif textFormat == "CURMAX" then
				bar.text:SetFormattedText("%s - %s", E:ShortValue(curExp), E:ShortValue(maxExp))
			elseif textFormat == "CURPERC" then
				bar.text:SetFormattedText("%s - %d%%", E:ShortValue(curExp), curExp / maxExp * 100)
			elseif textFormat == "CUR" then
				bar.text:SetFormattedText("%s", E:ShortValue(curExp))
			elseif textFormat == "REM" then
				bar.text:SetFormattedText("%s", E:ShortValue(maxExp - curExp))
			elseif textFormat == "CURREM" then
				bar.text:SetFormattedText("%s - %s", E:ShortValue(curExp), E:ShortValue(maxExp - curExp))
			elseif textFormat == "CURPERCREM" then
				bar.text:SetFormattedText("%s - %d%% (%s)", E:ShortValue(curExp), curExp / maxExp * 100, E:ShortValue(maxExp - curExp))
			end
		end
	end
end

function mod.ExperienceBar_OnEnter(self)
	if mod.db.experience.mouseover then
		E:UIFrameFadeIn(self, 0.4, self:GetAlpha(), 1)
	end

	local curExp = UnitXP("player")
	local maxExp = max(1, UnitXPMax("player"))
	local rested = GetXPExhaustion()

	GameTooltip:ClearLines()
	GameTooltip:SetOwner(self, "ANCHOR_CURSOR", 0, -4)

	GameTooltip:AddLine(L["Experience"])
	GameTooltip:AddLine(" ")

	GameTooltip:AddDoubleLine(L["XP:"], format("%d / %d (%d%%)", curExp, maxExp, curExp / maxExp * 100), 1, 1, 1)
	GameTooltip:AddDoubleLine(L["Remaining:"], format("%d (%d%% - %d %s)", maxExp - curExp, (maxExp - curExp) / maxExp * 100, 20 * (maxExp - curExp) / maxExp, L["Bars"]), 1, 1, 1)

	if rested then
		GameTooltip:AddDoubleLine(L["Rested:"], format("+%d (%d%%)", rested, rested / maxExp * 100), 1, 1, 1)
	end

	if mod.questXPEnabled and mod.db.experience.questXP.tooltip then
		GameTooltip:AddDoubleLine(L["Quest Log XP:"], mod.questTotalXP, 1, 1, 1)
	end

	GameTooltip:Show()
end

function mod.ExperienceBar_OnClick(self, button)
    if button == "RightButton" and IsTargetRealm() then
        if not self.dropdown then
            self.dropdown = mod:CreateExperienceBarDropdown()
        end
        
        if not weekendXPChecked and not isChecking then
            isChecking = true
            pendingRateResponse = false
            SendChatMessage(".xp view", "SAY")
            self.dropdown:initialize()
            ToggleDropDownMenu(1, nil, self.dropdown, "cursor", 0, 0, "MENU")
        else
            self.dropdown:initialize()
            ToggleDropDownMenu(1, nil, self.dropdown, "cursor", 0, 0, "MENU")
        end
    end
end

-- Create the dropdown menu
function mod:CreateExperienceBarDropdown()
    local dropdown = CreateFrame("Frame", "ExperienceBarDropdown", UIParent, "UIDropDownMenuTemplate")
    dropdown:Hide()
    
    function dropdown:initialize()
        local info = UIDropDownMenu_CreateInfo()
        
        -- If still checking, show a message
        if isChecking then
            info.text = "Checking XP status..."
            info.notCheckable = true
            info.disabled = true
            UIDropDownMenu_AddButton(info)
            return
        end
        
        -- Show weekend status and current rate
        if weekendXPChecked then
            -- Weekend status
            if weekendXPActive then
                info.text = "|cff00ff00Weekend XP ACTIVE|r"
            else
                info.text = "|cffff8800Weekend XP: Inactive|r"
            end
            info.notCheckable = true
            info.disabled = true
            UIDropDownMenu_AddButton(info)
            
            -- Show current rate if known
            if currentXPRate > 0 then
                info = UIDropDownMenu_CreateInfo()
                info.text = string.format("|cff00ccffCurrent XP Rate: %dx|r", currentXPRate)
                info.notCheckable = true
                info.disabled = true
                UIDropDownMenu_AddButton(info)
            end
        end
        
        -- Separator
        info = UIDropDownMenu_CreateInfo()
        info.text = ""
        info.disabled = true
        info.notCheckable = true
        info.isTitle = false
        UIDropDownMenu_AddButton(info)
        
        -- View XP Rate
        info = UIDropDownMenu_CreateInfo()
        info.text = L["View XP Rate"]
        info.notCheckable = true
        info.func = function()
            SendChatMessage(".xp view", "SAY")
            AddChatMessage("|cff00ff00[XP]|r Checking XP rate...", 1, 1, 1)
        end
        UIDropDownMenu_AddButton(info)
        
        -- Refresh Status
        info = UIDropDownMenu_CreateInfo()
        info.text = L["Refresh Status"]
        info.notCheckable = true
        info.func = function()
            weekendXPChecked = false
            weekendXPActive = false
            weekendXPMaxRate = 3
            currentXPRate = 0
            isChecking = true
            pendingRateResponse = false
            AddChatMessage("|cff00ff00[XP]|r Refreshing status...", 1, 1, 1)
            SendChatMessage(".xp view", "SAY")
            dropdown:initialize()
            ToggleDropDownMenu(1, nil, dropdown, "cursor", 0, 0, "MENU")
        end
        UIDropDownMenu_AddButton(info)
        
        -- Separator
        info = UIDropDownMenu_CreateInfo()
        info.text = ""
        info.disabled = true
        info.notCheckable = true
        info.isTitle = false
        UIDropDownMenu_AddButton(info)
        
        -- Only show Enable XP if XP is disabled
        if not xpEnabled then
            info = UIDropDownMenu_CreateInfo()
            info.text = L["Enable XP"]
            info.notCheckable = true
            info.func = function()
                SendChatMessage(".xp enable", "SAY")
                AddChatMessage("|cff00ff00[XP]|r Enabling XP gain...", 1, 1, 1)
            end
            UIDropDownMenu_AddButton(info)
        end
        
        -- Only show Disable XP if XP is enabled
        if xpEnabled then
            info = UIDropDownMenu_CreateInfo()
            info.text = L["Disable XP"]
            info.notCheckable = true
            info.func = function()
                SendChatMessage(".xp disable", "SAY")
                AddChatMessage("|cffff0000[XP]|r Disabling XP gain...", 1, 1, 1)
            end
            UIDropDownMenu_AddButton(info)
        end
        
        -- Default XP Rate
        info = UIDropDownMenu_CreateInfo()
        info.text = L["Default XP Rate"]
        info.notCheckable = true
        info.func = function()
            SendChatMessage(".xp default", "SAY")
            AddChatMessage("|cff00ff00[XP]|r Resetting XP rate to default...", 1, 1, 1)
        end
        UIDropDownMenu_AddButton(info)
        
        -- Separator
        info = UIDropDownMenu_CreateInfo()
        info.text = ""
        info.disabled = true
        info.notCheckable = true
        info.isTitle = false
        UIDropDownMenu_AddButton(info)
        
        -- Determine which rates to show based on weekend status
        local maxRate = weekendXPActive and weekendXPMaxRate or 3
        local rates = {}
        for i = 1, maxRate do
            table.insert(rates, i)
        end
        
        -- Set XP Rate options based on available rates
        for _, rate in ipairs(rates) do
            info = UIDropDownMenu_CreateInfo()
            local rateText = string.format("Set XP Rate: %dx", rate)
            if currentXPRate == rate then
                rateText = rateText .. " |cff00ff00(CURRENT)|r"
            end
            info.text = rateText
            info.notCheckable = true
            info.func = function()
                SendChatMessage(string.format(".xp set %d", rate), "SAY")
                AddChatMessage(string.format("|cff00ff00[XP]|r Setting XP rate to %dx...", rate), 1, 1, 1)
            end
            UIDropDownMenu_AddButton(info)
        end
    end
    
    return dropdown
end

function mod:ExperienceBar_UpdateDimensions()
	self.expBar:Size(self.db.experience.width, self.db.experience.height)
	self.expBar:SetAlpha(self.db.experience.mouseover and 0 or 1)

	self.expBar.text:FontTemplate(LSM:Fetch("font", self.db.experience.font), self.db.experience.textSize, self.db.experience.fontOutline)

	self.expBar.statusBar:SetOrientation(self.db.experience.orientation)
	self.expBar.statusBar:SetRotatesTexture(self.db.experience.orientation ~= "HORIZONTAL")

	self.expBar.rested:SetOrientation(self.db.experience.orientation)
	self.expBar.rested:SetRotatesTexture(self.db.experience.orientation ~= "HORIZONTAL")

	self.expBar.questBar:SetOrientation(self.db.experience.orientation)
	self.expBar.questBar:SetRotatesTexture(self.db.experience.orientation ~= "HORIZONTAL")

	local color = self.db.experience.questXP.color
	self.expBar.questBar:SetStatusBarColor(color.r, color.g, color.b, color.a)

	if self.expBar.bubbles then
		self:UpdateBarBubbles(self.expBar, self.db.experience)
	elseif self.db.experience.showBubbles then
		local bubbles = self:CreateBarBubbles(self.expBar)
		bubbles:SetFrameLevel(5)
		self:UpdateBarBubbles(self.expBar, self.db.experience)
	end
end

function mod:ExperienceBar_Toggle()
	if self.db.experience.enable and (self.playerLevel ~= self.maxExpansionLevel or not self.db.experience.hideAtMaxLevel) then
		self.playerLevel = UnitLevel("player")
		self.expDisabled = IsXPUserDisabled()

		self.expBar.eventFrame:RegisterEvent("DISABLE_XP_GAIN")
		self.expBar.eventFrame:RegisterEvent("ENABLE_XP_GAIN")

		if not self.expDisabled then
			self.expBar.eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
			self.expBar.eventFrame:RegisterEvent("PLAYER_XP_UPDATE")
			self.expBar.eventFrame:RegisterEvent("UPDATE_EXHAUSTION")
			self.expBar.eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
			self.expBar.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
		end

		self:ExperienceBar_Update()
		self:ExperienceBar_QuestXPToggle()
		E:EnableMover(self.expBar.mover:GetName())
	else
		self.expBar.eventFrame:UnregisterEvent("DISABLE_XP_GAIN")
		self.expBar.eventFrame:UnregisterEvent("ENABLE_XP_GAIN")

		if not self.expDisabled then
			self.expBar.eventFrame:UnregisterEvent("PLAYER_LEVEL_UP")
			self.expBar.eventFrame:UnregisterEvent("PLAYER_XP_UPDATE")
			self.expBar.eventFrame:UnregisterEvent("UPDATE_EXHAUSTION")
			self.expBar.eventFrame:UnregisterEvent("PLAYER_REGEN_DISABLED")
			self.expBar.eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
		end

		self:ExperienceBar_QuestXPToggle()
		self.expBar:Hide()
		E:DisableMover(self.expBar.mover:GetName())
	end
end

function mod:ExperienceBar_QuestXPToggle(event)
	if not self.questXPEnabled and not self.expDisabled and self.db.experience.questXP.enable then
		self.questXPEnabled = true

		self.expBar.eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
		self.expBar.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
		self.expBar.eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

		self:ExperienceBar_QuestXPUpdate(event)
	elseif self.questXPEnabled and (self.expDisabled or not self.db.experience.questXP.enable) then
		self.questXPEnabled = false
		self.expBar.eventFrame:UnregisterEvent("QUEST_LOG_UPDATE")
		self.expBar.eventFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
		self.expBar.eventFrame:UnregisterEvent("ZONE_CHANGED_NEW_AREA")

		self.expBar.questBar:Hide()
	end
end

function mod:ExperienceBar_Load()
	self.expBar = self:CreateBar("ElvUI_ExperienceBar", self.ExperienceBar_OnEnter, self.ExperienceBar_OnClick, "LEFT", LeftChatPanel, "RIGHT", -E.Border + E.Spacing*3, 0)
	self.expBar:RegisterForClicks("RightButtonUp")
	self.expBar.dropdown = nil
	
	self.expBar.statusBar:SetFrameLevel(3)
	self.expBar.statusBar:SetStatusBarColor(0, 0.4, 1, 1)

	self.expBar.rested = CreateFrame("StatusBar", "$parent_Rested", self.expBar)
	self.expBar.rested:SetFrameLevel(1)
	self.expBar.rested:SetInside()
	self.expBar.rested:SetStatusBarTexture(E.media.normTex)
	self.expBar.rested:SetStatusBarColor(0.5, 0, 0.5, 0.8)
	E:RegisterStatusBar(self.expBar.rested)

	self.expBar.questBar = CreateFrame("StatusBar", "$parent_Quest", self.expBar)
	self.expBar.questBar:SetFrameLevel(2)
	self.expBar.questBar:SetInside()
	self.expBar.questBar:SetStatusBarTexture(E.media.normTex)
	self.expBar.questBar:Hide()
	E:RegisterStatusBar(self.expBar.questBar)

	self.expBar.eventFrame = CreateFrame("Frame")
	self.expBar.eventFrame:Hide()
	self.expBar.eventFrame:SetScript("OnEvent", function(this, event, arg1)
		if event == "PLAYER_LEVEL_UP" then
			self.playerLevel = arg1
			self.forceUpdateQuestXP = true
		elseif event == "PLAYER_XP_UPDATE" then
			self:ExperienceBar_Update(event)

			if self.forceUpdateQuestXP and self.questXPEnabled and self.db.experience.questXP.enable then
				self.forceUpdateQuestXP = nil
				self:ExperienceBar_QuestXPUpdate(event)
			end
		elseif event == "PLAYER_REGEN_DISABLED" then
			self.inCombatLockdown = true

			if self.db.experience.hideInCombat then
				self:ExperienceBar_Update(event)
			end
		elseif event == "PLAYER_REGEN_ENABLED" then
			self.inCombatLockdown = false

			if self.db.experience.hideInCombat then
				self:ExperienceBar_Update(event)
			end
		elseif event == "ENABLE_XP_GAIN" then
			self.expDisabled = false

			this:RegisterEvent("PLAYER_LEVEL_UP")
			this:RegisterEvent("PLAYER_XP_UPDATE")
			this:RegisterEvent("UPDATE_EXHAUSTION")
			this:RegisterEvent("PLAYER_REGEN_DISABLED")
			this:RegisterEvent("PLAYER_REGEN_ENABLED")

			self:ExperienceBar_Update(event)
			self:ExperienceBar_QuestXPToggle(event)
		elseif event == "DISABLE_XP_GAIN" then
			self.expDisabled = true

			this:UnregisterEvent("PLAYER_LEVEL_UP")
			this:UnregisterEvent("PLAYER_XP_UPDATE")
			this:UnregisterEvent("UPDATE_EXHAUSTION")
			this:UnregisterEvent("PLAYER_REGEN_DISABLED")
			this:UnregisterEvent("PLAYER_REGEN_ENABLED")

			self:ExperienceBar_Update(event)
			self:ExperienceBar_QuestXPToggle(event)
		elseif event == "QUEST_LOG_UPDATE"
		or event == "ZONE_CHANGED_NEW_AREA"
		then
			self:ExperienceBar_QuestXPUpdate(event)
		elseif event == "PLAYER_ENTERING_WORLD" then
			this:UnregisterEvent(event)
			self:ExperienceBar_QuestXPUpdate(event)
		end
	end)

	self:ExperienceBar_UpdateDimensions()

	E:CreateMover(self.expBar, "ExperienceBarMover", L["Experience Bar"], nil, nil, nil, nil, nil, "databars,experience")
	self:ExperienceBar_Toggle()
	
	-- Check weekend status when the addon loads
	self:CheckWeekendStatusOnLoad()
end