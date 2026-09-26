-- ElvUI_QuestTracker - Core.lua
local E, L, V, P, G = unpack(ElvUI_)
local QGT = E:NewModule("ElvUI_QuestTracker", "AceEvent-3.0", "AceHook-3.0")
_G.ElvUI_QuestTracker = QGT
_G.L = L

P["ElvUI_QuestTracker"] = {
        enabled = true,
        ShowBorder          = true,
        Scale               = 0.9,
        Lines               = 30,
        Alpha               = 0.7,
        ShowHeaders         = true,
        QuestItemIcons      = true,
        ShowLevels          = true,
        Pin                 = false,
        HideDuringCombat    = false,
        AutoUnTrack         = false,
        ShowCompletedObj    = true,
        ColorizeObj         = false,
        ColorizeObjZero     = {r = 0.8, g = 0.2, b = 0.8},
        ColorizeObjFull     = {r = 0.3, g = 0.8, b = 1.0},
        ColorizeObjComplete = {r = 0.1, g = 0.9, b = 1.0},
        ClickThrough        = false,
        ShowQuestTooltips   = true,
        ShowPartyTooltips   = true,
        ShowQuestPercent    = true,
        Bullet              = "-",
        Anchor              = "TOP",
        LastTracker         = "Q",
        BothTrackers        = false,
        QuestWatch = {
            Minimized    = false,
            AutoMinimize = false,
            Left         = nil,
            Top          = nil,
            Bottom       = nil,
        },
        AchievementWatch = {
            Minimized    = false,
            AutoMinimize = false,
            Left         = nil,
            Top          = nil,
            Bottom       = nil,
        },
        WatchAchievements = {},
        WatchList = {},
        WatchHeaders = {},
        WatchQuests = {},

}

QGT_Settings = {}
QGT_PlayerAlive        = false
QGT_VariablesLoaded    = false
QGT_ShowTracker        = true
QGT_PlayerInCombat     = false
QGT_WatchHeaders       = {}
QGT_WatchQuests        = {}
QGT_WatchFlash         = {}
QGT_WatchList          = {}
QGT_WatchLine          = {}
QGT_WatchLines         = 0
QGT_WatchUpdateTime    = 0
QGT_WATCHFRAME_NUM_ITEMS = 0
QGT_LastAbandonQuestTitle = ""
QGT_QuestTimer         = {}
QGT_Timer              = {}
QGT_CurrTime           = 0
QGT_WatchAchievements  = {}
QGT_WatchAchievementLines = 0
QGT_AchievementTimer   = {}
QGT_AWUpdating         = false
WATCHFRAME_MAXACHIEVEMENTS = 10

function QGT:Initialize()
    self.db = E.db.ElvUI_QuestTracker
    QGT_Settings = self.db

    QGT_WatchAchievements = self.db.WatchAchievements
    QGT_WatchList = self.db.WatchList
    QGT_WatchHeaders = self.db.WatchHeaders
    QGT_WatchQuests = self.db.WatchQuests

	self:StartTracker()

    self.initialized = true
    self:SetupMovers()

    if GetBindingKey("QGT_TOGGLE_TRACKER_KB") == nil then
        SetBinding("SHIFT-L", "QGT_TOGGLE_TRACKER_KB")
        SaveBindings(2)
    end
end

function QGT:ResetSettings()
    for k, v in pairs(P["ElvUI_QuestTracker"]) do
        if type(v) == "table" then
            self.db[k] = E:CopyTable({}, v)
        else
            self.db[k] = v
        end
    end
    if WatchFrame_Update then WatchFrame_Update() end
end

SLASH_ELVUI_QUESTTRACKER1 = "/qgt"
SLASH_ELVUI_QUESTTRACKER2 = "/questtracker"
SlashCmdList.ELVUI_QUESTTRACKER = function(msg)
    if msg == "reset" then
        QGT:ResetSettings()
        E:Print("QuestTracker settings reset.")
    elseif msg == "toggle" then
        QGT_ShowTracker = not QGT_ShowTracker
        WatchFrame_Update()
    else
        E:ToggleOptionsUI("ElvUI_QuestTracker")
    end
end

local function InitializeCallback()
    QGT:Initialize()
end

E:RegisterModule(QGT:GetName(), InitializeCallback)