local E, L, V, P, G = unpack(ElvUI)
local ABS = E:NewModule("ActionBarSaver", "AceConsole-3.0")

local restoreErrors, spellCache, macroCache, macroNameCache = {}, {}, {}, {}
local iconCache, playerClass

local MAX_MACROS = 54
local MAX_CHAR_MACROS = 18
local MAX_GLOBAL_MACROS = 36
local MAX_ACTION_BUTTONS = 144
local POSSESSION_START = 121
local POSSESSION_END = 132

-- Register default settings in ElvUI profile
P["actionBarSaver"] = {
	macro = false,
	checkCount = false,
	restoreRank = true,
	restoreTalents = true,
	spellSubs = {},
	sets = {}
}

for classToken in pairs(RAID_CLASS_COLORS) do
	P["actionBarSaver"].sets[classToken] = {}
end

function ABS:Initialize()
	self.db = E.db.actionBarSaver
	playerClass = select(2, UnitClass("player"))

	-- Register Slash Commands
	self:RegisterChatCommand("abs", "SlashHandler")
	self:RegisterChatCommand("actionbarsaver", "SlashHandler")

	-- Register options with ElvUI Plugin Library
	local EP = LibStub("LibElvUIPlugin-1.0")
	EP:RegisterPlugin("ElvUI_ActionBarSaver", ABS.GetOptions)
end

function ABS:CompressText(text)
	text = string.gsub(text, "\n", "/n")
	text = string.gsub(text, "/n$", "")
	text = string.gsub(text, "||", "/124")
	return string.trim(text)
end

function ABS:UncompressText(text)
	text = string.gsub(text, "/n", "\n")
	text = string.gsub(text, "/124", "|")
	return string.trim(text)
end

-- Save Talent Build
function ABS:SaveTalents(set)
	set.talents = {}
	local numTabs = GetNumTalentTabs()
	if not numTabs or numTabs == 0 then return end

	for tab = 1, numTabs do
		set.talents[tab] = {}
		local numTalents = GetNumTalents(tab)
		for idx = 1, numTalents do
			local cRank = select(5, GetTalentInfo(tab, idx)) or 0
			local pRank = select(9, GetTalentInfo(tab, idx)) or 0
			-- Use math.max to prevent 1 + 1 double counting
			set.talents[tab][idx] = math.max(cRank, pRank)
		end
	end
end

-- Restore Talent Build
function ABS:RestoreTalents(set)
	if not set.talents or not self.db.restoreTalents then return false end
	local numTabs = GetNumTalentTabs()
	if not numTabs or numTabs == 0 then return false end

	-- Wipe staged uncommitted preview points
	local activeGroup = GetActiveTalentGroup and GetActiveTalentGroup() or 1
	if ResetGroupPreviewTalentPoints then
		ResetGroupPreviewTalentPoints(activeGroup)
	elseif ResetPreviewTalentPoints then
		ResetPreviewTalentPoints()
	end

	local totalPointsSpent = 0
	local passCount = 0
	local maxPasses = 10

	repeat
		local pointsAddedThisPass = 0
		passCount = passCount + 1

		for tier = 1, 11 do
			for tab = 1, numTabs do
				if set.talents[tab] then
					local numTalents = GetNumTalents(tab)
					for idx = 1, numTalents do
						local name, _, tTier, _, currentRank, maxRank, _, _, previewRank = GetTalentInfo(tab, idx)
						if tTier == tier then
							local savedRank = set.talents[tab][idx] or 0
							local effectiveRank = math.max(currentRank or 0, previewRank or 0)
							local needed = savedRank - effectiveRank

							if needed > 0 and (GetUnspentTalentPoints() or 0) > 0 then
								for p = 1, needed do
									if (GetUnspentTalentPoints() or 0) <= 0 then break end

									local c1 = select(5, GetTalentInfo(tab, idx)) or 0
									local p1 = select(9, GetTalentInfo(tab, idx)) or 0
									local rankBefore = math.max(c1, p1)

									AddPreviewTalentPoints(tab, idx, 1)

									local c2 = select(5, GetTalentInfo(tab, idx)) or 0
									local p2 = select(9, GetTalentInfo(tab, idx)) or 0
									local rankAfter = math.max(c2, p2)

									if rankAfter > rankBefore then
										pointsAddedThisPass = pointsAddedThisPass + 1
										totalPointsSpent = totalPointsSpent + 1
									else
										break
									end
								end
							end
						end
					end
				end
			end
		end
	until pointsAddedThisPass == 0 or passCount >= maxPasses or (GetUnspentTalentPoints() or 0) == 0

	if totalPointsSpent > 0 then
		LearnPreviewTalents(false)
		return true
	end
	return false
