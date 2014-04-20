include("class.lua")
include("objectWrapper.lua")

ParticleInformation = class()

function ParticleInformation:init(shipClass, effect, state, minTime, maxTime, minNum, maxNum, minSpeed, maxSpeed, minSize, maxSize, minVec, maxVec, spewCones, typee, trailEff, additionalOptions)
    self.class = shipClass

    self.effect = effect

    self.state = state

    self.minTime = minTime
    self.maxTime = maxTime

    self.minNum = minNum
    self.maxNum = maxNum

    self.minSpeed = minSpeed
    self.maxSpeed = maxSpeed

    self.minSize = minSize
    self.maxSize = maxSize

    self.minVec = minVec
    self.maxVec = maxVec

    self.spewCones = spewCones
    if (type(self.spewCones) == "table") then
        for i = 1, #self.spewCones do
            self.spewCones[i] = math.sin(math.rad(self.spewCones[i]))
        end
    end

    self.trailEff = trailEff

    self.particleEmitter = {}

    self.options = additionalOptions

    self:initType(typee)
end

function ParticleInformation:getOption(key, default)
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

function ParticleInformation:hasOption(key)
    return self:getOption(key) ~= nil
end

function ParticleInformation:initType(type)
    type = type:lower()

    if (type == "ship") then
        self.isShip = true
        self.isWeapon = false
        self.isParticle = false
    elseif (type == "weapon") then
        self.isShip = false
        self.isWeapon = true
        self.isParticle = false
    elseif (type == "particle") then
        self.isShip = false
        self.isWeapon = false
        self.isParticle = true
    else
        errorf("ParticleInformation: Unknown type %q!", type)
    end
end

function ParticleInformation:checkNumbers(a, b)
    if (type(a) ~= "number" or type(b) ~= "number") then
        return false
    end

    if (a > b) then
        return false
    end

    return true
end


function ParticleInformation:isValid()
    if (not self.isParticle) then
        if (self.class == nil or not self.class:isValid()) then
            return false, "Class", true
        end
    else
        if (self.class == nil) then
            return false, "Trail name", true
        end
    end

    if (self.effect == nil or not self.effect:isValid()) then
        return false, "Effect", true
    end

    if (self.isShip and type(self.state) ~= "number") then
        return false, "State", true
    end

    if (not self.isParticle and not self:checkNumbers(self.minTime, self.maxTime)) then
        return false, "Time", false
    end

    if (not self:checkNumbers(self.minNum, self.maxNum)) then
        return false, "Number", true
    end

    if (not self.isParticle and not self:checkNumbers(self.minSpeed, self.maxSpeed)) then
        return false, "Speed", true
    end

    if (not self:checkNumbers(self.minSize, self.maxSize)) then
        return false, "Size", true
    end

    if (not self.isParticle and self.minVec == nil or self.maxVec == nil) then
        return false, "Vectors", false
    end

    return true
end

function ParticleInformation:checkShip(shp)
    if (not self.isShip) then
        return false
    end
    if (shp:hasShipExploded() == self.state and shp.Class.Name == self.class.Name and self.particleEmitter[shp.Name] == nil) then
        return true
    else
        return false
    end
end

function ParticleInformation:checkState(weapon)
    local state = self:getOption("emitstate")
    if (not state) then
        state = "impact"
    end

    if (state == "impact") then
        return weapon:getCollisionInformation():isValid()
    elseif (state == "intercepted") then
        return weapon.DestroyedByWeapon
    elseif (state == "self-destructed") then
        return not weapon:getCollisionInformation():isValid() and not weapon.DestroyedByWeapon
    else
        return false
    end
end

function ParticleInformation:checkWeapon(weap)
    if (not self.isWeapon) then
        return false
    end

    if (weap:isValid() and weap.Class.Name == self.class.Name) then
        if (self:checkState(weap)) then
            if (self:getOption("armedState") ~= nil) then
                return self:getOption("armedState") == weap:isArmed()
            else
                return true
            end
        end
    else
        return false
    end
end

function ParticleInformation:createEmitter(obj)
    if (obj:isValid()) then
        local em
        if (self.isShip or self.isWeapon) then
            em = ObjectParticleEmitter(self, obj)
        elseif (self.isParticle) then
            em = ParticleTrailEmitter(self, obj)
        else
            stackErrorf("Reached impossible code. This information is corrupt. Please report if it happens again.")
        end

        self.particleEmitter[obj] = em

        local n = obj:getName()
        if (n) then
            self.particleEmitter[n] = em
        end

        return em
    end
end

