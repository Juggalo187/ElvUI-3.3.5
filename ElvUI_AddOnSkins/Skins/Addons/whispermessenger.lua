local E, L, V, P, G = unpack(ElvUI)
local S = E:GetModule('Skins')

-- Set the relative WoW file path to your TGA icon here
local CUSTOM_ICON_PATH = [[Interface\AddOns\ElvUI_AddOnSkins\Media\whispermessenger\icon.tga]]

local function SkinWhisperMessengerToggleIcon()
    local toggleIcon = _G["WhisperMessengerToggleIcon"]
    if not toggleIcon then return end

    -- 1. Apply ElvUI's backdrop and force its internal border textures to black
    if not toggleIcon.backdrop then
        toggleIcon:CreateBackdrop("Default")
        
        if toggleIcon.backdrop then
            -- Set background color to ElvUI's dark fade
            if toggleIcon.backdrop.SetBackdropColor then
                toggleIcon.backdrop:SetBackdropColor(unpack(E.media.backdropfadecolor))
            end
            
            -- Force ElvUI's custom inner/outer border lines to solid black (0, 0, 0, 1)
            if toggleIcon.backdrop.iborder then
                toggleIcon.backdrop.iborder:SetVertexColor(0, 0, 0, 1)
            end
            if toggleIcon.backdrop.oborder then
                toggleIcon.backdrop.oborder:SetVertexColor(0, 0, 0, 1)
            end
            
            -- Fallback standard border color call
            if toggleIcon.backdrop.SetBackdropBorderColor then
                toggleIcon.backdrop:SetBackdropBorderColor(0, 0, 0, 1)
            end
        end
    end

    -- 2. Strip the circular textures and set the custom TGA icon
    for _, region in ipairs({ toggleIcon:GetRegions() }) do
        if region and region.IsObjectType and region:IsObjectType("Texture") then
            local drawLayer = region:GetDrawLayer()
            
            if drawLayer == "BACKGROUND" or drawLayer == "BORDER" then
                -- Hide the addon's circular grey mask and outer ring border
                region:SetTexture(nil)
                region:Hide()
                region:SetAlpha(0)
            elseif drawLayer == "ARTWORK" then
                -- Apply custom TGA texture and crop to fit ElvUI border
                region:SetTexture(CUSTOM_ICON_PATH)
                if region.SetTexCoord then
                    region:SetTexCoord(0, 1, 0, 1) -- Set to (unpack(E.TexCoords)) if the icon needs ElvUI's zoom crop
                end
                region:ClearAllPoints()
                region:SetInside(toggleIcon)
            end
        end
    end
end

-- Hook using ElvUI's native timer utility
local skinWatchFrame = CreateFrame("Frame")
skinWatchFrame:RegisterEvent("PLAYER_LOGIN")
skinWatchFrame:RegisterEvent("ADDON_LOADED")
skinWatchFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "PLAYER_LOGIN" or addonName == "WhisperMessenger" then
        if E.Delay then
            E:Delay(0.5, SkinWhisperMessengerToggleIcon)
        elseif E.ScheduleTimer then
            E:ScheduleTimer(SkinWhisperMessengerToggleIcon, 0.5)
        end
    end
end)