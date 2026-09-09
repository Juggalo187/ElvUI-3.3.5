local E, L, V, P, G = unpack(ElvUI)
local AT = E:NewModule("AuraTracker", "AceEvent-3.0")
E.AuraTracker = AT

--Lua functions
local ipairs, pairs = ipairs, pairs
local tinsert, tsort, twipe = table.insert, table.sort, table.wipe
--WoW API / Variables
local GetTime = GetTime
local InCombatLockdown = InCombatLockdown
local GetNumPartyMembers = GetNumPartyMembers
local GetNumRaidMembers = GetNumRaidMembers
local UnitBuff, UnitDebuff = UnitBuff, UnitDebuff
local UnitExists = UnitExists
local UnitInParty, UnitInRaid = UnitInParty, UnitInRaid
local UnitIsUnit = UnitIsUnit

--[[
	Performance notes (this module used to be a raid hotspot):
	- Recording is dictionary-based: one hash write per aura, no array shifting,
	  no index-map rebuilds. The old implementation did table.remove +
	  table.insert(1) + a full O(n) reindex for EVERY aura on EVERY UNIT_AURA,
	  which at raid scale meant thousands of operations per event storm.
	- The sorted arrays the Filters config reads (AT.playerBuffs etc.) are only
	  (re)built lazily via AT:RebuildLists() when the config UI asks for them.
	- Per-unit scans are throttled: UNIT_AURA bursts for the same unit within
	  SCAN_INTERVAL collapse into one scan.
	- UNIT_AURA is unregistered entirely while the tracker is disabled.
]]

local MAX_ENTRIES = 100
local SCAN_INTERVAL = 0.25

-- Public sorted arrays (most recent first), rebuilt on demand for the config UI
AT.playerBuffs = {}
AT.playerDebuffs = {}
AT.groupBuffs = {}
AT.groupDebuffs = {}

-- Internal storage: spellId -> entry
local store = {
	playerBuffs = {},
	playerDebuffs = {},
	groupBuffs = {},
	groupDebuffs = {},
}
local counts = {
	playerBuffs = 0,
	playerDebuffs = 0,
	groupBuffs = 0,
	groupDebuffs = 0,
}
local listsDirty = true

local lastScan = {} -- unit -> GetTime() of last scan

local function Record(category, name, icon, count, duration, spellId, unit, index, isDebuff)
	if not name or not spellId then return end

	local bucket = store[category]
	local entry = bucket[spellId]
	local now = GetTime()

	if entry then
		entry.count = count or 0
		entry.duration = duration or 0
		entry.unit = unit
		entry.index = index
		entry.time = now
	else
		bucket[spellId] = {
			name = name,
			icon = icon,
			count = count or 0,
			duration = duration or 0,
			spellId = spellId,
			unit = unit,
			index = index,
			isDebuff = isDebuff,
			time = now,
		}
		counts[category] = counts[category] + 1

		-- Evict the oldest entry when over capacity (rare: only on new spellIds)
		if counts[category] > MAX_ENTRIES then
			local oldestId, oldestTime
			for id, e in pairs(bucket) do
				if not oldestTime or e.time < oldestTime then
					oldestId, oldestTime = id, e.time
				end
			end
			if oldestId then
				bucket[oldestId] = nil
				counts[category] = counts[category] - 1
			end
		end
	end

	listsDirty = true
end

local function SortByTimeDesc(a, b)
	return a.time > b.time
end

-- Rebuilds the public sorted arrays. Called by the Filters config UI before it
-- renders the columns; costs nothing during combat.
function AT:RebuildLists()
	if not listsDirty then return end

	for category, bucket in pairs(store) do
		local list = AT[category]
		twipe(list)
		for _, entry in pairs(bucket) do
			tinsert(list, entry)
		end
		tsort(list, SortByTimeDesc)
	end

	listsDirty = false
end

local function IsGroupUnit(unit)
	if not unit then return false end
	if UnitIsUnit(unit, "player") or UnitIsUnit(unit, "pet") then return true end

	local onlyInGroup = E.global.unitframe.auraTrackerOnlyInGroup
	if onlyInGroup == nil then onlyInGroup = true end

	if onlyInGroup then
		return (UnitInParty(unit) or UnitInRaid(unit)) and true or false
	end
	return true
end

function AT:ScanUnitAuras(unit, force)
	if E.global.unitframe.auraTrackerEnable == false then return end
	if not unit or not UnitExists(unit) then return end

	-- Collapse UNIT_AURA bursts for the same unit (throttled further during combat)
	local now = GetTime()
	local interval = InCombatLockdown() and 1.5 or SCAN_INTERVAL
	if not force and lastScan[unit] and (now - lastScan[unit]) < interval then return end
	lastScan[unit] = now

	if not IsGroupUnit(unit) then return end

	local isPlayer = UnitIsUnit(unit, "player") or UnitIsUnit(unit, "pet")
	local buffCategory = isPlayer and "playerBuffs" or "groupBuffs"
	local debuffCategory = isPlayer and "playerDebuffs" or "groupDebuffs"

	local i = 1
	while true do
		local name, _, icon, count, _, duration, _, _, _, _, spellId = UnitBuff(unit, i)
		if not name then break end
		if spellId then
			Record(buffCategory, name, icon, count, duration, spellId, unit, i, false)
		end
		i = i + 1
	end

	i = 1
	while true do
		local name, _, icon, count, _, duration, _, _, _, _, spellId = UnitDebuff(unit, i)
		if not name then break end
		if spellId then
			Record(debuffCategory, name, icon, count, duration, spellId, unit, i, true)
		end
		i = i + 1
	end
end

function AT:UNIT_AURA(event, unit)
	if not unit then return end
	AT:ScanUnitAuras(unit)
end

function AT:ScanGroup()
	twipe(lastScan) -- roster changed; unit tokens map to different players now

	AT:ScanUnitAuras("player", true)
	AT:ScanUnitAuras("pet", true)

	if GetNumRaidMembers() > 0 then
		for j = 1, GetNumRaidMembers() do
			AT:ScanUnitAuras("raid"..j, true)
		end
	elseif GetNumPartyMembers() > 0 then
		for j = 1, GetNumPartyMembers() do
			AT:ScanUnitAuras("party"..j, true)
		end
	end
end

function AT:PLAYER_ENTERING_WORLD()
	AT:ScanGroup()
end

-- Registers/unregisters the hot event based on the enable setting.
-- Called from Initialize and from the Filters config toggle.
function AT:UpdateRegistration()
	if E.global.unitframe.auraTrackerEnable == false then
		self:UnregisterEvent("UNIT_AURA")
	elseif not self.auraEventRegistered then
		self:RegisterEvent("UNIT_AURA")
	end
	self.auraEventRegistered = E.global.unitframe.auraTrackerEnable ~= false
end

function AT:Initialize()
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("PARTY_MEMBERS_CHANGED", "ScanGroup")
	self:RegisterEvent("RAID_ROSTER_UPDATE", "ScanGroup")
	self:UpdateRegistration()
	AT:ScanGroup()
end

E:RegisterModule(AT:GetName())
