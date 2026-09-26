-- ElvUI_QuestTracker - Plugin.lua
-- Ported from QuestGuru_Tracker.lua by MrOBrian
local E, L, V, P, G = unpack(ElvUI_)
local QGT = E:GetModule("ElvUI_QuestTracker")

-- Ensure QGT_Settings exists as an empty table at file-load time so the
-- frame-creation block below (which reads QGT_Settings.Alpha) doesn't error.
if QGT_Settings == nil then QGT_Settings = {} end

QGT_PlayerAlive = false
QGT_VariablesLoaded = false
QGT_ShowTracker = true
QGT_PlayerInCombat = false

BINDING_HEADER_QGT_HEADER = "Quest Tracker"
BINDING_NAME_QGT_TOGGLE_TRACKER_KB = "Toggle Quest Tracker"

QG_TRACKER_Q           = L["Q"]
QG_TRACKER_A           = L["A"]
QG_TRACKER_QUESTS      = L["Quests"]
QG_TRACKER_ACHIEVE     = L["Achievements"]
QG_TRACKER_SHOW        = L["Show Tracker"]
QG_TRACKER_MINIMIZE    = L["Minimize Tracker"]
QG_TRACKER_OPTIONS     = L["Tracker Options"]
QG_TRACKER_TOGGLE      = L["Click to switch between Quest and Achievement tracking. Right-click to toggle showing both windows"]

QG_UNKNOWN             = L["Unknown"]
QG_NONE                = L["None"]
QG_TRACK               = L["Track"]
QG_UNTRACK             = L["Untrack"]
QG_SHARE_QUEST         = L["Share Quest"]
QG_ABANDON_QUEST       = L["Abandon Quest"]
QG_DELETE_QUEST        = L["Delete Quest"]
QG_OPTIONS             = L["Options"]
QG_SEARCH              = L["Search: "]
QG_CLEAR_ABANDON       = L["Clear Abandoned List"]
QG_COMPLETE            = L["Completed"]
QG_ABANDONED           = L["Abandoned"]
QG_INCOMPLETE          = L["Incomplete"]
QG_ACTIVE              = L["Active"]
QG_ALT_STATUS_HEAD     = L["Alt Status Header"]
QG_GUILD_STATUS_HEAD   = L["Guild Status Header"]
QG_EXPAND_HEADERS      = L["Expand/Collapse All Headers"]

QG_ITEM_REQ_STR  = "(.*):%s*([%d]+)%s*/%s*([%d]+)"
QG_ITEM_REQ_STR2 = "(.*):%s*%(([%d]+)%)"
QG_DATETIME      = "%m/%d/%Y %H:%M:%S"

local lastColorPick

-- ============================================================
--  DEFAULTS
-- ============================================================
local defaultSettings = {
    QuestWatch = {},
    AchievementWatch = {},
    ShowBorder = true,
    Scale = 0.9,
    Lines = 30,
    Alpha = 0.7,
    ShowHeaders = true,
    QuestItemIcons = true,
    ShowLevels = true,
    Pin = false,
    HideDuringCombat = false,
    AutoUnTrack = false,
    ShowCompletedObj = true,
    ColorizeObj = false,
    ColorizeObjZero = {r = 0.8, g = 0.2, b = 0.8},
    ColorizeObjFull = {r = 0.3, g = 0.8, b = 1.0},
    ColorizeObjComplete = {r = 0.1, g = 0.9, b = 1.0},
    ClickThrough = false,
    ShowQuestTooltips = true,
    ShowPartyTooltips = true,
    ShowQuestPercent = true,
    Bullet = "-",
    Anchor = "TOP",
    LastTracker = "Q",
    BothTrackers = false,
}

-- ============================================================
--  BORDER HELPERS
-- ============================================================
function QGT_SetQuestWatchBorder(enabled)
	if (enabled) then
		QGT_QuestWatchFrame:SetBackdrop({
			bgFile="Interface\\Characterframe\\UI-Party-Background",
			edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
			tile=1, tileSize=16, edgeSize=16,
			insets={left=4, right=4, top=4, bottom=4}
		});
	else
		QGT_QuestWatchFrame:SetBackdrop({
			bgFile="Interface\\Characterframe\\UI-Party-Background",
			tile=1, tileSize=16,
			insets={left=4, right=4, top=4, bottom=4}
		});
	end
	QGT_QuestWatchFrame:SetBackdropColor(0,0,0,QGT_Settings.Alpha);
end

