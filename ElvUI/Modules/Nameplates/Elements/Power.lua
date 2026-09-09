local E, L, V, P, G = unpack(select(2, ...))
local NP = E:GetModule("NamePlates")
local LSM = E.Libs.LSM

local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitPowerType = UnitPowerType
local UnitIsConnected = UnitIsConnected
local CreateFrame = CreateFrame

function NP:Update_Power(frame)
	local db = NP:PlateDB(frame)
	if not db or not db.power or not db.power.enable or not frame.Power then
		if frame.Power then frame.Power:Hide() end
		return
	end

	local unit = NP:ResolvePlateUnit(frame)
	if not unit then
		frame.Power:Hide()
		return
	end

	local power = frame.Power
	local cur = UnitPower(unit) or 0
	local max = UnitPowerMax(unit) or 1
	local ptype, ptoken = UnitPowerType(unit)

	power:SetMinMaxValues(0, max)
	power:SetValue(cur)
	power:Size(db.power.width, db.power.height)
	power:ClearAllPoints()
	power:Point("CENTER", frame, "CENTER", db.power.xOffset, db.power.yOffset)

	local t = (NP.db.colors and NP.db.colors.power) or (E.db.unitframe and E.db.unitframe.colors and E.db.unitframe.colors.power)
	if t then
		t = t[ptoken] or t[ptype] or t.MANA
	end
	if t then
		power:SetStatusBarColor(t.r, t.g, t.b)
		if power.bg then
			power.bg:SetVertexColor(t.r * 0.35, t.g * 0.35, t.b * 0.35)
		end
	end

	if db.power.hideWhenEmpty and cur == 0 then
		power:Hide()
	elseif UnitIsConnected(unit) then
		power:Show()
	else
		power:Hide()
	end
end

function NP:Configure_Power(frame)
	local db = NP:PlateDB(frame)
	if not db or not db.power or not frame.Power then return end
	frame.Power:SetStatusBarTexture(LSM:Fetch("statusbar", NP.db.statusbar))
	E:SetSmoothing(frame.Power, NP.db.smoothbars)
end

function NP:Construct_Power(frame)
	local power = CreateFrame("StatusBar", nil, frame)
	power:CreateBackdrop("Transparent", nil, nil, nil, nil, true, true)
	power.bg = power:CreateTexture(nil, "BORDER")
	power.bg:SetAllPoints()
	power.bg:SetTexture(LSM:Fetch("statusbar", NP.db.statusbar))
	power:Hide()
	return power
end

function NP:Power_OnEvent()
	NP:ForEachVisiblePlate("Update_Power")
end
