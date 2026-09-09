local E, L, V, P, G = unpack(select(2, ...))
local NP = E:GetModule("NamePlates")

local UnitIsPVP = UnitIsPVP
local UnitFactionGroup = UnitFactionGroup

function NP:Update_PvPIndicator(frame)
	local db = NP:PlateDB(frame)
	if not db or not db.pvpindicator or not db.pvpindicator.enable or not frame.PvPIndicator then
		if frame.PvPIndicator then frame.PvPIndicator:Hide() end
		return
	end

	if not (frame.UnitType == "FRIENDLY_PLAYER" or frame.UnitType == "ENEMY_PLAYER") then
		frame.PvPIndicator:Hide()
		return
	end

	local unit = NP:ResolvePlateUnit(frame)
	if not unit or not UnitIsPVP(unit) then
		frame.PvPIndicator:Hide()
		return
	end

	local faction = UnitFactionGroup(unit)
	local icon = frame.PvPIndicator
	icon:Size(db.pvpindicator.size, db.pvpindicator.size)
	icon:ClearAllPoints()
	icon:Point(E.InversePoints[db.pvpindicator.position], frame, db.pvpindicator.position, db.pvpindicator.xOffset, db.pvpindicator.yOffset)

	if faction == "Horde" then
		icon:SetTexture([[Interface\TargetingFrame\UI-PVP-Horde]])
	elseif faction == "Alliance" then
		icon:SetTexture([[Interface\TargetingFrame\UI-PVP-Alliance]])
	else
		icon:SetTexture([[Interface\TargetingFrame\UI-PVP-FFA]])
	end
	icon:SetTexCoord(0, 0.65625, 0, 0.65625)
	icon:Show()
end

function NP:Update_PvPClassificationIndicator(frame)
	if frame.PvPClassificationIndicator then frame.PvPClassificationIndicator:Hide() end
end

function NP:Construct_PvPIndicator(frame)
	local icon = frame:CreateTexture(nil, "OVERLAY")
	icon:Hide()
	return icon
end

function NP:Construct_PvPClassificationIndicator(frame)
	local icon = frame:CreateTexture(nil, "OVERLAY")
	icon:Hide()
	return icon
end
