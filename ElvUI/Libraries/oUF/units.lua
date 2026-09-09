local parent, ns = ...
local oUF = ns.oUF
local Private = oUF.Private

local enableTargetUpdate = Private.enableTargetUpdate

-- Handles unit specific actions.
function oUF:HandleUnit(object, unit)
	unit = object.unit or unit
	if not unit then return end
	if(unit == 'target') then
		object:RegisterEvent('PLAYER_TARGET_CHANGED', object.UpdateAllElements)
	elseif(unit == 'mouseover') then
		object:RegisterEvent('UPDATE_MOUSEOVER_UNIT', object.UpdateAllElements)
	elseif(unit == 'focus') then
		object:RegisterEvent('PLAYER_FOCUS_CHANGED', object.UpdateAllElements)
	elseif(unit:match('%w+target') or unit:match('boss%d?$')) then
		enableTargetUpdate(object)
	end
end