function ParticleInformation:onFrame(time, spawn)
    if (self.particleEmitter == nil) then
        return
    end

    for i, v in pairs(self.particleEmitter) do
        if (type(i) ~= "string") then
            v:onFrame(time, spawn)
        end
    end
end

function ParticleInformation:clearEmitter()
    if (self.particleEmitter == nil) then
        return
    end

    for i, v in pairs(self.particleEmitter) do
        if (not v:isValid()) then
            self.particleEmitter[i] = nil
        end
    end
end

ParticleEmitter = class()

function ParticleEmitter:__index(index)
    if (index == "isShip" or index == "isWeapon" or index == "isParticle" or index == "isDebris") then
        stackErrorf("%q is an index that should point to the particle information.\nPlease report.")

        return self.info[index]
    end

    return nil
end

function ParticleEmitter:init(particleInfo, obj)
    self:__defaultInit(particleInfo, obj)
end

function ParticleEmitter:__defaultInit(particleInfo, obj)
    self.info = particleInfo
    self.obj = obj

    self.targetNum = self:rand(self.info.minNum, self.info.maxNum)

    self.time = 0
end

function ParticleEmitter:onFrame(time, spawn)
    if (spawn and self:checkSpawn()) then
        self:createParticles(time)
    end

    self.time = self.time + time
end

function ParticleEmitter:rand(min, max, exact)
    if (min == nil and max ~= nil) then
        return max
    elseif (max == nil and min ~= nil) then
        return min
    elseif (min == nil and max == nil) then
        return 0
    end

    if (min == max) then
        return min
    end

    if (exact) then
        if (min > max) then
            return math.random(max, min)
        else
            return math.random(min, max)
        end
    else
        if (min > max) then
            return max + (min - max) * math.random()
        else
            return min + (max - min) * math.random()
        end
    end
end

function ParticleEmitter:oneOf(...)
    if (arg.n < 1) then
        return nil
    end

    local increase = 1 / arg.n
    local current = increase

    local val = math.random()
    for i = 1, arg.n do
        if (val < current) then
            return arg[i]
        end

        current = current + increase
    end

    return nil
end

function ParticleEmitter:getPosition(pos, orient)
    stackError("This method should be called on one of the subclasses!")
end

function ParticleEmitter:getVelocity(orient, originPoint)
    stackError("This method should be called on one of the subclasses!")
end

function ParticleEmitter:createParticles(time, targetPosition)
    stackError("This method should be called on one of the subclasses!")
end

function ParticleEmitter:isValid()
    local b, c, h = self.info:isValid()
    return self.obj ~= nil and self.obj:isValid() and (b or not h)
end

function ParticleEmitter:isDone()
    if (not self.info.maxTime) then
        return false
    else
        if (self.info.minTime) then
            return self.time - self.info.minTime > self.info.maxTime
        else
            return self.time > self.info.maxTime
        end
    end
end

function ParticleEmitter:checkSpawn()
    if (not self:isValid()) then
        return false
    end

    if (self:isDone()) then
        return false
    end

    if (self.info.minTime and self.time < self.info.minTime) then
        return false
    end

    if (self.info:getOption("density") ~= nil) then
        if (self.frameDelay > self.frameCounter) then
            return false
        else
            self.frameCounter = 0
        end
    end

    return true
end

function ParticleEmitter:randomSign()
    local n = math.random()
    if (n > 0.5) then
        return 1
    elseif (n == 0.5) then
        return 0
    else
        return -1
    end
end

ObjectParticleEmitter = class(ParticleEmitter)

function ObjectParticleEmitter:init(particleInfo, obj)
    self:__defaultInit(particleInfo, obj)

    self.timeStack = 0
end

function ObjectParticleEmitter:getEdgeposition()
    local switch = self:rand(1, 3, true)
    local vec = ba.createVector()

    if (switch == 1) then
        vec.x = self:oneOf(self.info.minVec.x, self.info.maxVec.x)
        vec.y = self:rand(self.info.minVec.y, self.info.maxVec.y)
        vec.z = self:rand(self.info.minVec.z, self.info.maxVec.z)
    elseif (switch == 2) then
        vec.x = self:rand(self.info.minVec.x, self.info.maxVec.x)
        vec.y = self:oneOf(self.info.minVec.y, self.info.maxVec.y)
        vec.z = self:rand(self.info.minVec.z, self.info.maxVec.z)
    else
        vec.x = self:rand(self.info.minVec.x, self.info.maxVec.x)
        vec.y = self:rand(self.info.minVec.y, self.info.maxVec.y)
        vec.z = self:oneOf(self.info.minVec.z, self.info.maxVec.z)
    end

    return vec
