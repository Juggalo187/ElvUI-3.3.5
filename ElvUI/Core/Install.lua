local E, L, V, P, G = unpack(select(2, ...)); --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local UF = E:GetModule("UnitFrames")
local S = E:GetModule("Skins")

--Lua functions
local _G = _G
local format = format
--WoW API / Variables
local CreateFrame = CreateFrame
local SetCVar = SetCVar
local PlaySoundFile = PlaySoundFile
local ReloadUI = ReloadUI
local UIFrameFadeOut = UIFrameFadeOut
local ChatFrame_AddMessageGroup = ChatFrame_AddMessageGroup
local ChatFrame_RemoveAllMessageGroups = ChatFrame_RemoveAllMessageGroups
local ChatFrame_AddChannel = ChatFrame_AddChannel
local ChatFrame_RemoveChannel = ChatFrame_RemoveChannel
local ChangeChatColor = ChangeChatColor
local ToggleChatColorNamesByClassGroup = ToggleChatColorNamesByClassGroup
local FCF_ResetChatWindows = FCF_ResetChatWindows
local FCF_SetLocked = FCF_SetLocked
local FCF_DockFrame, FCF_UnDockFrame = FCF_DockFrame, FCF_UnDockFrame
local FCF_OpenNewWindow = FCF_OpenNewWindow
local FCF_SavePositionAndDimensions = FCF_SavePositionAndDimensions
local FCF_SetWindowName = FCF_SetWindowName
local FCF_StopDragging = FCF_StopDragging
local FCF_SetChatWindowFontSize = FCF_SetChatWindowFontSize
local CLASS, CONTINUE, PREVIOUS = CLASS, CONTINUE, PREVIOUS
local NUM_CHAT_WINDOWS = NUM_CHAT_WINDOWS
local LOOT, GENERAL, TRADE = LOOT, GENERAL, TRADE
local GUILD_EVENT_LOG = GUILD_EVENT_LOG
local RAID_CLASS_COLORS = RAID_CLASS_COLORS

local CURRENT_PAGE = 0
local MAX_PAGE = 8
local layoutTooltipState

local function HasClassPet()
	return E.myclass == "HUNTER" or E.myclass == "WARLOCK" or E.myclass == "DEATHKNIGHT"
end

local function ConfigureClassLayout(layout)
	local hasClassPet = HasClassPet()
	local units = E.db.unitframe.units

	units.pet.enable = hasClassPet
	units.pet.castbar.enable = hasClassPet
	units.pettarget.enable = hasClassPet
	E.db.actionbar.barPet.enabled = true

	if layout ~= "skulytheme" then
		E.db.movers.ElvUF_PlayerSwingBarMover = IsAddOnLoaded("ElvUI_RaidMarkers")
			and _G.ElvUI_RaidMarkersBar
			and "TOP,ElvUI_RaidMarkersBar,BOTTOM,0,-4"
			or "BOTTOM,ElvUIParent,BOTTOM,0,272"
	end

	if hasClassPet and layout ~= "minimal" then
		E.db.movers.ElvUF_PetMover = "BOTTOM,ElvUIParent,BOTTOM,-341,42"
		E.db.movers.ElvUF_PetCastbarMover = "BOTTOM,ElvUIParent,BOTTOM,-341,0"
		E.db.movers.ElvBar_Pet = "BOTTOMRIGHT,ElvUIParent,BOTTOMRIGHT,-4,282"
	end

	if layout ~= "minimal" and E.myclass == "DEATHKNIGHT" then
		E.db.movers.ClassBarMover = layout == "skulytheme"
			and "BOTTOM,ElvUIParent,BOTTOM,-293,355"
			or "BOTTOM,ElvUIParent,BOTTOM,-341,110"
	elseif layout ~= "minimal" and E.myclass == "DRUID" then
		E.db.movers.ClassBarMover = layout == "skulytheme"
			and "BOTTOM,ElvUIParent,BOTTOM,-293,355"
			or "BOTTOM,ElvUIParent,BOTTOM,-341,110"
	elseif layout ~= "minimal" and E.myclass == "SHAMAN" then
		E.db.movers.ElvBar_Totem = "BOTTOM,ElvUIParent,BOTTOM,0,55"
	end

	if layout == "pet" and hasClassPet then
		units.pet.width = 220
		units.pet.height = 52
		units.pet.health.frequentUpdates = true
		units.pettarget.width = 150
	end
end

local function ConfigureLayoutActionBars(layout)
	local layouts = {
		balanced = {main = {8, 44}, chatWidth = 472, buttons = 6, perRow = 3, buttonSize = 22, formation = "balanced"},
		tank = {main = {10, 36}, chatWidth = 448, buttons = 6, perRow = 3, buttonSize = 24, formation = "tank"},
		melee = {main = {12, 36}, chatWidth = 448, buttons = 6, perRow = 3, buttonSize = 22, formation = "melee"},
		dpsCaster = {main = {8, 44}, chatWidth = 440, buttons = 8, perRow = 4, buttonSize = 20, formation = "caster"},
		healer = {main = {8, 36}, chatWidth = 440, buttons = 6, perRow = 3, buttonSize = 22, formation = "healer"},
		raid10 = {main = {10, 32}, chatWidth = 448, buttons = 3, perRow = 3, buttonSize = 20, formation = "raid10"},
		raid25 = {main = {12, 30}, chatWidth = 440, buttons = 6, perRow = 2, buttonSize = 20, formation = "raid25"},
		arena = {main = {12, 32}, chatWidth = 472, buttons = 4, perRow = 2, buttonSize = 20, formation = "arena"},
		battleground = {main = {12, 28}, chatWidth = 440, buttons = 6, perRow = 3, buttonSize = 18, formation = "battleground"},
		dungeon = {main = {8, 40}, chatWidth = 448, buttons = 6, perRow = 3, buttonSize = 22, formation = "dungeon"},
		questing = {main = {10, 36}, chatWidth = 472, buttons = 6, perRow = 3, buttonSize = 22, formation = "questing"},
		pet = {main = {8, 40}, chatWidth = 448, buttons = 6, perRow = 3, buttonSize = 22, formation = "pet"},
		compact = {main = {12, 28}, chatWidth = 420, buttons = 3, perRow = 3, buttonSize = 18, formation = "compact"},
	}
	local config = layouts[layout]
	if not config then return end

	local maxChatWidth = math.max(320, math.floor((E.UIParent:GetWidth() - 360) / 2))
	E.db.chat.panelWidth = math.min(config.chatWidth, maxChatWidth)
	local centerWidth = E.UIParent:GetWidth() - (E.db.chat.panelWidth * 2)
	local usableWidth = math.max(120, centerWidth - 36)

	local mainBar = E.db.actionbar.bar1
	mainBar.enabled = true
	mainBar.buttons = config.main[1]
	mainBar.buttonsPerRow = config.main[1]
	mainBar.buttonspacing = 2
	mainBar.buttonsize = math.min(config.main[2], math.floor((usableWidth - mainBar.buttonspacing * (mainBar.buttonsPerRow - 1) - 12) / mainBar.buttonsPerRow))
	mainBar.visibility = ""
	E.db.movers.ElvAB_1 = "BOTTOM,ElvUIParent,BOTTOM,0,18"

	local formations = {
		balanced = {positions = {{-1, 0}, {0, 0}, {1, 0}, {-1, 1}, {0, 1}, {1, 1}, {-1, 2}, {0, 2}, {1, 2}}, rowStep = 52, startY = 72},
		tank = {positions = {{-0.8, 0}, {-1, 1}, {-0.8, 2}, {0, 0}, {0, 1}, {0, 2}, {0.8, 0}, {1, 1}, {0.8, 2}}, rowStep = 52, startY = 72},
		melee = {positions = {{0, 0}, {-1, 0}, {1, 0}, {-1, 1}, {0, 1}, {1, 1}, {-1, 2}, {0, 2}, {1, 2}}, rowStep = 52, startY = 72},
		caster = {positions = {{0, 0}, {-1, 0}, {1, 0}, {0, 1}, {-1, 1}, {1, 1}, {0, 2}, {-1, 2}, {1, 2}}, rowStep = 62, startY = 72},
		healer = {positions = {{-1, 0}, {1, 0}, {0, 1}, {-1, 1}, {1, 1}, {0, 0}, {-1, 2}, {1, 2}, {0, 2}}, rowStep = 52, startY = 72},
		raid10 = {positions = {{-1, 0}, {1, 0}, {-1, 1}, {1, 1}, {-1, 2}, {1, 2}, {-1, 3}, {1, 3}, {0, 0}}, rowStep = 32, startY = 55},
		raid25 = {positions = {{-1, 0}, {0, 0}, {1, 0}, {-0.7, 1}, {0.7, 1}, {0, 1}, {-1, 2}, {0, 2}, {1, 2}}, rowStep = 68, startY = 72},
		arena = {positions = {{0, 0}, {-1, 1}, {1, 1}, {-1, 2}, {0, 2}, {1, 2}, {-1, 3}, {1, 3}, {0, 4}}, rowStep = 46, startY = 55},
		battleground = {positions = {{-0.6, 0}, {0.6, 0}, {-1, 1}, {0, 1}, {1, 1}, {-0.6, 2}, {0.6, 2}, {-1, 0}, {1, 2}}, rowStep = 52, startY = 72},
		dungeon = {positions = {{-0.65, 0}, {0, 0}, {0.65, 0}, {-1, 1}, {0, 1}, {1, 1}, {-0.65, 2}, {0, 2}, {0.65, 2}}, rowStep = 52, startY = 72},
		questing = {positions = {{-1, 0}, {0, 0}, {1, 0}, {-0.7, 1}, {0.7, 1}, {0, 1}, {-1, 2}, {0, 2}, {1, 2}}, rowStep = 52, startY = 72},
		pet = {positions = {{0, 0}, {-0.7, 0}, {0.7, 0}, {-1, 1}, {0, 1}, {1, 1}, {-0.7, 2}, {0, 2}, {0.7, 2}}, rowStep = 52, startY = 72},
		compact = {positions = {{-0.75, 0}, {-0.75, 1}, {-0.75, 2}, {0, 0}, {0, 1}, {0, 2}, {0.75, 0}, {0.75, 1}, {0.75, 2}}, rowStep = 36, startY = 65},
	}
	local formation = formations[config.formation]
	local columnOffset = math.min(120, math.max(42, (usableWidth / 2) - 42))

	for index = 2, 10 do
		local bar = E.db.actionbar["bar"..index]
		if bar and (index <= 6 or IsAddOnLoaded("ElvUI_ExtraActionBars")) then
			local position = formation.positions[index - 1]
			local buttons = config.buttons
			local perRow = math.min(buttons, config.perRow)
			bar.buttonspacing = 2
			local buttonSize = math.min(config.buttonSize, math.floor((usableWidth - bar.buttonspacing * (perRow - 1) - 12) / perRow))
			bar.enabled = true
			bar.mouseover = false
			bar.alpha = 1
			bar.buttons = buttons
			bar.buttonsPerRow = perRow
			bar.point = "BOTTOMLEFT"
			bar.buttonsize = buttonSize
			bar.visibility = "[vehicleui] hide; show"
			E.db.movers["ElvAB_"..index] = "BOTTOM,ElvUIParent,BOTTOM,"..(position[1] * columnOffset)..","..(formation.startY + position[2] * formation.rowStep)
		end
	end
end

