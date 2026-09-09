local E, L, V, P, G = unpack(ElvUI)
local S = E:GetModule("Skins")
local AS = E:GetModule("AddOnSkins")

if not AS:IsAddonLODorEnabled("ProjectAstral") then return end

local _G = _G
local unpack, pairs, ipairs, type, getmetatable, math = unpack, pairs, ipairs, type, getmetatable, math
local upper = string.upper
local GetItemQualityColor = GetItemQualityColor
local hooksecurefunc = hooksecurefunc

local function MediaColor()
	local vr, vg, vb = unpack(E.media.rgbvaluecolor)
	local br, bg, bb = unpack(E.media.bordercolor)
	local dr, dg, db, da = unpack(E.media.backdropfadecolor)
	local pr, pg, pb = unpack(E.media.backdropcolor)
	return {
		bgDeep    = {dr, dg, db, da},
		bgPanel   = {pr, pg, pb, 1},
		bgRowAlt  = {pr, pg, pb, 0.35},
		bgHover   = {vr, vg, vb, 0.15},
		borderDim  = {br, bg, bb, 1},
		borderMid  = {br, bg, bb, 1},
		borderHot  = {vr, vg, vb, 1},
		textTitle    = {1, 1, 1},
		textPrimary  = {0.9, 0.9, 0.9},
		textMuted    = {0.6, 0.6, 0.6},
		textAccent   = {vr, vg, vb},
		textHi       = {1, 1, 1},
		textGood     = {0.3, 1, 0.3},
		textBad      = {1, 0.2, 0.2},
		textWarn     = {1, 0.8, 0.1},
		accent       = {vr, vg, vb},
		accentSoft   = {vr, vg, vb},
	}
end

local function ApplyFont(fs, size)
	if fs and fs.FontTemplate then
		fs:FontTemplate(nil, size or 12, "OUTLINE")
	end
end

local function BorderAPI(frame)
	local idx = getmetatable(frame) and getmetatable(frame).__index
	if type(idx) ~= "table" then return end
	return idx.SetBackdropBorderColor, idx.SetBackdropColor
end

local function LockTemplate(frame, template)
	if not frame or not frame.SetTemplate then return end
	frame:SetTemplate(template or "Transparent")
	local _, origColor = BorderAPI(frame)
	if origColor then
		frame.SetBackdropColor = function(self)
			if template == "Transparent" then
				origColor(self, unpack(E.media.backdropfadecolor))
			else
				origColor(self, unpack(E.media.backdropcolor))
			end
		end
	end
end

local function ApplyHover(frame, opts)
	if not frame or frame.__elvPAHover then return end
	frame.__elvPAHover = true
	frame:EnableMouse(true)

	local setBorder = BorderAPI(frame)
	local hl = frame:CreateTexture(nil, "OVERLAY")
	hl:SetTexture(E.media.blankTex)
	hl:SetAllPoints()
	hl:SetBlendMode("ADD")
	hl:SetAlpha(0)
	frame.__elvPAHighlight = hl

	frame:HookScript("OnEnter", function(self)
		if setBorder then setBorder(self, unpack(E.media.rgbvaluecolor)) end
		hl:SetVertexColor(unpack(E.media.rgbvaluecolor))
		hl:SetAlpha((opts and opts.alpha) or 0.35)
		if self.text and not self.__elvPA_selected then
			self.text:SetTextColor(unpack(E.media.rgbvaluecolor))
		end
	end)
	frame:HookScript("OnLeave", function(self)
		if setBorder then
			if self.__elvPA_selected then
				setBorder(self, unpack(E.media.rgbvaluecolor))
			else
				setBorder(self, unpack(E.media.bordercolor))
			end
		end
		hl:SetAlpha(0)
		if self.text then
			if self.__elvPA_selected then
				self.text:SetTextColor(unpack(E.media.rgbvaluecolor))
			else
				self.text:SetTextColor(1, 1, 1)
			end
		end
	end)
end

