include("class.lua")
include("parser.lua")
include("particles.lua")
include("trailInfo.lua")

ParticleTypeParser = class(ParseHandler)

function ParticleTypeParser:init()
    self.currentHandler = nil

    self.inIfChunk = false
    self.ifStatus = nil

    self.availableHandlers = {}

    self.availableHandlers["Ship"] = ParticleShipHandler(self.system, self.delim)
    self.availableHandlers["Weapon"] = ParticleWeaponHandler(self.system, self.delim)

    self.availableHandlers["ParticleTrail"] = ParticleTrailHandler(self.system, self.delim)

    self.availableHandlers["ShipTrail"] = ShipTrailHandler(self.system, self.delim)
    self.availableHandlers["WeaponTrail"] = WeaponTrailHandler(self.system, self.delim)
    self.availableHandlers["DebrisTrail"] = DebrisTrailHandler(self.system, self.delim)

    self:addHandlerFunction("$Type", self.handleType, "String")
    self:addHandlerFunction("$EndType", self.handleEndType)

    self:addHandlerFunction("$Minimum Framerate", self.handleFrameRate, "Number")

    self:addHandlerFunction("$Include", self.handleInclude, "String")
    self:addHandlerFunction("$Execute", self.handleExecute, "LuaCode")

    self:addHandlerFunction("$If", self.handleIf, "LuaCode")
    self:addHandlerFunction("$Else", self.handleElse)
    self:addHandlerFunction("$EndIf", self.handleEndIf)
end

function ParticleTypeParser:handleKeyValue(key, value)
    if (self.inIfChunk) then
        if (not self.ifStatus) then
            if (key ~= "$Else" and key ~= "$EndIf") then
                return
            end
        end
    end

    if (self.currentHandler and key ~= "$Type" and key ~= "$EndType") then
        self.currentHandler:handleKeyValue(key, value)
    else
        local handlerFunction = self.handlerFunctions[key]
        if (type(handlerFunction) == "table") then
            handlerFunction:handle(self.system, self, value, key)
        else
            if (self.defaultFunction) then
                self.defaultFunction(self, value, key)
            else
                self.system:warningf("Unknown key %q. Skipping line...", key)
            end
        end
    end
end

function ParticleTypeParser:handleType(val)
    if (self.currentHandler) then
        self.currentHandler:sectionEnded()
    end

    local handler = self.availableHandlers[val]

    if (not handler) then
        self.currentHandler = nil
        self.system:warningf("Unknown type %q. Skipping...", val)
    else
        handler:beginSection()
        self.currentHandler = handler
    end
end

function ParticleTypeParser:endOfFile()
    if (self.currentHandler) then
        self.currentHandler:sectionEnded()
    end
end

function ParticleTypeParser:handleFrameRate(val)
    particleTrailScript.minimumFrameTime = 1 / val
end

function ParticleTypeParser:handleInclude(val)
    if (val and particleTrailScript) then
        if (cf.fileExists(val, "", true)) then
            if (val:ends(".lua")) then
                execute_lua_file(val)
            else
                particleTrailScript:__doParse(val)
            end
        else
            self.system:warningf("The file %q does not exist!", val)
        end
    end
end

function ParticleTypeParser:handleExecute(val)
    val()
end

function ParticleTypeParser:handleEndType()
    if (self.currentHandler) then
        self.currentHandler:sectionEnded()
        self.currentHandler = nil
    else
        self.system:warningf("\"$EndType\" found but there was not section present.")
    end
end

function ParticleTypeParser:handleIf(func, key)
    local ret = func()

    if (type(ret) == "boolean") then
        self.ifStatus = ret
        self.inIfChunk = true
    elseif (type(ret) == "function") then
        self:handleIf(ret, key)
    else
        self.system:warningf("The lua code for the %q option should return a boolean or a function but it returns %q", key, type(ret))
    end
end

function ParticleTypeParser:handleElse(val, key)
    if (self.inIfChunk) then
        self.ifStatus = not self.ifStatus
    else
        self.system:warningf("Encoutnered %q outside an if-block!", key)
    end
end

function ParticleTypeParser:handleEndIf()
    self.inIfChunk = false
    self.ifStatus = nil
end

ParticleChunkHandler = class(ParseHandler)
function ParticleChunkHandler:init()
end

function ParticleChunkHandler:initInformation()
end

function ParticleChunkHandler:beginSection()
    self:initInformation()
end

function ParticleChunkHandler:sectionEnded()
end

function ParticleChunkHandler:initOptions()
    if (type(self.options) ~= "table") then
        self.options = {}
    end
end

function ParticleChunkHandler:addOption(key, val)
    if (key == nil) then
        return
    end

    self:initOptions()

    self.options[key] = val
end

