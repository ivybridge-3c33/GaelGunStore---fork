local function HasPowerLaser(item)
    local modData = item:getModData().LaserBatteryReamin
    if not modData then
        modData = 100
        item:getModData().LaserBatteryReamin = modData
    end
    return modData > 0
end

local function HasPowerLight(item)
    local modData = item:getModData().LightBatteryReamin
    if not modData then
        modData = 100
        item:getModData().LightBatteryReamin = modData
    end
    return modData > 0
end
local function isObjectIndexable(obj)
    local t = type(obj)
    return t == "table" or t == "userdata"
end

local LOG_LASER = false
local LOG_LIGHT = false

local function dbgLaser(msg)
    if LOG_LASER then
        print(msg)
    end
end

local function dbgLight(msg)
    if LOG_LIGHT then
        print(msg)
    end
end

local function disableWeaponLight(weapon)
    if not weapon or not isObjectIndexable(weapon) then
        return
    end
    if weapon.setTorchCone then
        weapon:setTorchCone(false)
    end
    if weapon.setLightDistance then
        weapon:setLightDistance(0.0)
    end
    if weapon.setLightStrength then
        weapon:setLightStrength(0.0)
    end
    if weapon.setActivated then
        weapon:setActivated(false)
    end
end

local function disableGunLightSource(weapon)
    if not weapon or not isObjectIndexable(weapon) then
        return
    end
    local key = tostring(weapon)
    local light = _G.AWCWF_LightByWeapon and _G.AWCWF_LightByWeapon[key]
    if light then
        getCell():removeLamppost(light)
        _G.AWCWF_LightByWeapon[key] = nil
    end
end
local function updateGunLightSource(player, weapon, strength, distance)
    if not player or not weapon or not isObjectIndexable(weapon) then
        return
    end
    if not strength or strength <= 0 or not distance or distance <= 0 then
        disableGunLightSource(weapon)
        return
    end

    local fwd = player:getForwardDirection()
    if not fwd then
        disableGunLightSource(weapon)
        return
    end

    local ahead = math.max(distance * 0.8, 1.0)
    local sideX = -fwd:getY()
    local sideY = fwd:getX()
    local sideLen = math.sqrt(sideX * sideX + sideY * sideY)
    if sideLen > 0 then
        sideX = sideX / sideLen
        sideY = sideY / sideLen
    end
    local sideOffset = 0.18
    local lx = player:getX() + fwd:getX() * ahead + sideX * sideOffset
    local ly = player:getY() + fwd:getY() * ahead + sideY * sideOffset
    local lz = player:getZ() + 1.3
    local ix = math.floor(lx + 0.5)
    local iy = math.floor(ly + 0.5)
    local iz = math.floor(lz + 0.5)
    local radius = math.max(1, math.floor(distance + 0.5))

    _G.AWCWF_LightByWeapon = _G.AWCWF_LightByWeapon or {}
    local lightKey = tostring(weapon)
    -- Recreate light each update to avoid missing setters on IsoLightSource
    disableGunLightSource(weapon)
    local light = IsoLightSource.new(ix, iy, iz, 1.0, 1.0, 1.0, radius)
    _G.AWCWF_LightByWeapon[lightKey] = light
    getCell():addLamppost(light)
    if light.setLightStrength then
        light:setLightStrength(strength)
    end
    if light.setActive then
        light:setActive(true)
    end
end
local lastLightWeaponByPlayer = _G.AWCWF_LastLightWeapon or {}
_G.AWCWF_LastLightWeapon = lastLightWeaponByPlayer
local lastLaserLog = {}
local switchAnimFramesByPlayer = _G.AWCWF_SwitchAnimFramesByPlayer or {}
_G.AWCWF_SwitchAnimFramesByPlayer = switchAnimFramesByPlayer