end

function ObjectParticleEmitter:doRaycasting(pos, orient)
    for i = 1, self.info:getOption("raycastRetries", 5) do
        local rayEnd
        if (not self.info.minVec or not self.info.maxVec) then
            local xFactor
            local yFactor
            local zFactor

            if (self.info.spewCones) then
                xFactor = self.info.spewCones[1]
                if (not xFactor) then xFactor = 1 end

                yFactor = self.info.spewCones[2]
                if (not yFactor) then yFactor = 1 end

                zFactor = self.info.spewCones[3]
                if (not zFactor) then zFactor = 1 end
            else
                xFactor = 1
                yFactor = 1
                zFactor = 1
            end

            rayEnd = ba.createVector()
            rayEnd.x = math.random() * self:randomSign() * xFactor
            rayEnd.y = math.random() * self:randomSign() * yFactor
            rayEnd.z = math.random() * self:randomSign() * zFactor

            if (orient) then
                rayEnd = orient:unrotateVector(rayEnd) * self.obj:getRadius() + pos
            else
                rayEnd = rayEnd * self.obj:getRadius() + pos
            end
        else

            if (orient) then
                rayEnd = orient:unrotateVector(self:getEdgeposition()) + pos
            else
                rayEnd = self:getEdgeposition() + pos
            end
        end


        local vec, colInfo = self.obj:get():checkRayCollision(rayEnd, pos)
        if (vec) then
            if (colInfo ~= nil and colInfo:isValid()) then
                return vec, colInfo:getCollisionNormal(true)
            else
                return vec
            end
        end
    end

    printf("PARTICLE SCRIPT: Ray check failed %d times! No result found.", self.info:getOption("raycastRetries", 5))

    return nil
end

function ObjectParticleEmitter:getPosition(pos, orient)
    if (self.info.isShip and self.info:getOption("doCreationRaycast")) then
        return self:doRaycasting(pos, orient)
    end

    if (not self.info.minVec or not self.info.maxVec) then
        return pos
    end

    local unrBoxMin
    local unrBoxMax

    if (orient) then
        unrBoxMin = orient:unrotateVector(self.info.minVec)
        unrBoxMax = orient:unrotateVector(self.info.maxVec)
    else
        unrBoxMin = self.info.minVec
        unrBoxMax = self.info.maxVec
    end

    local randX = self:rand(unrBoxMin.x, unrBoxMax.x)
    local randY = self:rand(unrBoxMin.y, unrBoxMax.y)
    local randZ = self:rand(unrBoxMin.z, unrBoxMax.z)

    local result = ba.createVector(randX, randY, randZ) + pos

    return result
end

function ObjectParticleEmitter:getVelocity(orient, creationPoint, originPoint, directionOverride)
    if (not self.info.minSpeed and not self.info.maxSpeed) then
        return ba.createVector(0, 0, 0)
    end
    if (self.info.minSpeed == 0 and self.info.maxSpeed == 0) then
        return ba.createVector(0, 0, 0)
    end

    local speedFactor
    if (self.info.minSpeed and self.info.maxSpeed) then
        speedFactor = math.random(self.info.minSpeed, self.info.maxSpeed)
    elseif (self.info.maxSpeed and not self.info.minSpeed) then
        speedFactor = self.info.maxSpeed
    elseif (self.info.minSpeed and not self.info.maxSpeed) then
        speedFactor = self.info.minSpeed
    end

    local xFactor
    local yFactor
    local zFactor

    local x
    local y
    local z

    local needsRotate = true

    if (directionOverride ~= nil) then
        x = directionOverride.x
        y = directionOverride.y
        z = directionOverride.z
    elseif (self.info:getOption("moveOutwards")) then
        local vel = creationPoint - originPoint

        x = vel.x
        y = vel.y
        z = vel.z

        needsRotate = false
    elseif (self.info:getOption("emitVector")) then
        local vec = self.info:getOption("emitVector")

        x = vec.x
        y = vec.y
        z = vec.z

        local variance = self.info:getOption("emitVariance", 0)
        if (variance > 0) then
            -- Shamelessly stolen from the FreeSpace source code
            x = x + (math.random() * 2 - 1) * variance
            y = y + (math.random() * 2 - 1) * variance
            z = z + (math.random() * 2 - 1) * variance
        end

    elseif (self.info:getOption("xOffset") or self.info:getOption("yOffset") or self.info:getOption("zOffset")) then
        local default = { 0, 0 }
        x = self:rand(self.info:getOption("xOffset", default)[1], self.info:getOption("xOffset", default)[2])
        y = self:rand(self.info:getOption("yOffset", default)[1], self.info:getOption("yOffset", default)[2])
        z = self:rand(self.info:getOption("zOffset", default)[1], self.info:getOption("zOffset", default)[2])
    else
        if (self.info.spewCones) then
            xFactor = self.info.spewCones[1]
            if (not xFactor) then xFactor = 1 end

            yFactor = self.info.spewCones[2]
            if (not yFactor) then yFactor = 1 end

            zFactor = self.info.spewCones[3]
            if (not zFactor) then zFactor = 1 end
        else
            xFactor = 1
            yFactor = 1
            zFactor = 1
        end

        x = math.random() * self:randomSign() * xFactor
        y = math.random() * self:randomSign() * yFactor
        z = math.random() * self:randomSign() * zFactor
    end


    local vec

    if (orient and needsRotate) then
        vec = orient:unrotateVector(ba.createVector(x, y, z):getNormalized() * speedFactor)
    else
        vec = ba.createVector(x, y, z):getNormalized() * speedFactor
    end

    if (self.info:getOption("additiveVelocity", true)) then
        vec = vec + self.obj:getVelocity() * self.info:getOption("velocityFactor", 1)
    end

    return vec