function ParticleChunkHandler:hasOption(key)
    if (self.options == nil) then
        return false
    end

    return self.options[key] ~= nil
end

ParticleShipHandler = class(ParticleChunkHandler)

function ParticleShipHandler:init()
    self:initTokens()

    self:addHandlerFunction("+Subsystem", self.handleSubsystem, "String")
end

function ParticleShipHandler:initTokens()
    self:addHandlerFunction("$Class", self.handleClass)
    self:addHandlerFunction("+Effect", self.handleEffect)
    self:addHandlerFunction("+Emitstate", self.handleState)
    self:addHandlerFunction("+Time", self.handleTime)
    self:addHandlerFunction("+Number", self.handleNumber)
    self:addHandlerFunction("+Speed", self.handleSpeed)
    self:addHandlerFunction("+Size", self.handleSize)
    self:addHandlerFunction("+Box Min", self.handleBoxMin)
    self:addHandlerFunction("+Box Max", self.handleBoxMax)
    self:addHandlerFunction("+Spewcone", self.handleSpewcone)
    self:addHandlerFunction("+Trail", self.handleTrail)
    self:addHandlerFunction("+Trail Effect", self.handleTrailOld)
    self:addHandlerFunction("+Add Velocity", self.handleVelocityAdd)
    self:addHandlerFunction("+Offset", self.handleOffset)
    self:addHandlerFunction("+Velocity Factor", self.handleVelocityFactor)
    self:addHandlerFunction("+Weapon", self.handleWeaponEffect)
    self:addHandlerFunction("+FPS", self.handleFPS)
    self:addHandlerFunction("+Creation raycast", self.handleCreationRaycast)
    self:addHandlerFunction("+Raycast retries", self.handleRaycastRetries)
    self:addHandlerFunction("+Name", self.handleName)
    self:addHandlerFunction("+Fixed Size", self.handleFixedSize)
    self:addHandlerFunction("+Emit Vector", self.handleEmitVector, "Vector")
    self:addHandlerFunction("+Emit Variance", self.handleEmitVariance, "Number")
    self:addHandlerFunction("+Emit from hull", self.handleEmitFromHull)
    self:addHandlerFunction("+Move outwards", self.handleMoveOutwards)
    self:addHandlerFunction("+Use Ray normal", self.handleUseRayNormal)

    self:addHandlerFunction("+Velocity X Offset", self.handleXOffset)
    self:addHandlerFunction("+Velocity Y Offset", self.handleYOffset)
    self:addHandlerFunction("+Velocity Z Offset", self.handleZOffset)
end

function ParticleShipHandler:initInformation()
end

function ParticleShipHandler:beginSection()
    self:resetInfo()

    self.startLine = self.system.currentLine
end

function ParticleShipHandler:sectionEnded()
    self:writeInfo()
end

function ParticleShipHandler:writeInfo()
    local info = ParticleInformation(self.class,
        self.effect,
        self.state,
        self.minTime,
        self.maxTime,
        self.minNum,
        self.maxNum,
        self.minSpeed,
        self.maxSpeed,
        self.minSize,
        self.maxSize,
        self.boxMin,
        self.boxMax,
        self.spewCones,
        "Ship",
        self.trailName,
        self.options)

    local b, c, h = info:isValid()

    if (b or not h) then
        info.__definitionLocation = string.format("[%s]:%d", self.system.path, self.startLine)
        table.insert(particleTrailScript:getTable(), info)
    else
        self.system:warningf("Invalid definition found! Cause: %q", c)
    end
end

function ParticleShipHandler:resetInfo()
    self.class = nil
    self.effect = nil
    self.state = nil
    self.minTime = nil
    self.maxTime = nil
    self.minNum = nil
    self.maxNum = nil
    self.minSpeed = nil
    self.maxSpeed = nil
    self.minSize = nil
    self.maxSize = nil
    self.boxMin = nil
    self.boxMax = nil
    self.spewCones = nil
    self.trailName = nil
    self.options = nil
end

function ParticleShipHandler:handleClass(val)
    local c = self.system:convert("ShipClass", val)

    if (c) then
        self.class = c
    end
end

function ParticleShipHandler:handleEffect(val)
    local e = self.system:convert("Effect", val)
    if (e) then
        self.effect = e
        self:addOption("createWeapons", false)
    end
end

function ParticleShipHandler:handleState(val)
    local n = self.system:convert("Number", val)
    if (n) then
        if (n < 1 or n > 3) then
            self.system:warningf("%d is an invalid emitstate. Only states from 1 to 3 are allowed.")
        else
            self.state = n
        end
    end
end

