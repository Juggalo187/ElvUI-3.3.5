local E, L, V, P, G = unpack(select(2, ...)) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local DT = E:GetModule("DataTexts")

local format, join = string.format, string.join
local GetSpellCritChance = GetSpellCritChance
local GetCombatRating = GetCombatRating
local GetCombatRatingBonus = GetCombatRatingBonus
local CR_CRIT_SPELL = CR_CRIT_SPELL or 11

local displayString = ""
local lastPanel

local function OnEvent(self)
	lastPanel = self
	local crit = GetSpellCritChance(5) or 0
	self.text:SetFormattedText(displayString, crit)
end

local function OnEnter(self)
	DT:SetupTooltip(self)
	local rating = GetCombatRating(CR_CRIT_SPELL)
	local bonus = GetCombatRatingBonus(CR_CRIT_SPELL)
	local crit = GetSpellCritChance(5) or 0
	DT.tooltip:AddDoubleLine("Frost Crit Chance", format("%.2f%%", crit), 1, 1, 1, 1, 1, 1)
	DT.tooltip:AddLine(format("Crit rating %d (+%.2f%% crit chance)", rating, bonus), 1, 0.82, 0)
	DT.tooltip:Show()
end

local function ValueColorUpdate(hex)
	displayString = join("", "Frost Crit: ", hex, "%.2f%%|r")
	if lastPanel ~= nil then
		OnEvent(lastPanel)
	end
end
E.valueColorUpdateFuncs[ValueColorUpdate] = true

DT:RegisterDatatext("Frost Crit", {"COMBAT_RATING_UPDATE", "UNIT_STATS", "PLAYER_DAMAGE_DONE_MODS"}, OnEvent, nil, nil, OnEnter, nil, "Frost Crit")