end

function ObjectParticleEmitter:computeReflectVector(normal, incoming)
    return incoming - 2 * normal * (incoming:getDotProduct(normal))
end

function ObjectParticleEmitter:createParticles(time, targetPosition)
    if (not self:isValid()) then
        return false
    end

    local orient

    if (self.info.isWeapon and self.info:getOption("useNormal", false)) then
        if (self.info:getOption("absoluteNormal")) then
            orient = self.info:getOption("absoluteNormal")
        else
            local colInfo = self.obj:get():getCollisionInformation()
            if (colInfo and colInfo:isValid()) then
                local normal = colInfo:getCollisionNormal()

                if (normal) then
                    if (self.info:getOption("reflect", false)) then
                        orient = self:computeReflectVector(normal, self.obj:getVelocity()):getOrientation()
                    else
                        orient = normal:getOrientation()
                    end
                else
                    orient = self.obj:getOrientation()
                end
            else
                orient = self.obj:getOrientation()
            end
        end
    else
        orient = self.obj:getOrientation()
    end

    local pos
    if (targetPosition) then
        pos = targetPosition
    else
        if (self.info.isWeapon) then
            if (self.info:getOption("collides", false)) then
                -- most likely a HACK: set the position to the last position of the weapon so it handles collision right (hopefully...)
                pos = self.obj:get().LastPosition
            else
                local colInfo = self.obj:get():getCollisionInformation()
                if (colInfo and colInfo:isValid()) then
                    pos = colInfo:getCollisionPoint()
                else
                    pos = self.obj:getPosition()
                end
            end
        else
            pos = self.obj:getPosition()
        end
    end

    if (self.info:getOption("originOffset", nil)) then
        pos = pos + orient:unrotateVector(self.info:getOption("originOffset"))
    end

    local num = self.targetNum
    if (not self.info.isWeapon and self.info.maxTime > 0) then
        num = self.targetNum * time
        if (num < 1) then
            self.timeStack = self.timeStack + time
            num = self.targetNum * self.timeStack
            if (num < 1) then
                return
            end
            self.timeStack = 0
        else
            self.timeStack = 0
        end
    end

    for i = 1, num do
        local radius = self.obj:getRadiusPart(self:rand(self.info.minSize, self.info.maxSize))

        local createPos, velOverride = self:getPosition(pos, orient)

        if (self.info:getOption("createWeapons", false)) then
            local vel = self:getVelocity(orient, createPos, pos, velOverride)
            if (createPos) then
                local weapon = mn.createWeapon(self.info.effect, vel:getOrientation(), createPos, self.obj:get())
                weapon.Physics.Velocity = vel

                if (weapon) then
                    if (type(self.info.trailEff) == "table") then
                        self.info.trailEff:createEmitter(ObjectWrapper(weapon, "Weapon"))
                    end
                end
            end
        else
            if (createPos) then
                local part = ts.createParticle(createPos, self:getVelocity(orient, createPos, pos, velOverride), 10, radius, PARTICLE_BITMAP, -1, false, self.info.effect)
                if (type(self.info:getOption("fpsValues")) == "table" and part ~= nil) then
                    local t = self.info:getOption("fpsValues")

                    local val = t[1]
                    if (#t > 1) then
                        val = self:rand(t[1], t[2])
                    end

                    local lifeTime = self.info.effect:getFramesLeft() / val

                    part.MaximumLife = lifeTime
                end

                if (part and self.info:getOption("collides", false)) then
                    if (self.otherObject ~= nil and self.otherObject:isValid()) then
                        Globals.particleCollider:registerPair(part, self.otherObject)
                    end
                end

                if (part) then
                    if (type(self.info.trailEff) == "table") then
                        self.info.trailEff:createEmitter(ObjectWrapper(part, "Particle"))
                    end
                end
            end
        end
    end

    return true
end

function ObjectParticleEmitter:setOtherObject(obj)
    self.otherObject = obj
end

ParticleTrailEmitter = class(ParticleEmitter)

function ParticleTrailEmitter:init(particleInfo, obj)
    self:__defaultInit(particleInfo, obj)

    self.frameCounter = 0

    if (self.info:getOption("density") ~= nil) then
        self.frameDelay = 1 / self.info:getOption("density")
    end

    self.lastPosition = self.obj:getPosition()
    self.ppsStack = 0
end

function ParticleTrailEmitter:onFrame(time, spawn)
    if (spawn and self:checkSpawn()) then
        self:createParticles(time)
    end

    self.lastPosition = self.obj:getPosition()

    self.frameCounter = self.frameCounter + 1

    self.time = self.time + time
end

function ParticleTrailEmitter:create(number, position, orient)
    local radius

    if (not self.info:getOption("fixedParticleSize", false)) then
        radius = self.obj:getRadiusPart(self:rand(self.info.minSize, self.info.maxSize))
    else
        radius = self:rand(self.info.minSize, self.info.maxSize)
    end

    if (self.info:getOption("createWeapons", false)) then
        if (position) then
            local weapon = mn.createWeapon(self.info.effect, vel:getOrientation(), position, self.obj:get())
            weapon.Physics.Velocity = self:getVelocity(orient, position)

            if (weapon) then
                if (type(self.info.trailEff) == "table") then
                    self.info.trailEff:createEmitter(ObjectWrapper(weapon, "Weapon"))
                end
            end
        end
    else
        if (position) then
            local part = ts.createParticle(position, self:getVelocity(orient, position), 10, radius, PARTICLE_BITMAP, -1, false, self.info.effect)
            if (type(self.info:getOption("fpsValues")) == "table" and part ~= nil) then
                local t = self.info:getOption("fpsValues")

                local val = t[1]
                if (#t > 1) then
                    val = self:rand(t[1], t[2])
                end

                local lifeTime = self.info.effect:getFramesLeft() / val

                part.MaximumLife = lifeTime
            end

            if (part) then
                if (type(self.info.trailEff) == "table") then
                    self.info.trailEff:createEmitter(ObjectWrapper(part, "Particle"))
                end
            end
        end
    end
end

function ParticleTrailEmitter:createParticles()
    if (not self:isValid()) then
        return false
    end

    local pos = self.obj:getPosition()

    local orient = self.obj:getOrientation()

    local num = self.targetNum

    if (self.info:hasOption("pps")) then
        local pps = self.info:getOption("pps")

        local currNum = pps * ba.getFrametime() + self.ppsStack
        self.ppsStack = currNum

        if (currNum < 1) then
            return
        end

        local posDiff = self.lastPosition - self.obj:getPosition()

        local i = 0
        local dec = 1 / currNum
        while (i <= 1) do
            local pos = self:getPosition(pos, orient) + posDiff * i

            self:create(num, pos)

            self.ppsStack = self.ppsStack - 1
            i = i + dec
        end
    else
        self:create(num, self:getPosition(pos, orient), orient)
    end

    return true
end

function ParticleTrailEmitter:getPosition(pos, orient)
    if (orient and self.info:getOption("originOffset")) then
        pos = pos + orient:unrotateVector(self.info:getOption("originOffset"))
    end

    return pos
end

function ParticleTrailEmitter:getVelocity(orient, originPoint)
    if (not self.info.minSpeed and not self.info.maxSpeed) then
        return ba.createVector(0, 0, 0)
    end
    if (self.info.minSpeed == 0 and self.info.maxSpeed == 0) then
        return ba.createVector(0, 0, 0)
    end

    local speedFactor
    if (self.info.minSpeed and self.info.maxSpeed) then
        speedFactor = self:rand(self.info.minSpeed, self.info.maxSpeed)
    elseif (self.info.maxSpeed and not self.info.minSpeed) then
        speedFactor = self.info.maxSpeed
    elseif (self.info.minSpeed and not self.info.maxSpeed) then
        speedFactor = self.info.minSpeed
    end

    return self.obj:getVelocity() * (speedFactor / 100)
end
