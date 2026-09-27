local E, L, V, P, G = unpack(select(2, ...))
local DT = E:GetModule("DataTexts")

-- Lua functions
local format, join, gmatch = string.format, string.join, string.gmatch

-- WoW API / Variables
local GetCombatRating = GetCombatRating
local GetCombatRatingBonus = GetCombatRatingBonus
local UnitAttackSpeed = UnitAttackSpeed
local UnitRangedDamage = UnitRangedDamage

local CR_HASTE_MELEE = CR_HASTE_MELEE or 18
local CR_HASTE_RANGED = CR_HASTE_RANGED or 19
local CR_HASTE_SPELL = CR_HASTE_SPELL or 20
local CR_HASTE_RATING_TOOLTIP = CR_HASTE_RATING_TOOLTIP
local PAPERDOLLFRAME_TOOLTIP_FORMAT = PAPERDOLLFRAME_TOOLTIP_FORMAT or "%s"
local SPELL_HASTE_TOOLTIP = SPELL_HASTE_TOOLTIP

local hasteRating = 0
local displayNumberString = ""
local lastPanel

local function OnEvent(self, event)
	lastPanel = self

	if event == "SPELL_UPDATE_USABLE" then
		self:UnregisterEvent(event)
	end

	if E.Role == "Caster" then
		hasteRating = GetCombatRating(CR_HASTE_SPELL) or 0
	elseif E.myclass == "HUNTER" then
		hasteRating = GetCombatRating(CR_HASTE_RANGED) or 0
	else
		hasteRating = GetCombatRating(CR_HASTE_MELEE) or 0
	end

	self.text:SetFormattedText(displayNumberString, hasteRating)
end

local function OnEnter(self)
	DT:SetupTooltip(self)

	-- Dynamically fetch ElvUI locale inside OnEnter
	local hasteLabel = L["Haste"] or "Haste"

	local text, tooltip
	if E.Role == "Caster" then
		text = format("%s %d", hasteLabel, hasteRating)
		local bonus = GetCombatRatingBonus(CR_HASTE_SPELL) or 0
		if SPELL_HASTE_TOOLTIP then
			tooltip = format(SPELL_HASTE_TOOLTIP, bonus)
		end
	elseif E.myclass == "HUNTER" then
		text = format("%s %.2f", format(PAPERDOLLFRAME_TOOLTIP_FORMAT, hasteLabel), UnitRangedDamage("player") or 0)
		local bonus = GetCombatRatingBonus(CR_HASTE_RANGED) or 0
		if CR_HASTE_RATING_TOOLTIP then
			tooltip = format(CR_HASTE_RATING_TOOLTIP, hasteRating, bonus)
		end
	else
		local speed, offhandSpeed = UnitAttackSpeed("player")
		speed = speed or 0
		if offhandSpeed then
			text = format("%s %.2f / %.2f", format(PAPERDOLLFRAME_TOOLTIP_FORMAT, hasteLabel), speed, offhandSpeed)
		else
			text = format("%s %.2f", format(PAPERDOLLFRAME_TOOLTIP_FORMAT, hasteLabel), speed)
		end

		local bonus = GetCombatRatingBonus(CR_HASTE_MELEE) or 0
		if CR_HASTE_RATING_TOOLTIP then
			tooltip = format(CR_HASTE_RATING_TOOLTIP, hasteRating, bonus)
		end
	end

	DT.tooltip:AddLine(text, 1, 1, 1)

	if tooltip then
		for line in gmatch(tooltip, "[^\r\n]+") do
			DT.tooltip:AddLine(line, nil, nil, nil, 1)
		end
	end

	DT.tooltip:Show()
end

local function ValueColorUpdate(hex)
	local hasteLabel = L["Haste"] or "Haste"
	displayNumberString = join("", hasteLabel, ": ", hex, "%d|r")

	if lastPanel ~= nil then
		OnEvent(lastPanel)
	end
end
E.valueColorUpdateFuncs[ValueColorUpdate] = true

DT:RegisterDatatext("Haste", {"PLAYER_ENTERING_WORLD", "SPELL_UPDATE_USABLE", "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_TALENT_UPDATE", "UNIT_ATTACK_SPEED", "UNIT_SPELL_HASTE"}, OnEvent, nil, nil, OnEnter, nil, L["Haste"])