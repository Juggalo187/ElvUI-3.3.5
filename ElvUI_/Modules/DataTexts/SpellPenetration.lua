local E, L, V, P, G = unpack(select(2, ...))
local DT = E:GetModule("DataTexts")

-- Lua functions
local format, join, gmatch = string.format, string.join, string.gmatch
local pcall, tostring = pcall, tostring

-- WoW API / Variables
local GetSpellPenetration = GetSpellPenetration
local PAPERDOLLFRAME_TOOLTIP_FORMAT = PAPERDOLLFRAME_TOOLTIP_FORMAT
local SPELL_PENETRATION = SPELL_PENETRATION or "Spell Penetration"
local SPELL_PENETRATION_TOOLTIP = SPELL_PENETRATION_TOOLTIP

local spellPenetration = 0
local displayString = ""
local lastPanel

local function OnEvent(self)
    lastPanel = self
    spellPenetration = GetSpellPenetration() or 0
    self.text:SetFormattedText(displayString, spellPenetration)
end

local function OnEnter(self)
    DT:SetupTooltip(self)

    spellPenetration = GetSpellPenetration() or 0

    -- Line 1 (white header): "Spell Penetration 0"
    DT.tooltip:AddLine(format("%s %d", format(PAPERDOLLFRAME_TOOLTIP_FORMAT or "%s", SPELL_PENETRATION), spellPenetration), 1, 1, 1)

    -- Line 2 (grey body): Localized 3.3.5a Spell Penetration description
    local rawTooltip = SPELL_PENETRATION_TOOLTIP or _G.SPELL_PENETRATION_TOOLTIP
    if rawTooltip then
        -- Pass the value multiple times in case the localized string expects the number more than once
        local ok, formattedText = pcall(format, rawTooltip, spellPenetration, spellPenetration, spellPenetration)
        
        -- Bulletproof fallback: manually replace %d if the format engine still rejects it
        if not ok then
            formattedText = rawTooltip:gsub("%%d", tostring(spellPenetration))
        end

        for line in gmatch(formattedText, "[^\r\n]+") do
            DT.tooltip:AddLine(line, nil, nil, nil, 1)
        end
    end

    DT.tooltip:Show()
end

local function ValueColorUpdate(hex)
    displayString = join("", SPELL_PENETRATION, ": ", hex, "%d|r")

    if lastPanel ~= nil then
        OnEvent(lastPanel)
    end
end
E.valueColorUpdateFuncs[ValueColorUpdate] = true

DT:RegisterDatatext("Spell Penetration", {"COMBAT_RATING_UPDATE", "PLAYER_ENTERING_WORLD"}, OnEvent, nil, nil, OnEnter, nil, SPELL_PENETRATION)