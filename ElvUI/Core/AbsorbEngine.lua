--[[
	AbsorbEngine - shared absorb shield detection for UnitFrames and Nameplates.

	Replaces the duplicated GetUnitShields implementations that lived in
	Modules/UnitFrames/Elements/HealComm.lua and Modules/Nameplates/Elements/Health.lua.

	Design goals (raid performance):
	- Whitelist-first classification: the user-editable "Absorb Shields" aura filter
	  plus the built-in KNOWN_SHIELDS list decide what is a shield. No tooltip work
	  for whitelisted or excluded buffs.
	- Tooltip discovery of unknown shields is OPT-IN per group size
	  (absorbDiscoverySolo/Party/Raid) and defaults OFF in raids.
	- Zero allocations in the steady state: per-unit result tables and shield entry
	  tables are reused between updates; a version counter tells callers whether
	  anything actually changed so they can skip re-layout entirely.
	- Optional fast path: absorbTrustNative skips all buff scanning whenever
	  UnitGetTotalAbsorbs() reports 0 (test on your realm before enabling).
]]

local E, L, V, P, G = unpack(select(2, ...)) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB

--Lua functions
local ipairs, pairs, type, tonumber, tostring = ipairs, pairs, type, tonumber, tostring
local floor = math.floor
local format, gmatch, gsub, lower, match, strfind, strlen, strsub = string.format, string.gmatch, string.gsub, string.lower, string.match, string.find, string.len, string.sub
--WoW API / Variables
local CreateFrame = CreateFrame
local GetTime = GetTime
local GetNumPartyMembers = GetNumPartyMembers
local GetNumRaidMembers = GetNumRaidMembers
local UnitBuff = UnitBuff
local UnitExists = UnitExists
local UnitGetTotalAbsorbs = UnitGetTotalAbsorbs
local UnitGUID = UnitGUID
local UnitIsUnit = UnitIsUnit
local UnitManaMax = UnitManaMax
local UnitName = UnitName

local Engine = {}
E.AbsorbEngine = Engine
Engine.REVISION = 5 -- shown by /eabsorb; bump on engine changes

-- Kept as a global for backwards compatibility with layouts/user code
_G.ElvUI_AbsorbSettings = _G.ElvUI_AbsorbSettings or {
	Colors = {
		{r = 0.3, g = 0.7, b = 1.0, a = 0.6},
		{r = 0.5, g = 0.5, b = 1.0, a = 0.6},
		{r = 0.2, g = 0.8, b = 0.8, a = 0.6},
		{r = 0.6, g = 0.4, b = 0.9, a = 0.6},
		{r = 0.4, g = 0.7, b = 0.5, a = 0.6},
	},
	IconSize = 12,
	MinIconWidth = 18,
	SeparatorWidth = 1.5,
	SeparatorColor = {r = 1, g = 1, b = 1, a = 0.6},
}
Engine.Settings = _G.ElvUI_AbsorbSettings

local scannerTooltip = _G.ElvUI_ShieldScannerTooltip or CreateFrame("GameTooltip", "ElvUI_ShieldScannerTooltip", nil, "GameTooltipTemplate")

-- Built-in fallback whitelist. The user-editable "Absorb Shields" aura filter
-- (Filters config) takes precedence over this list in both directions.
local KNOWN_SHIELDS = {
	["Power Word: Shield"] = true,
	["Void Shield"] = true,
	["Forbidden Ritual"] = true,
	["Hateforged Barrier"] = true,
	["Phoenix Shield"] = true,
	["Sacred Shield"] = true,
	["Ice Barrier"] = true,
	["Mana Shield"] = true,
	["Anti-Magic Shell"] = true,
	["Savage Defense"] = true,
	["Divine Aegis"] = true,
	["Blood Shield"] = true,
	["Protection"] = true,
	["Illuminated Healing"] = true,
	["Guard"] = true,
	["Fire Ward"] = true,
	["Frost Ward"] = true,
	["Shadow Ward"] = true,
}
Engine.KNOWN_SHIELDS = KNOWN_SHIELDS