local function SetupChat(noDisplayMsg)
	FCF_ResetChatWindows() -- Monitor this
	FCF_SetLocked(ChatFrame1, 1)
	FCF_DockFrame(ChatFrame2)
	FCF_SetLocked(ChatFrame2, 1)

	FCF_OpenNewWindow(LOOT)
	FCF_UnDockFrame(ChatFrame3)
	FCF_SetLocked(ChatFrame3, 1)
	ChatFrame3:Show()

	for i = 1, NUM_CHAT_WINDOWS do
		local frame = _G[format("ChatFrame%s", i)]

		-- move general bottom left
		if i == 1 then
			frame:ClearAllPoints()
			frame:Point("BOTTOMLEFT", LeftChatToggleButton, "TOPLEFT", 1, 3)
		elseif i == 3 then
			frame:ClearAllPoints()
			frame:Point("BOTTOMLEFT", RightChatDataPanel, "TOPLEFT", 1, 3)
		end

		FCF_SavePositionAndDimensions(frame)
		FCF_StopDragging(frame)

		-- set default Elvui font size
		FCF_SetChatWindowFontSize(nil, frame, 12)

		-- rename windows general because moved to chat #3
		if i == 1 then
			FCF_SetWindowName(frame, GENERAL)
		elseif i == 2 then
			FCF_SetWindowName(frame, GUILD_EVENT_LOG)
		elseif i == 3 then
			FCF_SetWindowName(frame, LOOT.." / "..TRADE)
		end
	end

	local chatGroup = {"SYSTEM", "CHANNEL", "SAY", "EMOTE", "YELL", "WHISPER", "PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER", "RAID_WARNING", "BATTLEGROUND", "BATTLEGROUND_LEADER", "GUILD", "OFFICER", "MONSTER_SAY", "MONSTER_YELL", "MONSTER_EMOTE", "MONSTER_WHISPER", "MONSTER_BOSS_EMOTE", "MONSTER_BOSS_WHISPER", "ERRORS", "AFK", "DND", "IGNORED", "BG_HORDE", "BG_ALLIANCE", "BG_NEUTRAL", "ACHIEVEMENT", "GUILD_ACHIEVEMENT", "BN_WHISPER", "BN_CONVERSATION", "BN_INLINE_TOAST_ALERT"}
	ChatFrame_RemoveAllMessageGroups(ChatFrame1)
	for _, v in ipairs(chatGroup) do
		ChatFrame_AddMessageGroup(ChatFrame1, v)
	end

	chatGroup = {"COMBAT_XP_GAIN", "COMBAT_HONOR_GAIN", "COMBAT_FACTION_CHANGE", "SKILL", "LOOT", "MONEY"}
	ChatFrame_RemoveAllMessageGroups(ChatFrame3)
	for _, v in ipairs(chatGroup) do
		ChatFrame_AddMessageGroup(ChatFrame3, v)
	end

	ChatFrame_AddChannel(ChatFrame1, GENERAL)
	ChatFrame_RemoveChannel(ChatFrame1, TRADE)
	ChatFrame_AddChannel(ChatFrame3, TRADE)

	chatGroup = {"SAY", "EMOTE", "YELL", "WHISPER", "PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER", "RAID_WARNING", "BATTLEGROUND", "BATTLEGROUND_LEADER", "GUILD", "OFFICER", "ACHIEVEMENT", "GUILD_ACHIEVEMENT"}
	for i = 1, MAX_WOW_CHAT_CHANNELS do
		tinsert(chatGroup, "CHANNEL"..i)
	end
	for _, v in ipairs(chatGroup) do
		ToggleChatColorNamesByClassGroup(true, v)
	end

	-- Adjust Chat Colors
	ChangeChatColor("CHANNEL1", 195/255, 230/255, 232/255) -- General
	ChangeChatColor("CHANNEL2", 232/255, 158/255, 121/255) -- Trade
	ChangeChatColor("CHANNEL3", 232/255, 228/255, 121/255) -- Local Defense

	if E.Chat then
		E.Chat:PositionChat(true)
		if E.db.RightChatPanelFaded then
			RightChatToggleButton:Click()
		end

		if E.db.LeftChatPanelFaded then
			LeftChatToggleButton:Click()
		end
	end

	if InstallStepComplete and not noDisplayMsg then
		InstallStepComplete.message = L["Chat Set"]
		InstallStepComplete:Show()
	end
end

local function SetupCVars(noDisplayMsg)
	SetCVar("mapQuestDifficulty", 1)
	SetCVar("ShowClassColorInNameplate", 1)
	SetCVar("screenshotQuality", 10)
	SetCVar("chatMouseScroll", 1)
	SetCVar("chatStyle", "classic")
	SetCVar("WholeChatWindowClickable", 0)
	SetCVar("ConversationMode", "inline")
	SetCVar("showTutorials", 0)
	SetCVar("showNewbieTips", 0)
	SetCVar("showLootSpam", 1)
	SetCVar("UberTooltips", 1)
	SetCVar("threatWarning", 3)
	SetCVar("alwaysShowActionBars", 1)
	SetCVar("lockActionBars", 1)
	SetCVar("SpamFilter", 0)

	if InstallStepComplete and not noDisplayMsg then
		InstallStepComplete.message = L["CVars Set"]
		InstallStepComplete:Show()
	end
end

function E:GetColor(r, g, b, a)
	return {r = r, g = g, b = b, a = a}
end

function E:SetupTheme(theme, noDisplayMsg)
	E.private.theme = theme

	local classColor

	--Set colors
	if theme == "classic" then
		E.db.general.bordercolor = (E.PixelMode and E:GetColor(0, 0, 0) or E:GetColor(0.31, 0.31, 0.31))
		E.db.general.backdropcolor = E:GetColor(0.1, 0.1, 0.1)
		E.db.general.backdropfadecolor = E:GetColor(13/255, 13/255, 13/255, 0.69)
		E.db.unitframe.colors.borderColor = (E.PixelMode and E:GetColor(0, 0, 0) or E:GetColor(0.31, 0.31, 0.31))
		E.db.unitframe.colors.healthclass = false
		E.db.unitframe.colors.health = E:GetColor(0.31, 0.31, 0.31)
		E.db.unitframe.colors.auraBarBuff = E:GetColor(0.31, 0.31, 0.31)
		E.db.unitframe.colors.castColor = E:GetColor(0.31, 0.31, 0.31)
		E.db.unitframe.colors.castClassColor = false
	elseif theme == "class" then
		classColor = E.myclass == "PRIEST" and E.PriestColors or (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[E.myclass] or RAID_CLASS_COLORS[E.myclass])

		E.db.general.bordercolor = (E.PixelMode and E:GetColor(0, 0, 0) or E:GetColor(0.31, 0.31, 0.31))
		E.db.general.backdropcolor = E:GetColor(0.1, 0.1, 0.1)
		E.db.general.backdropfadecolor = E:GetColor(0.06, 0.06, 0.06, 0.8)
		E.db.unitframe.colors.borderColor = (E.PixelMode and E:GetColor(0, 0, 0) or E:GetColor(0.31, 0.31, 0.31))
		E.db.unitframe.colors.auraBarBuff = E:GetColor(classColor.r, classColor.g, classColor.b)
		E.db.unitframe.colors.healthclass = true
		E.db.unitframe.colors.castClassColor = true
	else
		E.db.general.bordercolor = (E.PixelMode and E:GetColor(0, 0, 0) or E:GetColor(0.1, 0.1, 0.1))
		E.db.general.backdropcolor = E:GetColor(0.1, 0.1, 0.1)
		E.db.general.backdropfadecolor = E:GetColor(0.054, 0.054, 0.054, 0.8)
		E.db.unitframe.colors.borderColor = (E.PixelMode and E:GetColor(0, 0, 0) or E:GetColor(0.1, 0.1, 0.1))
		E.db.unitframe.colors.auraBarBuff = E:GetColor(0.1, 0.1, 0.1)
		E.db.unitframe.colors.healthclass = false
		E.db.unitframe.colors.health = E:GetColor(0.1, 0.1, 0.1)
		E.db.unitframe.colors.castColor = E:GetColor(0.1, 0.1, 0.1)
		E.db.unitframe.colors.castClassColor = false
	end

	--Value Color
	if theme == "class" then
		E.db.general.valuecolor = E:GetColor(classColor.r, classColor.g, classColor.b)
	else
		E.db.general.valuecolor = E:GetColor(254/255, 123/255, 44/255)
	end

	E:UpdateAll(true)

	if InstallStepComplete and not noDisplayMsg then
		InstallStepComplete.message = L["Theme Set"]
		InstallStepComplete:Show()
	end
end

