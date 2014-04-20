include("class.lua")
include("particles.lua")
include("util.lua")

ObjectTrailInfo = class()

function ObjectTrailInfo:init(class, trailEffect, state, startTime, length, minSpeed, maxSpeed, maxSize, minSize, minNum, maxNum, typee, trail, options)
    self.class = class

    self.trailEffect = trailEffect

    self.state = state

    self.startTime = startTime
    self.length = length

    self.maxSize = maxSize
    self.minSize = minSize

    self.minSpeed = minSpeed
    self.maxSpeed = maxSpeed

    self.minNum = minNum
    self.maxNum = maxNum

    self.trailEff = trail

    self.options = options

    self:initType(typee)

    self.particleEmitter = {}
end

function ObjectTrailInfo:getOption(key, default)
    if (self.options) then
        local val = self.options[key]

        if (val == nil) then
            return default
        else
            return val
        end
    else
        return default
    end
end

function ObjectTrailInfo:hasOption(key)
    return self:getOption(key) ~= nil
end

function ObjectTrailInfo:isValid()
    if (self.class == nil or not self.class:isValid()) then
        if (not self.isDebris and not self:getOption("defaultDebrisInfo", false)) then
            return false, "Class", true
        end
    end

    if (self.trailEffect == nil or not self.trailEffect:isValid()) then
        return false, "Effect", true
    end

    if (self.state == nil or not type(self.state) ~= "string") then
        return false, "Emitstate", false
    end

    return true
end

function ObjectTrailInfo:initType(type)
    type = type:lower();

    if (type == "ship") then
        self.isShip = true
        self.isWeapon = false
        self.isDebris = false
    elseif (type == "weapon") then
        self.isShip = false
        self.isWeapon = true
        self.isDebris = false
    elseif (type == "debris") then
        self.isShip = false
        self.isWeapon = false
        self.isDebris = true
    else
        errorf("ObjectTrailInfo: Unknown type %q!", type)
    end
end

function ObjectTrailInfo:getType()
    if (self.isShip) then
        return "Ship"
    elseif (self.isWeapon) then
        return "Weapon"
    elseif (self.isDebris) then
        return "Debris"
    else
        stackError("ObjectTrailInfo: Invalid type state detected! Please report!")
        return nil
    end
end

function ObjectTrailInfo:isInFreeflight(weapon)
    if (weapon.Class.FreeFlightTime <= 0) then
        return false
    end

    return getWeaponLivingTime(weapon) <= weapon.Class.FreeFlightTime
end

function ObjectTrailInfo:isIgniting(weapon)
    if (weapon.Class.FreeFlightTime <= 0) then
        return false
    end

    if (not weapon.HomingObject:isValid()) then
        return false
    end

    return ((getWeaponLivingTime(weapon) >= weapon.Class.FreeFlightTime) and ((getWeaponLivingTime(weapon) - ba.getFrametime()) <= weapon.Class.FreeFlightTime))
end

function ObjectTrailInfo:checkShipState(ship)
    if (self.state == "default") then
        return true
    end

    if (self.state == "warpin") then
        return ship:isWarpingIn()
    end

    if (self.state == "afterburner") then
        return ship.Physics:isAfterburnerActive()
    end

    if (self.state == "normal") then
        return (not ship:isWarpingIn() and not ship.Physics:isAfterburnerActive())
    end

    if (self:isSubsystem()) then
        if (self.state == "destroyed") then
            return self:subsystemDestroyed(ship)
        end
    end

    stackErrorf("Invalid state (%q) made it into %q!", self.state, "checkShipState")
    return false
end

function ObjectTrailInfo:isSubsystem()
    return self.isShip and self:getOption("subsystem") ~= nil
end

function ObjectTrailInfo:getSubsystem(ship)
    if (not self:isSubsystem()) then
        return nil
    end

    if (ship.Class.Name ~= self.class.Name) then
        return nil
    end

    if (self.subsystemFailed) then
        printf("Tried to find invalid subsystem %q on ship %q!", self:getOption("subsystem"), ship.Name)
        return nil
    end

    local subsys = ship[self:getOption("subsystem")]

    if (subsys:isValid()) then
        return subsys
    else
        self.subsystemFailed = true
        return nil
    end
end

