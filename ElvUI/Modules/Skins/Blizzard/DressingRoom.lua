local E, L, V, P, G = unpack(select(2, ...)) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local S = E:GetModule("Skins")

-- Ebonhold: the "if <widget> then" guards below cover widgets that patch-D
-- drops from its Interface\FrameXML\* overrides. These are direct method
-- calls, so the nil-guards added to S:Handle* in Skins.lua do not cover them.

--Lua functions
--WoW API / Variables
if not string.find(string.lower(E.myrealm), "rogue-lite", 1, true) then
S:AddCallback("Skin_DressingRoom", function()
	if not E.private.skins.blizzard.enable or not E.private.skins.blizzard.dressingroom then return end

	if string.find(string.lower(E.myrealm), "rogue-lite", 1, true) then
		do return end
	end

	DressUpFrame:StripTextures()
	DressUpFrame:CreateBackdrop("Transparent")
	DressUpFrame.backdrop:Point("TOPLEFT", 11, -12)
	DressUpFrame.backdrop:Point("BOTTOMRIGHT", -32, 76)

	S:SetUIPanelWindowInfo(DressUpFrame, "width")
	S:SetBackdropHitRect(DressUpFrame)

	-- Ebonhold: guarded. patch-D ships its own Interface\FrameXML\DressUpFrame.xml,
	-- which fully replaces the stock file and no longer defines this widget.
	-- Indexing it raised a nil-value error that aborted the rest of this skin.
	if DressUpFramePortrait then DressUpFramePortrait:Kill() end

	SetDressUpBackground()
	for _, bgName in ipairs({"DressUpBackgroundTopLeft", "DressUpBackgroundTopRight",
		"DressUpBackgroundBotLeft", "DressUpBackgroundBotRight"}) do
		local bg = _G[bgName]
		if bg then bg:SetDesaturated(true) end
	end

	if DressUpFrameCloseButton then S:HandleCloseButton(DressUpFrameCloseButton, DressUpFrame.backdrop) end

	S:HandleRotateButton(DressUpModelRotateLeftButton)
	S:HandleRotateButton(DressUpModelRotateRightButton)

	S:HandleButton(DressUpFrameCancelButton)
	S:HandleButton(DressUpFrameResetButton)

	DressUpModel:CreateBackdrop("Default")
	DressUpModel.backdrop:SetOutside(DressUpModel)

	if DressUpFrameDescriptionText then DressUpFrameDescriptionText:Point("CENTER", DressUpFrameTitleText, "BOTTOM", 10, -18) end

	if DressUpModelRotateLeftButton then DressUpModelRotateLeftButton:Point("TOPLEFT", DressUpFrame, 29, -76) end
	if DressUpModelRotateRightButton then DressUpModelRotateRightButton:Point("TOPLEFT", DressUpModelRotateLeftButton, "TOPRIGHT", 3, 0) end

	DressUpModel:Size(323, 331)
	DressUpModel:ClearAllPoints()
	DressUpModel:Point("TOPLEFT", 20, -67)

	if DressUpBackgroundTopLeft then DressUpBackgroundTopLeft:Point("TOPLEFT", 23, -67) end

	if DressUpFrameCancelButton then DressUpFrameCancelButton:Point("CENTER", DressUpFrame, "TOPLEFT", 304, -417) end
	if DressUpFrameResetButton then DressUpFrameResetButton:Point("RIGHT", DressUpFrameCancelButton, "LEFT", -3, 0) end
end)
end