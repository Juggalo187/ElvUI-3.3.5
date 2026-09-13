local E, L, V, P, G = unpack(select(2, ...))
local DT = E:GetModule("DataTexts")

--Lua functions
local format, join = string.format, string.join
--WoW API / Variables
local GetExpertise = GetExpertise
local PAPERDOLLFRAME_TOOLTIP_FORMAT = PAPERDOLLFRAME_TOOLTIP_FORMAT
local STAT_EXPERTISE = STAT_EXPERTISE

local expertise
local displayString = ""
local lastPanel

local function OnEvent(self)
    lastPanel = self
    expertise = GetExpertise()
    self.text:SetFormattedText(displayString, expertise)
end

local function OnEnter(self)
    DT:SetupTooltip(self)
    DT.tooltip:AddLine(format("%s %d", format(PAPERDOLLFRAME_TOOLTIP_FORMAT, STAT_EXPERTISE), expertise), 1, 1, 1)
    DT.tooltip:Show()
end

local function ValueColorUpdate(hex)
    displayString = join("", STAT_EXPERTISE, ": ", hex, "%d|r")

    if lastPanel ~= nil then
        OnEvent(lastPanel)
    end
end
E.valueColorUpdateFuncs[ValueColorUpdate] = true

DT:RegisterDatatext("Expertise", {"COMBAT_RATING_UPDATE", "PLAYER_ENTERING_WORLD"}, OnEvent, nil, nil, OnEnter, nil, STAT_EXPERTISE)