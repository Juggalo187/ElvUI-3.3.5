local E, L, V, P, G = unpack(select(2, ...)) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local DT = E:GetModule("DataTexts")

--Lua functions
local format, join = string.format, string.join
--WoW API / Variables
local GetParryChance = GetParryChance
local GetCombatRating = GetCombatRating
local GetCombatRatingBonus = GetCombatRatingBonus
local STAT_PARRY = STAT_PARRY or "Parry"
local CR_PARRY = CR_PARRY or 4

local displayString = ""
local lastPanel

local function OnEvent(self)
	lastPanel = self
	local parry = GetParryChance()
	self.text:SetFormattedText(displayString, parry)
end

local function OnEnter(self)
	DT:SetupTooltip(self)
	local rating = GetCombatRating(CR_PARRY)
	local bonus = GetCombatRatingBonus(CR_PARRY)
	DT.tooltip:AddDoubleLine(STAT_PARRY, format("%.2f%%", GetParryChance()), 1, 1, 1)
	DT.tooltip:AddDoubleLine(L["Rating"] or "Rating", rating, 1, 1, 1)
	DT.tooltip:AddDoubleLine(L["Bonus"] or "Bonus", format("+%.2f%%", bonus), 1, 1, 1)
	DT.tooltip:Show()
end

local function ValueColorUpdate(hex)
	displayString = join("", L["Parry"] or "Parry", ": ", hex, "%.2f%%|r")
	if lastPanel ~= nil then
		OnEvent(lastPanel)
	end
end
E.valueColorUpdateFuncs[ValueColorUpdate] = true

DT:RegisterDatatext("Parry", {"UNIT_STATS", "UNIT_AURA", "PLAYER_TARGET_CHANGED", "COMBAT_RATING_UPDATE"}, OnEvent, nil, nil, OnEnter, nil, STAT_PARRY)
