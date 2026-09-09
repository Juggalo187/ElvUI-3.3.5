local E, _, V, P, G = unpack(ElvUI)
local C, L = unpack(select(2, ...))

local function astralMasterDisabled()
	return not E:IsAstralEnabled()
end

local function astralProjectDisabled()
	return astralMasterDisabled() or not E.private.addOnSkins or not E.private.addOnSkins.ProjectAstral
end

E.Options.args.astral = {
	order = 49,
	type = "group",
	name = L["Astral"],
	childGroups = "tab",
	get = function(info)
		local astral = E.private.astral
		if not astral then return true end
		return astral[info[#info]] ~= false
	end,
	set = function(info, value)
		E.private.astral = E.private.astral or {}
		E.private.astral[info[#info]] = value
		E:StaticPopup_Show("PRIVATE_RL")
	end,
	args = {
		intro = {
			order = 1,
			type = "description",
			name = L["ASTRAL_DESC"],
		},
		enable = {
			order = 2,
			type = "toggle",
			name = L["Enable Astral"],
			desc = L["ASTRAL_ENABLE_DESC"],
		},
		coreHeader = {
			order = 3,
			type = "header",
			name = L["Astral Core"],
		},
		gmIcon = {
			order = 4,
			type = "toggle",
			name = L["Astral GM Icon"],
			desc = L["ASTRAL_GM_ICON_DESC"],
			disabled = astralMasterDisabled,
		},
		microButton = {
			order = 5,
			type = "toggle",
			name = L["Astral Micro Button"],
			desc = L["ASTRAL_MICRO_BUTTON_DESC"],
			disabled = astralMasterDisabled,
		},
		projectHeader = {
			order = 10,
			type = "header",
			name = L["Project Astral"],
		},
		projectNote = {
			order = 11,
			type = "description",
			name = L["ASTRAL_PROJECT_NOTE"],
		},
		hub = {
			order = 12,
			type = "toggle",
			name = L["Astral Hub Skin"],
			desc = L["TOGGLESKIN_DESC"],
			disabled = astralProjectDisabled,
		},
		transmog = {
			order = 13,
			type = "toggle",
			name = L["Astral Transmogrify Skin"],
			desc = L["TOGGLESKIN_DESC"],
			disabled = astralProjectDisabled,
		},
		table = {
			order = 13.5,
			type = "toggle",
			name = L["Astral Table Skin"],
			desc = L["TOGGLESKIN_DESC"],
			disabled = astralProjectDisabled,
		},
		minimapButton = {
			order = 14,
			type = "toggle",
			name = L["Astral Minimap Button Skin"],
			desc = L["TOGGLESKIN_DESC"],
			disabled = astralProjectDisabled,
		},
		popups = {
			order = 15,
			type = "toggle",
			name = L["Astral Popup Skin"],
			desc = L["TOGGLESKIN_DESC"],
			disabled = astralProjectDisabled,
		},
	},
}