end

function ABS:SaveProfile(name)
	if not name or name == "" then return end
	self.db.sets[playerClass][name] = self.db.sets[playerClass][name] or {}
	local set = self.db.sets[playerClass][name]

	-- Save Action Bar Buttons
	for actionID = 1, MAX_ACTION_BUTTONS do
		set[actionID] = nil

		local type, id, subType, extraID = GetActionInfo(actionID)
		if type and id and (actionID < POSSESSION_START or actionID > POSSESSION_END) then
			if type == "companion" then
				set[actionID] = string.format("%s|%s|%s|%s|%s|%s", type, id, "", name, subType, extraID)
			elseif type == "equipmentset" then
				set[actionID] = string.format("%s|%s|%s", type, id, "")
			elseif type == "item" then
				set[actionID] = string.format("%s|%d|%s|%s", type, id, "", (GetItemInfo(id)) or "")
			elseif type == "spell" and id > 0 then
				local spell, rank = GetSpellName(id, BOOKTYPE_SPELL)
				if spell then
					set[actionID] = string.format("%s|%d|%s|%s|%s|%s", type, id, "", spell, rank or "", extraID or "")
				end
			elseif type == "macro" then
				local name, icon, macro = GetMacroInfo(id)
				if name and icon and macro then
					set[actionID] = string.format("%s|%d|%s|%s|%s|%s", type, actionID, "", self:CompressText(name), icon, self:CompressText(macro))
				end
			end
		end
	end

	-- Save Talents
	self:SaveTalents(set)

	self:Print(string.format(L["Saved profile %s!"], name))
end

function ABS:FindMacro(id, name, data)
	if macroCache[id] == data then return id end
	for id, currentMacro in pairs(macroCache) do
		if currentMacro == data then return id end
	end
	if macroNameCache[name] then return macroNameCache[name] end
	return nil
end

function ABS:RestoreMacros(set)
	local perCharacter = true
	for id = 1, MAX_ACTION_BUTTONS do
		local data = set[id]
		if type(data) == "string" then
			local type, actionID, binding, macroName, macroIcon, macroData = string.split("|", data)
			if type == "macro" then
				local macroID = self:FindMacro(actionID, macroName, macroData)
				if not macroID then
					local globalNum, charNum = GetNumMacros()
					if globalNum == MAX_GLOBAL_MACROS and charNum == MAX_CHAR_MACROS then
						table.insert(restoreErrors, L["Unable to restore macros, you already have 18 global and 18 per character ones created."])
						break
					elseif charNum == MAX_CHAR_MACROS then
						perCharacter = false
					end

					if not iconCache then
						iconCache = {}
						for i = 1, GetNumMacroIcons() do
							iconCache[(GetMacroIconInfo(i))] = i
						end
					end

					macroName = self:UncompressText(macroName)
					CreateMacro(macroName == "" and " " or macroName, iconCache[macroIcon] or 1, self:UncompressText(macroData), nil, perCharacter)
				end
			end
		end
	end

	table.wipe(macroCache)
	table.wipe(macroNameCache)
	local blacklist = {}
	for i = 1, MAX_MACROS do
		local name, icon, macro = GetMacroInfo(i)
		if name then
			if macroNameCache[name] then
				blacklist[name] = true
				macroNameCache[name] = i
			elseif not blacklist[name] then
				macroNameCache[name] = i
			end
		end
		macroCache[i] = macro and self:CompressText(macro) or nil
	end
end

