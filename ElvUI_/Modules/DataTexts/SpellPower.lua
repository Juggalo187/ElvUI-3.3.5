local E, L, V, P, G = unpack(select(2, ...))
local DT = E:GetModule("DataTexts")

--Lua functions
local format, join = string.format, string.join
--WoW API / Variables
local GetSpellBonusDamage = GetSpellBonusDamage
local GetSpellBonusHealing = GetSpellBonusHealing
local PAPERDOLLFRAME_TOOLTIP_FORMAT = PAPERDOLLFRAME_TOOLTIP_FORMAT

local spellDamage, spellHealing
local displayNumberString = ""
local lastPanel

local function OnEvent(self)
	spellDamage  = GetSpellBonusDamage(7)
	spellHealing = GetSpellBonusHealing()

	if spellHealing > spellDamage then
		self.text:SetFormattedText(displayNumberString, L["HP"], spellHealing)
	else
		self.text:SetFormattedText(displayNumberString, L["SP"], spellDamage)
	end
	lastPanel = self
end

local function OnEnter(self)
	DT:SetupTooltip(self)

	DT.tooltip:AddLine(format("%s %d", format(PAPERDOLLFRAME_TOOLTIP_FORMAT, L["SP"]), spellDamage), 1, 1, 1)
	DT.tooltip:AddLine(format("%s %d", format(PAPERDOLLFRAME_TOOLTIP_FORMAT, L["HP"]), spellHealing), 1, 1, 1)
	DT.tooltip:Show()
end

local function ValueColorUpdate(hex)
	displayNumberString = join("", "%s: ", hex, "%d|r")

	if lastPanel ~= nil then
		OnEvent(lastPanel)
	end
end
E.valueColorUpdateFuncs[ValueColorUpdate] = true

DT:RegisterDatatext("Spell/Heal Power", {"PLAYER_DAMAGE_DONE_MODS"}, OnEvent, nil, nil, OnEnter, nil, L["Spell/Heal Power"])