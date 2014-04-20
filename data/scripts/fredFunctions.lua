include("class.lua")

local FredFunctions = class()

function FredFunctions:init(partFred)
    self.particleFred = partFred

    self.__index = _G
    self._G = _G
end

function FredFunctions:effect(name)
    local effect = particleTrailScript:getEffectByName(name)

    if (effect) then
        self.effect = effect
    else
        self.particleFred:warningf("Invalid effect name %q encountered!", tostring(name))
    end
end

function FredFunctions:ship(name)
    local ship = mn.Ships[name]

    if (ship:isValid()) then
        self.ship = ship
    else
        self.particleFred:warningf("%q is an invalid ship name!", name)
    end
end

function FredFunctions:doEffect()
    if (self.effect) then
        if (self.ship) then
        end
    end
end

ParticleFredClass = class()

function ParticleFredClass:onFrame(time)
    if (self.inAction) then
        errorf("Detected open particle action! You have to call %q after you're done with particle manipulation!", "particle_end()")
        self:endActions()
    end

    self.inAction = false
end

function ParticleFredClass:beginActions()
    self.inAction = true

    self.functions = FredFunctions(self)
    setfenv(0, self.functions)
end

function ParticleFredClass:endActions()
    setfenv(0, self.functions._G)

    self.inAction = false
    self.functions = nil
end

function particle_begin()
    particleFred:beginAcrions()
end

function particle_end()
    particleFred:endActions()
end

particleFred = ParticleFredClass()
