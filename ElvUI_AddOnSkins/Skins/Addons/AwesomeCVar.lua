local E, L, V, P, G = unpack(ElvUI)
local S = E:GetModule("Skins")
local AS = E:GetModule("AddOnSkins")

if not AS:IsAddonLODorEnabled("AwesomeCVar") then return end

local _G = _G
local ipairs = ipairs
local match = string.match
local find = string.find
local sub = string.sub

S:AddCallbackForAddon("AwesomeCVar", "Skin_AwesomeCVar", function()
	if not E.private.addOnSkins.AwesomeCVar then return end

	-- ============================================================
	-- Per-CVar controls (sliders, checkboxes, dropdowns, radios,
	-- reset buttons, control containers).
	--
	-- These are all created in UI.lua with getFrameName(prefix, suffix)
	-- -> "AwesomeCVar_" .. cvarName .. suffix. We can't iterate
	-- ACVar.CVARS (it's a local upvalue), so we enumerate all frames
	-- and match on the name prefix instead.
	-- ============================================================
	local function SkinCVarControls()
		local f = EnumerateFrames()
		while f do
			local name = f:GetName()
			if name and sub(name, 1, 12) == "AwesomeCVar_" then
				if find(name, "SliderValue$") then
					-- fontstring placeholder, nothing to skin
				elseif find(name, "Slider$") then
					if not f.__elvSkinned then
						S:HandleSliderFrame(f)
						f.__elvSkinned = true
					end
				elseif find(name, "Checkbox$") then
					if not f.__elvSkinned then
						S:HandleCheckBox(f, true)
						f.__elvSkinned = true
					end
				elseif find(name, "Dropdown$") then
					if not f.__elvSkinned then
						S:HandleDropDownBox(f)

						local btn = _G[name.."Button"]
						if btn then
							btn:ClearAllPoints()
							btn:Point("RIGHT", f, "RIGHT", -8, 0)
							btn:Size(20, 20)
						end

						local _, p = f:GetPoint()
						f:ClearAllPoints()
						f:SetPoint("TOPLEFT", p)
						f:SetPoint("TOPRIGHT", p)
						f.xOffset = 1

						f.__elvSkinned = true
					end
				elseif find(name, "Radio%d+$") then
					if not f.__elvSkinned then
						S:HandleCheckBox(f, true)
						f.__elvSkinned = true
					end
				elseif find(name, "ResetButton$") then
					if not f.isSkinned then
						S:HandleButton(f)
					end
				elseif find(name, "Control$") then
					if not f.__elvSkinned then
						f:StripTextures()
						f:SetTemplate("Transparent")
						f.__elvSkinned = true
					end
				end
			end
			f = EnumerateFrames(f)
		end
	end

	-- ============================================================
	-- Main frame, tabs, scrollframes, subpanels, bottom buttons
	-- ============================================================
	local function SkinMainFrame()
		local frame = _G.AwesomeCVarFrame
		if not frame or frame.__elvSkinned then return end

		frame:StripTextures()
		frame:SetTemplate("Transparent")

		local titleClose = _G.AwesomeCVarFrameClose
		if titleClose then
			S:HandleCloseButton(titleClose)
		end

		-- Tabs. frame.numTabs is set by UI.lua before creating each tab.
		for i = 1, (frame.numTabs or 12) do
			local tab = _G["AwesomeCVarFrameTab"..i]
			if not tab then break end
			if not tab.__elvSkinned then
				S:HandleTab(tab)

				local text = _G[tab:GetName().."Text"]
				if text then
					text:ClearAllPoints()
					text:Point("CENTER", 0, 1)
				end

				tab.__elvSkinned = true
			end
		end

		-- Scroll frames and their subpanels
		for _, child in ipairs({ frame:GetChildren() }) do
			if child:GetObjectType() == "ScrollFrame" then
				local cname = child:GetName() or ""

				if not child.__elvSkinned then
					child:StripTextures()

					local sb = _G[cname.."ScrollBar"]
					if sb then
						S:HandleScrollBar(sb)
					end

					child.__elvSkinned = true
				end

				local category = match(cname, "^AwesomeCVarScrollFrame_(.+)$")
				if category then
					local subPanel = _G["AwesomeCVarFramePanel_"..category]
					if subPanel and not subPanel.__elvSkinned then
						subPanel:StripTextures()
						subPanel:SetTemplate("Transparent")
						subPanel.__elvSkinned = true
					end
				end
			end
		end

		-- Bottom buttons
		for _, name in ipairs({
			"AwesomeCVarCloseButton",
			"AwesomeCVarOkayButton",
			"AwesomeCVarDefaultsButton",
		}) do
			local b = _G[name]
			if b and not b.isSkinned then
				S:HandleButton(b)
			end
		end

		-- Checkboxes at the bottom
		for _, name in ipairs({
			"AwesomeCVarMinimapCheck",
			"AwesomeCVarGameMenuCheck",
		}) do
			local cb = _G[name]
			if cb and not cb.__elvSkinned then
				S:HandleCheckBox(cb)
				cb:Size(24, 24)

				local text = _G[name.."Text"]
				if text then
					text:ClearAllPoints()
					text:Point("LEFT", cb, "RIGHT", 5, 0)
				end

				cb.__elvSkinned = true
			end
		end

		frame.__elvSkinned = true
	end

	-- ============================================================
	-- Popups (reload confirmation, defaults confirmation)
	-- ============================================================
	local function SkinPopups()
		for _, name in ipairs({
			"AwesomeCVarReloadPopup",
			"AwesomeCVarDefaultConfirmationPopup",
		}) do
			local p = _G[name]
			if p and not p.__elvSkinned then
				p:StripTextures()
				p:SetTemplate("Transparent")
				p.__elvSkinned = true
			end
		end

		for _, name in ipairs({
			"AwesomeCVarAcceptButton",
			"AwesomeCVarCancelButton",
			"AwesomeCVar_ConfirmResetButton",
			"AwesomeCVar_CancelResetButton",
		}) do
			local b = _G[name]
			if b and not b.isSkinned then
				S:HandleButton(b)
			end
		end
	end

	-- ============================================================
	-- Blizzard Interface Options panel entry button
	-- ============================================================
	local function SkinBlizzOptions()
		local btn = _G.AwesomeCVarBlizzOpenBtn
		if btn and not btn.isSkinned then
			S:HandleButton(btn)
		end
	end

	-- ============================================================
	-- Escape menu button.
	--
	-- Two issues with the MPQ version's placement:
	--   1. Nothing skins it (the MPQ .toc has no Skins\ElvUI.lua).
	--   2. It anchors to GameMenuButtonMacros, which conflicts with
	--      ElvUI's reordered escape menu.
	--
	-- Anchor to Continue (what the newer addon version does) and
	-- grow the frame to fit. Guard the height change so we only do
	-- it once, and shrink it back on hide.
	-- ============================================================
		local function SkinEscapeButton()
		local btn = _G.GameMenuButtonAwesomeCVar
		local continue = _G.GameMenuButtonContinue
		local menuFrame = _G.GameMenuFrame
		local macros = _G.GameMenuButtonMacros

		if not (btn and continue and menuFrame) then return end

		if not btn.isSkinned then
			S:HandleButton(btn)
		end

		-- The MPQ version anchored Macros relative to our button, which
		-- creates a cycle once we try to anchor the button to Continue.
		-- Detach Macros first and restore it to its Blizzard default
		-- anchor (it sits above Continue in the stock menu).
		if macros then
			macros:ClearAllPoints()
			macros:SetPoint("TOPLEFT", _G.GameMenuButtonKeybindings or continue, "BOTTOMLEFT", 0, -1)
		end

		btn:ClearAllPoints()
		btn:SetPoint("TOP", continue, "BOTTOM", 0, -1)

		if not btn.__elvHookedShow then
			btn:HookScript("OnShow", function(self)
				local anchor, anchorBottom
				for _, child in ipairs({ menuFrame:GetChildren() }) do
					if child ~= self and child:IsShown() and child:GetObjectType() == "Button" then
						local bottom = child:GetBottom()
						if bottom and (not anchorBottom or bottom < anchorBottom) then
							anchorBottom, anchor = bottom, child
						end
					end
				end

				self:ClearAllPoints()
				self:SetPoint("TOP", anchor or continue, "BOTTOM", 0, -1)

				if not menuFrame.__elvGrownForAwesomeCVar then
					menuFrame:SetHeight(menuFrame:GetHeight() + 24)
					menuFrame.__elvGrownForAwesomeCVar = true
				end
			end)

			btn:HookScript("OnHide", function(self)
				if menuFrame.__elvGrownForAwesomeCVar then
					menuFrame:SetHeight(menuFrame:GetHeight() - 24)
					menuFrame.__elvGrownForAwesomeCVar = false
				end
			end)

			btn.__elvHookedShow = true
		end
	end

	-- ============================================================
	-- Run it all.
	--
	-- AddCallbackForAddon fires on ADDON_LOADED("AwesomeCVar"), which
	-- is after the addon's own OnLoad has run, so all of the frames
	-- created there already exist. A one-tick defer gives ElvUI's
	-- own Skin_Misc / GameMenu layout a chance to finish first.
	-- ============================================================
	local runner = CreateFrame("Frame")
	runner:SetScript("OnUpdate", function(self)
		self:SetScript("OnUpdate", nil)

		SkinEscapeButton()
		SkinMainFrame()
		SkinPopups()
		SkinBlizzOptions()
		SkinCVarControls()
	end)
end)