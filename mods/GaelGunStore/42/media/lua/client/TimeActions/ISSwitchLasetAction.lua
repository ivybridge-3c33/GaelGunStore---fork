require "TimedActions/ISBaseTimedAction"
ISSwitchLasetAction = ISBaseTimedAction:derive("ISSwitchLasetAction");
function ISSwitchLasetAction:isValid()
    return true
end
function ISSwitchLasetAction:update()
end
function ISSwitchLasetAction:start()
    self.character:setVariable("SwtichLaser", "true");
end
function ISSwitchLasetAction:stop()
    ISBaseTimedAction.stop(self);
    self.character:setVariable("SwtichLaser", "false");
end
function ISSwitchLasetAction:perform()
    ISBaseTimedAction.perform(self);
    self.character:setVariable("SwtichLaser", "false");
    local modData = self.weaopon:getModData().NowLightSet
    if modData == nil then
        modData = {
            Type = "nil",
            index = 1,
            IsLaserOn = false,
            IsGunLightOn = false
        }
    else
        if modData.index >= #AWCWF_LaserAndGunLightSwitchSet then
            modData.index = 1
        else
            modData.index = modData.index + 1
        end
        modData.Type = AWCWF_LaserAndGunLightSwitchSet[modData.index]
    end
    modData.IsLaserOn = (modData.Type == "Laser" or modData.Type == "LaserAndGunLight")
    modData.IsGunLightOn = (modData.Type == "GunLight" or modData.Type == "LaserAndGunLight")

    self.weaopon:getModData().NowLightSet = modData
    self.character:Say(getText("IGUI_LightMode_" .. modData.Type))
end
function ISSwitchLasetAction:new(character, time, weapon)
    local o = ISBaseTimedAction.new(self, character)
    o.weaopon = weapon
    o.stopOnWalk = true;
    o.stopOnRun = true;
    o.maxTime = time;
    return o;
end
