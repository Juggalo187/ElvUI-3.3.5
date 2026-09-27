local E, L, V, P, G = unpack(select(2, ...))
local DT = E:GetModule("DataTexts")

--Lua functions
local format, join = string.format, string.join
--WoW API / Variables
local GetArmorPenetration = GetArmorPenetration
local PAPERDOLLFRAME_TOOLTIP_FORMAT = PAPERDOLLFRAME_TOOLTIP_FORMAT

local armorPenPercent
local displayString = ""
local lastPanel

local function OnEvent(self)
    lastPanel = self
    armorPenPercent = GetArmorPenetration()
    self.text:SetFormattedText(displayString, armorPenPercent)
end

local function OnEnter(self)
    DT:SetupTooltip(self)
    DT.tooltip:AddLine(format("%s %.2f%%", format(PAPERDOLLFRAME_TOOLTIP_FORMAT, "Armor Penetration"), armorPenPercent), 1, 1, 1)
    DT.tooltip:Show()
end

local function ValueColorUpdate(hex)
    displayString = join("", "Armor Pen", ": ", hex, "%.2f%%|r")

    if lastPanel ~= nil then
        OnEvent(lastPanel)
    end
end
E.valueColorUpdateFuncs[ValueColorUpdate] = true

DT:RegisterDatatext("Armor Penetration", {"COMBAT_RATING_UPDATE", "PLAYER_ENTERING_WORLD"}, OnEvent, nil, nil, OnEnter, nil, "Armor Penetration")