-- Buffs that contain shield/protection wording but are never damage absorbs
local EXCLUDED_BUFFS = {
	["Lightning Shield"] = true,
	["Water Shield"] = true,
	["Earth Shield"] = true,
	["Shield Wall"] = true,
	["Shield Block"] = true,
	["Blessing of Protection"] = true,
	["Hand of Protection"] = true,
	["Divine Protection"] = true,
	["Aeon of Protection"] = true,
}
Engine.EXCLUDED_BUFFS = EXCLUDED_BUFFS

----------------------------------------------------------------------------
-- User filter lookup (rebuilt lazily; O(1) per-buff checks in the hot path)
----------------------------------------------------------------------------
local filterByID, filterByName = {}, {}
local filtersDirty = true

function Engine:MarkFiltersDirty()
	filtersDirty = true
end

local function RebuildFilterLookup()
	for k in pairs(filterByID) do filterByID[k] = nil end
	for k in pairs(filterByName) do filterByName[k] = nil end

	local filter = E.global and E.global.unitframe and E.global.unitframe.aurafilters and E.global.unitframe.aurafilters["Absorb Shields"]
	if filter and filter.spells then
		for key, value in pairs(filter.spells) do
			local enabled = (type(value) == "table" and value.enable ~= false) or (type(value) ~= "table" and value and true)
			if type(key) == "number" then
				filterByID[key] = enabled
			else
				filterByName[key] = enabled
			end
		end
	end

	filtersDirty = false
end

-- Session discovery cache: buff name -> true (is a shield) / false (is not)
local shieldCache = {}
-- Tooltip scan attempts per buff name; give up after MAX_SCAN_ATTEMPTS
local scanAttempts = {}
local MAX_SCAN_ATTEMPTS = 3

-- Classification result: true (shield), false (not a shield), nil (unknown)
local function ClassifyBuff(name, spellId)
	if EXCLUDED_BUFFS[name] or strfind(name, "Protector", 1, true) then return false end

	-- Explicit user filter entries override everything
	if spellId then
		local byId = filterByID[spellId]
		if byId ~= nil then return byId end
	end
	local byName = filterByName[name]
	if byName ~= nil then return byName end

	if KNOWN_SHIELDS[name] then return true end

	return shieldCache[name] -- true / false / nil (never seen)
end

function Engine:IsKnownShield(name, spellId)
	if filtersDirty then RebuildFilterLookup() end
	return ClassifyBuff(name, spellId) == true
end

----------------------------------------------------------------------------
-- Tooltip discovery (only used when discovery is enabled for the group size)
----------------------------------------------------------------------------
local function ParseAbsorbFromLine(lineText)
	local lowerText = lower(lineText)

	-- Only lines that actually talk about ABSORBING qualify. The old fallback
	-- patterns (any number followed by "damage", or any bare number on a
	-- damage/protect line) matched unrelated buffs - "Deals X damage to
	-- attackers", stat buffs - and turned them into phantom shield segments.
	if not strfind(lowerText, "absorb", 1, true) then
		return nil
	end

	local valStr = match(lowerText, "absorb[a-z]*%s+up%s+to%s+(%d[%d%.,]*)")
		or match(lowerText, "absorb[a-z]*%s+a%s+maximum%s+of%s+(%d[%d%.,]*)")
		or match(lowerText, "absorb[a-z]*%s+(%d[%d%.,]*)")
		or match(lowerText, "(%d[%d%.,]*)%s+damage%s+absorb")
		or match(lowerText, "absorb[a-z]*[^%d]*(%d[%d%.,]*)")
	if valStr then
		valStr = gsub(valStr, "[%,%.%s]", "")
		local val = tonumber(valStr)
		if val and val > 0 then return val end
	end

	return nil
