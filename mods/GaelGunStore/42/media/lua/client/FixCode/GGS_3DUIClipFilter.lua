local function safeGetItem(self)
    if self and self.item then return self.item end
    if self and self.javaObject and type(self.javaObject.getItem) == "function" then
        local ok, result = pcall(self.javaObject.getItem, self.javaObject)
        if ok then return result end
    end
    return nil
end

local function stripClipForPreview(item)
    if not (item and item.getModData and item.getWeaponPart and item.clearWeaponPart) then return end
    local md = item:getModData()
    md.weaponpart = md.weaponpart or {}
    if not md.weaponpart["ClipUI"] then return end
    local clipPart = item:getWeaponPart("Clip")
    if clipPart then
        md.__ggs_savedClipPart = md.__ggs_savedClipPart or clipPart:getFullType()
        pcall(item.clearWeaponPart, item, "Clip")
    end
end

local function restoreClipAfterPreview(item)
    if not (item and item.setWeaponPart and item.getModData) then return end
    local md = item:getModData()
    local saved = md and md.__ggs_savedClipPart
    if not saved then return end
    md.__ggs_savedClipPart = nil
    local inst = instanceItem(saved)
    if inst and instanceof(inst, "WeaponPart") then
        pcall(item.setWeaponPart, item, "Clip", inst, true, false)
    end
end

local function forceStaticModel(part, saved)
    if not (part and part.getType and part.getWorldStaticModel and part.setWorldStaticModel and part.getStaticModel) then
        return
    end
    local pt = part:getType()
    if pt ~= "Clip" and pt ~= "ClipUI" then return end
    saved[part] = saved[part] or part:getWorldStaticModel()
    part:setWorldStaticModel(part:getStaticModel())
end

local function restoreStaticModel(part, saved)
    if part and saved[part] ~= nil and part.setWorldStaticModel then
        part:setWorldStaticModel(saved[part])
        saved[part] = nil
    end
end

local function patchISUI3DScene()
    -- LÃ³gica desactivada: ya no ocultamos ni forzamos Clip/ClipUI en el 3DUI.
    -- Mantener la funciÃ³n vacÃ­a evita hooks adicionales y conserva compatibilidad.
    return
end

Events.OnGameStart.Add(patchISUI3DScene)
Events.OnGameBoot.Add(patchISUI3DScene)
patchISUI3DScene()
