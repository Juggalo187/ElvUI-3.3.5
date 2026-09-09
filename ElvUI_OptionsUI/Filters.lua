local E, _, V, P, G = unpack(ElvUI); --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local _, L = unpack(select(2, ...))
local UF = E:GetModule("UnitFrames")

local type, pairs, tonumber, tostring = type, pairs, tonumber, tostring
local gsub, match, format = string.gsub, string.match, string.format

local GetSpellInfo = GetSpellInfo

local quickSearchText, selectedSpell, selectedFilter = ""

local function filterMatch(s,v)
	local m1, m2, m3, m4 = "^"..v.."$", "^"..v..",", ","..v.."$", ","..v..","
	return (match(s, m1) and m1) or (match(s, m2) and m2) or (match(s, m3) and m3) or (match(s, m4) and v..",")
end

local function removePriority(value)
	if not value then return end
	local x,y,z = E.db.unitframe.units,E.db.nameplates.units
	for n, t in pairs(x) do
		if t and t.buffs and t.buffs.priority and t.buffs.priority ~= "" then
			z = filterMatch(t.buffs.priority, E:EscapeString(value))
			if z then E.db.unitframe.units[n].buffs.priority = gsub(t.buffs.priority, z, "") end
		end
		if t and t.debuffs and t.debuffs.priority and t.debuffs.priority ~= "" then
			z = filterMatch(t.debuffs.priority, E:EscapeString(value))
			if z then E.db.unitframe.units[n].debuffs.priority = gsub(t.debuffs.priority, z, "") end
		end
		if t and t.aurabar and t.aurabar.priority and t.aurabar.priority ~= "" then
			z = filterMatch(t.aurabar.priority, E:EscapeString(value))
			if z then E.db.unitframe.units[n].aurabar.priority = gsub(t.aurabar.priority, z, "") end
		end
	end
	for n, t in pairs(y) do
		if t and t.buffs and t.buffs.priority and t.buffs.priority ~= "" then
			z = filterMatch(t.buffs.priority, E:EscapeString(value))
			if z then E.db.nameplates.units[n].buffs.priority = gsub(t.buffs.priority, z, "") end
		end
		if t and t.debuffs and t.debuffs.priority and t.debuffs.priority ~= "" then
			z = filterMatch(t.debuffs.priority, E:EscapeString(value))
			if z then E.db.nameplates.units[n].debuffs.priority = gsub(t.debuffs.priority, z, "") end
		end
	end
end

local FilterResetState = {}