end
Engine.ParseAbsorbFromLine = ParseAbsorbFromLine

-- Scans the tooltip of buff `index` on `unit`. Returns:
--   true, amount  -> classified as a shield
--   false         -> classified as not a shield
--   nil           -> tooltip not ready, try again later
local function DiscoverBuff(unit, index, name)
	scannerTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
	scannerTooltip:ClearLines()
	scannerTooltip:SetUnitBuff(unit, index)

	local firstLine = _G.ElvUI_ShieldScannerTooltipTextLeft1 and _G.ElvUI_ShieldScannerTooltipTextLeft1:GetText()
	local secondLine = _G.ElvUI_ShieldScannerTooltipTextLeft2 and _G.ElvUI_ShieldScannerTooltipTextLeft2:GetText()
	local tooltipLoaded = (firstLine and name and strfind(firstLine, name, 1, true) and secondLine and secondLine ~= "")

	if not tooltipLoaded then
		scanAttempts[name] = (scanAttempts[name] or 0) + 1
		if scanAttempts[name] >= MAX_SCAN_ATTEMPTS then
			shieldCache[name] = false -- stop retrying this session
			return false
		end
		return nil
	end

	for j = 2, scannerTooltip:NumLines() do
		local lineObj = _G["ElvUI_ShieldScannerTooltipTextLeft"..j]
		local lineText = lineObj and lineObj:GetText()
		if lineText then
			local val = ParseAbsorbFromLine(lineText)
			if val then
				shieldCache[name] = true
				return true, val
			end
		end
	end

	shieldCache[name] = false
	return false
end

----------------------------------------------------------------------------
-- Group context (drives discovery gating and cache interval)
----------------------------------------------------------------------------
local groupContext = "solo" -- "solo" | "party" | "raid"

local function DiscoveryEnabled()
	local db = E.global and E.global.unitframe
	if not db then return true end
	if groupContext == "raid" then
		return db.absorbDiscoveryRaid == true -- default OFF in raids
	elseif groupContext == "party" then
		return db.absorbDiscoveryParty ~= false
	end
	return db.absorbDiscoverySolo ~= false
end

local function TrustNative()
	local db = E.global and E.global.unitframe
	return db and db.absorbTrustNative == true
end

----------------------------------------------------------------------------
-- Per-unit result caching with table reuse
----------------------------------------------------------------------------
-- caches[1] = full results, caches[2] = personal-only results
local caches = {{}, {}}

local function GetResultSlot(unit, personalOnly)
	local cache = caches[personalOnly and 2 or 1]
	local slot = cache[unit]
	if not slot then
		slot = {shields = {}, count = 0, version = 0, time = 0, total = 0}
		cache[unit] = slot
	end
	return slot
end

local function WipeCaches()
	for _, cache in ipairs(caches) do
		for k in pairs(cache) do cache[k] = nil end
	end
end

-- Working buffer used during a scan, compared against the cached slot afterwards
local work = {}
local workCount = 0

local function WorkEntry()
	workCount = workCount + 1
	local entry = work[workCount]
	if not entry then
		entry = {}
		work[workCount] = entry
	end
	return entry
end

local MAX_SHIELDS = 8 -- more than the 5 display bars; extras collapse into the last bar

