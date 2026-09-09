local E, L, V, P, G = unpack(select(2, ...)); --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local PF = E:NewModule("Profiler")
E.Profiler = PF

--Lua functions
local collectgarbage = collectgarbage
local floor, max, min = math.floor, math.max, math.min
local format = string.format
local ipairs, pairs, next, type, tostring = ipairs, pairs, next, type, tostring
local tinsert, tsort, tconcat = table.insert, table.sort, table.concat
--WoW API / Variables
local CreateFrame = CreateFrame
local GetAddOnCPUUsage = GetAddOnCPUUsage
local GetAddOnMemoryUsage = GetAddOnMemoryUsage
local GetCVar = GetCVar
local GetFramerate = GetFramerate
local GetNumPartyMembers = GetNumPartyMembers
local GetNumRaidMembers = GetNumRaidMembers
local GetRealZoneText = GetRealZoneText
local GetTime = GetTime
local UpdateAddOnCPUUsage = UpdateAddOnCPUUsage
local UpdateAddOnMemoryUsage = UpdateAddOnMemoryUsage

-- High resolution timer (ms); falls back to GetTime if the client lacks it
local dpstop = debugprofilestop or function() return GetTime() * 1000 end

--[[
	Lightweight in-game profiler (/eperf)

	Turn it on for a dungeon/raid session, turn it off, and export the report.
	It answers "what exactly is eating my frame time" with four data sources:

	1. Function wrappers around the known-hot ElvUI paths (absorb engine, chat
	   pipeline, aura tracker, party damage). Wall-clock ms via debugprofilestop,
	   works without any CVar.
	2. Event storm counters: every event that fires is counted (one table
	   increment per event) - the top offenders list shows what the client is
	   actually spamming at the UI.
	3. Lua garbage churn: collectgarbage("count") sampled every 0.5s; the sum of
	   positive deltas approximates allocation rate (KB/s) - GC spikes are what
	   cause periodic stutter.
	4. Blizzard CPU profiling (only if the scriptProfile CVar is enabled):
	   per-addon CPU totals for the whole session.

	Commands:
	  /eperf start  - begin a session
	  /eperf stop   - end the session and build the report
	  /eperf show   - open the report window (copy with Ctrl-C, send it away)
	  /eperf        - toggle start/stop
]]

local session = {
	running = false,
	startTime = 0,
	stopTime = 0,
	-- fps
	fpsSamples = 0, fpsSum = 0, fpsMin = 9999,
	-- memory
	lastMem = 0, churnSum = 0, churnPeak = 0, churnSamples = 0,
	memAtStart = 0,
	-- events
	eventCounts = {},
	eventTotal = 0,
	-- wrapped functions
	stats = {},
	-- cpu (scriptProfile)
	cpuProfiling = false,
	addonCPUStart = {},
}

PF.session = session

----------------------------------------------------------------------------
-- Function wrapping
----------------------------------------------------------------------------
-- Wrap targets are resolved through their owner tables at call time, so
-- replacing owner[key] intercepts all future calls and can be undone cleanly.
local function BuildWatchList()
	local list = {
		{owner = E.AbsorbEngine, key = "GetUnitShields", label = "AbsorbEngine:GetUnitShields"},
	}

	local CH = E:GetModule("Chat", true)
	if CH then
		tinsert(list, {owner = CH, key = "CheckKeyword", label = "Chat:CheckKeyword"})
		tinsert(list, {owner = CH, key = "GetSmileyReplacementText", label = "Chat:SmileyReplacement"})
		tinsert(list, {owner = CH, key = "FindURL", label = "Chat:FindURL (unregistered path)"})
		tinsert(list, {owner = CH, key = "SaveChatHistory", label = "Chat:SaveChatHistory"})
	end

	local AT = E.AuraTracker
	if AT then
		tinsert(list, {owner = AT, key = "ScanUnitAuras", label = "AuraTracker:ScanUnitAuras"})
	end

	local PD = E:GetModule("PartyDamage", true)
	if PD then
		tinsert(list, {owner = PD, key = "COMBAT_LOG_EVENT_UNFILTERED", label = "PartyDamage:CLEU"})
		tinsert(list, {owner = PD, key = "ProcessDamage", label = "PartyDamage:ProcessDamage"})
	end

	local UF = E:GetModule("UnitFrames", true)
	if UF then
		tinsert(list, {owner = UF, key = "ApplyRoleNameList", label = "UnitFrames:RoleSort"})
	end

	return list
