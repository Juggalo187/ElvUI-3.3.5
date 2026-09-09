local E, L, V, P, G = unpack(select(2, ...)); --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local UF = E:GetModule("UnitFrames")

--Lua functions
local ipairs, pairs, next = ipairs, pairs, next
local gmatch, gsub, strupper = string.gmatch, string.gsub, string.upper
local tinsert, tsort, tconcat, twipe = table.insert, table.sort, table.concat, table.wipe
--WoW API / Variables
local CreateFrame = CreateFrame
local GetNumPartyMembers = GetNumPartyMembers
local GetNumRaidMembers = GetNumRaidMembers
local GetRaidRosterInfo = GetRaidRosterInfo
local InCombatLockdown = InCombatLockdown
local UnitName = UnitName

--[[
	Stable role sorting ("Sort By: ROLE" / ASSIGNEDROLE)

	How it works: instead of asking the secure group header to bucket units by
	role (which on this 3.3.5 client required overriding the global
	UnitGroupRolesAssigned and produced unstable, reshuffling orders), ElvUI now
	computes the full ordering itself and hands the header a NAMELIST:

	  header.nameList   = "Tankguy,Healgirl,Dpsdude,..."
	  header.sortMethod = "NAMELIST"
	  header.groupBy    = nil, header.groupFilter = nil

	The secure header then displays units strictly in list order. The order is
	fully deterministic: role bucket (user-configured order, incl. SUPPORT and
	the PLAYER slot) then alphabetical within a bucket. Roles come from
	E:GetUnitRole which understands CoA Support specs.

	Combat: header attributes are protected, so updates during combat are
	queued and applied on PLAYER_REGEN_ENABLED. A member joining mid-combat
	appears once combat drops (same limitation the stock header config has).
]]

UF.roleSortHeaders = {} -- header -> true, maintained by Configure_Groups + ConfigureRoleSortHeader

local DEFAULT_ORDER = "TANK,HEALER,DAMAGER,SUPPORT,NONE"
local VALID_TOKENS = {TANK = true, HEALER = true, DAMAGER = true, SUPPORT = true, NONE = true, PLAYER = true}

local roleRank = {}
local sortNames = {}
local sortRanks = {}
local memoOrderRaw, memoSeparate, memoGroupKind -- BuildRoleRank memo

-- Parses the user's role order CSV into roleRank[token] = position.
-- Returns whether the PLAYER slot is active for this group type.
local function BuildRoleRank(groupName)
	local order, separatePlayer
	if groupName == "party" then
		order = E.db.unitframe.roleSortOrderParty
		separatePlayer = E.db.unitframe.roleSortPlayerSeparatelyParty
	else
		order = E.db.unitframe.roleSortOrderRaid
		separatePlayer = E.db.unitframe.roleSortPlayerSeparatelyRaid
	end
	-- The order string and player-slot flag almost never change between
	-- ticks; skip the re-parse (string allocs + gmatch loop) when unchanged
	local groupKind = (groupName == "party") and 1 or 2
	if order == memoOrderRaw and separatePlayer == memoSeparate and groupKind == memoGroupKind then
		return separatePlayer
	end
	memoOrderRaw, memoSeparate, memoGroupKind = order, separatePlayer, groupKind

	if not order or order == "" then order = DEFAULT_ORDER end

	order = strupper(order)
	order = gsub(order, "%s+", "")
	order = gsub(order, "DPS", "DAMAGER")

	twipe(roleRank)
	local rank = 0
	for token in gmatch(order, "[^,]+") do
		if VALID_TOKENS[token] and not roleRank[token] and (token ~= "PLAYER" or separatePlayer) then
			rank = rank + 1
			roleRank[token] = rank
		end
	end

	-- Roles missing from the user's string still need a deterministic slot
	if not roleRank.TANK then rank = rank + 1 roleRank.TANK = rank end
	if not roleRank.HEALER then rank = rank + 1 roleRank.HEALER = rank end
	if not roleRank.DAMAGER then rank = rank + 1 roleRank.DAMAGER = rank end
	if not roleRank.SUPPORT then rank = rank + 1 roleRank.SUPPORT = rank end
	if not roleRank.NONE then rank = rank + 1 roleRank.NONE = rank end

	return separatePlayer
end

-- Deterministic comparator: role bucket first, then alphabetical.
-- (table.sort is not stable; the name tiebreak is what makes the order
-- reproducible between updates instead of reshuffling equal entries.)
local function NameSort(a, b)
	local ra, rb = sortRanks[a], sortRanks[b]
	if ra ~= rb then return ra < rb end
	return a < b
end

