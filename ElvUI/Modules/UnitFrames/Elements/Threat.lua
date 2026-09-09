local E, L, V, P, G = unpack(select(2, ...)); --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local UF = E:GetModule("UnitFrames")
local LSM = E.Libs.LSM

--Lua functions
local unpack = unpack
local pairs = pairs
local type = type
--WoW API / Variables
local CreateFrame = CreateFrame
local UnitExists = UnitExists
local UnitGUID = UnitGUID
local UnitIsPlayer = UnitIsPlayer
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitThreatSituation = UnitThreatSituation
local GetNumPartyMembers = GetNumPartyMembers
local GetNumRaidMembers = GetNumRaidMembers

function UF:Construct_Threat(frame)
	local threat = CreateFrame("Frame", nil, frame)

	--Main ThreatGlow
	frame:CreateShadow()
	threat.glow = frame.shadow
	threat.glow:SetParent(frame)
	threat.glow:Hide()
	frame.shadow = nil

	--Secondary ThreatGlow, for power frame when using power offset
	frame:CreateShadow()
	threat.powerGlow = frame.shadow
	threat.powerGlow:SetParent(frame)
	threat.powerGlow:SetFrameStrata("BACKGROUND")
	threat.powerGlow:Hide()
	frame.shadow = nil

	threat.texIcon = threat:CreateTexture(nil, "OVERLAY")
	threat.texIcon:Size(8)
	threat.texIcon:SetTexture(E.media.blankTex)
	threat.texIcon:Hide()

	threat.text = threat:CreateFontString(nil, "OVERLAY")
	threat.text:Hide()

	threat.PostUpdate = self.UpdateThreat
	return threat
end

local function GetThreatCount(unit)
	if not unit or not UnitExists(unit) then return 0 end

	local checkedGUIDs = {}
	local count = 0

	local function checkEnemy(enemyUnit)
		if UnitExists(enemyUnit) and not UnitIsPlayer(enemyUnit) and not UnitIsDeadOrGhost(enemyUnit) then
			local guid = UnitGUID(enemyUnit)
			if guid and not checkedGUIDs[guid] then
				checkedGUIDs[guid] = true
				local uStatus = UnitThreatSituation(unit, enemyUnit)
				if uStatus and uStatus >= 2 then
					count = count + 1
				end
			end
		end
	end

	checkEnemy("target")
	checkEnemy("focus")
	checkEnemy("mouseover")
	checkEnemy("playertarget")
	checkEnemy("pettarget")

	local numParty = GetNumPartyMembers()
	if numParty > 0 then
		for i = 1, numParty do
			checkEnemy("party"..i.."target")
			checkEnemy("party"..i.."pettarget")
		end
	end

	local numRaid = GetNumRaidMembers()
	if numRaid > 0 then
		for i = 1, numRaid do
			checkEnemy("raid"..i.."target")
			checkEnemy("raid"..i.."pettarget")
		end
	end

	for i = 1, 4 do
		checkEnemy("boss"..i.."target")
	end

	for i = 1, 40 do
		checkEnemy("nameplate"..i)
	end

	local NP = E:GetModule("NamePlates", true)
	if NP and NP.Plates then
		for nameplate in pairs(NP.Plates) do
			if nameplate:IsShown() and nameplate.unit then
				checkEnemy(nameplate.unit)
			end
		end
	end

	return count
end

