local E, L, V, P, G = unpack(ElvUI)
local QGT = E:GetModule("ElvUI_QuestTracker")

-- Register the tracker frames with ElvUI's mover system.
-- The ported code already anchors the frames manually using
-- QGT_Settings.QuestWatch.Left/Top, but registering them as movers
-- lets users move them via ElvUI's /moveui command too.
function QGT:SetupMovers()
    -- Quest tracker
    E:CreateMover(
        QGT_QuestWatchFrame,
        "QGT_QuestWatchFrameMover",
        L["Quests"],
        nil, nil, nil,
        "ALL,GENERAL"
    )

    -- Achievement tracker
    E:CreateMover(
        QGT_AchievementWatchFrame,
        "QGT_AchievementWatchFrameMover",
        L["Achievements"],
        nil, nil, nil,
        "ALL,GENERAL"
    )
end