function E:SetupLayout(layout, noDataReset, noDisplayMsg)
	if not noDataReset then
		E.db.layoutSet = layout

		--Unitframes
		E:CopyTable(E.db.unitframe.units, P.unitframe.units)

		--Shared base layout, tweaks to individual layouts will be below
		E:ResetMovers("")
		if not E.db.movers then E.db.movers = {} end
		if not E.db.enhanced then E.db.enhanced = {} end
		if not E.db.enhanced.nameplates then E.db.enhanced.nameplates = {} end
		
		if not E.db.nameplates then E.db.nameplates = {} end
		if not E.db.nameplates.units then E.db.nameplates.units = {} end
		if not E.db.nameplates.units.ENEMY_NPC then E.db.nameplates.units.ENEMY_NPC = {} end
		if not E.db.nameplates.units.ENEMY_NPC.health then E.db.nameplates.units.ENEMY_NPC.health = {} end
		if not E.db.nameplates.units.ENEMY_NPC.health.text then E.db.nameplates.units.ENEMY_NPC.health.text = {} end
		if not E.db.nameplates.units.ENEMY_NPC.iconFrame then E.db.nameplates.units.ENEMY_NPC.iconFrame = {} end
		if not E.db.nameplates.units.ENEMY_NPC.questIcons then E.db.nameplates.units.ENEMY_NPC.questIcons = {} end
		if not E.db.nameplates.filters then E.db.nameplates.filters = {} end
		if not E.db.nameplates.filters.test then E.db.nameplates.filters.test = {} end
		if not E.db.nameplates.filters.test.triggers then E.db.nameplates.filters.test.triggers = {} end
		
		if not E.db.nameplates.filters.nme then E.db.nameplates.filters.nme = {} end
		if not E.db.nameplates.filters.nme.triggers then E.db.nameplates.filters.nme.triggers = {} end
		if not E.db.nameplates.filters.nme.triggers.nameplateType then E.db.nameplates.filters.nme.triggers.nameplateType = {} end
		if not E.db.nameplates.filters.nme.actions then E.db.nameplates.filters.nme.actions = {} end
		E.db.nameplates.filters.test.triggers.enable = false
		E.db.nameplates.filters.nme.triggers.enable = false
		E.db.nameplates.filters.nme.triggers.nameplateType.enable = false
		E.db.nameplates.filters.nme.triggers.notTarget = false
		E.db.nameplates.filters.nme.triggers.nameplateType.enemyNPC = false
		E.db.nameplates.filters.nme.triggers.healthThreshold = false
		
		local PZLoaded = IsAddOnLoaded("ElvUI_ProjectZidras")
		if PZLoaded then
			E.db.pz.wratharmory.enable = false
		end
		E.db.nameplates.filters.nme.actions.nameOnly = true
		E.db.general.afk = false
		E.db.actionbar.microbar.enabled = true
		E.db.movers.MicrobarMover = "TOPLEFT,ElvUIParent,TOPLEFT,4,-4"
		
		--ActionBars
		E.db.actionbar.backdropSpacingConverted = true
		E.db.actionbar.bar1.buttons = 8
		E.db.actionbar.bar1.buttonsize = 50
		E.db.actionbar.bar1.buttonspacing = 1
		E.db.actionbar.bar1.buttonsPerRow = P.actionbar.bar1.buttonsPerRow
		E.db.actionbar.bar1.visibility = ""
		E.db.actionbar.bar2.buttons = 9
		E.db.actionbar.bar2.buttonsPerRow = P.actionbar.bar2.buttonsPerRow
		E.db.actionbar.bar2.buttonsize = 38
		E.db.actionbar.bar2.buttonspacing = 1
		E.db.actionbar.bar2.enabled = true
		E.db.actionbar.bar2.visibility = ""
		E.db.actionbar.bar3.enabled = true
		E.db.actionbar.bar3.buttons = 8
		E.db.actionbar.bar3.buttonsize = 50
		E.db.actionbar.bar3.buttonspacing = 1
		E.db.actionbar.bar3.buttonsPerRow = 10
		E.db.actionbar.bar3.visibility = ""
		E.db.actionbar.bar4.enabled = false
		E.db.actionbar.bar4.visibility = "[vehicleui] hide; show"
		E.db.actionbar.bar5.enabled = false
		E.db.actionbar.bar5.visibility = "[vehicleui] hide; show"
		E.db.actionbar.bar6.enabled = false
		E.db.actionbar.bar6.visibility = "[vehicleui] hide; show"
		if IsAddOnLoaded("ElvUI_ExtraActionBars") then
			for i = 7, 10 do
				local bar = E.db.actionbar["bar"..i]
				if bar then
					bar.enabled = false
				end
			end
		end
		E.db.general.bottomPanel = P.general.bottomPanel
		E.db.nameplates.useTargetScale = P.nameplates.useTargetScale
		E.db.nameplates.targetScale = P.nameplates.targetScale
		E.db.nameplates.nonTargetTransparency = P.nameplates.nonTargetTransparency
		E.db.nameplates.lowHealthThreshold = P.nameplates.lowHealthThreshold
		E.db.nameplates.threat.goodScale = P.nameplates.threat.goodScale
		E.db.nameplates.threat.badScale = P.nameplates.threat.badScale
		E.db.nameplates.threat.useThreatColor = P.nameplates.threat.useThreatColor
		
		
		--Auras
		E.db.auras.buffs.countFontSize = 10
		E.db.auras.buffs.size = 40
		E.db.auras.debuffs.countFontSize = 10
		E.db.auras.debuffs.size = 40
		--Bags
		E.db.bags.bagSize = 42
		E.db.bags.bagWidth = 472
		E.db.bags.bankSize = 42
		E.db.bags.bankWidth = 472
		--Chat
		E.db.chat.fontSize = 10
		E.db.chat.panelColorConverted = true
		E.db.chat.separateSizes = false
		E.db.chat.panelHeight = 236
		E.db.chat.panelWidth = 472
		E.db.chat.tabFontSize = 12
		--DataBars
		E.db.databars.experience.height = 10
		E.db.databars.experience.orientation = "HORIZONTAL"
		E.db.databars.experience.textSize = 12
		E.db.databars.experience.width = 350
		E.db.databars.experience.questXP.enable = true
		E.db.databars.experience.questXP.questCurrentZoneOnly = true
		E.db.databars.experience.questXP.questCompletedOnly = false
		E.db.databars.reputation.enable = true
		E.db.databars.reputation.height = 10
		E.db.databars.reputation.orientation = "HORIZONTAL"
		E.db.databars.reputation.width = 222
		--General
		E.db.general.minimap.size = 220
		E.db.general.watchFrameHeight = 400
		E.db.general.totems.growthDirection = "HORIZONTAL"
		E.db.general.totems.size = 50
		E.db.general.totems.spacing = 8
		E.db.general.reminder.enable = false
		--Movers
		E.db.movers.AlertFrameMover = "TOP,ElvUIParent,TOP,-1,-18"
		E.db.movers.BNETMover = "TOPRIGHT,ElvUIParent,TOPRIGHT,-4,-274"
		E.db.movers.ElvAB_1 = "BOTTOM,ElvUIParent,BOTTOM,0,190"
		E.db.movers.ElvAB_2 = "BOTTOM,ElvUIParent,BOTTOM,0,4"
		E.db.movers.ElvAB_3 = "BOTTOM,ElvUIParent,BOTTOM,0,138"
		E.db.movers.ElvAB_5 = "BOTTOM,ElvUIParent,BOTTOM,-92,57"
		E.db.movers.ElvUF_FocusMover = "BOTTOM,ElvUIParent,BOTTOM,342,59"
		E.db.movers.ElvUF_PartyMover = "BOTTOMLEFT,ElvUIParent,BOTTOMLEFT,4,248"
		E.db.movers.ElvUF_PetMover = "BOTTOM,ElvUIParent,BOTTOM,-341,42"
		E.db.movers.ElvUF_PetCastbarMover = "BOTTOM,ElvUIParent,BOTTOM,-341,0"
		E.db.movers.ElvUF_PlayerCastbarMover = "BOTTOM,ElvUIParent,BOTTOM,0,96"
		E.db.movers.ElvUF_PlayerMover = "BOTTOM,ElvUIParent,BOTTOM,-341,138"
		E.db.movers.ElvUF_PlayerSwingBarMover = "BOTTOM,ElvUIParent,BOTTOM,0,272"
		E.db.movers.ElvUF_Raid40Mover = "TOPLEFT,ElvUIParent,BOTTOMLEFT,4,482"
		E.db.movers.ElvUF_RaidMover = "BOTTOMLEFT,ElvUIParent,BOTTOMLEFT,4,248"
		E.db.movers.ElvUF_RaidpetMover = "TOPLEFT,ElvUIParent,BOTTOMLEFT,4,737"
		E.db.movers.ElvUF_TargetCastbarMover = "BOTTOM,ElvUIParent,BOTTOM,0,242"
		E.db.movers.ElvUF_TargetMover = "BOTTOM,ElvUIParent,BOTTOM,342,138"
		E.db.movers.ElvUF_TargetTargetMover = "BOTTOM,ElvUIParent,BOTTOM,342,99"
		E.db.movers.ExperienceBarMover = "BOTTOM,ElvUIParent,BOTTOM,0,43"
		E.db.movers.LootFrameMover = "TOPLEFT,ElvUIParent,TOPLEFT,418,-186"
		E.db.movers.MirrorTimer1Mover = "TOP,ElvUIParent,TOP,-1,-96"
		E.db.movers.WatchFrameMover = "TOPRIGHT,ElvUIParent,TOPRIGHT,-163,-325"
		E.db.movers.ReputationBarMover = "TOPRIGHT,ElvUIParent,TOPRIGHT,-2,-245"
		E.db.movers.ShiftAB = "TOPLEFT,ElvUIParent,BOTTOMLEFT,4,769"
		E.db.movers.TempEnchantMover = "TOPRIGHT,ElvUIParent,TOPRIGHT,-4,-257"
		E.db.movers.TotemBarMover = "BOTTOMLEFT,ElvUIParent,BOTTOMLEFT,485,4"
		E.db.movers.ElvBar_Pet = "BOTTOMRIGHT,ElvUIParent,BOTTOMRIGHT,-4,282"
		E.db.movers.VehicleSeatMover = "TOPLEFT,ElvUIParent,TOPLEFT,4,-4"
		--Tooltip
		E.db.tooltip.fontSize = 10
		E.db.tooltip.healthBar.fontOutline = "MONOCHROMEOUTLINE"
		E.db.tooltip.healthBar.height = 12
		--UnitFrames
		E.db.unitframe.smoothbars = true
		E.db.unitframe.thinBorders = true
			--Player
		E.db.unitframe.units.player.aurabar.height = 26
		E.db.unitframe.units.player.buffs.perrow = 7
		E.db.unitframe.units.player.castbar.height = 40
		E.db.unitframe.units.player.castbar.insideInfoPanel = false
		E.db.unitframe.units.player.castbar.width = 407
		E.db.unitframe.units.player.classbar.height = 14
		E.db.unitframe.units.player.debuffs.perrow = 7
		E.db.unitframe.units.player.disableMouseoverGlow = true
		E.db.unitframe.units.player.health.attachTextTo = "InfoPanel"
		E.db.unitframe.units.player.height = 82
		E.db.unitframe.units.player.infoPanel.enable = true
		E.db.unitframe.units.player.power.attachTextTo = "InfoPanel"
		E.db.unitframe.units.player.power.height = 22
			--Target
		E.db.unitframe.units.target.aurabar.height = 26
		E.db.unitframe.units.target.buffs.anchorPoint = "TOPLEFT"
		E.db.unitframe.units.target.buffs.perrow = 7
		E.db.unitframe.units.target.castbar.height = 40
		E.db.unitframe.units.target.castbar.insideInfoPanel = false
		E.db.unitframe.units.target.castbar.width = 407
		E.db.unitframe.units.target.debuffs.anchorPoint = "TOPLEFT"
		E.db.unitframe.units.target.debuffs.attachTo = "FRAME"
		E.db.unitframe.units.target.debuffs.enable = false
		E.db.unitframe.units.target.debuffs.maxDuration = 0
		E.db.unitframe.units.target.debuffs.perrow = 7
		E.db.unitframe.units.target.disableMouseoverGlow = true
		E.db.unitframe.units.target.health.attachTextTo = "InfoPanel"
		E.db.unitframe.units.target.height = 82
		E.db.unitframe.units.target.infoPanel.enable = true
		E.db.unitframe.units.target.name.attachTextTo = "InfoPanel"
		E.db.unitframe.units.target.name.text_format = "[namecolor][name]"
		E.db.unitframe.units.target.orientation = "LEFT"
		E.db.unitframe.units.target.power.attachTextTo = "InfoPanel"
		E.db.unitframe.units.target.power.height = 22
			--TargetTarget
		E.db.unitframe.units.targettarget.debuffs.anchorPoint = "TOPRIGHT"
		E.db.unitframe.units.targettarget.debuffs.enable = false
		E.db.unitframe.units.targettarget.disableMouseoverGlow = true
		E.db.unitframe.units.targettarget.power.enable = false
		E.db.unitframe.units.targettarget.raidicon.attachTo = "LEFT"
		E.db.unitframe.units.targettarget.raidicon.enable = false
		E.db.unitframe.units.targettarget.raidicon.xOffset = 2
		E.db.unitframe.units.targettarget.raidicon.yOffset = 0
		E.db.unitframe.units.targettarget.threatStyle = "GLOW"
		E.db.unitframe.units.targettarget.width = 270
			--Focus
		E.db.unitframe.units.focus.castbar.width = 270
		E.db.unitframe.units.focus.width = 270
			--Pet
		E.db.unitframe.units.pet.castbar.iconSize = 32
		E.db.unitframe.units.pet.castbar.width = 270
		E.db.unitframe.units.pet.debuffs.anchorPoint = "TOPRIGHT"
		E.db.unitframe.units.pet.debuffs.enable = true
		E.db.unitframe.units.pet.disableTargetGlow = false
		E.db.unitframe.units.pet.infoPanel.height = 14
		E.db.unitframe.units.pet.portrait.camDistanceScale = 2
		E.db.unitframe.units.pet.width = 270
			--Boss
		E.db.unitframe.units.boss.buffs.maxDuration = 300
		E.db.unitframe.units.boss.buffs.sizeOverride = 27
		E.db.unitframe.units.boss.buffs.yOffset = 16
		E.db.unitframe.units.boss.castbar.width = 246
		E.db.unitframe.units.boss.debuffs.maxDuration = 300
		E.db.unitframe.units.boss.debuffs.numrows = 1
		E.db.unitframe.units.boss.debuffs.sizeOverride = 27
		E.db.unitframe.units.boss.debuffs.yOffset = -16
		E.db.unitframe.units.boss.height = 60
		E.db.unitframe.units.boss.infoPanel.height = 17
		E.db.unitframe.units.boss.portrait.camDistanceScale = 2
		E.db.unitframe.units.boss.portrait.width = 45
		E.db.unitframe.units.boss.width = 246
			--Party
		E.db.unitframe.units.party.height = 74
		E.db.unitframe.units.party.power.height = 13
		E.db.unitframe.units.party.rdebuffs.font = "PT Sans Narrow"
		E.db.unitframe.units.party.width = 231
			--Raid
		E.db.unitframe.units.raid.growthDirection = "RIGHT_UP"
		E.db.unitframe.units.raid.health.frequentUpdates = true
		E.db.unitframe.units.raid.infoPanel.enable = true
		E.db.unitframe.units.raid.name.attachTextTo = "InfoPanel"
		E.db.unitframe.units.raid.name.position = "BOTTOMLEFT"
		E.db.unitframe.units.raid.name.xOffset = 2
		E.db.unitframe.units.raid.numGroups = 8
		E.db.unitframe.units.raid.rdebuffs.font = "PT Sans Narrow"
		E.db.unitframe.units.raid.rdebuffs.size = 30
		E.db.unitframe.units.raid.rdebuffs.xOffset = 30
		E.db.unitframe.units.raid.rdebuffs.yOffset = 25
		E.db.unitframe.units.raid.resurrectIcon.attachTo = "BOTTOMRIGHT"
		E.db.unitframe.units.raid.visibility = "[@raid6,noexists] hide;show"
		E.db.unitframe.units.raid.width = 92
			--Raid40
		E.db.unitframe.units.raid40.enable = false
		E.db.unitframe.units.raid40.rdebuffs.font = "PT Sans Narrow"
		E.db.nameplates.filters.nme.triggers.enable = false
		
		local ExtrasLoaded = IsAddOnLoaded("ElvUI_Extras")
			if ExtrasLoaded then
				E.db.Extras.nameplates.QuestIcons.enabled = true
				E.db.Extras.nameplates.QuestIcons.showText = true
			end
		--[[
		--	Layout Tweaks will be handled below.
		--	These are changes that deviate from the shared base layout
		--]]

		if layout == "tank" then
			E.db.nameplates.useTargetScale = true
			E.db.nameplates.targetScale = 1.35
			E.db.nameplates.nonTargetTransparency = 0.65
			E.db.nameplates.lowHealthThreshold = 0.5
			E.db.nameplates.threat.useThreatColor = true
			E.db.nameplates.threat.goodScale = 0.9
			E.db.nameplates.threat.badScale = 1.35
			E.db.unitframe.units.player.health.frequentUpdates = true
			E.db.unitframe.units.target.health.frequentUpdates = true
			E.db.unitframe.units.player.height = 66
			E.db.unitframe.units.target.height = 66
			E.db.unitframe.units.player.aurabar.attachTo = "FRAME"
			E.db.unitframe.units.target.aurabar.attachTo = "FRAME"
			E.db.unitframe.units.player.threatStyle = "HEALTHBORDER"
			E.db.unitframe.units.target.threatStyle = "HEALTHBORDER"
			E.db.movers.ElvUF_PlayerMover = "BOTTOM,ElvUIParent,BOTTOM,-341,138"
			E.db.movers.ElvUF_TargetMover = "BOTTOM,ElvUIParent,BOTTOM,342,138"
		elseif layout == "melee" then
			E.db.movers.ElvUF_PlayerCastbarMover = "BOTTOM,ElvUIParent,BOTTOM,0,243"
			E.db.movers.ElvUF_TargetCastbarMover = "BOTTOM,ElvUIParent,BOTTOM,0,97"
			E.db.unitframe.units.player.aurabar.attachTo = "FRAME"
			E.db.unitframe.units.target.aurabar.attachTo = "FRAME"
			E.db.nameplates.useTargetScale = true
			E.db.nameplates.targetScale = 1.2
			E.db.movers.ElvUF_PlayerMover = "BOTTOM,ElvUIParent,BOTTOM,-341,138"
			E.db.movers.ElvUF_TargetMover = "BOTTOM,ElvUIParent,BOTTOM,342,138"
		elseif layout == "dpsCaster" then
			E.db.movers.ElvUF_PlayerCastbarMover = "BOTTOM,ElvUIParent,BOTTOM,0,243"
			E.db.movers.ElvUF_TargetCastbarMover = "BOTTOM,ElvUIParent,BOTTOM,0,97"
			E.db.unitframe.units.player.castbar.width = 407
			E.db.unitframe.units.target.castbar.width = 407
			E.db.unitframe.units.player.power.height = 26
			E.db.unitframe.units.target.power.height = 26
		elseif layout == "healer" then
			E.db.movers.ElvUF_PlayerCastbarMover = "BOTTOM,ElvUIParent,BOTTOM,0,243"
			E.db.movers.ElvUF_TargetCastbarMover = "BOTTOM,ElvUIParent,BOTTOM,0,97"
			E.db.movers.ElvUF_RaidMover = "BOTTOMLEFT,ElvUIParent,BOTTOMLEFT,202,373"
			E.db.movers.LootFrameMover = "TOPLEFT,ElvUIParent,TOPLEFT,250,-104"
			E.db.movers.ShiftAB = "TOPLEFT,ElvUIParent,BOTTOMLEFT,4,273"
			--E.db.unitframe.units.party.enable = false
			E.db.unitframe.units.party.health.frequentUpdates = true
			E.db.unitframe.units.raid.visibility = "[@raid6,noexists] hide;show"
			E.db.unitframe.units.raid40.health.frequentUpdates = true
			E.db.unitframe.units.party.width = 250
			E.db.unitframe.units.party.height = 82
			E.db.unitframe.units.party.debuffs.enable = true
			E.db.unitframe.units.party.buffs.enable = true
		elseif layout == "raid10" then
			E.db.unitframe.units.raid.enable = true
			E.db.unitframe.units.raid.visibility = "[@raid6,noexists] hide;show"
			E.db.unitframe.units.raid.numGroups = 2
			E.db.unitframe.units.raid.width = 88
			E.db.unitframe.units.raid.height = 40
			E.db.unitframe.units.raid40.enable = false
			E.db.movers.ElvUF_RaidMover = "BOTTOMLEFT,ElvUIParent,BOTTOMLEFT,4,248"
		elseif layout == "raid25" then
			E.db.unitframe.units.raid.enable = true
			E.db.unitframe.units.raid.visibility = "[@raid6,noexists] hide;[@raid26,exists] hide;show"
			E.db.unitframe.units.raid.numGroups = 5
			E.db.unitframe.units.raid.width = 80
			E.db.unitframe.units.raid.height = 36
			E.db.unitframe.units.raid40.enable = true
			E.db.unitframe.units.raid40.visibility = "[@raid26,noexists] hide;show"
			E.db.unitframe.units.raid40.numGroups = 8
			E.db.unitframe.units.raid40.width = 68
			E.db.unitframe.units.raid40.height = 30
			E.db.movers.ElvUF_RaidMover = "BOTTOMLEFT,ElvUIParent,BOTTOMLEFT,4,248"
			E.db.movers.ElvUF_Raid40Mover = "TOPLEFT,ElvUIParent,BOTTOMLEFT,4,482"
		elseif layout == "arena" then
			E.db.unitframe.units.arena.enable = true
			E.db.unitframe.units.arena.width = 246
			E.db.unitframe.units.arena.height = 47
			E.db.unitframe.units.arena.spacing = 18
			E.db.movers.ArenaHeaderMover = "TOPLEFT,ElvUIParent,TOPLEFT,20,-270"
			E.db.nameplates.useTargetScale = true
			E.db.nameplates.targetScale = 1.25
			E.db.nameplates.nonTargetTransparency = 0.4
		elseif layout == "battleground" then
			E.db.unitframe.units.raid.enable = true
			E.db.unitframe.units.raid.visibility = "[@raid6,noexists] hide;[@raid26,exists] hide;show"
			E.db.unitframe.units.raid.numGroups = 8
			E.db.unitframe.units.raid.width = 74
			E.db.unitframe.units.raid.height = 34
			E.db.unitframe.units.raid40.enable = true
			E.db.unitframe.units.raid40.visibility = "[@raid26,noexists] hide;show"
			E.db.unitframe.units.raid40.width = 64
			E.db.unitframe.units.raid40.height = 28
			E.db.movers.ElvUF_RaidMover = "BOTTOMLEFT,ElvUIParent,BOTTOMLEFT,4,248"
			E.db.movers.ElvUF_Raid40Mover = "TOPLEFT,ElvUIParent,BOTTOMLEFT,4,482"
			E.db.nameplates.useTargetScale = true
			E.db.nameplates.targetScale = 1.2
			E.db.nameplates.threat.useThreatColor = true
		elseif layout == "dungeon" then
			E.db.unitframe.units.party.enable = true
			E.db.unitframe.units.party.visibility = "[group:party] show;hide"
			E.db.unitframe.units.party.width = 220
			E.db.unitframe.units.party.height = 62
			E.db.unitframe.units.party.health.frequentUpdates = true
			E.db.unitframe.units.party.healPrediction.enable = true
			E.db.unitframe.units.party.buffs.enable = true
			E.db.unitframe.units.party.debuffs.enable = true
			E.db.unitframe.units.raid.enable = true
			E.db.unitframe.units.raid.visibility = "[group:raid] show;hide"
			E.db.unitframe.units.raid.numGroups = 8
			E.db.unitframe.units.raid.width = 74
			E.db.unitframe.units.raid.height = 34
			E.db.unitframe.units.raid40.enable = false
			E.db.movers.ElvUF_PartyMover = "BOTTOMLEFT,ElvUIParent,BOTTOMLEFT,4,248"
			E.db.movers.ElvUF_RaidMover = "BOTTOMLEFT,ElvUIParent,BOTTOMLEFT,-20,288"
		elseif layout == "questing" then
			E.db.nameplates.useTargetScale = true
			E.db.nameplates.targetScale = 1.25
			E.db.nameplates.nonTargetTransparency = 0.45
			E.db.unitframe.units.raid.width = 74
			E.db.unitframe.units.raid.height = 34
		elseif layout == "minimal" then
			E:ResetMovers("")
			if not E.db.movers then E.db.movers = {} end
			E:CopyTable(E.db.unitframe.units, P.unitframe.units)
			E:CopyTable(E.db.actionbar, P.actionbar)
			E.db.databars.experience.orientation = "VERTICAL"
			E.db.databars.experience.width = 10
			E.db.databars.experience.height = 235
			local chatTopOffset = E.UIParent:GetHeight() - E.db.chat.panelHeight
			E.db.movers.ExperienceBarMover = "TOPRIGHT,ElvUIParent,TOPRIGHT,-"..E.db.chat.panelWidth..",-"..chatTopOffset
			E.db.actionbar.bar4.enabled = true
			E.db.actionbar.bar4.buttons = 12
			E.db.actionbar.bar4.buttonsPerRow = 1
			E.db.actionbar.bar4.buttonsize = 18
			E.db.actionbar.bar4.buttonspacing = 1
			E.db.actionbar.bar4.backdropSpacing = 2
			E.db.movers.ElvAB_4 = "TOPLEFT,LeftChatPanel,TOPRIGHT,0,0"
			E.db.databars.reputation.width = 10
			E.db.databars.reputation.height = 180
			E.db.databars.reputation.orientation = "VERTICAL"
			E.db.movers.ReputationBarMover = "TOPLEFT,LeftChatPanel,TOPRIGHT,26,0"
			if IsAddOnLoaded("ElvUI_ExtraActionBars") then
				for i = 7, 10 do
					local bar = E.db.actionbar["bar"..i]
					if bar then
						bar.enabled = false
					end
				end
			end
			E.db.general.bottomPanel = P.general.bottomPanel
			E.db.general.minimap.size = P.general.minimap.size
			E.db.nameplates.nonTargetTransparency = P.nameplates.nonTargetTransparency
		elseif layout == "compact" then
			E.db.chat.panelHeight = 190
			E.db.chat.panelWidth = 400
			E.db.chat.fontSize = 9
			E.db.general.minimap.size = 190
			E.db.unitframe.units.player.width = 180
			E.db.unitframe.units.player.height = 68
			E.db.unitframe.units.target.width = 180
			E.db.unitframe.units.target.height = 68
			for i = 1, 3 do
				local bar = E.db.actionbar["bar"..i]
				bar.buttons = 12
				bar.buttonsPerRow = 12
				bar.buttonsize = 36
				bar.buttonspacing = 1
			end
		elseif layout == "skulytheme" then
			-- ============================================
			-- SKULYTHEME LAYOUT
			-- ============================================

			E.db.nameplates.filters.nme.triggers.enable = true
			E.db.nameplates.filters.nme.triggers.nameplateType.enable = true
			E.db.nameplates.filters.nme.triggers.nameplateType.enemyNPC = true
			E.db.nameplates.filters.nme.triggers.notTarget = true
			E.db.nameplates.filters.nme.triggers.healthThreshold = true
			E.db.nameplates.filters.nme.triggers.overHealthThreshold = 0.85
			
			E.db.nameplates.filters.nme.actions.nameOnly = true
			E.global.nameplates.filters.nme.actions.castBar = true
			
			-- DATABARS
			E.db.databars.reputation.enable = true
			E.db.databars.reputation.orientation = "HORIZONTAL"
			E.db.databars.reputation.height = 10
			E.db.databars.reputation.width = 222
			
			E.db.databars.experience.orientation = "VERTICAL"
			E.db.databars.experience.width = 10
			E.db.databars.experience.height = 235
			E.db.databars.experience.textSize = 12
			
			-- GENERAL
			E.db.currentTutorial = 1
			E.db.general.totems.growthDirection = "HORIZONTAL"
			E.db.general.totems.size = 30
			E.db.general.totems.spacing = 1
			E.db.general.valuecolor.r = 0
			E.db.general.valuecolor.g = 0.44
			E.db.general.valuecolor.b = 0.87
			E.db.general.watchFrameHeight = 400
			E.db.general.minimap.size = 220
			
			-- ENHANCED
			E.db.enhanced.nameplates.classCache = true
			E.db.enhanced.nameplates.titleCache = true
			
			-- BAGS
			E.db.bags.bagSize = 42
			E.db.bags.bankSize = 42
			E.db.bags.bankWidth = 472
			E.db.bags.bagWidth = 472
			
			-- HIDE TUTORIAL
			E.db.hideTutorial = 1
			
			-- CHAT
			E.db.chat.panelHeight = 236
			E.db.chat.panelColorConverted = true
			E.db.chat.fontSize = 10
			E.db.chat.panelWidth = 472
			
			-- UNITFRAME COLORS
			E.db.unitframe.smoothbars = true
			E.db.unitframe.colors.auraBarBuff.b = 0.87
			E.db.unitframe.colors.auraBarBuff.g = 0.44
			E.db.unitframe.colors.auraBarBuff.r = 0
			E.db.unitframe.colors.healthclass = true
			E.db.unitframe.colors.castClassColor = true
			E.db.unitframe.thinBorders = true
			
			-- UNITFRAME - PETTARGET
			E.db.unitframe.units.pettarget.health.frequentUpdates = true
			
			-- UNITFRAME - TARGETTARGETTARGET
			E.db.unitframe.units.targettargettarget.health.frequentUpdates = true
			
			-- UNITFRAME - TARGETTARGET
			E.db.unitframe.units.targettarget.debuffs.anchorPoint = "TOPRIGHT"
			E.db.unitframe.units.targettarget.debuffs.enable = false
			E.db.unitframe.units.targettarget.power.enable = false
			E.db.unitframe.units.targettarget.disableMouseoverGlow = true
			E.db.unitframe.units.targettarget.width = 126
			E.db.unitframe.units.targettarget.threatStyle = "GLOW"
			E.db.unitframe.units.targettarget.health.frequentUpdates = true
			E.db.unitframe.units.targettarget.height = 26
			E.db.unitframe.units.targettarget.raidicon.attachTo = "LEFT"
			E.db.unitframe.units.targettarget.raidicon.xOffset = 2
			E.db.unitframe.units.targettarget.raidicon.enable = false
			E.db.unitframe.units.targettarget.raidicon.yOffset = 0
			
			-- UNITFRAME - RAID
			E.db.unitframe.units.raid.rdebuffs.font = "PT Sans Narrow"
			E.db.unitframe.units.raid.rdebuffs.size = 30
			E.db.unitframe.units.raid.rdebuffs.xOffset = 30
			E.db.unitframe.units.raid.rdebuffs.yOffset = 25
			E.db.unitframe.units.raid.growthDirection = "RIGHT_UP"
			E.db.unitframe.units.raid.resurrectIcon.attachTo = "BOTTOMRIGHT"
			E.db.unitframe.units.raid.numGroups = 8
			E.db.unitframe.units.raid.health.frequentUpdates = true
			E.db.unitframe.units.raid.width = 92
			E.db.unitframe.units.raid.infoPanel.enable = true
			E.db.unitframe.units.raid.name.attachTextTo = "InfoPanel"
			E.db.unitframe.units.raid.name.xOffset = 2
			E.db.unitframe.units.raid.name.position = "BOTTOMLEFT"
			E.db.unitframe.units.raid.visibility = "[@raid6,noexists] hide;show"
			
			-- UNITFRAME - FOCUSTARGET
			E.db.unitframe.units.focustarget.health.frequentUpdates = true
			
			-- UNITFRAME - PET
			E.db.unitframe.units.pet.debuffs.anchorPoint = "TOPRIGHT"
			E.db.unitframe.units.pet.debuffs.enable = true
			E.db.unitframe.units.pet.portrait.camDistanceScale = 2
			E.db.unitframe.units.pet.castbar.iconSize = 32
			E.db.unitframe.units.pet.castbar.width = 196
			E.db.unitframe.units.pet.width = 196
			E.db.unitframe.units.pet.infoPanel.height = 14
			E.db.unitframe.units.pet.disableTargetGlow = false
			E.db.unitframe.units.pet.height = 52
			E.db.unitframe.units.pet.health.frequentUpdates = true
			
			-- UNITFRAME - PLAYER
			E.db.unitframe.units.player.debuffs.perrow = 7
			E.db.unitframe.units.player.classbar.height = 14
			E.db.unitframe.units.player.aurabar.height = 26
			E.db.unitframe.units.player.power.position = "CENTER"
			E.db.unitframe.units.player.power.attachTextTo = "Power"
			E.db.unitframe.units.player.power.height = 17
			E.db.unitframe.units.player.power.xOffset = 0
			E.db.unitframe.units.player.power.text_format = "[powercolor][power:current-max]"
			E.db.unitframe.units.player.power.yOffset = 0
			E.db.unitframe.units.player.disableMouseoverGlow = true
			E.db.unitframe.units.player.width = 202
			E.db.unitframe.units.player.infoPanel.enable = false
			E.db.unitframe.units.player.health.attachTextTo = "Health"
			E.db.unitframe.units.player.health.frequentUpdates = true
			E.db.unitframe.units.player.health.position = "CENTER"
			E.db.unitframe.units.player.health.xOffset = 0
			E.db.unitframe.units.player.health.text_format = "[healthcolor][health:current-max]"
			E.db.unitframe.units.player.health.yOffset = 0
			E.db.unitframe.units.player.castbar.insideInfoPanel = false
			E.db.unitframe.units.player.castbar.height = 40
			E.db.unitframe.units.player.castbar.width = 202
			E.db.unitframe.units.player.height = 56
			E.db.unitframe.units.player.buffs.anchorPoint = "LEFT"
			E.db.unitframe.units.player.buffs.sizeOverride = 25
			E.db.unitframe.units.player.buffs.enable = true
			E.db.unitframe.units.player.buffs.numrows = 4
			E.db.unitframe.units.player.buffs.perrow = 7
			E.db.unitframe.units.player.CombatIcon.anchorPoint = "TOPRIGHT"
			
			
			-- UNITFRAME - RAID40
			E.db.unitframe.units.raid40.enable = false
			E.db.unitframe.units.raid40.rdebuffs.font = "PT Sans Narrow"
			
			-- UNITFRAME - FOCUS
			E.db.unitframe.units.focus.width = 150
			E.db.unitframe.units.focus.castbar.width = 150
			E.db.unitframe.units.focus.health.frequentUpdates = true
			
			-- UNITFRAME - TARGET
			E.db.unitframe.units.target.debuffs.attachTo = "FRAME"
			E.db.unitframe.units.target.debuffs.enable = false
			E.db.unitframe.units.target.debuffs.maxDuration = 0
			E.db.unitframe.units.target.debuffs.anchorPoint = "TOPLEFT"
			E.db.unitframe.units.target.debuffs.perrow = 7
			E.db.unitframe.units.target.aurabar.height = 26
			E.db.unitframe.units.target.castbar.height = 40
			E.db.unitframe.units.target.castbar.width = 196
			E.db.unitframe.units.target.castbar.insideInfoPanel = false
			E.db.unitframe.units.target.power.attachTextTo = "Power"
			E.db.unitframe.units.target.power.position = "CENTER"
			E.db.unitframe.units.target.power.height = 12
			E.db.unitframe.units.target.power.xOffset = 0
			E.db.unitframe.units.target.power.yOffset = 0
			E.db.unitframe.units.target.disableMouseoverGlow = true
			E.db.unitframe.units.target.width = 196
			E.db.unitframe.units.target.infoPanel.enable = true
			E.db.unitframe.units.target.height = 52
			E.db.unitframe.units.target.name.attachTextTo = "InfoPanel"
			E.db.unitframe.units.target.name.text_format = "[namecolor][name]"
			E.db.unitframe.units.target.orientation = "LEFT"
			E.db.unitframe.units.target.buffs.anchorPoint = "TOPLEFT"
			E.db.unitframe.units.target.buffs.perrow = 7
			E.db.unitframe.units.target.health.attachTextTo = "Health"
			E.db.unitframe.units.target.health.position = "CENTER"
			E.db.unitframe.units.target.health.frequentUpdates = true

			-- UNITFRAME - ARENA
			E.db.unitframe.units.arena.health.frequentUpdates = true
			
			-- UNITFRAME - PARTY
			E.db.unitframe.units.party.debuffs.enable = true
			E.db.unitframe.units.party.debuffs.numrows = 3
			E.db.unitframe.units.party.debuffs.sizeOverride = 14
			E.db.unitframe.units.party.debuffs.perrow = 6
			E.db.unitframe.units.party.debuffs.yOffset = 16
			E.db.unitframe.units.party.debuffs.anchorPoint = "LEFT"
			E.db.unitframe.units.party.buffs.enable = true
			E.db.unitframe.units.party.buffs.numrows = 3
			E.db.unitframe.units.party.buffs.sizeOverride = 14
			E.db.unitframe.units.party.buffs.perrow = 6
			E.db.unitframe.units.party.buffs.yOffset = 16
			E.db.unitframe.units.party.buffs.anchorPoint = "RIGHT"
			
			E.db.unitframe.units.party.rdebuffs.font = "PT Sans Narrow"
			E.db.unitframe.units.party.power.height = 13
			E.db.unitframe.units.party.width = 160
			E.db.unitframe.units.party.height = 43
			
			-- UNITFRAME - BOSS
			E.db.unitframe.units.boss.debuffs.numrows = 1
			E.db.unitframe.units.boss.debuffs.sizeOverride = 27
			E.db.unitframe.units.boss.debuffs.maxDuration = 300
			E.db.unitframe.units.boss.debuffs.yOffset = -16
			E.db.unitframe.units.boss.portrait.camDistanceScale = 2
			E.db.unitframe.units.boss.portrait.width = 45
			E.db.unitframe.units.boss.castbar.width = 246
			E.db.unitframe.units.boss.width = 246
			E.db.unitframe.units.boss.infoPanel.height = 17
			E.db.unitframe.units.boss.health.frequentUpdates = true
			E.db.unitframe.units.boss.height = 60
			E.db.unitframe.units.boss.buffs.maxDuration = 300
			E.db.unitframe.units.boss.buffs.sizeOverride = 27
			E.db.unitframe.units.boss.buffs.yOffset = 16
			
			-- NAMEPLATES
			E.db.nameplates.units.FRIENDLY_PLAYER.level.enable = true
			E.db.nameplates.units.ENEMY_NPC.health.text.enable = true
			E.db.nameplates.units.ENEMY_NPC.iconFrame.enable = true
			E.db.nameplates.units.ENEMY_NPC.questIcons.enable = true
			E.db.nameplates.units.ENEMY_NPC.questIcons.yOffset = 5
			E.db.nameplates.units.ENEMY_NPC.questIcons.size = 15
			E.db.nameplates.units.ENEMY_NPC.questIcons.spacing = 1
			E.db.nameplates.units.TARGET.glowStyle = "style1"
			E.db.nameplates.questIcons.enable = true
			E.db.nameplates.loadDistance = 200
			
			
			-- ACTIONBARS
			local raidmarkersbarBarsLoaded = IsAddOnLoaded("ElvUI_ExtraActionBars")
			if raidmarkersbarBarsLoaded then 
				E.db.actionbar.raidmarkersbar.visible = "HIDE"
			end
			E.db.actionbar.bar1.enabled = true	
			E.db.actionbar.bar1.backdropSpacing = 0
			E.db.actionbar.bar1.buttons = 12
			E.db.actionbar.bar1.point = "BOTTOMLEFT"
			E.db.actionbar.bar1.buttonsPerRow = 12
			E.db.actionbar.bar1.buttonspacing = -1
			E.db.actionbar.bar1.visibility = ""
			E.db.actionbar.bar1.buttonsize = 25
			
			for i = 2, 6 do
				local bar = E.db.actionbar["bar"..i]
				bar.enabled = true
				bar.backdropSpacing = 0
				bar.buttons = 12
				bar.point = "BOTTOMLEFT"
				bar.buttonsize = 25
				bar.buttonspacing = -1
				bar.buttonsPerRow = 12
				bar.visibility = "[vehicleui] hide; show"
			end
			
			local ExtraActionBarsLoaded = IsAddOnLoaded("ElvUI_ExtraActionBars")
			
			if ExtraActionBarsLoaded then
			for i = 7, 10 do
				local bar = E.db.actionbar["bar"..i]
				if bar then
					bar.enabled = true
					bar.backdropSpacing = 0
					bar.buttons = 12
					bar.point = "BOTTOMLEFT"
					bar.buttonsize = 25
					bar.buttonspacing = -1
					bar.buttonsPerRow = 12
					bar.visibility = "[vehicleui] hide; show"
				end
			end
			
			
			E.db.movers.ElvAB_7 = "BOTTOM,ElvUIParent,BOTTOM,0,76"
			E.db.movers.ElvAB_8 = "BOTTOM,ElvUIParent,BOTTOM,0,52"
			E.db.movers.ElvAB_9 = "BOTTOM,ElvUIParent,BOTTOM,0,28"
			E.db.movers.ElvAB_10 = "BOTTOM,ElvUIParent,BOTTOM,0,4"	
			end
			
			E.db.actionbar.barTotem.buttonsize = 26
			E.db.actionbar.backdropSpacingConverted = true
			
			-- LAYOUT SET
			E.db.layoutSet = "skulytheme"
			
			-- TOOLTIP
			E.db.tooltip.fontSize = 10
			E.db.tooltip.healthBar.height = 12
			E.db.tooltip.healthBar.fontOutline = "MONOCHROMEOUTLINE"
			
			-- AURAS
			E.db.auras.debuffs.countFontSize = 10
			E.db.auras.debuffs.size = 40
			E.db.auras.buffs.countFontSize = 10
			E.db.auras.buffs.size = 40
			
			-- MOVERS (All positions from your profile)
			E.db.movers.ElvUF_PlayerCastbarMover = "BOTTOM,ElvUIParent,BOTTOM,0,355"
			E.db.movers.ElvUF_RaidMover = "BOTTOMLEFT,ElvUIParent,BOTTOMLEFT,4,0"
			E.db.movers.LootFrameMover = "TOPLEFT,ElvUIParent,TOPLEFT,418,-186"
			E.db.movers.ElvUF_RaidpetMover = "TOPLEFT,ElvUIParent,BOTTOMLEFT,4,736"
			E.db.movers.ElvUF_PlayerSwingBarMover = "BOTTOM,ElvUIParent,BOTTOM,0,272"
			E.db.movers.ElvUF_FocusMover = "BOTTOMRIGHT,ElvUIParent,BOTTOMRIGHT,-508,50"
			E.db.movers.ElvBar_Totem = "BOTTOM,ElvUIParent,BOTTOM,0,243"
			E.db.movers.VehicleSeatMover = "TOPLEFT,ElvUIParent,TOPLEFT,4,-4"
			E.db.movers.ExperienceBarMover = "BOTTOMRIGHT,ElvUIParent,BOTTOMRIGHT,-476,4"
			E.db.movers.ElvUF_TargetMover = "BOTTOM,ElvUIParent,BOTTOM,304,406"
			E.db.movers.ElvBar_Pet = "BOTTOMRIGHT,ElvUIParent,BOTTOMRIGHT,-4,282"
			E.db.movers.ElvUF_Raid40Mover = "TOPLEFT,ElvUIParent,BOTTOMLEFT,4,432"
			E.db.movers.MirrorTimer1Mover = "TOP,ElvUIParent,TOP,-1,-96"
			E.db.movers.ElvAB_1 = "BOTTOM,ElvUIParent,BOTTOM,0,219"
			E.db.movers.ElvAB_2 = "BOTTOM,ElvUIParent,BOTTOM,0,195"
			E.db.movers.ElvAB_4 = "BOTTOM,ElvUIParent,BOTTOM,0,148"
			E.db.movers.ElvAB_3 = "BOTTOM,ElvUIParent,BOTTOM,0,171"
			E.db.movers.ReputationBarMover = "TOPRIGHT,ElvUIParent,TOPRIGHT,-2,-245"
			E.db.movers.TempEnchantMover = "TOPRIGHT,ElvUIParent,TOPRIGHT,-4,-257"
			E.db.movers.BNETMover = "TOPRIGHT,ElvUIParent,TOPRIGHT,-4,-274"
			E.db.movers.ShiftAB = "TOPLEFT,ElvUIParent,BOTTOMLEFT,4,1076"
			E.db.movers.ElvAB_5 = "BOTTOM,ElvUIParent,BOTTOM,0,124"
			E.db.movers.WatchFrameMover = "TOPRIGHT,ElvUIParent,TOPRIGHT,-163,-325"
			E.db.movers.ElvAB_6 = "BOTTOM,ElvUIParent,BOTTOM,0,100"
			E.db.movers.ElvUF_PlayerMover = "BOTTOM,ElvUIParent,BOTTOM,-293,403"
			E.db.movers.ElvUF_PetMover = "BOTTOMRIGHT,ElvUIParent,BOTTOMRIGHT,-399,299"
			E.db.movers.ElvUF_PetCastbarMover = "BOTTOMRIGHT,ElvUIParent,BOTTOMRIGHT,-399,245"
			E.db.movers.TotemBarMover = "BOTTOMLEFT,ElvUIParent,BOTTOMLEFT,431,248"
			
			E.db.movers.ElvUF_PartyMover = "BOTTOMLEFT,ElvUIParent,BOTTOMLEFT,568,4"
			E.db.movers.AlertFrameMover = "TOP,ElvUIParent,TOP,-1,-18"
			E.db.movers.ElvUF_TargetTargetMover = "BOTTOMRIGHT,ElvUIParent,BOTTOMRIGHT,-410,444"
			E.db.movers.ElvUF_TargetCastbarMover = "BOTTOM,ElvUIParent,BOTTOM,0,424"
			E.db.movers.ShiftAB = "TOPLEFT,ElvUIParent,BOTTOMLEFT,11,1015"

			local NP = E:GetModule("NamePlates")
			if NP and NP.StyleFilterConfigure then
				NP:StyleFilterConfigure()
				NP:ForEachPlate("StyleFilterClear")
			end
		end

		ConfigureClassLayout(layout)

		if layout ~= "skulytheme" and layout ~= "minimal" then
			ConfigureLayoutActionBars(layout)

			local frameWidth, castWidth, frameYOffset = 270, 270, 8

			if layout == "tank" then
				frameWidth, castWidth, frameYOffset = 270, 300, 4
				E.db.unitframe.units.player.height = 66
				E.db.unitframe.units.target.height = 66
			elseif layout == "melee" then
				frameWidth, castWidth, frameYOffset = 270, 280, 8
			elseif layout == "dpsCaster" then
				frameYOffset = 12
				castWidth = 407
			elseif layout == "healer" then
				frameYOffset = 12
				castWidth = 407
				E.db.movers.ElvUF_RaidMover = "BOTTOMLEFT,ElvUIParent,BOTTOMLEFT,260,300"
			elseif layout == "raid10" then
				frameWidth, castWidth = 250, 300
			elseif layout == "raid25" then
				frameWidth, castWidth = 240, 280
			elseif layout == "arena" then
				frameWidth, castWidth = 250, 280
			elseif layout == "battleground" then
				frameWidth, castWidth = 240, 260
			elseif layout == "dungeon" then
				frameWidth, castWidth = 280, 300
			elseif layout == "questing" then
				frameWidth, castWidth = 250, 270
			elseif layout == "pet" then
				frameWidth, castWidth = 260, 280
			elseif layout == "compact" then
				frameWidth, castWidth = 180, 180
				frameYOffset = 8
			end

			local frameY = math.max(0, E.db.chat.panelHeight - E.db.unitframe.units.player.height + frameYOffset)
			local maxFrameWidth = math.max(120, math.floor((E.UIParent:GetWidth() - (E.db.chat.panelWidth * 2) - 48) / 2))
			frameWidth = math.min(frameWidth, maxFrameWidth)
			castWidth = math.min(castWidth, frameWidth)
			E.db.unitframe.units.focus.width = 150
			E.db.unitframe.units.focus.castbar.width = 150
			E.db.unitframe.units.player.width = frameWidth
			E.db.unitframe.units.target.width = frameWidth
			E.db.unitframe.units.player.castbar.width = castWidth
			E.db.unitframe.units.target.castbar.width = castWidth
			local sideOffset = E.db.chat.panelWidth + 18
			E.db.movers.ElvUF_PlayerMover = "BOTTOMLEFT,ElvUIParent,BOTTOMLEFT,"..sideOffset..","..frameY
			E.db.movers.ElvUF_TargetMover = "BOTTOMRIGHT,ElvUIParent,BOTTOMRIGHT,-"..sideOffset..","..frameY
			E.db.movers.ElvUF_PlayerCastbarMover = "BOTTOM,ElvUIParent,BOTTOM,0,355"
			E.db.movers.ElvUF_TargetCastbarMover = "BOTTOM,ElvUIParent,BOTTOM,0,424"
			E.db.movers.ElvUF_TargetTargetMover = "BOTTOMRIGHT,ElvUIParent,BOTTOMRIGHT,-"..sideOffset..","..(frameY - 80)
			E.db.movers.ElvUF_FocusMover = "BOTTOMRIGHT,ElvUIParent,BOTTOMRIGHT,-508,50"

			if HasClassPet() then
				E.db.movers.ElvUF_PetMover = "TOPLEFT,ElvUF_Player,BOTTOMLEFT,0,-8"
				E.db.movers.ElvUF_PetCastbarMover = "BOTTOMLEFT,ElvUIParent,BOTTOMLEFT,"..sideOffset..",0"
				if layout == "pet" then
					E.db.unitframe.units.pet.castbar.width = E.db.unitframe.units.pet.width
				end
			end

			if E.myclass == "DEATHKNIGHT" or E.myclass == "DRUID" then
				E.db.movers.ClassBarMover = "BOTTOMLEFT,ElvUIParent,BOTTOMLEFT,"..sideOffset..","..(frameY - 24)
			end
		end

		if layout ~= "skulytheme" and layout ~= "minimal" then
			E.db.databars.experience.width = 10
			E.db.databars.experience.height = 180
			E.db.databars.experience.orientation = "VERTICAL"
			local chatTopOffset = E.UIParent:GetHeight() - E.db.chat.panelHeight
			E.db.movers.ExperienceBarMover = "TOPRIGHT,ElvUIParent,TOPRIGHT,-"..E.db.chat.panelWidth..",-"..chatTopOffset
		end
		
	end

	E:UpdateAll(true)

	if InstallStepComplete and not noDisplayMsg then
		InstallStepComplete.message = L["Layout Set"]
		InstallStepComplete:Show()
	end
