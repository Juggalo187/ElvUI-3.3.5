local E, L, V, P, G = unpack(select(2, ...))
local DT = E:GetModule("DataTexts")

--Lua functions
local format, join = string.format, string.join
--WoW API / Variables
local GetParryChance = GetParryChance
local PAPERDOLLFRAME_TOOLTIP_FORMAT = PAPERDOLLFRAME_TOOLTIP_FORMAT
local STAT_PARRY = STAT_PARRY

local parryChance
local displayString = ""
local lastPanel

local function OnEvent(self)
    lastPanel = self
    parryChance = GetParryChance()
    self.text:SetFormattedText(displayString, parryChance)
end

local function OnEnter(self)
    DT:SetupTooltip(self)
    DT.tooltip:AddLine(format("%s %.2f%%", format(PAPERDOLLFRAME_TOOLTIP_FORMAT, STAT_PARRY), parryChance), 1, 1, 1)
    DT.tooltip:Show()
end

local function ValueColorUpdate(hex)
    displayString = join("", STAT_PARRY, ": ", hex, "%.2f%%|r")
    if lastPanel ~= nil then OnEvent(lastPanel) end
end
E.valueColorUpdateFuncs[ValueColorUpdate] = true

DT:RegisterDatatext("Parry", {"COMBAT_RATING_UPDATE", "PLAYER_ENTERING_WORLD"}, OnEvent, nil, nil, OnEnter, nil, STAT_PARRY)