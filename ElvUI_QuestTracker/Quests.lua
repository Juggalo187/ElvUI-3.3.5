-- ElvUI_QuestTracker - Quests.lua
-- Ported from QGT_Quests.lua by MrOBrian
--
-- NOTE: The frame-creation block and all button/helper functions that used to
-- live here have been moved to Plugin.lua (they must run before this file and
-- before Quests.lua's cross-references). This file now only contains the
-- quest-watching logic itself.

local E, L, V, P, G = unpack(ElvUI_)
local QGT = E:GetModule("ElvUI_QuestTracker")

-- ============================================================
--  QuestWatch: main update
-- ============================================================
function QGT_QuestWatch_Update()
	if not QGT_Settings.enabled then
        QGT_QuestWatchFrame:Hide()
        return
    end

	local numEntries, numQuests = GetNumQuestLogEntries();

	QGT_UpdateQuestTimers(GetQuestTimers());

	local questCount=0;
	local i;

	for i=1, numEntries do
		if (IsQuestWatched(i)) then questCount = questCount + 1; end
	end

	QGT_QuestWatchNumQuests:SetText(numQuests.."/"..MAX_QUESTS);

	if (QGT_Settings.QuestWatch.AutoMinimize) then
		QGT_QuestWatchFrameMinimize:SetText("*");
	else
		QGT_QuestWatchFrameMinimize:SetText("-");
	end

	local achieveCount=0;
	local i, j;

	for i, j in pairs(QGT_WatchAchievements) do
		achieveCount = achieveCount + 1;
	end

	if (achieveCount == 0) then
		QGT_QuestWatchFrameToggle:Hide();
	else
		QGT_QuestWatchFrameToggle:Show();
		if (QGT_Settings.BothTrackers) then
			QGT_QuestWatchFrameToggle:SetText("*");
		else
			QGT_QuestWatchFrameToggle:SetText(QG_TRACKER_A);
		end
	end

	if (questCount == 0 and achieveCount == 0) then
		QGT_QuestWatchFrame:Hide();
		return;
	elseif (questCount == 0 and achieveCount > 0) then
		if (QGT_Settings.BothTrackers) then
			QGT_QuestWatchFrame:Hide();
		else
			QGT_QuestWatchFrameToggle:Click();
		end
		return;
	else
		QGT_QuestWatchFrame:Show();
	end

	if (QGT_Settings.QuestWatch.Left == nil) then
		QGT_Settings.QuestWatch.Left = MinimapCluster:GetLeft();
	end
	if (QGT_Settings.QuestWatch.Top == nil) then
		QGT_Settings.QuestWatch.Top = MinimapCluster:GetBottom()+10;
	end
	if (QGT_Settings.QuestWatch.Bottom == nil) then
		QGT_Settings.QuestWatch.Bottom = 60;
	end

	if (QGT_Settings.ClickThrough) then
		QGT_SetQuestTrackerMouse(0);
	else
		QGT_SetQuestTrackerMouse(1);
	end

	if (QGT_Settings.Pin) then
		QGT_QuestWatchFrame:SetMovable(0);
	else
		QGT_QuestWatchFrame:SetMovable(1);
	end

	local questIndex;
	local numObjectives;
	local questWatchMaxWidth = 0;
	local tempWidth;
	local watchText;
	local text, type, finished;
	local questTitle;
	local watchTextIndex = 1;
	QGT_WatchLine[watchTextIndex] = {};
	local objectivesCompleted;
	local strLvl;
	local currHeader = "";
	local lastWatchHeader = "";
	local lastWatchIndex = 0;
	local i, j = 0, 0;
	local numEntries, numQuests = GetNumQuestLogEntries();

	if (QGT_WatchFlash == nil) then QGT_WatchFlash = {}; end

	for questIndex=1, numEntries do
		local questLogTitleText, level, questTag, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily = GetQuestLogTitle(questIndex);
		if (isHeader) then
		    currHeader = questLogTitleText;
		end
		if (IsQuestWatched(questIndex) and (not isHeader)) then
			if (currHeader ~= lastWatchHeader and QGT_Settings.ShowHeaders) then
				QGT_WatchLine[watchTextIndex].Text = currHeader;
				QGT_WatchLine[watchTextIndex].TextColor = {r=1, g=1, b=1};
				QGT_WatchLine[watchTextIndex].Tag = "";
				lastWatchHeader = currHeader;
				lastWatchIndex = watchTextIndex;
				QGT_WatchLine[watchTextIndex].qID = nil;
				QGT_WatchLine[watchTextIndex].isHeader = true;
				QGT_WatchLine[watchTextIndex].isTitle = false;
				watchTextIndex = watchTextIndex + 1;
				QGT_WatchLine[watchTextIndex] = {};
			end

			if ( QGT_WatchHeaders[currHeader] ~= false ) then
				-- Set title
				strLvl = "["..level
				if (isDaily) then
				    strLvl = strLvl.."Y";
				end
				if (questTag ~= nil) then
					if ((questTag == "Group") and (suggestedGroup > 0)) then
						strLvl = strLvl.."G"..suggestedGroup;
					elseif (questTag == "Dungeon") then
						strLvl = strLvl.."D";
					elseif ((questTag == "Elite") or (questTag == "Group")) then
						strLvl = strLvl.."+"
					else
						strLvl = strLvl.."+"
					end
				end
				strLvl = strLvl.."] "
				if (QGT_Settings.ShowLevels) then
					QGT_WatchLine[watchTextIndex].Text = strLvl..questLogTitleText;
				else
					QGT_WatchLine[watchTextIndex].Text = questLogTitleText;
				end
				QGT_WatchLine[watchTextIndex].qID = questIndex;

				QGT_WatchLine[watchTextIndex].isHeader = false;
				QGT_WatchLine[watchTextIndex].isTitle = true;

				local watchQuestIndex = watchTextIndex;
				watchTextIndex = watchTextIndex + 1;
				QGT_WatchLine[watchTextIndex] = {};
				objectivesCompleted = 0;
				local questNumNeeded = 0;
				local questNumDone = 0;
				local r, g, b;

				numObjectives = GetNumQuestLeaderBoards(questIndex);
				for j=1, numObjectives do
					text, type, finished = GetQuestLogLeaderBoard(j, questIndex);
					local qi, qj, itemName, numDone, numNeeded = string.find(text, QG_ITEM_REQ_STR);
					if (itemName == nil) then
						qi, qj, itemName, numDone = string.find(text, QG_ITEM_REQ_STR2);
						numNeeded = 1;
					end

					if ((type == "item") and itemName and IsAddOnLoaded("QuestGuru") and QuestGuru_Items[QuestGuru_RealmName]) then
						iiName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, texture = GetItemInfo(itemName);
						if ((iiName and itemLink) and QuestGuru_Items[QuestGuru_RealmName][iiName] == nil) then
							QuestGuru_Items[QuestGuru_RealmName][iiName] = itemLink;
						end
					end

					if ((not finished) or QGT_Settings.ShowCompletedObj) then
						-- Set Objective text
						if (((type == "item") or (type == "monster") or (type == "object")) and (itemName ~= nil)) then
							QGT_WatchLine[watchTextIndex].Text = " "..QGT_Settings.Bullet.." "..itemName;
							if (numDone == numNeeded) then
								QGT_WatchLine[watchTextIndex].Tag = COMPLETE;
								objectivesCompleted = objectivesCompleted + 1;
							else
								QGT_WatchLine[watchTextIndex].Tag = numDone.."/"..numNeeded;
							end
							r, g, b = QGT_QuestWatchGetObjColor(numDone/numNeeded);
							questNumNeeded = questNumNeeded + numNeeded;
							questNumDone = questNumDone + numDone;
						else
							QGT_WatchLine[watchTextIndex].Text = " "..QGT_Settings.Bullet.." "..text;
							QGT_WatchLine[watchTextIndex].Tag = "";
							questNumNeeded = questNumNeeded + 1;
							if (finished) then
								questNumDone = questNumDone + 1;
								objectivesCompleted = objectivesCompleted + 1;
								r, g, b = QGT_QuestWatchGetObjColor(1);
							else
								r, g, b = QGT_QuestWatchGetObjColor(0);
							end
						end
						QGT_WatchLine[watchTextIndex].qID = type;
						QGT_WatchLine[watchTextIndex].isHeader = false;
						QGT_WatchLine[watchTextIndex].isTitle = false;
						-- Color the objectives
						QGT_WatchLine[watchTextIndex].TextColor = {r=r,g=g,b=b};
						if (QGT_WatchQuests[questLogTitleText] == false) then
							if (QGT_WatchFlash and QGT_WatchFlash[questIndex] and QGT_WatchFlash[questIndex][j]) then
								QGT_WatchLine[watchQuestIndex].fading = QGT_WatchFlash[questIndex][j];
								QGT_WatchFlash[questIndex][j] = nil;
							end
							watchTextIndex = watchTextIndex - 1;
						else
							if (QGT_WatchFlash and QGT_WatchFlash[questIndex] and QGT_WatchFlash[questIndex][j]) then
								QGT_WatchLine[watchTextIndex].fading = QGT_WatchFlash[questIndex][j];
								QGT_WatchFlash[questIndex][j] = nil;
							end
						end
						watchTextIndex = watchTextIndex + 1;
						QGT_WatchLine[watchTextIndex] = {};
					elseif (finished) then
						objectivesCompleted = objectivesCompleted + 1;
						if ((type == "item") or (type == "monster") or (type == "object")) then
							questNumNeeded = questNumNeeded + numNeeded;
							questNumDone = questNumDone + numDone;
						else
							questNumNeeded = questNumNeeded + 1;
							questNumDone = questNumDone + 1;
						end
					end
				end
				-- Brighten the quest title if all the quest objectives were met
				color = GetQuestDifficultyColor(level);
				if ( objectivesCompleted == numObjectives ) then
					QGT_WatchLine[watchQuestIndex].Tag = COMPLETE;
					QGT_WatchLine[watchQuestIndex].TextColor = {r=color.r, g=color.g, b=color.b};
				else
					if (questNumNeeded > 0) then
						local perComplete = math.floor((questNumDone * 100) / questNumNeeded);
						QGT_WatchLine[watchQuestIndex].Tag = perComplete.."%";
					else
						QGT_WatchLine[watchQuestIndex].Tag = "";
					end
					QGT_WatchLine[watchQuestIndex].TextColor = {r=color.r * 0.75, g=color.g * 0.75, b=color.b * 0.75};
				end
			elseif (QGT_WatchFlash[questIndex]) then
				if (QGT_WatchFlash[questIndex].fading == true) then
					QGT_WatchLine[lastWatchIndex].fading = true;
					QGT_WatchFlash[questIndex].fading = nil;
				end
			end
		end
	end

	local watchLines = 30;
	if (QGT_Settings and QGT_Settings and QGT_Settings.Lines) then
		watchLines = QGT_Settings.Lines;
	end

	QGT_WatchLines = watchTextIndex - 1;
	if (QGT_WatchLines > watchLines) then
		QGT_QuestWatchFrameSlider:SetMinMaxValues(0, QGT_WatchLines - watchLines);
	else
		QGT_QuestWatchFrameSlider:SetMinMaxValues(0, 0);
	end

	if (QGT_Settings.QuestWatch.Minimized) then
		if (QGT_Settings.QuestWatch.AutoMinimize) then
			QGT_QuestWatchFrameMinimize:SetText("*");
		else
			QGT_QuestWatchFrameMinimize:SetText("+");
		end
		for i=1, 40 do
			getglobal("QGT_QuestWatchLine"..i):Hide();
		end
		for i=1, QGT_WATCHFRAME_NUM_ITEMS do
			_G["WatchFrameItem"..i]:Hide();
		end
		QGT_QuestWatchFrame:SetHeight(26);

		if (QGT_Settings.QuestWatch.Left == nil) then
			QGT_Settings.QuestWatch.Left = MinimapCluster:GetLeft();
		end
		if (QGT_Settings.QuestWatch.Top == nil) then
			QGT_Settings.QuestWatch.Top = MinimapCluster:GetBottom()+10;
		end
		if (QGT_Settings.QuestWatch.Bottom == nil) then
			QGT_Settings.QuestWatch.Bottom = 60;
		end
		if (not QGT_QuestWatchFrame.isMoving) then
			QGT_QuestWatchFrame:ClearAllPoints();
			if (QGT_Settings.Anchor == "TOP") then
				QGT_QuestWatchFrame:SetPoint("TOPLEFT", "UIParent", "BOTTOMLEFT", QGT_Settings.QuestWatch.Left, QGT_Settings.QuestWatch.Top);
			elseif (QGT_Settings.Anchor == "BOTTOM") then
				QGT_QuestWatchFrame:SetPoint("BOTTOMLEFT", "UIParent", "BOTTOMLEFT", QGT_Settings.QuestWatch.Left, QGT_Settings.QuestWatch.Bottom);
			end
		end
		return;
	end

	local numHeaders = 0;
	local numTitles = 0;
	local watchItemIndex = 0;
	local oldWatchItems = QGT_WATCHFRAME_NUM_ITEMS;
	local sliderVal = QGT_QuestWatchFrameSlider:GetValue();
	local lastQuestWatch = 1;
	for i= 1, QGT_WatchLines do
		j = i - sliderVal;
		if (j > watchLines) then
			j = j - 1;
			break;
		end
		if (i > sliderVal) then
			watchText = getglobal("QGT_QuestWatchLine"..j);
			watchTextTag = getglobal("QGT_QuestWatchLine"..j.."Tag");
			watchNormalText = getglobal("QGT_QuestWatchLine"..j.."NormalText");
			watchTextHighlight = getglobal("QGT_QuestWatchLine"..j.."Highlight");
			watchText:SetText(QGT_WatchLine[i].Text);
			if (QGT_WatchLine[i].TextColor == nil) then
				watchNormalText:SetTextColor(1, 1, 1);
			else
				watchNormalText:SetTextColor(QGT_WatchLine[i].TextColor.r,QGT_WatchLine[i].TextColor.g,QGT_WatchLine[i].TextColor.b);
			end
			watchText.qID = QGT_WatchLine[i].qID;
			watchTextTag:SetText(QGT_WatchLine[i].Tag);
			watchTextTag:Show();

			if (QGT_WatchLine[i].isHeader == true) then
				if ( j > 1 ) then
					watchText:SetPoint("TOPLEFT", "QGT_QuestWatchLine"..(j - 1), "BOTTOMLEFT", 0, -6);
					numHeaders = numHeaders + 1;
				end
				watchText:SetNormalTexture("Interface\\Buttons\\UI-SortArrow");
				watchNormalText:SetPoint("LEFT", "QGT_QuestWatchLine"..j, "LEFT", 8, 0);
				if (QGT_WatchHeaders[QGT_WatchLine[i].Text] ~= false) then
					QGT_WatchHeaders[QGT_WatchLine[i].Text] = true;
					getglobal("QGT_QuestWatchLine"..j.."Arrow"):SetTexCoord(0, 0.5, 0, 1);
				else
					getglobal("QGT_QuestWatchLine"..j.."Arrow"):SetTexCoord(0.5, 0, 0, 0, 0.5, 1, 0, 1);
				end
			elseif (QGT_WatchLine[i].isTitle == true) then
				if ( j > 1 ) then
					watchText:SetPoint("TOPLEFT", "QGT_QuestWatchLine"..(j - 1), "BOTTOMLEFT", 0, -4);
					numTitles = numTitles + 1;
				end
				watchText:SetNormalTexture("");
				watchNormalText:SetPoint("LEFT", "QGT_QuestWatchLine"..j, "LEFT", 0, 0);

				if (QGT_QuestTimer[watchText.qID]) then
					watchTextTag:SetText(SecondsToTime(QGT_QuestTimer[watchText.qID]));
					watchText:SetScript("OnUpdate",
						function (self)
							QGT_UpdateQuestTimers(GetQuestTimers());
							if (QGT_QuestTimer[self.qID]) then
								getglobal(self:GetName().."Tag"):SetText(SecondsToTime(QGT_QuestTimer[self.qID]));
								local tempWidth = getglobal(self:GetName().."Tag"):GetWidth() + 8;
								getglobal(self:GetName().."NormalText"):SetWidth(240 - tempWidth);
							else
								self:SetScript("OnUpdate", nil);
							end
						end);
				else
					if (not QGT_Settings.ShowQuestPercent) then watchTextTag:Hide(); end
				end

				local link, item, charges = GetQuestLogSpecialItemInfo(watchText.qID);
				if ( item and QGT_Settings.QuestItemIcons ) then
					watchItemIndex = watchItemIndex + 1;
					itemButton = _G["WatchFrameItem"..watchItemIndex];
					if ( not itemButton ) then
						QGT_WATCHFRAME_NUM_ITEMS = watchItemIndex;
						itemButton = CreateFrame("BUTTON", "WatchFrameItem" .. watchItemIndex, QGT_QuestWatchFrame, "WatchFrameItemButtonTemplate");
						itemButton:SetScript("OnLeave", WatchFrameItem_OnLeave);
					end
					itemButton:Show();
					itemButton:ClearAllPoints();
					itemButton:SetID(watchText.qID);
					SetItemButtonTexture(itemButton, item);
					SetItemButtonCount(itemButton, charges);
					itemButton.charges = charges;
					WatchFrameItem_UpdateCooldown(itemButton);
					itemButton.rangeTimer = -1;
					if ((QGT_Settings.QuestWatch.Left * QGT_Settings.Scale) < 32) then
						if (QGT_QuestWatchFrameSlider:GetAlpha() > 0) then
							itemButton:SetPoint("TOPLEFT", watchText, "TOPRIGHT", 16, 0);
						else
							itemButton:SetPoint("TOPLEFT", watchText, "TOPRIGHT", 4, 0);
						end
					else
						if ((QGT_QuestWatchFrameSlider:GetAlpha() > 0) and (((QGT_Settings.QuestWatch.Left + 256) * QGT_Settings.Scale) > (UIParent:GetWidth() - 16))) then
							itemButton:SetPoint("TOPRIGHT", watchText, "TOPLEFT", -16, 0);
						else
							itemButton:SetPoint("TOPRIGHT", watchText, "TOPLEFT", -4, 0);
						end
					end
				end
			else
				if (j > 1) then
					watchText:SetPoint("TOPLEFT", "QGT_QuestWatchLine"..(j - 1), "BOTTOMLEFT", 0, 0);
				end
				watchText:SetNormalTexture("");
				watchNormalText:SetPoint("LEFT", "QGT_QuestWatchLine"..j, "LEFT", 0, 0);
			end
			local tempWidth = watchTextTag:GetWidth() + 8;
			watchNormalText:SetWidth(240 - tempWidth);
			if (QGT_WatchLine[i].fading) then
				watchText.fading = 1;
				watchText:SetScript("OnUpdate", QGT_QuestWatchButton_OnUpdate);
				watchTextHighlight:SetAlpha(1);
				watchTextHighlight:Show();
			end
			watchText:Show();
			lastQuestWatch = j;
		end
	end

	QGT_QuestWatchFrame:Show();
	local tempHeight = 16 + (numHeaders*6)+(numTitles*4)+((lastQuestWatch+1)*13);
	QGT_QuestWatchFrame:SetHeight(tempHeight);
	QGT_QuestWatchFrameSlider:SetHeight(tempHeight-16);
	QGT_QuestWatchFrame:SetWidth(256);
	if (not QGT_QuestWatchFrame.isMoving) then
		QGT_QuestWatchFrame:ClearAllPoints();
		if (QGT_Settings.Anchor == "TOP") then
			QGT_QuestWatchFrame:SetPoint("TOPLEFT", "UIParent", "BOTTOMLEFT", QGT_Settings.QuestWatch.Left, QGT_Settings.QuestWatch.Top);
			QGT_Settings.QuestWatch.Bottom = QGT_QuestWatchFrame:GetBottom();
		elseif (QGT_Settings.Anchor == "BOTTOM") then
			QGT_QuestWatchFrame:SetPoint("BOTTOMLEFT", "UIParent", "BOTTOMLEFT", QGT_Settings.QuestWatch.Left, QGT_Settings.QuestWatch.Bottom);
			QGT_Settings.QuestWatch.Top = QGT_QuestWatchFrame:GetTop();
		end
	end
	QGT_QuestWatchFrameSlider:ClearAllPoints();
	if (((QGT_Settings.QuestWatch.Left + 256) * QGT_Settings.Scale) > (UIParent:GetWidth() - 16)) then
		QGT_QuestWatchFrameSlider:SetPoint("TOPLEFT", -14, -16);
	else
		QGT_QuestWatchFrameSlider:SetPoint("TOPRIGHT", 14, -16);
	end
	-- Hide unused watch lines
	for i=j + 1, 40 do
		getglobal("QGT_QuestWatchLine"..i):Hide();
	end
	for i=watchItemIndex+1, oldWatchItems do
	    _G["WatchFrameItem"..i]:Hide();
	end

	if (IsAddOnLoaded("MobMap")) then
		for i=1, 40 do
			local frame=getglobal("QGT_QuestWatchLine"..i);
			local button=getglobal("MobMapQGTWatchButton"..i);
			if (frame:IsVisible() and (mobmap_hide_questtracker_buttons == false) and (frame.qID ~= nil)) then
				local questobj=frame:GetText();
				if(questobj) then
					if (button==nil) then
						button = CreateFrame("Frame","MobMapQGTWatchButton"..i, frame, "MobMapQuestButtonFrameTemplate");
						button:ClearAllPoints();
						button:SetPoint("RIGHT","QGT_QuestWatchLine"..i,"LEFT",-6,0);
						button:SetAlpha(0.6);
						button:SetFrameStrata("LOW");
						getglobal(button:GetName().."Button"):SetScript("OnEnter",
							function (self)
								QGT_ShowQuestTrackerSlider(true);
								GameTooltip_AddNewbieTip(self, "MobMap",1.0,1.0,1.0,MOBMAP_QUEST_BUTTON_TOOLTIP);
							end);
						getglobal(button:GetName().."Button"):SetScript("OnLeave",
							function (self)
								QGT_ShowQuestTrackerSlider(false);
								GameTooltip:Hide();
							end);
					end
					if (string.sub(questobj,1,2+strlen(QGT_Settings.Bullet))==" "..QGT_Settings.Bullet.." ") then
						button.questobj=string.sub(questobj,3+strlen(QGT_Settings.Bullet));
						button.questtitle=nil;
						button.unknowntext=nil;
						button:Show();
					else
						local title=questobj;
						if(title~=nil) then
							local filteredtitle=string.match(title,".*%] (.*)");
							if(filteredtitle~=nil) then
								title=filteredtitle;
							end
						end
						button.questtitle=title;
						button.questobj=nil;
						button.unknowntext=nil;
						button:Show();
					end
				end
			else
				if (button) then
					button:Hide();
				end
			end
		end
	end
end

-- ============================================================
--  Objective color
-- ============================================================
function QGT_QuestWatchGetObjColor(progress, alwaysColor)
	local r, g, b;
	if (QGT_Settings.ColorizeObj or alwaysColor) then
		if (progress == 1) then
			r = QGT_Settings.ColorizeObjComplete.r;
			g = QGT_Settings.ColorizeObjComplete.g;
			b = QGT_Settings.ColorizeObjComplete.b;
		else
			r = QGT_Settings.ColorizeObjZero.r + ((QGT_Settings.ColorizeObjFull.r - QGT_Settings.ColorizeObjZero.r) * progress);
			g = QGT_Settings.ColorizeObjZero.g + ((QGT_Settings.ColorizeObjFull.g - QGT_Settings.ColorizeObjZero.g) * progress);
			b = QGT_Settings.ColorizeObjZero.b + ((QGT_Settings.ColorizeObjFull.b - QGT_Settings.ColorizeObjZero.b) * progress);
		end
	else
		if (progress == 1) then
			r = HIGHLIGHT_FONT_COLOR.r;
			g = HIGHLIGHT_FONT_COLOR.g;
			b = HIGHLIGHT_FONT_COLOR.b;
		else
			r = GRAY_FONT_COLOR.r;
			g = GRAY_FONT_COLOR.g;
			b = GRAY_FONT_COLOR.b;
	    end
	end
	return r, g, b;
end

-- ============================================================
--  AddQuestWatch / RemoveQuestWatch / IsQuestWatched hooks
-- ============================================================
local old_AddQuestWatch = AddQuestWatch;
function AddQuestWatch(questIndex, watchTime)
	local questLogTitleText, level, questTag, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily = GetQuestLogTitle(questIndex);
	if (isHeader) then
		QGT_AddQuestWatchHeader(questLogTitleText);
		return false;
	end
	if (QGT_WatchList[questLogTitleText] == nil) then
		QGT_WatchList[questLogTitleText] = {};
	end
	if (QGT_WatchList[questLogTitleText].Watched) then
		return true;
	end
	QGT_WatchList[questLogTitleText].Watched = true;
	return true;
end

function QGT_AddQuestWatchHeader(questHeader)
	local numEntries, numQuests = GetNumQuestLogEntries();
	local inHeader = false;

	for questIndex=1, numEntries do
		local questLogTitleText, level, questTag, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily = GetQuestLogTitle(questIndex);
		if (isHeader) then
			if (questLogTitleText == questHeader) then
				inHeader = true;
			else
				inHeader = false;
			end
		end
		if (inHeader and (not isHeader)) then
			AddQuestWatch(questIndex);
		end
	end
end

local old_RemoveQuestWatch = RemoveQuestWatch;
function RemoveQuestWatch(questIndex, ...)
	local questLogTitleText, level, questTag, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily = GetQuestLogTitle(questIndex);
	if (isHeader) then
		QGT_RemoveQuestWatchHeader(questLogTitleText);
	end
	if (questLogTitleText) then
		QGT_WatchList[questLogTitleText] = nil;
		QGT_WatchQuests[questLogTitleText] = nil;
	end
	WatchFrame_Update();
end

function QGT_RemoveQuestWatchHeader(questHeader)
	local numEntries, numQuests = GetNumQuestLogEntries();
	local inHeader = false;

	for questIndex=1, numEntries do
		local questLogTitleText, level, questTag, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily = GetQuestLogTitle(questIndex);
		if (isHeader) then
			if (questLogTitleText == questHeader) then
				inHeader = true;
			else
				inHeader = false;
		    end
		end
		if (inHeader and (not isHeader)) then
			RemoveQuestWatch(questIndex);
		end
	end
end

local old_IsQuestWatched = IsQuestWatched;
function IsQuestWatched(questIndex, ...)
	local questLogTitleText, level, questTag, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily = GetQuestLogTitle(questIndex);
	if (QGT_WatchList[questLogTitleText] == nil) then
		return false;
	end
	return QGT_WatchList[questLogTitleText].Watched;
end

-- ============================================================
--  Update timer
-- ============================================================
function QGT_OnUpdate(elapsed)
	QGT_CurrTime = QGT_CurrTime + elapsed;
	if (QGT_CurrTime < 1) then return; end

	local i, timer;

	for i, timer in ipairs(QGT_Timer) do
	    timer.currTime = timer.currTime - 1;
	    if (timer.currTime == 0) then
	        timer.func(timer.arg1, timer.arg2, timer.arg3, timer.arg4);
	        timer.currTime = timer.interval;
	        timer.count = timer.count - 1;
	        if (timer.count < 0) then
	            timer.count = -1;
			elseif (timer.count == 0) then
			    tremove(QGT_Timer, i);
			    i = i - 1;
			end
		end
	end

	QGT_CurrTime = 0;
end

function QGT_AddTimer(interval, count, func, arg1, arg2, arg3, arg4)
	local tempTimer = {}
	tempTimer.interval = interval;
	tempTimer.currTime = interval;
	tempTimer.count = count;
	tempTimer.func = func;
	tempTimer.arg1 = arg1;
	tempTimer.arg2 = arg2;
	tempTimer.arg3 = arg3;
	tempTimer.arg4 = arg4;
	tinsert(QGT_Timer, tempTimer);
end

-- ============================================================
--  UI info message -> flash the changed objective
-- ============================================================
function QGT_UIInfoMessage(arg1)
	local questID=0;
	local numEntries, numQuests = GetNumQuestLogEntries();
	local i, ii, jj, itemName, numDone, numNeeded;
	local questLogTitleText, level, questTag, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily;

	if (arg1 == nil) then return; end

	for questID=1, numEntries, 1 do
		questLogTitleText, level, questTag, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily = GetQuestLogTitle(questID);
		local numObjectives = GetNumQuestLeaderBoards(questID);

		if (numObjectives ~= nil) then
			for i=1, numObjectives, 1 do
				local text, type, finished = GetQuestLogLeaderBoard(i,questID);
				local qi, qj, qitemName, qnumDone, qnumNeeded = string.find(text, QG_ITEM_REQ_STR);
				if (qitemName == nil) then
					qi, qj, qitemName, qnumDone = string.find(text, QG_ITEM_REQ_STR2);
					qnumNeeded = 1;
				end
				if ((type == "item") or (type == "monster") or (type == "object")) then
					if (type == "object") then type = "item"; end
					ii, jj, itemName, numDone, numNeeded = string.find(arg1, QG_ITEM_REQ_STR);
					if ((itemName == qitemName) and (numNeeded == qnumNeeded)) then
						if (QGT_WatchFlash[questID] == nil) then QGT_WatchFlash[questID] = {}; end
						QGT_WatchFlash[questID].fading = true;
						QGT_WatchFlash[questID][i] = true;
					end
				elseif (type == "event") then
					itemName = text;
					numDone=1;
					numNeeded=1;
					if (arg1 == text.." ("..COMPLETE..")") then
						if (QGT_WatchFlash[questID] == nil) then QGT_WatchFlash[questID] = {}; end
						QGT_WatchFlash[questID].fading = true;
						QGT_WatchFlash[questID][i] = true;
					end
				end
			end
		end
	end
end

-- ============================================================
--  Hooks: reward / abandon quests
-- ============================================================
function QGT_RewardComplete_Click()
	local qTitle = GetTitleText();

	if (qTitle) then
		QGT_WatchList[qTitle] = nil;
		QGT_WatchQuests[qTitle] = nil;
	end
end
hooksecurefunc("QuestRewardCompleteButton_OnClick", QGT_RewardComplete_Click);

function QGT_AbandonQuest()
	if (QGT_LastAbandonQuestTitle) then
		QGT_WatchList[QGT_LastAbandonQuestTitle] = nil;
		QGT_WatchQuests[QGT_LastAbandonQuestTitle] = nil;
	end
end
hooksecurefunc("AbandonQuest", QGT_AbandonQuest);

function QGT_SetAbandonQuest()
	QGT_LastAbandonQuestTitle = GetAbandonQuestName();
end
hooksecurefunc("SetAbandonQuest", QGT_SetAbandonQuest);