-- ============================================================
--  FRAME CREATION
--  (from original QuestGuru_Tracker.lua; unchanged except
--   options-panel block removed)
-- ============================================================
do
	local temp, i;

	QGT_QuestWatchFrame = CreateFrame("FRAME", "QGT_QuestWatchFrame", UIParent);
	QGT_QuestWatchFrame:Hide();
	QGT_QuestWatchFrame:EnableMouse(1);
	QGT_QuestWatchFrame:EnableMouseWheel(1);
	QGT_QuestWatchFrame:SetMovable(1);
	QGT_QuestWatchFrame:SetResizable(0);
	QGT_QuestWatchFrame:SetToplevel(1);
	QGT_QuestWatchFrame:SetFrameStrata("LOW");
	QGT_QuestWatchFrame:SetClampedToScreen(true);
	QGT_QuestWatchFrame:SetWidth(256);
	QGT_QuestWatchFrame:SetHeight(20);
	QGT_QuestWatchFrame:SetPoint("TOPRIGHT", MinimapCluster, "BOTTOMRIGHT", 0, 10);
	QGT_QuestWatchFrame:SetHitRectInsets(-16, 0, 0, 0);
	QGT_SetQuestWatchBorder(true);

	QGT_QuestWatchFrame:RegisterForDrag("LeftButton");
	QGT_QuestWatchFrame:SetScript("OnDragStart",
		function ()
			QGT_DragStart();
		end);
 	QGT_QuestWatchFrame:SetScript("OnDragStop",
	 	function ()
		 	QGT_DragStop();
		end);
	QGT_QuestWatchFrame:SetScript("OnEnter",
		function ()
			QGT_QuestWatchFrameSlider:SetScript("OnMouseUp", nil);
			QGT_ShowQuestTrackerSlider(true);
		end);
	QGT_QuestWatchFrame:SetScript("OnLeave",
		function ()
			QGT_ShowQuestTrackerSlider(false);
		end);
	QGT_QuestWatchFrame:SetScript("OnMouseWheel",
		function ()
			local min, max = QGT_QuestWatchFrameSlider:GetMinMaxValues();
			local currVal = QGT_QuestWatchFrameSlider:GetValue();

			currVal = currVal - arg1;
			if (currVal < min) then currVal = min; end
			if (currVal > max) then currVal = max; end
			QGT_QuestWatchFrameSlider:SetValue(currVal);
		end);
	QGT_QuestWatchFrame:SetScript("OnShow",
		function ()
			QGT_ShowQuestTrackerSlider(false);
		end);
	QGT_QuestWatchFrame:RegisterEvent("QUEST_WATCH_UPDATE");
	QGT_QuestWatchFrame:RegisterEvent("VARIABLES_LOADED");
	QGT_QuestWatchFrame:RegisterEvent("UI_INFO_MESSAGE");
	QGT_QuestWatchFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
	QGT_QuestWatchFrame:RegisterEvent("PLAYER_REGEN_DISABLED");
	QGT_QuestWatchFrame:RegisterEvent("PLAYER_REGEN_ENABLED");
	QGT_QuestWatchFrame:SetScript("OnEvent",
		function (self, event, arg1, arg2, arg3, arg4)
			if (event == "QUEST_WATCH_UPDATE") then
				QGT_AddTimer(2, 1, CheckRemoveQuestWatch, arg1);
			elseif (event == "VARIABLES_LOADED") then
				QGT_VariablesLoaded = true;
				QGT_QuestWatchLoadSettings();
			elseif (event == "UI_INFO_MESSAGE") then
				QGT_UIInfoMessage(arg1);
			elseif (event == "PLAYER_ENTERING_WORLD") then
				QGT_PlayerAlive = true;
				if (GetBindingKey("QGT_TOGGLE_TRACKER_KB") == nil) then
					SetBinding("SHIFT-L", "QGT_TOGGLE_TRACKER_KB");
					SaveBindings(2);
				end
				QGT_QuestWatchFrame:UnregisterEvent("PLAYER_ENTERING_WORLD");
			elseif (event == "PLAYER_REGEN_ENABLED") then
				QGT_PlayerInCombat = false;
				WatchFrame_Update();
			elseif (event == "PLAYER_REGEN_DISABLED") then
				QGT_PlayerInCombat = true;
				WatchFrame_Update();
			end
		end);
	QGT_QuestWatchFrame:SetScript("OnUpdate",
		function ()
			QGT_OnUpdate(arg1);
		end);

	temp = QGT_QuestWatchFrame:CreateTexture("QGT_QuestWatchFrameBackground", "ARTWORK");
	temp:SetHeight(18);
	temp:SetPoint("TOPRIGHT", -4, -4);
	temp:SetPoint("TOPLEFT", 4, -4);
	temp:SetTexture(1, 1, 1);
	temp:SetGradientAlpha("VERTICAL", 0, 0, 0, 0, 0.3, 0.3, 0.3, 1);

	temp = QGT_QuestWatchFrame:CreateFontString("QGT_QuestWatchQuestName", "ARTWORK", "GameFontNormal");
	temp:SetPoint("TOPLEFT", 8, -6);
	temp:SetJustifyH("LEFT");
	temp:SetWidth(0);
	temp:SetHeight(12);
	temp:SetText(""..QG_TRACKER_QUESTS);

	temp = QGT_QuestWatchFrame:CreateFontString("QGT_QuestWatchNumQuests", "ARTWORK", "GameFontNormal");
	temp:SetPoint("LEFT", QGT_QuestWatchQuestName, "RIGHT", 12, 0);
	temp:SetJustifyH("CENTER");
	temp:SetWidth(0);
	temp:SetHeight(12);
	temp:SetText("0/"..MAX_QUESTS);

	QGT_QuestWatchFrameOptions = CreateFrame("BUTTON", "QGT_QuestWatchFrameOptions", QGT_QuestWatchFrame, "QGT_QuestWatchMiniButtonTemplate");
	QGT_QuestWatchFrameOptions:SetText("O");
	QGT_QuestWatchFrameOptions:SetPoint("TOPRIGHT", -5, -4);
	QGT_QuestWatchFrameOptions:SetScript("OnClick",
		function ()
			E:ToggleOptionsUI("ElvUI_QuestTracker");
		end);
	QGT_QuestWatchFrameOptions:SetScript("OnEnter",
		function (self)
			QGT_QuestWatchFrameSlider:SetScript("OnMouseUp", nil);
			QGT_ShowQuestTrackerSlider(true);
			GameTooltip:SetOwner(self, "ANCHOR_LEFT");
			GameTooltip:SetText(QG_TRACKER_OPTIONS, nil,nil, nil, nil, 1);
		end);
	QGT_QuestWatchFrameOptions:SetScript("OnLeave",
		function ()
			QGT_ShowQuestTrackerSlider(false);
			GameTooltip:Hide();
		end);

	QGT_QuestWatchFrameMinimize = CreateFrame("BUTTON", "QGT_QuestWatchFrameMinimize", QGT_QuestWatchFrame, "QGT_QuestWatchMiniButtonTemplate");
	QGT_QuestWatchFrameMinimize:SetText("-");
	QGT_QuestWatchFrameMinimize:SetPoint("RIGHT", QGT_QuestWatchFrameOptions, "LEFT", 0, 0);
	QGT_QuestWatchFrameMinimize:RegisterForClicks("LeftButtonUp", "RightButtonUp");
	QGT_QuestWatchFrameMinimize:SetScript("OnClick",
		function (self, button, down)
			if (button == "LeftButton") then
				if (QGT_Settings.QuestWatch.AutoMinimize) then
					QGT_ShowQuestTrackerSlider(false);
					QGT_Settings.QuestWatch.Minimized = true;
				else
					QGT_ShowQuestTrackerSlider(QGT_Settings.QuestWatch.Minimized);
					QGT_Settings.QuestWatch.Minimized = not QGT_Settings.QuestWatch.Minimized;
				end
				QGT_Settings.QuestWatch.AutoMinimize = false;
				WatchFrame_Update();
				GameTooltip:Hide();
			elseif (button == "RightButton") then
				QGT_Settings.QuestWatch.AutoMinimize = not QGT_Settings.QuestWatch.AutoMinimize;
				WatchFrame_Update();
			end
		end);
	QGT_QuestWatchFrameMinimize:SetScript("OnEnter",
		function (self)
			QGT_QuestWatchFrameSlider:SetScript("OnMouseUp", nil);
			QGT_ShowQuestTrackerSlider(true);
			GameTooltip:SetOwner(self, "ANCHOR_LEFT");
			if (QGT_Settings.QuestWatch.Minimized) then
				GameTooltip:SetText(QG_TRACKER_SHOW, nil,nil, nil, nil, 1);
			else
				GameTooltip:SetText(QG_TRACKER_MINIMIZE, nil,nil, nil, nil, 1);
			end
		end);
	QGT_QuestWatchFrameMinimize:SetScript("OnLeave",
		function ()
			QGT_ShowQuestTrackerSlider(false);
			GameTooltip:Hide();
		end);

	QGT_QuestWatchFrameToggle = CreateFrame("BUTTON", "QGT_QuestWatchFrameToggle", QGT_QuestWatchFrame, "QGT_QuestWatchMiniButtonTemplate");
	QGT_QuestWatchFrameToggle:SetText(QG_TRACKER_A);
	QGT_QuestWatchFrameToggle:SetPoint("RIGHT", QGT_QuestWatchFrameMinimize, "LEFT", 0, 0);
	QGT_QuestWatchFrameToggle:RegisterForClicks("LeftButtonUp", "RightButtonUp");
	QGT_QuestWatchFrameToggle:SetScript("OnClick",
		function (self, button, down)
			if (button == "LeftButton") then
				QGT_Settings.LastTracker = "A";
				QGT_Settings.BothTrackers = false;
				QGT_Settings.AchievementWatch.Top = QGT_Settings.QuestWatch.Top;
				QGT_Settings.AchievementWatch.Bottom = QGT_Settings.QuestWatch.Bottom;
				QGT_Settings.AchievementWatch.Left = QGT_Settings.QuestWatch.Left;
				QGT_Settings.AchievementWatch.Minimized = QGT_Settings.QuestWatch.Minimized;
				QGT_Settings.AchievementWatch.AutoMinimize = QGT_Settings.QuestWatch.AutoMinimize;
				WatchFrame_Update();
				GameTooltip:Hide();
			elseif (button == "RightButton") then
				QGT_Settings.LastTracker = "Q";
				QGT_Settings.BothTrackers = not QGT_Settings.BothTrackers;
				WatchFrame_Update();
			end
		end);
	QGT_QuestWatchFrameToggle:SetScript("OnEnter",
		function (self)
			QGT_QuestWatchFrameSlider:SetScript("OnMouseUp", nil);
			QGT_ShowQuestTrackerSlider(true);
			GameTooltip:SetOwner(self, "ANCHOR_LEFT");
			GameTooltip:SetText(QG_TRACKER_TOGGLE, nil,nil, nil, nil, 1);
		end);
	QGT_QuestWatchFrameToggle:SetScript("OnLeave",
		function ()
			QGT_ShowQuestTrackerSlider(false);
			GameTooltip:Hide();
		end);

	QGT_QuestWatchFrameSlider = CreateFrame("Slider", "QGT_QuestWatchFrameSlider", QGT_QuestWatchFrame, "OptionsSliderTemplate");
	QGT_QuestWatchFrameSlider:SetWidth(16);
	QGT_QuestWatchFrameSlider:SetHeight(200);
	QGT_QuestWatchFrameSliderText:SetText("");
	QGT_QuestWatchFrameSliderHigh:SetText("");
	QGT_QuestWatchFrameSliderLow:SetText("");
	QGT_QuestWatchFrameSlider:SetOrientation("VERTICAL");
	QGT_QuestWatchFrameSlider:SetPoint("TOPLEFT", QGT_QuestWatchFrame, "TOPLEFT", -14, -2);
	QGT_QuestWatchFrameSlider:SetMinMaxValues(0,0);
	QGT_QuestWatchFrameSlider:SetValueStep(1);
	QGT_QuestWatchFrameSlider:SetValue(0);
	QGT_QuestWatchFrameSlider:Hide();
	QGT_QuestWatchFrameSlider:SetAlpha(0);
	QGT_QuestWatchFrameSlider:SetScript("OnEnter",
		function ()
			QGT_ShowQuestTrackerSlider(true);
		end);
	QGT_QuestWatchFrameSlider:SetScript("OnLeave",
		function ()
			QGT_ShowQuestTrackerSlider(false);
		end);
	QGT_QuestWatchFrameSlider:SetScript("OnValueChanged",
		function ()
			WatchFrame_Update();
		end);

	for i=1, 40 do
		temp = CreateFrame("Button", "QGT_QuestWatchLine"..i, QGT_QuestWatchFrame, "QGT_QuestWatchButtonTemplate");
		temp:SetPoint("TOPLEFT", QGT_QuestWatchFrame, 8, -20);
		temp:SetHeight(13);
		temp:RegisterForClicks("LeftButtonUp", "RightButtonUp");
	end

	QGT_QuestWatchFrameTooltip = CreateFrame("GameTooltip", "QGT_QuestWatchFrameTooltip", QGT_QuestWatchFrame, "GameTooltipTemplate");
	QGT_QuestWatchFrameTooltip:Hide();
	QGT_QuestWatchFrameTooltip:SetFrameStrata("TOOLTIP");