end

local wrapped = {}

local function WrapAll()
	local list = BuildWatchList()
	for _, item in ipairs(list) do
		local owner, key = item.owner, item.key
		if owner and type(owner[key]) == "function" then
			local original = owner[key]
			local stat = {label = item.label, calls = 0, total = 0, maxTime = 0}
			session.stats[item.label] = stat

			owner[key] = function(...)
				local before = dpstop()
				local a, b, c, d, e, f = original(...)
				local elapsed = dpstop() - before
				stat.calls = stat.calls + 1
				stat.total = stat.total + elapsed
				if elapsed > stat.maxTime then stat.maxTime = elapsed end
				return a, b, c, d, e, f
			end

			tinsert(wrapped, {owner = owner, key = key, original = original})
		end
	end
end

local function UnwrapAll()
	for _, item in ipairs(wrapped) do
		item.owner[item.key] = item.original
	end
	for i = #wrapped, 1, -1 do wrapped[i] = nil end
end

----------------------------------------------------------------------------
-- Collectors
----------------------------------------------------------------------------
local eventCounter -- frame with RegisterAllEvents, created on demand
local sampler -- OnUpdate frame for fps + memory sampling

local function EnsureFrames()
	if not eventCounter then
		eventCounter = CreateFrame("Frame")
		eventCounter:Hide()
		eventCounter:SetScript("OnEvent", function(_, event)
			session.eventCounts[event] = (session.eventCounts[event] or 0) + 1
			session.eventTotal = session.eventTotal + 1
		end)
	end

	if not sampler then
		sampler = CreateFrame("Frame")
		sampler:Hide()
		sampler.acc = 0
		sampler:SetScript("OnUpdate", function(self, elapsed)
			self.acc = self.acc + elapsed
			if self.acc < 0.5 then return end
			self.acc = 0

			local fps = GetFramerate()
			session.fpsSamples = session.fpsSamples + 1
			session.fpsSum = session.fpsSum + fps
			if fps < session.fpsMin then session.fpsMin = fps end

			local mem = collectgarbage("count")
			local delta = mem - session.lastMem
			session.lastMem = mem
			if delta > 0 then
				session.churnSum = session.churnSum + delta
				session.churnSamples = session.churnSamples + 1
				local perSec = delta * 2 -- 0.5s sample
				if perSec > session.churnPeak then session.churnPeak = perSec end
			end
		end)
	end
end

----------------------------------------------------------------------------
-- Session control
----------------------------------------------------------------------------
local ADDON_LIST = {"ElvUI", "ElvUI_OptionsUI", "ElvUI_Enhanced", "ElvUI_AddOnSkins", "ElvUI_PartyDamage", "ElvUI_EnhancedFriendsList", "ElvUI_ExtraActionBars"}

function PF:Start()
	if session.running then
		E:Print("Profiler already running. /eperf stop to finish.")
		return
	end

	-- reset
	session.running = true
	session.startTime = GetTime()
	session.stopTime = 0
	session.fpsSamples, session.fpsSum, session.fpsMin = 0, 0, 9999
	session.churnSum, session.churnPeak, session.churnSamples = 0, 0, 0
	session.eventCounts = {}
	session.eventTotal = 0
	session.stats = {}
	session.lastMem = collectgarbage("count")
	session.report = nil

	UpdateAddOnMemoryUsage()
	session.memAtStart = 0
	for _, addon in ipairs(ADDON_LIST) do
		session.memAtStart = session.memAtStart + (GetAddOnMemoryUsage(addon) or 0)
	end

	session.cpuProfiling = GetCVar("scriptProfile") == "1"
	if session.cpuProfiling then
		UpdateAddOnCPUUsage()
		for _, addon in ipairs(ADDON_LIST) do
			session.addonCPUStart[addon] = GetAddOnCPUUsage(addon) or 0
		end
	end

	EnsureFrames()
	eventCounter:RegisterAllEvents()
	eventCounter:Show()
	sampler.acc = 0
	sampler:Show()

	WrapAll()

	E:Print(format("Profiler started (%s). Play the content you want measured, then /eperf stop.", session.cpuProfiling and "with CPU profiling" or "wall-clock mode; enable the scriptProfile CVar + reload for per-addon CPU"))
