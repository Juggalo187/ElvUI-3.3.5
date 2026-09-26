local E, L, V, P, G = unpack(ElvUI_)
local ABS = E:GetModule("ActionBarSaver")

local selectedProfile = ""
local newProfileName = ""
local restoretalents = nil
if string.find(string.lower(E.myrealm or GetRealmName() or ""), "project astral", 1, true) then
		restoretalents = true
	else
		restoretalents = false
end

function ABS.GetOptions()
	local playerClass = select(2, UnitClass("player"))

	local options = {
		type = "group",
		name = "|cff4beb2cAction Bar Saver|r",
		order = 57,
		args = {
			header = {
				order = 1,
				type = "header",
				name = (type(L["Action Bar Saver Profiles"]) == "string" and L["Action Bar Saver Profiles"]) or "Action Bar Saver Profiles",
			},
			settingsGroup = {
				order = 2,
				type = "group",
				name = (type(L["Settings"]) == "string" and L["Settings"]) or "Settings",
				inline = true,
				args = {
					restoreRank = {
						order = 1,
						type = "toggle",
						name = (type(L["Restore Highest Rank"]) == "string" and L["Restore Highest Rank"]) or "Restore Highest Rank",
						get = function() return ABS.db.restoreRank end,
						set = function(_, value) ABS.db.restoreRank = value end,
					},
					macro = {
						order = 2,
						type = "toggle",
						name = (type(L["Auto Restore Macros"]) == "string" and L["Auto Restore Macros"]) or "Auto Restore Macros",
						get = function() return ABS.db.macro end,
						set = function(_, value) ABS.db.macro = value end,
					},
					restoreTalents = {
						order = 3,
						type = "toggle",
						name = (type(L["Auto Restore Talents"]) == "string" and L["Auto Restore Talents"]) or "Auto Restore Talents",
						get = function() return ABS.db.restoreTalents end,
						set = function(_, value) ABS.db.restoreTalents = value end,
						disabled = function() return not restoretalents end
					},
					checkCount = {
						order = 4,
						type = "toggle",
						name = (type(L["Check Item Count"]) == "string" and L["Check Item Count"]) or "Check Item Count",
						get = function() return ABS.db.checkCount end,
						set = function(_, value) ABS.db.checkCount = value end,
					},
				},
			},
			profileGroup = {
				order = 3,
				type = "group",
				name = (type(L["Profile Management"]) == "string" and L["Profile Management"]) or "Profile Management",
				inline = true,
				args = {
					profileInput = {
						order = 1,
						type = "input",
						name = (type(L["New Profile Name"]) == "string" and L["New Profile Name"]) or "New Profile Name",
						get = function() return newProfileName end,
						set = function(_, val) newProfileName = val end,
					},
					saveButton = {
						order = 2,
						type = "execute",
						name = (type(L["Save Profile"]) == "string" and L["Save Profile"]) or "Save Profile",
						func = function()
							if newProfileName ~= "" then
								ABS:SaveProfile(newProfileName)
								newProfileName = ""
							end
						end,
					},
					spacer = {
						order = 3,
						type = "description",
						name = " ",
					},
					profileDropdown = {
						order = 4,
						type = "select",
						name = (type(L["Select Profile"]) == "string" and L["Select Profile"]) or "Select Profile",
						get = function() return selectedProfile end,
						set = function(_, val) selectedProfile = val end,
						values = function()
							local list = {}
							if ABS.db.sets[playerClass] then
								for name in pairs(ABS.db.sets[playerClass]) do
									list[name] = name
								end
							end
							return list
						end,
					},
					restoreButton = {
						order = 5,
						type = "execute",
						name = (type(L["Restore Profile"]) == "string" and L["Restore Profile"]) or "Restore Profile",
						func = function()
							if selectedProfile ~= "" then
								ABS:RestoreProfile(selectedProfile, playerClass)
							end
						end,
					},
					deleteButton = {
						order = 6,
						type = "execute",
						name = (type(L["Delete Profile"]) == "string" and L["Delete Profile"]) or "Delete Profile",
						func = function()
							if selectedProfile ~= "" then
								ABS.db.sets[playerClass][selectedProfile] = nil
								ABS:Print(string.format(L["Deleted saved profile %s."], selectedProfile))
								selectedProfile = ""
							end
						end,
					},
				},
			},
		},
	}

	E.Options.args.ActionBarSaver = options
end