end

-- ============================================================
--  TRACKER DRAG / SLIDER HELPERS
-- ============================================================
function CheckRemoveQuestWatch(arg1)
	if (QGT_IsQuestComplete(arg1) and QGT_Settings.AutoUnTrack) then
		RemoveQuestWatch(arg1);
	end
end

function QGT_DragStart()
	if (not QGT_Settings.Pin) then
		QGT_QuestWatchFrame:StartMoving();
		QGT_QuestWatchFrame.isMoving = true;
	end
end

function QGT_DragStop()
	QGT_QuestWatchFrame:StopMovingOrSizing();
	QGT_QuestWatchFrame.isMoving = false;
	QGT_Settings.QuestWatch.Left = QGT_QuestWatchFrame:GetLeft();
	QGT_Settings.QuestWatch.Top = QGT_QuestWatchFrame:GetTop();
	QGT_Settings.QuestWatch.Bottom = QGT_QuestWatchFrame:GetBottom();
	QGT_QuestWatchFrameSlider:ClearAllPoints();
	if (((QGT_Settings.QuestWatch.Left + 256) * QGT_Settings.Scale) > (UIParent:GetWidth() - 16)) then
		QGT_QuestWatchFrameSlider:SetPoint("TOPLEFT", -14, -16);
	else
		QGT_QuestWatchFrameSlider:SetPoint("TOPRIGHT", 14, -16);
	end
