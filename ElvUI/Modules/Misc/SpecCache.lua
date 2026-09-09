local E, L, V, P, G = unpack(select(2, ...)); --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local SC = E:NewModule("SpecCache", "AceEvent-3.0")

--Lua functions
local ipairs, pairs, next, type, pcall = ipairs, pairs, next, type, pcall
local tinsert, tremove = table.insert, table.remove
--WoW API / Variables
local CanInspect = CanInspect
local CreateFrame = CreateFrame
local GetNumPartyMembers = GetNumPartyMembers
local GetNumRaidMembers = GetNumRaidMembers
local GetTime = GetTime
local InCombatLockdown = InCombatLockdown
local UnitClass = UnitClass
local UnitExists = UnitExists
local UnitGUID = UnitGUID
local UnitIsPlayer = UnitIsPlayer
local UnitIsUnit = UnitIsUnit
local UnitIsVisible = UnitIsVisible
local UnitLevel = UnitLevel

--[[
	Group spec inspector (Conquest of Azeroth)

	The dungeon finder only knows TANK/HEALER/DAMAGER, so a Support-spec player
	(e.g. a Farstrider Ranger who queued as DPS) shows a DPS role icon unless we
	find out their actual spec. This module resolves group members' specs in the
	background using the CoA client APIs - no hovering required:

	1. UnitSpecAndIcon(unit)                   - free, works when the client
	   already knows the spec (recently inspected / nearby data)
	2. C_CharacterAdvancement.InspectUnit(unit) - async spec inspection, read
	   back via GetInspectInfo/GetInspectedBuild and decoded through the
	   level-10 passive -> specID map (map sourced from the SpecTip addon by
	   Netherborne, used with thanks)

	Results land in E.SupportSpecCache[guid] = true/false, which
	E:GetUnitRole() consults first. On resolution the role icons and role
	sorting refresh automatically. Everything is guarded so realms without
	these APIs simply never activate the module.
]]

E.SupportSpecCache = {} -- guid -> true (support spec) / false (known non-support)

local resolveTime = {} -- guid -> GetTime() of resolution
local attempts = {} -- guid -> failed inspect attempts
local RESOLVE_TTL = 300 -- re-check specs every 5 minutes (respecs)
local MAX_ATTEMPTS = 3
local RETRY_COOLDOWN = 120 -- after giving up, wait this long before retrying
local INSPECT_SPACING = 2.5 -- seconds between inspect requests
local INSPECT_READ_DELAY = 1.0 -- wait after InspectUnit before reading results

-- CoA client APIs (guarded; nil on other realms/clients)
local UnitSpecAndIcon = _G.UnitSpecAndIcon
local IsCustomClass = _G.IsCustomClass
local CA = _G.C_CharacterAdvancement
local CI = _G.C_ClassInfo

local hasDirectAPI = type(UnitSpecAndIcon) == "function"
local hasInspectAPI = CA and type(CA.InspectUnit) == "function" and type(CA.GetInspectInfo) == "function" and type(CA.GetInspectedBuild) == "function" and type(CA.GetEntryByInternalID) == "function"

-- Level-10 passive internal spellID -> specID (from SpecTip by Netherborne)
local PASSIVE_TO_SPEC = {
	-- PYROMANCER
	[92126] = 37, [92124] = 38, [300755] = 39,
	-- CULTIST
	[92131] = 40, [92130] = 41, [680750] = 96, [92129] = 42,
	-- VENOMANCER
	[92144] = 52, [92143] = 53, [92142] = 54, [680800] = 101,
	-- WITCH HUNTER
	[707064] = 97, [92093] = 11, [92091] = 10, [92094] = 12,
	-- REAPER
	[92145] = 56, [92147] = 57, [92146] = 55,
	-- TEMPLAR
	[92111] = 24, [92109] = 22, [92108] = 23,
	-- WITCH DOCTOR
	[92086] = 4, [92085] = 6, [92084] = 5,
	-- FELSWORN
	[92089] = 9, [92087] = 8, [92088] = 7,
	-- BARBARIAN
	[92083] = 3, [92082] = 1, [92081] = 2,
	-- PRIMALIST
	[92150] = 58, [92148] = 59, [92149] = 95, [680395] = 60,
	-- SUN CLERIC
	[707072] = 47, [92135] = 46, [92137] = 48, [92136] = 98,
	-- RANGER
	[92115] = 28, [92117] = 29, [92116] = 30,
	-- BLOODMAGE
	[92114] = 99, [681078] = 25, [92112] = 26, [92113] = 27,
	-- RUNEMASTER
	[92153] = 61, [92152] = 62, [92154] = 63,
	-- TINKER
	[92141] = 50, [92140] = 51, [92138] = 49,
	-- STORMBRINGER
	[92097] = 13, [92098] = 14, [92096] = 15,
	-- KNIGHT OF XOROTH
	[92101] = 16, [92104] = 17, [92100] = 18,
	-- GUARDIAN
	[92105] = 21, [92107] = 20, [92106] = 19,
	-- NECROMANCER
	[92121] = 34, [92123] = 35, [92122] = 36,
	-- CHRONOMANCER
	[92120] = 33, [92118] = 32, [92119] = 31,
	-- STARCALLER
	[680725] = 45, [92132] = 100, [92133] = 44, [92134] = 43,
}

