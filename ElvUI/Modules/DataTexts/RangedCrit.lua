local E, L, V, P, G = unpack(select(2, ...)) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local DT = E:GetModule("DataTexts")

--Lua functions
local format, join = string.format, string.join
--WoW API / Variables
local GetRangedCritChance = GetRangedCritChance
local GetCombatRating = GetCombatRating
local GetCombatRatingBonus = GetCombatRatingBonus
local CR_CRIT_RANGED = CR_CRIT_RANGED or 10

local displayString = ""
local lastPanel

local function OnEvent(self)
	lastPanel = self
	local crit = GetRangedCritChance()
	self.text:SetFormattedText(displayString, crit)
end

local function OnEnter(self)
	DT:SetupTooltip(self)
	local rating = GetCombatRating(CR_CRIT_RANGED)
	local bonus = GetCombatRatingBonus(CR_CRIT_RANGED)
	local crit = GetRangedCritChance()
	DT.tooltip:AddDoubleLine(L["Crit Chance"] or "Crit Chance", format("%.2f%%", crit), 1, 1, 1, 1, 1, 1)
	DT.tooltip:AddLine(format(L["Crit rating %d (+%.2f%% crit chance)"] or "Crit rating %d (+%.2f%% crit chance)", rating, bonus), 1, 0.82, 0)
	DT.tooltip:AddLine(" ")
	DT.tooltip:AddLine(L["Crit Chance scales Primarily from Crit Rating, and Agility."] or "Crit Chance scales Primarily from Crit Rating, and Agility.", 1, 0.82, 0)
	DT.tooltip:Show()
end

local function ValueColorUpdate(hex)
	displayString = join("", L["Ranged Crit"] or "Ranged Crit", ": ", hex, "%.2f%%|r")
	if lastPanel ~= nil then
		OnEvent(lastPanel)
	end
end
E.valueColorUpdateFuncs[ValueColorUpdate] = true

DT:RegisterDatatext("Ranged Crit", {"COMBAT_RATING_UPDATE", "UNIT_STATS", "PLAYER_DAMAGE_DONE_MODS"}, OnEvent, nil, nil, OnEnter, nil, L["Ranged Crit"] or "Ranged Crit")