function UF:Configure_Threat(frame)
	if not (frame.VARIABLES_SET and frame.ThreatIndicator) then return end

	local threat = frame.ThreatIndicator
	local db = frame.db

	local customEnable = db.threat and db.threat.enable

	if (db.threatStyle ~= "NONE" and db.threatStyle ~= nil) or customEnable then
		if not frame:IsElementEnabled("ThreatIndicator") then
			frame:EnableElement("ThreatIndicator")
		end

		if db.threatStyle == "GLOW" then
			threat:SetFrameStrata("BACKGROUND")
			threat.glow:SetFrameStrata("BACKGROUND")
			threat.glow:ClearAllPoints()
			if frame.USE_POWERBAR_OFFSET then
				if frame.ORIENTATION == "RIGHT" then
					threat.glow:Point("TOPLEFT", frame.Health.backdrop, "TOPLEFT", -frame.SHADOW_SPACING - frame.SPACING - (frame.HAPPINESS_WIDTH or 0), frame.SHADOW_SPACING + frame.SPACING + (frame.USE_CLASSBAR and (frame.USE_MINI_CLASSBAR and 0 or frame.CLASSBAR_HEIGHT) or 0))
					threat.glow:Point("BOTTOMRIGHT", frame.Health.backdrop, "BOTTOMRIGHT", frame.SHADOW_SPACING + frame.SPACING, -frame.SHADOW_SPACING - frame.SPACING)
				else
					threat.glow:Point("TOPLEFT", frame.Health.backdrop, "TOPLEFT", -frame.SHADOW_SPACING - frame.SPACING, frame.SHADOW_SPACING + frame.SPACING + (frame.USE_CLASSBAR and (frame.USE_MINI_CLASSBAR and 0 or frame.CLASSBAR_HEIGHT) or 0))
					threat.glow:Point("BOTTOMRIGHT", frame.Health.backdrop, "BOTTOMRIGHT", frame.SHADOW_SPACING + frame.SPACING + (frame.HAPPINESS_WIDTH or 0), -frame.SHADOW_SPACING - frame.SPACING)
				end

				threat.powerGlow:ClearAllPoints()
				threat.powerGlow:Point("TOPLEFT", frame.Power.backdrop, "TOPLEFT", -frame.SHADOW_SPACING - frame.SPACING, frame.SHADOW_SPACING + frame.SPACING)
				threat.powerGlow:Point("BOTTOMRIGHT", frame.Power.backdrop, "BOTTOMRIGHT", frame.SHADOW_SPACING + frame.SPACING, -frame.SHADOW_SPACING - frame.SPACING)
			else
				threat.glow:Point("TOPLEFT", -frame.SHADOW_SPACING, frame.SHADOW_SPACING-(frame.USE_MINI_CLASSBAR and frame.CLASSBAR_YOFFSET or 0))

				if frame.USE_MINI_POWERBAR then
					threat.glow:Point("BOTTOMLEFT", -frame.SHADOW_SPACING, -frame.SHADOW_SPACING + (frame.POWERBAR_HEIGHT/2))
					threat.glow:Point("BOTTOMRIGHT", frame.SHADOW_SPACING, -frame.SHADOW_SPACING + (frame.POWERBAR_HEIGHT/2))
				else
					threat.glow:Point("BOTTOMLEFT", -frame.SHADOW_SPACING, -frame.SHADOW_SPACING)
					threat.glow:Point("BOTTOMRIGHT", frame.SHADOW_SPACING, -frame.SHADOW_SPACING)
				end
			end
		elseif db.threatStyle == "ICONTOPLEFT" or db.threatStyle == "ICONTOPRIGHT" or db.threatStyle == "ICONBOTTOMLEFT" or db.threatStyle == "ICONBOTTOMRIGHT" or db.threatStyle == "ICONTOP" or db.threatStyle == "ICONBOTTOM" or db.threatStyle == "ICONLEFT" or db.threatStyle == "ICONRIGHT" then
			threat:SetFrameStrata("LOW")
			threat:SetFrameLevel(75) --Inset power uses 50, we want it to appear above that
			local point = db.threatStyle
			point = string.gsub(point, "ICON", "")

			threat.texIcon:ClearAllPoints()
			threat.texIcon:Point(point, frame.Health, point)
		elseif db.threatStyle == "HEALTHBORDER" then
			if frame.InfoPanel then
				frame.InfoPanel:SetFrameLevel(frame.Health:GetFrameLevel() - 3)
			end
		elseif db.threatStyle == "INFOPANELBORDER" then
			if frame.InfoPanel then
				frame.InfoPanel:SetFrameLevel(frame.Health:GetFrameLevel() + 3)
			end
		end

		if customEnable then
			threat:SetFrameStrata("LOW")
			threat:SetFrameLevel(75)

			local attachToFrame = frame
			if db.threat.attachTo == "Health" and frame.Health then
				attachToFrame = frame.Health
			elseif db.threat.attachTo == "Power" and frame.Power then
				attachToFrame = frame.Power
			elseif db.threat.attachTo == "InfoPanel" and frame.InfoPanel then
				attachToFrame = frame.InfoPanel
			end

			threat.texIcon:ClearAllPoints()
			threat.texIcon:Point(db.threat.position, attachToFrame, db.threat.position, db.threat.xOffset, db.threat.yOffset)
			threat.texIcon:Size(db.threat.size)

			local texturePath = LSM:Fetch("statusbar", db.threat.texture) or LSM:Fetch("background", db.threat.texture) or E.media.blankTex
			threat.texIcon:SetTexture(texturePath)

			threat.text:ClearAllPoints()
			threat.text:Point("CENTER", threat.texIcon, "CENTER", 0, 0)
			threat.text:FontTemplate(LSM:Fetch("font", db.threat.font), db.threat.fontSize, db.threat.fontOutline)
			if db.threat.textColor then
				threat.text:SetTextColor(db.threat.textColor.r, db.threat.textColor.g, db.threat.textColor.b, db.threat.textColor.a)
			end
		end
	elseif frame:IsElementEnabled("ThreatIndicator") then
		frame:DisableElement("ThreatIndicator")
	end
