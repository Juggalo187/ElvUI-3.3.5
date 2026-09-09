--[[
# Element: Group Role Indicator

Toggles the visibility of an indicator based on the unit's current group role (tank, healer or damager).

## Widget

GroupRoleIndicator - A `Texture` used to display the group role icon.

## Notes

A default texture will be applied if the widget is a Texture and doesn't have a texture or a color set.

## Examples

    -- Position and size
    local GroupRoleIndicator = self:CreateTexture(nil, 'OVERLAY')
    GroupRoleIndicator:SetSize(16, 16)
    GroupRoleIndicator:SetPoint('LEFT', self)

    -- Register it with oUF
    self.GroupRoleIndicator = GroupRoleIndicator
--]]

local _, ns = ...
local oUF = ns.oUF

local UnitGroupRolesAssigned = UnitGroupRolesAssigned

local function Update(self, event)
	local element = self.GroupRoleIndicator

	--[[ Callback: GroupRoleIndicator:PreUpdate()
	Called before the element has been updated.

	* self - the GroupRoleIndicator element
	--]]
	if(element.PreUpdate) then
		element:PreUpdate()
	end

	local isTank, isHealer, isDamage, isSupport = UnitGroupRolesAssigned(self.unit)
	if(isTank or isHealer or isDamage or isSupport) then
		local role = isSupport and "support" or isTank and "tank" or isHealer and "healer" or isDamage and "dps"
		if role == "support" then
			element:SetTexture("Interface\\AddOns\\ElvUI\\media\\textures\\support")
		else
			element:SetTexture("Interface\\AddOns\\ElvUI\\media\\textures\\" .. role)
		end
		element:Show()
	else
		element:Hide()
	end

	--[[ Callback: GroupRoleIndicator:PostUpdate(role)
	Called after the element has been updated.

	* self - the GroupRoleIndicator element
	* isTank, isHealer, isDamage - the role as returned by [UnitGroupRolesAssigned](http://wowprogramming.com/docs/api/UnitGroupRolesAssigned)
	--]]
	if(element.PostUpdate) then
		return element:PostUpdate(isTank, isHealer, isDamage)
	end
end

local function Path(self, ...)
	--[[ Override: GroupRoleIndicator.Override(self, event, ...)
	Used to completely override the internal update function.

	* self  - the parent object
	* event - the event triggering the update (string)
	* ...   - the arguments accompanying the event
	--]]
	return (self.GroupRoleIndicator.Override or Update) (self, ...)
end

local function ForceUpdate(element)
	return Path(element.__owner, 'ForceUpdate')
end

local function Enable(self)
	local element = self.GroupRoleIndicator
	if(element) then
		element.__owner = self
		element.ForceUpdate = ForceUpdate

		-- PLAYER_ROLES_ASSIGNED fires when Dungeon Finder assigns roles and it
		-- is relevant for every group frame, not just the player. Registering
		-- only PARTY_MEMBERS_CHANGED on party frames meant role icons often
		-- stayed empty/stale after an RDF group formed.
		self:RegisterEvent('PLAYER_ROLES_ASSIGNED', Path, true)
		self:RegisterEvent('LFG_ROLE_UPDATE', Path, true)
		self:RegisterEvent('ROLE_CHANGED_INFORM', Path, true)
		self:RegisterEvent('PARTY_MEMBERS_CHANGED', Path, true)
		self:RegisterEvent('RAID_ROSTER_UPDATE', Path, true)
		self:RegisterEvent('PLAYER_ENTERING_WORLD', Path, true)

		if(element:IsObjectType('Texture') and not element:GetTexture()) then
			element:SetTexture([[Interface\LFGFrame\UI-LFG-ICON-PORTRAITROLES]])
		end

		return true
	end
end

local function Disable(self)
	local element = self.GroupRoleIndicator
	if(element) then
		element:Hide()

		self:UnregisterEvent('PLAYER_ROLES_ASSIGNED', Path)
		self:UnregisterEvent('LFG_ROLE_UPDATE', Path)
		self:UnregisterEvent('ROLE_CHANGED_INFORM', Path)
		self:UnregisterEvent('PARTY_MEMBERS_CHANGED', Path)
		self:UnregisterEvent('RAID_ROSTER_UPDATE', Path)
		self:UnregisterEvent('PLAYER_ENTERING_WORLD', Path)
	end
end

oUF:AddElement('GroupRoleIndicator', Path, Enable, Disable)