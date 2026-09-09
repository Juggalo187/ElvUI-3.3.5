local E = unpack(select(2, ...))

local find, gsub, lower, format = string.find, string.gsub, string.lower, string.format

local BLIZZ_GM_TAG = "|TInterface\\ChatFrame\\UI-ChatIcon"
local BLIZZ_GM_PATTERN = "|TInterface[\\/]ChatFrame[\\/]UI%-ChatIcon[^|]*|t%s*"
local astralGMPattern
local testSelf = false

local function GetAstralGMPattern()
	if not astralGMPattern and E.Media and E.Media.Textures and E.Media.Textures.Astral then
		local tex = gsub(E.Media.Textures.Astral, "([%(%)%.%+%-%*%?%[%]%^%$%%])", "%%%1")
		astralGMPattern = "|T" .. tex .. "[^|]*|t%s*"
	end
	return astralGMPattern
end

function E:ReplaceGMWorldName(name)
	if not name or not self:UseAstralGMIcon() then return name end

	local isGM = find(name, BLIZZ_GM_TAG, 1, true) or find(name, "<GM>", 1, true)
	if not isGM and E.Media and E.Media.Textures and E.Media.Textures.Astral then
		isGM = find(name, E.Media.Textures.Astral, 1, true)
	end
	if not isGM then return name end

	name = gsub(name, BLIZZ_GM_PATTERN, "")
	local pattern = GetAstralGMPattern()
	if pattern then
		name = gsub(name, pattern, "")
	end
	name = gsub(name, "^<GM>%s*", "")

	return "<GM> " .. name
end

local function ApplySelfTest(name, unit)
	if not testSelf or not name or not unit then return name end
	if unit ~= "player" and not UnitIsUnit(unit, "player") then return name end
	if find(name, "<GM>", 1, true) then return name end
	return E:GetGMNameIcon() .. name
end

function E:InitializeGMIcon()
	if not self:IsAstralEnabled() or self.private.astral.gmIcon == false then return end

	local icon = E:GetGMChatIcon()
	_G.CHAT_FLAG_GM = icon
	_G.CHAT_FLAG_DEV = icon

	local UnitName = _G.UnitName
	_G.UnitName = function(unit)
		if not unit then return end
		local name, realm = UnitName(unit)
		name = E:ReplaceGMWorldName(name)
		name = ApplySelfTest(name, unit)
		return name, realm
	end
end

SLASH_ELVUIGMICON1 = "/egmicon"
SlashCmdList.ELVUIGMICON = function(msg)
	local arg = lower(msg or "")

	if arg == "chat" then
		DEFAULT_CHAT_FRAME:AddMessage(E:GetGMChatIcon().."|cff40c7ebTestGM|r: Simulated GM chat message.")
		return
	end

	if arg == "name" then
		local blizz = "|TInterface\\ChatFrame\\UI-ChatIcon-Blizz.blp:0:2:0:-3|t TestGM"
		DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaaBlizzard GM tag:|r")
		DEFAULT_CHAT_FRAME:AddMessage(blizz)
		DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaaWorld replacement:|r")
		DEFAULT_CHAT_FRAME:AddMessage(E:ReplaceGMWorldName(blizz))
		return
	end

	if arg == "target" then
		if not UnitExists("target") then
			DEFAULT_CHAT_FRAME:AddMessage("No target. Target a player first.", 1, 0.2, 0.2)
			return
		end
		DEFAULT_CHAT_FRAME:AddMessage(format("UnitName(target): %s", UnitName("target") or "nil"))
		return
	end

	if arg == "self" or arg == "self on" then
		testSelf = true
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00GM icon test ON|r - <GM> tag added to your name.")
		DEFAULT_CHAT_FRAME:AddMessage(format("UnitName(player): %s", UnitName("player") or "nil"))
		DEFAULT_CHAT_FRAME:AddMessage("Look above your character, or target yourself. /egmicon self off to stop.", 0.7, 0.7, 0.7)
		return
	end

	if arg == "self off" then
		testSelf = false
		DEFAULT_CHAT_FRAME:AddMessage("|cffff0000GM icon test OFF|r.")
		DEFAULT_CHAT_FRAME:AddMessage(format("UnitName(player): %s", UnitName("player") or "nil"))
		return
	end

	DEFAULT_CHAT_FRAME:AddMessage("Astral GM icon: "..E:GetGMChatIcon())
	DEFAULT_CHAT_FRAME:AddMessage("/egmicon chat     - simulated GM chat line", 0.7, 0.7, 0.7)
	DEFAULT_CHAT_FRAME:AddMessage("/egmicon name     - Blizzard tag vs world replacement", 0.7, 0.7, 0.7)
	DEFAULT_CHAT_FRAME:AddMessage("/egmicon self     - preview <GM> on your own name", 0.7, 0.7, 0.7)
	DEFAULT_CHAT_FRAME:AddMessage("/egmicon self off - stop self name preview", 0.7, 0.7, 0.7)
	DEFAULT_CHAT_FRAME:AddMessage("/egmicon target   - show hooked UnitName for target", 0.7, 0.7, 0.7)
end
