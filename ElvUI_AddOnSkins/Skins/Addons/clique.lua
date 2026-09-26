local E, L, V, P, G = unpack(ElvUI_)
local S = E:GetModule("Skins")
local AS = E:GetModule("AddOnSkins")

if not AS:IsAddonLODorEnabled("Clique") then return end

local _G = _G
local unpack = unpack

local FauxScrollFrame_GetOffset = FauxScrollFrame_GetOffset

-- Clique Dual-Version Compatible Skin
S:AddCallbackForAddon("Clique", "Clique", function()
	if not E.private.addOnSkins.Clique then return end

	-- Dual-version frame references
	local tab = CliqueSpellTab or CliquePulloutTab
	if CliqueConfig and not CliqueFrame then CliqueFrame = CliqueConfig end

	-- Skin Spellbook Tab
	if tab then
		tab:StyleButton(nil, true)
		tab:SetTemplate("Default", true)
		local normTex = tab:GetNormalTexture()
		if normTex then
			normTex:SetTexCoord(unpack(E.TexCoords))
			normTex:SetInside()
		end
		tab:GetRegions():Hide()
	end

	local function SkinFrame(frame)
		if not frame then return end
		frame:StripTextures()
		frame:SetTemplate("Transparent")

		if frame.titleBar then
			frame.titleBar:StripTextures()
			frame.titleBar:SetTemplate("Default", true)
			frame.titleBar:Height(20)
			frame.titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
			frame.titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
		end
	end

	local function listItemOnEnter(self)
		self:SetBackdropBorderColor(unpack(E.media.rgbvaluecolor))
	end

	local function listItemOnLeave(self)
		local offset = FauxScrollFrame_GetOffset(CliqueListScroll)
		if (self.id + offset) == Clique.listSelected then
			self:SetBackdropBorderColor(1, 1, 1)
		else
			self:SetBackdropBorderColor(unpack(E.media.bordercolor))
		end
	end

	local function ApplyOptionsSkin()
		local mainFrame = CliqueConfig or CliqueFrame
		if not mainFrame then return end

		-- Main Frame
		SkinFrame(mainFrame)
		mainFrame:Height(424)
		if SpellBookFrame then
			mainFrame:Point("LEFT", SpellBookFrame, "RIGHT", 6, 32)
		end

		if CliqueButtonClose then
			S:HandleCloseButton(CliqueButtonClose)
			CliqueButtonClose:Size(32)
			CliqueButtonClose:Point("TOPRIGHT", 5, 6)
		end

		if CliqueDropDown then
			S:HandleDropDownBox(CliqueDropDown, 170)
			CliqueDropDown:Point("TOPRIGHT", 0, -26)
		end

		if CliqueList1 then
			CliqueList1:Point("TOPLEFT", 8, -56)
		end

		if CliqueListScroll then
			CliqueListScroll:StripTextures()
			if CliqueListScrollScrollBar then
				S:HandleScrollBar(CliqueListScrollScrollBar)
				CliqueListScrollScrollBar:Point("TOPLEFT", CliqueListScroll, "TOPRIGHT", 3, -19)
				CliqueListScrollScrollBar:Point("BOTTOMLEFT", CliqueListScroll, "BOTTOMRIGHT", 3, 19)
			end
		end

		if CliqueButtonCustom then
			CliqueButtonCustom:Point("BOTTOMLEFT", 8, 8)
			S:HandleButton(CliqueButtonCustom)
		end

		for i = 1, 10 do
			local entry = _G["CliqueList"..i]
			if entry then
				entry:Size(388, 32)
				entry:SetTemplate("Default")
				if entry.icon then
					entry.icon:Point("LEFT", 4, 0)
					entry.icon:SetTexCoord(unpack(E.TexCoords))
				end

				if i > 1 and _G["CliqueList" .. (i - 1)] then
					entry:Point("TOP", _G["CliqueList" .. (i - 1)], "BOTTOM", 0, -1)
				end

				entry:SetScript("OnEnter", listItemOnEnter)
				entry:SetScript("OnLeave", listItemOnLeave)
			end
		end

		if CliqueButtonFrames then S:HandleButton(CliqueButtonFrames) end
		if CliqueButtonProfiles then S:HandleButton(CliqueButtonProfiles) end
		if CliqueButtonOptions then S:HandleButton(CliqueButtonOptions) end
		if CliqueButtonDelete then S:HandleButton(CliqueButtonDelete) end
		if CliqueButtonEdit then S:HandleButton(CliqueButtonEdit) end

		-- OptionsFrame
		if CliqueOptionsFrame then
			SkinFrame(CliqueOptionsFrame)
			CliqueOptionsFrame:Height(125)
			CliqueOptionsFrame:Point("TOPLEFT", mainFrame, "TOPRIGHT", -1, 0)

			if CliqueOptionsButtonClose then
				S:HandleCloseButton(CliqueOptionsButtonClose)
				CliqueOptionsButtonClose:Size(32)
				CliqueOptionsButtonClose:Point("TOPRIGHT", 5, 6)
			end

			if CliqueOptionsAnyDown then
				S:HandleCheckBox(CliqueOptionsAnyDown)
				if CliqueOptionsAnyDown.backdrop then
					CliqueOptionsAnyDown.backdrop:Point("TOPLEFT", 6, -4)
					CliqueOptionsAnyDown.backdrop:Point("BOTTOMRIGHT", -4, 3)
					if CliqueOptionsAnyDown.name then
						CliqueOptionsAnyDown.backdrop:Point("TOPRIGHT", CliqueOptionsAnyDown.name, "TOPLEFT", -4, 0)
					end
				end
			end

			if CliqueOptionsSpecSwitch then
				S:HandleCheckBox(CliqueOptionsSpecSwitch)
				if CliqueOptionsSpecSwitch.backdrop then
					CliqueOptionsSpecSwitch.backdrop:Point("TOPLEFT", 6, -4)
					CliqueOptionsSpecSwitch.backdrop:Point("BOTTOMRIGHT", -4, 3)
					if CliqueOptionsSpecSwitch.name then
						CliqueOptionsSpecSwitch.backdrop:Point("TOPRIGHT", CliqueOptionsSpecSwitch.name, "TOPLEFT", -4, 0)
					end
				end
			end

			if CliquePriSpecDropDown then S:HandleDropDownBox(CliquePriSpecDropDown, 225) end
			if CliqueSecSpecDropDown then
				S:HandleDropDownBox(CliqueSecSpecDropDown, 225)
				if CliquePriSpecDropDown then
					CliqueSecSpecDropDown:Point("TOPLEFT", CliquePriSpecDropDown, "BOTTOMLEFT", 0, 7)
				end
			end
		end

		-- TextListFrame
		if CliqueTextListFrame then
			SkinFrame(CliqueTextListFrame)
			CliqueTextListFrame:Point("BOTTOMLEFT", mainFrame, "BOTTOMRIGHT", -1, 0)

			if CliqueTextButtonClose then
				S:HandleCloseButton(CliqueTextButtonClose)
				CliqueTextButtonClose:Size(32)
				CliqueTextButtonClose:Point("TOPRIGHT", 5, 6)
			end

			if CliqueTextList1 then
				CliqueTextList1:Point("TOPLEFT", 6, -23)
			end

			if CliqueTextListScroll then
				CliqueTextListScroll:StripTextures()
				if CliqueTextListScrollScrollBar then
					S:HandleScrollBar(CliqueTextListScrollScrollBar)
					CliqueTextListScrollScrollBar:Point("TOPLEFT", CliqueTextListScroll, "TOPRIGHT", 3, -19)
					CliqueTextListScrollScrollBar:Point("BOTTOMLEFT", CliqueTextListScroll, "BOTTOMRIGHT", 3, 19)
				end
			end

			if CliqueButtonDeleteProfile then S:HandleButton(CliqueButtonDeleteProfile) end
			if CliqueButtonSetProfile then S:HandleButton(CliqueButtonSetProfile) end
			if CliqueButtonNewProfile then
				S:HandleButton(CliqueButtonNewProfile)
				if CliqueButtonDeleteProfile then
					CliqueButtonDeleteProfile:Point("BOTTOMLEFT", 30, 8)
				end
			end

			for i = 1, 12 do
				local entry = _G["CliqueTextList"..i]
				if entry then
					S:HandleCheckBox(entry)
					if entry.backdrop then
						entry.backdrop:Point("TOPLEFT", 6, -4)
						entry.backdrop:Point("BOTTOMRIGHT", -4, 3)
						if entry.name then
							entry.backdrop:Point("TOPRIGHT", entry.name, "TOPLEFT", -4, 0)
						end
					end
				end
			end
		end

		-- CustomFrame
		if CliqueCustomFrame then
			SkinFrame(CliqueCustomFrame)

			if CliqueCustomButtonBinding then S:HandleButton(CliqueCustomButtonBinding) end
			if CliqueCustomButtonIcon then
				S:HandleButton(CliqueCustomButtonIcon)
				if CliqueCustomButtonIcon.icon then
					CliqueCustomButtonIcon.icon:SetTexCoord(unpack(E.TexCoords))
					CliqueCustomButtonIcon.icon:SetInside()
				end
			end

			for i = 1, 5 do
				local entry = _G["CliqueCustomArg"..i]
				if entry then
					S:HandleEditBox(entry)
					if entry.backdrop then
						entry.backdrop:Point("TOPLEFT", -5, -5)
						entry.backdrop:Point("BOTTOMRIGHT", -5, 5)
					end
				end
			end

			if CliqueMulti then
				CliqueMulti:Width(276)
				if CliqueCustomArg1 then
					CliqueMulti:Point("TOPRIGHT", CliqueCustomArg1, "BOTTOMRIGHT", -14, -27)
				end
				CliqueMulti:SetBackdrop(nil)
				CliqueMulti:CreateBackdrop("Default")
				if CliqueMulti.backdrop then
					CliqueMulti.backdrop:Point("TOPLEFT", 5, -7)
					CliqueMulti.backdrop:Point("BOTTOMRIGHT", -5, 5)
				end
			end

			if CliqueMultiScrollFrameScrollBar then
				S:HandleScrollBar(CliqueMultiScrollFrameScrollBar)
				if CliqueMultiScrollFrame then
					CliqueMultiScrollFrameScrollBar:Point("TOPLEFT", CliqueMultiScrollFrame, "TOPRIGHT", 6, -18)
				end
			end

			if CliqueCustomButtonCancel then
				S:HandleButton(CliqueCustomButtonCancel)
				CliqueCustomButtonCancel:Point("BOTTOM", 65, 8)
			end
			if CliqueCustomButtonSave then S:HandleButton(CliqueCustomButtonSave) end
		end

		-- IconSelectFrame
		if CliqueIconSelectFrame then
			SkinFrame(CliqueIconSelectFrame)
			CliqueIconSelectFrame:Size(261, 211)

			if CliqueIcon1 then
				CliqueIcon1:Point("TOPLEFT", 9, -28)
			end

			if CliqueIconScrollFrame then
				CliqueIconScrollFrame:StripTextures()
				if CliqueIconScrollFrameScrollBar then
					S:HandleScrollBar(CliqueIconScrollFrameScrollBar)
					CliqueIconScrollFrameScrollBar:Point("TOPLEFT", CliqueIconScrollFrame, "TOPRIGHT", -4, -18)
					CliqueIconScrollFrameScrollBar:Point("BOTTOMLEFT", CliqueIconScrollFrame, "BOTTOMRIGHT", -4, 18)
				end
			end

			for i = 1, 20 do
				local button = _G["CliqueIcon"..i]
				local buttonIcon = _G["CliqueIcon"..i.."Icon"]

				if button then
					button:StripTextures()
					button:StyleButton(nil, true)
					if button.hover then button.hover:SetAllPoints() end
					button:CreateBackdrop("Default")

					if buttonIcon then
						buttonIcon:SetAllPoints()
						buttonIcon:SetTexCoord(unpack(E.TexCoords))
					end
				end
			end
		end
	end

	-- Hook options creation if function exists, or skin directly if already created
	if type(Clique) == "table" and type(Clique.CreateOptionsFrame) == "function" then
		hooksecurefunc(Clique, "CreateOptionsFrame", ApplyOptionsSkin)
	else
		ApplyOptionsSkin()
	end

	-- List Scroll Hook
	if type(Clique) == "table" and type(Clique.ListScrollUpdate) == "function" then
		hooksecurefunc(Clique, "ListScrollUpdate", function(self)
			if not CliqueListScroll then return end

			local offset = FauxScrollFrame_GetOffset(CliqueListScroll)
			local width = CliqueListScroll:IsShown() and 388 or 384

			for i = 1, 10 do
				local idx = offset + i

				if self.sortList and idx <= #self.sortList then
					local button = _G["CliqueList" .. i]
					if button then
						button:Width(width)

						if idx == self.listSelected then
							button:SetBackdropBorderColor(1, 1, 1)
						else
							button:SetBackdropBorderColor(unpack(E.media.bordercolor))
						end
					end
				end
			end
		end)
	end
end)