local E, L, V, P, G = unpack(select(2, ...))
local DT = E:GetModule("DataTexts")

-- Lua functions
local format, join, gmatch = string.format, string.join, string.gmatch
local pcall = pcall

-- WoW API / Variables
local UnitDefense = UnitDefense
local GetCombatRating = GetCombatRating
local GetCombatRatingBonus = GetCombatRatingBonus
local CR_DEFENSE_SKILL = CR_DEFENSE_SKILL or 2
local PAPERDOLLFRAME_TOOLTIP_FORMAT = PAPERDOLLFRAME_TOOLTIP_FORMAT
local STAT_DEFENSE = L["Defense"] or STAT_DEFENSE or DEFENSE or "Defense"

local defenseSkill = 0
local displayString = ""
local lastPanel

local function OnEvent(self)
    lastPanel = self
    local base, modifier = UnitDefense("player")
    defenseSkill = (base or 0) + (modifier or 0)
    self.text:SetFormattedText(displayString, defenseSkill)
end

local function OnEnter(self)
    DT:SetupTooltip(self)

    -- Refresh total defense skill
    local base, modifier = UnitDefense("player")
    defenseSkill = (base or 0) + (modifier or 0)

    local rating      = GetCombatRating(CR_DEFENSE_SKILL) or 0
    local ratingBonus = GetCombatRatingBonus(CR_DEFENSE_SKILL) or 0
    local bonusPct    = ratingBonus * 0.04

    -- Line 1 (white): "Defense 540"
    DT.tooltip:AddLine(format("%s %d", format(PAPERDOLLFRAME_TOOLTIP_FORMAT or "%s", STAT_DEFENSE), defenseSkill), 1, 1, 1)

    -- Localized WotLK Defense description
    local rawTooltip = STAT_DEFENSE_TOOLTIP or CR_DEFENSE_TOOLTIP or DEFAULT_STATDEFENSE_TOOLTIP
    if rawTooltip then
        -- Safely try 4 arguments first, then fall back to 2 if needed
        local ok, formattedText = pcall(format, rawTooltip, rating, ratingBonus, bonusPct, bonusPct)
        if not ok then
            ok, formattedText = pcall(format, rawTooltip, rating, ratingBonus)
        end

        -- Split multi-line string line-by-line so 3.3.5a tooltip frame renders properly
        if ok and formattedText then
            for line in gmatch(formattedText, "[^\r\n]+") do
                DT.tooltip:AddLine(line, nil, nil, nil, 1)
            end
        end
    end

    DT.tooltip:Show()
end

local function ValueColorUpdate(hex)
    displayString = join("", STAT_DEFENSE, ": ", hex, "%d|r")
    if lastPanel ~= nil then OnEvent(lastPanel) end
end
E.valueColorUpdateFuncs[ValueColorUpdate] = true

DT:RegisterDatatext("Defense", {"PLAYER_ENTERING_WORLD", "COMBAT_RATING_UPDATE", "UNIT_DEFENSE", "PLAYER_EQUIPMENT_CHANGED"}, OnEvent, nil, nil, OnEnter, nil, STAT_DEFENSE)