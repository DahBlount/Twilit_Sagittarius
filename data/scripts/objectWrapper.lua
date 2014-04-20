include("class.lua")

ObjectWrapper = class()

function ObjectWrapper:init(obj, typee)
    if (not type(typee) == "string") then
        ba.error("ObjectWrapper: Invalid object type!")
        return
    end
    typee = typee:lower()

    if (typee == "ship") then
        self.isShip = true
        self.isWeapon = false
        self.isParticle = false
        self.isDebris = false
    elseif (typee == "weapon") then
        self.isShip = false
        self.isWeapon = true
        self.isParticle = false
        self.isDebris = false
    elseif (typee == "particle") then
        self.isShip = false
        self.isWeapon = false
        self.isParticle = true
        self.isDebris = false
    elseif (typee == "debris") then
        self.isShip = false
        self.isWeapon = false
        self.isParticle = false
        self.isDebris = true
    else
        errorf("objectWrapper: Unknown object type %q!", typee)
    end

    self.obj = obj
end

function ObjectWrapper:getPosition()
    return self.obj.Position
end

function ObjectWrapper:getVelocity()
    if (self.isParticle) then
        return self.obj.Velocity
    else
        return self.obj.Physics.Velocity
    end
end

function ObjectWrapper:getName()
    if (self.isShip) then
        return self.obj.Name
    else
        return nil
    end
end

function ObjectWrapper:getOrientation()
    if (self.isShip or self.isDebris) then
        return self.obj.Orientation
    else
        return self:getVelocity():getOrientation()
    end
end

function ObjectWrapper:isValid()
    if (self.obj == nil) then
        return false
    end

    return self.obj:isValid()
end

function ObjectWrapper:get()
    return self.obj
end

function ObjectWrapper:getRadius()
    if (self.isShip) then
        return self.obj.Class.Model.Radius
    elseif (self.isDebris) then
        return self.obj:getDebrisRadius()
    elseif (self.isWeapon) then
        if (self.obj.Class.Model:isValid()) then
            return self.obj.Class.Model.Radius
        else
            return 1
        end
    else
        return self.obj.Radius
    end
end

function ObjectWrapper:getRadiusPart(part)
    if (self.isShip or self.isDebris) then
        return self:getRadius() * (part / 100)
    elseif (self.isWeapon) then
        if (self.obj.Class:isMissile()) then
            return self:getRadius() * (part / 100)
        else
            return part
        end
    else
        return self:getRadius() * (part / 100)
    end
end

function ObjectWrapper:getSignature()
    if (self.isParticle) then
        return nil
    else
        return self.obj:getSignature()
    end
end

function ObjectWrapper:getModel()
    if (self.isShip) then
        return self.obj.Class.Model
    elseif (self.isDebris) then
        return nil
    end

    if (self.isWeapon) then
        if (self.obj.Class:isMissile()) then
            return obj
        else
            return nil
        end
    end

    return nil
end
