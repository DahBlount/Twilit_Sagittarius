include("class.lua")
include("effectManager.lua")
include("parser.lua")
include("particles.lua")
include("particleParser.lua")
include("objectWrapper.lua")
include("trailInfo.lua")


math.randomseed(os.time())

ParticleTrailScript = class()

function ParticleTrailScript:init()
    if (deathParticleScript) then
        stackError("This class should not be instantiated more than once!")
        return
    end

    self.configurationFiles = { "particles.cfg" }

    self.informationTable = {}
    self.objectInfoTable = {}

    self.minimumFrameTime = nil
end

function ParticleTrailScript:addConfigFile(fileName)
    if (type(fileName) ~= "string") then
        return false
    end

    table.insert(self.configurationFiles, fileName)
end

function ParticleTrailScript:parseConfigFiles()
    self.informationTable = {}

    local start = os.clock()

    for _, v in ipairs(self.configurationFiles) do
        self:__doParse(v)
    end

    self:generateTrails()

    printf("PARTICLE SCRIPT: Configuration file read. Loaded %d entries and took %.2f s\n", #self.informationTable + #self.objectInfoTable, os.clock() - start)
end

function ParticleTrailScript:__doParse(file)
    printf("PARTICLE SCRIPT: Parsing file %q\n", file)

    local system = ParseSystem(file, "", "//")
    local handler = ParticleTypeParser(system, ":", self)
    system:setHandler(handler)

    if (not system:isValid()) then
        printf("PARTICLE SCRIPT: Couldn't open configuration file %q\n", file)
        return
    end

    system:parseFile()
end

function ParticleTrailScript:buildTrailTable()
    local t = {}
    for i, v in ipairs(self.informationTable) do
        if (v.isParticle) then
            t[v.class] = v
        end
    end

    return t
end

function ParticleTrailScript:generateTrails()
    local t = self:buildTrailTable()

    for i, v in ipairs(self.informationTable) do
        if (type(v.trailEff) == "string") then
            local eff = t[v.trailEff]
            if (eff) then
                v.trailEff = eff
            else
                warningf("Trailname %q for particle definition defined in %s is invalid", v.trailEff, v.__definitionLocation)
                v.trailEff = nil
            end
        end
    end

    for i, v in ipairs(self.objectInfoTable) do
        if (type(v.trailEff) == "string") then
            local eff = t[v.trailEff]
            if (eff) then
                v.trailEff = eff
            else
                warningf("Trailname %q for particle definition defined in %s is invalid", v.trailEff, v.__definitionLocation)
                v.trailEff = nil
            end
        end
    end
end

function ParticleTrailScript:shouldExecute()
    if ((self.informationTable == nil or #self.informationTable < 1) and (self.objectInfoTable == nil or #self.objectInfoTable < 1)) then
        return false
    end

    return true
end

function ParticleTrailScript:shouldSpawnNewParticles(time)
    if (self.minimumFrameTime) then
        if (time > self.minimumFrameTime) then
            return false
        else
            return true
        end
    end

    return true
end

function ParticleTrailScript:resetTable()
    self.informationTable = {}
    self.objectInfoTable = {}
end

function ParticleTrailScript:getTable()
    return self.informationTable
end

function ParticleTrailScript:getObjectTable()
    return self.objectInfoTable
end

function ParticleTrailScript:doNormalInfoRun(time, shouldSpawn)
    if (self.informationTable == nil or #self.informationTable < 1) then
        return
    end

    for i = 1, #mn.Ships do
        local ship = mn.Ships[i]
        for j = 1, #self.informationTable do
            local info = self.informationTable[j]
            if (info.isShip and info:checkShip(ship)) then
                info:createEmitter(ObjectWrapper(ship, "Ship"))
            end
        end
    end

    for i = 1, #self.informationTable do
        local info = self.informationTable[i]
        info:onFrame(time, shouldSpawn)
        info:clearEmitter()
    end
end

function ParticleTrailScript:doObjectInfoRun(time, shouldSpawn)
    if (self.objectInfoTable == nil or #self.objectInfoTable < 1) then
        return
    end

    for i = 1, #self.objectInfoTable do
        local objectInfo = self.objectInfoTable[i]
        if (objectInfo:getType() == "Ship") then
            for j = 1, #mn.Ships do
                local ship = mn.Ships[j]

                if (objectInfo:checkShip(ship)) then
                    objectInfo:createEmitter(ObjectWrapper(ship, objectInfo:getType()))
                end
            end
        elseif (objectInfo:getType() == "Weapon") then
            for j = 1, #mn.Weapons do
                local weapon = mn.Weapons[j]

                if (objectInfo:checkWeapon(weapon)) then
                    objectInfo:createEmitter(ObjectWrapper(weapon, objectInfo:getType()))
                end
            end
        elseif (objectInfo:getType() == "Debris") then
            for j = 0, #mn.Debris do
                local debris = mn.Debris[j]

                if (objectInfo:checkDebris(debris)) then
                    objectInfo:createEmitter(ObjectWrapper(debris, objectInfo:getType()))
                end
            end
        else
            stackErrorf("Invalid trail object type %q found!", objectInfo:getType())
        end
    end

    for i = 1, #self.objectInfoTable do
        local info = self.objectInfoTable[i]
        info:onFrame(time, shouldSpawn)
        info:clearEmitter()
    end
end

function ParticleTrailScript:isUnhandledDebrisClass(class)
    if (not class or not class:isValid()) then
        return false
    end

    for i = 1, #self.objectInfoTable do
        local info = self.objectInfoTable[i]
        if (info:getType() == "Debris") then
            if (info.class) then
                if (info.class.Name == class.Name) then
                    return false
                end
            end
        end
    end

    return true
end

function ParticleTrailScript:getEffectByName(name)
    if (self.informationTable) then
        for i, v in pairs(self.informationTable) do
            if (v:getOption("name") == name) then
                return v
            end
        end
    end

    return nil
end

function ParticleTrailScript:getTrailByName(name)
    if (self.objectInfoTable) then
        for i, v in pairs(self.objectInfoTable) do
            if (v:getOption("name") == name) then
                return v
            end
        end
    end

    return nil
end

particleTrailScript = ParticleTrailScript()

------------------------------------------------------
--------- Global utility functions     -----------
------------------------------------------------------
function inMission(name)
    if (type(name) ~= "string") then
        return false
    end

    return mn.getMissionFilename() == name
end