end

function QGT_IsQuestComplete(index)
	local questLogTitleText, level, questTag, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily = GetQuestLogTitle(index);
	local numObjectives = GetNumQuestLeaderBoards(index);

	return (isComplete or (numObjectives == 0));
end

function QGT_QuestWatchTitleMenu_OnLoad()
	local info = UIDropDownMenu_CreateInfo();
	info.func = QGT_QuestWatchTitleMenu_OnClick;
	info.arg1 = this:GetID();
	if (this.qID) then info.arg1 = this.qID; end
	info.checked = nil;
	info.icon = nil;

	local questLogTitleText, level, questTag, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily = GetQuestLogTitle(info.arg1);
	if (questLogTitleText == nil) then return; end
	if (IsQuestWatched(info.arg1)) then
	    info.text = QG_UNTRACK.." "..questLogTitleText;
	    info.value = "untrack";
	    UIDropDownMenu_AddButton(info, 1);
	else
	    info.text = QG_TRACK.." "..questLogTitleText;
	    info.value = "track";
	    UIDropDownMenu_AddButton(info, 1);
	end

	if (not this.isHeader) then
		if (GetQuestLogPushable() and ( GetRealNumPartyMembers() > 0 or GetRealNumRaidMembers() > 0) ) then
			info.disabled = nil;
		else
			info.disabled = 1;
		end
		info.text = QG_SHARE_QUEST;
		info.value = "share";
		UIDropDownMenu_AddButton(info, 1);
		info.disabled = nil;

		info.text = QG_ABANDON_QUEST;
		info.value = "abandon";
		UIDropDownMenu_AddButton(info, 1);
	end

	info.text = "--------------------";
	info.value = "-";
	info.isTitle = 1;
	UIDropDownMenu_AddButton(info, 1);

	info = UIDropDownMenu_CreateInfo();
	info.func = QGT_QuestWatchTitleMenu_OnClick;
	info.checked = nil;
	info.icon = nil;
	info.text = CANCEL;
	info.value = "cancel";
	UIDropDownMenu_AddButton(info, 1);
end

function QGT_QuestWatchTitleMenu_OnClick()
	if (this.value == "abandon") then
		if (IsAddOnLoaded("QuestGuru")) then
			QuestGuru_AbandonQuest();
		else
			AbandonQuest();
		end
	elseif (this.value == "share") then
		QuestLogPushQuest();
	elseif (this.value == "track") then
		AddQuestWatch(this.arg1);
		QuestLog_Update();
	elseif (this.value == "untrack") then
		RemoveQuestWatch(this.arg1);
		QuestLog_Update();
	end
