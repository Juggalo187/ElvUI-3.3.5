local E, L, V, P, G = unpack(select(2, ...)); --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local UF = E:GetModule("UnitFrames")
local SpellRange = E.Libs.SpellRange

--Lua functions
local pairs, ipairs = pairs, ipairs
local find = string.find
--WoW API / Variables
local CheckInteractDistance = CheckInteractDistance
local UnitCanAttack = UnitCanAttack
local UnitInParty = UnitInParty
local UnitInRaid = UnitInRaid
local UnitInRange = UnitInRange
local UnitIsConnected = UnitIsConnected
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsUnit = UnitIsUnit

local SRT = {}
local function AddTable(tbl)
	SRT[E.myclass][tbl] = {}
end

local function AddSpell(tbl, spellID)
	SRT[E.myclass][tbl][#SRT[E.myclass][tbl] + 1] = spellID
end

-- User-configured range spells (Range Fader options). CoA classes have no
-- entries in spellRangeCheck at all, so these are the only way to make the
-- fader match an actual cast range there.
local customSpells = {}

local function ParseSpellInput(value)
	if not value or value == "" then return nil end
	return tonumber(value) or value -- LibSpellRange accepts spellID or name
end

function UF:UpdateRangeCheckSpells()
	if not SRT[E.myclass] then SRT[E.myclass] = {} end
	SRT[E.myclass].friendlySpells = SRT[E.myclass].friendlySpells or {}
	SRT[E.myclass].enemySpells = SRT[E.myclass].enemySpells or {}
	SRT[E.myclass].resSpells = SRT[E.myclass].resSpells or {}

	local classDB = E.global.unitframe.spellRangeCheck[E.myclass]
	if classDB then -- guard: CoA class tokens have no built-in lists
		for tbl, spells in pairs(classDB) do
			AddTable(tbl) --Create the table holding spells, even if it ends up being an empty table
			for spellID in pairs(spells) do
				local enabled = spells[spellID]
				if enabled then --We will allow value to be false to disable this spell from being used
					AddSpell(tbl, spellID, enabled)
				end
			end
		end
	end

	-- Scan player spellbook for Ascension / Classless spells with range
	local maxSpells = 0
	for i = MAX_SKILLLINE_TABS, 1, -1 do
		local _, _, offs, numspells = GetSpellTabInfo(i)
		if numspells and numspells > 0 then
			maxSpells = offs + numspells
			break
		end
	end

	for i = 1, maxSpells do
		local spellName = GetSpellName(i, "spell")
		if spellName and spellName ~= "" then
			local link = GetSpellLink(i, "spell")
			local spellID = link and tonumber(link:match("spell:(%d+)"))
			local checkID = spellID or i

			if SpellHasRange(i, "spell") then
				if spellName:find("Resurrect") or spellName:find("Revive") or spellName:find("Rebirth") or spellName:find("Ancestral") or spellName:find("Redemption") then
					table.insert(SRT[E.myclass].resSpells, checkID)
				else
					table.insert(SRT[E.myclass].friendlySpells, checkID)
					table.insert(SRT[E.myclass].enemySpells, checkID)
				end
			end
		end
	end

	local db = E.db.unitframe
	customSpells.friendly = ParseSpellInput(db.rangeFriendlySpell)
	customSpells.enemy = ParseSpellInput(db.rangeEnemySpell)
	customSpells.res = ParseSpellInput(db.rangeResSpell)
	customSpells.pet = ParseSpellInput(db.rangePetSpell)
end

-- Returns true/false when the configured spell gave an authoritative answer,
-- nil when no spell is configured or the spell is unknown to the client
local function CustomSpellCheck(kind, unit)
	local spell = customSpells[kind]
	if spell then
		local result = SpellRange.IsSpellInRange(spell, unit)
		if result == nil and type(spell) == "number" then
			local spellName = GetSpellInfo(spell)
			if spellName then
				result = SpellRange.IsSpellInRange(spellName, unit)
			end
		end
		if result ~= nil then
			return result == 1
		end
	end
	return nil
end

local fallbackChecks = {
	INTERACT28 = function(unit) return CheckInteractDistance(unit, 1) end, -- ~28yd
	INTERACT11 = function(unit) return CheckInteractDistance(unit, 2) end, -- ~11yd
	INTERACT9 = function(unit) return CheckInteractDistance(unit, 3) end, -- ~9yd
	ALWAYS = function() return true end,
	SPELLS = function() return false end, -- spells only: no distance fallback
}

local function FallbackInRange(unit, enemy)
	local mode = enemy and E.db.unitframe.rangeFallbackEnemy or E.db.unitframe.rangeFallback
	local check = fallbackChecks[mode] or (enemy and fallbackChecks.INTERACT11 or fallbackChecks.INTERACT28)
	return check(unit)
end

local function getUnit(unit)
	-- Only scan for a canonical token when the unit is NEITHER party- nor
	-- raid-shaped already. The old 'or' made this condition always true, so
	-- every fader range check ran up to 44 UnitIsUnit calls (thousands/sec
	-- at raid scale) even for units already named "raid17"/"party2".
	if not find(unit, "party") and not find(unit, "raid") then
		for i = 1, 4 do
			if UnitIsUnit(unit, "party"..i) then
				return "party"..i
			end
		end

		for i = 1, 40 do
			if UnitIsUnit(unit, "raid"..i) then
				return "raid"..i
			end
		end
	else
		return unit
	end
end

local function friendlyIsInRange(unit)
	if (not UnitIsUnit(unit, "player")) and (UnitInParty(unit) or UnitInRaid(unit)) then
		unit = getUnit(unit) -- swap the unit with `raid#` or `party#` when its NOT `player`, UnitIsUnit is true, and its not using `raid#` or `party#` already
	end

	-- user-configured spells are authoritative and MUST run before the
	-- UnitInRange short-circuit (your spell may reach further than 38yd)
	if UnitIsDeadOrGhost(unit) then
		local customRes = CustomSpellCheck("res", unit)
		if customRes ~= nil then
			return customRes
		end
	else
		local custom = CustomSpellCheck("friendly", unit)
		if custom ~= nil then
			return custom
		end
	end

	local inRange, checkedRange = UnitInRange(unit)
	if checkedRange and not inRange then
		return false -- blizz checked and said the unit is out of range
	end

	if FallbackInRange(unit) then
		return true -- within the configured fallback distance
	end

	if SRT[E.myclass] then
		if SRT[E.myclass].resSpells and UnitIsDeadOrGhost(unit) and (#SRT[E.myclass].resSpells > 0) then -- dead with rez spells
			for _, spellID in ipairs(SRT[E.myclass].resSpells) do
				if SpellRange.IsSpellInRange(spellID, unit) == 1 then
					return true -- within rez range
				end
			end

			return false -- dead but no spells are in range
		end

		if SRT[E.myclass].friendlySpells and (#SRT[E.myclass].friendlySpells > 0) then -- you have some healy spell
			for _, spellID in ipairs(SRT[E.myclass].friendlySpells) do
				if SpellRange.IsSpellInRange(spellID, unit) == 1 then
					return true -- within healy spell range
				end
			end
		end
	end

	return false -- not within 28 yards and no spells in range
end

local function petIsInRange(unit)
	local custom = CustomSpellCheck("pet", unit)
	if custom ~= nil then
		return custom
	end

	if CheckInteractDistance(unit, 2) then
		return true -- within 8 yards (arg2 as 2 is Trade distance)
	end

	if SRT[E.myclass] then
		if SRT[E.myclass].friendlySpells and (#SRT[E.myclass].friendlySpells > 0) then -- you have some healy spell
			for _, spellID in ipairs(SRT[E.myclass].friendlySpells) do
				if SpellRange.IsSpellInRange(spellID, unit) == 1 then
					return true
				end
			end
		end

		if SRT[E.myclass].petSpells and (#SRT[E.myclass].petSpells > 0) then -- you have some pet spell
			for _, spellID in ipairs(SRT[E.myclass].petSpells) do
				if SpellRange.IsSpellInRange(spellID, unit) == 1 then
					return true
				end
			end
		end
	end

	return false -- not within 8 yards and no spells in range
end

local function enemyIsInRange(unit)
	local custom = CustomSpellCheck("enemy", unit)
	if custom ~= nil then
		return custom
	end

	if FallbackInRange(unit, true) then
		return true -- within the configured enemy fallback distance
	end

	if SRT[E.myclass] then
		if SRT[E.myclass].enemySpells and (#SRT[E.myclass].enemySpells > 0) then -- you have some damage spell
			for _, spellID in ipairs(SRT[E.myclass].enemySpells) do
				if SpellRange.IsSpellInRange(spellID, unit) == 1 then
					return true
				end
			end
		end
	end

	return false -- not within 8 yards and no spells in range
end

local function enemyIsInLongRange(unit)
	if SRT[E.myclass] then
		if SRT[E.myclass].longEnemySpells and (#SRT[E.myclass].longEnemySpells > 0) then -- you have some 30+ range damage spell
			for _, spellID in ipairs(SRT[E.myclass].longEnemySpells) do
				if SpellRange.IsSpellInRange(spellID, unit) == 1 then
					return true
				end
			end
		end
	end

	return false
end

local UnitDistanceSquared = UnitDistanceSquared -- retail-style API; present on some custom clients

-- Per-frame range modes (Fader options on each unit frame).
-- Returns true/false, or nil to fall back to the smart default logic.
local function CheckDistanceMode(unit, mode, fdb)
	if mode == "MELEE" then
		return CheckInteractDistance(unit, 3) and true or false -- ~9yd (duel)
	elseif mode == "INTERACT11" then
		return CheckInteractDistance(unit, 2) and true or false -- ~11yd (trade)
	elseif mode == "INTERACT28" then
		return CheckInteractDistance(unit, 1) and true or false -- ~28yd (inspect)
	elseif mode == "GROUP38" then
		local inRange, checked = UnitInRange(unit)
		if checked then
			return inRange and true or false
		end
		return nil -- not a group unit right now; use the default logic
	elseif mode == "SPELL" then
		local spell = fdb.rangeSpell
		if spell and spell ~= "" then
			local spellVal = tonumber(spell) or spell
			local result = SpellRange.IsSpellInRange(spellVal, unit)
			if result == nil and type(spellVal) == "number" then
				local spellName = GetSpellInfo(spellVal)
				if spellName then
					result = SpellRange.IsSpellInRange(spellName, unit)
				end
			end
			if result ~= nil then
				return result == 1
			end
		end
		return nil -- spell unknown; use the default logic
	elseif mode == "YARDS" then
		if UnitDistanceSquared then
			local distSq, valid = UnitDistanceSquared(unit)
			if distSq and valid ~= false then
				local yards = fdb.rangeYards or 30
				return distSq <= (yards * yards)
			end
		end
		return nil
	end
	return nil
end

function UF:UpdateRange(unit)
	if not self.Fader then return end
	local alpha

	unit = unit or self.unit

	-- Per-frame override from this unit's Fader settings
	local overrideResult
	if unit and not self.forceInRange and not self.forceNotInRange and unit ~= "player" then
		local fdb = self.db and self.db.fader
		local mode = fdb and fdb.rangeDistance
		if mode and mode ~= "DEFAULT" then
			overrideResult = CheckDistanceMode(unit, mode, fdb)
		end
	end

	if self.forceInRange or unit == "player" then
		alpha = self.Fader.MaxAlpha
	elseif self.forceNotInRange then
		alpha = self.Fader.MinAlpha
	elseif overrideResult ~= nil then
		alpha = (overrideResult and self.Fader.MaxAlpha) or self.Fader.MinAlpha
	elseif unit then
		if UnitCanAttack("player", unit) then
			alpha = ((enemyIsInRange(unit) or enemyIsInLongRange(unit)) and self.Fader.MaxAlpha) or self.Fader.MinAlpha
		elseif UnitIsUnit(unit, "pet") then
			alpha = (petIsInRange(unit) and self.Fader.MaxAlpha) or self.Fader.MinAlpha
		else
			alpha = (UnitIsConnected(unit) and friendlyIsInRange(unit) and self.Fader.MaxAlpha) or self.Fader.MinAlpha
		end
	else
		alpha = self.Fader.MaxAlpha
	end

	self.Fader.RangeAlpha = alpha
end