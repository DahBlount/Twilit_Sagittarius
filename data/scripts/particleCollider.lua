include("class.lua")
include("util.lua")

ParticleCollisionEntry = class()

function ParticleCollisionEntry:init(particle, ...)
    self.particle = particle

    self.objects = {}

    for _, v in ipairs(arg) do
        if (v:isValid()) then
            table.insert(self.objects, v)
        end
    end
end

function ParticleCollisionEntry:checkObjects(time)
    local p1 = self.particle.Position
    local p2 = p1 + (self.particle.Velocity * time)

    local length = (self.particle.Velocity * time):getMagnitude()

    for _, v in ipairs(self.objects) do
        if (v:isValid()) then
            if (self:checkObject(v, p1, p2, length)) then
                break
            end
        end
    end
end

function ParticleCollisionEntry:checkObject(obj, p1, p2, length)
    local point, info = obj:checkRayCollision(p1, p2)

    if (point ~= nil) then
        -- This will have a better performence with the info:getCollisionDistance() function
        local dist = p1:getDistance(point)

        if (dist <= length) then
            self.particle.Velocity = self:computeReflectVector(info:getCollisionNormal(), self.particle.Velocity) * safeRand(0.75, 0.95)
            self.particle.Position = point

            return true
        end
    end

    return false
end

function ParticleCollisionEntry:computeReflectVector(normal, incoming)
    return incoming - 2 * normal * (incoming:getDotProduct(normal))
end

function ParticleCollisionEntry:isValid()
    if (self.particle == nil or not self.particle:isValid()) then
        return false
    end

    if (#self.objects == 0) then
        return false
    end

    return true
end

ParticleCollider = class()

function ParticleCollider:init()
    self.checkParticles = {}
end

function ParticleCollider:onMissionStart()
end

function ParticleCollider:onFrame(time)
    for _, v in ipairs(self.checkParticles) do
        if (v:isValid()) then
            v:checkObjects(time)
        end
    end

    self:cleanup()
end

function ParticleCollider:cleanup()
    local index = 1
    local done = false

    while (not done) do
        for i = index, #self.checkParticles do
            if (not self.checkParticles[i]:isValid()) then
                table.remove(self.checkParticles, i)
                index = i
                break
            end
        end

        done = true
    end
end

function ParticleCollider:onMissionEnd()
    self.checkParticles = {}
end

function ParticleCollider:registerPair(particle, ...)
    if (type(particle) ~= "userdata") then
        stackErrorf("Invalid type %q!", type(particle))
    end

    local entry = ParticleCollisionEntry(particle, ...)
    table.insert(self.checkParticles, entry)

    if (entry:isValid()) then
        entry:checkObjects(ba.getFrametime())
    end
end

Globals.particleCollider = ParticleCollider()