end

function UF:UpdateThreat(unit, status, r, g, b)
	local parent = self:GetParent()
	if (parent.unit ~= unit) or not unit then return end

	local db = parent.db
	if not db then return end

	if parent.isForced then
		status = 3
		r, g, b = 1, 0, 0
		self:Show()
	end

	local tdb = db.threat
	local customEnable = tdb and tdb.enable

	if status and status > 1 then
		if db.threatStyle == "GLOW" then
			self.glow:Show()
			self.glow:SetBackdropBorderColor(r, g, b)

			if parent.USE_POWERBAR_OFFSET then
				self.powerGlow:Show()
				self.powerGlow:SetBackdropBorderColor(r, g, b)
			end
		elseif db.threatStyle == "BORDERS" then
			parent.Health.backdrop:SetBackdropBorderColor(r, g, b)

			if parent.Power and parent.Power.backdrop then
				parent.Power.backdrop:SetBackdropBorderColor(r, g, b)
			end

			if parent.ClassBar and parent[parent.ClassBar] and parent[parent.ClassBar].backdrop then
				parent[parent.ClassBar].backdrop:SetBackdropBorderColor(r, g, b)
			end

			if parent.InfoPanel and parent.InfoPanel.backdrop then
				parent.InfoPanel.backdrop:SetBackdropBorderColor(r, g, b)
			end
		elseif db.threatStyle == "HEALTHBORDER" then
			parent.Health.backdrop:SetBackdropBorderColor(r, g, b)
		elseif db.threatStyle == "INFOPANELBORDER" then
			parent.InfoPanel.backdrop:SetBackdropBorderColor(r, g, b)
		elseif db.threatStyle ~= "NONE" and self.texIcon then
			self.texIcon:Show()
			self.texIcon:SetVertexColor(r, g, b)
		end

		if customEnable then
			self.texIcon:Show()
			self.texIcon:SetVertexColor(r, g, b)

			local count = parent.isForced and 3 or GetThreatCount(unit)
			local countText = count > 0 and count or 1
			self.text:SetText(countText)
			self.text:Show()
		else
			if self.text then self.text:Hide() end
		end
	else
		r, g, b = unpack(E.media.unitframeBorderColor)
		if db.threatStyle == "GLOW" then
			self.glow:Hide()
			self.powerGlow:Hide()
		elseif db.threatStyle == "BORDERS" then
			parent.Health.backdrop:SetBackdropBorderColor(r, g, b)

			if parent.Power and parent.Power.backdrop then
				parent.Power.backdrop:SetBackdropBorderColor(r, g, b)
			end

			if parent.ClassBar and parent[parent.ClassBar] and parent[parent.ClassBar].backdrop then
				parent[parent.ClassBar].backdrop:SetBackdropBorderColor(r, g, b)
			end

			if parent.InfoPanel and parent.InfoPanel.backdrop then
				parent.InfoPanel.backdrop:SetBackdropBorderColor(r, g, b)
			end
		elseif db.threatStyle == "HEALTHBORDER" then
			parent.Health.backdrop:SetBackdropBorderColor(r, g, b)
		elseif db.threatStyle == "INFOPANELBORDER" then
			parent.InfoPanel.backdrop:SetBackdropBorderColor(r, g, b)
		elseif db.threatStyle ~= "NONE" and self.texIcon then
			self.texIcon:Hide()
		end

		if customEnable then
			self.texIcon:Hide()
			if self.text then self.text:Hide() end
		else
			if self.text then self.text:Hide() end
		end
	end
end

local function UpdateThreatOnFrame(frame)
	if frame and frame.Health then
		UF:Configure_Threat(frame)
		if frame:IsElementEnabled("ThreatIndicator") then
			frame:UpdateElement("ThreatIndicator")
		end
	end
end

function UF:UpdateThreatSettings(group)
	local header = self[group]
	if not header then return end

	for i = 1, header:GetNumChildren() do
		local child = select(i, header:GetChildren())
		if child then
			if child.Health then
				UpdateThreatOnFrame(child)
			else
				for j = 1, child:GetNumChildren() do
					local grandChild = select(j, child:GetChildren())
					UpdateThreatOnFrame(grandChild)
				end
			end
		end
	end
end