local function AddMember(name, unit, separatePlayer, playerName)
	local rank
	if separatePlayer and name == playerName and roleRank.PLAYER then
		rank = roleRank.PLAYER
	else
		rank = roleRank[E:GetUnitRole(unit)] or roleRank.NONE
	end
	sortRanks[name] = rank
	tinsert(sortNames, name)
end

local function BuildNameList(header)
	local groupName = header.groupName
	local separatePlayer = BuildRoleRank(groupName)
	local playerName = UnitName("player")

	twipe(sortNames)
	twipe(sortRanks)

	local numRaid = GetNumRaidMembers()
	if numRaid > 0 and groupName ~= "party" then
		local idx = header.roleSortGroupIndex or 0
		for i = 1, numRaid do
			local name, _, subgroup = GetRaidRosterInfo(i)
			if name and (idx == 0 or subgroup == idx) then
				AddMember(name, "raid"..i, separatePlayer, playerName)
			end
		end
	else
		-- party header, or a raid-style header shown while only in a party
		if header.roleSortShowPlayer ~= false and playerName then
			AddMember(playerName, "player", separatePlayer, playerName)
		end
		for i = 1, GetNumPartyMembers() do
			local unit = "party"..i
			local name = UnitName(unit)
			if name then
				AddMember(name, unit, separatePlayer, playerName)
			end
		end
	end

	tsort(sortNames, NameSort)
	return tconcat(sortNames, ",")
end

-- Deferred/queued update driver (also the combat queue)
local driver = CreateFrame("Frame")
driver:Hide()
driver.combatQueued = false

local function Arm(delay)
	if not driver.wait or driver.wait > delay or not driver:IsShown() then
		driver.wait = delay
	end
	driver:Show()
end

function UF:ApplyRoleNameList(header)
	if not UF.roleSortHeaders[header] then return end

	if InCombatLockdown() then
		driver.combatQueued = true
		return
	end

	local nameList = BuildNameList(header)
	local changed = false

	-- compare-before-set: every SetAttribute triggers a secure header update
	if header:GetAttribute("groupFilter") ~= nil then
		header:SetAttribute("groupFilter", nil)
		changed = true
	end
	if header:GetAttribute("groupBy") ~= nil then
		header:SetAttribute("groupBy", nil)
		header:SetAttribute("groupingOrder", nil)
		changed = true
	end
	if header:GetAttribute("sortMethod") ~= "NAMELIST" then
		header:SetAttribute("sortMethod", "NAMELIST")
		changed = true
	end
	if header:GetAttribute("nameList") ~= nameList then
		header:SetAttribute("nameList", nameList)
		changed = true
	end

	return changed
end

-- Public: queue a re-sort (used by the spec inspector when a Support spec resolves)
function UF:QueueRoleSortUpdate(delay)
	if next(UF.roleSortHeaders) then
		driver.stableCount = 0
		Arm(delay or 0.25)
	end
end

-- Entry point used by UF.headerGroupBy["ASSIGNEDROLE"]
function UF:ConfigureRoleSortHeader(header)
	UF.roleSortHeaders[header] = true
	UF:ApplyRoleNameList(header)
	driver.stableCount = 0
	Arm(0.25) -- roster/role data may settle right after configuration
end

driver:SetScript("OnUpdate", function(self, elapsed)
	self.wait = (self.wait or 0) - elapsed
	if self.wait > 0 then return end
	self:Hide()

	if not next(UF.roleSortHeaders) then return end

	if InCombatLockdown() then
		self.combatQueued = true
		return
	end

	local anyChanged = false
	for header in pairs(UF.roleSortHeaders) do
		if UF:ApplyRoleNameList(header) then
			anyChanged = true
		end
	end

	-- Async spec data (inspects, Details cache) can classify SUPPORT late;
	-- keep a backoff recheck while role sorting is active, then go idle when stable.
	if anyChanged then
		self.stableCount = 0
		Arm(5)
	else
		self.stableCount = (self.stableCount or 0) + 1
		if self.stableCount == 1 then
			Arm(15)
		elseif self.stableCount == 2 then
			Arm(60)
		end
	end
end)

driver:RegisterEvent("PARTY_MEMBERS_CHANGED")
driver:RegisterEvent("RAID_ROSTER_UPDATE")
driver:RegisterEvent("PLAYER_ROLES_ASSIGNED")
driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:RegisterEvent("PLAYER_REGEN_ENABLED")
driver:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_REGEN_ENABLED" then
		if self.combatQueued then
			self.combatQueued = false
			Arm(0.1)
		end
		return
	end

	if event == "PLAYER_ROLES_ASSIGNED" or event == "PLAYER_ENTERING_WORLD" then
		E:WipeUnitRoleCache()
	end

	if next(UF.roleSortHeaders) then
		Arm(0.25)
	end
end)
