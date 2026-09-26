local E, L, V, P, G = unpack(select(2, ...)); --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local AB = E:GetModule("ActionBars")

--Lua functions
local _G = _G
local unpack = unpack
local tinsert = tinsert
--WoW API / Variables
local CreateFrame = CreateFrame
local GameTooltip = GameTooltip
local InCombatLockdown = InCombatLockdown
local RegisterStateDriver = RegisterStateDriver

local MICRO_BUTTONS = {
	"CharacterMicroButton",
	"SpellbookMicroButton",
	"TalentMicroButton",
	"AchievementMicroButton",
	"QuestLogMicroButton",
	"SocialsMicroButton",
	"PVPMicroButton",
	"LFDMicroButton",
	"MainMenuMicroButton",
	"HelpMicroButton",
	"SoloCollectionsCollectionsMicroButton",
	"SoloCollectionsTransmogMicroButton",
}

do
	local existing = {}
	for i = 1, #MICRO_BUTTONS do
		if _G[MICRO_BUTTONS[i]] then
			existing[#existing + 1] = MICRO_BUTTONS[i]
		end
	end
	MICRO_BUTTONS = existing
end

local function onEnter(button)
	if AB.db.microbar.mouseover then
		E:UIFrameFadeIn(ElvUI_MicroBar, 0.2, ElvUI_MicroBar:GetAlpha(), AB.db.microbar.alpha)
	end

	if button and button ~= ElvUI_MicroBar and button.backdrop then
		button.backdrop:SetBackdropBorderColor(unpack(E.media.rgbvaluecolor))
	end
end

local function onLeave(button)
	if AB.db.microbar.mouseover then
		E:UIFrameFadeOut(ElvUI_MicroBar, 0.2, ElvUI_MicroBar:GetAlpha(), 0)
	end

	if button and button ~= ElvUI_MicroBar and button.backdrop then
		button.backdrop:SetBackdropBorderColor(unpack(E.media.bordercolor))
	end
end

function AB:HandleMicroButton(button)
	if not button then return end
	local pushed = button:GetPushedTexture()
	local normal = button:GetNormalTexture()
	local disabled = button:GetDisabledTexture()
	local highlight = button:GetHighlightTexture()

	local f = CreateFrame("Frame", nil, button)
	f:SetFrameLevel(button:GetFrameLevel() - 1)
	f:SetTemplate("Default", true)
	f:SetOutside(button)
	button.backdrop = f

	button:SetParent(ElvUI_MicroBar)
	if highlight then highlight:Kill() end
	button:HookScript("OnEnter", onEnter)
	button:HookScript("OnLeave", onLeave)
	button:SetHitRectInsets(0, 0, 0, 0)
	button:Show()

	local l, r, t, b = 0.17, 0.87, 0.5, 0.908
	if button.useFullIcon then
		l, r, t, b = unpack(E.TexCoords)
	end

	if pushed then
		pushed:SetTexCoord(l, r, t, b)
		pushed:SetInside(f)
	end

	if normal then
		normal:SetTexCoord(l, r, t, b)
		normal:SetInside(f)
	end

	if disabled then
		disabled:SetTexCoord(l, r, t, b)
		disabled:SetInside(f)
	end

	-- Frostmourne Icon Adjustments
	if string.find(string.lower(E.myrealm), "frostmourne", 1, true) then
		if button == _G.CollectionsMicroButton and _G.CollectionsMicroButtonIcon then
			_G.CollectionsMicroButtonIcon:ClearAllPoints()
			_G.CollectionsMicroButtonIcon:SetPoint("CENTER", button, "CENTER")
		end

		if button == _G.StoreMicroButton and _G.StoreMicroButtonIcon then
			_G.StoreMicroButtonIcon:ClearAllPoints()
			_G.StoreMicroButtonIcon:SetPoint("CENTER", button, "CENTER")
		elseif button == _G.ParagonMicroButton and _G.ParagonMicroButtonIcon then
			_G.ParagonMicroButtonIcon:SetInside(f)
		end
	end
end

function AB:UpdateMicroButtonsParent()
	if CharacterMicroButton:GetParent() == ElvUI_MicroBar then return end

	for i = 1, #MICRO_BUTTONS do
		local button = _G[MICRO_BUTTONS[i]]
		if button then
			button:SetParent(ElvUI_MicroBar)
		end
	end

	AB:UpdateMicroPositionDimensions()
end

function AB:UpdateMicroBarVisibility()
	if InCombatLockdown() then
		AB.NeedsUpdateMicroBarVisibility = true
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
		return
	end

	local visibility = self.db.microbar.visibility
	if visibility and string.match(visibility, "[\n\r]") then
		visibility = string.gsub(visibility, "[\n\r]", "")
	end

	RegisterStateDriver(ElvUI_MicroBar.visibility, "visibility", (self.db.microbar.enabled and visibility) or "hide")
end

function AB:UpdateMicroPositionDimensions()
	if not ElvUI_MicroBar then return end

	local numRows = 1
	local prevButton = ElvUI_MicroBar
	local offset = E:Scale(E.PixelMode and 1 or 3)
	local spacing = E:Scale(offset + self.db.microbar.buttonSpacing)

	for i = 1, #MICRO_BUTTONS do
		local button = _G[MICRO_BUTTONS[i]]
		if button then
			local lastColumnButton = i - self.db.microbar.buttonsPerRow
			lastColumnButton = _G[MICRO_BUTTONS[lastColumnButton]]

			button:Size(self.db.microbar.buttonSize, self.db.microbar.buttonSize * 1.4)
			button:ClearAllPoints()

			if prevButton == ElvUI_MicroBar then
				button:Point("TOPLEFT", prevButton, "TOPLEFT", offset, -offset)
			elseif (i - 1) % self.db.microbar.buttonsPerRow == 0 and lastColumnButton then
				button:Point("TOP", lastColumnButton, "BOTTOM", 0, -spacing)
				numRows = numRows + 1
			else
				button:Point("LEFT", prevButton, "RIGHT", spacing, 0)
			end

			prevButton = button
		end
	end

	if AB.db.microbar.mouseover and not ElvUI_MicroBar:IsMouseOver() then
		ElvUI_MicroBar:SetAlpha(0)
	else
		ElvUI_MicroBar:SetAlpha(self.db.microbar.alpha)
	end

	AB.MicroWidth = (((CharacterMicroButton:GetWidth() + spacing) * self.db.microbar.buttonsPerRow) - spacing) + (offset * 2)
	AB.MicroHeight = (((CharacterMicroButton:GetHeight() + spacing) * numRows) - spacing) + (offset * 2)
	ElvUI_MicroBar:Size(AB.MicroWidth, AB.MicroHeight)

	if ElvUI_MicroBar.mover then
		if self.db.microbar.enabled then
			E:EnableMover(ElvUI_MicroBar.mover:GetName())
		else
			E:DisableMover(ElvUI_MicroBar.mover:GetName())
		end
	end

	self:UpdateMicroBarVisibility()
end

function AB:UpdateMicroButtons()
	if _G.PVPMicroButtonTexture and _G.PVPMicroButton then
		PVPMicroButtonTexture:Point("TOPLEFT", PVPMicroButton, "TOPLEFT")
		PVPMicroButtonTexture:Point("BOTTOMRIGHT", PVPMicroButton, "BOTTOMRIGHT")
		PVPMicroButtonTexture:SetTexture("Interface\\AddOns\\ElvUI_\\media\\textures\\PVP-Icons")

		if PVPMicroButton.minLevel and E.mylevel < PVPMicroButton.minLevel then
			PVPMicroButtonTexture:SetDesaturated(true)
		else
			PVPMicroButtonTexture:SetDesaturated(false)
		end
	end

	self:UpdateMicroPositionDimensions()
end

function AB:SetupAstralMicroButton()
	if not E:IsAstralEnabled() or E.private.astral.microButton == false then return end
	if _G.AstralMicroButton then return end

	local button = CreateFrame("Button", "AstralMicroButton", ElvUI_MicroBar)
	button.useFullIcon = true
	button:RegisterForClicks("AnyUp")

	local icon = "Interface\\AddOns\\ProjectAstral\\astralhub"
	button:SetNormalTexture(icon)
	button:SetPushedTexture(icon)
	button:SetHighlightTexture(icon)

	button:SetScript("OnClick", function()
		if _G.ProjectAstral and ProjectAstral.ToggleMainMenu then
			ProjectAstral:ToggleMainMenu()
		end
	end)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Project Astral", 1, 0.82, 0)
		GameTooltip:AddLine("Open the Astral hub.", 1, 1, 1, true)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	MICRO_BUTTONS[#MICRO_BUTTONS + 1] = "AstralMicroButton"
	self:HandleMicroButton(button)
end

function AB:SetupEbonholdMicroButtons()
	local echoButton, skillButton = _G.EchoJournalMicroButton, _G.SkillTreeMicroButton
	if not echoButton then return end

	for i = 1, #MICRO_BUTTONS do
		if MICRO_BUTTONS[i] == "PVPMicroButton" then
			tremove(MICRO_BUTTONS, i)
			break
		end
	end

	for i = 1, #MICRO_BUTTONS do
		if MICRO_BUTTONS[i] == "SocialsMicroButton" then
			tinsert(MICRO_BUTTONS, i + 1, "EchoJournalMicroButton")
			break
		end
	end

	if skillButton then
		skillButton:UnregisterEvent("UPDATE_BINDINGS")
		skillButton:UnregisterEvent("PLAYER_ENTERING_WORLD")
	end

	_G.SkillTreeMicroButton_StartFlashing = function()
		E:Flash(echoButton, 0.5, true)
	end
	_G.SkillTreeMicroButton_StopFlashing = function()
		E:StopFlash(echoButton)
		echoButton:SetAlpha(1)
	end

	for i = 1, echoButton:GetNumRegions() do
		local region = select(i, echoButton:GetRegions())
		if region:GetObjectType() == "Texture" and region:GetDrawLayer() == "OVERLAY" then
			local tex = region:GetTexture()
			if tex and (strfind(strlower(tex), "guardianspirit", 1, true) or strfind(strlower(tex), "soulgem", 1, true)) then
				region:ClearAllPoints()
				region:SetPoint("CENTER", echoButton, "CENTER", 0, 0)
				region:SetWidth(14)
				region:SetHeight(14)
				break
			end
		end
	end

	local function repositionAlert(alert)
		local button = alert.microButton
		local _, y = button:GetCenter()
		alert:ClearAllPoints()
		if y and y > (E.UIParent:GetHeight() / 2) then
			alert:SetPoint("TOP", button, "BOTTOM", 0, -12)
			alert.Arrow:Hide()
		else
			alert:SetPoint("BOTTOM", button, "TOP", 0, 10)
			alert.Arrow:Show()
		end
	end

	local alerts = {echoButton.Alert, skillButton and skillButton.Alert}
	for i = 1, #alerts do
		local alert = alerts[i]
		alert.microButton = echoButton
		alert:SetClampedToScreen(true)
		alert:HookScript("OnShow", repositionAlert)
		if alert:IsShown() then repositionAlert(alert) end
	end

	local function updateHotkeys()
		echoButton.tooltipText = MicroButtonTooltipText("Character Progression", "Toggle Echo Journal")
	end

	local hotkeyWatcher = CreateFrame("Frame")
	hotkeyWatcher:RegisterEvent("UPDATE_BINDINGS")
	hotkeyWatcher:SetScript("OnEvent", updateHotkeys)
	updateHotkeys()
end

function AB:SetupFrostmourneMicroButtons()
	if not string.find(string.lower(E.myrealm), "frostmourne", 1, true) then return end

	local extraButtons = {
		{ name = "ParagonMicroButton", after = "QuestLogMicroButton" },
		{ name = "CollectionsMicroButton", after = "LFDMicroButton" },
		{ name = "StoreMicroButton", after = "CollectionsMicroButton" },
	}

	for _, info in ipairs(extraButtons) do
		local btnName = info.name
		if _G[btnName] then
			local alreadyAdded = false
			for i = 1, #MICRO_BUTTONS do
				if MICRO_BUTTONS[i] == btnName then
					alreadyAdded = true
					break
				end
			end

			if not alreadyAdded then
				local inserted = false
				for i = 1, #MICRO_BUTTONS do
					if MICRO_BUTTONS[i] == info.after then
						tinsert(MICRO_BUTTONS, i + 1, btnName)
						inserted = true
						break
					end
				end
				if not inserted then
					tinsert(MICRO_BUTTONS, btnName)
				end
			end
		end
	end
end

function AB:SetupMicroBar()
	local microBar = CreateFrame("Frame", "ElvUI_MicroBar", E.UIParent)
	microBar:Point("TOPLEFT", E.UIParent, "TOPLEFT", 4, -4)
	microBar:SetFrameStrata("LOW")
	microBar:EnableMouse(true)
	microBar:SetScript("OnEnter", onEnter)
	microBar:SetScript("OnLeave", onLeave)

	microBar.visibility = CreateFrame("Frame", nil, E.UIParent, "SecureHandlerStateTemplate")
	microBar.visibility:SetScript("OnShow", function() microBar:Show() end)
	microBar.visibility:SetScript("OnHide", function() microBar:Hide() end)

	if string.find(string.lower(E.myrealm), "project astral", 1, true) then
		self:SetupAstralMicroButton()
	end
	
	if string.find(string.lower(E.myrealm), "rogue-lite", 1, true) then
		self:SetupEbonholdMicroButtons()
	end

	if string.find(string.lower(E.myrealm), "frostmourne", 1, true) then
		self:SetupFrostmourneMicroButtons()
	end

	for i = 1, #MICRO_BUTTONS do
		self:HandleMicroButton(_G[MICRO_BUTTONS[i]])
	end

	if CharacterMicroButton and CharacterMicroButton.backdrop then
		MicroButtonPortrait:SetInside(CharacterMicroButton.backdrop)
	end

	if PVPMicroButtonTexture then
		if E.myfaction == "Alliance" then
			PVPMicroButtonTexture:SetTexCoord(0.545, 0.935, 0.070, 0.940)
		else
			PVPMicroButtonTexture:SetTexCoord(0.100, 0.475, 0.070, 0.940)
		end
	end

	self:SecureHook("VehicleMenuBar_MoveMicroButtons", "UpdateMicroButtonsParent")
	self:SecureHook("UpdateMicroButtons")

	self:UpdateMicroPositionDimensions()
	if MainMenuBarPerformanceBar then
		MainMenuBarPerformanceBar:Kill()
	end

	E:CreateMover(microBar, "MicrobarMover", L["Micro Bar"], nil, nil, nil, "ALL,ACTIONBARS", nil, "actionbar,microbar")
end