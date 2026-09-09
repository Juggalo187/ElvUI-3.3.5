local parent, ns = ...
local oUF = ns.oUF

-- sourced from Blizzard_ArenaUI/Blizzard_ArenaUI.lua
local MAX_ARENA_ENEMIES = MAX_ARENA_ENEMIES or 5

-- sourced from FrameXML/TargetFrame.lua
local MAX_BOSS_FRAMES = MAX_BOSS_FRAMES or 4

-- sourced from FrameXML/PartyMemberFrame.lua
local MAX_PARTY_MEMBERS = MAX_PARTY_MEMBERS or 4

local hiddenParent = CreateFrame('Frame', nil, UIParent)
hiddenParent:SetAllPoints()
hiddenParent:Hide()

local offScreenParent = CreateFrame('Frame', nil, UIParent)
offScreenParent:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 0, -128)
offScreenParent:SetFrameLevel(0)

local hooksecurefunc = hooksecurefunc

local function WorldPlateName(text)
	local engine = _G.ElvUI and _G.ElvUI[1]
	if engine and engine.ReplaceGMWorldName and text and text ~= "" then
		return engine:ReplaceGMWorldName(text)
	end
	return text
end

local function SuppressStockStatusBar(bar, offscreen)
	if not bar then return end

	if not bar.__elvStockSuppressed then
		bar.__elvStockSuppressed = true
		if bar.UnregisterAllEvents then bar:UnregisterAllEvents() end
		if hooksecurefunc then
			hooksecurefunc(bar, 'Show', function(self)
				self:SetAlpha(0)
				local tex = self.GetStatusBarTexture and self:GetStatusBarTexture()
				if tex then
					if tex.SetAlpha then tex:SetAlpha(0) end
					if tex.SetTexture then tex:SetTexture() end
				end
				self:Hide()
			end)
		end
	end

	if offscreen and bar.SetParent then
		bar:SetParent(offScreenParent)
	end

	local ntex = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
	if ntex then
		if ntex.SetAlpha then ntex:SetAlpha(0) end
		if ntex.SetTexture then ntex:SetTexture() end
	end
	bar:SetAlpha(0)
	bar:Hide()
	if bar.EnableMouse then bar:EnableMouse(false) end
end

local function CacheBlizzNameplateData(nameplate, nameFS)
	if not nameplate then return end
	if nameFS and nameFS.GetText then
		local text = WorldPlateName(nameFS:GetText())
		if text and text ~= '' then
			nameplate.__elvBlizzName = text
		end
	end
	if nameFS and nameFS.GetTextColor then
		nameplate.__elvBlizzNameR, nameplate.__elvBlizzNameG, nameplate.__elvBlizzNameB = nameFS:GetTextColor()
	end
end

function oUF:SyncLegacyPlateName(nameplate)
	return oUF:RefreshLegacyPlateName(nameplate)
end

function oUF:RefreshLegacyPlateName(nameplate)
	if not nameplate then return end

	local nameFS = nameplate.blizzName
	if nameFS and nameFS.GetText then
		local text = WorldPlateName(nameFS:GetText())
		if text and text ~= '' then
			nameplate.__elvBlizzName = text
			if nameFS.GetTextColor then
				nameplate.__elvBlizzNameR, nameplate.__elvBlizzNameG, nameplate.__elvBlizzNameB = nameFS:GetTextColor()
			end
			return text
		end
	end

	for i = 1, select('#', nameplate:GetRegions()) do
		local region = select(i, nameplate:GetRegions())
		if region and region.GetText then
			local text = WorldPlateName(region:GetText())
			if text and text ~= '' then
				nameplate.__elvBlizzName = text
				if region.GetTextColor then
					nameplate.__elvBlizzNameR, nameplate.__elvBlizzNameG, nameplate.__elvBlizzNameB = region:GetTextColor()
				end
				return text
			end
		end
	end

	return nameplate.__elvBlizzName
end

