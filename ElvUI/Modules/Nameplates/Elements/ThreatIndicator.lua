local E, L, V, P, G = unpack(select(2, ...))
local NP = E:GetModule("NamePlates")

function NP:Update_ThreatIndicator(frame)
	local db = NP.db.threat
	local indicator = frame.ThreatIndicator
	if not indicator then return end

	if frame.UnitType ~= "ENEMY_NPC" or not db.enable or not db.indicator then
		indicator:Hide()
		return
	end

	local status = frame.ThreatStatus
	if not status then
		indicator:Hide()
		return
	end

	local colors = NP.db.colors.threat
	local color
	if status == 3 then
		color = E.Role == "Tank" and colors.goodColor or colors.badColor
	elseif status == 2 then
		color = E.Role == "Tank" and colors.badTransition or colors.goodTransition
	elseif status == 1 then
		color = E.Role == "Tank" and colors.goodTransition or colors.badTransition
	else
		color = E.Role == "Tank" and colors.badColor or colors.goodColor
	end

	indicator:SetVertexColor(color.r, color.g, color.b)
	indicator:ClearAllPoints()
	indicator:Point("CENTER", frame.Health:IsShown() and frame.Health or frame.Name, "TOPRIGHT", 0, 4)
	indicator:Show()
end

function NP:Construct_ThreatIndicator(frame)
	local indicator = frame:CreateTexture(nil, "OVERLAY")
	indicator:SetTexture([[Interface\TargetingFrame\UI-TargetingFrame-Flash]])
	indicator:Size(16, 16)
	indicator:Hide()
	return indicator
end