end

local BuildReport -- fwd

function PF:Stop()
	if not session.running then
		E:Print("Profiler is not running. /eperf start to begin.")
		return
	end

	session.running = false
	session.stopTime = GetTime()

	eventCounter:UnregisterAllEvents()
	eventCounter:Hide()
	sampler:Hide()

	UnwrapAll()

	session.report = BuildReport()
	E.global.profilerLastReport = session.report -- also persisted to SavedVariables at logout

	E:Print("Profiler stopped. /eperf show to view and copy the report.")
	PF:Show()
end

----------------------------------------------------------------------------
-- Report
----------------------------------------------------------------------------
BuildReport = function()
	local out = {}
	local duration = max(session.stopTime - session.startTime, 0.001)

	local groupSize, groupType
	if GetNumRaidMembers() > 0 then
		groupSize, groupType = GetNumRaidMembers(), "raid"
	elseif GetNumPartyMembers() > 0 then
		groupSize, groupType = GetNumPartyMembers() + 1, "party"
	else
		groupSize, groupType = 1, "solo"
	end

	tinsert(out, "== ElvUI Profiler Report ==")
	tinsert(out, format("Duration: %.0fs | Zone: %s | Group: %s (%d)", duration, GetRealZoneText() or "?", groupType, groupSize))
	tinsert(out, format("Date: %s | ElvUI %s", date("%Y-%m-%d %H:%M"), E.version or "?"))
	tinsert(out, "")

	-- fps + memory
	local avgFps = session.fpsSamples > 0 and (session.fpsSum / session.fpsSamples) or 0
	local churnRate = session.churnSum / duration
	tinsert(out, format("FPS: avg %.1f | min %.1f", avgFps, session.fpsMin == 9999 and 0 or session.fpsMin))
	tinsert(out, format("Lua garbage: %.0f KB/s average | %.0f KB/s peak | %.1f MB total churned", churnRate, session.churnPeak, session.churnSum / 1024))

	UpdateAddOnMemoryUsage()
	local memNow = 0
	for _, addon in ipairs(ADDON_LIST) do
		memNow = memNow + (GetAddOnMemoryUsage(addon) or 0)
	end
	tinsert(out, format("ElvUI suite memory: %.1f MB (%+.1f MB during session)", memNow / 1024, (memNow - session.memAtStart) / 1024))
	tinsert(out, "")

	-- wrapped functions
	tinsert(out, "-- Instrumented functions (wall-clock) --")
	local statList = {}
	for _, stat in pairs(session.stats) do
		if stat.calls > 0 then tinsert(statList, stat) end
	end
	tsort(statList, function(a, b) return a.total > b.total end)
	if #statList == 0 then
		tinsert(out, "(no calls recorded)")
	else
		tinsert(out, format("%-38s %9s %10s %9s %9s", "function", "calls", "total ms", "avg us", "max ms"))
		for _, stat in ipairs(statList) do
			tinsert(out, format("%-38s %9d %10.1f %9.1f %9.2f",
				stat.label, stat.calls, stat.total, (stat.total / stat.calls) * 1000, stat.maxTime))
		end
	end
	tinsert(out, "")

	-- event storms
	tinsert(out, format("-- Top events (%d total, %.0f/sec) --", session.eventTotal, session.eventTotal / duration))
	local events = {}
	for event, count in pairs(session.eventCounts) do
		tinsert(events, {event = event, count = count})
	end
	tsort(events, function(a, b) return a.count > b.count end)
	for i = 1, min(20, #events) do
		local ev = events[i]
		tinsert(out, format("%-42s %9d %8.1f/s", ev.event, ev.count, ev.count / duration))
	end
	tinsert(out, "")

	-- CPU (scriptProfile)
	if session.cpuProfiling then
		tinsert(out, "-- Addon CPU (scriptProfile, ms this session) --")
		UpdateAddOnCPUUsage()
		local cpuList = {}
		for _, addon in ipairs(ADDON_LIST) do
			local total = (GetAddOnCPUUsage(addon) or 0) - (session.addonCPUStart[addon] or 0)
			if total > 0 then tinsert(cpuList, {addon = addon, total = total}) end
		end
		tsort(cpuList, function(a, b) return a.total > b.total end)
		for _, item in ipairs(cpuList) do
			tinsert(out, format("%-30s %12.0f ms (%.1f%% of session)", item.addon, item.total, item.total / (duration * 10)))
		end
	else
		tinsert(out, "(Per-addon CPU numbers unavailable: run '/console scriptProfile 1' and reload,")
		tinsert(out, " profile again, then '/console scriptProfile 0' + reload when done - the CVar")
		tinsert(out, " itself costs 10-30% fps while enabled.)")
	end

	return tconcat(out, "\n")
end

----------------------------------------------------------------------------
-- Report window (copyable)
----------------------------------------------------------------------------
local reportFrame

local function EnsureReportFrame()
	if reportFrame then return end

	reportFrame = CreateFrame("Frame", "ElvUI_ProfilerReport", UIParent)
	reportFrame:SetSize(680, 420)
	reportFrame:SetPoint("CENTER")
	reportFrame:SetFrameStrata("DIALOG")
	reportFrame:SetMovable(true)
	reportFrame:EnableMouse(true)
	reportFrame:RegisterForDrag("LeftButton")
	reportFrame:SetScript("OnDragStart", reportFrame.StartMoving)
	reportFrame:SetScript("OnDragStop", reportFrame.StopMovingOrSizing)
	reportFrame:SetTemplate("Transparent")

	local title = reportFrame:CreateFontString(nil, "OVERLAY")
	title:FontTemplate(nil, 12, "OUTLINE")
	title:SetPoint("TOPLEFT", 10, -8)
	title:SetText("ElvUI Profiler Report - select all (Ctrl-A) and copy (Ctrl-C)")

	local close = CreateFrame("Button", nil, reportFrame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", 2, 2)
	close:SetScript("OnClick", function() reportFrame:Hide() end)

	local scroll = CreateFrame("ScrollFrame", "ElvUI_ProfilerReportScroll", reportFrame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 10, -28)
	scroll:SetPoint("BOTTOMRIGHT", -30, 10)

	local editBox = CreateFrame("EditBox", nil, scroll)
	editBox:SetMultiLine(true)
	editBox:SetFontObject(ChatFontNormal)
	editBox:SetFont("Interface\\AddOns\\ElvUI\\Media\\Fonts\\PTSansNarrow.ttf", 11)
	editBox:SetWidth(620)
	editBox:SetAutoFocus(false)
	editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() reportFrame:Hide() end)
	-- keep the text intact if the user types; re-set on show instead
	scroll:SetScrollChild(editBox)
	reportFrame.editBox = editBox

	reportFrame:Hide()
end

function PF:Show()
	if not session.report and not E.global.profilerLastReport then
		E:Print("No profiler report yet. /eperf start, play, /eperf stop.")
		return
	end
	EnsureReportFrame()
	reportFrame.editBox:SetText(session.report or E.global.profilerLastReport)
	reportFrame:Show()
	reportFrame.editBox:HighlightText()
	reportFrame.editBox:SetFocus()
end

----------------------------------------------------------------------------
-- Slash command
----------------------------------------------------------------------------
SLASH_EPERF1 = "/eperf"
_G.SlashCmdList.EPERF = function(msg)
	msg = (msg or ""):lower():gsub("%s+", "")
	if msg == "start" then
		PF:Start()
	elseif msg == "stop" then
		PF:Stop()
	elseif msg == "show" then
		PF:Show()
	else
		if session.running then PF:Stop() else PF:Start() end
	end
end

function PF:Initialize()
	-- nothing to do until /eperf is used; the module costs nothing while idle
end

E:RegisterModule(PF:GetName())