end

function QGT_ShowQuestTrackerSlider(flag)
	UIFrameFadeRemoveFrame(QGT_QuestWatchFrameSlider);
	local currAlpha = QGT_QuestWatchFrameSlider:GetAlpha();
	if (QGT_Settings and QGT_Settings.QuestWatch and (QGT_Settings.QuestWatch.AutoMinimize==true) and not IsMouseButtonDown("LeftButton")) then
		QGT_Settings.QuestWatch.Minimized = not flag;
	end

	local watchLines = 30;
	if (QGT_Settings and QGT_Settings.Lines) then
		watchLines = QGT_Settings.Lines;
	end
	if ((flag == true) and (QGT_WatchLines > watchLines) and not QGT_Settings.QuestWatch.Minimized) then
		if (currAlpha < 1) then
			local fadeInfo = {};
			fadeInfo.mode = "IN";
			fadeInfo.timeToFade = 0.1 * (1 - currAlpha);
			fadeInfo.startAlpha = currAlpha;
			fadeInfo.endAlpha = 1;
			fadeInfo.finishedFunc = function ()
					WatchFrame_Update();
				end;
			UIFrameFade(QGT_QuestWatchFrameSlider, fadeInfo);
		end
	else
		if (IsMouseButtonDown("LeftButton")) then
			this:SetScript("OnMouseUp",
				function ()
					QGT_ShowQuestTrackerSlider(false);
					this:SetScript("OnMouseUp", nil);
				end);
		else
			local fadeInfo = {};
			fadeInfo.mode = "OUT";
			fadeInfo.timeToFade = 0.1 * currAlpha;
			fadeInfo.startAlpha = currAlpha;
			fadeInfo.endAlpha = 0;
			fadeInfo.finishedFunc = function ()
					QGT_QuestWatchFrameSlider:Hide();
					WatchFrame_Update();
				end;
			UIFrameFade(QGT_QuestWatchFrameSlider, fadeInfo);
		end
	end
end

function QGT_SetQuestTrackerMouse(enableFlag)
	QGT_QuestWatchFrame:EnableMouse(enableFlag);
	for i=1, 40 do
		getglobal("QGT_QuestWatchLine"..i):EnableMouse(enableFlag);
	end
end

function QGT_QuestWatchButton_OnEnter(self, motion)
	local qID = self.qID;
	local minWidth = 224;

	self.fading = 0;
	self:SetScript("OnUpdate", nil);
	getglobal(self:GetName().."Highlight"):SetAlpha(0.5);
	getglobal(self:GetName().."Highlight"):Show();
	if (qID == nil) then -- header
		return;
	elseif (tonumber(qID) == nil) then -- objective line
		local objName = string.sub(self:GetText(),3+strlen(QGT_Settings.Bullet));
		local objText = "";
		if (qID == "item") then
			local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture = GetItemInfo(objName);
			if ((not itemLink) and IsAddOnLoaded("QuestGuru") and QuestGuru_Items and QuestGuru_Items[QuestGuru_RealmName] and QuestGuru_Items[QuestGuru_RealmName][objName]) then
				itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture = GetItemInfo(QuestGuru_Items[QuestGuru_RealmName][objName]);
			end
			if (itemLink and QGT_Settings.ShowQuestTooltips) then
				GameTooltip:SetOwner(self);
				GameTooltip:SetHyperlink(itemLink);
				GameTooltip:Show();
				local tW = GameTooltip:GetWidth();
				if (QGT_Settings.QuestWatch.Left < tW) then
					GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
					GameTooltip:SetHyperlink(itemLink);
					GameTooltip:Show();
				else
					GameTooltip:SetOwner(self, "ANCHOR_LEFT");
					GameTooltip:SetHyperlink(itemLink);
					GameTooltip:Show();
				end
			end
		end
	else -- quest line
	    if (QGT_Settings.ShowQuestTooltips) then
			QGT_QuestWatchFrameTooltip:SetOwner(self);
			local qLink = GetQuestLink(qID);
			if (qLink) then QGT_QuestWatchFrameTooltip:SetHyperlink(qLink); end
			QGT_QuestWatchFrameTooltip:Show();
			local tW = QGT_QuestWatchFrameTooltip:GetWidth();
			if (QGT_Settings.QuestWatch.Left < tW) then
				QGT_QuestWatchFrameTooltip:SetOwner(self, "ANCHOR_RIGHT");
				if (qLink) then QGT_QuestWatchFrameTooltip:SetHyperlink(qLink); end
				QGT_QuestWatchFrameTooltip:Show();
			else
				QGT_QuestWatchFrameTooltip:SetOwner(self, "ANCHOR_LEFT");
				if (qLink) then QGT_QuestWatchFrameTooltip:SetHyperlink(qLink); end
				QGT_QuestWatchFrameTooltip:Show();
			end
		end
		if (QGT_Settings.ShowPartyTooltips) then QGT_UpdatePartyInfoTooltip(self); end
	end
end