function ABS:RestoreActionsAndMacros(name, overrideClass, set)
	table.wipe(macroCache)
	table.wipe(spellCache)
	table.wipe(macroNameCache)

	for book = 1, MAX_SKILLLINE_TABS do
		local _, _, offset, numSpells = GetSpellTabInfo(book)
		for i = 1, numSpells do
			local index = offset + i
			local spell, rank = GetSpellName(index, BOOKTYPE_SPELL)
			if spell then
				spellCache[spell] = index
				spellCache[string.lower(spell)] = index
				if rank and rank ~= "" then
					spellCache[spell .. rank] = index
				end
			end
		end
	end

	local blacklist = {}
	for i = 1, MAX_MACROS do
		local name, icon, macro = GetMacroInfo(i)
		if name then
			if macroNameCache[name] then
				blacklist[name] = true
				macroNameCache[name] = i
			elseif not blacklist[name] then
				macroNameCache[name] = i
			end
		end
		macroCache[i] = macro and self:CompressText(macro) or nil
	end

	if self.db.macro then
		self:RestoreMacros(set)
	end

	ClearCursor()
	local soundToggle = GetCVar("Sound_EnableAllSound")
	SetCVar("Sound_EnableAllSound", 0)

	for i = 1, MAX_ACTION_BUTTONS do
		if i < POSSESSION_START or i > POSSESSION_END then
			local type, id = GetActionInfo(i)
			if id or type then
				PickupAction(i)
				ClearCursor()
			end
			if set[i] then
				self:RestoreAction(i, string.split("|", set[i]))
			end
		end
	end

	SetCVar("Sound_EnableAllSound", soundToggle)

	if #restoreErrors == 0 then
		self:Print(string.format(L["Restored profile %s!"], name))
	else
		self:Print(string.format(L["Restored profile %s, failed to restore %d buttons type /abs errors for more information."], name, #restoreErrors))
	end
end

function ABS:RestoreProfile(name, overrideClass)
	local set = self.db.sets[overrideClass or playerClass][name]
	if not set then
		self:Print(string.format(L["No profile with the name \"%s\" exists."], name or ""))
		return
	elseif InCombatLockdown() then
		self:Print(string.format(L["Unable to restore profile \"%s\", you are in combat."], name))
		return
	end

	local talentsLearned = self:RestoreTalents(set)

	if talentsLearned then
		local syncFrame = CreateFrame("Frame")
		syncFrame:RegisterEvent("SPELLS_CHANGED")
		
		local timer = 0
		syncFrame:SetScript("OnUpdate", function(f, elapsed)
			timer = timer + elapsed
			if timer >= 0.6 then
				f:SetScript("OnUpdate", nil)
				f:UnregisterAllEvents()
				ABS:RestoreActionsAndMacros(name, overrideClass, set)
			end
		end)

		syncFrame:SetScript("OnEvent", function(f, event)
			f:SetScript("OnUpdate", nil)
			f:UnregisterAllEvents()
			ABS:RestoreActionsAndMacros(name, overrideClass, set)
		end)
	else
		self:RestoreActionsAndMacros(name, overrideClass, set)
	end
end

function ABS:RestoreAction(i, type, actionID, binding, ...)
	if type == "spell" then
		local spellName, spellRank = ...
		if (self.db.restoreRank or spellRank == "") and spellCache[spellName] then
			PickupSpell(spellCache[spellName], BOOKTYPE_SPELL)
		elseif spellRank ~= "" and spellCache[spellName .. spellRank] then
			PickupSpell(spellCache[spellName .. spellRank], BOOKTYPE_SPELL)
		end

		if GetCursorInfo() ~= type then
			local lowerSpell = string.lower(spellName)
			for spell, linked in pairs(self.db.spellSubs) do
				if lowerSpell == spell and spellCache[linked] then
					self:RestoreAction(i, type, actionID, binding, linked, nil, select(3, ...))
					return
				elseif lowerSpell == linked and spellCache[spell] then
					self:RestoreAction(i, type, actionID, binding, spell, nil, select(3, ...))
					return
				end
			end
			table.insert(restoreErrors, string.format(L["Unable to restore spell \"%s\" to slot #%d, it does not appear to have been learned yet."], spellName, i))
			ClearCursor()
			return
		end
		PlaceAction(i)

	elseif type == "equipmentset" then
		local slotID = -1
		for idx = 1, GetNumEquipmentSets() do
			if GetEquipmentSetInfo(idx) == actionID then
				slotID = idx
				break
			end
		end
		PickupEquipmentSet(slotID)
		if GetCursorInfo() ~= "equipmentset" then
			table.insert(restoreErrors, string.format(L["Unable to restore equipment set \"%s\" to slot #%d, it does not appear to exist anymore."], actionID, i))
			ClearCursor()
			return
		end
		PlaceAction(i)

	elseif type == "companion" then
		local critterName, critterType = ...
		PickupCompanion(critterType, actionID)
		if GetCursorInfo() ~= "companion" then
			table.insert(restoreErrors, string.format(L["Unable to restore companion \"%s\" to slot #%d, it does not appear to exist yet."], critterName or actionID, i))
			ClearCursor()
			return
		end
		PlaceAction(i)

	elseif type == "item" then
		PickupItem(actionID)
		if GetCursorInfo() ~= type then
			local itemName = select(1, ...)
			table.insert(restoreErrors, string.format(L["Unable to restore item \"%s\" to slot #%d, cannot be found in inventory."], itemName and itemName ~= "" and itemName or actionID, i))
			ClearCursor()
			return
		end
		PlaceAction(i)

	elseif type == "macro" then
		local name, _, content = ...
		PickupMacro(self:FindMacro(actionID, name, content or -1))
		if GetCursorInfo() ~= type then
			table.insert(restoreErrors, string.format(L["Unable to restore macro id #%d to slot #%d, it appears to have been deleted."], actionID, i))
			ClearCursor()
			return
		end
		PlaceAction(i)
	end
end

function ABS:Print(msg)
	E:Print("|cff33ff99ABS:|r " .. msg)
end

function ABS:SlashHandler(msg)
	local cmd, arg = string.split(" ", msg or "", 2)
	cmd = string.lower(cmd or "")
	arg = string.lower(arg or "")

	if cmd == "save" and arg ~= "" then
		self:SaveProfile(arg)
	elseif cmd == "restore" and arg ~= "" then
		table.wipe(restoreErrors)
		self:RestoreProfile(arg, playerClass)
	elseif cmd == "errors" then
		if #restoreErrors == 0 then
			self:Print(L["No errors found!"])
			return
		end
		self:Print(string.format(L["Errors found: %d"], #restoreErrors))
		for _, text in ipairs(restoreErrors) do
			DEFAULT_CHAT_FRAME:AddMessage(text)
		end
	else
		E:ToggleOptionsUI("ActionBarSaver")
	end
end

-- =========================================================================
-- Chat Reset Listener for Automatic Talent Restoration
-- =========================================================================
local ABS_ResetWatcher = CreateFrame("Frame")
ABS_ResetWatcher:RegisterEvent("CHAT_MSG_SYSTEM")

ABS_ResetWatcher:SetScript("OnEvent", function(self, event, msg)
	if not msg then return end

	local lowerMsg = string.lower(msg)
	if lowerMsg:find("talents have been reset") or lowerMsg:find("talents reset") or lowerMsg:find("talent tree reset") then
		if PlayerTalentFrame and PlayerTalentFrame:IsShown() then
			TalentFrame_Update()
		end

		local delayFrame = CreateFrame("Frame")
		local totalElapsed = 0

		delayFrame:SetScript("OnUpdate", function(f, elapsed)
			totalElapsed = totalElapsed + elapsed
			if totalElapsed >= 0.4 then
				f:SetScript("OnUpdate", nil)
				if ABS and ABS.db and ABS.db.sets then
					local pClass = select(2, UnitClass("player"))
					if ABS.db.sets[pClass] and ABS.db.sets[pClass]["AutoSave"] then
						ABS:RestoreProfile("AutoSave", pClass)
					end
				end
			end
		end)
	end
end)

E:RegisterModule(ABS:GetName())