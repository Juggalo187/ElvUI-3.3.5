local E, L, V, P, G = unpack(select(2, ...))
local DT = E:GetModule("DataTexts")

--Lua functions
local format, join = string.format, string.join
--WoW API / Variables
local GetCombatRating = GetCombatRating
local CR_DEFENSE_SKILL = CR_DEFENSE_SKILL
local PAPERDOLLFRAME_TOOLTIP_FORMAT = PAPERDOLLFRAME_TOOLTIP_FORMAT
local COMBAT_RATING_NAME2 = COMBAT_RATING_NAME2

local defenseRating
local displayString = ""
local lastPanel

local function OnEvent(self)
    lastPanel = self
    defenseRating = GetCombatRating(CR_DEFENSE_SKILL)
    self.text:SetFormattedText(displayString, defenseRating)
end

local function OnEnter(self)
    DT:SetupTooltip(self)
    DT.tooltip:AddLine(format("%s %d", format(PAPERDOLLFRAME_TOOLTIP_FORMAT, COMBAT_RATING_NAME2), defenseRating), 1, 1, 1)
    DT.tooltip:Show()
end

local function ValueColorUpdate(hex)
    displayString = join("", COMBAT_RATING_NAME2, ": ", hex, "%d|r")

    if lastPanel ~= nil then
        OnEvent(lastPanel)
    end
end
E.valueColorUpdateFuncs[ValueColorUpdate] = true

DT:RegisterDatatext("Defense", {"COMBAT_RATING_UPDATE", "PLAYER_ENTERING_WORLD"}, OnEvent, nil, nil, OnEnter, nil, COMBAT_RATING_NAME2)