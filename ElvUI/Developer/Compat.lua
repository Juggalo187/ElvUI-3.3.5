-- ʕ •ᴥ•ʔ✿ 3.3.5a shims so Ascension/retail ElvUI can boot ✿ ʕ •ᴥ•ʔ

-- ʕ •ᴥ•ʔ✿ Never replace CreateFrame; ExecuteCastSequence calls it and taints /castsequence ✿ ʕ •ᴥ•ʔ

do
	local origSetCVar = SetCVar
	function SetCVar(cvar, value, ...)
		return pcall(origSetCVar, cvar, value, ...)
	end
	local restore = CreateFrame("Frame")
	restore:RegisterEvent("ADDON_LOADED")
	restore:SetScript("OnEvent", function(self, _, addon)
		if addon ~= "ElvUI" then return end
		_G.SetCVar = origSetCVar
		self:UnregisterAllEvents()
		self:SetScript("OnEvent", nil)
	end)
end

if not CreateCounter then
	function CreateCounter(start)
		local n = start or 0
		return function()
			n = n + 1
			return n
		end
	end
end

if not CopyTable then
	function CopyTable(src)
		if type(src) ~= "table" then return src end
		local dst = {}
		for k, v in pairs(src) do
			if type(v) == "table" then
				dst[k] = CopyTable(v)
			else
				dst[k] = v
			end
		end
		return dst
	end
end

if not GetCVarBool then
	function GetCVarBool(name)
		local v = GetCVar(name)
		return v == "1" or v == 1 or v == true
	end
end

if not IsInRaid then
	function IsInRaid()
		return (GetNumRaidMembers() or 0) > 0
	end
end

if not IsInGroup then
	function IsInGroup()
		return (GetNumPartyMembers() or 0) > 0 or (GetNumRaidMembers() or 0) > 0
	end
end

if not IsLoggedIn then
	function IsLoggedIn()
		return UnitName("player") ~= nil
	end
end

if not GenerateClosure then
	function GenerateClosure(a, b)
		if type(a) == "function" then
			return function(...)
				return a(b, ...)
			end
		end
		if type(b) == "function" then
			return function(...)
				return b(a, ...)
			end
		end
	end
end

if not CreateAtlasMarkup then
	function CreateAtlasMarkup()
		return ""
	end
end

if not IsModifierKeyDown then
	function IsModifierKeyDown()
		return IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown()
	end
end

if not C_CVar then
	C_CVar = {}
	function C_CVar.GetBool(name)
		local v = GetCVar(name)
		-- ʕ •ᴥ•ʔ✿ Ascension-only CVar; stock 3.3.5a always reports addon memory ✿ ʕ •ᴥ•ʔ
		if v == nil then
			return name == "allowAddonMemoryUsage"
		end
		return v == "1" or v == 1 or v == true
	end
	function C_CVar.Set(name, value)
		SetCVar(name, value)
	end
end