local function getPlayerStateKey(player)
    if not player then
        return nil
    end

    local key = nil
    if player.getOnlineID then
        key = player:getOnlineID()
    end
    if not key and player.getPlayerNum then
        key = player:getPlayerNum()
    end
    if not key then
        key = tostring(player)
    end
    return key
end

local function rememberLightWeapon(player, weapon)
    if not player then
        return
    end

    local key = getPlayerStateKey(player)

    local last = lastLightWeaponByPlayer[key]
    if not weapon then
        if last and isObjectIndexable(last) then
            disableGunLightSource(last)
            disableWeaponLight(last)
        end
        lastLightWeaponByPlayer[key] = nil
        return
    end

    if last and last ~= weapon and isObjectIndexable(last) then
        disableGunLightSource(last)
    end

    lastLightWeaponByPlayer[key] = weapon
end
local function ensureLightState(item)
    local state = item:getModData().NowLightSet
    if not state then
        state = {
            Type = "nil",
            index = 1,
            IsLaserOn = false,
            IsGunLightOn = false
        }
        item:getModData().NowLightSet = state
        return state
    end

    if state.Type == nil then
        state.Type = "LaserAndGunLight"
    end

    if state.index == nil then
        state.index = 4
    end

    if not state.__ggsLaserBoot then
        state.Type = "nil"
        state.index = 1
        state.IsLaserOn = false
        state.IsGunLightOn = false
        state.__ggsLaserBoot = true
    end

    state.IsLaserOn = state.IsLaserOn or false
    state.IsGunLightOn = state.IsGunLightOn or false

    return state
end

local function startSwitchAnim(player)
    local key = getPlayerStateKey(player)
    if not key then
        return
    end
    switchAnimFramesByPlayer[key] = 6
    if player.setVariable then
        player:setVariable("SwtichLaser", "true")
    end
end

local function updateSwitchAnim(player)
    local key = getPlayerStateKey(player)
    if not key then
        return
    end
    local frames = switchAnimFramesByPlayer[key]
    if not frames then
        return
    end
    if frames <= 0 then
        switchAnimFramesByPlayer[key] = nil
        if player.clearVariable then
            player:clearVariable("SwtichLaser")
        elseif player.setVariable then
            player:setVariable("SwtichLaser", "false")
        end
        return
    end
    switchAnimFramesByPlayer[key] = frames - 1
end

local function safeRound(val, prec)
    if type(_G.round) == "function" then
        return _G.round(val, prec)
    end
    local m = 10 ^ (prec or 0)
    return math.floor((val or 0) * m + 0.5) / m
end

