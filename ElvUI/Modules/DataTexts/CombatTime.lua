local E, L, V, P, G = unpack(select(2, ...)) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local DT = E:GetModule("DataTexts")

--Lua functions
local floor = math.floor
local format, join = string.format, string.join
--WoW API / Variables
local COMBAT = COMBAT

local timer = 0
local displayNumberString = ""

local lastPanel

local acc = 0
local function OnUpdate(self, elapsed)
	timer = timer + elapsed

	-- 30fps cap: the hundredths display stays visually smooth without a
	-- string format + text set on every rendered frame for the whole fight
	acc = acc + elapsed
	if acc < 0.033 then return end
	acc = 0

	self.text:SetFormattedText(displayNumberString, format("%02d:%02d:%02d", floor(timer / 60), timer % 60, (timer - floor(timer)) * 100))
end

local function OnEvent(self, event)
	if event == "PLAYER_REGEN_DISABLED" then
		timer = 0
		self:SetScript("OnUpdate", OnUpdate)
	elseif event == "PLAYER_REGEN_ENABLED" then
		self:SetScript("OnUpdate", nil)
	else
		self.text:SetFormattedText(displayNumberString, "00:00:00")
	end

	lastPanel = self
end

local function ValueColorUpdate(hex)
	displayNumberString = join("", COMBAT, ": ", hex, "%s|r")

	if lastPanel ~= nil then
		OnEvent(lastPanel)
	end
end
E.valueColorUpdateFuncs[ValueColorUpdate] = true

DT:RegisterDatatext("Combat Time", {"PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED"}, OnEvent, nil, nil, nil, nil, L["Combat Time"])