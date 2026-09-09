-- Fallback definitions for Spell Activation Alerts (Proc glows)
-- This fixes the missing templates on custom WotLK clients (e.g. Ascension WoW)

if not AnimateTexCoords2 then
    function AnimateTexCoords2(texture, textureWidth, textureHeight, frameWidth, frameHeight, numFrames, elapsed, throttle)
        if not texture.frame then
            texture.frame = 1
            texture.throttle = throttle
            texture.numColumns = math.floor(textureWidth/frameWidth)
            texture.numRows = math.floor(textureHeight/frameHeight)
            texture.columnWidth = frameWidth/textureWidth
            texture.rowHeight = frameHeight/textureHeight
        end
        if not texture.throttle then
            texture.throttle = 0
        end
        texture.throttle = texture.throttle + elapsed
        if texture.throttle >= throttle then
            local framesToAdvance = math.floor(texture.throttle / throttle)
            local frame = texture.frame + framesToAdvance
            if frame > numFrames then
                frame = ((frame - 1) % numFrames) + 1
            end
            texture.throttle = texture.throttle - (framesToAdvance * throttle)
            texture.frame = frame
            
            local left = ((frame - 1) % texture.numColumns) * texture.columnWidth
            local right = left + texture.columnWidth
            local bottom = math.ceil(frame / texture.numColumns) * texture.rowHeight
            local top = bottom - texture.rowHeight
            texture:SetTexCoord(left, right, top, bottom)
        end
    end
end

if not ActionButton_OverlayGlowAnimOutFinished then
    function ActionButton_OverlayGlowAnimOutFinished(animGroup)
        local overlay = animGroup:GetParent()
        if overlay then
            overlay:Hide()
        end
    end
end