end

local function SetupAuras(style, noDisplayMsg)
	local frame = UF.player
	E:CopyTable(E.db.unitframe.units.player.buffs, P.unitframe.units.player.buffs)
	E:CopyTable(E.db.unitframe.units.player.debuffs, P.unitframe.units.player.debuffs)
	E:CopyTable(E.db.unitframe.units.player.aurabar, P.unitframe.units.player.aurabar)
	if frame then
		UF:Configure_Auras(frame, "Buffs")
		UF:Configure_Auras(frame, "Debuffs")
		UF:Configure_AuraBars(frame)
	end

	frame = UF.target
	E:CopyTable(E.db.unitframe.units.target.buffs, P.unitframe.units.target.buffs)
	E:CopyTable(E.db.unitframe.units.target.debuffs, P.unitframe.units.target.debuffs)
	E:CopyTable(E.db.unitframe.units.target.aurabar, P.unitframe.units.target.aurabar)
	if frame then
		UF:Configure_Auras(frame, "Buffs")
		UF:Configure_Auras(frame, "Debuffs")
		UF:Configure_AuraBars(frame)
	end

	frame = UF.focus
	E:CopyTable(E.db.unitframe.units.focus.buffs, P.unitframe.units.focus.buffs)
	E:CopyTable(E.db.unitframe.units.focus.debuffs, P.unitframe.units.focus.debuffs)
	E:CopyTable(E.db.unitframe.units.focus.aurabar, P.unitframe.units.focus.aurabar)
	if frame then
		UF:Configure_Auras(frame, "Buffs")
		UF:Configure_Auras(frame, "Debuffs")
		UF:Configure_AuraBars(frame)
	end

	if not style then
		--PLAYER
		E.db.unitframe.units.player.buffs.enable = true
		E.db.unitframe.units.player.buffs.attachTo = "FRAME"
		E.db.unitframe.units.player.debuffs.attachTo = "BUFFS"
		E.db.unitframe.units.player.aurabar.enable = false
		if E.private.unitframe.enable then
			UF:CreateAndUpdateUF("player")
		end

		--TARGET
		E.db.unitframe.units.target.debuffs.enable = true
		E.db.unitframe.units.target.aurabar.enable = false
		if E.private.unitframe.enable then
			UF:CreateAndUpdateUF("target")
		end
	end

	if InstallStepComplete and not noDisplayMsg then
		InstallStepComplete.message = L["Auras Set"]
		InstallStepComplete:Show()
	end