local function ScanUnit(unit, personalOnly, totalNativeAbsorb)
	workCount = 0
	local totalParsed = 0
	local minExpiry = nil
	local tooltipScannedThisCall = false
	local discovery = DiscoveryEnabled()

	local isSelfUnit = UnitIsUnit(unit, "player") or UnitIsUnit(unit, "pet") or UnitIsUnit(unit, "vehicle")

	local i = 1
	while true do
		local name, _, icon, _, _, _, expirationTime, unitCaster, _, _, spellId = UnitBuff(unit, i)
		if not name then break end

		local isPlayerCaster = (unitCaster == "player" or unitCaster == "vehicle" or unitCaster == "pet") or (unitCaster == nil and isSelfUnit)

		if (not personalOnly or isPlayerCaster) and workCount < MAX_SHIELDS then
			local entryAdded = false
			-- Special case: Arcane Barrier absorbs 10% of caster max mana
			if name == "Arcane Barrier" or spellId == 1112478 then
				local caster = unitCaster or "player"
				local maxMana = UnitManaMax(caster) or 0
				local amount = floor(maxMana * 0.10)
				if amount <= 0 then amount = 1000 end
				local entry = WorkEntry()
				entry.name, entry.icon, entry.spellId, entry.amount, entry.isPlayer, entry.isFallback = name, icon, spellId, amount, isPlayerCaster, false
				totalParsed = totalParsed + amount
				entryAdded = true
			else
				local classified = ClassifyBuff(name, spellId)

				if classified == nil and discovery and not tooltipScannedThisCall and totalNativeAbsorb > 0 then
					-- Unknown buff while the unit has active absorbs: try to classify it (max 1 tooltip scan per update)
					local isShield, parsedAmount = DiscoverBuff(unit, i, name)
					if isShield ~= nil then tooltipScannedThisCall = true end
					if isShield then
						local entry = WorkEntry()
						entry.name, entry.icon, entry.spellId, entry.amount, entry.isPlayer, entry.isFallback = name, icon, spellId, parsedAmount or 0, isPlayerCaster, false
						if parsedAmount then totalParsed = totalParsed + parsedAmount end
						entryAdded = true
					end
				elseif classified == true then
					local entry = WorkEntry()
					entry.name, entry.icon, entry.spellId, entry.amount, entry.isPlayer, entry.isFallback = name, icon, spellId, 0, isPlayerCaster, false
					entryAdded = true
				end
			end

			if entryAdded and expirationTime and expirationTime > 0 then
				if not minExpiry or expirationTime < minExpiry then
					minExpiry = expirationTime
				end
			end
		end
		i = i + 1
	end

	-- Reconcile amounts with the native total. The native API is the only
	-- authoritative CURRENT value; tooltip-parsed numbers are snapshots from
	-- discovery time and act as weights only. (The old remainder-distribution
	-- could starve a shield to zero width - rendering as "just a line" -
	-- whenever parsed amounts met or exceeded the native total.)
	if workCount > 0 and totalNativeAbsorb > 0 then
		local weightSum, parsedCount = 0, 0
		for k = 1, workCount do
			local amount = work[k].amount
			if amount > 0 then
				weightSum = weightSum + amount
				parsedCount = parsedCount + 1
			end
		end

		local defaultWeight = (parsedCount > 0 and (weightSum / parsedCount)) or 1
		local totalWeight = weightSum + (workCount - parsedCount) * defaultWeight

		local assigned = 0
		for k = 1, workCount do
			local weight = (work[k].amount > 0 and work[k].amount) or defaultWeight
			local share = floor(totalNativeAbsorb * (weight / totalWeight))
			if share < 1 then share = 1 end -- every detected shield stays visible
			work[k].amount = share
			assigned = assigned + share
		end

		-- rounding remainder goes to the first shield
		if assigned < totalNativeAbsorb then
			work[1].amount = work[1].amount + (totalNativeAbsorb - assigned)
		end
	end

	-- Fallback: the API reports an absorb but we couldn't attribute it to any buff (skip when personalOnly is active)
	if not personalOnly and workCount == 0 and totalNativeAbsorb > 0 then
		local entry = WorkEntry()
		entry.name = "Shield"
		entry.icon = "Interface\\Icons\\spell_holy_powerwordshield"
		entry.spellId = nil
		entry.amount = totalNativeAbsorb
		entry.isPlayer = isSelfUnit
		entry.isFallback = true

		local bIdx = 1
		while true do
			local bName, _, bIcon, _, _, _, _, bCaster, _, _, bSpellId = UnitBuff(unit, bIdx)
			if not bName then break end
			if ClassifyBuff(bName, bSpellId) == true then
				entry.name, entry.icon, entry.spellId, entry.isFallback = bName, bIcon, bSpellId, false
				entry.isPlayer = (bCaster == "player" or bCaster == "vehicle" or bCaster == "pet") or (bCaster == nil and isSelfUnit)
				break
			end
			bIdx = bIdx + 1
		end
	end

	return totalParsed, minExpiry