local function IsSupportSpecID(specID)
	if not specID then return nil end
	if CI and CI.GetSpecInfoByID then
		local ok, info = pcall(CI.GetSpecInfoByID, specID)
		if ok and info then
			if info.Support then return true end
			if info.Name and E.SupportSpecNames and E.SupportSpecNames[info.Name] then return true end
			return false
		end
	end
	return false
end

local function NotifyResolved()
	E:WipeUnitRoleCache()

	local UF = E:GetModule("UnitFrames", true)
	if UF then
		if UF.QueueRoleSortUpdate then
			UF:QueueRoleSortUpdate(0.2)
		end
		if UF.HeaderUpdateSpecificElement then
			for _, group in ipairs({"party", "raid", "raid40"}) do
				if UF[group] then
					pcall(UF.HeaderUpdateSpecificElement, UF, group, "GroupRoleIndicator")
				end
			end
		end
	end
end

local function StoreResult(guid, isSupport)
	local previous = E.SupportSpecCache[guid]
	E.SupportSpecCache[guid] = isSupport and true or false
	resolveTime[guid] = GetTime()
	attempts[guid] = nil

	if previous ~= E.SupportSpecCache[guid] then
		NotifyResolved()
	end
end

-- Attempt the free path: the client may already know the spec
local function TryDirect(unit, guid)
	if not hasDirectAPI then return false end

	local ok, spec = pcall(UnitSpecAndIcon, unit)
	if not ok or not spec then return false end

	local className = UnitClass(unit)
	if spec == className then
		return false -- client doesn't know the spec yet; needs an inspect
	end

	StoreResult(guid, E.SupportSpecNames and E.SupportSpecNames[spec])
	return true
end

-- Read back the async inspect result
local function TryReadInspect(unit, guid)
	local ok, activeSpec = pcall(CA.GetInspectInfo, unit)
	if not ok or not activeSpec then return false end

	local ok2, entries = pcall(CA.GetInspectedBuild, unit, activeSpec)
	if not ok2 or type(entries) ~= "table" then return false end

	for _, v in ipairs(entries) do
		local ok3, entry = pcall(CA.GetEntryByInternalID, v.EntryId)
		if ok3 and entry and entry.Spells then
			local spellID = entry.Spells[v.Rank]
			local specID = spellID and PASSIVE_TO_SPEC[spellID]
			if specID then
				StoreResult(guid, IsSupportSpecID(specID))
				return true
			end
		end
	end

	return false
end

----------------------------------------------------------------------------
-- Queue driver
----------------------------------------------------------------------------
local queue = {} -- array of {guid = guid, unit = unit}
local queued = {} -- guid -> true (dedupe)
local driver = CreateFrame("Frame")
driver:Hide()
driver.wait = 0
driver.pendingRead = nil -- {guid, unit, readAt, reads}

local UnitIsConnected = UnitIsConnected

local function UnitIsInspectable(unit)
	if not UnitExists(unit) or not UnitIsPlayer(unit) or UnitIsUnit(unit, "player") then return false end
	if not UnitIsVisible(unit) then return false end
	if UnitIsConnected and not UnitIsConnected(unit) then return false end
	-- Client-side inspectability gate, error-protected: on this custom client
	-- CanInspect may run client Lua (SharedXML) that can itself error on some
	-- units - never let that escape into the user's error frame.
	if CanInspect then
		local ok, can = pcall(CanInspect, unit)
		if ok and not can then return false end
	end
	if IsCustomClass and not IsCustomClass(unit) then return false end
	if UnitLevel(unit) < 10 then return false end
	return true
end

local function Enqueue(unit)
	local guid = UnitGUID(unit)
	if not guid or queued[guid] then return end

	-- fresh enough?
	local resolvedAt = resolveTime[guid]
	if resolvedAt and (GetTime() - resolvedAt) < RESOLVE_TTL then return end

	-- gave up recently?
	if attempts[guid] and attempts[guid] >= MAX_ATTEMPTS then
		if resolvedAt == nil and (GetTime() - (attempts[guid.."_t"] or 0)) < RETRY_COOLDOWN then
			return
		end
		attempts[guid] = nil
	end

	if not UnitIsInspectable(unit) then return end

	queued[guid] = true
	tinsert(queue, {guid = guid, unit = unit})
	driver:Show()
end

