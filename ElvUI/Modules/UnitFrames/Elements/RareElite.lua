local E, L, V, P, G = unpack(select(2, ...)) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local UF = E:GetModule("UnitFrames")

--Lua functions
local select = select

--WoW API / Variables
local CreateFrame = CreateFrame
local UnitClassification = UnitClassification
local UnitIsPlayer = UnitIsPlayer
local UnitClass = UnitClass
local UnitExists = UnitExists

function UF:Construct_RareElite(frame)
	local container = CreateFrame("Frame", nil, frame)
	container:SetFrameStrata("LOW")
	container:SetFrameLevel(frame:GetFrameLevel() + 15)

	local texture = container:CreateTexture(nil, "OVERLAY", nil, 7)
	texture:SetAllPoints(container)

	container.Texture = texture
	return container
end

function UF:Configure_RareElite(frame)
	if not frame then return end
	local indicator = frame.RareEliteIndicator
	if not indicator then return end

	local db = frame.db and frame.db.rareElite
	if not db then
		db = { enable = true, skin = "classic", frameStrata = "LOW" }
		if frame.db then frame.db.rareElite = db end
	end

	if db.enable then
		indicator:SetParent(frame)
		indicator:SetFrameStrata(db.frameStrata or "LOW")
		indicator:SetFrameLevel(frame:GetFrameLevel() + 15)
		indicator:ClearAllPoints()

		local skin = db.skin or "classic"
		if skin == "blurry" then
			indicator:Size(db.width or 120, db.height or 120)
			indicator:Point("TOPRIGHT", frame, "TOPRIGHT", db.xOffset or 47, db.yOffset or 25)
		elseif skin == "modern" then
			indicator:Size(db.width or 100, db.height or 100)
			indicator:Point("TOPRIGHT", frame, "TOPRIGHT", db.xOffset or 36, db.yOffset or 8)
		elseif skin == "tiny" then
			indicator:Size(db.width or 100, db.height or 100)
			indicator:Point("TOPRIGHT", frame, "TOPRIGHT", db.xOffset or 33, db.yOffset or 8)
		else -- classic
			indicator:Size(db.width or 256, db.height or 128)
			indicator:Point("TOPRIGHT", frame, "TOPRIGHT", db.xOffset or 100, db.yOffset or 15)
		end

		self:UpdateRareElite(frame)
	else
		indicator:Hide()
	end
end

function UF:UpdateRareElite(frame)
	if not frame then return end
	local indicator = frame.RareEliteIndicator
	if not indicator then return end

	local db = frame.db and frame.db.rareElite
	if not (db and db.enable) then
		indicator:Hide()
		return
	end

	local unit = frame.unit or "target"

	if db.preview then
		local skin = db.skin or "classic"
		indicator.Texture:SetTexture("Interface\\AddOns\\ElvUI\\Media\\Textures\\SimpleRareElite\\" .. skin .. "\\rareelite.tga")
		indicator.Texture:SetTexCoord(0, 1, 0, 1)
		indicator:Show()
		return
	end

	if not UnitExists(unit) then
		indicator:Hide()
		return
	end

	local classification = UnitIsPlayer(unit) and select(2, UnitClass(unit)) or UnitClassification(unit)
	local textureName

	if classification == "worldboss" or classification == "boss" then
		textureName = "worldboss.tga"
	elseif classification == "rareelite" then
		textureName = "rareelite.tga"
	elseif classification == "elite" then
		textureName = "elite.tga"
	elseif classification == "rare" then
		textureName = "rare.tga"
	end

	if textureName then
		local skin = db.skin or "classic"
		indicator.Texture:SetTexture("Interface\\AddOns\\ElvUI\\Media\\Textures\\SimpleRareElite\\" .. skin .. "\\" .. textureName)
		indicator.Texture:SetTexCoord(0, 1, 0, 1)
		indicator:Show()
	else
		indicator:Hide()
	end
end

-- Event listener for target updates
local rareEliteEventsFrame = CreateFrame("Frame")
rareEliteEventsFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
rareEliteEventsFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
rareEliteEventsFrame:RegisterEvent("UNIT_CLASSIFICATION_CHANGED")
rareEliteEventsFrame:SetScript("OnEvent", function(self, event, unit)
	if ElvUF_Target and (event ~= "UNIT_CLASSIFICATION_CHANGED" or unit == "target") then
		UF:UpdateRareElite(ElvUF_Target)
	end
end)

-- Slash Commands
SLASH_SIMPLERAREELITE1 = "/sre"
SLASH_SIMPLERAREELITE2 = "/simplerareelite"
SlashCmdList["SIMPLERAREELITE"] = function()
	E:ToggleOptionsUI("unitframe,target,rareElite")
end