function ObjectTrailInfo:subsystemDestroyed(ship)
    if (not ship:isValid()) then
        return false
    end

    local subsys = self:getSubsystem(ship)

    if (subsys == nil or not subsys:isValid()) then
        return false
    end

    return subsys.HitpointsLeft == 0
end

function ObjectTrailInfo:wasCreated(weapon)
    return getWeaponLivingTime(weapon) <= 0
end

function ObjectTrailInfo:checkWeaponState(weapon)
    if (self.state == "default") then
        return true
    end

    if (self.state == "freeflight") then
        return self:isInFreeflight(weapon)
    end

    if (self.state == "ignition") then
        return self:isIgniting(weapon)
    end

    if (self.state == "homedflight") then
        return ((weapon.HomingObject:isValid()) and (not self:isInFreeflight(weapon)))
    end

    if (self.state == "unhomedflight") then
        return ((not weapon.HomingObject:isValid()) and (not self:isInFreeflight(weapon)))
    end

    if (self.state == "creation") then
        return self:wasCreated(weapon)
    end

    return true
end

function ObjectTrailInfo:getShipPercentage(ship)
    if (not ship:isValid()) then
        return -1
    end

    return (ship.HitpointsLeft / ship.Class.HitpointsMax) * 100
end

function ObjectTrailInfo:getSubsystemPercentage(ship)
    if (not ship:isValid()) then
        return -1
    end

    if (not self:isSubsystem()) then
        return -1
    end

    local subsys = self:getSubsystem(ship)

    if (subsys and subsys:isValid()) then
        return (subsys.HitpointsLeft / subsys.HitpointsMax) * 100
    else
        return -1
    end
end

function ObjectTrailInfo:getPercentage(ship)
    if (self:isSubsystem()) then
        return self:getSubsystemPercentage(ship)
    else
        return self:getShipPercentage(ship)
    end
end

function ObjectTrailInfo:checkDamage(ship)
    local start = self:getOption("damageStartLevel", 100)
    local endLevel = self:getOption("damageEndLevel", 0)

    local perc = self:getPercentage(ship)

    if (perc > start) then
        return false
    end

    if (perc < endLevel) then
        return false
    end

    return true
end

function ObjectTrailInfo:checkShip(ship)
    if (not self.isShip) then
        return false
    end

    if (not ship:isValid()) then
        return false
    end

    if (ship.Class.Name ~= self.class.Name) then
        return false
    end

    if (self:getOption("damageTrail", false)) then
        if (not self:checkDamage(ship)) then
            return false
        end
    end

    return self:checkShipState(ship)
end

function ObjectTrailInfo:checkWeapon(weapon)
    if (not self.isWeapon) then
        return false
    end

    if (not weapon:isValid()) then
        return false
    end

    if (weapon.Class.Name ~= self.class.Name) then
        return false
    end

    return self:checkWeaponState(weapon)
end

function ObjectTrailInfo:checkDebris(debris)
    if (not self.isDebris) then
        return false
    end

    if (not debris:isValid()) then
        return false
    end

    if (not debris.IsHull) then
        return false
    end

    if (self.class == nil) then
        return self:getOption("defaultDebrisInfo", false) and deathParticleScript:isUnhandledDebrisClass(debris.OriginClass)
    else
        if (debris.OriginClass.Name == self.class.Name) then
            return true
        else
            return false
        end
    end
end

function ObjectTrailInfo:createEmitter(obj)
    if (obj:isValid()) then
        if (self.particleEmitter[obj:getSignature()] ~= nil) then
            return nil
        end

        local em
        if (self.isShip) then
            em = ShipTrailEmitter(self, obj)
        elseif (self.isWeapon) then
            em = WeaponTrailEmitter(self, obj)
        elseif (self.isDebris) then
            em = DebrisTrailEmitter(self, obj)
        else
            stackError("Reached impossible code. This information is corrupt. If it happens again please report.")
            return
        end

        self.particleEmitter[obj:getSignature()] = em

        return em
    end
end

function ObjectTrailInfo:onFrame(time, spawn)
    if (self.particleEmitter == nil) then
        return
    end

    for i, v in pairs(self.particleEmitter) do
        v:onFrame(time, spawn)
    end
end

function ObjectTrailInfo:clearEmitter()
    if (self.particleEmitter == nil) then
        return
    end

    for i, v in pairs(self.particleEmitter) do
        if (not v:isValid()) then
            self.particleEmitter[i] = nil
        end
    end
