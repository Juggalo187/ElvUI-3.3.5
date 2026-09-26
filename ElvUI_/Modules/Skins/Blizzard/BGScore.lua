local E, L, V, P, G = unpack(select(2, ...)) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local S = E:GetModule("Skins")

--Lua functions
local format, split = string.format, string.split
--WoW API / Variables
local FauxScrollFrame_GetOffset = FauxScrollFrame_GetOffset
local GetBattlefieldScore = GetBattlefieldScore
local IsActiveBattlefieldArena = IsActiveBattlefieldArena
local RAID_CLASS_COLORS = RAID_CLASS_COLORS

if not string.find(string.lower(E.myrealm), "rogue-lite", 1, true) then
S:AddCallback("Skin_WorldStateScore", function()
	if not E.private.skins.blizzard.enable or not E.private.skins.blizzard.bgscore then return end

	if string.find(string.lower(E.myrealm), "rogue-lite", 1, true) then
		do return end
	end

	WorldStateScoreFrame:StripTextures()
	WorldStateScoreFrame:CreateBackdrop("Transparent")
	WorldStateScoreFrame.backdrop:Point("TOPLEFT", 10, -15)
	WorldStateScoreFrame.backdrop:Point("BOTTOMRIGHT", -113, 67)

	WorldStateScoreFrame:EnableMouse(true)
	S:SetBackdropHitRect(WorldStateScoreFrame)

	S:HandleCloseButton(WorldStateScoreFrameCloseButton, WorldStateScoreFrame.backdrop)

	WorldStateScoreScrollFrame:StripTextures()
	S:HandleScrollBar(WorldStateScoreScrollFrameScrollBar)

	-- Ebonhold: the scoreboard no longer has the stock 3.3.5 set of column
	-- headers. Our custom Interface\FrameXML\WorldStateFrame.xml (ships in
	-- patch-D) drops WorldStateScoreFrameClass entirely -- the matching
	-- WorldStateScoreFrameClass:GetWidth() call in WorldStateFrame.lua is
	-- commented out for the same reason, and the class is drawn per row as
	-- $parentClassButton instead. Indexing it here raised
	--     attempt to index global 'WorldStateScoreFrameClass' (a nil value)
	-- and, since this whole function runs inside one Skins callback, that
	-- aborted everything below it: the scoreboard stayed unskinned.
	-- Skin whatever exists, ignore the rest, so the next column change is a
	-- missing skin instead of a Lua error every time a BG ends.
	for _, headerName in ipairs({
		"WorldStateScoreFrameKB",
		"WorldStateScoreFrameDeaths",
		"WorldStateScoreFrameHK",
		"WorldStateScoreFrameDamageDone",
		"WorldStateScoreFrameHealingDone",
		"WorldStateScoreFrameHonorGained",
		"WorldStateScoreFrameName",
		"WorldStateScoreFrameClass",
		"WorldStateScoreFrameTeam",
	}) do
		local header = _G[headerName]
		if header and header.StyleButton then header:StyleButton() end
	end
--	WorldStateScoreFrameRatingChange:StyleButton()

	S:HandleButton(WorldStateScoreFrameLeaveButton)

	for i = 1, 3 do
		local tab, tabText = _G["WorldStateScoreFrameTab"..i], _G["WorldStateScoreFrameTab"..i.."Text"]
		if tab then S:HandleTab(tab) end
		if tabText then tabText:Point("CENTER", 0, 2) end
	end

	WorldStateScoreFrameTab2:Point("LEFT", WorldStateScoreFrameTab1, "RIGHT", -15, 0)
	WorldStateScoreFrameTab3:Point("LEFT", WorldStateScoreFrameTab2, "RIGHT", -15, 0)

	WorldStateScoreScrollFrameScrollBar:Point("TOPLEFT", WorldStateScoreScrollFrame, "TOPRIGHT", 8, -21)
	WorldStateScoreScrollFrameScrollBar:Point("BOTTOMLEFT", WorldStateScoreScrollFrame, "BOTTOMRIGHT", 8, 38)

	for i = 1, 5 do
		local column = _G["WorldStateScoreColumn"..i]
		if column and column.StyleButton then column:StyleButton() end
	end

	local myName = format("> %s <", E.myname)

	hooksecurefunc("WorldStateScoreFrame_Update", function()
		local inArena = IsActiveBattlefieldArena()
		local offset = FauxScrollFrame_GetOffset(WorldStateScoreScrollFrame)

		local _, name, faction, classToken, realm, classTextColor, nameText

		for i = 1, MAX_WORLDSTATE_SCORE_BUTTONS do
			name, _, _, _, _, faction, _, _, _, classToken = GetBattlefieldScore(offset + i)

			if name then
				name, realm = split("-", name, 2)

				if name == E.myname then
					name = myName
				end

				if realm then
					local color

					if inArena then
						if faction == 1 then
							color = "|cffffd100"
						else
							color = "|cff19ff19"
						end
					else
						if faction == 1 then
							color = "|cff00adf0"
						else
							color = "|cffff1919"
						end
					end

					name = format("%s|cffffffff - |r%s%s|r", name, color, realm)
				end

				classTextColor = CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[classToken] or RAID_CLASS_COLORS[classToken]

				nameText = _G["WorldStateScoreButton"..i.."NameText"]
				nameText:SetText(name)
				nameText:SetTextColor(classTextColor.r, classTextColor.g, classTextColor.b)
			end
		end
	end)
end)
end