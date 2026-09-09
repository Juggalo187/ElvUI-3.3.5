local E, L, V, P, G = unpack(ElvUI)
local S = E:GetModule("Skins")
local AS = E:GetModule("AddOnSkins")

if not AS:IsAddonLODorEnabled("MoveAnything") then return end

local _G = _G
local unpack = unpack

-- MoveAnything 3.3.5-10
-- https://www.curseforge.com/wow/addons/move-anything/files/434496

S:AddCallbackForAddon("MoveAnything", "MoveAnything", function()
	if not E.private.addOnSkins.MoveAnything then return end

	local SPACING = 1 + (E.Spacing * 2)

	local moverOnShow = function(self)
		_G[self:GetName() .. "Backdrop"]:SetBackdropBorderColor(unpack(E.media.rgbvaluecolor))
	end
	local moverOnEnter = function(self)
		_G[self:GetName() .. "BackdropMovingFrameName"]:SetTextColor(1, 1, 1)
	end
	local moverOnLeave = function(self)
		_G[self:GetName() .. "BackdropMovingFrameName"]:SetTextColor(unpack(E.media.rgbvaluecolor))
	end

	for i = 1, 20 do
		local backdrop = _G["MAMover" .. i .. "Backdrop"]
		local mover = _G["MAMover" .. i]
		if backdrop then
			backdrop:SetTemplate("Transparent")
		end
		if mover then
			mover:HookScript("OnShow", moverOnShow)
			mover:SetScript("OnEnter", moverOnEnter)
			mover:SetScript("OnLeave", moverOnLeave)
		end
	end

	if MAOptions then
		MAOptions:StripTextures()
		MAOptions:SetTemplate("Transparent")
		MAOptions:Size(420, 500 + (16 * SPACING))
	end

	if MAOptionsCharacterSpecific then S:HandleCheckBox(MAOptionsCharacterSpecific) end
	if MAOptionsToggleTooltips then S:HandleCheckBox(MAOptionsToggleTooltips) end
	if MAOptionsToggleModifiedFramesOnly then S:HandleCheckBox(MAOptionsToggleModifiedFramesOnly) end
	if MAOptionsToggleCategories then S:HandleCheckBox(MAOptionsToggleCategories) end

	if MAOptionsResetAll then S:HandleButton(MAOptionsResetAll) end
	if MAOptionsClose then S:HandleButton(MAOptionsClose) end
	if MAOptionsSync then S:HandleButton(MAOptionsSync) end

	for i = 1, 17 do
		local row = _G["MAMove" .. i]
		local backdrop = _G["MAMove" .. i .. "Backdrop"]
		if backdrop then
			backdrop:SetTemplate("Default")
		end
		if _G["MAMove" .. i .. "Move"] then
			S:HandleCheckBox(_G["MAMove" .. i .. "Move"])
		end
		if _G["MAMove" .. i .. "Hide"] then
			S:HandleCheckBox(_G["MAMove" .. i .. "Hide"])
		end
		if _G["MAMove" .. i .. "Reset"] then
			S:HandleButton(_G["MAMove" .. i .. "Reset"])
		end
		if i ~= 1 and row and _G["MAMove" .. (i - 1)] then
			row:SetPoint("TOPLEFT", "MAMove" .. (i - 1), "BOTTOMLEFT", 0, -SPACING)
		end
	end

	if MAScrollFrame then
		MAScrollFrame:Size(380, 442 + (16 * SPACING))
	end
	if MAScrollFrameScrollBar then
		S:HandleScrollBar(MAScrollFrameScrollBar)
	end
	if MAScrollBorder then
		MAScrollBorder:StripTextures()
	end

	if not MANudger then return end
	MANudger:SetTemplate("Transparent")
	S:HandleButton(MANudger_NudgeUp)
	MANudger_NudgeUp:Point("CENTER", 0, 24 + SPACING)
	S:HandleButton(MANudger_CenterMe)
	MANudger_CenterMe:Point("TOP", MANudger_NudgeUp, "BOTTOM", 0, -SPACING)
	S:HandleButton(MANudger_NudgeDown)
	MANudger_NudgeDown:Point("TOP", MANudger_CenterMe, "BOTTOM", 0, -SPACING)
	S:HandleButton(MANudger_NudgeLeft)
	MANudger_NudgeLeft:Point("RIGHT", MANudger_CenterMe, "LEFT", -SPACING, 0)
	S:HandleButton(MANudger_NudgeRight)
	MANudger_NudgeRight:Point("LEFT", MANudger_CenterMe, "RIGHT", SPACING, 0)
	S:HandleButton(MANudger_CenterH)
	S:HandleButton(MANudger_CenterV)
	S:HandleButton(MANudger_Detach)
	S:HandleButton(MANudger_Hide)
	S:HandleButton(MANudger_MoverPlus)
	S:HandleButton(MANudger_MoverMinus)

	if GameMenuButtonMoveAnything then
		S:HandleButton(GameMenuButtonMoveAnything)
	end
end)