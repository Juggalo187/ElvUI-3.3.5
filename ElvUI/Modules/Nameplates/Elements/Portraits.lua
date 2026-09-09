local E, L, V, P, G = unpack(select(2, ...))
local NP = E:GetModule("NamePlates")

local _G = _G
local unpack = unpack
local UnitIsPlayer = UnitIsPlayer

function NP:Update_Portrait(frame)
	local db = NP:PlateDB(frame)
	if not db or not db.portrait or not db.portrait.enable then
		if frame.Portrait then frame.Portrait:Hide() end
		return
	end

	if not (frame.UnitType == "FRIENDLY_PLAYER" or frame.UnitType == "ENEMY_PLAYER") then
		frame.Portrait:Hide()
		return
	end

	local portrait = frame.Portrait
	portrait:Size(db.portrait.width, db.portrait.height)
	portrait:ClearAllPoints()
	portrait:Point(E.InversePoints[db.portrait.position], frame, db.portrait.position, db.portrait.xOffset, db.portrait.yOffset)

	if db.portrait.classicon and frame.UnitClass then
		portrait:SetTexture([[Interface\GLUES\CHARACTERCREATE\UI-CHARACTERCREATE-CLASSES]])
		portrait:SetTexCoord(unpack(_G.CLASS_ICON_TCOORDS[frame.UnitClass]))
	else
		portrait:SetTexture([[Interface\Icons\INV_Misc_QuestionMark]])
		portrait:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	end

	portrait:Show()
end

function NP:Configure_Portrait(frame)
	local db = NP:PlateDB(frame)
	if not db or not db.portrait then return end
end

function NP:Construct_Portrait(frame)
	local portrait = frame:CreateTexture(nil, "OVERLAY", nil, 2)
	portrait:Hide()
	return portrait
end