if not C_Timer then
	local timers = {}
	local timerFrame = CreateFrame("Frame")
	local methods = {}
	methods.__index = methods

	function methods:Cancel()
		self.cancelled = true
	end

	function methods:IsCancelled()
		return self.cancelled == true
	end

	timerFrame:Hide()
	timerFrame:SetScript("OnUpdate", function(_, elapsed)
		for i = #timers, 1, -1 do
			local timer = timers[i]
			if timer.cancelled then
				table.remove(timers, i)
			else
				timer.remaining = timer.remaining - elapsed
				if timer.remaining <= 0 then
					timer.callback(timer)
					if timer.ticker and not timer.cancelled then
						if timer.iterations then
							timer.iterations = timer.iterations - 1
							if timer.iterations <= 0 then
								timer.cancelled = true
								table.remove(timers, i)
							else
								timer.remaining = timer.duration
							end
						else
							timer.remaining = timer.duration
						end
					else
						table.remove(timers, i)
					end
				end
			end
		end
		if #timers == 0 then
			timerFrame:Hide()
		end
	end)

	local function CreateTimer(duration, callback, ticker, iterations)
		local timer = setmetatable({
			duration = (duration and duration > 0) and duration or 0.01,
			remaining = (duration and duration > 0) and duration or 0.01,
			callback = callback,
			ticker = ticker,
			iterations = iterations,
			cancelled = false,
		}, methods)
		timers[#timers + 1] = timer
		timerFrame:Show()
		return timer
	end

	C_Timer = {}
	function C_Timer.After(duration, callback)
		CreateTimer(duration, callback, false)
	end
	function C_Timer.NewTimer(duration, callback)
		return CreateTimer(duration, callback, false)
	end
	function C_Timer.NewTicker(duration, callback, iterations)
		return CreateTimer(duration, callback, true, iterations)
	end
end

if not Timer then
	Timer = C_Timer
end

if not C_Player then
	C_Player = {}
	function C_Player.IsInGroup()
		return IsInGroup()
	end
	function C_Player.IsInRaid()
		return IsInRaid()
	end
	function C_Player:IsHero()
		return false
	end
end

if not GroupUtil then
	GroupUtil = {}
	function GroupUtil.GetNumGroupMembers()
		local raid = GetNumRaidMembers()
		if raid > 0 then return raid end
		local party = GetNumPartyMembers()
		if party > 0 then return party + 1 end
		return 1
	end
end

-- ʕ •ᴥ•ʔ✿ Detect native nameplate API before any stubs ✿ ʕ •ᴥ•ʔ
_G.ELVUI_NATIVE_AWESOME_NAMEPLATES = not not (
	(C_NamePlate and type(C_NamePlate.GetNamePlateForUnit) == "function")
	or (C_NamePlate and type(C_NamePlate.GetNamePlateByGUID) == "function")
)
_G.ELVUI_HAS_AWESOME_NAMEPLATES = _G.ELVUI_NATIVE_AWESOME_NAMEPLATES

_G.ELVUI_AWESOMEWOTLK = not not (
	_G.ELVUI_HAS_AWESOME_NAMEPLATES
	or (type(CopyToClipboard) == "function")
	or (type(FlashWindow) == "function")
	or (C_VoiceChat and type(C_VoiceChat.SpeakText) == "function")
)

if not C_VanityCollection then
	C_VanityCollection = {}
	function C_VanityCollection.IsConsolidatedVanityBuff()
		return false
	end
	function C_VanityCollection.IsCollectionItemOwned()
		return false
	end
end

C_NamePlate = C_NamePlate or {}
if not C_NamePlate.GetNamePlateForUnit then
	function C_NamePlate.GetNamePlateForUnit()
		return nil
	end
end
if not C_NamePlate.GetNamePlates then
	function C_NamePlate.GetNamePlates()
		return {}
	end
end

-- ʕ •ᴥ•ʔ✿ C_NamePlateManager is not 3.3.5a or AwesomeWotLK; do not stub it ✿ ʕ •ᴥ•ʔ

if not C_Quest then
	C_Quest = {}
	function C_Quest.GetQuestID()
		return 0
	end
end

-- ʕ •ᴥ•ʔ✿ 3.3.5 widgets have Show/Hide, not SetShown ✿ ʕ •ᴥ•ʔ
local function PatchWidgetAPI(obj)
	if not obj then return end
	local mt = getmetatable(obj)
	if not mt or type(mt.__index) ~= "table" then return end
	if not mt.__index.SetShown then
		mt.__index.SetShown = function(self, shown)
			if shown then
				self:Show()
			else
				self:Hide()
			end
		end
	end
	if obj.SetTexture then
		if not mt.__index.SetColorTexture then
			mt.__index.SetColorTexture = function(self, r, g, b, a)
				return self:SetTexture(r, g, b, a)
			end
		end
		if not mt.__index.SetAtlas then
			mt.__index.SetAtlas = function(self, atlas)
				if type(atlas) == "string" and not strfind(atlas, "\\") then
					return
				end
				return self:SetTexture(atlas)
			end
		end
		if not mt.__index.GetAtlas then
			mt.__index.GetAtlas = function()
				return nil
			end
		end
	end
end

do
	local frame = CreateFrame("Frame")
	frame:Hide()
	PatchWidgetAPI(frame)
	local tex = UIParent:CreateTexture()
	tex:Hide()
	PatchWidgetAPI(tex)
	local fs = UIParent:CreateFontString()
	fs:Hide()
	PatchWidgetAPI(fs)
	local bar = CreateFrame("StatusBar")
	bar:Hide()
	PatchWidgetAPI(bar)
end

if not SetNamePlateCastBarMode then
	function SetNamePlateCastBarMode() end
end

if not GetUnitBattlefieldFaction then
	function GetUnitBattlefieldFaction(unit)
		return UnitFactionGroup(unit)
	end
end

if not UnitInVehicle then
	function UnitInVehicle()
		return false
	end
end

if not UnitIsPVPSanctuary then
	function UnitIsPVPSanctuary()
		return false
	end
end

if not UnitIsTrivial then
	function UnitIsTrivial()
		return false
	end
end

if not GetCreatureIDFromGUID then
	function GetCreatureIDFromGUID(guid)
		if type(guid) ~= "string" then return end
		if strfind(guid, "-", 1, true) then
			return tonumber((select(6, strsplit("-", guid))))
		end
		return tonumber(strsub(guid, 9, 12), 16)
	end
end

if not GetActionCharges then
	function GetActionCharges()
		return 0, 0, 0, 0, 1
	end
end

if not GetSpellCharges then
	function GetSpellCharges()
		return nil
	end
end

if not UnitGetIncomingHeals then
	function UnitGetIncomingHeals()
		return 0
	end
end

if not UnitGetTotalAbsorbs then
	function UnitGetTotalAbsorbs()
		return 0
	end
end

if not GetItemInfoFromHyperlink then
	function GetItemInfoFromHyperlink(link)
		if type(link) ~= "string" then return end
		return tonumber(strmatch(link, "item:(%d+)"))
	end
end

if not GetMaxLevel then
	function GetMaxLevel()
		if MAX_PLAYER_LEVEL_TABLE and GetAccountExpansionLevel then
			return MAX_PLAYER_LEVEL_TABLE[GetAccountExpansionLevel()] or MAX_PLAYER_LEVEL or 80
		end
		return MAX_PLAYER_LEVEL or 80
	end
end

if not SPEC_SWAP_SPELLS then
	SPEC_SWAP_SPELLS = { 1, 2, 3 }
end

-- ʕ •ᴥ•ʔ✿ 3.3.5 has no ActionButton overlay glow ✿ ʕ •ᴥ•ʔ
if not ActionButton_ShowOverlayGlow then
	function ActionButton_ShowOverlayGlow() end
end
if not ActionButton_HideOverlayGlow then
	function ActionButton_HideOverlayGlow() end
end

if not tIndexOf then
	function tIndexOf(tbl, item)
		for i, v in pairs(tbl) do
			if v == item then return i end
		end
	end
end

if not GetClassInfo then
	local classFiles = {
		"WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST",
		"DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "DRUID",
	}
	function GetClassInfo(index)
		local file = classFiles[index]
		if not file then return end
		local loc = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[file]) or file
		return loc, file, index
	end
end

if not GetDifficultyInfo then
	function GetDifficultyInfo()
		return "", "party", false
	end
end

if not GetMapInfo then
	function GetMapInfo()
		return nil
	end
end

if not GetSpellTexture then
	function GetSpellTexture(spell)
		local _, _, icon = GetSpellInfo(spell)
		return icon
	end
end
