local E, L, V, P, G = unpack(select(2, ...))
local DT = E:GetModule("DataTexts")

--Lua functions
local format, join = string.format, string.join
--WoW API / Variables
local GetCombatRating = GetCombatRating
local GetCombatRatingBonus = GetCombatRatingBonus
local CR_HIT_MELEE = CR_HIT_MELEE
local CR_HIT_RANGED = CR_HIT_RANGED
local CR_HIT_SPELL = CR_HIT_SPELL
local PAPERDOLLFRAME_TOOLTIP_FORMAT = PAPERDOLLFRAME_TOOLTIP_FORMAT

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

local function OnEnter(self)
	DT:SetupTooltip(self)

	local ratingID
	if E.Role == "Caster" then
		ratingID = CR_HIT_SPELL
	elseif E.myclass == "HUNTER" then
		ratingID = CR_HIT_RANGED
	else
		ratingID = CR_HIT_MELEE
	end

	local text    = format("%s %d", format(PAPERDOLLFRAME_TOOLTIP_FORMAT, L["Hit"]), hitRating)
	local tooltip = format("%s %d (+%.2f%%)", L["Hit"], GetCombatRating(ratingID), GetCombatRatingBonus(ratingID))

	DT.tooltip:AddLine(text, 1, 1, 1)
	DT.tooltip:AddLine(tooltip, nil, nil, nil, 1)
	DT.tooltip:Show()
end

local function ValueColorUpdate(hex)
	displayString = join("", L["Hit"], ": ", hex, "%d|r")

	if lastPanel ~= nil then
		OnEvent(lastPanel)
	end
end
E.valueColorUpdateFuncs[ValueColorUpdate] = true

DT:RegisterDatatext("Hit", {"PLAYER_ENTERING_WORLD", "SPELL_UPDATE_USABLE", "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_TALENT_UPDATE", "COMBAT_RATING_UPDATE"}, OnEvent, nil, nil, OnEnter, nil, L["Hit"])