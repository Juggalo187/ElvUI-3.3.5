local E, L = unpack(select(2, ...)); --Import: Engine, Locales
local B = E:GetModule("Blizzard")

--Lua functions
local _G = _G
--WoW API / Variables
local InCombatLockdown = InCombatLockdown

local numAlwaysUpFrames = 0
local pvpHolder = CreateFrame("Frame", "ElvUI_PvPHolder", E.UIParent)
local alwaysUpFrameLocked = false

local function styleAlwaysUpFrame(id)
	local frame = _G["AlwaysUpFrame"..id]
	local text = _G["AlwaysUpFrame"..id.."Text"]
	local icon = _G["AlwaysUpFrame"..id.."Icon"]
	local dynamic = _G["AlwaysUpFrame"..id.."DynamicIconButton"]

	text:ClearAllPoints()
	text:SetPoint("CENTER", frame, "CENTER", 0, 0)

	icon:ClearAllPoints()
	icon:Point("CENTER", text, "LEFT", -10, -9)

	dynamic:ClearAllPoints()
	dynamic:Point("LEFT", text, "RIGHT", 5, 0)

	-- AlwaysUpFrame1 itself is anchored by lockAlwaysUpFrame() below.
end

-- Blizzard only creates AlwaysUpFrame1 the first time a world state shows up
-- (battlegrounds), long after ElvUI initialized, so the mover anchor and the
-- SetPoint lock have to be applied lazily. Blizzard then re-points it on every
-- WorldStateAlwaysUpFrame_Update; those calls are blocked in combat and blamed
-- on us (ADDON_ACTION_BLOCKED ...AlwaysUpFrame1:SetPoint()), so turn SetPoint
-- into a no-op once the frame is anchored to the mover.
local function lockAlwaysUpFrame()
	if alwaysUpFrameLocked or InCombatLockdown() then return end

	local frame = _G.AlwaysUpFrame1
	if not frame then return end

	frame:ClearAllPoints()
	frame:Point("CENTER", pvpHolder, "CENTER", 0, 5)
	frame.SetPoint = E.noop
	alwaysUpFrameLocked = true
end

local function repositionCaptureBar(id)
	local bar = _G["WorldStateCaptureBar"..id]
	bar:ClearAllPoints()
	bar:Point("TOP", pvpHolder, "BOTTOM", 0, -75)
	bar.SetPoint = E.noop
end

function B:WorldStateAlwaysUpFrame_Update()
	if numAlwaysUpFrames < NUM_ALWAYS_UP_UI_FRAMES then
		for id = numAlwaysUpFrames + 1, NUM_ALWAYS_UP_UI_FRAMES do
			styleAlwaysUpFrame(id)
			numAlwaysUpFrames = id
		end
	end

	lockAlwaysUpFrame()
end

function B:PositionCaptureBar()
	pvpHolder:Size(30, 70)
	pvpHolder:Point("TOP", 0, -4)

	-- Anchor the protected score frame while it is safe to do so and turn its
	-- SetPoint into a no-op afterwards (retried from the update hook below,
	-- because the frame usually does not exist yet at this point).
	lockAlwaysUpFrame()

	hooksecurefunc("WorldStateAlwaysUpFrame_Update", B.WorldStateAlwaysUpFrame_Update)
	hooksecurefunc(ExtendedUI["CAPTUREPOINT"], "create", repositionCaptureBar)

	if NUM_EXTENDED_UI_FRAMES > 0 then
		for id = 1, NUM_EXTENDED_UI_FRAMES do
			repositionCaptureBar(id)
		end
	end

	E:CreateMover(pvpHolder, "PvPMover", L["PvP"], nil, nil, nil, "ALL")
end