local function LocalLaserUpdate(playerObj)
    -- Sanitiza entrada
    if not playerObj then
        return
    end
    updateSwitchAnim(playerObj)

    local MainGun = playerObj.getPrimaryHandItem and playerObj:getPrimaryHandItem() or nil
    if not MainGun or not isObjectIndexable(MainGun) or not (MainGun.IsWeapon and MainGun:IsWeapon()) or not (MainGun.isRanged and MainGun:isRanged()) then
        -- Solo loguea una vez por arma si se cae aquí
        if MainGun and not lastLaserLog[tostring(MainGun) .. ":gate"] then
            dbgLaser("[GGS LaserDBG] skip: not weapon/ranged or invalid gun=" .. tostring(MainGun))
            lastLaserLog[tostring(MainGun) .. ":gate"] = true
        end
        rememberLightWeapon(playerObj, nil)
        return
    end

    -- Proteger el flujo de errores: mejor loguear y salir que romper el hilo.
    local function run()
        rememberLightWeapon(playerObj, MainGun)
        local Laser = MainGun.getLaser and MainGun:getLaser() or nil
        if not Laser and MainGun.getWeaponPart then
            Laser = MainGun:getWeaponPart("Laser")
        end
        local modData = ensureLightState(MainGun)
        local LightSet = modData.Type
        local logKey = tostring(MainGun) .. ":laser"
        if Laser == nil then
            if lastLaserLog[logKey] ~= "no-laser" then
                dbgLaser("[GGS LaserDBG] No Laser part on " .. tostring(MainGun))
                lastLaserLog[logKey] = "no-laser"
            end
        end
        -- Láser: solo depende del modo/flag, no del Activated (para evitar beams pegados)
        local manualOn = (MainGun.isActivated and MainGun:isActivated()) or false
        if Laser and _G.AWCWF_LaserAndGunLightSet and Laser.getType and _G.AWCWF_LaserAndGunLightSet[Laser:getType()] then
            -- Asegura obtener el beam aunque el método getHide_Beam no exista
            local LaserBeam = MainGun.getHide_Beam and MainGun:getHide_Beam() or nil
            if not LaserBeam and MainGun.getWeaponPart then
                LaserBeam = MainGun:getWeaponPart("Hide_Beam")
            end
            local wantsLaser = (LightSet == "LaserAndGunLight" or LightSet == "Laser") and modData.IsLaserOn == true
            if not LaserBeam and wantsLaser and HasPowerLaser(MainGun) then
                local beamType = _G.AWCWF_LaserAndGunLightSet[Laser:getType()].Beam
                local newBeam = beamType and instanceItem(beamType)
                if newBeam and newBeam.getPartType and newBeam:getPartType() == "Hide_Beam" then
                    if MainGun.setWeaponPart then
                        -- fuerza a real para que el modelo se aplique en mano y suelo
                        -- B42 signature is setWeaponPart(partType, weaponPart); do not pass legacy flags.
                        MainGun:setWeaponPart("Hide_Beam", newBeam)
                        dbgLaser("[GGS LaserDBG] Beam attached type=" .. tostring(beamType) .. " to " .. tostring(MainGun))
                        if playerObj and playerObj.resetEquippedHandsModels then
                            playerObj:resetEquippedHandsModels()
                            playerObj:resetModelNextFrame()
                        end
                    end
                else
                    dbgLaser("[GGS LaserDBG] Beam spawn failed for " .. tostring(beamType) .. " laser=" .. tostring(Laser))
                end
            elseif LaserBeam and (LightSet == "GunLight" or LightSet == "nil" or not wantsLaser) then
                if MainGun.setWeaponPart then
                    MainGun:setWeaponPart("Hide_Beam", nil)
                    if playerObj and playerObj.resetEquippedHandsModels then
                        playerObj:resetEquippedHandsModels()
                        playerObj:resetModelNextFrame()
                    end
                end
                modData.IsLaserOn = false
            elseif LaserBeam then
                if lastLaserLog[logKey] ~= "beam-present" then
                    dbgLaser("[GGS LaserDBG] Beam already present on " .. tostring(MainGun))
                    lastLaserLog[logKey] = "beam-present"
                end
            elseif not HasPowerLaser(MainGun) then
                if lastLaserLog[logKey] ~= "no-power" then
                    dbgLaser("[GGS LaserDBG] No laser power on " .. tostring(MainGun))
                    lastLaserLog[logKey] = "no-power"
                end
            end
        else
            if lastLaserLog[logKey] ~= "no-mapping" then
                local laserType = Laser and Laser.getType and Laser:getType() or "nil"
                dbgLaser("[GGS LaserDBG] Laser missing or mapping not found for type=" .. tostring(laserType) .. " on " .. tostring(MainGun))
                lastLaserLog[logKey] = "no-mapping"
            end
            -- si no hay mapping o laser, limpia beam
            if MainGun.setWeaponPart then
                MainGun:setWeaponPart("Hide_Beam", nil)
                if playerObj and playerObj.resetEquippedHandsModels then
                    playerObj:resetEquippedHandsModels()
                    playerObj:resetModelNextFrame()
                end
            end
            modData.IsLaserOn = false
        end

        local Light = MainGun.getLight and MainGun:getLight() or nil
        if not Light and MainGun.getWeaponPart then
            Light = MainGun:getWeaponPart("Light")
        end
        if Light and Light.getLightDistance and Light.getLightStrength then
            -- Permite encender con la tecla o con el "Turn On" de contexto (usa Activated)
            local modeAllowsLight = (LightSet == "LaserAndGunLight" or LightSet == "GunLight")
            local aiming = playerObj.isAiming and playerObj:isAiming() or false
            if manualOn and not modeAllowsLight and MainGun.setActivated then
                MainGun:setActivated(false)
                manualOn = false
            end
            if not modeAllowsLight then
                modData.IsGunLightOn = false
            end
            local wantsLight = HasPowerLight(MainGun) and aiming and modeAllowsLight
            local canLight = wantsLight and ((modData.IsGunLightOn == true) or (manualOn and modeAllowsLight))
            if manualOn and modeAllowsLight then
                modData.IsGunLightOn = true
            end
            if canLight then
                MainGun:setTorchCone(true)
                MainGun:setLightDistance(Light:getLightDistance())
                MainGun:setLightStrength(Light:getLightStrength())
                MainGun:setActivated(true)
                modData.IsGunLightOn = true
                updateGunLightSource(playerObj, MainGun, Light:getLightStrength(), Light:getLightDistance())
            else
                if (MainGun.isTorchCone and MainGun:isTorchCone()) or (MainGun.getLightDistance and MainGun:getLightDistance() ~= 0) or (MainGun.getLightStrength and MainGun:getLightStrength() ~= 0) then
                    MainGun:setTorchCone(false)
                    MainGun:setLightDistance(0.0)
                    MainGun:setLightStrength(0.0)
                    MainGun:setActivated(false)
                end
                -- Si el modo sigue siendo de luz y solo dejamos de apuntar, conservamos el flag para reencender al volver a apuntar.
                if modeAllowsLight and HasPowerLight(MainGun) then
                    -- mantiene IsGunLightOn como estaba
                else
                    modData.IsGunLightOn = false
                end
                disableGunLightSource(MainGun)
            end
        else
            if (MainGun.isTorchCone and MainGun:isTorchCone()) or (MainGun.getLightDistance and MainGun:getLightDistance() ~= 0) or (MainGun.getLightStrength and MainGun:getLightStrength() ~= 0) then
                MainGun:setTorchCone(false)
                MainGun:setLightDistance(0.0)
                MainGun:setLightStrength(0.0)
                MainGun:setActivated(false)
                modData.IsGunLightOn = false
            end
            disableGunLightSource(MainGun)
        end
    end

    local ok, err = pcall(run)
    if not ok then
        dbgLaser("[GGS LaserDBG] LocalLaserUpdate error: " .. tostring(err))
    end
