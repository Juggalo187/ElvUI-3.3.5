local E, L, V, P, G = unpack(select(2, ...))
local NP = E:GetModule("NamePlates")

function NP:Update_PVPRole(frame)
	local db = NP:PlateDB(frame)
	local role = frame.PVPRole
	if not role or not db then return end

	if not (frame.UnitType == "FRIENDLY_PLAYER" or frame.UnitType == "ENEMY_PLAYER") then
		role:Hide()
		return
	end

	local showHealer = db.markHealers and NP.Healers[frame.UnitName]
	local showTank = db.markTanks and frame.UnitClass and false -- tank detection needs group role data

	if showHealer then
		role:SetTexture(E.Media.Textures.Healer)
		role:ClearAllPoints()
		if frame.Health:IsShown() then
			role:Point("RIGHT", frame.Health, "LEFT", -6, 0)
		else
			role:Point("BOTTOM", frame.Name, "TOP", 0, 3)
		end
		role:Show()
	elseif showTank and E.Media.Textures.Tank then
		role:SetTexture(E.Media.Textures.Tank)
		role:ClearAllPoints()
		role:Point("RIGHT", frame.Health:IsShown() and frame.Health or frame.Name, "LEFT", -6, 0)
		role:Show()
	else
		role:Hide()
	end
end

function NP:Construct_PVPRole(frame)
	local texture = frame:CreateTexture(nil, "OVERLAY", nil, 1)
	texture:Size(40, 40)
	texture:Hide()
	return texture
end