end

-- Copies the work buffer into the slot if contents differ; bumps slot.version on change
local function CommitResult(slot, minExpiry)
	slot.minExpiry = minExpiry
	local changed = slot.count ~= workCount
	if not changed then
		for k = 1, workCount do
			local a, b = slot.shields[k], work[k]
			if not a or a.name ~= b.name or a.spellId ~= b.spellId or a.amount ~= b.amount or a.isPlayer ~= b.isPlayer or a.isFallback ~= b.isFallback or a.icon ~= b.icon then
				changed = true
				break
			end
		end
	end

	if changed then
		for k = 1, workCount do
			local entry = slot.shields[k]
			if not entry then
				entry = {}
				slot.shields[k] = entry
			end
			local b = work[k]
			entry.name, entry.icon, entry.spellId, entry.amount, entry.isPlayer, entry.isFallback = b.name, b.icon, b.spellId, b.amount, b.isPlayer, b.isFallback
		end
		slot.count = workCount
		slot.version = slot.version + 1
	end

	return changed
end

--[[
	Engine:GetUnitShields(unit, personalOnly)

	Returns: shields (array, REUSED - do not keep references), count, version, totalAmount, nativeTotal, minExpiry
	`version` increments only when the shield composition or amounts changed,
	so callers can skip their entire re-layout when it is unchanged.
]]
function Engine:GetUnitShields(unit, personalOnly)
	if filtersDirty then RebuildFilterLookup() end

	local slot = GetResultSlot(unit, personalOnly)
	local now = GetTime()
	local interval = (groupContext == "raid") and 0.25 or 0.1

	-- Unit tokens are REUSED across different characters: "target" stays
	-- "target" while the actual character behind it changes on every target
	-- swap. A cached result must never cross that boundary - this was the
	-- "my shield shows on any target" bug.
	local guid = UnitGUID(unit)
	if slot.guid ~= guid then
		slot.guid = guid
		slot.time = 0
		slot.native = nil -- force a full rescan below
		slot.total = 0
		slot.minExpiry = nil
		if slot.count ~= 0 then
			slot.count = 0
			slot.version = slot.version + 1 -- displays must re-layout/hide
		end
	end

	if not guid then -- unit doesn't exist right now
		return slot.shields, 0, slot.version, 0, 0, nil
	end

	-- Reading the native total is cheap; do it BEFORE the throttle so any
	-- change (shield consumed or expired) bypasses the cache. Without this,
	-- the final absorb event could be served a stale result and nothing would
	-- ever refresh the bars again (the "leftover Power Word: Shield" bug).
	local totalNativeAbsorb = UnitGetTotalAbsorbs and UnitGetTotalAbsorbs(unit) or 0

	if totalNativeAbsorb == slot.native and (now - slot.time) < interval then
		return slot.shields, slot.count, slot.version, slot.total, slot.native or 0, slot.minExpiry
	end
	slot.time = now
	slot.native = totalNativeAbsorb

	-- Fast path: trust the native API when it reports no absorbs
	if totalNativeAbsorb <= 0 and TrustNative() then
		if slot.count ~= 0 then
			slot.count = 0
			slot.version = slot.version + 1
		end
		slot.total = 0
		slot.minExpiry = nil
		return slot.shields, 0, slot.version, 0, 0, nil
	end

	local totalParsed, minExpiry = ScanUnit(unit, personalOnly, totalNativeAbsorb)
	CommitResult(slot, minExpiry)

	local total = 0
	for k = 1, slot.count do
		total = total + slot.shields[k].amount
	end
	slot.total = total
	slot.totalParsed = totalParsed

	return slot.shields, slot.count, slot.version, total, totalNativeAbsorb, slot.minExpiry
