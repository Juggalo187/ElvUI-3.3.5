local E, L, V, P, G = unpack(select(2, ...))
local NP = E:GetModule("NamePlates")
local LSM = E.Libs.LSM

local gsub, format, strfind, strsplit, select, tonumber = gsub, format, strfind, strsplit, select, tonumber
local UnitExists = UnitExists
local UnitLevel = UnitLevel
local GetQuestDifficultyColor = GetQuestDifficultyColor
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local CUSTOM_CLASS_COLORS = CUSTOM_CLASS_COLORS

local legacyHealthTags = {
	{"health:current%-max%-percent%-nostatus", "CURRENT_MAX_PERCENT"},
	{"health:current%-max%-percent", "CURRENT_MAX_PERCENT"},
	{"health:current%-percent%-nostatus", "CURRENT_PERCENT"},
	{"health:current%-percent", "CURRENT_PERCENT"},
	{"health:current%-max%-nostatus", "CURRENT_MAX"},
	{"health:current%-max", "CURRENT_MAX"},
	{"health:percent%-nostatus", "PERCENT"},
	{"health:percent:nostatus", "PERCENT"},
	{"health:percent", "PERCENT"},
	{"health:current", "CURRENT"},
	{"health:max", "MAX"},
	{"perhp", "PERCENT"},
}

function NP:EvalLegacyTag(frame, tagFormat)
	local name = frame.UnitName or ""
	local text = tagFormat or ""
	if text == "" then return name end

	local class = frame.UnitClass
	local classColor = class and (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class] or RAID_CLASS_COLORS[class])
	local hex = (classColor and E:RGBToHex(classColor.r, classColor.g, classColor.b)) or "|cffffffff"
	local abbrev = (name ~= "" and strfind(name, "%s") and E.TagFunctions.Abbrev(name)) or name

	text = gsub(text, "%[classcolor%]", hex)
	text = gsub(text, "%[name:abbrev:veryshort%]", E:ShortenString(abbrev, 5) or "")
	text = gsub(text, "%[name:abbrev:short%]", E:ShortenString(abbrev, 10) or "")
	text = gsub(text, "%[name:abbrev:medium%]", E:ShortenString(abbrev, 15) or "")
	text = gsub(text, "%[name:abbrev:long%]", E:ShortenString(abbrev, 20) or "")
	text = gsub(text, "%[name:abbrev%]", abbrev)
	text = gsub(text, "%[name:veryshort%]", E:ShortenString(name, 5) or "")
	text = gsub(text, "%[name:short%]", E:ShortenString(name, 10) or "")
	text = gsub(text, "%[name:medium%]", E:ShortenString(name, 15) or "")
	text = gsub(text, "%[name:long%]", E:ShortenString(name, 20) or "")
	text = gsub(text, "%[name:last%]", (strfind(name, "%s") and name:match("([%S]+)$")) or name)
	text = gsub(text, "%[name:first%]", (select(1, strsplit(" ", name))) or name)
	text = gsub(text, "%[name%]", name)

	local health = frame.oldHealthBar and frame.oldHealthBar:GetValue() or 0
	local _, maxHealth = frame.oldHealthBar and frame.oldHealthBar:GetMinMaxValues() or 1, 1
	if not maxHealth or maxHealth == 0 then maxHealth = 1 end

	for i = 1, #legacyHealthTags do
		local pattern, style = legacyHealthTags[i][1], legacyHealthTags[i][2]
		text = gsub(text, "%["..pattern.."]", function()
			if style == "MAX" then
				return E:GetFormattedText("CURRENT", maxHealth, maxHealth) or format("%.0f", maxHealth)
			end
			return E:GetFormattedText(style, health, maxHealth) or ""
		end)
	end

	local levelStr = "??"
	local unit = NP:ResolvePlateUnit(frame)
	if unit and UnitExists(unit) then
		local level = UnitLevel(unit)
		levelStr = (level and level > 0) and tostring(level) or "??"
	elseif frame.oldLevel then
		local levelText = frame.oldLevel:GetText()
		levelStr = levelText or "??"
	end

	text = gsub(text, "%[smartlevel%]", levelStr)
	text = gsub(text, "%[level%]", levelStr)

	local diffHex = hex
	if unit and UnitExists(unit) then
		local diffColor = GetQuestDifficultyColor(UnitLevel(unit))
		diffHex = E:RGBToHex(diffColor.r, diffColor.g, diffColor.b)
	end
	text = gsub(text, "%[difficultycolor%]", diffHex)
	text = gsub(text, "%[reactioncolor%]", hex)
	text = gsub(text, "%[classificationcolor%]", hex)
	text = gsub(text, "%[shortclassification%]", frame.BossIcon:IsShown() and "+" or (frame.EliteIcon:IsShown() and "+" or ""))
	text = gsub(text, "%[npctitle%]", (frame.Title and frame.Title.npcTitle) or "")

	text = gsub(text, "%[[^%]]+%]", "")
	return text
end

local function ConfigureTagText(frame, element, db, hide)
	if not element or not db then return end

	if db.enable and not hide then
		element:FontTemplate(LSM:Fetch("font", db.font), db.fontSize, db.fontOutline)
		element:SetText(NP:EvalLegacyTag(frame, db.format))

		local relative = frame
		if db.parent == "Health" and frame.Health then
			relative = frame.Health
		elseif db.parent and db.parent ~= "Nameplate" and frame[db.parent] then
			relative = frame[db.parent]
		end

		element:ClearAllPoints()
		element:Point(E.InversePoints[db.position] or "CENTER", relative, db.position or "CENTER", db.xOffset or 0, db.yOffset or 0)
		element:Show()
	else
		element:Hide()
	end
end

function NP:Update_Tags(frame, hide)
	local db = NP:PlateDB(frame)
	if not db then return end

	if frame.Title then
		ConfigureTagText(frame, frame.Title, db.title, hide)
	end

	if db.name and db.name.format and strfind(db.name.format, "%[") then
		ConfigureTagText(frame, frame.Name, db.name, hide)
	end

	if db.level and db.level.format and strfind(db.level.format, "%[") then
		ConfigureTagText(frame, frame.Level, db.level, hide)
	end

	if db.health and db.health.text and db.health.text.format and strfind(db.health.text.format, "%[") then
		ConfigureTagText(frame, frame.Health.Text, db.health.text, hide)
	end
end

function NP:Construct_Title(frame)
	return frame:CreateFontString(nil, "OVERLAY")
end