function QGT_UpdatePartyInfoTooltip(self)
	if (IsAddOnLoaded("QuestGuru")) then
		QuestLog_UpdatePartyInfoTooltip(self);
		return;
	end
	local numPartyMembers = GetNumPartyMembers();
	if ( numPartyMembers == 0 or self.isHeader ) then
		return;
	end
	GameTooltip_SetDefaultAnchor(GameTooltip, self);

	local questLogTitleText = GetQuestLogTitle(self.qID);
	GameTooltip:SetText(questLogTitleText);

	local partyMemberOnQuest;
	for i=1, numPartyMembers do
		if ( IsUnitOnQuest(self.qID, "party"..i) ) then
			if ( not partyMemberOnQuest ) then
				GameTooltip:AddLine(HIGHLIGHT_FONT_COLOR_CODE..PARTY_QUEST_STATUS_ON..FONT_COLOR_CODE_CLOSE);
				partyMemberOnQuest = 1;
			end
			GameTooltip:AddLine(LIGHTYELLOW_FONT_COLOR_CODE..UnitName("party"..i)..FONT_COLOR_CODE_CLOSE);
		end
	end
	if ( not partyMemberOnQuest ) then
		GameTooltip:AddLine(HIGHLIGHT_FONT_COLOR_CODE..PARTY_QUEST_STATUS_NONE..FONT_COLOR_CODE_CLOSE);
	end
	GameTooltip:Show();
end

function QGT_QuestWatchButton_OnLeave(self, motion)
	getglobal(self:GetName().."Highlight"):Hide();
	QGT_ShowQuestTrackerSlider(false);
	QGT_QuestWatchFrameTooltip:Hide();
	GameTooltip:Hide();
end

function QGT_QuestWatchButton_OnUpdate(self, elapsed)
	local hilight = getglobal(self:GetName().."Highlight");

	if (self.fading == 1) then
	    local a = hilight:GetAlpha();
	    a = a - elapsed;
	    if (a <= 0) then
			a = 0;
			self.fading = 0;
			self:SetScript("OnUpdate", nil);
		end
		hilight:SetAlpha(a);
	end
end

function QGT_QuestWatchButton_OnClick(self, button, down)
	local qID = self.qID;

	if (button == "LeftButton") then
		if ( IsShiftKeyDown() ) then
			local activeWindow = ChatEdit_GetActiveWindow();
			if (qID == nil) then -- header line
				if (activeWindow) then
					activeWindow:Insert(self:GetText());
				end
			elseif (tonumber(qID) == nil) then -- objective line
				local objName = string.sub(self:GetText(), 3 + strlen(QGT_Settings.Bullet));
				local objText = "";
				if (qID == "item") then
					local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture = GetItemInfo(objName);
					if (itemLink == nil) then
						objText = objName;
					else
						objText = itemLink;
					end
				else
					objText = objName;
				end
				if (activeWindow) then
					activeWindow:Insert(objText);
				end
			else -- quest number
				if (activeWindow) then
					activeWindow:Insert(GetQuestLink(qID));
				end
			end
		else
			if (qID == nil) then -- header line
				local headName = self:GetText();
				if (QGT_WatchHeaders[headName] ~= false) then
					QGT_WatchHeaders[headName] = false;
				else
					QGT_WatchHeaders[headName] = true;
				end
				WatchFrame_Update();
			elseif (tonumber(qID) == nil) then -- objective line
				local objName = string.sub(self:GetText(), 3 + strlen(QGT_Settings.Bullet));
				if (qID == "item") then
					local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture = GetItemInfo(objName);
					if (itemLink ~= nil) then
						SetItemRef(itemLink, nil, button);
					end
				end
			else -- title line
				QuestLog_OpenToQuest(qID);
				QuestLogFrame:Show();
			end
		end
	elseif (button == "RightButton") then
	    if (IsShiftKeyDown()) then
	        if (qID and (tonumber(qID) ~= nil)) then
				QuestLog_SetSelection(qID, button);
				QuestLog_Update();
				ToggleDropDownMenu(1, nil, QGT_QuestWatchTitleMenu, self:GetName(), 0, 0);
			end
	    else
			if (qID == nil) then -- header line
				local headName = self:GetText();
				if (QGT_WatchHeaders[headName] ~= false) then
					QGT_WatchHeaders[headName] = false;
				else
					QGT_WatchHeaders[headName] = true;
				end
				WatchFrame_Update();
			elseif (tonumber(qID) ~= nil) then -- title line
			    -- expand/collapse quests
				local qName = GetQuestLogTitle(qID);

				if (QGT_WatchQuests[qName] ~= false) then
					QGT_WatchQuests[qName] = false;
				else
					QGT_WatchQuests[qName] = true;
				end
				WatchFrame_Update();
			end
		end
	end
	QGT_ShowQuestTrackerSlider(true);
end

function WatchFrameItem_OnEnter (self)
	GameTooltip_SetDefaultAnchor(GameTooltip, self);
	GameTooltip:SetQuestLogSpecialItem(self:GetID());
	QGT_ShowQuestTrackerSlider(true);
end

function WatchFrameItem_OnLeave(self)
	GameTooltip:Hide();
	QGT_ShowQuestTrackerSlider(false);
end

function QGT_UpdateQuestTimers(...)
	local numTimers = select("#", ...);

	QGT_QuestTimer = {};
	if ( numTimers == 0 ) then
		return;
	end

	for i = 1, numTimers do
		QGT_QuestTimer[GetQuestIndexForTimer(i)] = select(i, ...);
	end
end

