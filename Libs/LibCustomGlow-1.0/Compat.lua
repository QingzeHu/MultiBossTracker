-- Compat shim for LibCustomGlow on pre-Legion clients (Vanilla / TBC / WotLK / Cata / MoP).
-- LibCustomGlow uses CreateTexturePool / CreateFramePool which were added in Legion 7.0.
-- WOW_PROJECT_ID also doesn't exist on older clients.
-- This file MUST load before LibCustomGlow-1.0.lua (see LibCustomGlow-1.0.xml).

if WOW_PROJECT_ID == nil then
    -- Pin to a non-mainline value so the lib's `isRetail` check returns false.
    WOW_PROJECT_ID = -1
    WOW_PROJECT_MAINLINE = 1
end

if not CreateTexturePool then
    function CreateTexturePool(parent, layer, sublayer, textureTemplate, resetFunc)
        local pool = {
            parent = parent, layer = layer, sublayer = sublayer,
            textureTemplate = textureTemplate, resetFunc = resetFunc,
            inactive = {},
        }
        function pool:Acquire()
            local obj = table.remove(self.inactive)
            if not obj then
                obj = self.parent:CreateTexture(nil, self.layer, self.textureTemplate, self.sublayer)
            end
            return obj
        end
        function pool:Release(obj)
            -- resetFunc may call mask APIs that don't exist on this client; swallow gracefully.
            if self.resetFunc then pcall(self.resetFunc, self, obj) end
            table.insert(self.inactive, obj)
        end
        return pool
    end
end

if not CreateFramePool then
    function CreateFramePool(frameType, parent, frameTemplate, resetFunc)
        local pool = {
            frameType = frameType, parent = parent,
            frameTemplate = frameTemplate, resetFunc = resetFunc,
            inactive = {},
        }
        function pool:Acquire()
            local obj = table.remove(self.inactive)
            if not obj then
                obj = CreateFrame(self.frameType, nil, self.parent, self.frameTemplate)
            end
            obj:Show()
            return obj
        end
        function pool:Release(obj)
            if self.resetFunc then pcall(self.resetFunc, self, obj) end
            table.insert(self.inactive, obj)
        end
        return pool
    end
end
