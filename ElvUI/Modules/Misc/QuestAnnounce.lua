local E, L, V, P, G = unpack(select(2, ...)) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local M = E:GetModule("Misc")

--Lua functions
local tonumber, tostring = tonumber, tostring
local gsub, find = string.gsub, string.find
local math_fmod = math.fmod

--WoW API / Variables
local GetNumPartyMembers = GetNumPartyMembers
local SendChatMessage = SendChatMessage

function M:SendQuestAnnounceMsg(msg)
	if not msg then return end
	if E.db.general.questAnnounce.enable and GetNumPartyMembers() > 0 then
		SendChatMessage(msg, "PARTY")
	end
	if E.db.general.questAnnounce.debug then
		E:Print("QA DEBUG :: " .. msg)
	end
end

function M:UI_INFO_MESSAGE(_, msg)
	if not msg or not E.db.general.questAnnounce.enable then return end

	local questText = gsub(msg, "(.*):%s*([-%d]+)%s*/%s*([-%d]+)%s*$", "%1", 1)
	if questText ~= msg then
		local _, _, _, iNumItems, iNumNeeded = find(msg, "(.*):%s*([-%d]+)%s*/%s*([-%d]+)%s*$")
		iNumItems = tonumber(iNumItems)
		iNumNeeded = tonumber(iNumNeeded)

		if iNumItems and iNumNeeded then
			local stillNeeded = iNumNeeded - iNumItems
			local every = E.db.general.questAnnounce.every or 0

			if stillNeeded == 0 and every == 0 then
				M:SendQuestAnnounceMsg((L["Completed: "] or "Completed: ") .. msg)
			elseif every > 0 then
				local rem = math_fmod(iNumItems, every)
				if rem == 0 and stillNeeded > 0 then
					M:SendQuestAnnounceMsg((L["Progress: "] or "Progress: ") .. msg)
				elseif stillNeeded == 0 then
					M:SendQuestAnnounceMsg((L["Completed: "] or "Completed: ") .. msg)
				end
			end
		end
	end
end

function M:ToggleQuestAnnounce()
	if E.db.general.questAnnounce.enable then
		self:RegisterEvent("UI_INFO_MESSAGE")
	else
		self:UnregisterEvent("UI_INFO_MESSAGE")
	end
end

function M:LoadQuestAnnounce()
	self:ToggleQuestAnnounce()

	-- Slash Commands
	SLASH_QUESTANNOUNCE1 = "/qa"
	SLASH_QUESTANNOUNCE2 = "/questannounce"
	SlashCmdList["QUESTANNOUNCE"] = function()
		E:ToggleOptionsUI("general,misc")
	end
end
