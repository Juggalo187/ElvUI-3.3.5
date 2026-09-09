local E, L, V, P, G = unpack(select(2, ...))
local NP = E:GetModule("NamePlates")
local LSM = E.Libs.LSM

local ipairs = ipairs
local GetTime = GetTime
local CreateFrame = CreateFrame
local GetRuneCooldown = GetRuneCooldown
local GetRuneType = GetRuneType
local UnitClass = UnitClass
local RAID_CLASS_COLORS = RAID_CLASS_COLORS

function NP:Runes_SetBarColor(bar, r, g, b)
	bar:SetStatusBarColor(r, g, b)
	if bar.bg then
		bar.bg:SetVertexColor(r * 0.35, g * 0.35, b * 0.35)
	end
end

function NP:Runes_GetColor(runeType, classColor)
	local colors = NP.db.colors.classResources.DEATHKNIGHT
	if classColor then
		return classColor.r, classColor.g, classColor.b
	end
	local color = colors[runeType or 1] or colors[1]
	return color.r, color.g, color.b
end

function NP:Update_Runes(frame)
	if E.myclass ~= "DEATHKNIGHT" then return end
	if not frame.isTarget then
		if frame.Runes then frame.Runes:Hide() end
		return
	end

	local db = self.db.units.TARGET.classpower
	if not db or not db.enable then
		if frame.Runes then frame.Runes:Hide() end
		return
	end

	local runes = frame.Runes
	if not runes then return end

	runes:ClearAllPoints()
	if frame.Health:IsShown() then
		runes:Point("CENTER", frame.Health, "BOTTOM", db.xOffset, db.yOffset)
	else
		runes:Point("CENTER", frame, "TOP", db.xOffset, db.yOffset)
	end

	local width = db.width / 6
	runes:Size(db.width, db.height)
	runes:Show()

	local _, class = UnitClass("player")
	local classColor = db.classColor and RAID_CLASS_COLORS[class]

	for i = 1, 6 do
		local rune = runes[i]
		local start, duration, runeReady = GetRuneCooldown(i)
		local runeType = GetRuneType(i)
		local r, g, b = self:Runes_GetColor(runeType, classColor)

		self:Runes_SetBarColor(rune, r, g, b)

		if runeReady then
			rune:SetMinMaxValues(0, 1)
			rune:SetValue(1)
		elseif start and duration and duration > 0 then
			rune:SetMinMaxValues(0, duration)
			rune:SetValue(duration - (GetTime() - start))
		else
			rune:SetMinMaxValues(0, 1)
			rune:SetValue(0)
		end

		if i == 1 then
			rune:Size(width, db.height)
			rune:ClearAllPoints()
			rune:Point("LEFT", runes, "LEFT", 0, 0)
		else
			rune:Size(width - 1, db.height)
			rune:ClearAllPoints()
			rune:Point("LEFT", runes[i - 1], "RIGHT", 1, 0)
		end
	end
end

function NP:Configure_Runes(frame)
end

function NP:Construct_Runes(frame)
	local runes = CreateFrame("Frame", nil, frame)
	runes:Hide()

	local texture = LSM:Fetch("statusbar", NP.db.statusbar)
	for i = 1, 6 do
		local rune = CreateFrame("StatusBar", nil, runes)
		rune:SetStatusBarTexture(texture)
		rune.bg = rune:CreateTexture(nil, "BORDER")
		rune.bg:SetAllPoints()
		rune.bg:SetTexture(texture)
		runes[i] = rune
	end

	return runes
end

function NP:Runes_OnEvent()
	if E.myclass ~= "DEATHKNIGHT" then return end
	NP:ForEachVisiblePlate("Update_Runes")
end

local runeFrame = CreateFrame("Frame")
runeFrame:RegisterEvent("RUNE_POWER_UPDATE")
runeFrame:RegisterEvent("RUNE_TYPE_UPDATE")
runeFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
runeFrame:SetScript("OnEvent", function()
	NP:Runes_OnEvent()
end)