end

----------------------------------------------------------------------------
-- Events: track group context, invalidate unit caches on roster changes
----------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
eventFrame:RegisterEvent("RAID_ROSTER_UPDATE")
eventFrame:SetScript("OnEvent", function()
	local newContext
	if GetNumRaidMembers() > 0 then
		newContext = "raid"
	elseif GetNumPartyMembers() > 0 then
		newContext = "party"
	else
		newContext = "solo"
	end
	groupContext = newContext

	-- Unit tokens now point at different players; drop cached results
	WipeCaches()
end)

function Engine:GetGroupContext()
	return groupContext
end

----------------------------------------------------------------------------
-- /eabsorb - quick diagnostic: what does the engine see on a unit?
-- Useful for verifying the "Trust Native Absorb API" toggle: if the native
-- total is 0 while a shield buff is visibly active, the API misses that
-- shield and the toggle should stay off.
----------------------------------------------------------------------------
local function DumpDisplayState(label, frame)
	local pred = frame and frame.HealCommBar
	if not pred then
		E:Print(format("  %s: no HealComm element", label))
		return
	end
	E:Print(format("  %s: visible=%s storedVer=%s unit=%s count(pool shown)=%s watchdog=%s forceUpdate=%s",
		label,
		tostring(pred._shieldsVisible),
		tostring(pred._sv),
		tostring(pred._sunit),
		tostring(pred.shieldPool and ((pred.shieldPool[1] and pred.shieldPool[1]:IsShown()) and "1+" or "0")),
		tostring(pred._watchdogArmed),
		tostring(pred.ForceUpdate ~= nil)))
end

SLASH_EABSORB1 = "/eabsorb"
_G.SlashCmdList.EABSORB = function(msg)
	local unit = (msg and msg ~= "" and msg) or "target"
	if not UnitExists(unit) then unit = "player" end

	-- Loaded code revisions: if these don't all read r5, an old file is loaded
	-- (e.g. the launcher restored its own ElvUI files over the patched ones)
	local UFmod = E:GetModule("UnitFrames", true)
	local NPmod = E:GetModule("NamePlates", true)
	E:Print(format("Revisions: engine r%s | unitframes r%s | nameplates r%s",
		tostring(Engine.REVISION), tostring(UFmod and UFmod.HealCommRevision or "OLD"), tostring(NPmod and NPmod.HealCommRevision or "OLD")))

	local native = UnitGetTotalAbsorbs and UnitGetTotalAbsorbs(unit) or 0
	E:Print(format("Absorb debug for |cff1784d1%s|r (%s):", tostring(UnitName(unit)), unit))
	E:Print(format("  native API total: |cffffff00%d|r | trust native: %s | discovery in %s: %s",
		native, TrustNative() and "|cff00ff00ON|r" or "|cffff4444OFF|r", groupContext, DiscoveryEnabled() and "|cff00ff00ON|r" or "|cffff4444OFF|r"))

	local shields, count = Engine:GetUnitShields(unit, false)
	if count == 0 then
		E:Print("  engine result: no shields")
	else
		for k = 1, count do
			local s = shields[k]
			E:Print(format("  %d. %s (id %s) amount |cffffff00%d|r%s%s",
				k, s.name, tostring(s.spellId), s.amount,
				s.isPlayer and " |cff888888[player-cast]|r" or "",
				s.isFallback and " |cff888888[fallback]|r" or ""))
		end
	end

	-- Display-side state for the two frames that matter when debugging
	DumpDisplayState("player frame", _G.ElvUF_Player)
	DumpDisplayState("target frame", _G.ElvUF_Target)
end