end

ObjectTrailEmitter = class(ParticleEmitter)

function ObjectTrailEmitter:init(particleInfo, obj)
    self:__defaultInit(particleInfo, obj)

    self.ppsStack = 0
end

function ObjectTrailEmitter:isValid()
    local b, c, h = self.info:isValid()
    if (not (self.obj ~= nil and self.obj:isValid() and (b or not h))) then
        return false
    end

    if (self.info.isWeapon) then
        return self.info:checkWeapon(self.obj:get())
    elseif (self.info.isShip) then
        return self.info:checkShip(self.obj:get())
    elseif (self.info.isDebris) then
        return true
    else
        stackError("Reached impossible code. Please report!")
        return false
    end
end

function ObjectTrailEmitter:isDone()
    if (not self.info.startTime) then
        return false
    else
        if (self.info.length) then
            return self.time < (self.info.startTime + self.info.length)
        else
            return false
        end
    end
end

function ObjectTrailEmitter:checkSpawn()
    if (not self:isValid()) then
        return false
    end

    if (self:isDone()) then
        return false
    end

    if (self.info.startTime) then
        if (self.info.startTime > self.time) then
            return false
        end
    end

    return true
end

function ObjectTrailEmitter:onFrame(time, spawn)
    if (spawn and self:checkSpawn()) then
        self:createParticles()
    end

    self.time = self.time + time
end

function ObjectTrailEmitter:createParticles()
    stackError("This method should be called on one of the subclasses!")
end

