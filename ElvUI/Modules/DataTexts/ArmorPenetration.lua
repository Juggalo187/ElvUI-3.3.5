local E, L, V, P, G = unpack(select(2, ...)) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local DT = E:GetModule("DataTexts")

--Lua functions
local format, join = string.format, string.join
--WoW API / Variables
local GetCombatRating = GetCombatRating
local GetCombatRatingBonus = GetCombatRatingBonus
local CR_ARMOR_PENETRATION = CR_ARMOR_PENETRATION or 25
local STAT_ARMOR_PENETRATION = STAT_ARMOR_PENETRATION or "Armor Penetration"

local displayString = ""
local lastPanel

local function OnEvent(self)
	lastPanel = self
	local arpBonus = GetCombatRatingBonus(CR_ARMOR_PENETRATION)
	self.text:SetFormattedText(displayString, arpBonus)
end

local function OnEnter(self)
	DT:SetupTooltip(self)
	local rating = GetCombatRating(CR_ARMOR_PENETRATION)
	local bonus = GetCombatRatingBonus(CR_ARMOR_PENETRATION)
	DT.tooltip:AddDoubleLine(STAT_ARMOR_PENETRATION, format("%.2f%%", bonus), 1, 1, 1)
	DT.tooltip:AddDoubleLine(L["Rating"] or "Rating", rating, 1, 1, 1)
	DT.tooltip:Show()
end

local function ValueColorUpdate(hex)
	displayString = join("", L["ArP"] or "ArP", ": ", hex, "%.2f%%|r")
	if lastPanel ~= nil then
		OnEvent(lastPanel)
	end
end
E.valueColorUpdateFuncs[ValueColorUpdate] = true

DT:RegisterDatatext("Armor Penetration", {"COMBAT_RATING_UPDATE", "UNIT_STATS", "PLAYER_EQUIPMENT_CHANGED"}, OnEvent, nil, nil, OnEnter, nil, STAT_ARMOR_PENETRATION)
