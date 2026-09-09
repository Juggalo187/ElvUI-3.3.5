local E, L, V, P, G = unpack(select(2, ...)) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local DT = E:GetModule("DataTexts")

--Lua functions
local format, join = string.format, string.join
--WoW API / Variables
local UnitDefense = UnitDefense
local GetCombatRating = GetCombatRating
local GetCombatRatingBonus = GetCombatRatingBonus
local DEFENSE = DEFENSE or "Defense"
local CR_DEFENSE_SKILL = CR_DEFENSE_SKILL or 2

local displayString = ""
local lastPanel

local function OnEvent(self)
	lastPanel = self
	local base, modifier = UnitDefense("player")
	local total = (base or 0) + (modifier or 0)
	self.text:SetFormattedText(displayString, total)
end

local function OnEnter(self)
	DT:SetupTooltip(self)
	local base, modifier = UnitDefense("player")
	local total = (base or 0) + (modifier or 0)
	local rating = GetCombatRating(CR_DEFENSE_SKILL)
	local bonus = GetCombatRatingBonus(CR_DEFENSE_SKILL)
	DT.tooltip:AddDoubleLine(DEFENSE, total, 1, 1, 1)
	DT.tooltip:AddDoubleLine(L["Base Defense"] or "Base Defense", base, 1, 1, 1)
	DT.tooltip:AddDoubleLine(L["Bonus Defense"] or "Bonus Defense", modifier, 1, 1, 1)
	DT.tooltip:AddDoubleLine(L["Rating"] or "Rating", rating, 1, 1, 1)
	DT.tooltip:AddDoubleLine(L["Rating Increase"] or "Rating Increase", format("+%d", bonus), 1, 1, 1)
	DT.tooltip:Show()
end

local function ValueColorUpdate(hex)
	displayString = join("", L["Def"] or "Def", ": ", hex, "%d|r")
	if lastPanel ~= nil then
		OnEvent(lastPanel)
	end
end
E.valueColorUpdateFuncs[ValueColorUpdate] = true

DT:RegisterDatatext("Defense", {"UNIT_DEFENSE", "UNIT_STATS", "COMBAT_RATING_UPDATE"}, OnEvent, nil, nil, OnEnter, nil, DEFENSE)