end

Events.OnPlayerUpdate.Add(LocalLaserUpdate)

-- Registro de tecla (evita duplicados)
local _ggsLaserKeyRegistered = _G.__ggsLaserKeyRegistered or false
_G.__ggsLaserKeyRegistered = _ggsLaserKeyRegistered

local function getSwitchKey()
    -- Algunos setups usan la key mal escrita en options.ini (SwtichLightSet)
    local k = getCore():getKey("SwtichLightSet")
    if not k or k <= 0 then
        k = getCore():getKey("SwitchLightSet")
    end
    if not k or k <= 0 then
        k = 33 -- F por defecto
    end
    return k
end

local function cycleLightMode(player, weapon)
    if not player or not weapon then
        return
    end

    startSwitchAnim(player)

    local modData = ensureLightState(weapon)
    local set = _G.AWCWF_LaserAndGunLightSwitchSet
    if type(set) ~= "table" or #set == 0 then
        return
    end

    local idx = tonumber(modData.index) or 1
    if idx >= #set then
        idx = 1
    else
        idx = idx + 1
    end

    modData.index = idx
    modData.Type = set[idx]
    modData.IsLaserOn = (modData.Type == "Laser" or modData.Type == "LaserAndGunLight")
    modData.IsGunLightOn = (modData.Type == "GunLight" or modData.Type == "LaserAndGunLight")
    weapon:getModData().NowLightSet = modData

    local key = "IGUI_LightMode_" .. tostring(modData.Type)
    if player.Say then
        player:Say(getText(key))
    end