-- ============================================================
--  OPTIONS COLOR SAVE
-- ============================================================
function QGT_OptionsSaveColor()
	local r, g, b = ColorPickerFrame:GetColorRGB()

	if (lastColorPick == "TrackerZero") then
		QGT_Settings.ColorizeObjZero.r = r
		QGT_Settings.ColorizeObjZero.g = g
		QGT_Settings.ColorizeObjZero.b = b
		WatchFrame_Update()
	elseif (lastColorPick == "TrackerFull") then
		QGT_Settings.ColorizeObjFull.r = r
		QGT_Settings.ColorizeObjFull.g = g
		QGT_Settings.ColorizeObjFull.b = b
		WatchFrame_Update()
	elseif (lastColorPick == "TrackerComplete") then
		QGT_Settings.ColorizeObjComplete.r = r
		QGT_Settings.ColorizeObjComplete.g = g
		QGT_Settings.ColorizeObjComplete.b = b
		WatchFrame_Update()
	end
end

-- Kept as a no-op stub for compatibility (was used to refresh the options gradient)
function QGT_UpdateOptionsTrackerObjFade()
	-- nothing to do; ElvUI_ options panel updates itself
end

-- ============================================================
--  DEFAULTS / RESET
-- ============================================================
function QGT_SetTrackerDefaults()
	QGT_Settings.ShowBorder = true
	QGT_SetQuestWatchBorder(QGT_Settings.ShowBorder)
	QGT_SetAchievementWatchBorder(QGT_Settings.ShowBorder)

	QGT_Settings.Scale = 0.9
	QGT_QuestWatchFrame:SetScale(QGT_Settings.Scale)
	QGT_AchievementWatchFrame:SetScale(QGT_Settings.Scale)

	QGT_Settings.Lines = 30

	QGT_Settings.QuestWatch.Minimized = false
	QGT_Settings.AchievementWatch.Minimized = false

	QGT_Settings.Alpha = 0.7
	QGT_QuestWatchFrame:SetBackdropColor(0, 0, 0, QGT_Settings.Alpha)
	QGT_QuestWatchFrameBackground:SetGradientAlpha("VERTICAL", 0, 0, 0, 0, 0.3, 0.3, 0.3, QGT_Settings.Alpha)
	QGT_AchievementWatchFrame:SetBackdropColor(0, 0, 0, QGT_Settings.Alpha)
	QGT_AchievementWatchFrameBackground:SetGradientAlpha("VERTICAL", 0, 0, 0, 0, 0.3, 0.3, 0.3, QGT_Settings.Alpha)

	QGT_Settings.ShowHeaders = true
	QGT_Settings.QuestItemIcons = true
	QGT_Settings.ShowLevels = true
	QGT_Settings.Pin = false
	QGT_Settings.HideDuringCombat = false
	QGT_Settings.AutoUnTrack = false
	QGT_Settings.ShowCompletedObj = true
	QGT_Settings.ColorizeObj = false
	QGT_Settings.ColorizeObjZero.r = 0.8
	QGT_Settings.ColorizeObjZero.g = 0.2
	QGT_Settings.ColorizeObjZero.b = 0.8
	QGT_Settings.ColorizeObjFull.r = 0.3
	QGT_Settings.ColorizeObjFull.g = 0.8
	QGT_Settings.ColorizeObjFull.b = 1.0
	QGT_Settings.ColorizeObjComplete.r = 0.1
	QGT_Settings.ColorizeObjComplete.g = 0.9
	QGT_Settings.ColorizeObjComplete.b = 1.0

	QGT_Settings.ClickThrough = false
	QGT_Settings.ShowQuestTooltips = true
	QGT_Settings.ShowPartyTooltips = true
	QGT_Settings.ShowQuestPercent = true

	QGT_Settings.Bullet = "-"
	QGT_Settings.Anchor = "TOP"

	WatchFrame_Update()
end

-- ============================================================
--  WATCHFRAME UPDATE
-- ============================================================
local old_WatchFrame_Update = WatchFrame_Update
function WatchFrame_Update()
	WatchFrame:Hide()

	if (not (QGT_PlayerAlive and QGT_VariablesLoaded)) then return end
	
	 if not QGT_Settings.enabled then
        QGT_QuestWatchFrame:Hide()
        QGT_AchievementWatchFrame:Hide()
        return
    end

	if ((not QGT_ShowTracker) or (QGT_PlayerInCombat and QGT_Settings.HideDuringCombat)) then
		QGT_QuestWatchFrame:Hide()
		QGT_AchievementWatchFrame:Hide()
		return
	end

	if ((QGT_Settings.LastTracker == "Q") or QGT_Settings.BothTrackers) then
		QGT_QuestWatch_Update()
	else
		QGT_QuestWatchFrame:Hide()
	end
	if ((QGT_Settings.LastTracker == "A") or QGT_Settings.BothTrackers) then
		QGT_AchievementWatch_Update()
	else
		QGT_AchievementWatchFrame:Hide()
	end
end

function WatchFrame_GetRemainingSpace()
	return 1000
end

