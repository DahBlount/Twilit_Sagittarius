effectManager = {}

effectManager.knownEffects = {}

function effectManager.getEffect(name, cache)
    if (name == nil) then
        return nil
    end

    if (cache == nil) then
        cache = true
    end

    if (effectManager.knownEffects[name] == nil or not effectManager.knownEffects[name]:isValid()) then
        local texture = gr.loadTexture(name, true)
        if (not texture:isValid()) then
            return nil
        else
            if (cache) then
                effectManager.knownEffects[name] = texture
            end
            return texture
        end
    else
        return effectManager.knownEffects[name]
    end
end

function effectManager.__index(a)
    return effectManager.getEffect(a)
end