end

local function KeyCheck(key)
    local target = getSwitchKey()
    if key ~= target then
        return
    end

    local player = getPlayer()
    if not player then
        return
    end
    local MainGun = player:getPrimaryHandItem()
    if not MainGun or not MainGun.IsWeapon or not MainGun:IsWeapon() or not MainGun.isRanged or not MainGun:isRanged() then
        return
    end

    dbgLaser(string.format("[GGS LaserDBG] Switch key pressed key=%s target=%s gun=%s", tostring(key), tostring(target), tostring(MainGun)))
    cycleLightMode(player, MainGun)
end

local function registerLaserKey()
    if _ggsLaserKeyRegistered then
        return
    end
    _ggsLaserKeyRegistered = true
    _G.__ggsLaserKeyRegistered = true
    -- Protege si algun evento no existe en esta fase de carga
    if Events and Events.OnKeyPressed and Events.OnKeyPressed.Add then
        Events.OnKeyPressed.Add(KeyCheck)
    else
        dbgLaser("[GGS LaserDBG] WARN: Events.OnKeyPressed no disponible al registrar la tecla")
    end
    dbgLaser("[GGS LaserDBG] Key handlers ready, switchKey=" .. tostring(getSwitchKey()))
end

Events.OnGameStart.Add(registerLaserKey)
Events.OnGameBoot.Add(registerLaserKey)

local callback_ISToolTipInv_render = ISToolTipInv and ISToolTipInv.render or nil
local smallFontHeight = getTextManager():getFontHeight(UIFont.Small) + 5

local function drawText(self, data)
    local tooltipHeight = 5
    local tooltipWidth = self.tooltip:getWidth()
    for _, v in pairs(data) do

        tooltipWidth = math.max(tooltipWidth, getTextManager():MeasureStringX(UIFont.Small, v.desc) + 5)

        tooltipHeight = tooltipHeight + smallFontHeight
    end
    self:drawRect(0, -tooltipHeight, tooltipWidth, tooltipHeight, self.backgroundColor.a, self.backgroundColor.r,
        self.backgroundColor.g, self.backgroundColor.b)
    self:drawRectBorder(0, -tooltipHeight, tooltipWidth, tooltipHeight, self.borderColor.a, self.borderColor.r,
        self.borderColor.g, self.borderColor.b)
    local x = 5
    local y = -tooltipHeight + 5
    for _, v in pairs(data) do
        self:drawText(v.desc, x, y, v.r or 1, v.g or 1, v.b or 0, v.a or 1, UIFont.Small)
        y = y + smallFontHeight
    end
end

local function formatSignedNumber(value)
    if type(value) ~= "number" then
        return tostring(value)
    end
    local rounded = math.floor(value + 0.5)
    if math.abs(value - rounded) < 0.001 then
        return string.format("%+d", rounded)
    end
    return string.format("%+.2f", value)
end

local function addPartStatLine(lines, label, value, isBetterWhenNegative)
    if type(value) ~= "number" then
        return
    end
    if math.abs(value) < 0.0001 then
        return
    end

    local isGood = isBetterWhenNegative and value < 0 or (not isBetterWhenNegative and value > 0)
    table.insert(lines, {
        desc = string.format("%s %s", tostring(label), formatSignedNumber(value)),
        r = isGood and 0.15 or 1,
        g = isGood and 0.95 or 0.3,
        b = isGood and 0.15 or 0.3,
        a = 1
    })
end

local function measureCompactTooltip(lines)
    local width = 160
    local height = 8
    for i = 1, #lines do
        local line = lines[i]
        width = math.max(width, getTextManager():MeasureStringX(UIFont.Small, line.desc) + 10)
        height = height + smallFontHeight
    end
    return width, height