local function IsElvNameplateFrame(frame)
	if not frame then return end
	if frame.isNamePlate then return true end
	local name = frame.GetName and frame:GetName()
	return name and name:match('^ElvNP_')
end

local function HideStockNameplateArt(nameplate, keepHealthBar)
	oUF:RefreshLegacyPlateName(nameplate)
	if nameplate.EnableMouse then nameplate:EnableMouse(false) end
	if nameplate.SetHitRectInsets then
		nameplate:SetHitRectInsets(1000, 1000, 1000, 1000)
	end

	for _, region in ipairs({nameplate:GetRegions()}) do
		if region then
			region:SetParent(hiddenParent)
			region:SetAlpha(0)
			region:Hide()
		end
	end

	for _, child in ipairs({nameplate:GetChildren()}) do
		if child and not IsElvNameplateFrame(child) and not child.unitFrame then
			if child.EnableMouse then child:EnableMouse(false) end
			if child == nameplate.HealthBar then
				if not keepHealthBar then
					child:SetAlpha(0)
					child:Hide()
					local ntex = child.GetStatusBarTexture and child:GetStatusBarTexture()
					if ntex and ntex.SetAlpha then ntex:SetAlpha(0) end
				end
			else
				child:SetParent(hiddenParent)
				child:SetAlpha(0)
				child:Hide()
			end
		end
	end
end

function oUF:SuppressStockNameplateArt(nameplate, keepHealthBar)
	if not nameplate or _G.ELVUI_HAS_AWESOME_NAMEPLATES then return end
	if keepHealthBar == nil then keepHealthBar = true end
	HideStockNameplateArt(nameplate, keepHealthBar)
end

function oUF:HideStockHealthBarVisual(nameplate)
	SuppressStockStatusBar(nameplate and nameplate.HealthBar, false)
end

function oUF:HideStockCastBarVisual(nameplate)
	SuppressStockStatusBar(nameplate and nameplate.CastBar, true)
end

function oUF:SuppressLegacyStockBars(nameplate)
	if not nameplate or _G.ELVUI_HAS_AWESOME_NAMEPLATES then return end
	oUF:HideStockHealthBarVisual(nameplate)
	oUF:HideStockCastBarVisual(nameplate)
end

local function handleFrame(baseName)
	local frame
	if(type(baseName) == 'string') then
		frame = _G[baseName]
	else
		frame = baseName
	end

	if(frame) then
		frame:UnregisterAllEvents()
		frame:Hide()

		-- Keep frame hidden without causing taint
		frame:SetParent(hiddenParent)

		local health = frame.healthBar or frame.healthbar
		if(health) then
			health:UnregisterAllEvents()
		end

		local power = frame.manabar
		if(power) then
			power:UnregisterAllEvents()
		end

		local spell = frame.castBar or frame.spellbar
		if(spell) then
			spell:UnregisterAllEvents()
		end

		local buffFrame = frame.BuffFrame
		if(buffFrame) then
			buffFrame:UnregisterAllEvents()
		end
	end
end