local function UpdateFilterGroup()
	--Prevent errors when choosing a new filter, by doing a reset of the groups
	E.Options.args.filters.args.filterGroup = nil
	E.Options.args.filters.args.spellGroup = nil
	E.Options.args.filters.args.resetGroup = nil
	E.Options.args.filters.childGroups = nil
	if UpdateRecentAurasGroup then UpdateRecentAurasGroup() end

	if selectedFilter == "Debuff Highlight" then
		E.Options.args.filters.args.filterGroup = {
			order = 10,
			type = "group",
			name = selectedFilter,
			guiInline = true,
			args = {
				addSpell = {
					order = 1,
					type = "input",
					name = L["Add Spell ID or Name"],
					desc = L["Add a spell to the filter. Use spell ID if you don't want to match all auras which share the same name."],
					get = function(info) return "" end,
					set = function(info, value)
						if tonumber(value) then value = tonumber(value) end
						E.global.unitframe.DebuffHighlightColors[value] = {enable = true, style = "GLOW", color = {r = 0.8, g = 0, b = 0, a = 0.85}}
						UpdateFilterGroup()
						UF:Update_AllFrames()
					end
				},
				removeSpell = {
					order = 2,
					type = "execute",
					name = L["Remove Spell"],
					desc = L["Remove a spell from the filter. Use the spell ID if you see the ID as part of the spell name in the filter."],
					func = function()
						local value = selectedSpell:match(" %((%d+)%)$") or selectedSpell
						if tonumber(value) then value = tonumber(value) end
						E.global.unitframe.DebuffHighlightColors[value] = nil
						selectedSpell = nil
						UpdateFilterGroup()
						UF:Update_AllFrames()
					end,
					disabled = function() return not (selectedSpell and selectedSpell ~= "") end
				},
				quickSearch = {
					order = 3,
					type = "input",
					name = L["Filter Search"],
					desc = L["Search for a spell name inside of a filter."],
					get = function() return quickSearchText end,
					set = function(info,value) quickSearchText = value end
				},
				selectSpell = {
					order = 10,
					type = "select",
					name = L["Select Spell"],
					width = "double",
					guiInline = true,
					get = function(info) return selectedSpell end,
					set = function(info, value) selectedSpell = value UpdateFilterGroup() end,
					values = function()
						local filters = {}
						local list = E.global.unitframe.DebuffHighlightColors
						if not list then return end
						local searchText = quickSearchText:lower()
						for filter in pairs(list) do
							if tonumber(filter) then
								local spellName = GetSpellInfo(filter)
								if spellName then
									filter = format("%s (%s)", spellName, filter)
								else
									filter = tostring(filter)
								end
							end
							if filter:lower():find(searchText) then filters[filter] = filter end
						end
						if not next(filters) then filters[""] = L["NONE"] end
						return filters
					end
				}
			}
		}

		E.Options.args.filters.args.resetGroup = {
			order = 25,
			type = "group",
			name = L["Reset Filter"],
			guiInline = true,
			args = {
				enableReset = {
					order = 1,
					type = "toggle",
					name = L["Enable"],
					get = function(info) return FilterResetState[selectedFilter] end,
					set = function(info, value)
						FilterResetState[selectedFilter] = value
						E.Options.args.filters.args.resetGroup.args.resetFilter.disabled = (not value)
					end
				},
				resetFilter = {
					order = 2,
					type = "execute",
					name = L["Reset Filter"],
					desc = L["This will reset the contents of this filter back to default. Any spell you have added to this filter will be removed."],
					disabled = function() return not FilterResetState[selectedFilter] end,
					func = function(info)
						E.global.unitframe.DebuffHighlightColors = E:CopyTable({}, G.unitframe.DebuffHighlightColors)
						selectedSpell = nil
						UpdateFilterGroup()
						UF:Update_AllFrames()
					end
				}
			}
		}

		local spellID = selectedSpell and match(selectedSpell, "(%d+)")
		if spellID then spellID = tonumber(spellID) end

		if not selectedSpell or E.global.unitframe.DebuffHighlightColors[(spellID or selectedSpell)] == nil then
			E.Options.args.filters.args.spellGroup = nil
			return
		end

		E.Options.args.filters.args.spellGroup = {
			order = 15,
			type = "group",
			name = selectedSpell,
			guiInline = true,
			args = {
				enabled = {
					order = 0,
					type = "toggle",
					name = L["Enable"],
					get = function(info)
						return E.global.unitframe.DebuffHighlightColors[(spellID or selectedSpell)].enable
					end,
					set = function(info, value)
						E.global.unitframe.DebuffHighlightColors[(spellID or selectedSpell)].enable = value
						UF:Update_AllFrames()
					end
				},
				style = {
					order = 3,
					type = "select",
					name = L["Style"],
					values = {
						["GLOW"] = L["Glow"],
						["FILL"] = L["Fill"]
					},
					get = function(info)
						return E.global.unitframe.DebuffHighlightColors[(spellID or selectedSpell)].style
					end,
					set = function(info, value)
						E.global.unitframe.DebuffHighlightColors[(spellID or selectedSpell)].style = value
						UF:Update_AllFrames()
					end
				},
				color = {
					order = 1,
					type = "color",
					name = L["COLOR"],
					hasAlpha = true,
					get = function(info)
						local t = E.global.unitframe.DebuffHighlightColors[(spellID or selectedSpell)].color
						return t.r, t.g, t.b, t.a
					end,
					set = function(info, r, g, b, a)
						local t = E.global.unitframe.DebuffHighlightColors[(spellID or selectedSpell)].color
						t.r, t.g, t.b, t.a = r, g, b, a
						UF:Update_AllFrames()
					end
				}
			}
		}
	elseif selectedFilter == "AuraBar Colors" then
		E.Options.args.filters.args.filterGroup = {
			order = 10,
			type = "group",
			name = selectedFilter,
			guiInline = true,
			args = {
				addSpell = {
					order = 1,
					type = "input",
					name = L["Add Spell ID or Name"],
					desc = L["Add a spell to the filter. Use spell ID if you don't want to match all auras which share the same name."],
					get = function(info) return "" end,
					set = function(info, value)
						if tonumber(value) then value = tonumber(value) end
						if not E.global.unitframe.AuraBarColors[value] then
							E.global.unitframe.AuraBarColors[value] = false
						end
						UpdateFilterGroup()
						UF:CreateAndUpdateUF("player")
						UF:CreateAndUpdateUF("target")
						UF:CreateAndUpdateUF("focus")
					end
				},
				removeSpell = {
					order = 2,
					type = "execute",
					name = L["Remove Spell"],
					desc = L["Remove a spell from the filter. Use the spell ID if you see the ID as part of the spell name in the filter."],
					func = function()
						local value = selectedSpell:match(" %((%d+)%)$") or selectedSpell
						if tonumber(value) then value = tonumber(value) end
						if G.unitframe.AuraBarColors[value] then
							E.global.unitframe.AuraBarColors[value] = false
							E:Print(L["You may not remove a spell from a default filter that is not customly added. Setting spell to false instead."])
						else
							E.global.unitframe.AuraBarColors[value] = nil
						end
						selectedSpell = nil
						UpdateFilterGroup()
						UF:CreateAndUpdateUF("player")
						UF:CreateAndUpdateUF("target")
						UF:CreateAndUpdateUF("focus")
					end,
					disabled = function() return not (selectedSpell and selectedSpell ~= "") end
				},
				quickSearch = {
					order = 3,
					type = "input",
					name = L["Filter Search"],
					desc = L["Search for a spell name inside of a filter."],
					get = function() return quickSearchText end,
					set = function(info,value) quickSearchText = value end
				},
				selectSpell = {
					order = 10,
					type = "select",
					name = L["Select Spell"],
					width = "double",
					guiInline = true,
					get = function(info) return selectedSpell end,
					set = function(info, value)
						selectedSpell = value
						UpdateFilterGroup()
					end,
					values = function()
						local filters = {}
						local list = E.global.unitframe.AuraBarColors
						if not list then return end
						local searchText = quickSearchText:lower()
						for filter in pairs(list) do
							if tonumber(filter) then
								local spellName = GetSpellInfo(filter)
								if spellName then
									filter = format("%s (%s)", spellName, filter)
								else
									filter = tostring(filter)
								end
							end
							if filter:lower():find(searchText) then filters[filter] = filter end
						end
						if not next(filters) then filters[""] = L["NONE"] end
						return filters
					end
				}
			}
		}

		E.Options.args.filters.args.resetGroup = {
			order = 25,
			type = "group",
			name = L["Reset Filter"],
			guiInline = true,
			args = {
				enableReset = {
					order = 1,
					type = "toggle",
					name = L["Enable"],
					get = function(info) return FilterResetState[selectedFilter] end,
					set = function(info, value)
						FilterResetState[selectedFilter] = value
						E.Options.args.filters.args.resetGroup.args.resetFilter.disabled = (not value)
					end
				},
				resetFilter = {
					order = 2,
					type = "execute",
					name = L["Reset Filter"],
					desc = L["This will reset the contents of this filter back to default. Any spell you have added to this filter will be removed."],
					disabled = function() return not FilterResetState[selectedFilter] end,
					func = function(info)
						E.global.unitframe.AuraBarColors = E:CopyTable({}, G.unitframe.AuraBarColors)
						selectedSpell = nil
						UpdateFilterGroup()
						UF:Update_AllFrames()
					end
				}
			}
		}

		local spellID = selectedSpell and match(selectedSpell, "(%d+)")
		if spellID then spellID = tonumber(spellID) end

		if not selectedSpell or E.global.unitframe.AuraBarColors[(spellID or selectedSpell)] == nil then
			E.Options.args.filters.args.spellGroup = nil
			return
		end

		E.Options.args.filters.args.spellGroup = {
			order = 15,
			type = "group",
			name = selectedSpell,
			guiInline = true,
			args = {
				color = {
					order = 1,
					type = "color",
					name = L["COLOR"],
					get = function(info)
						local t = E.global.unitframe.AuraBarColors[(spellID or selectedSpell)]
						if type(t) == "boolean" then
							return 0, 0, 0, 1
						else
							return t.r, t.g, t.b, t.a
						end
					end,
					set = function(info, r, g, b)
						local spell = (spellID or selectedSpell)
						if type(E.global.unitframe.AuraBarColors[spell]) ~= "table" then
							E.global.unitframe.AuraBarColors[spell] = {}
						end
						local t = E.global.unitframe.AuraBarColors[spell]
						t.r, t.g, t.b = r, g, b
						UF:CreateAndUpdateUF("player")
						UF:CreateAndUpdateUF("target")
						UF:CreateAndUpdateUF("focus")
					end
				},
				removeColor = {
					order = 2,
					type = "execute",
					name = L["Restore Defaults"],
					func = function(info)
						E.global.unitframe.AuraBarColors[(spellID or selectedSpell)] = false
						UF:CreateAndUpdateUF("player")
						UF:CreateAndUpdateUF("target")
						UF:CreateAndUpdateUF("focus")
					end
				}
			}
		}
	elseif selectedFilter == "Buff Indicator (Pet)" then
		if not E.global.unitframe.buffwatch.PET then
			E.global.unitframe.buffwatch.PET = {}
		end

		E.Options.args.filters.args.filterGroup = {
			order = 15,
			type = "group",
			name = selectedFilter,
			guiInline = true,
			childGroups = "select",
			args = {
				addSpellID = {
					order = 1,
					type = "input",
					name = L["Add SpellID"],
					desc = L["Add a spell to the filter."],
					get = function(info) return "" end,
					set = function(info, value)
						if not tonumber(value) then
							E:Print(L["Value must be a number"])
						elseif not GetSpellInfo(value) then
							E:Print(L["Not valid spell id"])
						else
							E.global.unitframe.buffwatch.PET[tonumber(value)] = {["enabled"] = true, ["id"] = tonumber(value), ["point"] = "TOPRIGHT", ["color"] = {["r"] = 1, ["g"] = 0, ["b"] = 0}, ["anyUnit"] = true, ["style"] = "coloredIcon", ["xOffset"] = 0, ["yOffset"] = 0}
							selectedSpell = nil
							UpdateFilterGroup()
							UF:CreateAndUpdateUF("pet")
						end
					end
				},
				removeSpellID = {
					order = 2,
					type = "execute",
					name = L["Remove SpellID"],
					desc = L["Remove a spell from the filter."],
					func = function()
						if G.unitframe.buffwatch.PET[selectedSpell] then
							E.global.unitframe.buffwatch.PET[selectedSpell].enabled = false
							E:Print(L["You may not remove a spell from a default filter that is not customly added. Setting spell to false instead."])
						else
							E.global.unitframe.buffwatch.PET[selectedSpell] = nil
						end

						selectedSpell = nil
						UpdateFilterGroup()
						UF:CreateAndUpdateUF("pet")
					end,
					disabled = function() return not selectedSpell end
				},
				quickSearch = {
					order = 3,
					type = "input",
					name = L["Filter Search"],
					desc = L["Search for a spell name inside of a filter."],
					get = function() return quickSearchText end,
					set = function(info,value) quickSearchText = value end
				},
				selectSpell = {
					order = 10,
					type = "select",
					name = L["Select Spell"],
					width = "double",
					values = function()
						local values = {}
						local list = E.global.unitframe.buffwatch.PET
						if not list then return end
						local searchText = quickSearchText:lower()
						for _, spell in pairs(list) do
							if spell.id then
								local name = GetSpellInfo(spell.id)
								if name and name:lower():find(searchText) then values[spell.id] = name end
							end
						end
						return values
					end,
					get = function(info) return selectedSpell end,
					set = function(info, value)
						selectedSpell = value
						UpdateFilterGroup()
					end
				}
			}
		}

		E.Options.args.filters.args.resetGroup = {
			order = 25,
			type = "group",
			name = L["Reset Filter"],
			guiInline = true,
			args = {
				enableReset = {
					order = 1,
					type = "toggle",
					name = L["Enable"],
					get = function(info) return FilterResetState[selectedFilter] end,
					set = function(info, value)
						FilterResetState[selectedFilter] = value
						E.Options.args.filters.args.resetGroup.args.resetFilter.disabled = (not value)
					end
				},
				resetFilter = {
					order = 2,
					type = "execute",
					name = L["Reset Filter"],
					desc = L["This will reset the contents of this filter back to default. Any spell you have added to this filter will be removed."],
					disabled = function() return not FilterResetState[selectedFilter] end,
					func = function(info)
						E.global.unitframe.buffwatch.PET = E:CopyTable({}, G.unitframe.buffwatch.PET)
						selectedSpell = nil
						UpdateFilterGroup()
						UF:Update_AllFrames()
					end
				}
			}
		}

		if selectedSpell then
			local name = GetSpellInfo(selectedSpell)
			if name then
				E.Options.args.filters.args.filterGroup.args[name] = {
					order = -10,
					type = "group",
					name = name.." ("..selectedSpell..")",
					get = function(info) return E.global.unitframe.buffwatch.PET[selectedSpell][info[#info]] end,
					set = function(info, value) E.global.unitframe.buffwatch.PET[selectedSpell][info[#info]] = value UF:CreateAndUpdateUF("pet") end,
					args = {
						enabled = {
							order = 0,
							type = "toggle",
							name = L["Enable"],
						},
						point = {
							order = 1,
							type = "select",
							name = L["Anchor Point"],
							values = {
								["TOPLEFT"] = "TOPLEFT",
								["TOPRIGHT"] = "TOPRIGHT",
								["BOTTOMLEFT"] = "BOTTOMLEFT",
								["BOTTOMRIGHT"] = "BOTTOMRIGHT",
								["LEFT"] = "LEFT",
								["RIGHT"] = "RIGHT",
								["TOP"] = "TOP",
								["BOTTOM"] = "BOTTOM"
							}
						},
						sizeOverride = {
							order = 2,
							type = "range",
							name = L["Size Override"],
							min = 0, max = 50, step = 1
						},
						xOffset = {
							order = 3,
							type = "range",
							name = L["xOffset"],
							min = -75, max = 75, step = 1
						},
						yOffset = {
							order = 4,
							type = "range",
							name = L["yOffset"],
							min = -75, max = 75, step = 1
						},
						style = {
							order = 5,
							type = "select",
							name = L["Style"],
							values = {
								["coloredIcon"] = L["Colored Icon"],
								["texturedIcon"] = L["Textured Icon"],
								["NONE"] = L["NONE"]
							}
						},
						color = {
							order = 6,
							type = "color",
							name = L["COLOR"],
							get = function(info)
								local t = E.global.unitframe.buffwatch.PET[selectedSpell][info[#info]]
								return t.r, t.g, t.b, t.a
							end,
							set = function(info, r, g, b)
								local t = E.global.unitframe.buffwatch.PET[selectedSpell][info[#info]]
								t.r, t.g, t.b = r, g, b
								UF:CreateAndUpdateUF("pet")
							end
						},
						displayText = {
							order = 7,
							type = "toggle",
							name = L["Display Text"]
						},
						textColor = {
							order = 8,
							type = "color",
							name = L["Text Color"],
							get = function(info)
								local t = E.global.unitframe.buffwatch.PET[selectedSpell][info[#info]]
								if t then
									return t.r, t.g, t.b, t.a
								else
									return 1, 1, 1, 1
								end
							end,
							set = function(info, r, g, b)
								local t = E.global.unitframe.buffwatch.PET[selectedSpell][info[#info]]
								t.r, t.g, t.b = r, g, b
								UF:CreateAndUpdateUF("pet")
							end
						},
						decimalThreshold = {
							order = 9,
							type = "range",
							name = L["Decimal Threshold"],
							desc = L["Threshold before text goes into decimal form. Set to -1 to disable decimals."],
							min = -1, max = 10, step = 1
						},
						textThreshold = {
							order = 10,
							type = "range",
							name = L["Text Threshold"],
							desc = L["At what point should the text be displayed. Set to -1 to disable."],
							min = -1, max = 60, step = 1
						},
						anyUnit = {
							order = 11,
							type = "toggle",
							name = L["Show Aura From Other Players"]
						},
						onlyShowMissing = {
							order = 12,
							type = "toggle",
							name = L["Show When Not Active"]
						}
					}
				}
			else
				E:Print(L["Not valid spell id"])
			end
		end
	elseif selectedFilter == "Buff Indicator" then
		if not E.global.unitframe.buffwatch[E.myclass] then
			E.global.unitframe.buffwatch[E.myclass] = {}
		end

		E.Options.args.filters.args.filterGroup = {
			order = 15,
			type = "group",
			name = selectedFilter,
			guiInline = true,
			childGroups = "select",
			args = {
				addSpellID = {
					order = 1,
					type = "input",
					name = L["Add SpellID"],
					desc = L["Add a spell to the filter."],
					get = function(info) return "" end,
					set = function(info, value)
						if not tonumber(value) then
							E:Print(L["Value must be a number"])
						elseif not GetSpellInfo(value) then
							E:Print(L["Not valid spell id"])
						else
							E.global.unitframe.buffwatch[E.myclass][tonumber(value)] = {["enabled"] = true, ["id"] = tonumber(value), ["point"] = "TOPRIGHT", ["color"] = {["r"] = 1, ["g"] = 0, ["b"] = 0}, ["anyUnit"] = false, ["style"] = "coloredIcon", ["xOffset"] = 0, ["yOffset"] = 0}
							selectedSpell = nil
							UpdateFilterGroup()

							UF:UpdateAuraWatchFromHeader("raid")
							UF:UpdateAuraWatchFromHeader("raid40")
							UF:UpdateAuraWatchFromHeader("party")
							UF:UpdateAuraWatchFromHeader("raidpet", true)
						end
					end
				},
				removeSpellID = {
					order = 2,
					type = "execute",
					name = L["Remove SpellID"],
					desc = L["Remove a spell from the filter."],
					func = function()
						if E.global.unitframe.buffwatch[E.myclass][selectedSpell] then
							E.global.unitframe.buffwatch[E.myclass][selectedSpell].enabled = false
							E:Print(L["You may not remove a spell from a default filter that is not customly added. Setting spell to false instead."])
						else
							E.global.unitframe.buffwatch[E.myclass][selectedSpell] = nil
						end

						selectedSpell = nil
						UpdateFilterGroup()
						UF:UpdateAuraWatchFromHeader("raid")
						UF:UpdateAuraWatchFromHeader("raid40")
						UF:UpdateAuraWatchFromHeader("party")
						UF:UpdateAuraWatchFromHeader("raidpet", true)
					end,
					disabled = function() return not selectedSpell end
				},
				quickSearch = {
					order = 3,
					type = "input",
					name = L["Filter Search"],
					desc = L["Search for a spell name inside of a filter."],
					get = function() return quickSearchText end,
					set = function(info,value) quickSearchText = value end
				},
				selectSpell = {
					order = 10,
					type = "select",
					name = L["Select Spell"],
					width = "double",
					values = function()
						local values = {}
						local list = E.global.unitframe.buffwatch[E.myclass]
						if not list then return end
						local searchText = quickSearchText:lower()
						for _, spell in pairs(list) do
							if spell.id then
								local name = GetSpellInfo(spell.id)
								if name and name:lower():find(searchText) then values[spell.id] = name end
							end
						end
						return values
					end,
					get = function(info) return selectedSpell end,
					set = function(info, value)
						selectedSpell = value
						UpdateFilterGroup()
					end
				}
			}
		}

		E.Options.args.filters.args.resetGroup = {
			order = 25,
			type = "group",
			name = L["Reset Filter"],
			guiInline = true,
			args = {
				enableReset = {
					order = 1,
					type = "toggle",
					name = L["Enable"],
					get = function(info) return FilterResetState[selectedFilter] end,
					set = function(info, value)
						FilterResetState[selectedFilter] = value
						E.Options.args.filters.args.resetGroup.args.resetFilter.disabled = (not value)
					end
				},
				resetFilter = {
					order = 2,
					type = "execute",
					name = L["Reset Filter"],
					desc = L["This will reset the contents of this filter back to default. Any spell you have added to this filter will be removed."],
					disabled = function() return not FilterResetState[selectedFilter] end,
					func = function(info)
						E.global.unitframe.buffwatch[E.myclass] = E:CopyTable({}, G.unitframe.buffwatch[E.myclass])
						selectedSpell = nil
						UpdateFilterGroup()
						UF:Update_AllFrames()
					end
				}
			}
		}

		if selectedSpell then
			local name = GetSpellInfo(selectedSpell)
			E.Options.args.filters.args.filterGroup.args[name] = {
				order = -10,
				type = "group",
				name = name.." ("..selectedSpell..")",
				get = function(info) return E.global.unitframe.buffwatch[E.myclass][selectedSpell][info[#info]] end,
				set = function(info, value)
					E.global.unitframe.buffwatch[E.myclass][selectedSpell][info[#info]] = value

					UF:UpdateAuraWatchFromHeader("raid")
					UF:UpdateAuraWatchFromHeader("raid40")
					UF:UpdateAuraWatchFromHeader("party")
					UF:UpdateAuraWatchFromHeader("raidpet", true)
				end,
				args = {
					enabled = {
						order = 0,
						type = "toggle",
						name = L["Enable"]
					},
					point = {
						order = 1,
						type = "select",
						name = L["Anchor Point"],
						values = {
							["TOPLEFT"] = "TOPLEFT",
							["TOPRIGHT"] = "TOPRIGHT",
							["BOTTOMLEFT"] = "BOTTOMLEFT",
							["BOTTOMRIGHT"] = "BOTTOMRIGHT",
							["LEFT"] = "LEFT",
							["RIGHT"] = "RIGHT",
							["TOP"] = "TOP",
							["BOTTOM"] = "BOTTOM"
						}
					},
					sizeOverride = {
						order = 2,
						type = "range",
						name = L["Size Override"],
						min = 0, max = 50, step = 1
					},
					xOffset = {
						order = 3,
						type = "range",
						name = L["xOffset"],
						min = -75, max = 75, step = 1
					},
					yOffset = {
						order = 4,
						type = "range",
						name = L["yOffset"],
						min = -75, max = 75, step = 1
					},
					style = {
						order = 5,
						type = "select",
						name = L["Style"],
						values = {
							["coloredIcon"] = L["Colored Icon"],
							["texturedIcon"] = L["Textured Icon"],
							["NONE"] = L["NONE"]
						}
					},
					color = {
						order = 6,
						type = "color",
						name = L["COLOR"],
						get = function(info)
							local t = E.global.unitframe.buffwatch[E.myclass][selectedSpell][info[#info]]
							return t.r, t.g, t.b, t.a
						end,
						set = function(info, r, g, b)
							local t = E.global.unitframe.buffwatch[E.myclass][selectedSpell][info[#info]]
							t.r, t.g, t.b = r, g, b
							UF:UpdateAuraWatchFromHeader("raid")
							UF:UpdateAuraWatchFromHeader("raid40")
							UF:UpdateAuraWatchFromHeader("party")
							UF:UpdateAuraWatchFromHeader("raidpet", true)
						end
					},
					displayText = {
						order = 7,
						type = "toggle",
						name = L["Display Text"]
					},
					textColor = {
						order = 8,
						type = "color",
						name = L["Text Color"],
						get = function(info)
							local t = E.global.unitframe.buffwatch[E.myclass][selectedSpell][info[#info]]
							if t then
								return t.r, t.g, t.b, t.a
							else
								return 1, 1, 1, 1
							end
						end,
						set = function(info, r, g, b)
							E.global.unitframe.buffwatch[E.myclass][selectedSpell].textColor = E.global.unitframe.buffwatch[E.myclass][selectedSpell].textColor or {}
							local t = E.global.unitframe.buffwatch[E.myclass][selectedSpell].textColor
							t.r, t.g, t.b = r, g, b
							UF:UpdateAuraWatchFromHeader("raid")
							UF:UpdateAuraWatchFromHeader("raid40")
							UF:UpdateAuraWatchFromHeader("party")
							UF:UpdateAuraWatchFromHeader("raidpet", true)
						end
					},
					decimalThreshold = {
						order = 9,
						type = "range",
						name = L["Decimal Threshold"],
						desc = L["Threshold before text goes into decimal form. Set to -1 to disable decimals."],
						min = -1, max = 10, step = 1
					},
					textThreshold = {
						order = 10,
						type = "range",
						name = L["Text Threshold"],
						desc = L["At what point should the text be displayed. Set to -1 to disable."],
						min = -1, max = 60, step = 1
					},
					anyUnit = {
						order = 11,
						type = "toggle",
						name = L["Show Aura From Other Players"]
					},
					onlyShowMissing = {
						order = 12,
						type = "toggle",
						name = L["Show When Not Active"]
					}
				}
			}
		end
	elseif selectedFilter == "Buff Indicator (Profile)" then
		E.Options.args.filters.args.filterGroup = {
			order = 15,
			type = "group",
			name = selectedFilter,
			guiInline = true,
			childGroups = "select",
			args = {
				addSpellID = {
					order = 1,
					type = "input",
					name = L["Add SpellID"],
					desc = L["Add a spell to the filter."],
					get = function(info) return "" end,
					set = function(info, value)
						if not tonumber(value) then
							E:Print(L["Value must be a number"])
						elseif not GetSpellInfo(value) then
							E:Print(L["Not valid spell id"])
						else
							E.db.unitframe.filters.buffwatch[tonumber(value)] = {["enabled"] = true, ["id"] = tonumber(value), ["point"] = "TOPRIGHT", ["color"] = {["r"] = 1, ["g"] = 0, ["b"] = 0}, ["anyUnit"] = false, ["style"] = "coloredIcon", ["xOffset"] = 0, ["yOffset"] = 0}
							selectedSpell = nil
							UpdateFilterGroup()

							UF:UpdateAuraWatchFromHeader("raid")
							UF:UpdateAuraWatchFromHeader("raid40")
							UF:UpdateAuraWatchFromHeader("party")
						end
					end
				},
				removeSpellID = {
					order = 2,
					type = "execute",
					name = L["Remove SpellID"],
					desc = L["Remove a spell from the filter."],
					func = function()
						if P.unitframe.filters.buffwatch[selectedSpell] then
							E.db.unitframe.filters.buffwatch[selectedSpell].enabled = false
							E:Print(L["You may not remove a spell from a default filter that is not customly added. Setting spell to false instead."])
						else
							E.db.unitframe.filters.buffwatch[selectedSpell] = nil
						end

						selectedSpell = nil
						UpdateFilterGroup()
						UF:UpdateAuraWatchFromHeader("raid")
						UF:UpdateAuraWatchFromHeader("raid40")
						UF:UpdateAuraWatchFromHeader("party")
					end,
					disabled = function() return not selectedSpell end
				},
				quickSearch = {
					order = 3,
					type = "input",
					name = L["Filter Search"],
					desc = L["Search for a spell name inside of a filter."],
					get = function() return quickSearchText end,
					set = function(info,value) quickSearchText = value end
				},
				selectSpell = {
					order = 10,
					type = "select",
					name = L["Select Spell"],
					width = "double",
					values = function()
						local values = {}
						local list = E.db.unitframe.filters.buffwatch
						if not list then return end
						local searchText = quickSearchText:lower()
						for _, spell in pairs(list) do
							if spell.id then
								local name = GetSpellInfo(spell.id)
								if name:lower():find(searchText) then values[spell.id] = name end
							end
						end
						return values
					end,
					get = function(info) return selectedSpell end,
					set = function(info, value)
						selectedSpell = value
						UpdateFilterGroup()
					end
				}
			}
		}

		E.Options.args.filters.args.resetGroup = {
			order = 25,
			type = "group",
			name = L["Reset Filter"],
			guiInline = true,
			args = {
				enableReset = {
					order = 1,
					type = "toggle",
					name = L["Enable"],
					get = function(info) return FilterResetState[selectedFilter] end,
					set = function(info, value)
						FilterResetState[selectedFilter] = value
						E.Options.args.filters.args.resetGroup.args.resetFilter.disabled = (not value)
					end
				},
				resetFilter = {
					order = 2,
					type = "execute",
					name = L["Reset Filter"],
					desc = L["This will reset the contents of this filter back to default. Any spell you have added to this filter will be removed."],
					disabled = function() return not FilterResetState[selectedFilter] end,
					func = function(info)
						E.db.unitframe.filters.buffwatch = {}
						selectedSpell = nil
						UpdateFilterGroup()
						UF:Update_AllFrames()
					end
				}
			}
		}

		if selectedSpell then
			local name = GetSpellInfo(selectedSpell)
			E.Options.args.filters.args.filterGroup.args[name] = {
				order = -10,
				type = "group",
				name = name.." ("..selectedSpell..")",
				hidden = function() return not E.db.unitframe.filters.buffwatch[selectedSpell] end,
				get = function(info)
					if E.db.unitframe.filters.buffwatch[selectedSpell] then
						return E.db.unitframe.filters.buffwatch[selectedSpell][info[#info]]
					end
				end,
				set = function(info, value)
					E.db.unitframe.filters.buffwatch[selectedSpell][info[#info]] = value

					UF:UpdateAuraWatchFromHeader("raid")
					UF:UpdateAuraWatchFromHeader("raid40")
					UF:UpdateAuraWatchFromHeader("party")
				end,
				args = {
					enabled = {
						order = 0,
						type = "toggle",
						name = L["Enable"]
					},
					point = {
						order = 1,
						type = "select",
						name = L["Anchor Point"],
						values = {
							["TOPLEFT"] = "TOPLEFT",
							["TOPRIGHT"] = "TOPRIGHT",
							["BOTTOMLEFT"] = "BOTTOMLEFT",
							["BOTTOMRIGHT"] = "BOTTOMRIGHT",
							["LEFT"] = "LEFT",
							["RIGHT"] = "RIGHT",
							["TOP"] = "TOP",
							["BOTTOM"] = "BOTTOM"
						}
					},
					sizeOverride = {
						order = 2,
						type = "range",
						name = L["Size Override"],
						min = 0, max = 50, step = 1
					},
					xOffset = {
						order = 3,
						type = "range",
						name = L["xOffset"],
						min = -75, max = 75, step = 1
					},
					yOffset = {
						order = 4,
						type = "range",
						name = L["yOffset"],
						min = -75, max = 75, step = 1
					},
					style = {
						order = 5,
						type = "select",
						name = L["Style"],
						values = {
							["coloredIcon"] = L["Colored Icon"],
							["texturedIcon"] = L["Textured Icon"],
							["NONE"] = L["NONE"]
						}
					},
					color = {
						order = 6,
						type = "color",
						name = L["COLOR"],
						get = function(info)
							if E.db.unitframe.filters.buffwatch[selectedSpell] then
								local t = E.db.unitframe.filters.buffwatch[selectedSpell][info[#info]]
								return t.r, t.g, t.b, t.a
							end
						end,
						set = function(info, r, g, b)
							local t = E.db.unitframe.filters.buffwatch[selectedSpell][info[#info]]
							t.r, t.g, t.b = r, g, b
							UF:UpdateAuraWatchFromHeader("raid")
							UF:UpdateAuraWatchFromHeader("raid40")
							UF:UpdateAuraWatchFromHeader("party")
						end
					},
					displayText = {
						order = 7,
						type = "toggle",
						name = L["Display Text"]
					},
					textColor = {
						order = 8,
						type = "color",
						name = L["Text Color"],
						get = function(info)
							if E.db.unitframe.filters.buffwatch[selectedSpell] then
								local t = E.db.unitframe.filters.buffwatch[selectedSpell][info[#info]]
								if t then
									return t.r, t.g, t.b, t.a
								else
									return 1, 1, 1, 1
								end
							end
						end,
						set = function(info, r, g, b)
							local t = E.db.unitframe.filters.buffwatch[selectedSpell][info[#info]]
							t.r, t.g, t.b = r, g, b
							UF:UpdateAuraWatchFromHeader("raid")
							UF:UpdateAuraWatchFromHeader("raid40")
							UF:UpdateAuraWatchFromHeader("party")
						end
					},
					decimalThreshold = {
						order = 9,
						type = "range",
						name = L["Decimal Threshold"],
						desc = L["Threshold before text goes into decimal form. Set to -1 to disable decimals."],
						min = -1, max = 10, step = 1
					},
					textThreshold = {
						order = 10,
						type = "range",
						name = L["Text Threshold"],
						desc = L["At what point should the text be displayed. Set to -1 to disable."],
						min = -1, max = 60, step = 1
					},
					anyUnit = {
						order = 11,
						type = "toggle",
						name = L["Show Aura From Other Players"]
					},
					onlyShowMissing = {
						order = 12,
						type = "toggle",
						name = L["Show When Not Active"]
					}
				}
			}
		end
	else
		if not selectedFilter or not E.global.unitframe.aurafilters[selectedFilter] then
			E.Options.args.filters.args.filterGroup = nil
			E.Options.args.filters.args.spellGroup = nil
			E.Options.args.filters.args.resetGroup = nil
			return
		end

		E.Options.args.filters.args.filterGroup = {
			order = 10,
			type = "group",
			name = selectedFilter,
			guiInline = true,
			args = {
				addSpell = {
					order = 1,
					type = "input",
					name = L["Add Spell ID or Name"],
					desc = L["Add a spell to the filter. Use spell ID if you don't want to match all auras which share the same name."],
					get = function(info) return "" end,
					set = function(info, value)
						if tonumber(value) then	value = tonumber(value) end
						if not E.global.unitframe.aurafilters[selectedFilter].spells[value] then
							E.global.unitframe.aurafilters[selectedFilter].spells[value] = {
								["enable"] = true,
								["priority"] = 0,
								["stackThreshold"] = 0
							}
						end
						UpdateFilterGroup()
						UF:Update_AllFrames()
					end
				},
				removeSpell = {
					order = 2,
					type = "execute",
					name = L["Remove Spell"],
					desc = L["Remove a spell from the filter. Use the spell ID if you see the ID as part of the spell name in the filter."],
					func = function()
						local value = selectedSpell:match(" %((%d+)%)$") or selectedSpell
						if tonumber(value) then value = tonumber(value) end
						if G.unitframe.aurafilters[selectedFilter] then
							if G.unitframe.aurafilters[selectedFilter].spells[value] then
								E.global.unitframe.aurafilters[selectedFilter].spells[value].enable = false
								E:Print(L["You may not remove a spell from a default filter that is not customly added. Setting spell to false instead."])
							else
								E.global.unitframe.aurafilters[selectedFilter].spells[value] = nil
							end
						else
							E.global.unitframe.aurafilters[selectedFilter].spells[value] = nil
						end

						UpdateFilterGroup()
						UF:Update_AllFrames()
					end,
					disabled = function() return not (selectedSpell and selectedSpell ~= "") end
				},
				filterType = {
					order = 3,
					type = "select",
					name = L["Filter Type"],
					desc = L["Set the filter type. Blacklist will hide any auras in the list and show all others. Whitelist will show any auras in the filter and hide all others."],
					values = {
						["Whitelist"] = L["Whitelist"],
						["Blacklist"] = L["Blacklist"]
					},
					get = function() return E.global.unitframe.aurafilters[selectedFilter].type end,
					set = function(info, value) E.global.unitframe.aurafilters[selectedFilter].type = value UF:Update_AllFrames() end
				},
				quickSearch = {
					order = 4,
					type = "input",
					name = L["Filter Search"],
					desc = L["Search for a spell name inside of a filter."],
					get = function() return quickSearchText end,
					set = function(info,value) quickSearchText = value end
				},
				selectSpell = {
					order = 10,
					type = "select",
					name = L["Select Spell"],
					width = "double",
					guiInline = true,
					get = function(info) return selectedSpell end,
					set = function(info, value)
						selectedSpell = value
						UpdateFilterGroup()
					end,
					values = function()
						local filters = {}
						local list = E.global.unitframe.aurafilters[selectedFilter].spells
						if not list then return end
						local searchText = quickSearchText:lower()
						for filter in pairs(list) do
							if tonumber(filter) then
								local spellName = GetSpellInfo(filter)
								if spellName then
									filter = format("%s (%s)", spellName, filter)
								else
									filter = tostring(filter)
								end
							end
							if filter:lower():find(searchText) then filters[filter] = filter end
						end
						if not next(filters) then filters[""] = L["NONE"] end
						return filters
					end
				}
			}
		}

		if E.DEFAULT_FILTER[selectedFilter] then
			--Disable and hide filter type option for default filters
			E.Options.args.filters.args.filterGroup.args.filterType.disabled = true
			E.Options.args.filters.args.filterGroup.args.filterType.hidden = true

			--Add button to reset content of the filter back to default
			E.Options.args.filters.args.resetGroup = {
				order = 25,
				type = "group",
				name = L["Reset Filter"],
				guiInline = true,
				args = {
					enableReset = {
						order = 1,
						type = "toggle",
						name = L["Enable"],
						get = function(info) return FilterResetState[selectedFilter] end,
						set = function(info, value)
							FilterResetState[selectedFilter] = value
							E.Options.args.filters.args.resetGroup.args.resetFilter.disabled = (not value)
						end
					},
					resetFilter = {
						order = 2,
						type = "execute",
						name = L["Reset Filter"],
						desc = L["This will reset the contents of this filter back to default. Any spell you have added to this filter will be removed."],
						disabled = function() return not FilterResetState[selectedFilter] end,
						func = function()
							E.global.unitframe.aurafilters[selectedFilter].spells = E:CopyTable({}, G.unitframe.aurafilters[selectedFilter].spells)
							selectedSpell = nil
							UpdateFilterGroup()
							UF:Update_AllFrames()
						end
					}
				}
			}
		end

		local spellID = selectedSpell and match(selectedSpell, "(%d+)")
		if spellID then spellID = tonumber(spellID) end

		if not selectedSpell or not E.global.unitframe.aurafilters[selectedFilter].spells[(spellID or selectedSpell)] then
			E.Options.args.filters.args.spellGroup = nil
			return
		end

		E.Options.args.filters.args.spellGroup = {
			order = 15,
			type = "group",
			name = selectedSpell,
			guiInline = true,
			args = {
				enable = {
					order = 1,
					type = "toggle",
					name = L["Enable"],
					get = function()
						if not (spellID or selectedSpell) then
							return false
						else
							return E.global.unitframe.aurafilters[selectedFilter].spells[(spellID or selectedSpell)].enable
						end
					end,
					set = function(info, value) E.global.unitframe.aurafilters[selectedFilter].spells[(spellID or selectedSpell)].enable = value UpdateFilterGroup() UF:Update_AllFrames() end
				},
				forDebuffIndicator = {
					order = 2,
					type = "group",
					name = L["Used as RaidDebuff Indicator"],
					guiInline = true,
					args = {
						priority = {
							order = 1,
							type = "range",
							name = L["Priority"],
							desc = L["Set the priority order of the spell, please note that prioritys are only used for the raid debuff module, not the standard buff/debuff module. If you want to disable set to zero."],
							min = 0, max = 99, step = 1,
							get = function()
								if not selectedSpell then
									return 0
								else
									return E.global.unitframe.aurafilters[selectedFilter].spells[(spellID or selectedSpell)].priority
								end
							end,
							set = function(info, value) E.global.unitframe.aurafilters[selectedFilter].spells[(spellID or selectedSpell)].priority = value UpdateFilterGroup() UF:Update_AllFrames() end
						},
						stackThreshold = {
							order = 2,
							type = "range",
							name = L["Stack Threshold"],
							desc = L["The debuff needs to reach this amount of stacks before it is shown. Set to 0 to always show the debuff."],
							min = 0, max = 99, step = 1,
							get = function()
								if not selectedSpell then
									return 0
								else
									return E.global.unitframe.aurafilters[selectedFilter].spells[(spellID or selectedSpell)].stackThreshold
								end
							end,
							set = function(info, value) E.global.unitframe.aurafilters[selectedFilter].spells[(spellID or selectedSpell)].stackThreshold = value UpdateFilterGroup() UF:Update_AllFrames() end
						}
					}
				}
			}
		}
	end

	UF:Update_AllFrames()
end

local function OpenChatWithText(text)
	if not text then return end
	text = tostring(text)

	if ChatFrame_OpenChat then
		ChatFrame_OpenChat(text)
	elseif DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox then
		local editBox = DEFAULT_CHAT_FRAME.editBox
		editBox:Show()
		editBox:SetText(text)
		editBox:HighlightText()
		editBox:SetFocus()
	end
	E:Print(format("Pasted spell ID |cff00ff00%s|r into chat edit box", text))
end

local function AddSpellToSelectedFilter(spellId, spellName)
	local spellIdNum = tonumber(spellId) or spellId
	local name = spellName or GetSpellInfo(spellIdNum) or tostring(spellId)

	if selectedFilter and E.global.unitframe.aurafilters[selectedFilter] then
		if not E.global.unitframe.aurafilters[selectedFilter].spells[spellIdNum] then
			E.global.unitframe.aurafilters[selectedFilter].spells[spellIdNum] = {
				["enable"] = true,
				["priority"] = 0,
				["stackThreshold"] = 0
			}
		end
		selectedSpell = GetSpellInfo(spellIdNum) and format("%s (%s)", GetSpellInfo(spellIdNum), spellIdNum) or tostring(spellIdNum)
		E:Print(format("Added spell |cff00ff00%s|r (ID: %s) to filter |cff00ff00%s|r", name, spellId, selectedFilter))
		UpdateFilterGroup()
		UF:Update_AllFrames()
		if UpdateRecentAurasGroup then UpdateRecentAurasGroup() end -- turn the row green immediately
		if E.Libs and E.Libs.AceConfigRegistry then
			E.Libs.AceConfigRegistry:NotifyChange("ElvUI")
		end
	elseif selectedFilter == "Debuff Highlight" then
		E.global.unitframe.DebuffHighlightColors[spellIdNum] = {enable = true, style = "GLOW", color = {r = 0.8, g = 0, b = 0, a = 0.85}}
		selectedSpell = GetSpellInfo(spellIdNum) and format("%s (%s)", GetSpellInfo(spellIdNum), spellIdNum) or tostring(spellIdNum)
		E:Print(format("Added spell |cff00ff00%s|r (ID: %s) to filter |cff00ff00Debuff Highlight|r", name, spellId))
		UpdateFilterGroup()
		UF:Update_AllFrames()
		if UpdateRecentAurasGroup then UpdateRecentAurasGroup() end -- turn the row green immediately
		if E.Libs and E.Libs.AceConfigRegistry then
			E.Libs.AceConfigRegistry:NotifyChange("ElvUI")
		end
	else
		OpenChatWithText(spellId)
		E:Print(L["Select a Filter in the dropdown above to automatically add spells to it."])
	end
end

local AceGUI = E.Libs.AceGUI or LibStub("AceGUI-3.0")
local activeAuraWidget = nil

if AceGUI then
	local Type, Version = "AuraTrackerColumns", 107

	local methods = {
		OnAcquire = function(self)
			self.frame:SetHeight(380)
			self.userdata = self.userdata or {}
			self.user = self.userdata
			self.events = self.events or {}
			self.children = self.children or {}
			activeAuraWidget = self
			self:UpdateAuras()
		end,
		OnRelease = function(self)
			if activeAuraWidget == self then activeAuraWidget = nil end
			self.userdata = {}
			self.user = self.userdata
			self.events = {}
			self.children = {}
			self.frame:Hide()
			self.frame:ClearAllPoints()
		end,
		ReleaseChildren = function(self)
			self.children = self.children or {}
			self.children = {}
		end,
		OnWidthSet = function(self, width)
			self.frame:SetWidth(width)
			self:ResizeColumns()
		end,
		OnHeightSet = function(self, height)
			self.frame:SetHeight(height)
		end,
		GetWidth = function(self)
			return self.frame:GetWidth() or 800
		end,
		GetHeight = function(self)
			return self.frame:GetHeight() or 380
		end,
		SetWidth = function(self, width)
			self.frame:SetWidth(width)
			self:ResizeColumns()
		end,
		SetHeight = function(self, height)
			self.frame:SetHeight(height)
		end,
		SetPoint = function(self, ...)
			self.frame:SetPoint(...)
		end,
		ClearAllPoints = function(self)
			self.frame:ClearAllPoints()
		end,
		Show = function(self)
			self.frame:Show()
		end,
		Hide = function(self)
			self.frame:Hide()
		end,
		SetParent = function(self, parent)
			local parentFrame = (type(parent) == "table" and parent.frame) or parent
			if parentFrame then
				self.frame:SetParent(parentFrame)
			end
		end,
		AddChild = function(self, child)
			self.children = self.children or {}
			if child then
				table.insert(self.children, child)
				if type(child) == "table" and child.frame then
					child.frame:SetParent(self.frame)
				end
			end
		end,
		PauseLayout = function(self) end,
		ResumeLayout = function(self) end,
		DoLayout = function(self) end,
		SetLayout = function(self, layout) end,
		SetTitle = function(self, text) end,
		SetText = function(self, text) end,
		SetLabel = function(self, text) end,
		SetFont = function(self, ...) end,
		SetFontObject = function(self, ...) end,
		SetColor = function(self, ...) end,
		SetJustifyH = function(self, ...) end,
		SetJustifyV = function(self, ...) end,
		SetDisabled = function(self, disabled) end,
		SetUserData = function(self, key, value)
			self.userdata = self.userdata or {}
			self.userdata[key] = value
			self.user = self.userdata
		end,
		GetUserData = function(self, key)
			if self.userdata then
				return self.userdata[key]
			end
		end,
		GetUserDataTable = function(self)
			self.userdata = self.userdata or {}
			self.user = self.userdata
			return self.userdata
		end,
		SetCallback = function(self, name, func)
			if type(self.events) ~= "table" then
				self.events = {}
			end
			self.events[name] = func
		end,
		Fire = function(self, name, ...)
			if type(self.events) == "table" and self.events[name] then
				self.events[name](self, name, ...)
			end
		end,
	}

	local function ResizeColumns(self)
		local totalWidth = self.frame:GetWidth() or 800
		local spacing = 8
		local colWidth = math.max(140, math.floor((totalWidth - (spacing * 3) - 16) / 4))
		for i = 1, 4 do
			local col = self.columns[i]
			if col then
				col:SetWidth(colWidth)
				col:SetPoint("TOPLEFT", self.frame, "TOPLEFT", (i - 1) * (colWidth + spacing), -20)
			end
		end
	end

	local function UpdateAuras(self)
		if E.AuraTracker and E.AuraTracker.RebuildLists then
			E.AuraTracker:RebuildLists() -- lazy sort: arrays are only built when this UI renders
		end
		local maxDuration = E.global.unitframe.auraTrackerMaxDuration or 0
		local hideNoDuration = E.global.unitframe.auraTrackerHideNoDuration or false

		local categories = {
			{ name = "Player Buffs", list = E.AuraTracker and E.AuraTracker.playerBuffs },
			{ name = "Player Debuffs", list = E.AuraTracker and E.AuraTracker.playerDebuffs },
			{ name = "Group Buffs", list = E.AuraTracker and E.AuraTracker.groupBuffs },
			{ name = "Group Debuffs", list = E.AuraTracker and E.AuraTracker.groupDebuffs },
		}

		for cIdx, cat in ipairs(categories) do
			local col = self.columns[cIdx]
			local content = col.content

			if content.rows then
				for _, r in ipairs(content.rows) do
					r:Hide()
				end
			end
			content.rows = {}

			local filtered = {}
			if cat.list then
				for _, item in ipairs(cat.list) do
					local pass = true
					if hideNoDuration and (not item.duration or item.duration == 0) then pass = false end
					if maxDuration > 0 and item.duration and item.duration > 0 and item.duration > maxDuration then pass = false end
					if pass then table.insert(filtered, item) end
				end
			end

			if #filtered == 0 then
				local emptyText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
				emptyText:SetPoint("TOPLEFT", content, "TOPLEFT", 6, -6)
				emptyText:SetText("No auras recorded.")
				emptyText:SetTextColor(0.5, 0.5, 0.5)
				table.insert(content.rows, emptyText)
			else
				local yOffset = -2
				for rIdx, item in ipairs(filtered) do
					local row = CreateFrame("Button", nil, content)
					row:SetHeight(24)
					row:SetPoint("TOPLEFT", content, "TOPLEFT", 2, yOffset)
					row:SetPoint("TOPRIGHT", content, "TOPRIGHT", -2, yOffset)

					local hl = row:CreateTexture(nil, "HIGHLIGHT")
					hl:SetAllPoints()
					hl:SetTexture("Interface\\Buttons\\UI-ListHighlight")

					local icon = row:CreateTexture(nil, "ARTWORK")
					icon:SetSize(20, 20)
					icon:SetPoint("LEFT", row, "LEFT", 2, 0)
					icon:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
					icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

					local durationText = ""
					if item.duration and item.duration > 0 then
						if item.duration >= 60 then
							durationText = format(" |cff00ff00(%dm)|r", math.floor(item.duration / 60))
						else
							durationText = format(" |cff00ff00(%ds)|r", item.duration)
						end
					end

					-- Color the name by its status in the currently selected filter:
					-- green = in a Whitelist-type filter (enabled), red = in a
					-- Blacklist-type filter (enabled), yellow = present but disabled.
					local nameColor = "|cffffffff"
					local curFilter = selectedFilter and E.global.unitframe.aurafilters[selectedFilter]
					local curSpells = curFilter and curFilter.spells
					if curSpells then
						local entry = curSpells[item.spellId] or curSpells[item.name]
						if entry then
							local enabled = (type(entry) ~= "table" and entry and true) or (type(entry) == "table" and entry.enable ~= false)
							if not enabled then
								nameColor = "|cffcccc33"
							elseif curFilter.type == "Blacklist" then
								nameColor = "|cffff4444"
							else
								nameColor = "|cff33ff33"
							end
						end
					end

					local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
					label:SetPoint("LEFT", icon, "RIGHT", 4, 0)
					label:SetPoint("RIGHT", row, "RIGHT", -2, 0)
					label:SetJustifyH("LEFT")
					label:SetText(format("%s%s|r%s |cff999999(%d)|r", nameColor, item.name, durationText, item.spellId))

					row:EnableMouse(true)
					row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
					row:SetScript("OnClick", function(self, button)
						if button == "RightButton" or IsShiftKeyDown() then
							OpenChatWithText(item.spellId)
						else
							AddSpellToSelectedFilter(item.spellId, item.name)
						end
					end)

					row:SetScript("OnEnter", function(self)
						GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
						GameTooltip:ClearLines()

						local setTooltip = false
						if item.unit and item.index then
							local bName, _, _, _, _, _, _, _, _, _, bSpellId
							if item.isDebuff then
								bName, _, _, _, _, _, _, _, _, _, bSpellId = UnitDebuff(item.unit, item.index)
							else
								bName, _, _, _, _, _, _, _, _, _, bSpellId = UnitBuff(item.unit, item.index)
							end

							if bName == item.name or bSpellId == item.spellId then
								if item.isDebuff then
									GameTooltip:SetUnitDebuff(item.unit, item.index)
								else
									GameTooltip:SetUnitBuff(item.unit, item.index)
								end
								setTooltip = true
							end
						end

						-- Fallback: player buff search
						if not setTooltip then
							local bIdx = 1
							while true do
								local bName, _, _, _, _, _, _, _, _, _, bSpellId = UnitBuff("player", bIdx)
								if not bName then break end
								if bSpellId == item.spellId or bName == item.name then
									GameTooltip:SetUnitBuff("player", bIdx)
									setTooltip = true
									break
								end
								bIdx = bIdx + 1
							end
						end

						-- Fallback: player debuff search
						if not setTooltip then
							local bIdx = 1
							while true do
								local bName, _, _, _, _, _, _, _, _, _, bSpellId = UnitDebuff("player", bIdx)
								if not bName then break end
								if bSpellId == item.spellId or bName == item.name then
									GameTooltip:SetUnitDebuff("player", bIdx)
									setTooltip = true
									break
								end
								bIdx = bIdx + 1
							end
						end

						-- Final fallback: spell hyperlink
						if not setTooltip and item.spellId then
							GameTooltip:SetHyperlink("spell:" .. item.spellId)
						end

						GameTooltip:AddLine(" ")
						GameTooltip:AddLine("|cff00ff00Left-Click:|r Add to selected filter", 1, 1, 1)
						GameTooltip:AddLine("|cff00ff00Right-Click / Shift-Click:|r Paste ID into chat box", 1, 1, 1)
						GameTooltip:Show()
					end)
					row:SetScript("OnLeave", function()
						GameTooltip:Hide()
					end)

					table.insert(content.rows, row)
					yOffset = yOffset - 25
				end
				content:SetHeight(math.abs(yOffset) + 6)
			end
		end
	end

	local function Constructor()
		local num = AceGUI:GetNextWidgetNum(Type)
		local frame = CreateFrame("Frame", "AceGUI" .. Type .. num, UIParent)
		frame:Hide()
		frame:SetHeight(380)

		local widget = {
			frame = frame,
			type = Type,
			userdata = {},
			user = {},
			events = {},
			children = {},
			columns = {},
			ResizeColumns = ResizeColumns,
			UpdateAuras = UpdateAuras,
		}
		widget.user = widget.userdata

		for method, func in pairs(methods) do
			widget[method] = func
		end

		local S = E:GetModule("Skins")
		local catNames = { "Player Buffs", "Player Debuffs", "Group Buffs", "Group Debuffs" }
		for i = 1, 4 do
			local col = CreateFrame("Frame", nil, frame)
			col:SetHeight(350)
			if E.template then col:SetTemplate("Transparent") end

			local header = col:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			header:SetPoint("BOTTOMLEFT", col, "TOPLEFT", 4, 4)
			header:SetText(catNames[i])
			header:SetTextColor(1, 0.82, 0)
			col.header = header

			local sfName = "AceGUI" .. Type .. num .. "Col" .. i .. "Scroll"
			local sf = CreateFrame("ScrollFrame", sfName, col, "UIPanelScrollFrameTemplate")
			sf:SetPoint("TOPLEFT", col, "TOPLEFT", 4, -4)
			sf:SetPoint("BOTTOMRIGHT", col, "BOTTOMRIGHT", -22, 4)

			if S and S.HandleScrollBar then
				local sb = _G[sfName .. "ScrollBar"]
				if sb then S:HandleScrollBar(sb) end
			end

			local content = CreateFrame("Frame", nil, sf)
			content:SetSize(180, 340)
			sf:SetScrollChild(content)
			col.content = content
			col.scrollFrame = sf

			widget.columns[i] = col
		end

		frame:SetScript("OnSizeChanged", function()
			widget:ResizeColumns()
		end)

		return widget
	end

	AceGUI:RegisterWidgetType(Type, Constructor, Version)
end

-- Initialize default Absorb Shields filter if not existing
if not E.global.unitframe.aurafilters["Absorb Shields"] then
	E.global.unitframe.aurafilters["Absorb Shields"] = {
		["type"] = "Whitelist",
		["spells"] = {
			["Power Word: Shield"] = { ["enable"] = true, ["priority"] = 0 },
			["Void Shield"] = { ["enable"] = true, ["priority"] = 0 },
			["Forbidden Ritual"] = { ["enable"] = true, ["priority"] = 0 },
			["Hateforged Barrier"] = { ["enable"] = true, ["priority"] = 0 },
			["Phoenix Shield"] = { ["enable"] = true, ["priority"] = 0 },
			["Sacred Shield"] = { ["enable"] = true, ["priority"] = 0 },
			["Ice Barrier"] = { ["enable"] = true, ["priority"] = 0 },
			["Mana Shield"] = { ["enable"] = true, ["priority"] = 0 },
			["Anti-Magic Shell"] = { ["enable"] = true, ["priority"] = 0 },
			["Savage Defense"] = { ["enable"] = true, ["priority"] = 0 },
			["Divine Aegis"] = { ["enable"] = true, ["priority"] = 0 },
			["Blood Shield"] = { ["enable"] = true, ["priority"] = 0 },
			["Protection"] = { ["enable"] = true, ["priority"] = 0 },
			["Illuminated Healing"] = { ["enable"] = true, ["priority"] = 0 },
			["Guard"] = { ["enable"] = true, ["priority"] = 0 },
			["Fire Ward"] = { ["enable"] = true, ["priority"] = 0 },
			["Frost Ward"] = { ["enable"] = true, ["priority"] = 0 },
			["Shadow Ward"] = { ["enable"] = true, ["priority"] = 0 },
			[560374] = { ["enable"] = true, ["priority"] = 0 },
		}
	}
end

E.Options.args.filters = {
	order = -10, --Always Last Hehehe
	type = "group",
	name = L["FILTERS"],
	args = {
		createFilter = {
			order = 1,
			type = "input",
			name = L["Create Filter"],
			desc = L["Create a filter, once created a filter can be set inside the buffs/debuffs section of each unit."],
			get = function(info) return "" end,
			set = function(info, value)
				if match(value, "^[%s%p]-$") then
					return
				end
				if match(value, ",") then
					E:Print(L["Filters are not allowed to have commas in their name. Stripping commas from filter name."])
					value = gsub(value, ",", "")
				end
				if match(value, "^Friendly:") or match(value, "^Enemy:") then
					return --dont allow people to create Friendly: or Enemy: filters
				end
				if G.unitframe.specialFilters[value] or E.global.unitframe.aurafilters[value] then
					E:Print(L["Filter already exists!"])
					return
				end
				E.global.unitframe.aurafilters[value] = {}
				E.global.unitframe.aurafilters[value].spells = {}
			end
		},
		selectFilter = {
			order = 2,
			type = "select",
			name = L["Select Filter"],
			get = function(info) return selectedFilter end,
			set = function(info, value)
				if value == "" then
					selectedFilter = nil
					selectedSpell = nil
				else
					selectedSpell = nil
					if FilterResetState[selectedFilter] then
						FilterResetState[selectedFilter] = nil
					end
					selectedFilter = value
				end
				quickSearchText = ""
				UpdateFilterGroup()
				if UpdateRecentAurasGroup then UpdateRecentAurasGroup() end -- recolor tracker rows for the new filter
			end,
			values = function()
				local filters = {}
				filters[""] = L["NONE"]
				local list = E.global.unitframe.aurafilters
				if not list then return end
				for filter in pairs(list) do
					filters[filter] = filter
				end

				filters["Absorb Shields"] = "Absorb Shields"
				filters["Buff Indicator"] = "Buff Indicator"
				filters["Buff Indicator (Pet)"] = "Buff Indicator (Pet)"
				filters["Buff Indicator (Profile)"] = "Buff Indicator (Profile)"
				filters["AuraBar Colors"] = "AuraBar Colors"
				filters["Debuff Highlight"] = "Debuff Highlight"
				return filters
			end
		},
		deleteFilter = {
			order = 3,
			type = "execute",
			name = L["Delete Filter"],
			desc = L["Delete a created filter, you cannot delete pre-existing filters, only custom ones."],
			func = function()
				E.global.unitframe.aurafilters[selectedFilter] = nil
				removePriority(selectedFilter) --This will wipe a filter from the new aura system profile settings.
				selectedFilter = nil
				selectedSpell = nil
				quickSearchText = ""
				E.Options.args.filters.args.filterGroup = nil
			end,
			disabled = function() return G.unitframe.aurafilters[selectedFilter] end,
			hidden = function() return selectedFilter == nil end
		},
		absorbEngine = {
			order = 99,
			type = "group",
			name = L["Absorb Shields Engine"],
			guiInline = true,
			args = {
				desc = {
					order = 0,
					type = "description",
					name = L["Shields are recognized from the 'Absorb Shields' filter (whitelist). Discovery scans tooltips of unknown buffs to auto-detect new shields - it costs performance, so it is disabled in raids by default. Curate the whitelist with the Recent Auras Tracker, then leave discovery off."],
				},
				discoverySolo = {
					order = 1,
					type = "toggle",
					name = L["Discover While Solo"],
					desc = L["Tooltip-scan unknown buffs to detect new absorb shields while not in a group."],
					get = function(info) return E.global.unitframe.absorbDiscoverySolo ~= false end,
					set = function(info, value) E.global.unitframe.absorbDiscoverySolo = value end,
				},
				discoveryParty = {
					order = 2,
					type = "toggle",
					name = L["Discover In Party"],
					desc = L["Tooltip-scan unknown buffs to detect new absorb shields while in a party."],
					get = function(info) return E.global.unitframe.absorbDiscoveryParty ~= false end,
					set = function(info, value) E.global.unitframe.absorbDiscoveryParty = value end,
				},
				discoveryRaid = {
					order = 3,
					type = "toggle",
					name = L["Discover In Raid"],
					desc = L["Tooltip-scan unknown buffs to detect new absorb shields while in a raid. Expensive at raid scale - leave off unless curating the whitelist."],
					get = function(info) return E.global.unitframe.absorbDiscoveryRaid == true end,
					set = function(info, value) E.global.unitframe.absorbDiscoveryRaid = value end,
				},
				trustNative = {
					order = 4,
					type = "toggle",
					name = L["Trust Native Absorb API"],
					desc = L["Skip ALL buff scanning whenever UnitGetTotalAbsorbs() reports zero. Large raid performance win. Test on your realm first: if any shield stops displaying while active, the API misses it - turn this back off."],
					get = function(info) return E.global.unitframe.absorbTrustNative == true end,
					set = function(info, value) E.global.unitframe.absorbTrustNative = value end,
				},
			},
		},
		recentAuras = {
			order = 100,
			type = "group",
			name = L["Recent Auras Tracker"],
			guiInline = true,
			args = {
				legend = {
					order = -1,
					type = "description",
					name = L["Aura names are colored by the filter selected above: |cff33ff33green|r = in a whitelist, |cffff4444red|r = in a blacklist, |cffcccc33yellow|r = in the filter but disabled. Left-click a row to add it to the selected filter."],
				},
				enableTracker = {
					order = 0,
					type = "toggle",
					name = L["Enable"],
					desc = L["Enable or disable the Recent Auras Tracker."],
					get = function(info)
						if E.global.unitframe.auraTrackerEnable == nil then return true end
						return E.global.unitframe.auraTrackerEnable
					end,
					set = function(info, value)
						E.global.unitframe.auraTrackerEnable = value
						if E.AuraTracker and E.AuraTracker.UpdateRegistration then
							E.AuraTracker:UpdateRegistration() -- unregister UNIT_AURA entirely while disabled
						end
						if UpdateRecentAurasGroup then UpdateRecentAurasGroup() end
					end,
				},
				maxDuration = {
					order = 1,
					type = "range",
					name = L["Max Duration (Sec)"],
					desc = L["Filter out auras with a duration longer than this number of seconds. Set to 0 to show all durations."],
					disabled = function() return E.global.unitframe.auraTrackerEnable == false end,
					min = 0, max = 3600, step = 5,
					get = function(info) return E.global.unitframe.auraTrackerMaxDuration or 0 end,
					set = function(info, value)
						E.global.unitframe.auraTrackerMaxDuration = value
						UpdateRecentAurasGroup()
					end,
				},
				hideNoDuration = {
					order = 2,
					type = "toggle",
					name = L["Hide Permanent Auras"],
					desc = L["Hide auras that have no duration (passive stances, permanent buffs/debuffs)."],
					disabled = function() return E.global.unitframe.auraTrackerEnable == false end,
					get = function(info) return E.global.unitframe.auraTrackerHideNoDuration or false end,
					set = function(info, value)
						E.global.unitframe.auraTrackerHideNoDuration = value
						UpdateRecentAurasGroup()
					end,
				},
				onlyInGroup = {
					order = 3,
					type = "toggle",
					name = L["Only Record Group Members"],
					desc = L["Only record group buffs and debuffs when in a party or raid (prevents recording random players in town)."],
					disabled = function() return E.global.unitframe.auraTrackerEnable == false end,
					get = function(info)
						if E.global.unitframe.auraTrackerOnlyInGroup == nil then return true end
						return E.global.unitframe.auraTrackerOnlyInGroup
					end,
					set = function(info, value)
						E.global.unitframe.auraTrackerOnlyInGroup = value
						UpdateRecentAurasGroup()
					end,
				},
				refresh = {
					order = 4,
					type = "execute",
					name = L["Refresh Lists"],
					disabled = function() return E.global.unitframe.auraTrackerEnable == false end,
					func = function()
						if UpdateRecentAurasGroup then UpdateRecentAurasGroup() end
					end,
				},
				grid = {
					order = 10,
					type = "description",
					dialogControl = "AuraTrackerColumns",
					name = "",
					hidden = function() return E.global.unitframe.auraTrackerEnable == false end,
					width = "full",
				},
			}
		}
	}
}

function UpdateRecentAurasGroup()
	if activeAuraWidget and activeAuraWidget.UpdateAuras then
		activeAuraWidget:UpdateAuras()
	end
end

function E:SetToFilterConfig(filter)
	selectedFilter = filter or "Buff Indicator"
	UpdateFilterGroup()
	UpdateRecentAurasGroup()
	E.Libs.AceConfigDialog:SelectGroup("ElvUI", "filters")
end

UpdateRecentAurasGroup()

UpdateRecentAurasGroup()