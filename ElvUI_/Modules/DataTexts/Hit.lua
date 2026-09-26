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
local CR_ARMOR_PENETRATION = CR_ARMOR_PENETRATION
local CR_SPELL_PENETRATION = CR_SPELL_PENETRATION
local PAPERDOLLFRAME_TOOLTIP_FORMAT = PAPERDOLLFRAME_TOOLTIP_FORMAT
local STAT_HIT_CHANCE = STAT_HIT_CHANCE

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

	local ratingID, hitType, penRatingID, penLabel
	if E.Role == "Caster" then
		ratingID = CR_HIT_SPELL
		hitType = "spell"
		penRatingID = CR_SPELL_PENETRATION
		penLabel = L["Spell Penetration"]
	elseif E.myclass == "HUNTER" then
		ratingID = CR_HIT_RANGED
		hitType = "ranged"
		penRatingID = CR_ARMOR_PENETRATION
		penLabel = L["Armor Penetration"]
	else
		ratingID = CR_HIT_MELEE
		hitType = "melee"
		penRatingID = CR_ARMOR_PENETRATION
		penLabel = L["Armor Penetration"]
	end

	local hitBonus = GetCombatRatingBonus(ratingID)
	local penRating = penRatingID and GetCombatRating(penRatingID) or 0
	local penBonus  = penRatingID and GetCombatRatingBonus(penRatingID) or 0

	-- Line 1 (white): the stat name and rating
	local text = format("%s %d", format(PAPERDOLLFRAME_TOOLTIP_FORMAT, L["Hit"]), hitRating)
	DT.tooltip:AddLine(text, 1, 1, 1)

	-- Line 2 (grey): hit description matching Blizzard layout
	DT.tooltip:AddLine(format("Increases your %s chance to hit a target of level 83 by %.2f%%.", hitType, hitBonus), nil, nil, nil, 1)

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