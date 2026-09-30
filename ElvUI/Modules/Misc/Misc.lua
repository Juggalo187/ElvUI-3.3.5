local E, L, V, P, G = unpack(select(2, ...)) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local M = E:GetModule("Misc")
local Bags = E:GetModule("Bags")

--Lua functions
local ipairs = ipairs
local format = string.format
--WoW API / Variables
local AcceptGroup = AcceptGroup
local CanGuildBankRepair = CanGuildBankRepair
local CanMerchantRepair = CanMerchantRepair
local GetCVarBool, SetCVar = GetCVarBool, SetCVar
local GetFriendInfo = GetFriendInfo
local GetGuildBankMoney = GetGuildBankMoney
local GetGuildBankWithdrawMoney = GetGuildBankWithdrawMoney
local GetGuildRosterInfo = GetGuildRosterInfo
local GetMoney = GetMoney
local GetNumFriends = GetNumFriends
local GetNumGuildMembers = GetNumGuildMembers
local GetNumPartyMembers = GetNumPartyMembers
local GetNumRaidMembers = GetNumRaidMembers
local GetPartyMember = GetPartyMember
local GetRaidRosterInfo = GetRaidRosterInfo
local GetRepairAllCost = GetRepairAllCost
local GuildRoster = GuildRoster
local HideRepairCursor = HideRepairCursor
local InCombatLockdown = InCombatLockdown
local IsInGuild = IsInGuild
local IsInInstance = IsInInstance
local IsShiftKeyDown = IsShiftKeyDown
local LeaveParty = LeaveParty
local PickupInventoryItem = PickupInventoryItem
local RaidNotice_AddMessage = RaidNotice_AddMessage
local RepairAllItems = RepairAllItems
local SendChatMessage = SendChatMessage
local ShowFriends = ShowFriends
local ShowRepairCursor = ShowRepairCursor
local StaticPopup_Hide = StaticPopup_Hide
local UninviteUnit = UninviteUnit
local UnitGUID = UnitGUID
local UnitName = UnitName

local MAX_PARTY_MEMBERS = MAX_PARTY_MEMBERS

do
	local function EventHandler(event)
		if event == "PLAYER_REGEN_DISABLED" then
			UIErrorsFrame:UnregisterEvent("UI_ERROR_MESSAGE")
		else
			UIErrorsFrame:RegisterEvent("UI_ERROR_MESSAGE")
		end
	end

	function M:ToggleErrorHandling()
		if E.db.general.hideErrorFrame then
			self:RegisterEvent("PLAYER_REGEN_ENABLED", EventHandler)
			self:RegisterEvent("PLAYER_REGEN_DISABLED", EventHandler)
		else
			self:UnregisterEvent("PLAYER_REGEN_ENABLED", EventHandler)
			self:UnregisterEvent("PLAYER_REGEN_DISABLED", EventHandler)
		end
	end
end

do
	local interruptMsg = INTERRUPTED.." %s's \124cff71d5ff\124Hspell:%d\124h[%s]\124h\124r!"

	function M:ToggleInterruptAnnounce()
		if E.db.general.interruptAnnounce == "NONE" then
			self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		else
			self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		end
	end

	function M:COMBAT_LOG_EVENT_UNFILTERED(_, _, event, sourceGUID, _, _, _, destName, _, _, _, _, spellID, spellName)
		if not (event == "SPELL_INTERRUPT" and (sourceGUID == E.myguid or sourceGUID == UnitGUID("pet"))) then return end

		if E.db.general.interruptAnnounce == "SAY" then
			SendChatMessage(format(interruptMsg, destName, spellID, spellName), "SAY")
		elseif E.db.general.interruptAnnounce == "EMOTE" then
			SendChatMessage(format(interruptMsg, destName, spellID, spellName), "EMOTE")
		else
			local _, instanceType = IsInInstance()
			local battleground = instanceType == "pvp"

			if E.db.general.interruptAnnounce == "PARTY" then
				if GetNumPartyMembers() > 0 then
					SendChatMessage(format(interruptMsg, destName, spellID, spellName), battleground and "BATTLEGROUND" or "PARTY")
				end
			elseif E.db.general.interruptAnnounce == "RAID" then
				if GetNumRaidMembers() > 0 then
					SendChatMessage(format(interruptMsg, destName, spellID, spellName), battleground and "BATTLEGROUND" or "RAID")
				elseif GetNumPartyMembers() > 0 then
					SendChatMessage(format(interruptMsg, destName, spellID, spellName), battleground and "BATTLEGROUND" or "PARTY")
				end
			elseif E.db.general.interruptAnnounce == "RAID_ONLY" then
				if GetNumRaidMembers() > 0 then
					SendChatMessage(format(interruptMsg, destName, spellID, spellName), battleground and "BATTLEGROUND" or "RAID")
				end
			end
		end
	end