function ParticleShipHandler:handleTime(val, key)
    local range = self.system:convert("NumberList", val)
    if (#range == 1) then
        self.minTime = 0
        self.maxTime = range[1]
    elseif (#range == 2) then
        self.minTime = range[1]
        self.maxTime = range[2]
    else
        self.system:warningf("%d is an invalid range count for %q", #range, key)
    end
end

function ParticleShipHandler:handleNumber(val)
    local range = self.system:convert("NumberList", val)
    if (#range == 1) then
        self.minNum = range[1]
        self.maxNum = range[1]
    elseif (#range == 2) then
        self.minNum = range[1]
        self.maxNum = range[2]
    else
        self.system:warningf("%d is an invalid range count for %q", #range, key)
    end
end

function ParticleShipHandler:handleSpeed(val)
    local range = self.system:convert("NumberList", val)
    if (#range == 1) then
        self.minSpeed = range[1]
        self.maxSpeed = range[1]
    elseif (#range == 2) then
        self.minSpeed = range[1]
        self.maxSpeed = range[2]
    else
        self.system:warningf("%d is an invalid range count for %q", #range, key)
    end
end

function ParticleShipHandler:handleSize(val)
    local range = self.system:convert("NumberList", val)
    if (#range == 1) then
        self.minSize = tonumber(range[1])
        self.maxSize = tonumber(range[1])
    elseif (#range == 2) then
        self.minSize = tonumber(range[1])
        self.maxSize = tonumber(range[2])
    else
        self.system:warningf("%d is an invalid range count for %q", #range, key)
    end
end

function ParticleShipHandler:handleBoxMin(val)
    local box = self.system:convert("Vector", val)
    if (box) then
        self.boxMin = box
    end
end

function ParticleShipHandler:handleBoxMax(val)
    local box = self.system:convert("Vector", val)
    if (box) then
        self.boxMax = box
    end
end

function ParticleShipHandler:handleOffset(val)
    local off = self.system:convert("Vector", val)
    if (off) then
        self:addOption("originOffset", off)
    end
end

function ParticleShipHandler:handleSpewcone(val, key)
    local cones = self.system:convert("NumberList", val)
    if (#cones > 3 or #cones < 1) then
        self.system:warningf("%d is an invalid range count for %q", #cones, key)
    else
        self.spewCones = {}
        for i = 1, #cones do
            self.spewCones[i] = cones[i]
        end
    end
end

function ParticleShipHandler:handleTrail(val)
    self.trailName = val
end

function ParticleShipHandler:handleFPS(val, key)
    local t = self.system:convert("NumberList", val)
    if (t and #t > 0 and #t < 3) then
        self:addOption("fpsValues", t)
    else
        self.system:warningf("%d is an invalid range count for %q", #t, key)
    end
end

function ParticleShipHandler:handleTrailOld(val)
    self.system:warningf("This token is deprecated. Please use \"+Trail\"\n")

    self:handleTrail(val)
end

function ParticleShipHandler:handleVelocityAdd(val)
    local bool = self.system:convert("Boolean", val)
    if (bool ~= nil) then
        self:addOption("additiveVelocity", bool)
    end
end

function ParticleShipHandler:handleVelocityFactor(val)
    local n = self.system:convert("Number", val)
    if (n) then
        self:addOption("velocityFactor", n)
        if (n == 0) then
            self:addOption("additiveVelocity", false)
        else
            self:addOption("additiveVelocity", true)
        end
    end
end

function ParticleShipHandler:handleWeaponEffect(val)
    local clas = self.system:convert("WeaponClass", val)

    if (clas) then
        self.effect = clas
        self:addOption("createWeapons", true)
    end
end

function ParticleShipHandler:handleXOffset(val, key)
    local t = self.system:convert("NumberList", val)
    if (t) then
        local off = { 0, 0 }
        if (#t == 1) then
            off[1] = t[1]
            off[2] = t[1]

            self:addOption("xOffset", off)
        elseif (#t == 2) then
            off[1] = t[1]
            off[2] = t[2]

            self:addOption("xOffset", off)
        else
            self.system:warningf("%d is an invalid range for %q", #t, key)
        end
    end
end

function ParticleShipHandler:handleYOffset(val, key)
    local t = self.system:convert("NumberList", val)
    if (t) then
        self:initOptions()
        local off = { 0, 0 }
        if (#t == 1) then
            off[1] = t[1]
            off[2] = t[1]

            self:addOption("yOffset", off)
        elseif (#t == 2) then
            off[1] = t[1]
            off[2] = t[2]

            self:addOption("yOffset", off)
        else
            self.system:warningf("%d is an invalid range for %q", #t, key)
        end
    end
end

function ParticleShipHandler:handleZOffset(val, key)
    local t = self.system:convert("NumberList", val)
    if (t) then
        local off = { 0, 0 }
        if (#t == 1) then
            off[1] = t[1]
            off[2] = t[1]

            self:addOption("zOffset", off)
        elseif (#t == 2) then
            off[1] = t[1]
            off[2] = t[2]

            self:addOption("zOffset", off)
        else
            self.system:warningf("%d is an invalid range for %q", #t, key)
        end
    end
end

function ParticleShipHandler:handleName(val)
    self:addOption("name", val)
end

function ParticleShipHandler:handleCreationRaycast(val)
    local bool = self.system:convert("Boolean", val)
    if (bool ~= nil) then
        self:addOption("doCreationRaycast", bool)
    end
end

function ParticleShipHandler:handleRaycastRetries(val)
    local n = self.system:convert("Number", val)
    if (n) then
        self:addOption("raycastRetries", n)
    end
end

function ParticleShipHandler:handleFixedSize(val)
    local b = self.system:convert("Boolean", val)
    if (b ~= nil) then
        self:addOption("fixedParticleSize", b)
    end
end

function ParticleShipHandler:handleEmitVector(val, key)
    if (val:getMagnitude() <= 0) then
        self.system:warningf("A vector with the magnitude of zero is not valid for %q!", key)
        return
    end

    self:addOption("emitVector", val)
end

function ParticleShipHandler:handleEmitVariance(val)
    self:addOption("emitVariance", val)
end

function ParticleShipHandler:handleEmitFromHull(val, key)
    if (not self.class) then
        self.system.warningf("$Class has to be specified before the %s entry", key)
        return
    end

    self:addOption("doCreationRaycast", true)
    self.boxMin = self.class.Model.BoundingBoxMin
    self.boxMax = self.class.Model.BoundingBoxMax
end

function ParticleShipHandler:handleMoveOutwards(val, key)
    self:addOption("moveOutwards", true)
end

function ParticleShipHandler:handleUseRayNormal(val, key)
    self:addOption("useRayNormal", true)
end

function ParticleShipHandler:handleSubsystem(val)
    self:addOption("subsystem", val)
end

ParticleWeaponHandler = class(ParticleShipHandler)

function ParticleWeaponHandler:init()
    self:initTokens()

    self:addHandlerFunction("+Use Normal", self.handleUseNormal, "Boolean")
    self:addHandlerFunction("+Absolute Normal", self.handleAbsoluteNormal, "Vector")
    self:addHandlerFunction("+Reflect", self.handleReflect)
    self:addHandlerFunction("+Armed", self.handleArmed, "Boolean")
    self:addHandlerFunction("+Particle collides", self.handleCollide, "Boolean")

    self:removeHandlerFunction("+Creation raycast")
    self:removeHandlerFunction("+Raycast retries")
    self:removeHandlerFunction("+Emit from hull")
    self:removeHandlerFunction("+Move outwards")
    self:removeHandlerFunction("+Use Ray normal")
end

function ParticleWeaponHandler:writeInfo()
    local info = ParticleInformation(self.class,
        self.effect,
        self.state,
        self.minTime,
        self.maxTime,
        self.minNum,
        self.maxNum,
        self.minSpeed,
        self.maxSpeed,
        self.minSize,
        self.maxSize,
        self.boxMin,
        self.boxMax,
        self.spewCones,
        "Weapon",
        self.trailName,
        self.options)

    local b, c, h = info:isValid()

    if (b or not h) then
        info.__definitionLocation = string.format("[%s]:%d", self.system.path, self.startLine)
        table.insert(particleTrailScript:getTable(), info)
    else
        self.system:warningf("Invalid definition found! Cause: %q", c)
    end
end

function ParticleWeaponHandler:handleClass(val)
    local c = self.system:convert("WeaponClass", val)
    if (c) then
        self.class = c
    end
end

function ParticleWeaponHandler:handleUseNormal(val)
    self:addOption("useNormal", val)
end

function ParticleWeaponHandler:handleAbsoluteNormal(val, key)
    if (val:getMagnitude() == 0) then
        self.system:warningf("The vector for %q may not have a magnitude of zero!", key)
        return
    end

    self:addOption("absoluteNormal", val:getOrientation())
end

function ParticleWeaponHandler:handleReflect()
    self:addOption("reflect", true)
end

function ParticleWeaponHandler:handleArmed(val)
    self:addOption("armedState", val)
end

function ParticleWeaponHandler:handleState(val)
    val = val:lower()

    if (val == "impact" or val == "intercepted" or val == "self-destructed") then
        self:addOption("emitstate", val)
    else
        self.system:warningf("Unknown emitstate %q.", val)
    end
end

function ParticleWeaponHandler:handleCollide(val)
    self:addOption("collides", val)
end

ParticleTrailHandler = class(ParticleChunkHandler)

function ParticleTrailHandler:init()
    self:addHandlerFunction("$Name", self.handleName)
    self:addHandlerFunction("+Effect", self.handleEffect)
    self:addHandlerFunction("+Speed", self.handleSpeed)
    self:addHandlerFunction("+Number", self.handleNumber)
    self:addHandlerFunction("+Size", self.handleSize)
    self:addHandlerFunction("+Life-Size Factor", self.handleLifeSize)
    self:addHandlerFunction("+FPS", self.handleFPS)
    self:addHandlerFunction("+Delay", self.handleDelay)
    self:addHandlerFunction("+Time", self.handleTime)
    self:addHandlerFunction("+Density", self.handleDensity)
    self:addHandlerFunction("+Offset", self.handleOffset, "Vector")
    self:addHandlerFunction("+Fixed Size", self.handleFixedSize, "Boolean")
    self:addHandlerFunction("+PPS", self.handlePPS, "Number")
end

function ParticleTrailHandler:beginSection()
    self:resetInfo()

    self.startLine = self.system.currentLine
end

function ParticleTrailHandler:sectionEnded()
    self:writeInfo()
end

function ParticleTrailHandler:writeInfo()
    local info = ParticleInformation(self.name,
        self.effect,
        nil,
        self.minTime,
        self.maxTime,
        self.minNum,
        self.maxNum,
        self.minSpeed,
        self.maxSpeed,
        self.minSize,
        self.maxSize,
        nil,
        nil,
        nil,
        "Particle",
        nil,
        self.options)

    local b, c, h = info:isValid()

    if (b or not h) then
        info.__definitionLocation = string.format("[%s]:%d", self.system.path, self.startLine)
        table.insert(particleTrailScript:getTable(), info)
    else
        self.system:warningf("Invalid definition found! Cause: %q", c)
    end
end

function ParticleTrailHandler:resetInfo()
    self.name = nil
    self.effect = nil
    self.minNum = 1
    self.maxNum = 1
    self.minSpeed = nil
    self.maxSpeed = nil
    self.minSize = nil
    self.maxSize = nil
    self.minTime = nil
    self.maxTime = nil
    self.options = {}
end

function ParticleTrailHandler:handleName(val)
    self.name = val
end

function ParticleTrailHandler:handleLifeSize(val)
    local n = self.system:convert("Number", val)
    if (n ~= nil) then
        self:initOptions()

        self:addOption("lifeSizeFactor", n)
    end
end

function ParticleTrailHandler:handleEffect(val)
    local e = self.system:convert("Effect", val)
    if (e) then
        self.effect = e
    end
end

function ParticleTrailHandler:handleNumber(val)
    local t = self.system:convert("NumberList", val)
    if (t and #t > 0 and #t < 3) then
        if (#t == 1) then
            self.minNum = t[1]
            self.maxNum = t[1]
        else
            self.minNum = t[1]
            self.maxNum = t[2]
        end
    else
        self.system:warningf("%d is an invalid range number for \"+Number\"", #t)
    end
end

function ParticleTrailHandler:handleSize(val)
    local t = self.system:convert("NumberList", val)
    if (t and #t > 0 and #t < 3) then
        if (#t == 1) then
            self.minSize = t[1]
            self.maxSize = t[1]
        else
            self.minSize = t[1]
            self.maxSize = t[2]
        end
    else
        self.system:warningf("%d is an invalid range number for \"+Size\"", #t)
    end
end

function ParticleTrailHandler:handleParticleManipulation()
    self.inParticleSection = true
end

function ParticleTrailHandler:handleEndToken()
    if (not self.inParticleSection) then
        self.system:warningf("Ending section using %q but there is no open section!", "$End")
    end
    self.inParticleSection = false
end

function ParticleTrailHandler:handleDamping(val)
    if (not self.inParticleSection) then
        self.system:warningf("Found damping option but there is no opened Particle Manipulation section! Please fix this.")
    end

    local damp = self.system:convert("Number", val)
    if (damp) then
        if (type(self.options["particleManipulation"]) ~= "table") then
            self:addOption("particleManipulation", {})
        end
        self.options["particleManipulation"]["damping"] = val
    end
end

function ParticleTrailHandler:handleSpeed(val, key)
    local range = self.system:convert("NumberList", val)
    if (#range == 1) then
        self.minSpeed = range[1]
        self.maxSpeed = range[1]
    elseif (#range == 2) then
        self.minSpeed = range[1]
        self.maxSpeed = range[2]
    else
        self.system:warningf("%d is an invalid range count for %q", #range, key)
    end
end

function ParticleTrailHandler:handleFPS(val, key)
    local t = self.system:convert("NumberList", val)
    if (t and #t > 0 and #t < 3) then
        self:addOption("fpsValues", t)
    else
        self.system:warningf("%d is an invalid range count for %q", #t, key)
    end
end

function ParticleTrailHandler:handleDelay(val)
    local del = self.system:convert("Number", val)
    if (del) then
        self.minTime = del
    end
end

function ParticleTrailHandler:handleTime(val)
    local time = self.system:convert("Number", val)
    if (time) then
        self.maxTime = time
    end
end

function ParticleTrailHandler:handleOffset(val)
    self:addOption("originOffset", val)
end

function ParticleTrailHandler:handleDensity(val, key)
    local n = self.system:convert("Number", val)
    if (n) then
        if (n > 1 or n <= 0) then
            self.system:warningf("%q is an invalid value for %q.\nOnly values that are greater that zero and less or equal to one are valied for %q.", val, key, key)
        else
            self:addOption("density", n)
        end
    end
end

function ParticleTrailHandler:handleFixedSize(val)
    self:addOption("fixedParticleSize", val)
end

function ParticleTrailHandler:handlePPS(val, key)
    if (val <= 0) then
        self.system:warningf("The value for %q has to be higher than zero!", key)
    end

    self:addOption("pps", val)
end

ObjectTrailHandler = class(ParticleChunkHandler)

function ObjectTrailHandler:init()
    self:__initTokens()
end

function ObjectTrailHandler:__initTokens()
    self:addHandlerFunction("$Class", self.handleClass)

    self:addHandlerFunction("+Effect", self.handleTrailEffect)
    self:addHandlerFunction("+Speed", self.handleSpeed)
    self:addHandlerFunction("+Size", self.handleSize)
    self:addHandlerFunction("+Time", self.handleTime)
    self:addHandlerFunction("+Emitstate", self.handleEmitState)
    self:addHandlerFunction("+Number", self.handleNumber)
    self:addHandlerFunction("+Variance", self.handleVariance)
    self:addHandlerFunction("+Use thrusters", self.handleUseThrusters)
    self:addHandlerFunction("+Fixed Size", self.handleFixedSize)
    self:addHandlerFunction("+FPS", self.handleFPS)
    self:addHandlerFunction("+Density", self.handleDensity, "Number")
    self:addHandlerFunction("+Radius Factor", self.handleRadiusFactor, "Number")
    self:addHandlerFunction("+Offset", self.handleOffset, "Vector")
    self:addHandlerFunction("+PPS", self.handlePPS, "Number")
    self:addHandlerFunction("+Lifespan", self.handleLifespan, "NumberList")
    self:addHandlerFunction("+Radius", self.handleRadius, "Number")

    self:addHandlerFunction("+Particle trail", self.handleTrail)
end


function ObjectTrailHandler:beginSection()
    self:resetInfo()

    self.startLine = self.system.currentLine
end

function ObjectTrailHandler:sectionEnded()
    self:writeInfo()
end

function ObjectTrailHandler:writeInfo()
    local info = ObjectTrailInfo(self.class,
        self.effect,
        self.state,
        self.startTime,
        self.length,
        self.minSpeed,
        self.maxSpeed,
        self.minSize,
        self.maxSize,
        self.minNum,
        self.maxNum,
        self:getType(),
        self.trailName,
        self.options)

    local b, c, h = info:isValid()

    if (b or not h) then
        info.__definitionLocation = string.format("[%s]:%d", self.system.path, self.startLine)
        table.insert(particleTrailScript:getObjectTable(), info)
    else
        self.system:warningf("Invalid definition found! Cause: %q", c)
    end
end

function ObjectTrailHandler:resetInfo()
    self.class = nil

    self.effect = nil

    self.state = "default"

    self.startTime = nil
    self.length = nil

    self.minSpeed = nil
    self.maxSpeed = nil

    self.minSize = nil
    self.maxSize = nil

    self.minNum = nil
    self.maxNum = nil

    self.trailName = nil

    self.options = nil
end

ShipTrailHandler = class(ObjectTrailHandler)

function ShipTrailHandler:init()
    self:__initTokens()

    self:addHandlerFunction("+Use Thruster Strength", self.handleUseThrusterStrength)
    self:addHandlerFunction("+Subsystem", self.handleSubsystem, "String")

    self:addHandlerFunction("+Damage Trails", self.handleDamageTrails)
    self:addHandlerFunction("+Damage Start Level", self.handleDamageStartLevel)
    self:addHandlerFunction("+Damage Maximum Level", self.handleDamageMaximumLevel)
    self:addHandlerFunction("+Damage End Level", self.handleDamageEndLevel)
end

function ShipTrailHandler:hasSubsystem()
    if (self.options == nil) then
        return false
    end

    return self.options["subsystem"] ~= nil
end

function ShipTrailHandler:getType()
    return "Ship"
end

function ShipTrailHandler:handleClass(val, key)
    local class = self.system:convert("ShipClass", val)
    if (class) then
        self.class = class
    end
end

function ShipTrailHandler:handleTrailEffect(val, key)
    local eff = self.system:convert("Effect", val)
    if (eff) then
        self.effect = eff
    end
end

function ShipTrailHandler:handleSpeed(val, key)
    local range = self.system:convert("NumberList", val)
    if (#range == 1) then
        self.minSpeed = range[1]
        self.maxSpeed = range[1]
    elseif (#range == 2) then
        self.minSpeed = range[1]
        self.maxSpeed = range[2]
    else
        self.system:warningf("%d is an invalid range count for %q", #range, key)
    end
end

function ShipTrailHandler:handleSize(val, key)
    local range = self.system:convert("NumberList", val)
    if (#range == 1) then
        self.minSize = tonumber(range[1])
        self.maxSize = tonumber(range[1])
    elseif (#range == 2) then
        self.minSize = tonumber(range[1])
        self.maxSize = tonumber(range[2])
    else
        self.system:warningf("%d is an invalid range count for %q", #range, key)
    end
end

function ShipTrailHandler:handleTime(val, key)
    local range = self.system:convert("NumberList", val)
    if (#range == 1) then
        self.startTime = tonumber(range[1])
        self.length = nil
    elseif (#range == 2) then
        self.startTime = tonumber(range[1])
        self.length = tonumber(range[2])
    else
        self.system:warningf("%d is an invalid range count for %q", #range, key)
    end
end

function ShipTrailHandler:handleUseThrusters(val, key)
    if (self:hasOption("subsystem")) then
        self.system:warningf("%q is not valid when using \"+Subsystem\"", key)
    end

    local bool = self.system:convert("Boolean", val)
    if (bool ~= nil) then
        self:addOption("UseThruster", bool)
    end
end

function ShipTrailHandler:handleEmitState(val, key)
    local str = val:lower()

    if (str == "afterburner") then
        self.state = str
    elseif (str == "normal") then
        self.state = str
    elseif (str == "warpin") then
        self.state = str
    elseif (str == "always") then
        self.state = "default"
    else
        local valid = self:hasSubsystem()
        if (valid) then
            if (str == "destroyed") then
                self.state = str
            else
                valid = false
            end
        end

        if (not valid) then
            self.system:warningf("%q cannot be resolved to a valid state!", val)
        end
    end
end

function ShipTrailHandler:handleTrail(val, key)
    self.trailName = val
end

function ShipTrailHandler:handleNumber(val, key)
    local range = self.system:convert("NumberList", val)
    if (#range == 1) then
        self.minNum = tonumber(range[1])
        self.maxNum = nil
    elseif (#range == 2) then
        self.minNum = tonumber(range[1])
        self.maxNum = tonumber(range[2])
    else
        self.system:warningf("%d is an invalid range count for %q", #range, key)
    end
end

function ShipTrailHandler:handleVariance(val, key)
    local var = self.system:convert("Number", val)
    if (var) then
        self:addOption("velocityVariance", var)
    end
end

function ShipTrailHandler:handleUseThrusterStrength(val, key)
    local bool = self.system:convert("Boolean", val)
    if (bool ~= nil) then
        self:addOption("useThrusterStrength", bool)
    end
end

function ShipTrailHandler:handleDamageTrails(val, key)
    local bool = self.system:convert("Boolean", val)
    if (bool ~= nil) then
        self:addOption("damageTrail", bool)
    end
end

function ShipTrailHandler:handleDamageStartLevel(val, key)
    local n = self.system:convert("Number", val)
    if (n) then
        if (n < 0 or n > 100) then
            self.system:warningf("%q is no valid value. Has to be between 0 and 100", val)
        else
            self:addOption("damageStartLevel", n)
        end
    end
end

function ShipTrailHandler:handleDamageMaximumLevel(val, key)
    local n = self.system:convert("Number", val)
    if (n) then
        if (n < 0 or n > 100) then
            self.system:warningf("%q is no valid value. Has to be between 0 and 100", val)
        else
            self:addOption("damageMaximumLevel", n)
        end
    end
end

function ShipTrailHandler:handleDamageEndLevel(val, key)
    local n = self.system:convert("Number", val)
    if (n) then
        if (n < 0 or n > 100) then
            self.system:warningf("%q is no valid value. Has to be between 0 and 100", val)
        else
            self:addOption("damageEndLevel", n)
        end
    end
end

function ShipTrailHandler:handleFixedSize(val, key)
    local bool = self.system:convert("Boolean", val)
    if (bool ~= nil) then
        self:addOption("fixedSize", bool)
    end
end

function ShipTrailHandler:handleFPS(val, key)
    local t = self.system:convert("NumberList", val)
    if (t and #t > 0 and #t < 3) then
        self:addOption("fpsValues", t)
    else
        self.system:warningf("%d is an invalid range count for %q", #t, key)
    end
end

function ShipTrailHandler:handleDensity(val, key, realVal)
    if (val > 1 or val <= 0) then
        self.system:warningf("%q is an invalid value for %q.\nOnly values that are greater that zero and less or equal to one are valied for %q.", val, key, key)
    else
        self:addOption("density", val)
    end
end

function ShipTrailHandler:handleRadiusFactor(val, key, realVal)
    if (val < 0) then
        self.system:warningf("The radius Factor may not be less than zero!")
        return
    end

    self:addOption("radiusFactor", val)
end

function ShipTrailHandler:handleOffset(val)
    self:addOption("originOffset", val)
end

function ShipTrailHandler:handlePPS(val, key)
    if (val <= 0) then
        self.system:warningf("A value that is less than or equal to zero is not valid for %q", key)
    end

    self:addOption("pps", val)
end

function ShipTrailHandler:handleLifespan(val, key)
    if (#val < 1 or #val > 2) then
        self.system:warningf("%d is an invalid range number for %q!", #val, key)
        return
    end

    if (self.effect == nil) then
        self.system:warningf("%q has to be specified after the effect!", key)
        return
    end

    if (val[1] <= 0 or (val[2] ~= nil and val[2] <= 0)) then
        self.system:warningf("All values for %q have to be greater than zero!", key)
        return
    end

    local fpsVals = {}

    if (#val == 1) then
        local fps = self.effect:getFramesLeft() / val[1]

        fpsVals[1] = fps
        fpsVals[2] = fps
    else
        fpsVals[1] = self.effect:getFramesLeft() / val[1]
        fpsVals[2] = self.effect:getFramesLeft() / val[2]
    end

    self:addOption("fpsValues", fpsVals)
end

function ShipTrailHandler:handleSubsystem(val)
    self:addOption("subsystem", val)
end

function ShipTrailHandler:handleRadius(val, key)
    if (val <= 0) then
        self.system:warningf("A radius <= zero is ot valid for %q!", key)
        return
    end

    self:addOption("radius", val)
end

WeaponTrailHandler = class(ShipTrailHandler)

function WeaponTrailHandler:init()
    self:__initTokens()
end

function WeaponTrailHandler:getType()
    return "Weapon"
end

function WeaponTrailHandler:handleClass(val, key)
    local class = self.system:convert("WeaponClass", val)
    if (class) then
        self.class = class
    end
end

function WeaponTrailHandler:handleEmitState(val, key)
    local str = val:lower()

    if (str == "freeflight") then
        self.state = str
    elseif (str == "ignition") then
        self.state = str
    elseif (str == "normal") then
        self.state = str
    elseif (str == "homedflight") then
        self.state = str
    elseif (str == "unhomedflight") then
        self.state = str
    elseif (str == "always") then
        self.state = "default"
    elseif (str == "creation") then
        self.state = "creation"
    else
        self.system:warningf("%q cannot be resolved to a valid state!", val)
    end
end

DebrisTrailHandler = class(ShipTrailHandler)

function DebrisTrailHandler:init()
    self:addHandlerFunction("$Class", self.handleClass)

    self:addHandlerFunction("+Effect", self.handleTrailEffect)
    self:addHandlerFunction("+Speed", self.handleSpeed)
    self:addHandlerFunction("+Size", self.handleSize)
    self:addHandlerFunction("+Time", self.handleTime)
    self:addHandlerFunction("+Number", self.handleNumber)
    self:addHandlerFunction("+Variance", self.handleVariance)
    self:addHandlerFunction("+Fixed Size", self.handleFixedSize)
    self:addHandlerFunction("+FPS", self.handleFPS)
    self:addHandlerFunction("+Default", self.handleDefault)
    self:addHandlerFunction("+Density", self.handleDensity, "Number")
    self:addHandlerFunction("+Lifespan", self.handleLifespan, "NumberList")

    self:addHandlerFunction("+Particle trail", self.handleTrail)
end

function DebrisTrailHandler:getType()
    return "Debris"
end

function DebrisTrailHandler:beginSection()
    self:resetInfo()

    self.startLine = self.system.currentLine

    if (mediavps and not mediavps.debrisOverride) then
        mediavps.debrisOverride = true -- Override the mediavp script to avoid unwanted effects
        print("DebrisTrailHandler: Disabled the MediaVPs debris script.\n")
    end
end

function DebrisTrailHandler:handleDefault(val)
    local b = self.system:convert("Boolean", val)
    if (b ~= nil) then
        self:addOption("defaultDebrisInfo", b)
    end
end