end

local function positionCompactTooltip(self, width, height)
    local mx = getMouseX() + 24
    local my = getMouseY() + 24
    if not self.followMouse then
        mx = self:getX()
        my = self:getY()
        if self.anchorBottomLeft then
            mx = self.anchorBottomLeft.x
            my = self.anchorBottomLeft.y
        end
    end

    local maxX = getCore():getScreenWidth()
    local maxY = getCore():getScreenHeight()
    local x = math.max(0, math.min(mx, maxX - width - 1))
    local y
    if not self.followMouse and self.anchorBottomLeft then
        y = math.max(0, math.min(my - height, maxY - height - 1))
    else
        y = math.max(0, math.min(my, maxY - height - 1))
    end

    self:setX(x)
    self:setY(y)
    self:setWidth(width)
    self:setHeight(height)

    if self.contextMenu and self.contextMenu.joyfocus then
        local playerNum = self.contextMenu.player
        self:setX(getPlayerScreenLeft(playerNum) + 60)
        self:setY(getPlayerScreenTop(playerNum) + 60)
    elseif self.contextMenu and self.contextMenu.currentOptionRect then
        if self.contextMenu.currentOptionRect.height > 32 then
            self:setY(my + self.contextMenu.currentOptionRect.height)
        end
        self:adjustPositionToAvoidOverlap(self.contextMenu.currentOptionRect)
    elseif self.followMouse and (self.contextMenu == nil) then
        self:adjustPositionToAvoidOverlap({
            x = mx - 24 * 2,
            y = my - 24 * 2,
            width = 24 * 2,
            height = 24 * 2
        })
    end
end

local function renderCompactTooltip(self, lines)
    if not lines or #lines == 0 then
        return false
    end

    local width, height = measureCompactTooltip(lines)
    positionCompactTooltip(self, width, height)

    self:drawRect(0, 0, self.width, self.height, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g,
        self.backgroundColor.b)
    self:drawRectBorder(0, 0, self.width, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g,
        self.borderColor.b)

    local y = 5
    for i = 1, #lines do
        local v = lines[i]
        self:drawText(v.desc, 5, y, v.r or 1, v.g or 1, v.b or 1, v.a or 1, UIFont.Small)
        y = y + smallFontHeight
    end
    return true
end

local function renderCompactWeaponPartTooltip(self, item)
    local lines = {}
    table.insert(lines, {
        desc = tostring((item.getDisplayName and item:getDisplayName()) or (item.getName and item:getName()) or
            (item.getFullType and item:getFullType()) or "WeaponPart"),
        r = 1,
        g = 1,
        b = 1,
        a = 1
    })

    if item.getPartType then
        local partType = item:getPartType()
        if partType and partType ~= "" then
            table.insert(lines, {
                desc = "PartType: " .. tostring(partType),
                r = 0.8,
                g = 0.8,
                b = 0.8,
                a = 1
            })
        end
    end

    if item.getWeight then
        local weight = item:getWeight()
        if type(weight) == "number" then
            table.insert(lines, {
                desc = string.format("Weight %.2f", weight),
                r = 0.8,
                g = 0.8,
                b = 0.8,
                a = 1
            })
        end
    end

    addPartStatLine(lines, "AimingTimeModifier", item.getAimingTime and item:getAimingTime() or nil, true)
    addPartStatLine(lines, "HitChanceModifier", item.getHitChance and item:getHitChance() or nil, false)
    addPartStatLine(lines, "RecoilDelayModifier", item.getRecoilDelay and item:getRecoilDelay() or nil, true)
    addPartStatLine(lines, "ReloadTimeModifier", item.getReloadTime and item:getReloadTime() or nil, true)
    addPartStatLine(lines, "MaxRangeModifier", item.getMaxRange and item:getMaxRange() or nil, false)

    if item.getPartType and item:getPartType() == "Laser" then
        local modData = item:getModData().LaserBatteryReamin
        if not modData then
            modData = 100
            item:getModData().LaserBatteryReamin = modData
        end
        table.insert(lines, {
            desc = getText("IGUI_Light_BatteryRemaining_Laser") .. tostring(modData),
            r = 1,
            g = 1,
            b = 0,
            a = 1
        })
    elseif item.getPartType and item:getPartType() == "Light" then
        local modData = item:getModData().LightBatteryReamin
        if not modData then
            modData = 100
            item:getModData().LightBatteryReamin = modData
        end
        table.insert(lines, {
            desc = getText("IGUI_Light_CurrentLightSet_GunLight") .. tostring(modData),
            r = 1,
            g = 1,
            b = 0,
            a = 1
        })
    end

    -- Compact tooltip intentionally hides "Can be mounted on..." because 3DUI already handles compatibility.
    return renderCompactTooltip(self, lines)