end

local function InstallComplete()
	E.private.install_complete = E.version

	ReloadUI()
end

local function ResetAll()
	InstallNextButton:Disable()
	InstallPrevButton:Disable()
	InstallOption1Button:Hide()
	InstallOption1Button:SetScript("OnClick", nil)
	InstallOption1Button:SetText("")
	InstallOption2Button:Hide()
	InstallOption2Button:SetScript("OnClick", nil)
	InstallOption2Button:SetText("")
	InstallOption3Button:Hide()
	InstallOption3Button:SetScript("OnClick", nil)
	InstallOption3Button:SetText("")
	InstallOption4Button:Hide()
	InstallOption4Button:SetScript("OnClick", nil)
	InstallOption4Button:SetText("")
	InstallSlider:Hide()
	InstallSlider.Min:SetText("")
	InstallSlider.Max:SetText("")
	InstallSlider.Cur:SetText("")
	if ElvUIInstallFrame.LayoutCards then
		for _, card in ipairs(ElvUIInstallFrame.LayoutCards) do
			card:Hide()
		end
	end
	ElvUIInstallFrame.SubTitle:SetText("")
	ElvUIInstallFrame.Desc1:SetText("")
	ElvUIInstallFrame.Desc2:SetText("")
	ElvUIInstallFrame.Desc3:SetText("")
	ElvUIInstallFrame:Size(550, 400)
