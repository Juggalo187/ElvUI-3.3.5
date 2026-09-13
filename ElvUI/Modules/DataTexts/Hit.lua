local E, L, V, P, G = unpack(select(2, ...))
local DT = E:GetModule("DataTexts")

--Lua functions
local join = string.join
--WoW API / Variables
local GetCombatRating = GetCombatRating
local CR_HIT_MELEE = CR_HIT_MELEE
local CR_HIT_RANGED = CR_HIT_RANGED
local CR_HIT_SPELL = CR_HIT_SPELL
local STAT_HIT_CHANCE = STAT_HIT_CHANCE

local hitRating
local displayString = ""
local lastPanel

local function OnEvent(self, event)
	lastPanel = self

	if event == "SPELL_UPDATE_USABLE" then
		self:UnregisterEvent(event)
	end

	if E.Role == "Caster" then
		hitRating = GetCombatRating(CR_HIT_SPELL)
	elseif E.myclass == "HUNTER" then
		hitRating = GetCombatRating(CR_HIT_RANGED)
	else
		hitRating = GetCombatRating(CR_HIT_MELEE)
	end

	self.text:SetFormattedText(displayString, hitRating)
end

local function ValueColorUpdate(hex)
	displayString = join("", L["Hit"], ": ", hex, "%d|r")

	if lastPanel ~= nil then
		OnEvent(lastPanel)
	end
end
E.valueColorUpdateFuncs[ValueColorUpdate] = true

DT:RegisterDatatext("Hit", {"SPELL_UPDATE_USABLE", "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_TALENT_UPDATE", "COMBAT_RATING_UPDATE"}, OnEvent, nil, nil, nil, nil, STAT_HIT_CHANCE)