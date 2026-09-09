local E = unpack(select(2, ...))
local NP = E:GetModule("NamePlates")

-- ʕ ◕ᴥ◕ ʔ Utils live in Nameplates.lua; this file keeps partial AddOn syncs from breaking element loads
if not NP.UpdatePlateGUID then
	NP.PlateGUID = NP.PlateGUID or {}

	function NP:ResolvePlateUnit(frame)
		if frame.unit and UnitExists(frame.unit) and UnitName(frame.unit) == frame.UnitName then
			return frame.unit
		end

		if UnitExists("target") and UnitName("target") == frame.UnitName and self:GetUnitTypeFromUnit("target") == frame.UnitType then
			return "target"
		end

		if UnitExists("mouseover") and UnitName("mouseover") == frame.UnitName and self:GetUnitTypeFromUnit("mouseover") == frame.UnitType then
			return "mouseover"
		end

		local groupUnit = self:GetUnitByName(frame, frame.UnitType)
		if groupUnit and UnitExists(groupUnit) and UnitName(groupUnit) == frame.UnitName then
			return groupUnit
		end
	end

	function NP:UpdatePlateGUID(frame)
		if frame.guid then
			self.PlateGUID[frame.guid] = frame
		elseif frame.UnitName and frame.UnitType then
			local guid = self:GetGUIDByName(frame.UnitName, frame.UnitType)
			if guid then
				frame.guid = guid
				self.PlateGUID[guid] = frame
			end
		end
	end

	function NP:GetPlateByGUID(guid)
		if not guid then return end
		return self.PlateGUID[guid] or self:SearchNameplateByGUID(guid)
	end

	function NP:PlateDB(frame)
		return self.db.units[frame.UnitType]
	end
end