end

local function PowerDown()
    local playerObj = getPlayer()
    if not playerObj then
        return
    end
    local MainGun = playerObj:getPrimaryHandItem()
    if not MainGun or not isObjectIndexable(MainGun) or not MainGun.IsWeapon or not MainGun:IsWeapon() or not MainGun.isRanged or not MainGun:isRanged() then
        return
    end

    local lightState = ensureLightState(MainGun)
    local Laser = MainGun.getLaser and MainGun:getLaser() or nil
    if Laser then
        local modData = MainGun:getModData().LaserBatteryReamin
        if not modData then
            modData = 100
            MainGun:getModData().LaserBatteryReamin = modData
        end
        if modData and modData > 0 and lightState.IsLaserOn then
            modData = modData - 0.1
            MainGun:getModData().LaserBatteryReamin = safeRound(modData, 1)
        end
    end
    local Light = MainGun.getLight and MainGun:getLight() or nil
    if Light then
        local modData = MainGun:getModData().LightBatteryReamin
        if not modData then
            modData = 100
            MainGun:getModData().LightBatteryReamin = modData
        end
        if modData and modData > 0 and lightState.IsGunLightOn then
            modData = modData - 0.1
            MainGun:getModData().LightBatteryReamin = safeRound(modData, 1)
        end
    end
end

Events.EveryOneMinute.Add(PowerDown)

if ISToolTipInv then
function ISToolTipInv:render()
    local item = self.item
    if not item then
        return
    end

    if instanceof(item, "WeaponPart") then
        local okCompact, renderedOrErr = pcall(renderCompactWeaponPartTooltip, self, item)
        if okCompact and renderedOrErr then
            return
        end
        if not okCompact then
            print("[GGS LaserDBG] compact tooltip error: " .. tostring(renderedOrErr))
        end
    end

    if callback_ISToolTipInv_render then
        local ok, err = pcall(callback_ISToolTipInv_render, self)
        if not ok then
            print("[GGS LaserDBG] tooltip render error: " .. tostring(err))
            -- si el vanilla fallo, no sigas dibujando para evitar spam
            return
        end
    end

    local data = {}
    if item.IsWeapon and item:IsWeapon() and item.isRanged and item:isRanged() then
        local Laser = item.getLaser and item:getLaser() or nil
        local Light = item.getLight and item:getLight() or nil
        if Laser then
            local modData = item:getModData().LaserBatteryReamin
            if not modData then
                modData = 100
            end
            table.insert(data, {
                desc = getText("IGUI_Light_BatteryRemaining_Laser") .. modData
            })
        end
        if Light then
            local modData = Light:getModData().LightBatteryReamin
            if not modData then
                modData = 100
            end
            table.insert(data, {
                desc = getText("IGUI_Light_BatteryRemaining_GunLight") .. modData
            })
        end
        if drawText then
            pcall(drawText, self, data)
        end
    end
end
end