end

local function SetPage(PageNum)
	CURRENT_PAGE = PageNum
	ResetAll()

	InstallStatus.anim.progress:SetChange(PageNum)
	InstallStatus.anim.progress:Play()
	InstallStatus.text:SetText(CURRENT_PAGE.." / "..MAX_PAGE)

	local r, g, b = E:ColorGradient(CURRENT_PAGE / MAX_PAGE, 1, 0, 0, 1, 1, 0, 0, 1, 0)
	ElvUIInstallFrame.Status:SetStatusBarColor(r, g, b)

	if PageNum == MAX_PAGE then
		InstallNextButton:Disable()
	else
		InstallNextButton:Enable()
	end

	if PageNum == 1 then
		InstallPrevButton:Disable()
	else
		InstallPrevButton:Enable()
	end

	local f = ElvUIInstallFrame
	if PageNum == 1 then
		f.SubTitle:SetFormattedText(L["Welcome to ElvUI version %s!"], E.version)
		f.Desc1:SetText(L["This install process will help you learn some of the features in ElvUI has to offer and also prepare your user interface for usage."])
		f.Desc2:SetText(L["The in-game configuration menu can be accessed by typing the /ec command or by clicking the 'C' button on the minimap. Press the button below if you wish to skip the installation process."])
		f.Desc3:SetText(L["Please press the continue button to go onto the next step."])
		InstallOption1Button:Show()
		InstallOption1Button:SetScript("OnClick", InstallComplete)
		InstallOption1Button:SetText(L["Skip Process"])
	elseif PageNum == 2 then
		f.SubTitle:SetText(L["CVars"])
		f.Desc1:SetText(L["This part of the installation process sets up your World of Warcraft default options it is recommended you should do this step for everything to behave properly."])
		f.Desc2:SetText(L["Please click the button below to setup your CVars."])
		f.Desc3:SetText(L["Importance: |cff07D400High|r"])
		InstallOption1Button:Show()
		InstallOption1Button:SetScript("OnClick", function() SetupCVars() end)
		InstallOption1Button:SetText(L["Setup CVars"])
	elseif PageNum == 3 then
		f.SubTitle:SetText(L["Chat"])
		f.Desc1:SetText(L["This part of the installation process sets up your chat windows names, positions and colors."])
		f.Desc2:SetText(L["The chat windows function the same as Blizzard standard chat windows, you can right click the tabs and drag them around, rename, etc. Please click the button below to setup your chat windows."])
		f.Desc3:SetText(L["Importance: |cffD3CF00Medium|r"])
		InstallOption1Button:Show()
		InstallOption1Button:SetScript("OnClick", function() SetupChat() end)
		InstallOption1Button:SetText(L["Setup Chat"])
	elseif PageNum == 4 then
		f.SubTitle:SetText(L["Theme Setup"])
		f.Desc1:SetText(L["Choose a theme layout you wish to use for your initial setup."])
		f.Desc2:SetText(L["You can always change fonts and colors of any element of ElvUI from the in-game configuration."])
		f.Desc3:SetText(L["Importance: |cffFF0000Low|r"])
		InstallOption1Button:Show()
		InstallOption1Button:SetScript("OnClick", function() E:SetupTheme("classic") end)
		InstallOption1Button:SetText(L["Classic"])
		InstallOption2Button:Show()
		InstallOption2Button:SetScript("OnClick", function() E:SetupTheme("default") end)
		InstallOption2Button:SetText(L["Dark"])
		InstallOption3Button:Show()
		InstallOption3Button:SetScript("OnClick", function() E:SetupTheme("class") end)
		InstallOption3Button:SetText(CLASS)
	elseif PageNum == 5 then
		f.SubTitle:SetText(L["UI Scale"])
		f.Desc1:SetFormattedText(L["Adjust the UI Scale to fit your screen, press the autoscale button to set the UI Scale automatically."])
		InstallSlider:Show()
		InstallSlider:SetValueStep(0.01)
		InstallSlider:SetMinMaxValues(0.4, 1.15)

		local value = E.global.general.UIScale
		InstallSlider:SetValue(value)
		InstallSlider.Cur:SetText(value)
		InstallSlider:SetScript("OnValueChanged", function(self)
			E.global.general.UIScale = self:GetValue()
			InstallSlider.Cur:SetText(E.global.general.UIScale)
		end)

		InstallSlider.Min:SetText(0.4)
		InstallSlider.Max:SetText(1.15)
		InstallOption1Button:Show()
		InstallOption1Button:SetScript("OnClick", function()
			local scale = E:PixelBestSize()

			-- this is to just keep the slider in place, the values need updated again afterwards
			InstallSlider:SetValue(scale)

			-- update the values with deeper accuracy
			E.global.general.UIScale = scale
			InstallSlider.Cur:SetText(E.global.general.UIScale)
		end)

		InstallOption1Button:SetText(L["Auto Scale"])
		InstallOption2Button:Show()
		InstallOption2Button:SetScript("OnClick", function()
			E:PixelScaleChanged(nil, true)
		end)

		InstallOption2Button:SetText(L["Preview"])
		f.Desc3:SetText(L["Importance: |cff07D400High|r"])
	elseif PageNum == 6 then
		f.SubTitle:SetText(L["Layout"])
		f.Desc1:SetText(L["Choose a starting layout. You can customize it afterward."])
		f.Desc2:SetText(L["Applying resets unit frames and movers; presets may also change bars and panels."])
		f:Size(550, 455)

		for _, card in ipairs(f.LayoutCards) do
			card:Show()
			local selected = E.db.layoutSet == card.layout or (card.layout == "balanced" and E.db.layoutSet == "tank")
			card.selected:SetText(selected and L["Selected"] or "")
		end
	elseif PageNum == 7 then
		f.SubTitle:SetText(L["Auras"])
		f.Desc1:SetText(L["Select the type of aura system you want to use with ElvUI's unitframes. Set to Aura Bar & Icons to use both aura bars and icons, set to icons only to only see icons."])
		f.Desc2:SetText(L["If you have an icon or aurabar that you don't want to display simply hold down shift and right click the icon for it to disapear."])
		f.Desc3:SetText(L["Importance: |cffD3CF00Medium|r"])
		InstallOption1Button:Show()
		InstallOption1Button:SetScript("OnClick", function() SetupAuras(true) end)
		InstallOption1Button:SetText(L["Aura Bars & Icons"])
		InstallOption2Button:Show()
		InstallOption2Button:SetScript("OnClick", function() SetupAuras() end)
		InstallOption2Button:SetText(L["Icons Only"])
	elseif PageNum == 8 then
		f.SubTitle:SetText(L["Installation Complete"])
		f.Desc1:SetText(L["You are now finished with the installation process. If you are in need of technical support please visit us at https://github.com/ElvUI-WotLK."])
		f.Desc2:SetText(L["Please click the button below so you can setup variables and ReloadUI."])
		InstallOption1Button:Show()
		InstallOption1Button:SetScript("OnClick", function() E:StaticPopup_Show("ELVUI_EDITBOX", nil, nil, "https://discord.gg/UXSc7nt") end)
		InstallOption1Button:SetText(L["Discord"])
		InstallOption2Button:Show()
		InstallOption2Button:SetScript("OnClick", InstallComplete)
		InstallOption2Button:SetText(L["Finished"])
		ElvUIInstallFrame:Size(550, 350)
	end