end

do
	local repairInventoryPriority = {
		16,	-- MainHandSlot
		17,	-- SecondaryHandSlot
		18,	-- RangedSlot
		1,	-- HeadSlot
		5,	-- ChestSlot
		7,	-- LegsSlot
		3,	-- ShoulderSlot
		10,	-- HandsSlot
		6,	-- WaistSlot
		8,	-- FeetSlot
		9,	-- WristSlot
	}

	local function HasDamagedItems()
		for slotID = 1, 19 do
			local current, max = GetInventoryItemDurability(slotID)
			if current and max and current < max then
				return true
			end
		end
		return false
	end

	local function RepairInventoryByPriority(playerMoney)
		local money = playerMoney

		ShowRepairCursor()

		for _, slotID in ipairs(repairInventoryPriority) do
			local current, max = GetInventoryItemDurability(slotID)
			if current and max and current < max then
				PickupInventoryItem(slotID)
			end
		end

		HideRepairCursor()
	end

	local function FullRepairMessage(repairAllCost)
		E:Print(format("%s%s", L["Your items have been repaired for: "], E:FormatMoney(repairAllCost, "SMART", true)))
	end

	function M:AutoRepair(repairMode, greyValue)
		repairMode = repairMode or self.repairMode
		greyValue = greyValue or self.greyValue

		if not CanMerchantRepair() or IsShiftKeyDown() then
			self:UnregisterRepairEvents()
			return
		end

		if not HasDamagedItems() then
			self:UnregisterRepairEvents()
			return
		end

		local repairAllCost, canRepair = GetRepairAllCost()

		if not canRepair then
			self:UnregisterRepairEvents()
			return
		end

		local canGuildBank = CanGuildBankRepair()

		-- Strict Check: If set to GUILD mode, but guild bank repairs aren't available, fail gracefully.
		if repairMode == "GUILD" and not canGuildBank then
			E:Print(L["Guild repair is enabled, but guild bank funds are unavailable or limit has been reached."])
			self:UnregisterRepairEvents()
			return
		end

		-- Handle API cost delay (0 cost returned despite damaged gear)
		if repairAllCost <= 0 then
			self.repairRetries = (self.repairRetries or 0) + 1
			if self.repairRetries <= 3 then
				E:Delay(0.25, self.AutoRepair, self, repairMode, greyValue)
				return
			else
				-- Final fallback pass for API delays
				if repairMode == "GUILD" and canGuildBank then
					RepairAllItems(1)
					E:Print(L["Your items have been repaired using guild bank funds."])
				elseif repairMode == "PLAYER" then
					RepairAllItems()
				end
				self:UnregisterRepairEvents()
				return
			end
		end

		self:UnregisterRepairEvents()

		-- 1. GUILD REPAIR ONLY
		if repairMode == "GUILD" then
			RepairAllItems(1)
			E:Print(format("%s%s", L["Your items have been repaired using guild bank funds for: "], E:FormatMoney(repairAllCost, "SMART", true)))
			return
		end

		-- 2. PLAYER REPAIR ONLY (Only executes if repairMode == "PLAYER")
		if repairMode == "PLAYER" then
			local playerMoney = GetMoney()

			if playerMoney >= repairAllCost then
				RepairAllItems()
				FullRepairMessage(repairAllCost)
			elseif greyValue and (playerMoney + greyValue >= repairAllCost) then
				self.playerMoney = playerMoney
				self.repairAllCost = repairAllCost

				self:RegisterEvent("MERCHANT_CLOSED")
				E.RegisterCallback(M, "VendorGreys_ItemSold", "VendorGreys_ItemSold")
			elseif playerMoney > 0 then
				RepairAllItems() -- Partial player repair
			else
				E:Print(L["You don't have enough money to repair."])
			end
		end
	end

	function M:OnRepairEvent()
		self:AutoRepair()
	end

	function M:UnregisterRepairEvents()
		self:UnregisterEvent("UPDATE_INVENTORY_DURABILITY")
		self:UnregisterEvent("MERCHANT_UPDATE")
	end

	function M:VendorGreys_ItemSold(_, moneyGained)
		if not self.repairAllCost or not self.playerMoney then return end

		self.playerMoney = self.playerMoney + moneyGained

		if self.playerMoney >= self.repairAllCost then
			if self.playerMoney > GetMoney() then
				self:RegisterEvent("PLAYER_MONEY")
				E.UnregisterCallback(M, "VendorGreys_ItemSold")
			else
				RepairAllItems()
				FullRepairMessage(self.repairAllCost)
				self:MERCHANT_CLOSED()
			end
		end
	end

	function M:PLAYER_MONEY()
		if not self.repairAllCost then return end

		if GetMoney() >= self.repairAllCost then
			RepairAllItems()
			FullRepairMessage(self.repairAllCost)

			self:MERCHANT_CLOSED()
		end
	end

	function M:MERCHANT_CLOSED()
		self.playerMoney = nil
		self.repairAllCost = nil
		self.repairMode = nil
		self.greyValue = nil
		self.repairRetries = nil

		self:UnregisterRepairEvents()
		self:UnregisterEvent("PLAYER_MONEY")
		self:UnregisterEvent("MERCHANT_CLOSED")
		E.UnregisterCallback(M, "VendorGreys_ItemSold")
	end
