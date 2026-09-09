local E, L, V, P, G = unpack(select(2, ...)) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local DT = E:GetModule("DataTexts")

--Lua functions
local format, join = string.format, string.join
--WoW API / Variables
local GetDodgeChance = GetDodgeChance
local GetCombatRating = GetCombatRating
local GetCombatRatingBonus = GetCombatRatingBonus
local STAT_DODGE = STAT_DODGE or "Dodge"
local CR_DODGE = CR_DODGE or 3

local displayString = ""
local lastPanel

local function OnEvent(self)
	lastPanel = self
	local dodge = GetDodgeChance()
	self.text:SetFormattedText(displayString, dodge)
end

local function OnEnter(self)
	DT:SetupTooltip(self)
	local rating = GetCombatRating(CR_DODGE)
	local bonus = GetCombatRatingBonus(CR_DODGE)
	DT.tooltip:AddDoubleLine(STAT_DODGE, format("%.2f%%", GetDodgeChance()), 1, 1, 1)
	DT.tooltip:AddDoubleLine(L["Rating"] or "Rating", rating, 1, 1, 1)
	DT.tooltip:AddDoubleLine(L["Bonus"] or "Bonus", format("+%.2f%%", bonus), 1, 1, 1)
	DT.tooltip:Show()
end

local function ValueColorUpdate(hex)
	displayString = join("", L["Dodge"] or "Dodge", ": ", hex, "%.2f%%|r")
	if lastPanel ~= nil then
		OnEvent(lastPanel)
	end
end
E.valueColorUpdateFuncs[ValueColorUpdate] = true

DT:RegisterDatatext("Dodge", {"UNIT_STATS", "UNIT_AURA", "PLAYER_TARGET_CHANGED", "COMBAT_RATING_UPDATE"}, OnEvent, nil, nil, OnEnter, nil, STAT_DODGE)