end

local function NextPage()
	if CURRENT_PAGE ~= MAX_PAGE then
		CURRENT_PAGE = CURRENT_PAGE + 1
		SetPage(CURRENT_PAGE)
	end
end

local function PreviousPage()
	if CURRENT_PAGE ~= 1 then
		CURRENT_PAGE = CURRENT_PAGE - 1
		SetPage(CURRENT_PAGE)
	end
end

--Install UI
function E:Install()
	if not InstallStepComplete then
		local imsg = CreateFrame("Frame", "InstallStepComplete", E.UIParent)
		imsg:Size(418, 72)
		imsg:Point("TOP", 0, -190)
		imsg:Hide()
		imsg:SetScript("OnShow", function(f)
			if f.message then
				PlaySoundFile([[Sound\Interface\LevelUp.wav]])
				f.text:SetText(f.message)
				UIFrameFadeOut(f, 3.5, 1, 0)
				E:Delay(4, f.Hide, f)
				f.message = nil
			else
				f:Hide()
			end
		end)

		imsg.firstShow = false

		imsg.bg = imsg:CreateTexture(nil, "BACKGROUND")
		imsg.bg:SetTexture([[Interface\AddOns\ElvUI\media\textures\LevelUpTex]])
		imsg.bg:Point("BOTTOM")
		imsg.bg:Size(326, 103)
		imsg.bg:SetTexCoord(0.00195313, 0.63867188, 0.03710938, 0.23828125)
		imsg.bg:SetVertexColor(1, 1, 1, 0.6)

		imsg.lineTop = imsg:CreateTexture(nil, "BACKGROUND")
		imsg.lineTop:SetDrawLayer("BACKGROUND")
		imsg.lineTop:SetTexture([[Interface\AddOns\ElvUI\media\textures\LevelUpTex]])
		imsg.lineTop:Point("TOP")
		imsg.lineTop:Size(418, 7)
		imsg.lineTop:SetTexCoord(0.00195313, 0.81835938, 0.01953125, 0.03320313)

		imsg.lineBottom = imsg:CreateTexture(nil, "BACKGROUND")
		imsg.lineBottom:SetDrawLayer("BACKGROUND")
		imsg.lineBottom:SetTexture([[Interface\AddOns\ElvUI\media\textures\LevelUpTex]])
		imsg.lineBottom:Point("BOTTOM")
		imsg.lineBottom:Size(418, 7)
		imsg.lineBottom:SetTexCoord(0.00195313, 0.81835938, 0.01953125, 0.03320313)

		imsg.text = imsg:CreateFontString(nil, "OVERLAY")
		imsg.text:FontTemplate(E.media.normFont, 32, "OUTLINE")
		imsg.text:Point("BOTTOM", 0, 16)
		imsg.text:SetTextColor(1, 0.82, 0)
		imsg.text:SetJustifyH("CENTER")
	end

	--Create Frame
	if not ElvUIInstallFrame then
		local f = CreateFrame("Button", "ElvUIInstallFrame", E.UIParent)
		f.SetPage = SetPage
		f:Size(550, 400)
		f:SetTemplate("Transparent")
		f:Point("CENTER")
		f:SetFrameStrata("TOOLTIP")

		f:SetMovable(true)
		f:EnableMouse(true)
		f:RegisterForDrag("LeftButton")
		f:SetScript("OnDragStart", function(frame) frame:StartMoving() frame:SetUserPlaced(false) end)
		f:SetScript("OnDragStop", function(frame) frame:StopMovingOrSizing() end)

		f.Title = f:CreateFontString(nil, "OVERLAY")
		f.Title:FontTemplate(nil, 17, nil)
		f.Title:Point("TOP", 0, -5)
		f.Title:SetText(L["ElvUI Installation"])

		f.Next = CreateFrame("Button", "InstallNextButton", f, "UIPanelButtonTemplate")
		f.Next:Size(110, 25)
		f.Next:Point("BOTTOMRIGHT", -5, 5)
		f.Next:SetText(CONTINUE)
		f.Next:Disable()
		f.Next:SetScript("OnClick", NextPage)
		S:HandleButton(f.Next, true)

		f.Prev = CreateFrame("Button", "InstallPrevButton", f, "UIPanelButtonTemplate")
		f.Prev:Size(110, 25)
		f.Prev:Point("BOTTOMLEFT", 5, 5)
		f.Prev:SetText(PREVIOUS)
		f.Prev:Disable()
		f.Prev:SetScript("OnClick", PreviousPage)
		S:HandleButton(f.Prev, true)

		f.Status = CreateFrame("StatusBar", "InstallStatus", f)
		f.Status:SetFrameLevel(f.Status:GetFrameLevel() + 2)
		f.Status:CreateBackdrop()
		f.Status:SetStatusBarTexture(E.media.normTex)
		E:RegisterStatusBar(f.Status)
		f.Status:SetMinMaxValues(0, MAX_PAGE)
		f.Status:Point("TOPLEFT", f.Prev, "TOPRIGHT", 6, -2)
		f.Status:Point("BOTTOMRIGHT", f.Next, "BOTTOMLEFT", -6, 2)

		-- Setup StatusBar Animation
		f.Status.anim = CreateAnimationGroup(f.Status)
		f.Status.anim.progress = f.Status.anim:CreateAnimation("Progress")
		f.Status.anim.progress:SetEasing("Out")
		f.Status.anim.progress:SetDuration(0.3)

		f.Status.text = f.Status:CreateFontString(nil, "OVERLAY")
		f.Status.text:FontTemplate()
		f.Status.text:Point("CENTER")
		f.Status.text:SetText(CURRENT_PAGE.." / "..MAX_PAGE)

		f.Slider = CreateFrame("Slider", "InstallSlider", f)
		f.Slider:SetOrientation("HORIZONTAL")
		f.Slider:Height(15)
		f.Slider:Width(400)
		f.Slider:SetHitRectInsets(0, 0, -10, 0)
		f.Slider:SetPoint("CENTER", 0, 45)
		S:HandleSliderFrame(f.Slider)
		f.Slider:Hide()

		f.Slider.Min = f.Slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		f.Slider.Min:SetPoint("RIGHT", f.Slider, "LEFT", -3, 0)
		f.Slider.Max = f.Slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		f.Slider.Max:SetPoint("LEFT", f.Slider, "RIGHT", 3, 0)
		f.Slider.Cur = f.Slider:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		f.Slider.Cur:SetPoint("BOTTOM", f.Slider, "TOP", 0, 10)
		f.Slider.Cur:FontTemplate(nil, 30, nil)

		f.Option1 = CreateFrame("Button", "InstallOption1Button", f, "UIPanelButtonTemplate")
		f.Option1:Size(160, 30)
		f.Option1:Point("BOTTOM", 0, 45)
		f.Option1:SetText("")
		f.Option1:Hide()
		S:HandleButton(f.Option1, true)

		f.Option2 = CreateFrame("Button", "InstallOption2Button", f, "UIPanelButtonTemplate")
		f.Option2:Size(110, 30)
		f.Option2:Point("BOTTOMLEFT", f, "BOTTOM", 4, 45)
		f.Option2:SetText("")
		f.Option2:Hide()
		f.Option2:SetScript("OnShow", function()
			f.Option1:Width(110)
			f.Option1:ClearAllPoints()
			f.Option1:Point("BOTTOMRIGHT", f, "BOTTOM", -4, 45)
		end)
		f.Option2:SetScript("OnHide", function()
			f.Option1:Width(160)
			f.Option1:ClearAllPoints()
			f.Option1:Point("BOTTOM", 0, 45)
		end)
		S:HandleButton(f.Option2, true)

		f.Option3 = CreateFrame("Button", "InstallOption3Button", f, "UIPanelButtonTemplate")
		f.Option3:Size(100, 30)
		f.Option3:Point("LEFT", f.Option2, "RIGHT", 4, 0)
		f.Option3:SetText("")
		f.Option3:Hide()
		f.Option3:SetScript("OnShow", function()
			f.Option1:Width(100)
			f.Option1:ClearAllPoints()
			f.Option1:Point("RIGHT", f.Option2, "LEFT", -4, 0)
			f.Option2:Width(100)
			f.Option2:ClearAllPoints()
			f.Option2:Point("BOTTOM", f, "BOTTOM", 0, 45)
		end)
		f.Option3:SetScript("OnHide", function()
			f.Option1:Width(160)
			f.Option1:ClearAllPoints()
			f.Option1:Point("BOTTOM", 0, 45)
			f.Option2:Width(110)
			f.Option2:ClearAllPoints()
			f.Option2:Point("BOTTOMLEFT", f, "BOTTOM", 4, 45)
		end)
		S:HandleButton(f.Option3, true)

		f.Option4 = CreateFrame("Button", "InstallOption4Button", f, "UIPanelButtonTemplate")
		f.Option4:Size(100, 30)
		f.Option4:Point("LEFT", f.Option3, "RIGHT", 4, 0)
		f.Option4:SetText("")
		f.Option4:Hide()
		f.Option4:SetScript("OnShow", function()
			f.Option1:Width(100)
			f.Option1:ClearAllPoints()
			f.Option1:Point("RIGHT", f.Option2, "LEFT", -4, 0)
			f.Option2:Width(100)
			f.Option2:ClearAllPoints()
			f.Option2:Point("BOTTOMRIGHT", f, "BOTTOM", -4, 45)
		end)
		f.Option4:SetScript("OnHide", function()
			f.Option1:Width(160)
			f.Option1:ClearAllPoints()
			f.Option1:Point("BOTTOM", 0, 45)
			f.Option2:Width(110)
			f.Option2:ClearAllPoints()
			f.Option2:Point("BOTTOMLEFT", f, "BOTTOM", 4, 45)
		end)
		S:HandleButton(f.Option4, true)

		f.LayoutCards = {}
		local layouts = {
			{"balanced", L["Balanced"], L["Split player and target frames with centered cast bars and clear space between them."]},
			{"tank", L["Tank"], L["Threat-focused frames stay low while shorter cast bars sit above each frame."]},
			{"melee", L["Melee"], L["Player and target frames flank separate center lanes for their cast bars."]},
			{"dpsCaster", L["Caster DPS"], L["Wide cast bars line up above their matching player and target frames."]},
			{"healer", L["Healer"], L["Party and raid frames use a dedicated left column; cast bars align above player and target."]},
			{"raid10", L["Raid 10"], L["A compact 10-player grid sits above chat, clear of your player and target frames."]},
			{"raid25", L["Raid 25"], L["Raid and raid-40 grids use separate anchors and switch by roster size."]},
			{"arena", L["Arena"], L["Arena opponents sit upper-left, away from player and target frames."]},
			{"battleground", L["Battleground"], L["Compact raid grids stay above chat and leave the lower combat area open."]},
			{"dungeon", L["Dungeon"], L["A dedicated party-frame column adds larger health bars, auras, and healing prediction."]},
			{"questing", L["Questing"], L["Player and target frames sit closer to center, with a more prominent target nameplate."]},
			{"pet", L["Pet Class"], L["Pet and pet-target frames sit beneath the player; the pet action bar stays at the right edge."]},
			{"minimal", L["Minimal"], L["Uses default frame and action-bar positions and settings."]},
			{"compact", L["Compact"], L["Smaller frames and action buttons use a tighter, centered arrangement."]},
			{"skulytheme", L["Skuly's Personal Layout"], L["Apply Skuly's custom arrangement and settings."]},
		}

		for index, info in ipairs(layouts) do
			local layoutID, layoutTitle, layoutDescription = info[1], info[2], info[3]
			local card = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
			local column = (index - 1) % 5
			local row = math.floor((index - 1) / 5)
			card:Size(100, 64)
			card:Point("TOPLEFT", f, "TOPLEFT", 14 + (column * 104), -145 - (row * 72))
			card.layout = layoutID
			S:HandleButton(card, true)

			card.title = card:CreateFontString(nil, "OVERLAY")
			card.title:FontTemplate(nil, 11, "OUTLINE")
			card.title:Point("TOPLEFT", 5, -7)
			card.title:Point("TOPRIGHT", -5, -7)
			card.title:SetHeight(38)
			card.title:SetJustifyH("CENTER")
			card.title:SetJustifyV("MIDDLE")
			card.title:SetWordWrap(true)
			card.title:SetText(layoutTitle)

			card.selected = card:CreateFontString(nil, "OVERLAY")
			card.selected:FontTemplate(nil, 10, "OUTLINE")
			card.selected:Point("BOTTOM", 0, 6)

			card:HookScript("OnEnter", function(self)
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				if not layoutTooltipState then
					local r, g, b, a = GameTooltip:GetBackdropColor()
					layoutTooltipState = {
						strata = GameTooltip:GetFrameStrata(),
						level = GameTooltip:GetFrameLevel(),
						r = r, g = g, b = b, a = a,
					}
				end
				GameTooltip:SetFrameStrata("TOOLTIP")
				GameTooltip:SetFrameLevel(self:GetFrameLevel() + 100)
				GameTooltip:SetBackdropColor(0, 0, 0, 1)
				GameTooltip:SetText(layoutTitle, 0, 1, 0)
				GameTooltip:AddLine(layoutDescription, 0, 1, 0, true)
				GameTooltip:AddLine(L["Click to apply this layout."], 0, 1, 0, true)
				GameTooltip:Show()
			end)
			card:HookScript("OnLeave", function()
				GameTooltip:Hide()
				if layoutTooltipState then
					GameTooltip:SetFrameStrata(layoutTooltipState.strata)
					GameTooltip:SetFrameLevel(layoutTooltipState.level)
					GameTooltip:SetBackdropColor(layoutTooltipState.r, layoutTooltipState.g, layoutTooltipState.b, layoutTooltipState.a)
					layoutTooltipState = nil
				end
			end)

			card:SetScript("OnClick", function(self)
				E.db.layoutSet = nil
				E:SetupLayout(self.layout)
				for _, layoutCard in ipairs(f.LayoutCards) do
					local isSelected = E.db.layoutSet == layoutCard.layout
						or (layoutCard.layout == "balanced" and E.db.layoutSet == "tank")
					layoutCard.selected:SetText(isSelected and L["Selected"] or "")
				end
			end)

			f.LayoutCards[index] = card
		end

		f.SubTitle = f:CreateFontString(nil, "OVERLAY")
		f.SubTitle:FontTemplate(nil, 15, nil)
		f.SubTitle:Point("TOP", 0, -40)

		f.Desc1 = f:CreateFontString(nil, "OVERLAY")
		f.Desc1:FontTemplate()
		f.Desc1:Point("TOPLEFT", 20, -75)
		f.Desc1:Width(f:GetWidth() - 40)

		f.Desc2 = f:CreateFontString(nil, "OVERLAY")
		f.Desc2:FontTemplate()
		f.Desc2:Point("TOPLEFT", 20, -125)
		f.Desc2:Width(f:GetWidth() - 40)

		f.Desc3 = f:CreateFontString(nil, "OVERLAY")
		f.Desc3:FontTemplate()
		f.Desc3:Point("TOPLEFT", 20, -175)
		f.Desc3:Width(f:GetWidth() - 40)

		local closeButton = CreateFrame("Button", "InstallCloseButton", f, "UIPanelCloseButton")
		closeButton:Point("TOPRIGHT", f, "TOPRIGHT")
		closeButton:SetScript("OnClick", function() f:Hide() end)
		S:HandleCloseButton(closeButton)

	end

	ElvUIInstallFrame:Show()
	NextPage()
end