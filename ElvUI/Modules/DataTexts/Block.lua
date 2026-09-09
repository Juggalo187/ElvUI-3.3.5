local E, L, V, P, G = unpack(select(2, ...)) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local DT = E:GetModule("DataTexts")

--Lua functions
local format, join = string.format, string.join
--WoW API / Variables
local GetBlockChance = GetBlockChance
local GetShieldBlock = GetShieldBlock
local GetCombatRating = GetCombatRating
local GetCombatRatingBonus = GetCombatRatingBonus
local BLOCK_CHANCE = BLOCK_CHANCE or "Block Chance"
local CR_BLOCK = CR_BLOCK or 5

local displayString = ""
local lastPanel

local function OnEvent(self)
	lastPanel = self
	local block = GetBlockChance()
	self.text:SetFormattedText(displayString, block)
end

local function OnEnter(self)
	DT:SetupTooltip(self)
	local rating = GetCombatRating(CR_BLOCK)
	local bonus = GetCombatRatingBonus(CR_BLOCK)
	local blockValue = GetShieldBlock()
	DT.tooltip:AddDoubleLine(BLOCK_CHANCE, format("%.2f%%", GetBlockChance()), 1, 1, 1)
	DT.tooltip:AddDoubleLine(L["Rating"] or "Rating", rating, 1, 1, 1)
	DT.tooltip:AddDoubleLine(L["Bonus"] or "Bonus", format("+%.2f%%", bonus), 1, 1, 1)
	if blockValue and blockValue > 0 then
		DT.tooltip:AddDoubleLine(L["Block Value"] or "Block Value", blockValue, 1, 1, 1)
	end
	DT.tooltip:Show()
end

local function ValueColorUpdate(hex)
	displayString = join("", L["Block"] or "Block", ": ", hex, "%.2f%%|r")
	if lastPanel ~= nil then
		OnEvent(lastPanel)
	end
end
E.valueColorUpdateFuncs[ValueColorUpdate] = true

DT:RegisterDatatext("Block Chance", {"UNIT_STATS", "UNIT_AURA", "PLAYER_TARGET_CHANGED", "COMBAT_RATING_UPDATE"}, OnEvent, nil, nil, OnEnter, nil, BLOCK_CHANCE)
