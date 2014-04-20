include("class.lua")
include("parser.lua")

StringConverter = class()

function StringConverter:init(system)
    self.system = system

    self.functions = {}

    if (conv_defaultFunctions) then
        for i, v in pairs(conv_defaultFunctions) do
            self.functions[i] = v
        end
    end
end

function StringConverter:addDefaultHandler(typee, func)
    if (type(typee) ~= "string") then
        stackErrorf("Type of input type should be %q but it is %q!", "string", type(typee))

        return false
    end

    if (type(func) ~= "function") then
        stackErrorf("Type of handler function should be %q but it is %q!", "function", type(func))

        return false
    end

    conv_defaultFunctions[typee] = func

    return self:addHandlerFunction(typee, func)
end

function StringConverter:addHandlerFunction(typee, func)
    if (type(typee) ~= "string") then
        stackErrorf("Type of input type should be %q but it is %q!", "string", type(typee))

        return false
    end

    if (type(func) ~= "function") then
        stackErrorf("Type of handler function should be %q but it is %q!", "function", type(func))

        return false
    end

    self.functions[typee] = func

    return true
end

function StringConverter:__doConvert(typee, input)
    if (type(input) ~= "string") then
        stackErrorf("Invalid input type %q should be \"string\"", type(input))

        return nil, "Invalid input type"
    end

    local f = self.functions[typee]
    if (f) then
        local v, e = f(self, input)
        if (v == nil) then
            if (e) then
                return nil, e
            else
                return nil, "No reason available"
            end
        else
            return v
        end
    else
        return nil, string.format("Unknown type %q!", typee)
    end
end

function StringConverter:convert(typee, input)
    if (type(typee) == "string") then
        local val, msg = self:__doConvert(typee, input)

        if (val == nil) then
            if (msg) then
                self.system:warningf("The input %q couldn't be converted to type %q. Reason: %s", input, typee, msg)
            else
                self.system:warningf("The input %q couldn't be converted to type %q for an unknown reason.\nPlease contact the script author.", input, typee)
                -- The script author likes to talk about himself in the third person :P
            end

            return nil
        else
            return val
        end
    elseif (type(typee) == "table") then
        local reasons = {}
        for i, v in ipairs(typee) do
            local val, msg = self:__doConvert(v, input)
            if (val) then
                return val, v
            else
                reasons[v] = msg
            end
        end

        local types = ""

        for i, v in ipairs(typee) do
            types = types .. v

            if (i ~= #typee) then
                types = types .. ", "
            end
        end

        local message = string.format("Could convert input %q to any of the required input types (%s). The reasons for every input type are listed below:\n\n", input, types)

        for i, v in pairs(reasons) do
            message = message .. string.format("%q: %s\n", i, v)
        end

        self.system:warningf(message)

        return nil
    elseif (typee == nil) then
        return input -- Default is string
    else
        stackErrorf("%q is an illegal input type for StringConverter:convert()!", type(typee))
    end
end

function StringConverter:stringConvert(str)
    return str
end

function StringConverter:numberConvert(str)
    local n = tonumber(str)
    if (n) then
        return n, nil
    else
        return nil, string.format("Cannot convert %q to a number", str)
    end
end

function StringConverter:listConvert(str)
    local tbl = string.split(str, ",")

    return tbl
end

function StringConverter:listToTypeList(str, typee)
    local list, err = self:listConvert(str)

    if (err) then
        return nil, err
    end

    local ret = {}
    for i, v in pairs(list) do
        local val, err = self:convert(typee, v:trim())

        if (err) then
            return nil, err
        end
        if (val) then
            table.insert(ret, val)
        end
    end

    return ret
end

function StringConverter:numberListConvert(str)
    return self:listToTypeList(str, "Number")
end

function StringConverter:shipClassConvert(str)
    local shipClass = tb.ShipClasses[str]
    if (shipClass ~= nil and shipClass:isValid()) then
        return shipClass
    else
        return nil, string.format("Unknown shipclass %q", str)
    end
end

function StringConverter:weaponClassConvert(str)
    local weaponClass = tb.WeaponClasses[str]
    if (weaponClass ~= nil and weaponClass:isValid()) then
        return weaponClass
    else
        return nil, string.format("Unknown weaponclass %q", str)
    end
end

function StringConverter:vectorConvert(str)
    local tbl = self:numberListConvert(str)
    if (#tbl ~= 3) then
        return nil, string.format("Input %q cannot be converted to a vector!", str)
    else
        return ba.createVector(tbl[1], tbl[2], tbl[3])
    end
end

function StringConverter:effectConvert(str)
    local eff
    if (effectManager ~= nil) then
        eff = effectManager.getEffect(str)
    else
        eff = gr.loadTexture(str, true)
    end

    if (eff == nil or not eff:isValid()) then
        return nil, string.format("Effect %q couldn't be loaded", str)
    else
        return eff
    end
end

function StringConverter:booleanConvert(str)
    local val

    str = str:lower()
    if (str == "yes") then
        val = true
    elseif (str == "no") then
        val = false
    elseif (str == "true") then
        val = true
    elseif (str == "false") then
        val = false
    else
        return nil, string.format("Expected a boolean type. Got %q", str)
    end

    return val
end

function StringConverter:luaConvert(str)
    if (not str:starts("return")) then
        str = "return " .. str
    end

    local func, err = loadstring(str, self.system.path .. ":" .. self.system.currentLine)

    if (not func) then
        return nil, string.format("Cannot convert input to lua code. Reason:\n%s", err), err
    else
        return func
    end
end

function StringConverter:luaValue(str)
    local getterFunc, _, err = self:luaConvert(str)

    if (not getterFunc) then
        return nil, string.format("Cannot convert input to getter function: %s", err)
    end

    local val, err = pcall(getterFunc)
    if (val ~= nil) then
        return val
    else
        return nil, "Unknown global index"
    end
end

conv_defaultFunctions = {}

conv_defaultFunctions["String"] = StringConverter.stringConvert
conv_defaultFunctions["Number"] = StringConverter.numberConvert
conv_defaultFunctions["StringList"] = StringConverter.listConvert
conv_defaultFunctions["NumberList"] = StringConverter.numberListConvert
conv_defaultFunctions["ShipClass"] = StringConverter.shipClassConvert
conv_defaultFunctions["WeaponClass"] = StringConverter.weaponClassConvert
conv_defaultFunctions["Vector"] = StringConverter.vectorConvert
conv_defaultFunctions["Effect"] = StringConverter.effectConvert
conv_defaultFunctions["Boolean"] = StringConverter.booleanConvert
conv_defaultFunctions["LuaCode"] = StringConverter.luaConvert
conv_defaultFunctions["LuaValue"] = StringConverter.luaValue
