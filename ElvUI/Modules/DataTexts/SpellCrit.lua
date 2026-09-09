local E, L, V, P, G = unpack(select(2, ...)) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local DT = E:GetModule("DataTexts")

--Lua functions
local format, join = string.format, string.join
--WoW API / Variables
local GetSpellCritChance = GetSpellCritChance
local GetCombatRating = GetCombatRating
local GetCombatRatingBonus = GetCombatRatingBonus
local CR_CRIT_SPELL = CR_CRIT_SPELL or 11

local displayString = ""
local lastPanel

local function GetHighestSpellCrit()
	local maxCrit = GetSpellCritChance(2) or 0
	for i = 3, 7 do
		local c = GetSpellCritChance(i)
		if c and c > maxCrit then
			maxCrit = c
		end
	end
	return maxCrit
end

local function OnEvent(self)
	lastPanel = self
	local spellCrit = GetHighestSpellCrit()
	self.text:SetFormattedText(displayString, spellCrit)
end

local function OnEnter(self)
	DT:SetupTooltip(self)
	local rating = GetCombatRating(CR_CRIT_SPELL)

	DT.tooltip:AddDoubleLine("Crit Rating", rating, 1, 1, 1, 1, 0.82, 0)

	local holy = GetSpellCritChance(2) or 0
	local fire = GetSpellCritChance(3) or 0
	local nature = GetSpellCritChance(4) or 0
	local frost = GetSpellCritChance(5) or 0
	local shadow = GetSpellCritChance(6) or 0
	local arcane = GetSpellCritChance(7) or 0

	DT.tooltip:AddDoubleLine("Holy", format("%.2f%%", holy), 1, 1, 1, 1, 1, 1)
	DT.tooltip:AddDoubleLine("Fire", format("%.2f%%", fire), 1, 1, 1, 1, 1, 1)
	DT.tooltip:AddDoubleLine("Nature", format("%.2f%%", nature), 1, 1, 1, 1, 1, 1)
	DT.tooltip:AddDoubleLine("Frost", format("%.2f%%", frost), 1, 1, 1, 1, 1, 1)
	DT.tooltip:AddDoubleLine("Shadow", format("%.2f%%", shadow), 1, 1, 1, 1, 1, 1)
	DT.tooltip:AddDoubleLine("Arcane", format("%.2f%%", arcane), 1, 1, 1, 1, 1, 1)

	DT.tooltip:AddLine(" ")
	DT.tooltip:AddLine("Crit Chance scales Primarily from Crit Rating, and Intellect.", 1, 0.82, 0)
	DT.tooltip:Show()
end

local function ValueColorUpdate(hex)
	displayString = join("", "Spell Crit: ", hex, "%.2f%%|r")
	if lastPanel ~= nil then
		OnEvent(lastPanel)
	end
end
E.valueColorUpdateFuncs[ValueColorUpdate] = true

DT:RegisterDatatext("Spell Crit", {"COMBAT_RATING_UPDATE", "UNIT_STATS", "PLAYER_DAMAGE_DONE_MODS"}, OnEvent, nil, nil, OnEnter, nil, "Spell Crit")
