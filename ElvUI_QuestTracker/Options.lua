local E, L, V, P, G = unpack(ElvUI_)
local QGT = E:GetModule("ElvUI_QuestTracker")
local EP = LibStub("LibElvUIPlugin-1.0")
local addonName = ...

function QGT:GetOptions()
    local db = E.db.ElvUI_QuestTracker

    local function refresh()
        if WatchFrame_Update then WatchFrame_Update() end
    end

    local options = {
        type = "group",
        name = "|cffe5e3e3QuestTracker|r", 
		order = 54,
        args = {
            enable = {
                order = 1,
                type = "toggle",
                name = L["Enable"],
                get = function() return db.enabled end,
                set = function(_, v) db.enabled = v; if v then QGT:StartTracker() else QGT:StopTracker() end end,
            },
            description = {
                order = 2,
                type = "description",
                name = L["Tracker Description"],
            },
            headerGeneral = { order = 10, type = "header", name = L["Options"] },
            ShowHeaders = {
                order = 11, type = "toggle", name = L["Show Headers"], desc = L["Show Headers Desc"],
                get = function() return db.ShowHeaders end,
                set = function(_, v) db.ShowHeaders = v; refresh() end,
            },
            ShowLevels = {
                order = 12, type = "toggle", name = L["Show Levels"], desc = L["Show Levels Desc"],
                get = function() return db.ShowLevels end,
                set = function(_, v) db.ShowLevels = v; refresh() end,
            },
            ShowQuestPercent = {
                order = 13, type = "toggle", name = L["Show Quest Percent"], desc = L["Show Quest Percent Desc"],
                get = function() return db.ShowQuestPercent end,
                set = function(_, v) db.ShowQuestPercent = v; refresh() end,
            },
            ShowCompletedObj = {
                order = 14, type = "toggle", name = L["Show Completed Obj"], desc = L["Show Completed Obj Desc"],
                get = function() return db.ShowCompletedObj end,
                set = function(_, v) db.ShowCompletedObj = v; refresh() end,
            },
            AutoUnTrack = {
                order = 15, type = "toggle", name = L["Auto UnTrack"], desc = L["Auto UnTrack Desc"],
                get = function() return db.AutoUnTrack end,
                set = function(_, v) db.AutoUnTrack = v end,
            },
            headerBehaviour = { order = 20, type = "header", name = L["Tracker Options"] },
            Pin = {
                order = 21, type = "toggle", name = L["Pin Position"], desc = L["Pin Position Desc"],
                get = function() return db.Pin end,
                set = function(_, v) db.Pin = v; refresh() end,
            },
            ClickThrough = {
                order = 22, type = "toggle", name = L["Click Through"], desc = L["Click Through Desc"],
                get = function() return db.ClickThrough end,
                set = function(_, v) db.ClickThrough = v; refresh() end,
            },
            HideDuringCombat = {
                order = 23, type = "toggle", name = L["Hide During Combat"],
                get = function() return db.HideDuringCombat end,
                set = function(_, v) db.HideDuringCombat = v; refresh() end,
            },
            AnchorBottom = {
                order = 24, type = "toggle", name = L["Anchor Bottom"], desc = L["Anchor Bottom Desc"],
                get = function() return db.Anchor == "BOTTOM" end,
                set = function(_, v) db.Anchor = v and "BOTTOM" or "TOP"; refresh() end,
            },
            headerAppearance = { order = 30, type = "header", name = "Appearance" },
            ShowBorder = {
                order = 31, type = "toggle", name = L["Show Border"], desc = L["Show Border Desc"],
                get = function() return db.ShowBorder end,
                set = function(_, v)
                    db.ShowBorder = v
                    QGT_SetQuestWatchBorder(v)
                    QGT_SetAchievementWatchBorder(v)
                    refresh()
                end,
            },
            Alpha = {
				order = 32, type = "range", name = L["Tracker Alpha"],
				min = 0, max = 1, step = 0.01, isPercent = true,
				get = function() return db.Alpha end,
				set = function(_, v)
					db.Alpha = v
					QGT_QuestWatchFrame:SetBackdropColor(0, 0, 0, v)
					QGT_QuestWatchFrameBackground:SetGradientAlpha("VERTICAL", 0, 0, 0, 0, 0.3, 0.3, 0.3, v)
					QGT_AchievementWatchFrame:SetBackdropColor(0, 0, 0, v)
					QGT_AchievementWatchFrameBackground:SetGradientAlpha("VERTICAL", 0, 0, 0, 0, 0.3, 0.3, 0.3, v)
				end,
			},
            Scale = {
                order = 33, type = "range", name = L["Tracker Scale"],
                min = 0.5, max = 1.5, step = 0.01, isPercent = true,
                get = function() return db.Scale end,
                set = function(_, v)
                    db.Scale = v
                    QGT_QuestWatchFrame:SetScale(v)
                    QGT_AchievementWatchFrame:SetScale(v)
                end,
            },
            Lines = {
                order = 34, type = "range", name = L["Tracker Max Lines"],
                min = 7, max = 40, step = 1,
                get = function() return db.Lines end,
                set = function(_, v) db.Lines = v; refresh() end,
            },
            Bullet = {
                order = 35, type = "input", name = L["Tracker Bullet"],
                get = function() return db.Bullet end,
                set = function(_, v) db.Bullet = v; refresh() end,
            },
            headerTooltips = { order = 40, type = "header", name = "Tooltips" },
            ShowQuestTooltips = {
                order = 41, type = "toggle", name = L["Show Quest Tooltips"], desc = L["Show Quest Tooltips Desc"],
                get = function() return db.ShowQuestTooltips end,
                set = function(_, v) db.ShowQuestTooltips = v end,
            },
            ShowPartyTooltips = {
                order = 42, type = "toggle", name = L["Show Party Tooltips"], desc = L["Show Party Tooltips Desc"],
                get = function() return db.ShowPartyTooltips end,
                set = function(_, v) db.ShowPartyTooltips = v end,
            },
            QuestItemIcons = {
                order = 43, type = "toggle", name = L["Quest Item Icons"], desc = L["Quest Item Icons Desc"],
                get = function() return db.QuestItemIcons end,
                set = function(_, v) db.QuestItemIcons = v; refresh() end,
            },
            headerColorize = { order = 50, type = "header", name = L["Colorize Objective Progress"] },
            ColorizeObj = {
                order = 51, type = "toggle", name = L["Colorize Objective Progress"], desc = L["Colorize Objective Progress Desc"],
                get = function() return db.ColorizeObj end,
                set = function(_, v) db.ColorizeObj = v; refresh() end,
            },
            ColorizeObjZero = {
                order = 52, type = "color", name = L["Objective Color 0%"],
                get = function() local c = db.ColorizeObjZero; return c.r, c.g, c.b end,
                set = function(_, r, g, b) db.ColorizeObjZero = {r=r, g=g, b=b}; refresh() end,
            },
            ColorizeObjFull = {
                order = 53, type = "color", name = L["Objective Color 99%"],
                get = function() local c = db.ColorizeObjFull; return c.r, c.g, c.b end,
                set = function(_, r, g, b) db.ColorizeObjFull = {r=r, g=g, b=b}; refresh() end,
            },
            ColorizeObjComplete = {
                order = 54, type = "color", name = L["Objective Color Complete"],
                get = function() local c = db.ColorizeObjComplete; return c.r, c.g, c.b end,
                set = function(_, r, g, b) db.ColorizeObjComplete = {r=r, g=g, b=b}; refresh() end,
            },
        },
    }

    return options
end

local function InjectOptions()
    E.Options.args.ElvUI_QuestTracker = QGT:GetOptions()
end

EP:RegisterPlugin(addonName, InjectOptions)