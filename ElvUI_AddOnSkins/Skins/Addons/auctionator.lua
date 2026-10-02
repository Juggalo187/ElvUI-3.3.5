local E, L, V, P, G = unpack(ElvUI)
local S = E:GetModule("Skins")
local AS = E:GetModule("AddOnSkins")

if not AS:IsAddonLODorEnabled("Auctionator") then return end

local _G = _G
local type = type
local unpack = unpack

local GetItemIcon = GetItemIcon
local GetItemInfo = GetItemInfo
local GetItemQualityColor = GetItemQualityColor

S:AddCallbackForAddon("Auctionator", "Auctionator", function()
	if not E.private.addOnSkins.Auctionator then return end

	-- Helper function to recursively find and skin all EditBoxes in a parent frame
	local function SkinChildEditBoxes(parent)
		if not parent or not parent.GetChildren then return end
		local children = { parent:GetChildren() }
		for _, child in ipairs(children) do
			if child and child.GetObjectType and child:GetObjectType() == "EditBox" then
				if not child.isSkinned then
					S:HandleEditBox(child)
					child.isSkinned = true
				end
			end
			if child and child.GetChildren then
				SkinChildEditBoxes(child)
			end
		end
	end

	-- Helper function to lock bottom buttons in position across all tabs
	local function UpdateBottomButtons()
		local closeBtn = _G["AuctionatorCloseButton"]
		local buy1Btn = _G["Atr_Buy1_Button"] or _G["Atr_Buy1Button"]
		local cancelSelBtn = _G["Atr_CancelSelectionButton"] or _G["Atr_CancelSelection_Button"]

		if closeBtn then
			closeBtn:ClearAllPoints()
			closeBtn:Point("BOTTOMRIGHT", 202, 8)
		end

		if buy1Btn then
			buy1Btn:ClearAllPoints()
			if closeBtn then
				buy1Btn:Point("RIGHT", closeBtn, "LEFT", -5, 0)
			end
			if cancelSelBtn then
				cancelSelBtn:ClearAllPoints()
				cancelSelBtn:Point("RIGHT", buy1Btn, "LEFT", -5, 0)
			end
		elseif cancelSelBtn then
			cancelSelBtn:ClearAllPoints()
			if closeBtn then
				cancelSelBtn:Point("RIGHT", closeBtn, "LEFT", -5, 0)
			end
		end
	end

	-- Error Frame
	if Atr_Error_Frame then
		Atr_Error_Frame:SetTemplate("Transparent")
		S:HandleButton((Atr_Error_Frame:GetChildren()))
	end

	-- BuyConfirm Frame
	if Atr_Buy_Confirm_Frame then
		Atr_Buy_Confirm_Frame:SetTemplate("Transparent")

		if Atr_Buy_Confirm_Numstacks then S:HandleEditBox(Atr_Buy_Confirm_Numstacks) end
		if Atr_Buy_Confirm_OKBut then S:HandleButton(Atr_Buy_Confirm_OKBut) end
		if Atr_Buy_Confirm_CancelBut then S:HandleButton(Atr_Buy_Confirm_CancelBut) end
	end

	-- Advanced Search
	if Atr_Adv_Search_Dialog then
		Atr_Adv_Search_Dialog:StripTextures()
		Atr_Adv_Search_Dialog:SetTemplate("Transparent")
		Atr_Adv_Search_Dialog:Point("TOPLEFT", 215, -183)
		
		if Atr_AS_Searchtext_ClearBut then 
			S:HandleCloseButton(Atr_AS_Searchtext_ClearBut) 
		end

		if Atr_AS_Searchtext then S:HandleEditBox(Atr_AS_Searchtext) end
		if Atr_AS_Minlevel then S:HandleEditBox(Atr_AS_Minlevel) end
		if Atr_AS_Maxlevel then S:HandleEditBox(Atr_AS_Maxlevel) end

		if Atr_ASDD_Class then S:HandleDropDownBox(Atr_ASDD_Class, 180) end
		if Atr_ASDD_Subclass then S:HandleDropDownBox(Atr_ASDD_Subclass, 180) end
		if Atr_ASDD_Invtype then S:HandleDropDownBox(Atr_ASDD_Invtype, 180) end
		if Atr_ASDD_Quality then S:HandleDropDownBox(Atr_ASDD_Quality, 180) end


		if Atr_Adv_Search_ResetBut then S:HandleButton(Atr_Adv_Search_ResetBut) end
		if Atr_Adv_Search_OKBut then S:HandleButton(Atr_Adv_Search_OKBut) end
		if Atr_Adv_Search_CancelBut then S:HandleButton(Atr_Adv_Search_CancelBut) end
	end

	if Atr_FullScanAnalyze then
		hooksecurefunc("Atr_FullScanAnalyze", function()
			if Atr_FullScanResults then
				Atr_FullScanResults:SetBackdropColor(unpack(E.media.backdropfadecolor))
			end
		end)
	end

	-- Full Scan
	if Atr_FullScanFrame then
		Atr_FullScanFrame:StripTextures()
		Atr_FullScanFrame:SetTemplate("Transparent")
		Atr_FullScanFrame:Height(424)
		Atr_FullScanFrame:Point("TOPLEFT", 215, -116)

		if Atr_FullScanResults then
			Atr_FullScanResults:SetTemplate("Transparent")
		end

		if Atr_FullScanStartButton then S:HandleButton(Atr_FullScanStartButton) end
		if Atr_FullScanDone then S:HandleButton(Atr_FullScanDone) end
	end

	if Atr_ShowFullScanFrame then
		hooksecurefunc("Atr_ShowFullScanFrame", function()
			if Atr_FullScanFrame then
				Atr_FullScanFrame:SetBackdropColor(unpack(E.media.backdropfadecolor))
			end
		end)
	end

	-- Check Actives
	if Atr_CheckActives_Frame then
		Atr_CheckActives_Frame:StripTextures()
		Atr_CheckActives_Frame:SetTemplate("Transparent")

		local checkActivesButton1, checkActivesButton2 = Atr_CheckActives_Frame:GetChildren()
		if checkActivesButton1 then S:HandleButton(checkActivesButton1) end
		if checkActivesButton2 then S:HandleButton(checkActivesButton2) end
	end

	-- Confirm Frame
	if Atr_Confirm_Frame then
		Atr_Confirm_Frame:SetTemplate("Transparent")
		if Atr_Confirm_Cancel then S:HandleButton(Atr_Confirm_Cancel) end
		S:HandleButton((select(2, Atr_Confirm_Frame:GetChildren())))
	end

	-- Function to skin inventory buttons, edit boxes, and checkboxes dynamically
	local function SkinInventoryTab()
		local inventoryButtons = {
			"Atr_Inventory_Refresh",
			"Atr_Inventory_Clear",
			"Atr_Inventory_SelectAll",
			"Atr_Inventory_UseRecommended",
			"Atr_Inventory_StackMax",
			"Atr_Inventory_AuctionsMax",
			"Atr_Inventory_StartQueue",
			"Atr_Inventory_PostStack",
			"Atr_Inventory_Skip",
			"Atr_Inventory_Stop",
			"Atr_Inventory_Duration",
			"Atr_Inventory_ScrollFrame",
		}

		for _, name in ipairs(inventoryButtons) do
			local btn = _G[name]
			if btn and not btn.isSkinned then
				S:HandleButton(btn)
				btn.isSkinned = true
			end
		end

		-- Checkboxes
		for i = 1, 20 do
			local cb = _G["Atr_Inventory_Row"..i.."Check"]
			if cb and not cb.isSkinned then
				S:HandleCheckBox(cb)
				cb.isSkinned = true
			end
		end

		-- Explicit known edit box names
		local inventoryEditBoxes = {
			"Atr_Inventory_BuyoutPriceGold",
			"Atr_Inventory_BuyoutPriceSilver",
			"Atr_Inventory_BuyoutPriceCopper",
			"Atr_Inventory_ItemPriceGold",
			"Atr_Inventory_ItemPriceSilver",
			"Atr_Inventory_ItemPriceCopper",
			"Atr_Inventory_StackPriceGold",
			"Atr_Inventory_StackPriceSilver",
			"Atr_Inventory_StackPriceCopper",
			"Atr_Inventory_Stacksize",
			"Atr_Inventory_NumAuctions",
			"Atr_Inventory_Batch_Stacksize",
			"Atr_Inventory_Batch_NumAuctions",
			"Atr_Inventory_StackSize",
			"Atr_Inventory_NumAuctions",
		}
		for _, name in ipairs(inventoryEditBoxes) do
			local eb = _G[name]
			if eb and not eb.isSkinned then
				S:HandleEditBox(eb)
				eb.isSkinned = true
			end
		end

		-- Recursive scan over parent panels to catch un-named/nested edit boxes
		if Atr_InventoryFrame then SkinChildEditBoxes(Atr_InventoryFrame) end
		if Atr_Panel_Inventory then SkinChildEditBoxes(Atr_Panel_Inventory) end
		if Atr_Main_Panel then SkinChildEditBoxes(Atr_Main_Panel) end
	end

	local SELL_TAB = 1
	local BUY_TAB = 3
	if Atr_AuctionFrameTab_OnClick then
		hooksecurefunc("Atr_AuctionFrameTab_OnClick", function(self, index, down)
			if not index or type(index) == "string" then
				index = self:GetID()
			end

			if Atr_IsAuctionatorTab and Atr_IsAuctionatorTab(index) then
				if index == Atr_FindTabIndex(BUY_TAB) then
					if Atr_Hlist then Atr_Hlist:Height(242) end
					if Atr_Hlist_ScrollFrame then Atr_Hlist_ScrollFrame:Height(242) end
				else
					if Atr_Hlist then Atr_Hlist:Height(330) end
					if Atr_Hlist_ScrollFrame then Atr_Hlist_ScrollFrame:Height(330) end

					if index == Atr_FindTabIndex(SELL_TAB) then
						if Atr_Hlist_ScrollFrame and Atr_Hlist_ScrollFrame._Hide then
							Atr_Hlist_ScrollFrame:_Hide()
						end
						if AuctionFrameMoneyFrame then
							AuctionFrameMoneyFrame:Show()
						end
					end
				end
			end

			SkinInventoryTab()
			UpdateBottomButtons()
		end)
	end

	if Atr_SetTextureButton then
		hooksecurefunc("Atr_SetTextureButton", function(elementName, count, itemlink)
			local button = _G[elementName]
			local buttonName = _G[elementName.."Name"]

			if button and GetItemIcon(itemlink) then
				local _, _, quality = GetItemInfo(itemlink)
				if quality then
					local r, g, b = GetItemQualityColor(quality)

					button:SetBackdropBorderColor(r, g, b)
					if buttonName then
						buttonName:SetTextColor(r, g, b)
					end
				else
					button:SetBackdropBorderColor(unpack(E.media.bordercolor))
					if buttonName then
						buttonName:SetTextColor(1, 0.82, 0)
					end
				end
			elseif button then
				button:SetBackdropBorderColor(unpack(E.media.bordercolor))
				if buttonName then
					buttonName:SetTextColor(1, 0.82, 0)
				end
			end
		end)
	end

	local function itemButtomSetNormalTexture(self, texture)
		if self.normalTexture then
			self.normalTexture:SetTexture(texture)
		end
	end

	local function skinItemButtom(frame)
		if not frame then return end
		frame:StripTextures()
		frame:SetTemplate("Default", true)
		frame:StyleButton(nil, true)

		frame:SetNormalTexture("")
		frame.normalTexture = frame:GetNormalTexture()
		if frame.normalTexture then
			frame.normalTexture:SetTexCoord(unpack(E.TexCoords))
			frame.normalTexture:SetInside()
		end
		frame.SetNormalTexture = itemButtomSetNormalTexture
	end

	local function skinButtonHighlight(button)
		if not button then return end
		local highlight = button:GetHighlightTexture()
		if highlight then
			highlight:SetTexCoord(0, 1, 0, 1)
			highlight:SetTexture(E.Media.Textures.Highlight)
			highlight:SetVertexColor(0.9, 0.9, 0.9, 0.35)
		end

		local pushed = button:GetPushedTexture()
		if pushed then
			pushed:SetTexCoord(0, 1, 0, 1)
			pushed:SetTexture(E.Media.Textures.Highlight)
			pushed:SetVertexColor(0.9, 0.9, 0.9, 0.35)
		end
	end

	S:SecureHook("Atr_Init", function()
		S:Unhook("Atr_Init")

		if not E.private.skins.blizzard.enable or not E.private.skins.blizzard.auctionhouse then
			if AuctionFrame and AuctionFrame.numTabs then
				for i = AuctionFrame.numTabs - 2, AuctionFrame.numTabs do
					local tab = _G["AuctionFrameTab"..i]
					if tab then
						S:HandleTab(tab)
						local prevTab = _G["AuctionFrameTab"..(i - 1)]
						if prevTab then
							tab:Point("LEFT", prevTab, "RIGHT", -15, 0)
						end
					end
				end
			end
		end

		if Atr_Main_Panel then Atr_Main_Panel:Size(412, 424) end

		if Atr_Mask then
			Atr_Mask:Size(819, 422)
			Atr_Mask:Point("TOPLEFT", 12, -117)
		end

		if AuctionatorTitle then AuctionatorTitle:Point("TOP", 0, -5) end

		if Atr_FullScanButton then
			S:HandleButton(Atr_FullScanButton)
			Atr_FullScanButton:Height(22)
			if Auctionator1Button then
				Atr_FullScanButton:Point("RIGHT", Auctionator1Button, "LEFT", -5, 0)
			end
		end

		if Auctionator1Button then
			S:HandleButton(Auctionator1Button)
			Auctionator1Button:Height(22)
			if Atr_Search_Button then
				Auctionator1Button:Point("LEFT", Atr_Search_Button, "RIGHT", 177, 0)
			end
		end

		if AuctionatorCloseButton then
			S:HandleButton(AuctionatorCloseButton)
			AuctionatorCloseButton:HookScript("OnShow", UpdateBottomButtons)
		end

		local buy1Btn = _G["Atr_Buy1_Button"] or _G["Atr_Buy1Button"]
		local cancelSelBtn = _G["Atr_CancelSelectionButton"] or _G["Atr_CancelSelection_Button"]

		if buy1Btn then
			S:HandleButton(buy1Btn)
			buy1Btn:HookScript("OnShow", UpdateBottomButtons)
		end

		if cancelSelBtn then
			S:HandleButton(cancelSelBtn)
			cancelSelBtn:HookScript("OnShow", UpdateBottomButtons)
		end

		UpdateBottomButtons()

		-- Left panel
		if Atr_Hlist then
			Atr_Hlist:StripTextures()
			Atr_Hlist:SetTemplate("Transparent")
			Atr_Hlist:Width(172)
			Atr_Hlist:Point("TOPLEFT", -191, -57)
		end

		if Atr_Hlist_ScrollFrame then
			Atr_Hlist_ScrollFrame:Width(172)
			Atr_Hlist_ScrollFrame:Point("TOPLEFT", -191, -57)
			Atr_Hlist_ScrollFrame._Hide = Atr_Hlist_ScrollFrame.Hide
			Atr_Hlist_ScrollFrame.Hide = E.noop
		end

		if Atr_Hlist_ScrollFrameScrollBar then
			S:HandleScrollBar(Atr_Hlist_ScrollFrameScrollBar)
			if Atr_Hlist_ScrollFrame then
				Atr_Hlist_ScrollFrameScrollBar:Point("TOPLEFT", Atr_Hlist_ScrollFrame, "TOPRIGHT", 3, -19)
				Atr_Hlist_ScrollFrameScrollBar:Point("BOTTOMLEFT", Atr_Hlist_ScrollFrame, "BOTTOMRIGHT", 3, 19)
			end
		end

		for i = 1, 20 do
			local button = _G["AuctionatorHEntry"..i]
			if button then
				button:Width(170)
				skinButtonHighlight(button)

				local entryText = _G["AuctionatorHEntry"..i.."_EntryText"]
				if entryText then entryText:Width(168) end

				if i == 1 then
					button:Point("TOPLEFT", 1, -1)
				else
					button:Point("TOPLEFT", 1, -1 - (i - 1) * 16)
				end
			end
		end

		-- Right panel
		if Atr_Hilite1 then
			Atr_Hilite1:SetTemplate("Transparent", nil, true)
			Atr_Hilite1:SetBackdropColor(0, 0, 0, 0)
			Atr_Hilite1:Height(112)
			Atr_Hilite1:Point("TOPLEFT", 5, -57)
			Atr_Hilite1:Point("RIGHT", 202, 0)
		end

		skinItemButtom(Atr_RecommendItem_Tex)

		if AuctionatorMessageFrame then AuctionatorMessageFrame:Point("TOP", 100, -65) end
		if AuctionatorMessage2Frame then AuctionatorMessage2Frame:Point("TOP", 100, -55) end

		for i = 1, 3 do
			local tab = _G["Atr_ListTabsTab"..i]
			if tab then
				tab:StripTextures()
				S:HandleButton(tab)
				tab:Height(22)

				if i ~= 3 then
					local nextTab = _G["Atr_ListTabsTab"..(i + 1)]
					if nextTab then
						tab:Point("RIGHT", nextTab, "LEFT", -3, 0)
					end
				end
			end
		end

		if Atr_HeadingsBar then
			Atr_HeadingsBar:StripTextures()
			Atr_HeadingsBar:Point("TOPLEFT", 6, -152)
			Atr_HeadingsBar:CreateBackdrop("Transparent")
			if Atr_HeadingsBar.backdrop then
				Atr_HeadingsBar.backdrop:Point("TOPLEFT", -1, -41)
				Atr_HeadingsBar.backdrop:Point("BOTTOMRIGHT", 3, -171)
			end
		end

		if Atr_ListTabs and Atr_HeadingsBar then
			Atr_ListTabs:Point("BOTTOMRIGHT", Atr_HeadingsBar, "TOPRIGHT", 11, -22)
		end

		if AuctionatorScrollFrame then
			AuctionatorScrollFrame:Height(194)
			AuctionatorScrollFrame:Point("TOPLEFT", 5, -193)
		end

		if AuctionatorScrollFrameScrollBar then
			S:HandleScrollBar(AuctionatorScrollFrameScrollBar)
			if AuctionatorScrollFrame then
				AuctionatorScrollFrameScrollBar:Point("TOPLEFT", AuctionatorScrollFrame, "TOPRIGHT", 3, -19)
				AuctionatorScrollFrameScrollBar:Point("BOTTOMLEFT", AuctionatorScrollFrame, "BOTTOMRIGHT", 3, 19)
			end
		end

		for _, tab in ipairs({Atr_Col1_Heading_Button, Atr_Col3_Heading_Button}) do
			if tab then
				tab:StripTextures()
				tab:SetNormalTexture([[Interface\Buttons\UI-SortArrow]])
				tab:StyleButton()
			end
		end

		if AuctionatorEntry1 and AuctionatorScrollFrame then
			AuctionatorEntry1:Point("TOPLEFT", AuctionatorScrollFrame, "TOPLEFT", 1, -1)
		end

		for i = 1, 12 do
			local button = _G["AuctionatorEntry"..i]
			if button then
				button:Width(586)
				skinButtonHighlight(button)
			end
		end

		if AuctionatorScrollFrame and Atr_HeadingsBar and Atr_HeadingsBar.backdrop then
			AuctionatorScrollFrame:HookScript("OnShow", function(self)
				Atr_HeadingsBar.backdrop:Point("BOTTOMRIGHT", -18, -171)
			end)
			AuctionatorScrollFrame:HookScript("OnHide", function(self)
				Atr_HeadingsBar.backdrop:Point("BOTTOMRIGHT", 3, -171)
			end)
		end

		-- Buy tab
		if Atr_DropDownSL then
			S:HandleDropDownBox(Atr_DropDownSL, 221)
			Atr_DropDownSL:Point("TOPLEFT", -211, -29)
		end

		if Atr_Search_Box then S:HandleEditBox(Atr_Search_Box) end
		if Atr_Search_Button then S:HandleButton(Atr_Search_Button) end
		if Atr_Adv_Search_Button then S:HandleButton(Atr_Adv_Search_Button) end
		if Atr_Adv_Search_CB then S:HandleCheckBox(Atr_Adv_Search_CB) end
		if Atr_Exact_Search_Button then S:HandleButton(Atr_Exact_Search_Button) end
		
		if Atr_Search_ClearBut then 
			S:HandleCloseButton(Atr_Search_ClearBut) 
		end

		if Atr_Search_Box then Atr_Search_Box:Point("TOPLEFT", 20, -32) end
		if Atr_Search_Button and Atr_Search_Box then
			Atr_Search_Button:Point("LEFT", Atr_Search_Box, "RIGHT", 6, 0)
		end

		if Atr_Adv_Search_Button then
			Atr_Adv_Search_Button:Height(22)
			if Atr_Search_Button then
				Atr_Adv_Search_Button:Point("LEFT", Atr_Search_Button, "RIGHT", 5, 0)
			end
		end

		-- Shopping List Buttons
		local shoppingListButtons = {
			"Atr_AddSItemButton",
			"Atr_AddToSListButton",
			"Atr_RemSItemButton",
			"Atr_RemFromSListButton",
			"Atr_SrchSListButton",
			"Atr_MngSListsButton",
			"Atr_DelSListButton",
			"Atr_NewSListButton",
		}
		for _, name in ipairs(shoppingListButtons) do
			local btn = _G[name]
			if btn then
				S:HandleButton(btn)
			end
		end

		-- Shopping List Options Frame & Buttons
		if Atr_ShpList_Options_Frame then
			Atr_ShpList_Options_Frame:StripTextures()
			Atr_ShpList_Options_Frame:SetTemplate("Transparent")
		end

		local shpListOptionButtons = {
			"Atr_ShpList_DeleteButton",
			"Atr_ShpList_EditButton",
			"Atr_ShpList_RenameButton",
			"Atr_ShpList_NewButton",
			"Atr_ShpList_ImportButton",
			"Atr_ShpList_ExportButton",
		}
		for _, name in ipairs(shpListOptionButtons) do
			local btn = _G[name]
			if btn then
				S:HandleButton(btn)
			end
		end

		if Atr_Back_Button then
			S:HandleButton(Atr_Back_Button)
			Atr_Back_Button:Height(22)
			Atr_Back_Button:Point("TOPLEFT", 7, 13)
		end

		-- Sell tab
		if Atr_SellControls then
			Atr_SellControls:SetTemplate("Transparent")
			Atr_SellControls:Size(193, 330)
			Atr_SellControls:Point("TOPLEFT", -191, -57)
		end

		if _G["Atr_BagPanel"] then
			local bagPanel = _G["Atr_BagPanel"]
			bagPanel:StripTextures()
			bagPanel:SetTemplate("Transparent")

			for i = 1, 20 do
				local btn = _G["Atr_BagItem"..i] or _G["Atr_BagItem_"..i] or _G["Atr_BagPanel_Item"..i]
				if btn then
					skinItemButtom(btn)
				end
			end

			local point, relativeTo, relativePoint, xOfs, yOfs = Atr_BagPanel:GetPoint()
			Atr_BagPanel:ClearAllPoints()
			Atr_BagPanel:SetPoint(point, relativeTo, relativePoint, xOfs + 4, yOfs + 15)

		end

		skinItemButtom(Atr_SellControls_Tex)
		if Atr_SellControls_Tex then Atr_SellControls_Tex:Point("TOPLEFT", 11, -14) end

		if Atr_StackPriceText then Atr_StackPriceText:Point("TOPLEFT", 7, -56) end
		if Atr_ItemPriceText then Atr_ItemPriceText:Point("TOPLEFT", 7, -96) end

		if Atr_CreateAuctionButton then
			S:HandleButton(Atr_CreateAuctionButton)
			Atr_CreateAuctionButton:Point("TOPLEFT", 4, -139)
		end

		if Atr_Batch_Stacksize_Text then Atr_Batch_Stacksize_Text:Point("TOPLEFT", 55, -177) end
		if Atr_Batch_NumAuctions and Atr_Batch_Stacksize_Text then
			Atr_Batch_NumAuctions:Point("TOPLEFT", Atr_Batch_Stacksize_Text, "TOPLEFT", -41, 0)
		end

		if Atr_Batch_MaxAuctions_Text and Atr_Batch_NumAuctions then
			Atr_Batch_MaxAuctions_Text:ClearAllPoints()
			Atr_Batch_MaxAuctions_Text:Point("BOTTOM", Atr_Batch_NumAuctions, 0, -14)
		end
		if Atr_Batch_MaxStacksize_Text and Atr_Batch_Stacksize then
			Atr_Batch_MaxStacksize_Text:ClearAllPoints()
			Atr_Batch_MaxStacksize_Text:Point("BOTTOM", Atr_Batch_Stacksize, 0, -14)
		end

		if Atr_StartingPriceText then Atr_StartingPriceText:Point("TOPLEFT", 13, -229) end
		if Atr_StartingPriceDiscountText then Atr_StartingPriceDiscountText:Point("TOPLEFT", 10, -238) end

		if Atr_Duration_Text then
			Atr_Duration_Text:Point("TOPLEFT", 10, -276)
			Atr_Duration_Text.SetPoint = E.noop
		end
		if Atr_Duration then S:HandleDropDownBox(Atr_Duration, 130) end

		if Atr_Deposit_Text then Atr_Deposit_Text:Point("TOPLEFT", 10, -304) end

		if Atr_StackPriceGold then S:HandleEditBox(Atr_StackPriceGold) end
		if Atr_StackPriceSilver then S:HandleEditBox(Atr_StackPriceSilver) end
		if Atr_StackPriceCopper then S:HandleEditBox(Atr_StackPriceCopper) end
		if Atr_ItemPriceGold then S:HandleEditBox(Atr_ItemPriceGold) end
		if Atr_ItemPriceSilver then S:HandleEditBox(Atr_ItemPriceSilver) end
		if Atr_ItemPriceCopper then S:HandleEditBox(Atr_ItemPriceCopper) end
		if Atr_StartingPriceGold then S:HandleEditBox(Atr_StartingPriceGold) end
		if Atr_StartingPriceSilver then S:HandleEditBox(Atr_StartingPriceSilver) end
		if Atr_StartingPriceCopper then S:HandleEditBox(Atr_StartingPriceCopper) end
		if Atr_Batch_NumAuctions then S:HandleEditBox(Atr_Batch_NumAuctions) end
		if Atr_Batch_Stacksize then S:HandleEditBox(Atr_Batch_Stacksize) end

		-- Dynamic Inventory tab updates
		if Atr_Inventory_Update then
			hooksecurefunc("Atr_Inventory_Update", SkinInventoryTab)
		end
		if Atr_ShowInventoryFrame then
			hooksecurefunc("Atr_ShowInventoryFrame", SkinInventoryTab)
		end

		SkinInventoryTab()

		-- More tab
		if Atr_DropDown1 then
			S:HandleDropDownBox(Atr_DropDown1, 221)
			Atr_DropDown1:Point("TOPLEFT", -211, -29)
		end

		if Atr_HideBidOnly_Button then
			S:HandleCheckBox(Atr_HideBidOnly_Button)
		end
		
		if Atr_Chain_Buy_Button then
			S:HandleCheckBox(Atr_Chain_Buy_Button)
		end
		
		if Atr_MatchRarity_Button then
			S:HandleCheckBox(Atr_MatchRarity_Button)
		end

		if Atr_CheckActiveButton then
			S:HandleButton(Atr_CheckActiveButton)
			Atr_CheckActiveButton:Size(193, 22)
			Atr_CheckActiveButton:Point("TOPLEFT", -191, -394)
		end

		if Atr_CancelAllUndercutsButton then
			S:HandleButton(Atr_CancelAllUndercutsButton)
			Atr_CancelAllUndercutsButton:Height(22)
			Atr_CancelAllUndercutsButton:Point("TOPLEFT", 7, -394)
		end
	end)

	-- Config / Options Windows
	if Atr_BasicOptionsFrame then Atr_BasicOptionsFrame:SetTemplate("Transparent") end
	if Atr_TooltipsOptionsFrame then Atr_TooltipsOptionsFrame:SetTemplate("Transparent") end
	if Atr_UCConfigFrame then Atr_UCConfigFrame:SetTemplate("Transparent") end
	if Atr_StackingOptionsFrame then Atr_StackingOptionsFrame:SetTemplate("Transparent") end
	if Atr_ScanningOptionsFrame then Atr_ScanningOptionsFrame:SetTemplate("Transparent") end
	if AuctionatorDescriptionFrame then AuctionatorDescriptionFrame:SetTemplate("Transparent") end

	if Atr_Stacking_List then Atr_Stacking_List:SetTemplate("Transparent") end

	if AuctionatorOption_Enable_Alt_CB then S:HandleCheckBox(AuctionatorOption_Enable_Alt_CB) end
	if AuctionatorOption_Open_All_Bags_CB then S:HandleCheckBox(AuctionatorOption_Open_All_Bags_CB) end
	if AuctionatorOption_Show_StartingPrice_CB then S:HandleCheckBox(AuctionatorOption_Show_StartingPrice_CB) end
	if AuctionatorOption_Def_Duration_CB then S:HandleCheckBox(AuctionatorOption_Def_Duration_CB) end
	if ATR_tipsVendorOpt_CB then S:HandleCheckBox(ATR_tipsVendorOpt_CB) end
	if ATR_tipsAuctionOpt_CB then S:HandleCheckBox(ATR_tipsAuctionOpt_CB) end
	if ATR_tipsDisenchantOpt_CB then S:HandleCheckBox(ATR_tipsDisenchantOpt_CB) end

	if AuctionatorOption_Deftab then S:HandleDropDownBox(AuctionatorOption_Deftab) end
	if Atr_tipsShiftDD then S:HandleDropDownBox(Atr_tipsShiftDD) end
	if Atr_deDetailsDD then S:HandleDropDownBox(Atr_deDetailsDD, 220) end
	if Atr_scanLevelDD then S:HandleDropDownBox(Atr_scanLevelDD) end
	if Atr_deDetailsDDText then Atr_deDetailsDDText:SetJustifyH("RIGHT") end

	local moneyEditBoxes = {
		"UC_5000000_MoneyInput",
		"UC_1000000_MoneyInput",
		"UC_200000_MoneyInput",
		"UC_50000_MoneyInput",
		"UC_10000_MoneyInput",
		"UC_2000_MoneyInput",
		"UC_500_MoneyInput",
	}
	for _, name in ipairs(moneyEditBoxes) do
		if _G[name.."Gold"] then S:HandleEditBox(_G[name.."Gold"]) end
		if _G[name.."Silver"] then S:HandleEditBox(_G[name.."Silver"]) end
		if _G[name.."Copper"] then S:HandleEditBox(_G[name.."Copper"]) end
	end
	if Atr_Starting_Discount then S:HandleEditBox(Atr_Starting_Discount) end

	if Atr_UCConfigFrame_Reset then S:HandleButton(Atr_UCConfigFrame_Reset) end
	if Atr_StackingOptionsFrame_Edit then S:HandleButton(Atr_StackingOptionsFrame_Edit) end
	if Atr_StackingOptionsFrame_New then S:HandleButton(Atr_StackingOptionsFrame_New) end
end)