function ObjectTrailEmitter:createParticle(position, velocity, radius)
    local part = ts.createParticle(position, velocity, 10, radius, PARTICLE_BITMAP, -1, false, self.info.trailEffect)
    if (type(self.info:getOption("fpsValues")) == "table" and part ~= nil) then
        local t = self.info:getOption("fpsValues")

        local val = t[1]
        if (#t > 1) then
            val = self:rand(t[1], t[2])
        end

        local lifeTime = self.info.trailEffect:getFramesLeft() / val

        part.MaximumLife = lifeTime
    end

    if (part) then
        if (type(self.info.trailEff) == "table") then
            self.info.trailEff:createEmitter(ObjectWrapper(part, "Particle"))
        end
    end
end

function ObjectTrailEmitter:getVelocity(default)
    local parentVel = self.obj:getVelocity()

    if (not default) then
        default = parentVel
    end

    local particleVel
    if (not self.info.minSpeed and not self.info.maxSpeed) then
        particleVel = default
    else
        particleVel = parentVel * ((self:rand(self.info.minSpeed, self.info.maxSpeed)) / 100)
    end

    if (type(self.info:getOption("velocityVariance")) == "number") then
        local variance = self.info:getOption("velocityVariance")

        if (variance > 0) then
            -- Shamelessly stolen from the FreeSpace source code
            particleVel.x = particleVel.x + (math.random() * 2 - 1) * variance
            particleVel.y = particleVel.y + (math.random() * 2 - 1) * variance
            particleVel.z = particleVel.z + (math.random() * 2 - 1) * variance
        end
    end

    return particleVel
end

ShipTrailEmitter = class(ObjectTrailEmitter)

function ShipTrailEmitter:init(particleInfo, obj)
    self:__defaultInit(particleInfo, obj)

    if (self.info:isSubsystem()) then
        self.subsys = self.info:getSubsystem(obj:get())
    end
end

function ShipTrailEmitter:thrusterLocation(thruster, loc)
    if (thruster == nil or not thruster:isValid()) then
        return ba.createVector(0, 0, 0)
    end

    if (not loc) then
        return self.obj:getPosition() + self.obj:getOrientation():unrotateVector(thruster.Position)
    else
        return self.obj:getOrientation():unrotateVector(thruster.Position)
    end
end

function ShipTrailEmitter:randomRadiusVector(radius)
    local x = math.random() * 2 - 1
    local y = math.random() * 2 - 1
    local z = math.random() * 2 - 1

    local vec = ba.createVector(x, y, z):getNormalized()

    return vec * self:rand(0, radius)
end

function ShipTrailEmitter:getDamageNumber(origNumber)
    local perc = self.info:getShipPercentage(self.obj:get())

    local start = self.info:getOption("damageStartLevel", 100)
    local maximum = self.info:getOption("damageMaximumLevel", 0)

    -- This should not happen, but you never know...
    if (perc > start) then
        return 0
    end

    if (perc < maximum) then
        return origNumber
    end

    local diff = start - maximum

    local fac = (start - perc) / diff

    return origNumber * fac
end

function ShipTrailEmitter:createPointParticles(number, radius, offset, thrusterPoint)
    if (not self.info:getOption("pps")) then
        local pos
        if (thrusterPoint) then
            pos = self:thrusterLocation(thrusterPoint)
        else
            pos = self.obj:getPosition()
        end

        self:create(number, radius, offset, thrusterPoint, pos)
    else
        local pps = self.info:getOption("pps")

        local displacement

        if (thrusterPoint) then
            displacement = self:thrusterLocation(thrusterPoint, true)
        else
            displacement = Globals.nullVec
        end

        local currNum = pps * ba.getFrametime() + self.ppsStack
        self.ppsStack = currNum

        if (currNum < 1) then
            return
        end

        local posDiff = self.obj:get().LastPosition - self.obj:getPosition()

        local i = 0
        local dec = 1 / currNum
        while (i <= 1) do
            self:create(number, radius, offset, thrusterPoint, self.obj:getPosition() + posDiff * i + displacement)

            self.ppsStack = self.ppsStack - 1
            i = i + dec
        end
    end
end

function ShipTrailEmitter:create(number, radius, offset, thrusterPoint, pos)
    if (offset) then
        pos = pos + offset
    end

    if (self.info.isShip and self.info:getOption("damageTrail", false)) then
        number = self:getDamageNumber(number)
    end

    if (self.info:getOption("useThrusterStrength", false)) then
        number = number * self.obj:get().Physics.ForwardThrust
    end

    for i = 1, number do
        local doit = true
        if (self.info:getOption("density", nil) and math.random() > self.info:getOption("density")) then
            doit = false
        end

        if (doit) then
            if (radius > 0) then
                if (self.info:getOption("radiusFactor")) then
                    radius = radius * self.info:getOption("radiusFactor")
                end

                pos = pos + self:randomRadiusVector(radius)
            end

            local vel = self:getVelocity()

            local rad
            if (self.info:getOption("fixedSize", false)) then
                if (not self.info.minSize and not self.info.maxSize) then
                    rad = 1
                else
                    rad = self:rand(self.info.minSize, self.info.maxSize)
                end
            else
                if (not self.info.minSize and not self.info.maxSize) then
                    rad = 100
                else
                    rad = self:rand(self.info.minSize, self.info.maxSize)
                end

                if (thrusterPoint) then
                    rad = thrusterPoint.Radius * (rad / 100)
                else
                    rad = self.obj:getRadiusPart(rad)
                end
            end

            self:createParticle(pos, vel, rad)
        end
    end
end

function ShipTrailEmitter:createParticles()
    if (not self:isValid()) then
        return
    end

    local offset = Globals.nullVec
    if (self.info:getOption("originOffset")) then
        offset = offset + self.obj:getOrientation():unrotateVector(self.info:getOption("originOffset"))
    end

    if (self.subsystem ~= nil and self.subsystem:isValid()) then
        offset = offset + self.obj:getOrientation():unrotateVector(self.subsystem.Position)
    end

    local model = self.obj:getModel()
    if (self.subsystem == nil and self.info:getOption("UseThruster", false) and model and model:isValid()) then

        local thrusters = model.Thrusters
        for i = 1, #thrusters do
            local thrusterBank = thrusters[i]
            for j = 1, #thrusterBank do
                local glow = thrusterBank[j]
                if (glow:isValid()) then
                    local num

                    if (not self.info.minNum and not self.info.maxNum) then
                        num = 1
                    else
                        num = self:rand(self.info.minNum, self.info.maxNum)
                    end

                    self:createPointParticles(num, glow.Radius, offset, glow)
                end
            end
        end
    else
        local pos = self.obj:getPosition()

        local num
        if (not self.info.minNum and not self.info.maxNum) then
            num = 1
        else
            num = self:rand(self.info.minNum, self.info.maxNum)
        end

        self:createPointParticles(num, self.info:getOption("radius", 0), offset, nil)
    end
end

WeaponTrailEmitter = class(ShipTrailEmitter)

function WeaponTrailEmitter:init(particleInfo, obj)
    self:__defaultInit(particleInfo, obj)
end

DebrisPointInformation = class()

function DebrisPointInformation:init(point, frameDelay)
    self.point = point

    self.frameDelay = frameDelay

    if (self.frameDelay) then
        self.frameCounter = math.random(0, self.frameDelay)
    end
end

function DebrisPointInformation:doFrame()
    if (self.frameCounter) then
        self.frameCounter = self.frameCounter + 1
    end
end

function DebrisPointInformation:shouldCreate()
    if (not self.frameDelay) then
        return true
    end

    if (self.frameDelay > self.frameCounter) then
        return false
    else
        self.frameCounter = 0
        return true
    end
end

DebrisTrailEmitter = class(ShipTrailEmitter)

function DebrisTrailEmitter:init(particleInfo, obj)
    self:__defaultInit(particleInfo, obj)

    self:initPositions()

    self.frameCounter = 0

    if (self.info:getOption("density") ~= nil) then
        self.frameDelay = 1 / self.info:getOption("density")
    end
end

function DebrisTrailEmitter:initPositions()
    local debris = self.obj:get()

    self.ready = false

    if (debris.Physics:getSpeed() <= 0) then
        return
    end

    local num = self:rand(self.info.minNum, self.info.maxNum)

    if (num <= 0) then
        self.ready = true
        return
    end

    local startingPoint = debris.Position + (debris.Physics.Velocity:getNormalized() * -20 * debris:getDebrisRadius())

    local points = {}

    local failed = 0
    for i = 1, num do
        local vec, num = self:doRay(startingPoint, 5)

        if (not vec) then
            printf("DebrisTrailEmitter: Warning: No debris point found after %d tries.\n", num)
            failed = failed + 1
        else
            table.insert(points, DebrisPointInformation(vec, self.frameDelay))
        end
    end

    if (failed > (num / 5)) then
        printf("DebrisTrailEmitter: Warning: More than one fifth of the debris ray casts have failed (%d failed)!\n", num)
    end

    self.points = points

    self.ready = true
end

function DebrisTrailEmitter:doRay(startingPoint, tries)
    local vec
    local try = 0

    while (not vec and try < 5) do
        local randVec = (self.obj:get().Physics.Velocity:getOrientation():unrotateVector(ba.createVector(math.random(), math.random(), math.random()))) * self.obj:getRadius()

        local endPoint = self.obj:get().Position + randVec

        vec = self.obj:get():checkRayCollision(startingPoint, endPoint, true)

        try = try + 1
    end

    return vec, try
end

function DebrisTrailEmitter:onFrame(time, spawn)
    if (not self.ready) then
        self:initPositions()
    end

    if (self.ready) then
        if (spawn and self:checkSpawn()) then
            -- stackErrorf("Creating particles for %q", tostring(self.obj:get()))

            self:createParticles()
        end

        self.frameCounter = self.frameCounter + 1

        self.time = self.time + time
    end
end

function DebrisTrailEmitter:createFor(debrisInfo)
    local vel = self:getVelocity(Globals.nullVec)

    local rad
    if (self.info:getOption("fixedSize", false)) then
        if (not self.info.minSize and not self.info.maxSize) then
            rad = 1
        else
            rad = self:rand(self.info.minSize, self.info.maxSize)
        end
    else
        if (not self.info.minSize and not self.info.maxSize) then
            rad = 100
        else
            rad = self:rand(self.info.minSize, self.info.maxSize)
        end

        rad = self.obj:getRadiusPart(rad)
    end

    local add = debrisInfo.point

    if (self.info:getOption("originOffset")) then
        add = add + self.info:getOption("originOffset")
    end

    self:createParticle(self.obj:getPosition() + self.obj:getOrientation():unrotateVector(add), vel, rad)
end

function DebrisTrailEmitter:createParticles()
    if (self.ready) then
        for _, v in ipairs(self.points) do
            if (v:shouldCreate()) then
                self:createFor(v)
            end

            v:doFrame()
        end
    end
end

function DebrisTrailEmitter:checkSpawn()
    if (not self:isValid()) then
        return false
    end

    if (not self.ready) then
        return false
    end

    if (self:isDone()) then
        return false
    end

    return true
end
