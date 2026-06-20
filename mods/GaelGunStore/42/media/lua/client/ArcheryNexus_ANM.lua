local BOW_ANIM_MESH = {
    -- Si no defines "ready", usa "<base>_ready".
    Primitive_Bow = { base = "Primitive_Bow", ready = "REX5_MD_BOW" },
    Bow_hunting = { base = "Bow_hunting", ready = "Bow_hunting_ready" },
    Bow_crafted = { base = "Bow_crafted", ready = "Bow_crafted_ready" },
    Bow_compbound = { base = "Bow_compbound", ready = "Bow_compbound_ready" },
    Bow_compbound2 = { base = "Bow_compbound2", ready = "Bow_compbound2_ready" },
    Bow_medieval = { base = "Bow_medieval", ready = "Bow_medieval_ready" },
}

local function resolveBowAnimConfig(bow)
    if not bow then
        return nil
    end
    local bowType = bow:getType()
    local cfg = BOW_ANIM_MESH[bowType]
    if not cfg then
        return nil
    end
    local baseSprite = cfg.base or bowType
    local readySprite = cfg.ready or (baseSprite .. "_ready")
    return baseSprite, readySprite
end

local function setBowSpriteIfNeeded(player, bow, spriteName)
    if not (player and bow and spriteName) then
        return
    end
    local current = bow.getWeaponSprite and bow:getWeaponSprite() or nil
    if current ~= spriteName then
        bow:setWeaponSprite(spriteName)
        player:resetEquippedHandsModels()
    end
end

local function updateBowAnimation(player)
    if not player then
        return
    end

    local bow = player:getPrimaryHandItem()
    if not bow then
        return
    end

    local baseSprite, readySprite = resolveBowAnimConfig(bow)
    if not baseSprite then
        return
    end

    local hasAmmo = (tonumber(bow:getCurrentAmmoCount()) or 0) > 0
    if hasAmmo and player:isAiming() then
        setBowSpriteIfNeeded(player, bow, readySprite)
    else
        setBowSpriteIfNeeded(player, bow, baseSprite)
    end
end

Events.OnPlayerUpdate.Add(updateBowAnimation)