driver:SetScript("OnUpdate", function(self, elapsed)
	self.wait = self.wait - elapsed
	if self.wait > 0 then return end
	self.wait = 0.25

	if E.global and E.global.unitframe and E.global.unitframe.specInspectorDisabled then
		self:Hide()
		return
	end
	if InCombatLockdown() then return end -- resume after combat
	if _G.InspectFrame and _G.InspectFrame:IsShown() then return end

	-- Phase 2: a pending inspect read
	local pending = self.pendingRead
	if pending then
		if GetTime() < pending.readAt then return end

		local unit = pending.unit
		local guidNow = UnitExists(unit) and UnitGUID(unit)
		if guidNow == pending.guid and TryReadInspect(unit, pending.guid) then
			self.pendingRead = nil
		else
			pending.reads = pending.reads + 1
			if pending.reads >= 3 or guidNow ~= pending.guid then
				attempts[pending.guid] = (attempts[pending.guid] or 0) + 1
				attempts[pending.guid.."_t"] = GetTime()
				self.pendingRead = nil
			else
				pending.readAt = GetTime() + INSPECT_READ_DELAY
				return
			end
		end
	end

	-- Phase 1: pick the next queued unit
	local item = tremove(queue, 1)
	if not item then
		if not self.pendingRead then self:Hide() end
		return
	end
	queued[item.guid] = nil

	local unit = item.unit
	if not UnitExists(unit) or UnitGUID(unit) ~= item.guid or not UnitIsInspectable(unit) then
		return -- roster moved on; roster events will re-enqueue as needed
	end

	if TryDirect(unit, item.guid) then
		return
	end

	if hasInspectAPI then
		local ok = pcall(CA.InspectUnit, unit)
		if ok then
			self.pendingRead = {guid = item.guid, unit = unit, readAt = GetTime() + INSPECT_READ_DELAY, reads = 0}
			self.wait = INSPECT_SPACING
		else
			attempts[item.guid] = (attempts[item.guid] or 0) + 1
			attempts[item.guid.."_t"] = GetTime()
		end
	end
end)

local function IsUnresolvedMember(unit)
	if not UnitExists(unit) or not UnitIsPlayer(unit) or UnitIsUnit(unit, "player") then return false end
	if IsCustomClass and not IsCustomClass(unit) then return false end
	local guid = UnitGUID(unit)
	return guid and E.SupportSpecCache[guid] == nil
end

local function RescanTick()
	SC.rescanScheduled = nil
	SC:ScanGroup()
end

function SC:ScanGroup()
	if not (hasDirectAPI or hasInspectAPI) then return end
	if E.global and E.global.unitframe and E.global.unitframe.specInspectorDisabled then return end

	local anyUnresolved = false

	local numRaid = GetNumRaidMembers()
	if numRaid > 0 then
		for i = 1, numRaid do
			local unit = "raid"..i
			Enqueue(unit)
			if not anyUnresolved and IsUnresolvedMember(unit) then anyUnresolved = true end
		end
	else
		for i = 1, GetNumPartyMembers() do
			local unit = "party"..i
			Enqueue(unit)
			if not anyUnresolved and IsUnresolvedMember(unit) then anyUnresolved = true end
		end
	end

	-- Members can be uninspectable at group-form time (still zoning in, out
	-- of range, in combat). Keep re-scanning on a slow cadence until everyone
	-- is resolved instead of waiting for the next roster change.
	if anyUnresolved and not SC.rescanScheduled then
		SC.rescanScheduled = true
		E:Delay(10, RescanTick)
	end
end

function SC:PLAYER_REGEN_ENABLED()
	if #queue > 0 or driver.pendingRead then
		driver:Show()
	end
end

local function InspectorEnabled()
	return not (E.global and E.global.unitframe and E.global.unitframe.specInspectorDisabled)
end

function SC:Initialize()
	if not (hasDirectAPI or hasInspectAPI) then return end -- not a CoA client

	self:RegisterEvent("PARTY_MEMBERS_CHANGED", "ScanGroup")
	self:RegisterEvent("RAID_ROSTER_UPDATE", "ScanGroup")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "ScanGroup")
	self:RegisterEvent("PLAYER_REGEN_ENABLED")
end

-- /especs - toggle the background spec inspector (for error attribution:
-- if a client error stops while this is off, the inspector triggers it)
SLASH_ESPECS1 = "/especs"
_G.SlashCmdList.ESPECS = function(msg)
	msg = (msg or ""):lower():gsub("%s+", "")
	local db = E.global.unitframe
	if msg == "on" then
		db.specInspectorDisabled = nil
	elseif msg == "off" then
		db.specInspectorDisabled = true
	else
		db.specInspectorDisabled = not db.specInspectorDisabled or nil
	end

	if db.specInspectorDisabled then
		driver:Hide()
		driver.pendingRead = nil
		for i = #queue, 1, -1 do queue[i] = nil end
		for k in pairs(queued) do queued[k] = nil end
		E:Print("Spec inspector |cffff4444OFF|r (support detection paused; role icons fall back to queued roles)")
	else
		E:Print("Spec inspector |cff00ff00ON|r")
		SC:ScanGroup()
	end
end

E:RegisterModule(SC:GetName())