S:AddCallbackForAddon("ProjectAstral", "ProjectAstral", function()
	if not E.private.addOnSkins.ProjectAstral then return end

	local astral = E.private.astral
	local function AstralOn(key)
		if not E:IsAstralEnabled() then return false end
		return astral[key] ~= false
	end

	if not (AstralOn("hub") or AstralOn("transmog") or AstralOn("table") or AstralOn("minimapButton") or AstralOn("popups")) then
		return
	end

	local PA = _G.ProjectAstral
	if not PA or not PA.UI then return end
	local UI = PA.UI

	if AstralOn("hub") or AstralOn("transmog") or AstralOn("table") or AstralOn("popups") then
	UI.Color = MediaColor()
	UI.CosmicCorners = E.noop
	UI.AddStarfield = E.noop
	UI.AddInnerGlow = E.noop
	UI.PulseChip = E.noop

	function UI.AstralBackdrop(frame)
		if not frame then return end
		if frame.StripTextures then frame:StripTextures() end
		LockTemplate(frame, "Transparent")
	end

	function UI.CosmicButton(b)
		if not b or b.isSkinned then return end
		S:HandleButton(b, true)
		ApplyHover(b)
		local fs = b.GetFontString and b:GetFontString()
		ApplyFont(fs, 12)
	end

	function UI.CosmicCloseButton(btn)
		if not btn then return end
		S:HandleCloseButton(btn)
		btn:SetScript("OnClick", function(self)
			local parent = self:GetParent()
			if parent and parent.AnimatedHide then
				parent:AnimatedHide()
			elseif parent then
				parent:Hide()
			end
		end)
	end

	function UI.MakeButton(parent, label, opts)
		opts = opts or {}
		local b = CreateFrame("Button", nil, parent)
		b:SetSize(opts.w or 160, opts.h or 22)
		S:HandleButton(b, true)
		ApplyHover(b)

		local txt = b:CreateFontString(nil, "OVERLAY")
		ApplyFont(txt, 12)
		txt:SetPoint("CENTER")
		txt:SetText(label or "")
		b.text = txt

		if opts.onClick then b:SetScript("OnClick", opts.onClick) end

		function b:SetDisabledLook(off)
			self._disabled = off
			if off then
				self:Disable()
				self.text:SetTextColor(0.5, 0.5, 0.5)
			else
				self:Enable()
				self.text:SetTextColor(1, 1, 1)
			end
		end

		function b:SetLabel(s)
			self.text:SetText(s)
		end

		return b
	end

	function UI.MakeHeader(frame, title, subtitle)
		local h = CreateFrame("Frame", nil, frame)
		h:SetHeight(40)
		h:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8)
		h:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)

		local t = h:CreateFontString(nil, "OVERLAY")
		ApplyFont(t, 16)
		t:SetPoint("TOPLEFT", h, "TOPLEFT", 4, -2)
		t:SetText(title or "")
		t:SetTextColor(1, 1, 1)
		h.title = t

		if subtitle and subtitle ~= "" then
			local s = h:CreateFontString(nil, "OVERLAY")
			ApplyFont(s, 11)
			s:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -2)
			s:SetText(subtitle)
			s:SetTextColor(unpack(E.media.rgbvaluecolor))
			h.subtitle = s
		end

		local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
		closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
		UI.CosmicCloseButton(closeBtn)
		h.closeBtn = closeBtn

		return h
	end

	function UI.MakeFooter(frame, opts)
		opts = opts or {}
		local f = CreateFrame("Frame", nil, frame)
		f:SetHeight(22)
		f:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, 6)
		f:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 6)
		f.text = f:CreateFontString(nil, "OVERLAY")
		ApplyFont(f.text, 11)
		f.text:SetPoint("LEFT")
		f.text:SetTextColor(0.6, 0.6, 0.6)
		f.text:SetText(opts.text or "")
		return f
	end

	function UI.MakeSectionLabel(parent, text, opts)
		opts = opts or {}
		local host = CreateFrame("Frame", nil, parent)
		host:SetHeight(16)

		local label = host:CreateFontString(nil, "OVERLAY")
		ApplyFont(label, 11)
		label:SetPoint("LEFT", host, "LEFT", 0, 0)
		label:SetText(upper(text or ""))
		label:SetTextColor(unpack(E.media.rgbvaluecolor))
		host.label = label

		function host:SetText(s)
			self.label:SetText(upper(s or ""))
		end
		return host
	end

	function UI.MakeStatBox(parent, w, h, label)
		local box = CreateFrame("Frame", nil, parent)
		box:SetSize(w or 160, h or 48)
		LockTemplate(box, "Transparent")

		local lbl = box:CreateFontString(nil, "OVERLAY")
		ApplyFont(lbl, 10)
		lbl:SetPoint("TOP", 0, -6)
		lbl:SetText(label or "")
		lbl:SetTextColor(0.6, 0.6, 0.6)

		local val = box:CreateFontString(nil, "OVERLAY")
		ApplyFont(val, 16)
		val:SetPoint("BOTTOM", 0, 8)
		val:SetText("--")
		val:SetTextColor(1, 1, 1)

		box.label = lbl
		box.value = val
		ApplyHover(box, { alpha = 0.22 })
		return box
	end

	function UI.MakeChip(parent, label, value)
		local c = CreateFrame("Frame", nil, parent)
		c:SetHeight(20)
		LockTemplate(c, "Default")

		local txt = c:CreateFontString(nil, "OVERLAY")
		ApplyFont(txt, 11)
		txt:SetPoint("CENTER")
		if value ~= nil then
			txt:SetText(label.."  "..tostring(value))
		else
			txt:SetText(label)
		end
		c.text = txt

		local minW, pad = 54, 16
		c:SetWidth(math.max(minW, txt:GetStringWidth() + pad))
		function c:SetText(s)
			self.text:SetText(s)
			self:SetWidth(math.max(minW, self.text:GetStringWidth() + pad))
		end
		ApplyHover(c, { alpha = 0.25 })
		return c
	end

	function UI.MakeSearchBox(parent, opts)
		opts = opts or {}
		local w = opts.width or 160
		local h = opts.height or 20

		local container = CreateFrame("Frame", nil, parent)
		container:SetSize(w, h)

		local edit = CreateFrame("EditBox", nil, container)
		edit:SetPoint("TOPLEFT", 4, 0)
		edit:SetPoint("BOTTOMRIGHT", -4, 0)
		edit:SetAutoFocus(false)
		edit:SetMaxLetters(48)
		ApplyFont(edit, 12)
		S:HandleEditBox(edit)

		local ghost = container:CreateFontString(nil, "OVERLAY")
		ApplyFont(ghost, 11)
		ghost:SetPoint("LEFT", edit, "LEFT", 6, 0)
		ghost:SetText(opts.placeholder or "Search...")
		ghost:SetTextColor(0.5, 0.5, 0.5)

		local function refreshGhost()
			if edit:HasFocus() or (edit:GetText() or "") ~= "" then
				ghost:Hide()
			else
				ghost:Show()
			end
		end

		edit:SetScript("OnEditFocusGained", refreshGhost)
		edit:SetScript("OnEditFocusLost", refreshGhost)
		edit:SetScript("OnEscapePressed", function(self)
			self:SetText("")
			self:ClearFocus()
			refreshGhost()
			if opts.onChanged then opts.onChanged("") end
		end)
		edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
		edit:SetScript("OnTextChanged", function(self)
			refreshGhost()
			if opts.onChanged then opts.onChanged(self:GetText() or "") end
		end)

		container.edit = edit
		function container:GetText() return edit:GetText() or "" end
		function container:SetText(s) edit:SetText(s or ""); refreshGhost() end
		function container:Clear() edit:SetText(""); refreshGhost() end
		function container:ResetPlaceholder() refreshGhost() end
		ApplyHover(edit.backdrop or container, { alpha = 0.2 })
		return container
	end

	function UI.MakeIconFrame(parent, opts)
		opts = opts or {}
		local size = opts.size or 26
		local f = CreateFrame("Frame", nil, parent)
		f:SetSize(size, size)
		LockTemplate(f, "Default")

		local icon = f:CreateTexture(nil, "OVERLAY")
		icon:SetInside(f)
		icon:SetTexCoord(unpack(E.TexCoords))
		f.icon = icon
		f.ring = icon

		function f:SetTexture(path)
			self.icon:SetTexture(path or "Interface\\Icons\\INV_Misc_QuestionMark")
		end
		function f:SetQuality(q)
			local r, g, b = GetItemQualityColor(q or 1)
			local idx = getmetatable(self) and getmetatable(self).__index
			if idx and idx.SetBackdropBorderColor then
				idx.SetBackdropBorderColor(self, r, g, b)
			end
		end
		f:SetTexture()
		ApplyHover(f, { alpha = 0.28 })
		return f
	end

	function UI.MakeTabBar(parent, tabs, onSelect, opts)
		opts = opts or {}
		local bar = CreateFrame("Frame", nil, parent)
		bar.buttons = {}
		bar.activeId = nil
		local ROW_H = 24

		for i, t in ipairs(tabs) do
			local row = CreateFrame("Button", nil, bar)
			row:SetHeight(ROW_H)
			if opts.bottomAnchor then
				row:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, (i - 1) * (ROW_H + 1))
				row:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, (i - 1) * (ROW_H + 1))
			else
				row:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, -((i - 1) * (ROW_H + 1)))
				row:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, -((i - 1) * (ROW_H + 1)))
			end
			row:SetTemplate("Default", true)
			row:RegisterForClicks("AnyUp")
			ApplyHover(row)

			local lbl = row:CreateFontString(nil, "OVERLAY")
			ApplyFont(lbl, 12)
			lbl:SetPoint("LEFT", 8, 0)
			lbl:SetText(t.label)
			row.text = lbl
			row.id = t.id
			row.hl = { SetAlpha = E.noop }
			row.active = { SetAlpha = E.noop }
			row.marker = { SetAlpha = E.noop }
			row.chevron = { SetAlpha = E.noop, SetTextColor = E.noop }

			row:SetScript("OnClick", function(self)
				bar:SelectTab(self.id)
				if onSelect then onSelect(self.id) end
			end)

			bar.buttons[t.id] = row
		end

		function bar:SelectTab(id)
			self.activeId = id
			for tid, b in pairs(self.buttons) do
				b.__elvPA_selected = tid == id
				if tid == id then
					b:SetBackdropBorderColor(unpack(E.media.rgbvaluecolor))
					b.text:SetTextColor(unpack(E.media.rgbvaluecolor))
				else
					b:SetBackdropBorderColor(unpack(E.media.bordercolor))
					b.text:SetTextColor(1, 1, 1)
				end
			end
		end

		return bar
	end

	function UI.MakeRowChrome(row)
		if not row then return row end
		row:SetTemplate("Transparent")
		ApplyHover(row)
		return row
	end

	local function SkinPAText(fs, size)
		if not fs then return end
		ApplyFont(fs, size or 12)
		if fs.SetShadowColor then
			fs:SetShadowColor(0, 0, 0, 1)
			fs:SetShadowOffset(1, -1)
		end
	end

	local origGainPopup = UI.GainPopup
	if AstralOn("popups") and origGainPopup then
		UI.GainPopup = function(text, kind, opts)
			local f = origGainPopup(text, kind, opts)
			if f then
				if f.SetTemplate then f:SetTemplate("Transparent") end
				SkinPAText(f.label, (opts and opts.fontSize) or 12)
				if f.label then f.label:SetTextColor(1, 1, 1) end
			end
			return f
		end
		UI.Toast = UI.GainPopup
	end

	local origLoading = UI.MakeLoadingOverlay
	if AstralOn("popups") and origLoading then
		UI.MakeLoadingOverlay = function(parent, opts)
			local o = origLoading(parent, opts)
			if o then
				if o.SetTemplate then o:SetTemplate("Transparent") end
				SkinPAText(o.label, 16)
				if o.label then o.label:SetTextColor(unpack(E.media.rgbvaluecolor)) end
			end
			return o
		end
	end

	local function IsAstralPopup(which)
		if type(which) ~= "string" then return false end
		return which:find("^PA_") or which:find("^AT_") or which:find("^ASTRAL_")
			or which:find("^TRANSMOG") or which:find("^NO_ITEM")
	end

	if AstralOn("popups") then
	hooksecurefunc("StaticPopup_Show", function(which)
		if not IsAstralPopup(which) then return end
		for i = 1, 4 do
			local frame = _G["StaticPopup"..i]
			if frame and frame:IsShown() and frame.which == which then
				if frame.SetTemplate then frame:SetTemplate("Transparent") end
				SkinPAText(_G["StaticPopup"..i.."Text"], 12)
				local text = _G["StaticPopup"..i.."Text"]
				if text then text:SetTextColor(1, 1, 1) end
				for j = 1, 3 do
					local btn = _G["StaticPopup"..i.."Button"..j]
					if btn then
						if not btn.isSkinned then S:HandleButton(btn) end
						SkinPAText(btn:GetFontString(), 12)
					end
				end
				local edit = _G["StaticPopup"..i.."EditBox"]
				if edit then ApplyFont(edit, 12) end
			end
		end
	end)
	end
	end

	if AstralOn("transmog") then
	local transmogSlots = {
		"Head", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist",
		"Hands", "Waist", "Legs", "Feet", "MainHand", "SecondaryHand", "Ranged",
	}

	local transmogLayout = {
		width = 880,
		height = 510,
		panelLeft = 48,
		gridLeft = 324,
		panelRightPad = 10,
		searchTop = -52,
		gridTop = -78,
		cardW = 82,
		cardH = 100,
		cardGap = 6,
		cols = 6,
		rows = 3,
		cardCount = 18,
		serverPageSize = 6,
		modelTop = -52,
		modelBottomPad = 68,
		modelPad = 36,
		hoverRotRange = 0.25,
		searchHeight = 24,
	}

	local function TransmogGridWidth()
		return transmogLayout.cols * transmogLayout.cardW + (transmogLayout.cols - 1) * transmogLayout.cardGap
	end

	local function StyleTransmogOptionLabel(fs)
		if not fs then return end
		ApplyFont(fs, 12)
		fs:SetTextColor(0.9, 0.9, 0.9)
	end

	local function EnsureTransmogFooter(frame, model)
		if not frame.elvPAFooter then
			frame.elvPAFooter = CreateFrame("Frame", nil, frame)
		end
		frame.elvPAFooter:SetFrameLevel(model:GetFrameLevel() + 10)
		frame.elvPAFooter:ClearAllPoints()
		frame.elvPAFooter:SetPoint("BOTTOMLEFT", model, "BOTTOMLEFT", 0, 0)
		frame.elvPAFooter:SetPoint("BOTTOMRIGHT", model, "BOTTOMRIGHT", 0, 0)
		frame.elvPAFooter:SetHeight(30)
		return frame.elvPAFooter
	end

	local PA_SEARCH_PLACEHOLDER = "|cffb2b2b2Filter Item Appearance|r"

	local function IsSearchPlaceholder(text)
		if not text or text == "" then return true end
		return text == PA_SEARCH_PLACEHOLDER
	end

	local function RefreshSearchGhost(search)
		if not search or not search.elvPAGhost then return end
		local text = search:GetText() or ""
		if search:HasFocus() or (text ~= "" and not IsSearchPlaceholder(text)) then
			search.elvPAGhost:Hide()
			search:SetTextColor(0.9, 0.9, 0.9)
		else
			if text == "" then
				search:SetText(PA_SEARCH_PLACEHOLDER)
			end
			search.elvPAGhost:Show()
			search:SetTextColor(0, 0, 0, 0)
		end
	end

	local function SkinTransmogSearchInput(search)
		if not search or search.__elvPASearchSkinned then return end
		S:HandleEditBox(search)
		ApplyFont(search, 12)
		search:SetJustifyH("LEFT")
		search:SetTextInsets(8, 8, 3, 3)
		search:SetHeight(transmogLayout.searchHeight)
		local name = search:GetName()
		if name then
			for _, piece in ipairs({"Left", "Middle", "Right", "Mid"}) do
				local tex = _G[name..piece]
				if tex then
					tex:SetAlpha(0)
					if tex.SetWidth then tex:SetWidth(1) end
				end
			end
		end
		if not search.elvPAGhost then
			search.elvPAGhost = search:CreateFontString(nil, "OVERLAY")
			search.elvPAGhost:SetPoint("LEFT", search, "LEFT", 8, 0)
			search.elvPAGhost:SetPoint("RIGHT", search, "RIGHT", -8, 0)
			ApplyFont(search.elvPAGhost, 12)
			search.elvPAGhost:SetTextColor(0.75, 0.75, 0.75)
			search.elvPAGhost:SetText("Filter Item Appearance")
			search.elvPAGhost:SetJustifyH("CENTER")
			search:HookScript("OnEditFocusGained", function() RefreshSearchGhost(search) end)
			search:HookScript("OnEditFocusLost", function() RefreshSearchGhost(search) end)
			search:HookScript("OnTextChanged", function() RefreshSearchGhost(search) end)
		end
		RefreshSearchGhost(search)
		search.__elvPASearchSkinned = true
	end

	local function GetTransmogModelSize()
		local width = transmogLayout.gridLeft - transmogLayout.panelLeft - transmogLayout.panelRightPad
		local height = transmogLayout.height + transmogLayout.modelTop - transmogLayout.modelBottomPad
		return width, height
	end

	local function LayoutItemSearchInput(frame, gridWidth)
		local search = _G.ItemSearchInput
		if not search or not frame then return end

		SkinTransmogSearchInput(search)

		local cardWidth = gridWidth or TransmogGridWidth()
		search:ClearAllPoints()
		search:SetSize(cardWidth, transmogLayout.searchHeight)
		search:SetPoint("TOPLEFT", frame, "TOPLEFT", transmogLayout.gridLeft, transmogLayout.searchTop)
		search:SetFrameLevel(frame:GetFrameLevel() + 40)
		RefreshSearchGhost(search)
	end

	local activeTransmogSlotName = "Head"

	local transmogTabHooks = {
		OnClickHeadTab = "Head",
		OnClickShoulderTab = "Shoulder",
		OnClickShirtTab = "Shirt",
		OnClickChestTab = "Chest",
		OnClickWaistTab = "Waist",
		OnClickLegsTab = "Legs",
		OnClickFeetTab = "Feet",
		OnClickWristTab = "Wrist",
		OnClickHandsTab = "Hands",
		OnClickBackTab = "Back",
		OnClickMainTab = "MainHand",
		OnClickOffTab = "SecondaryHand",
		OnClickRangedTab = "Ranged",
		OnClickTabardTab = "Tabard",
	}

	local function SyncActiveTransmogSlotFromUI()
		for _, name in ipairs(transmogSlots) do
			local slot = _G["TransmogCharacter"..name.."Slot"]
			if slot and slot.toastTexture then
				local tex = slot.toastTexture:GetTexture()
				if tex and tex:find("Selected", 1, true) then
					activeTransmogSlotName = name
					return name
				end
			end
		end
		return activeTransmogSlotName
	end

	local function GetSlotRotation(slotName)
		if slotName == "Back" then return math.pi end
		if slotName == "MainHand" or slotName == "Ranged" then return 1 end
		if slotName == "SecondaryHand" then return -1 end
		if slotName == "Hands" then return 0.85 end
		if slotName == "Wrist" then return 0.65 end
		if slotName == "Shoulder" then return 0.4 end
		return 0
	end

	local slotPreviewCamera = {
		Head = { pos = 1.35, y = 0.13, x = 0, rot = 0 },
		Shoulder = { pos = 1.3, y = 0.08, x = 0, rot = 0.4 },
		Back = { pos = 1.35, y = 0.1, x = 0, rot = math.pi },
		Chest = { pos = 1.3, y = 0.06, x = 0, rot = 0 },
		Shirt = { pos = 1.3, y = 0.06, x = 0, rot = 0 },
		Tabard = { pos = 1.3, y = 0.04, x = 0, rot = 0 },
		Wrist = { pos = 1.2, y = -0.01, x = 0.06, rot = 0.65 },
		Hands = { pos = 1.2, y = -0.03, x = 0.05, rot = 0.85 },
		Waist = { pos = 1.3, y = -0.02, x = 0, rot = 0 },
		Legs = { pos = 1.25, y = -0.1, x = 0, rot = 0 },
		Feet = { pos = 1.15, y = -0.16, x = 0, rot = 0.15 },
		MainHand = { pos = 1.2, y = -0.02, x = -0.06, rot = 1 },
		SecondaryHand = { pos = 1.2, y = -0.02, x = 0.06, rot = -1 },
		Ranged = { pos = 1.2, y = 0, x = -0.04, rot = 1 },
	}

	local function HideTransmogPreviewBackgrounds(index)
		for _, prefix in ipairs({ "LeftTopItemFrame", "LeftBottomItemFrame", "RightTopItemFrame", "RightBottomItemFrame" }) do
			local sub = _G[prefix..index]
			if sub then sub:Hide() end
		end
	end

	local hoveredCardIndex

	local function GetActiveTransmogSlotName()
		return SyncActiveTransmogSlotFromUI()
	end

	local function GetSlotPreviewRotation(slotName, preset)
		if preset and preset.rot ~= nil then
			return preset.rot
		end
		return GetSlotRotation(slotName)
	end

	local function ApplyCardModelRotation(model, slotName, preset, hoverDelta)
		if not model then return end
		local baseRot = GetSlotPreviewRotation(slotName, preset)
		model.elvPABaseRotation = baseRot
		local extra = (hoverDelta or 0) * transmogLayout.hoverRotRange
		model:SetRotation(baseRot + extra, false)
	end

	local function HidePerSlotActionButtons()
		for _, name in ipairs(transmogSlots) do
			local slot = _G["TransmogCharacter"..name.."Slot"]
			if slot then
				if slot.restoreButton then slot.restoreButton:Hide() end
				if slot.hideButton then slot.hideButton:Hide() end
			end
		end
	end

	local function GetTransmogSlotName(slot)
		if not slot or not slot.GetName then return end
		return slot:GetName():match("^TransmogCharacter(.+)Slot$")
	end

	local function ToggleHideTransmogEquipmentSlot(slot)
		if not slot or not _G.previewTransmogrificationIDs then return end
		local slotName = GetTransmogSlotName(slot)
		if not slotName then return end

		local equipSlot = slot:GetID()
		if not equipSlot or not GetInventoryItemID("player", equipSlot) then
			if _G.StaticPopup_Show then
				_G.StaticPopupDialogs = _G.StaticPopupDialogs or {}
				_G.StaticPopupDialogs.ELVUI_PA_NO_ITEM_TO_HIDE = {
					text = "You must have an item equipped in this slot to hide its appearance.",
					button1 = OKAY,
					timeout = 0,
					whileDead = true,
					hideOnEscape = true,
					preferredIndex = 3,
				}
				_G.StaticPopup_Show("ELVUI_PA_NO_ITEM_TO_HIDE")
			end
			return
		end

		if _G.previewTransmogrificationIDs[slotName] == 0 then
			_G.previewTransmogrificationIDs[slotName] = nil
			if PlaySound then PlaySound("Glyph_MinorCreate", "sfx") end
		else
			_G.previewTransmogrificationIDs[slotName] = 0
			if PlaySound then PlaySound("ArcaneMissileImpacts", "sfx") end
		end

		if _G.LoadTransmogrificationsFromCurrentIDs then
			_G.LoadTransmogrificationsFromCurrentIDs(true)
		end
		if _G.UpdateSlotTexture then
			_G.UpdateSlotTexture(slotName, true, true)
		end
	end

	local function HookTransmogSlotRightClick(slot)
		if not slot or slot.__elvPARightClickHooked then return end
		slot.__elvPARightClickHooked = true
		slot:HookScript("OnMouseUp", function(self, button)
			if button == "RightButton" then
				ToggleHideTransmogEquipmentSlot(self)
			end
		end)
	end

	local function SetCardButtonIconVisible(button, visible)
		if not button then return end
		local icon = _G[button:GetName().."IconTexture"]
		if icon then
			if visible then icon:Show() else icon:Hide() end
		end
	end

	local function LayoutCardModel(model, child)
		if not model or not child then return end
		model:SetParent(child)
		model:SetFrameLevel(child:GetFrameLevel() + 1)
		local size = math.max(transmogLayout.cardW, transmogLayout.cardH) + transmogLayout.modelPad
		model:ClearAllPoints()
		model:SetSize(size, size)
		model:SetPoint("CENTER", child, "CENTER", 0, -1)
	end

	local function ApplySlotPreviewCamera(model, itemID, panX)
		if not model or not itemID or itemID <= 0 then return end
		local slotName = GetActiveTransmogSlotName()
		local preset = slotPreviewCamera[slotName] or slotPreviewCamera.Chest

		model:Show()
		model:SetUnit("player")
		model:Undress()
		model:TryOn(itemID)
		model:SetPosition(preset.pos, preset.y, preset.x + (panX or 0))
		ApplyCardModelRotation(model, slotName, preset)
		model.elvPACamera = preset
		model.elvPASlotName = slotName
	end

	local function RefreshTransmogCardPreview(index, isHover)
		local child = _G["ItemChild"..index]
		local model = _G["ItemModel"..index]
		local button = _G["ItemButton"..index]
		if not child then return end

		local itemID = child:GetID()
		if itemID and itemID > 0 then
			LayoutCardModel(model, child)
			ApplySlotPreviewCamera(model, itemID, 0)
			if button then
				button:SetAlpha(0)
				button:EnableMouse(true)
				SetCardButtonIconVisible(button, false)
			end
			child:SetAlpha(1)
			if isHover then
				child:SetBackdropBorderColor(unpack(E.media.rgbvaluecolor))
			else
				child:SetBackdropBorderColor(unpack(E.media.bordercolor))
			end
			child:Show()
		else
			if model then model:Hide() end
			if button then
				button:SetAlpha(1)
				SetCardButtonIconVisible(button, true)
			end
			child:Hide()
		end
	end

	local function RefreshAllTransmogCardPreviews()
		for i = 1, transmogLayout.cardCount do
			RefreshTransmogCardPreview(i, hoveredCardIndex == i)
		end
	end

	local function ClearTransmogCardHover(index)
		local model = _G["ItemModel"..index]
		if model then model:SetScript("OnUpdate", nil) end
		if hoveredCardIndex == index then hoveredCardIndex = nil end
		RefreshTransmogCardPreview(index, false)
	end

	local function ClearAllTransmogCardHovers()
		hoveredCardIndex = nil
		for i = 1, transmogLayout.cardCount do
			local model = _G["ItemModel"..i]
			if model then model:SetScript("OnUpdate", nil) end
		end
		RefreshAllTransmogCardPreviews()
	end

	local function ShowTransmogCardHover(index)
		local child = _G["ItemChild"..index]
		local model = _G["ItemModel"..index]
		local itemID = child and child:GetID()
		if not itemID or itemID <= 0 then return end
		if hoveredCardIndex and hoveredCardIndex ~= index then
			ClearTransmogCardHover(hoveredCardIndex)
		end
		hoveredCardIndex = index
		RefreshTransmogCardPreview(index, true)

		if not model then return end
		model:SetScript("OnUpdate", function(self)
			local parent = self:GetParent()
			if hoveredCardIndex ~= index or not parent then
				self:SetScript("OnUpdate", nil)
				return
			end
			local scale = UIParent:GetEffectiveScale()
			local left, width = parent:GetLeft(), parent:GetWidth()
			if not left or not width or width <= 0 then return end
			local mx = select(1, GetCursorPosition()) / scale
			local delta = (mx - (left + width * 0.5)) / width
			local preset = self.elvPACamera or slotPreviewCamera.Chest
			local slotName = self.elvPASlotName or GetActiveTransmogSlotName()
			self:SetPosition(preset.pos, preset.y, preset.x)
			ApplyCardModelRotation(self, slotName, preset, delta)
		end)
	end

	local function HookTransmogCardHover(child, index)
		if not child or child.__elvPAHoverHooked then return end
		child.__elvPAHoverHooked = true
		child:EnableMouse(true)

		local function onEnter()
			ShowTransmogCardHover(index)
		end

		local function onLeave()
			E:Delay(0.05, function()
				if child:IsMouseOver() or (child.itemButton and child.itemButton:IsMouseOver()) then return end
				ClearTransmogCardHover(index)
			end)
		end

		child:HookScript("OnEnter", onEnter)
		child:HookScript("OnLeave", onLeave)

		if child.itemButton then
			child.itemButton:HookScript("OnEnter", onEnter)
			child.itemButton:HookScript("OnLeave", onLeave)
		end
	end

	local function LayoutTransmogAppearanceCard(index, slot, frame)
		local child = _G["ItemChild"..index]
		if not frame or not child then return end

		local col = (slot - 1) % transmogLayout.cols
		local row = math.floor((slot - 1) / transmogLayout.cols)
		local x = transmogLayout.gridLeft + col * (transmogLayout.cardW + transmogLayout.cardGap)
		local y = transmogLayout.gridTop - row * (transmogLayout.cardH + transmogLayout.cardGap)

		child:SetParent(frame)
		child:ClearAllPoints()
		child:SetSize(transmogLayout.cardW, transmogLayout.cardH)
		child:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
		child.__elvPAIndex = index
		if child.SetClipsChildren then child:SetClipsChildren(true) end

		HideTransmogPreviewBackgrounds(index)

		local model = _G["ItemModel"..index]
		if model then
			model:SetParent(child)
			model:SetFrameLevel(child:GetFrameLevel() + 1)
		end

		local button = _G["ItemButton"..index]
		if button then
			button:SetParent(child)
			button:SetFrameLevel(child:GetFrameLevel() + 3)
			button:ClearAllPoints()
			button:SetSize(transmogLayout.cardW, transmogLayout.cardH)
			button:SetPoint("CENTER", child, "CENTER", 0, 0)
		end

		HookTransmogCardHover(child, index)
		RefreshTransmogCardPreview(index, hoveredCardIndex == index)
	end

	local function LayoutVisibleAppearanceCards()
		local frame = _G.TransmogrificationFrame
		if not frame then return end

		local order = {}
		for i = 1, transmogLayout.cardCount do
			local child = _G["ItemChild"..i]
			if child then child:SetParent(frame) end
			local itemID = child and child:GetID()
			if itemID and itemID > 0 then
				order[#order + 1] = i
			else
				if child then child:Hide() end
				local model = _G["ItemModel"..i]
				if model then model:Hide() end
			end
		end

		if _G.ItemSearchInput then
			LayoutItemSearchInput(frame)
		end

		for slot, index in ipairs(order) do
			LayoutTransmogAppearanceCard(index, slot, frame)
		end
	end

	local function ReconcileTransmogCards()
		SyncActiveTransmogSlotFromUI()
		for i = 1, transmogLayout.cardCount do
			HideTransmogPreviewBackgrounds(i)
			local child = _G["ItemChild"..i]
			local button = _G["ItemButton"..i]
			if child and button then
				button:SetParent(child)
				button:ClearAllPoints()
				button:SetSize(transmogLayout.cardW, transmogLayout.cardH)
				button:SetPoint("CENTER", child, "CENTER", 0, 0)
			end
		end
		LayoutVisibleAppearanceCards()
		HidePerSlotActionButtons()
	end

	local function ApplyTransmogCardIdleState()
		for i = 1, transmogLayout.cardCount do
			local child = _G["ItemChild"..i]
			local button = _G["ItemButton"..i]
			if child and child.modelBG then child.modelBG:Hide() end
			if button and child then
				button:SetParent(child)
				button:Show()
				button:ClearAllPoints()
				button:SetSize(transmogLayout.cardW, transmogLayout.cardH)
				button:SetPoint("CENTER", child, "CENTER", 0, 0)
			end
		end
		ReconcileTransmogCards()
	end

	local function LayoutTransmogrificationFrame()
		local frame = _G.TransmogrificationFrame
		if not frame then return end

		frame:SetSize(transmogLayout.width, transmogLayout.height)

		if frame.TitleText then
			frame.TitleText:ClearAllPoints()
			frame.TitleText:SetPoint("TOP", frame, "TOP", 0, -12)
		end
		if frame.SubtitleText then
			frame.SubtitleText:ClearAllPoints()
			frame.SubtitleText:SetPoint("TOP", frame.TitleText, "BOTTOM", 0, -2)
		end

		if _G.TransmogCloseButton then
			_G.TransmogCloseButton:ClearAllPoints()
			_G.TransmogCloseButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
		end

		if _G.TransmogrificationModelFrame then
			local model = _G.TransmogrificationModelFrame
			local modelW, modelH = GetTransmogModelSize()
			model:ClearAllPoints()
			model:SetSize(modelW, modelH)
			model:SetPoint("TOPLEFT", frame, "TOPLEFT", transmogLayout.panelLeft, transmogLayout.modelTop)
			model:SetPosition(0.9, 0.03, 0)
			model:SetRotation(0, false)

			if model.backdrop then
				model.backdrop:ClearAllPoints()
				model.backdrop:SetPoint("TOPLEFT", model, "TOPLEFT", -2, 2)
				model.backdrop:SetPoint("BOTTOMRIGHT", model, "BOTTOMRIGHT", 2, -2)
			end

			if _G.TransmogrificationModelFrameRotateLeftButton then
				_G.TransmogrificationModelFrameRotateLeftButton:ClearAllPoints()
				_G.TransmogrificationModelFrameRotateRightButton:ClearAllPoints()
				_G.TransmogrificationModelFrameRotateLeftButton:SetPoint("TOP", model, "TOP", -20, 10)
				_G.TransmogrificationModelFrameRotateRightButton:SetPoint("LEFT", _G.TransmogrificationModelFrameRotateLeftButton, "RIGHT", 4, 0)
			end

			local footer = EnsureTransmogFooter(frame, model)

			if _G.RestoreAllButton then
				_G.RestoreAllButton:SetParent(footer)
				_G.RestoreAllButton:ClearAllPoints()
				_G.RestoreAllButton:SetSize(24, 24)
				_G.RestoreAllButton:SetPoint("BOTTOMLEFT", footer, "BOTTOMLEFT", 4, 3)
				_G.RestoreAllButton:Show()
			end
			if _G.HideAllButton then
				_G.HideAllButton:SetParent(footer)
				_G.HideAllButton:ClearAllPoints()
				_G.HideAllButton:SetSize(24, 24)
				_G.HideAllButton:SetPoint("LEFT", _G.RestoreAllButton, "RIGHT", 6, 0)
				_G.HideAllButton:Show()
			end

			if _G.ShowHelmCheckBox then
				StyleTransmogOptionLabel(_G.ShowHelmText)
				StyleTransmogOptionLabel(_G.ShowCloakText)
				_G.ShowHelmCheckBox:SetParent(footer)
				_G.ShowHelmText:SetParent(footer)
				_G.ShowCloakCheckBox:SetParent(footer)
				_G.ShowCloakText:SetParent(footer)

				_G.ShowHelmCheckBox:ClearAllPoints()
				_G.ShowHelmCheckBox:SetPoint("LEFT", footer, "CENTER", -58, 2)
				_G.ShowHelmText:ClearAllPoints()
				_G.ShowHelmText:SetPoint("LEFT", _G.ShowHelmCheckBox, "RIGHT", 4, 0)
				_G.ShowCloakCheckBox:ClearAllPoints()
				_G.ShowCloakCheckBox:SetPoint("LEFT", _G.ShowHelmText, "RIGHT", 14, 0)
				_G.ShowCloakText:ClearAllPoints()
				_G.ShowCloakText:SetPoint("LEFT", _G.ShowCloakCheckBox, "RIGHT", 4, 0)
			end
		end

		LayoutItemSearchInput(frame)

		LayoutVisibleAppearanceCards()

		if _G.TransmogWarningFrame then
			_G.TransmogWarningFrame:ClearAllPoints()
			_G.TransmogWarningFrame:SetPoint("CENTER", _G.TransmogrificationModelFrame or frame, "CENTER", 0, 0)
		end

		if not _G.TransmogrificationModelFrame then
			if _G.RestoreAllButton then
				_G.RestoreAllButton:ClearAllPoints()
				_G.RestoreAllButton:SetSize(24, 24)
				_G.RestoreAllButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 34)
				_G.RestoreAllButton:Show()
			end
			if _G.HideAllButton then
				_G.HideAllButton:ClearAllPoints()
				_G.HideAllButton:SetSize(24, 24)
				_G.HideAllButton:SetPoint("LEFT", _G.RestoreAllButton, "RIGHT", 6, 0)
				_G.HideAllButton:Show()
			end
		end

		if _G.TransmogPaginationText then
			_G.TransmogPaginationText:ClearAllPoints()
			_G.TransmogPaginationText:SetPoint("BOTTOM", frame, "BOTTOM", transmogLayout.gridLeft + TransmogGridWidth() * 0.5 - transmogLayout.width * 0.5, 16)
		end
		if _G.LeftButton then
			_G.LeftButton:ClearAllPoints()
			_G.LeftButton:SetPoint("RIGHT", _G.TransmogPaginationText, "LEFT", -6, 0)
		end
		if _G.RightButton then
			_G.RightButton:ClearAllPoints()
			_G.RightButton:SetPoint("LEFT", _G.TransmogPaginationText, "RIGHT", 6, 0)
		end

		if _G.SaveButton then
			_G.SaveButton:ClearAllPoints()
			_G.SaveButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 12)
		end
	end

	local function SkinTransmogIconButton(btn, texturePath, iconSize)
		if not btn or btn.__elvPASkinned then return end
		if not btn.isSkinned then
			btn:SetTemplate("Default", true, true)
			btn:StyleButton(false)
		end
		local size = iconSize or 22
		if not btn.elvPAIcon then
			btn.elvPAIcon = btn:CreateTexture(nil, "ARTWORK")
			btn.elvPAIcon:SetPoint("CENTER")
		end
		btn.elvPAIcon:SetSize(size, size)
		btn.elvPAIcon:SetTexture(texturePath)
		btn.elvPAIcon:Show()
		btn.__elvPASkinned = true
	end

	local function RefreshTransmogSlotBorders()
		for _, name in ipairs(transmogSlots) do
			local slot = _G["TransmogCharacter"..name.."Slot"]
			if slot and slot.backdrop then
				if name == activeTransmogSlotName then
					slot:SetBackdropBorderColor(unpack(E.media.rgbvaluecolor))
				else
					slot:SetBackdropBorderColor(unpack(E.media.bordercolor))
				end
			end
		end
	end

	local function SkinTransmogSlot(slot)
		if not slot or slot.__elvPASkinned then return end

		slot:StripTextures()
		slot:SetTemplate("Default", true, true)
		slot:StyleButton(false)

		local icon = _G[slot:GetName().."IconTexture"]
		if icon then
			icon:SetInside()
			icon:SetTexCoord(unpack(E.TexCoords))
		end

		if slot.toastTexture then slot.toastTexture:Hide() end
		if slot.ignoreTexture then slot.ignoreTexture:SetAlpha(0) end

		if slot.restoreButton then slot.restoreButton:Hide() end
		if slot.hideButton then slot.hideButton:Hide() end

		HookTransmogSlotRightClick(slot)
		slot.__elvPASkinned = true
	end

	local function SkinTransmogItemChild(child, index)
		if not child or child.__elvPASkinned then return end

		if child.SetBackdrop then child:SetBackdrop(nil) end
		child:StripTextures(true)
		child:CreateBackdrop("Default")

		if not child.modelBG then
			child.modelBG = child:CreateTexture(nil, "BACKGROUND")
			child.modelBG:SetAllPoints(child.backdrop)
			child.modelBG:SetTexture(E.media.blankTex)
			child.modelBG:SetVertexColor(unpack(E.media.backdropcolor))
			child.modelBG:Hide()
		end

		if index then HideTransmogPreviewBackgrounds(index) end

		if child.itemButton then
			child.itemButton:SetParent(child)
			child.itemButton:Show()
			child.itemButton:StripTextures()
			child.itemButton:SetTemplate("Default", true, true)
			child.itemButton:StyleButton(false)

			local icon = _G[child.itemButton:GetName().."IconTexture"]
			if icon then
				icon:SetInside()
				icon:SetTexCoord(unpack(E.TexCoords))
			end
			if child.itemButton.toastTexture then child.itemButton.toastTexture:Hide() end
		end

		child.__elvPASkinned = true
	end

	local function EnsureTransmogAppearanceCards()
		local frame = _G.TransmogrificationFrame
		if not frame then return end

		for i = 1, transmogLayout.cardCount do
			if not _G["ItemChild"..i] then
				local child = CreateFrame("Frame", "ItemChild"..i, frame, "TransmogItemWrapperTemplate")
				child:Hide()

				local model = CreateFrame("DressUpModel", "ItemModel"..i, child)
				model:SetPoint("CENTER", 0, 0)
				model:SetSize(transmogLayout.cardW, transmogLayout.cardH)
				model:Hide()

				local button = CreateFrame("Button", "ItemButton"..i, child, "TransmogItemButtonTemplate")
				button:SetPoint("CENTER", child, "CENTER", 0, 0)
				button:SetScript("OnClick", _G.OnClickItemTransmogrificationButton)
				button:SetScript("OnEnter", _G.OnEnterItemToolTip)
				button:SetScript("OnLeave", _G.OnLeaveHideToolTip)
				button:RegisterForClicks("AnyUp")
				button:Disable()

				child.itemModel = model
				child.itemButton = button
			end
			SkinTransmogItemChild(_G["ItemChild"..i], i)
		end
	end

	local function ActiveSlotHasItem()
		local name = GetActiveTransmogSlotName()
		local slot = name and _G["TransmogCharacter"..name.."Slot"]
		local id = slot and slot:GetID()
		return id and GetInventoryItemID("player", id) ~= nil
	end

	local function ApplyAppearanceToCard(index, itemID, hasItem)
		local child = _G["ItemChild"..index]
		local button = _G["ItemButton"..index]
		local model = _G["ItemModel"..index]
		if not child then return end

		if not itemID or itemID <= 0 then
			child:SetID(0)
			if button then
				button:SetID(0)
				button:Disable()
			end
			if model then model:Hide() end
			child:Hide()
			return
		end

		child:SetID(itemID)
		if button then
			button:SetID(itemID)
			SetItemButtonTexture(button, GetItemIcon(itemID))
			button:Enable()
			if hasItem then
				button:SetScript("OnClick", _G.OnClickItemTransmogrificationButton)
			else
				button:SetScript("OnClick", function()
					PlaySound("igMainMenuOptionCheckBoxOff", "sfx")
				end)
			end
		end
		child:Show()
	end

	local function FinishTransmogAppearancePage(origInitTab, player, itemIDs, visualPage, hasMore)
		EnsureTransmogAppearanceCards()
		origInitTab(player, itemIDs, visualPage, hasMore)

		local hasItem = ActiveSlotHasItem()
		for i = transmogLayout.serverPageSize + 1, transmogLayout.cardCount do
			ApplyAppearanceToCard(i, itemIDs and itemIDs[i], hasItem)
		end

		SyncActiveTransmogSlotFromUI()
		RefreshAllTransmogCardPreviews()
		E:Delay(0, function()
			LayoutTransmogrificationFrame()
			ReconcileTransmogCards()
		end)
		E:Delay(0.1, ReconcileTransmogCards)
	end

	local function FlattenAppearanceChunks(chunks)
		local out = {}
		for i = 1, #chunks do
			local chunk = chunks[i]
			if chunk then
				for j = 1, #chunk do
					out[#out + 1] = chunk[j]
				end
			end
		end
		return out
	end

	local function InstallTransmogPageAggregation()
		if not PA.TransmogHandlers or not PA.TransmogHandlers.InitTab or PA.TransmogHandlers.__elvPAPaged then return end

		local origInitTab = PA.TransmogHandlers.InitTab
		local aio = _G.AIO
		local origHandle = aio and aio.Handle
		local pagesPerView = transmogLayout.rows
		local collect = {
			token = 0,
			slot = nil,
			search = nil,
			visualPage = 1,
			expectedPage = nil,
			chunks = {},
		}

		local function RequestServerPage(serverPage)
			if not origHandle then return end
			if collect.search then
				origHandle("TransmogrificationServer", "SetSearchCurrentSlotItemIDs", collect.slot, serverPage, collect.search)
			else
				origHandle("TransmogrificationServer", "SetCurrentSlotItemIDs", collect.slot, serverPage)
			end
		end

		PA.TransmogHandlers.InitTab = function(player, newSlotItemIDs, page, hasMorePages)
			if collect.token ~= 0 and page ~= collect.expectedPage then
				return
			end
			if collect.token == 0 then
				FinishTransmogAppearancePage(origInitTab, player, newSlotItemIDs, page, hasMorePages)
				return
			end

			collect.chunks[#collect.chunks + 1] = newSlotItemIDs or {}
			local got = #collect.chunks
			if hasMorePages and got < pagesPerView then
				collect.expectedPage = (collect.visualPage - 1) * pagesPerView + got + 1
				RequestServerPage(collect.expectedPage)
				return
			end

			local combined = FlattenAppearanceChunks(collect.chunks)
			collect.token = 0
			FinishTransmogAppearancePage(origInitTab, player, combined, collect.visualPage, hasMorePages and got == pagesPerView)
		end

		if origHandle and not aio.__elvPAPageRemap then
			aio.Handle = function(addon, handler, ...)
				if addon == "TransmogrificationServer" and (handler == "SetCurrentSlotItemIDs" or handler == "SetSearchCurrentSlotItemIDs") then
					local slot, page, searchText = ...
					collect.token = collect.token + 1
					collect.slot = slot
					collect.search = handler == "SetSearchCurrentSlotItemIDs" and searchText or nil
					collect.visualPage = page or 1
					collect.expectedPage = (collect.visualPage - 1) * pagesPerView + 1
					collect.chunks = {}
					if collect.search then
						return origHandle(addon, handler, slot, collect.expectedPage, searchText)
					end
					return origHandle(addon, handler, slot, collect.expectedPage)
				end
				return origHandle(addon, handler, ...)
			end
			aio.__elvPAPageRemap = true
		end

		PA.TransmogHandlers.__elvPAPaged = true
	end

	local function SkinTransmogrificationFrame()
		local frame = _G.TransmogrificationFrame
		if not frame or frame.__elvPATransmogSkinned then return end

		if frame.DialogBG then frame.DialogBG:Hide() end
		UI.AstralBackdrop(frame)

		if frame.TitleText then
			ApplyFont(frame.TitleText, 16)
			frame.TitleText:SetTextColor(1, 1, 1)
		end
		if frame.SubtitleText then
			ApplyFont(frame.SubtitleText, 12)
			frame.SubtitleText:SetTextColor(unpack(E.media.rgbvaluecolor))
		end

		if _G.TransmogCloseButton then
			UI.CosmicCloseButton(_G.TransmogCloseButton)
		end

		for _, name in ipairs(transmogSlots) do
			SkinTransmogSlot(_G["TransmogCharacter"..name.."Slot"])
		end

		if _G.ItemSearchInput then
			SkinTransmogSearchInput(_G.ItemSearchInput)
		end
		if _G.ShowCloakCheckBox then S:HandleCheckBox(_G.ShowCloakCheckBox) end
		if _G.ShowHelmCheckBox then S:HandleCheckBox(_G.ShowHelmCheckBox) end
		if _G.LeftButton then S:HandleNextPrevButton(_G.LeftButton, "left") end
		if _G.RightButton then S:HandleNextPrevButton(_G.RightButton, "right") end

		if _G.TransmogrificationModelFrameRotateLeftButton then
			S:HandleRotateButton(_G.TransmogrificationModelFrameRotateLeftButton)
		end
		if _G.TransmogrificationModelFrameRotateRightButton then
			S:HandleRotateButton(_G.TransmogrificationModelFrameRotateRightButton)
		end

		if _G.TransmogrificationModelFrame then
			_G.TransmogrificationModelFrame:CreateBackdrop("Default")
			_G.TransmogrificationModelFrame.backdrop:SetOutside(_G.TransmogrificationModelFrame, 2, 2)
		end

		if _G.SaveButton then
			if _G.SaveBackgroundTexture then _G.SaveBackgroundTexture:Hide() end
			if _G.SaveTexture then _G.SaveTexture:Hide() end
			_G.SaveButton:StripTextures()
			S:HandleButton(_G.SaveButton, true)
			SetItemButtonTexture(_G.SaveButton, "Interface\\AddOns\\ProjectAstral\\Transmogrification\\assets\\Transmog-Icon")
			local saveIcon = _G.SaveButton:GetNormalTexture()
			if saveIcon then
				saveIcon:SetInside()
				saveIcon:SetTexCoord(unpack(E.TexCoords))
			end
		end

		if _G.RestoreAllButton then
			SkinTransmogIconButton(_G.RestoreAllButton, "Interface\\AddOns\\ProjectAstral\\Transmogrification\\assets\\Transmog-Overlay-Restore", 18)
		end
		if _G.HideAllButton then
			SkinTransmogIconButton(_G.HideAllButton, "Interface\\AddOns\\ProjectAstral\\Transmogrification\\assets\\Transmog-Overlay-Hide", 16)
		end

		for func, slotName in pairs(transmogTabHooks) do
			if _G[func] then
				hooksecurefunc(func, function() activeTransmogSlotName = slotName end)
			end
		end

		StyleTransmogOptionLabel(_G.ShowCloakText)
		StyleTransmogOptionLabel(_G.ShowHelmText)
		ApplyFont(_G.TransmogPaginationText, 12)
		ApplyFont(_G.TransmogWarningText, 12)

		for i = 1, transmogLayout.cardCount do
			SkinTransmogItemChild(_G["ItemChild"..i], i)
		end
		EnsureTransmogAppearanceCards()
		InstallTransmogPageAggregation()

		LayoutTransmogrificationFrame()

		if _G.SetTab then
			hooksecurefunc("SetTab", function()
				SyncActiveTransmogSlotFromUI()
				E:Delay(0, function()
					LayoutTransmogrificationFrame()
					RefreshTransmogSlotBorders()
					ReconcileTransmogCards()
					ClearAllTransmogCardHovers()
				end)
			end)
		end
		if _G.OnClickTransmogButton then
			hooksecurefunc("OnClickTransmogButton", function()
				E:Delay(0, function()
					LayoutTransmogrificationFrame()
					RefreshTransmogSlotBorders()
					ApplyTransmogCardIdleState()
					ClearAllTransmogCardHovers()
				end)
			end)
		end

		frame:HookScript("OnShow", function()
			EnsureTransmogAppearanceCards()
			LayoutTransmogrificationFrame()
			RefreshTransmogSlotBorders()
			ApplyTransmogCardIdleState()
			HidePerSlotActionButtons()
			ClearAllTransmogCardHovers()
		end)
		RefreshTransmogSlotBorders()
		frame.__elvPATransmogSkinned = true
	end

	if _G.OnTransmogrificationFrameLoad then
		hooksecurefunc("OnTransmogrificationFrameLoad", SkinTransmogrificationFrame)
	end
	InstallTransmogPageAggregation()
	SkinTransmogrificationFrame()

	end

	if AstralOn("table") then
		-- ʕ •ᴥ•ʔ✿ Astral Table (lazy-built) + stash depositall ✿ ʕ •ᴥ•ʔ
		local function SkinAstralTable(frame)
			if not frame or frame.__elvPATableSkinned then return end

			if frame.StripTextures then frame:StripTextures() end
			LockTemplate(frame, "Transparent")

			if frame.TitleText then
				ApplyFont(frame.TitleText, 16)
			end

			for _, region in ipairs({ frame:GetRegions() }) do
				if region.GetObjectType and region:GetObjectType() == "FontString" then
					ApplyFont(region, region:GetStringHeight() > 18 and 16 or 11)
					if region:GetText() == "The Astral Table" then
						region:SetTextColor(1, 1, 1)
					else
						region:SetTextColor(0.7, 0.7, 0.7)
					end
				end
			end

			for _, child in ipairs({ frame:GetChildren() }) do
				if child.GetObjectType and child:GetObjectType() == "Button" and child:GetFrameStrata() then
					local fs = child.GetFontString and child:GetFontString()
					local label = fs and fs:GetText()
					if child:GetWidth() > 40 and label and not child.isSkinned then
						S:HandleButton(child, true)
					end
				end
			end

			for i = 1, 9 do
				local slot = _G["PAAstralDisenchantSlot"..i]
				if slot and not slot.__elvPASkinned then
					slot:SetTemplate("Default")
					if slot.icon then
						slot.icon:SetTexCoord(unpack(E.TexCoords))
						slot.icon:SetInside()
					end
					slot.__elvPASkinned = true
				end
			end

			local function SkinPopup(pop)
				if not pop or pop.__elvPASkinned then return end
				if pop.StripTextures then pop:StripTextures() end
				LockTemplate(pop, "Transparent")
				for _, region in ipairs({ pop:GetRegions() }) do
					if region.GetObjectType and region:GetObjectType() == "FontString" then
						ApplyFont(region, 12)
					end
				end
				for _, child in ipairs({ pop:GetChildren() }) do
					if child.IsObjectType and child:IsObjectType("CheckButton") and not child.isSkinned then
						S:HandleCheckBox(child)
					end
				end
				pop.__elvPASkinned = true
			end

			SkinPopup(frame.tierPopup)
			SkinPopup(frame.filterPopup)

			if not frame.elvPADepositGems and not frame.qolDepositGems then
				frame:SetHeight((frame:GetHeight() or 470) + 40)
				local btn = CreateFrame("Button", nil, frame)
				S:HandleButton(btn, true)
				ApplyHover(btn)
				btn:SetSize(268, 26)
				btn:SetPoint("BOTTOM", frame, "BOTTOM", 0, 14)
				local txt = btn:CreateFontString(nil, "OVERLAY")
				ApplyFont(txt, 12)
				txt:SetPoint("CENTER")
				txt:SetText("Deposit All Gems")
				btn:SetFontString(txt)
				btn:SetScript("OnClick", function()
					SendChatMessage(".astralstash depositall", "SAY")
					if PA.GemStash and PA.GemStash.DelayedRequestState then
						PA.GemStash.DelayedRequestState(400)
					end
				end)
				btn:HookScript("OnEnter", function(self)
					GameTooltip:SetOwner(self, "ANCHOR_TOP")
					GameTooltip:SetText("Deposit All Gems")
					GameTooltip:AddLine("Sends all Astral gems and scrolls in your bags to the Gem Stash.", 1, 1, 1, true)
					GameTooltip:Show()
				end)
				btn:HookScript("OnLeave", GameTooltip_Hide)
				frame.elvPADepositGems = btn
			end

			frame.__elvPATableSkinned = true
		end

		local wait = CreateFrame("Frame")
		wait:SetScript("OnUpdate", function(self)
			local frame = _G.ProjectAstralAstralDisenchant
			if not frame then return end
			SkinAstralTable(frame)
			self:SetScript("OnUpdate", nil)
		end)
	end

	if AstralOn("hub") and _G.PAMainMenuFrame then
		UI.AstralBackdrop(_G.PAMainMenuFrame)
		if _G.PAMainMenuFrame.sidebar then
			UI.AstralBackdrop(_G.PAMainMenuFrame.sidebar)
		end
	end

	if AstralOn("minimapButton") then
		local mini = _G.PAMinimapButton
		if mini and not mini.__elvPA then
			mini.__elvPA = true
			mini:SetTemplate("Default")
			local icon = mini:GetRegions()
			if icon and icon.SetTexCoord then
				icon:SetTexCoord(unpack(E.TexCoords))
				if icon.SetInside then icon:SetInside() end
			end
		end
	end
end)