function oUF:DisableBlizzardNamePlate(nameplate)
	-- ʕ •ᴥ•ʔ✿ Friendly plates often have no health/cast children on 3.3.5 ✿ ʕ •ᴥ•ʔ
	if not nameplate or nameplate.__elvBlizzDisabled then return end
	nameplate.__elvBlizzDisabled = true

	local highlight, nameFS
	for i = 1, select('#', nameplate:GetRegions()) do
		local region = select(i, nameplate:GetRegions())
		if region and region.GetText and not nameFS then
			nameFS = region
		elseif region and region.GetTexture and region:GetTexture() == [[Interface\Tooltips\Nameplate-Border]] then
			highlight = highlight or select(3, nameplate:GetRegions())
		end
	end
	if not highlight then
		highlight = select(3, nameplate:GetRegions())
	end
	nameplate.blizzHighlight = highlight
	nameplate.blizzName = nameFS

	local blizzElements = {nameplate:GetRegions()}
	local healthBar, castBar
	for _, child in ipairs({nameplate:GetChildren()}) do
		if child and not child.isNamePlate then
			tinsert(blizzElements, child)
			if child.GetStatusBarTexture then
				if not healthBar then
					healthBar = child
				elseif not castBar then
					castBar = child
				end
			end
		end
	end

	nameplate.HealthBar = healthBar
	nameplate.CastBar = castBar

	CacheBlizzNameplateData(nameplate, nameFS)

	if healthBar then
		nameplate.__hpMin, nameplate.__hpMax = healthBar:GetMinMaxValues()
		nameplate.__hpVal = healthBar:GetValue()
		nameplate.__hpR, nameplate.__hpG, nameplate.__hpB = healthBar:GetStatusBarColor()
	end

	-- ʕ •ᴥ•ʔ✿ Stock 3.3.5: hide native HP/cast art; ElvUI draws at plateSize ✿ ʕ •ᴥ•ʔ
	if not _G.ELVUI_HAS_AWESOME_NAMEPLATES then
		HideStockNameplateArt(nameplate, false)
		oUF:SuppressLegacyStockBars(nameplate)
		return
	end

	for _, child in ipairs(blizzElements) do
		if child then
			child:SetParent(hiddenParent)
			child:SetAlpha(0)
			child:Hide()
			if child.SetTexture then
				child:SetTexture()
			end
		end
	end

	if castBar then
		castBar:SetParent(offScreenParent)
		castBar:SetAlpha(0)
		castBar:Hide()
	end
end

function oUF:DisableBlizzard(unit)
	if(not unit) then return end

	if(unit == 'player') then
		handleFrame(PlayerFrame)

		-- For the damn vehicle support:
		PlayerFrame:RegisterEvent('PLAYER_ENTERING_WORLD')
		PlayerFrame:RegisterEvent('UNIT_ENTERING_VEHICLE')
		PlayerFrame:RegisterEvent('UNIT_ENTERED_VEHICLE')
		PlayerFrame:RegisterEvent('UNIT_EXITING_VEHICLE')
		PlayerFrame:RegisterEvent('UNIT_EXITED_VEHICLE')

		-- User placed frames don't animate
		PlayerFrame:SetUserPlaced(true)
		PlayerFrame:SetDontSavePosition(true)
	elseif(unit == 'pet') then
		handleFrame(PetFrame)
	elseif(unit == 'target') then
		handleFrame(TargetFrame)
		handleFrame(ComboFrame)
	elseif(unit == 'focus') then
		handleFrame(FocusFrame)
		handleFrame(TargetofFocusFrame)
	elseif(unit == 'targettarget') then
		handleFrame(TargetFrameToT)
	elseif(unit:match('boss%d?$')) then
		local id = unit:match('boss(%d)')
		if(id) then
			handleFrame('Boss' .. id .. 'TargetFrame')
		else
			for i = 1, MAX_BOSS_FRAMES do
				handleFrame(string.format('Boss%dTargetFrame', i))
			end
		end
	elseif(unit:match('party%d?$')) then
		local id = unit:match('party(%d)')
		if(id) then
			handleFrame('PartyMemberFrame' .. id)
		else
			for i = 1, MAX_PARTY_MEMBERS do
				handleFrame(string.format('PartyMemberFrame%d', i))
			end
		end
	elseif(unit:match('arena%d?$')) then
		local id = unit:match('arena(%d)')
		if(id) then
			handleFrame('ArenaEnemyFrame' .. id)
		else
			for i = 1, MAX_ARENA_ENEMIES do
				handleFrame(string.format('ArenaEnemyFrame%d', i))
			end
		end

		-- Blizzard_ArenaUI should not be loaded
		Arena_LoadUI = function() end
		SetCVar('showArenaEnemyFrames', '0', 'SHOW_ARENA_ENEMY_FRAMES_TEXT')
	end
end