-- ============================================================
--  LOAD SETTINGS FROM ElvUI_ DB
-- ============================================================
function QGT_QuestWatchLoadSettings()
	if (QGT_WatchHeaders == nil) then QGT_WatchHeaders = {} end
	if (QGT_WatchQuests == nil) then QGT_WatchQuests = {} end
	if (QGT_WatchAchievements == nil) then QGT_WatchAchievements = {} end

	if (QGT_Settings == nil) then QGT_Settings = {} end
	if (QGT_Settings.QuestWatch == nil) then QGT_Settings.QuestWatch = {} end
	if (QGT_Settings.AchievementWatch == nil) then QGT_Settings.AchievementWatch = {} end

	if (QGT_Settings.ShowBorder ~= false) then
		QGT_Settings.ShowBorder = true
	end
	QGT_SetQuestWatchBorder(QGT_Settings.ShowBorder)
	QGT_SetAchievementWatchBorder(QGT_Settings.ShowBorder)

	if (QGT_Settings.Scale == nil) then
		QGT_Settings.Scale = 0.9
	end
	QGT_QuestWatchFrame:SetScale(QGT_Settings.Scale)
	QGT_AchievementWatchFrame:SetScale(QGT_Settings.Scale)

	if (QGT_Settings.Lines == nil) then
		QGT_Settings.Lines = 30
	end

	if (QGT_Settings.QuestWatch.Minimized ~= true) then
		QGT_Settings.QuestWatch.Minimized = false
	end
	if (QGT_Settings.QuestWatch.AutoMinimize ~= true) then
		QGT_Settings.QuestWatch.AutoMinimize = false
	end
	if (QGT_Settings.AchievementWatch.Minimized ~= true) then
		QGT_Settings.AchievementWatch.Minimized = false
	end
	if (QGT_Settings.AchievementWatch.AutoMinimize ~= true) then
		QGT_Settings.AchievementWatch.AutoMinimize = false
	end

	if (QGT_Settings.Anchor == nil) then
		QGT_Settings.Anchor = "TOP"
	end

	if (QGT_Settings.Alpha == nil) then
		QGT_Settings.Alpha = 0.7
	end
	QGT_QuestWatchFrame:SetBackdropColor(0, 0, 0, QGT_Settings.Alpha)
	QGT_QuestWatchFrameBackground:SetGradientAlpha("VERTICAL", 0, 0, 0, 0, 0.3, 0.3, 0.3, QGT_Settings.Alpha)
	QGT_AchievementWatchFrame:SetBackdropColor(0, 0, 0, QGT_Settings.Alpha)
	QGT_AchievementWatchFrameBackground:SetGradientAlpha("VERTICAL", 0, 0, 0, 0, 0.3, 0.3, 0.3, QGT_Settings.Alpha)

	if (QGT_Settings.ShowHeaders ~= false) then
		QGT_Settings.ShowHeaders = true
	end

	if (QGT_Settings.QuestItemIcons ~= false) then
		QGT_Settings.QuestItemIcons = true
	end

	if (QGT_Settings.ShowLevels ~= false) then
		QGT_Settings.ShowLevels = true
	end

	if (QGT_Settings.Pin ~= true) then
		QGT_Settings.Pin = false
	end

	if (QGT_Settings.HideDuringCombat ~= true) then
		QGT_Settings.HideDuringCombat = false
	end

	if (QGT_Settings.AutoUnTrack ~= true) then
		QGT_Settings.AutoUnTrack = false
	end

	if (QGT_Settings.ShowCompletedObj ~= false) then
		QGT_Settings.ShowCompletedObj = true
	end

	if (QGT_Settings.ColorizeObj ~= true) then
		QGT_Settings.ColorizeObj = false
	end

	if (QGT_Settings.ColorizeObjZero == nil) then
		QGT_Settings.ColorizeObjZero = {}
		QGT_Settings.ColorizeObjZero.r = 0.8
		QGT_Settings.ColorizeObjZero.g = 0.2
		QGT_Settings.ColorizeObjZero.b = 0.8
	end
	if (QGT_Settings.ColorizeObjFull == nil) then
		QGT_Settings.ColorizeObjFull = {}
		QGT_Settings.ColorizeObjFull.r = 0.3
		QGT_Settings.ColorizeObjFull.g = 0.8
		QGT_Settings.ColorizeObjFull.b = 1.0
	end
	if (QGT_Settings.ColorizeObjComplete == nil) then
		QGT_Settings.ColorizeObjComplete = {}
		QGT_Settings.ColorizeObjComplete.r = 0.1
		QGT_Settings.ColorizeObjComplete.g = 0.9
		QGT_Settings.ColorizeObjComplete.b = 1.0
	end

	if (QGT_Settings.ClickThrough ~= true) then
		QGT_Settings.ClickThrough = false
	end

	if (QGT_Settings.ShowQuestTooltips ~= false) then
		QGT_Settings.ShowQuestTooltips = true
	end

	if (QGT_Settings.ShowPartyTooltips ~= false) then
		QGT_Settings.ShowPartyTooltips = true
	end

	if (QGT_Settings.ShowQuestPercent ~= false) then
		QGT_Settings.ShowQuestPercent = true
	end

	if (QGT_Settings.Bullet == nil) then
		QGT_Settings.Bullet = "-"
	end

	if (QGT_Settings.LastTracker ~= "A") then
		QGT_Settings.LastTracker = "Q"
	end
	if (QGT_Settings.BothTrackers ~= true) then
		QGT_Settings.BothTrackers = false
	end
end

-- ============================================================
--  FINALIZE INITIALIZATION (called from Core.lua)
-- ============================================================
function QGT:StartTracker()
	if not self.db.enabled then return end
	if self.started then return end

	QGT_Settings = self.db  -- rebind global to current DB table

	QGT_VariablesLoaded = true
	QGT_PlayerAlive = true
	QGT_QuestWatchLoadSettings()
	QGT_SetAchievements()

	WatchFrame_Update()
	self.started = true
end

function QGT:StopTracker()
	if not self.started then return end
	QGT_QuestWatchFrame:Hide()
	QGT_AchievementWatchFrame:Hide()
	self.started = false
end