end

function M:MERCHANT_SHOW()
	local greyValue

	if E.db.bags.vendorGrays.enable then
		local itemCount
		itemCount, greyValue = Bags:GetGraysInfo()

		if itemCount > 0 then
			Bags:VendorGrays()
		end
	end

	local repairMode = E.db.general.autoRepair

	if repairMode ~= "NONE" then
		self.repairMode = repairMode
		self.greyValue = greyValue
		self.repairRetries = 0

		self:RegisterEvent("UPDATE_INVENTORY_DURABILITY", "OnRepairEvent")
		self:RegisterEvent("MERCHANT_UPDATE", "OnRepairEvent")
		self:RegisterEvent("MERCHANT_CLOSED")

		E:Delay(0.1, self.AutoRepair, self, repairMode, greyValue)
	end
end

function M:DisbandRaidGroup()
	if InCombatLockdown() then return end -- Prevent user error in combat

	local numRaid = GetNumRaidMembers()

	if numRaid > 0 then
		for i = 1, numRaid do
			local name, _, _, _, _, _, _, online = GetRaidRosterInfo(i)
			if online and name ~= E.myname then
				UninviteUnit(name)
			end
		end
	else
		for i = MAX_PARTY_MEMBERS, 1, -1 do
			if GetPartyMember(i) then
				UninviteUnit(UnitName("party"..i))
			end
		end
	end

	LeaveParty()
end

function M:PVPMessageEnhancement(_, msg)
	if not E.db.general.enhancedPvpMessages then return end

	local _, instanceType = IsInInstance()
	if instanceType == "pvp" or instanceType == "arena" then
		RaidNotice_AddMessage(RaidBossEmoteFrame, msg, ChatTypeInfo.RAID_BOSS_EMOTE)
	end
end

function M:AutoInvite(event, leaderName)
	if not E.db.general.autoAcceptInvite then return end

	if MiniMapLFGFrame:IsShown() then return end
	if GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0 then return end

	local numFriends = GetNumFriends()

	if numFriends > 0 then
		ShowFriends()

		for i = 1, numFriends do
			if GetFriendInfo(i) == leaderName then
				AcceptGroup()
				StaticPopup_Hide("PARTY_INVITE")
				return
			end
		end
	end

	if not IsInGuild() then return end

	GuildRoster()

	for i = 1, GetNumGuildMembers() do
		if GetGuildRosterInfo(i) == leaderName then
			AcceptGroup()
			StaticPopup_Hide("PARTY_INVITE")
			return
		end
	end
end

function M:ForceCVars(event)
	if not GetCVarBool("lockActionBars") then
		SetCVar("lockActionBars", 1)
	end

	if event == "PLAYER_ENTERING_WORLD" then
		self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	end
end

function M:Initialize()
	self:LoadRaidMarker()
	self:LoadLoot()
	self:LoadLootRoll()
	self:LoadChatBubbles()

	self:ToggleErrorHandling()
	self:ToggleInterruptAnnounce()

	self:RegisterEvent("CHAT_MSG_BG_SYSTEM_HORDE", "PVPMessageEnhancement")
	self:RegisterEvent("CHAT_MSG_BG_SYSTEM_ALLIANCE", "PVPMessageEnhancement")
	self:RegisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL", "PVPMessageEnhancement")
	self:RegisterEvent("PARTY_INVITE_REQUEST", "AutoInvite")
	self:RegisterEvent("MERCHANT_SHOW")

	if E.private.actionbar.enable then
		self:RegisterEvent("CVAR_UPDATE", "ForceCVars")
		self:RegisterEvent("PLAYER_ENTERING_WORLD", "ForceCVars")
	end

	self.Initialized = true
end

local function InitializeCallback()
	M:Initialize()
end

E:RegisterModule(M:GetName(), InitializeCallback)