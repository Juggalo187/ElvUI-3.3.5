local E, L, V, P, G = unpack(select(2, ...))
local DT = E:GetModule("DataTexts")

--Lua functions
local format, join = string.format, string.join
--WoW API / Variables
local GetBlockChance = GetBlockChance
local PAPERDOLLFRAME_TOOLTIP_FORMAT = PAPERDOLLFRAME_TOOLTIP_FORMAT
local STAT_BLOCK = STAT_BLOCK

local blockChance
local displayString = ""
local lastPanel

local function OnEvent(self)
    lastPanel = self
    blockChance = GetBlockChance()
    self.text:SetFormattedText(displayString, blockChance)
end

local function OnEnter(self)
    DT:SetupTooltip(self)
    DT.tooltip:AddLine(format("%s %.2f%%", format(PAPERDOLLFRAME_TOOLTIP_FORMAT, STAT_BLOCK), blockChance), 1, 1, 1)
    DT.tooltip:Show()
end

local function ValueColorUpdate(hex)
    displayString = join("", STAT_BLOCK, ": ", hex, "%.2f%%|r")

    if lastPanel ~= nil then
        OnEvent(lastPanel)
    end
end
E.valueColorUpdateFuncs[ValueColorUpdate] = true

DT:RegisterDatatext("Block", {"COMBAT_RATING_UPDATE", "PLAYER_ENTERING_WORLD"}, OnEvent, nil, nil, OnEnter, nil, STAT_BLOCK)