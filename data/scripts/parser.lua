include("class.lua")
include("strings.lua")
include("converter.lua")

ParseSystem = class()

function ParseSystem:init(fileName, path, comment)
    if (path == nil) then
        path = ""
    end

    self.fileName = fileName
    self.path = path .. fileName
    self.comment = comment
    self.multilineStartStatement = "%["
    self.multilineEndStatement = "]%"

    self.valid = self:__read(path)

    self.converter = StringConverter(self)
end

function ParseSystem:__read(path)
    local fileHandle = cf.openFile(self.fileName, "r", path)
    if (not fileHandle:isValid()) then
        return false
    end

    self.lines = {}
    self.currentLine = 1

    local line
    while true do
        line = fileHandle:read("*l")
        if (line == nil) then
            break
        end

        if (self.comment) then
            local com = line:find(self.comment, 1, true)
            if (com) then
                line = line:sub(1, com - 1)
            end
        end

        table.insert(self.lines, line)
    end

    fileHandle:close()

    return true
end

function ParseSystem:convert(type, input)
    local val, err = self.converter:convert(type, input)

    if (err ~= nil) then
        return nil
    end

    return val
end

function ParseSystem:isValid()
    if (not self.valid) then
        return false
    end

    if (#self.lines < 1) then
        return false
    end

    if (self.currentLine > #self.lines) then
        return false
    end

    if (not self.handler) then
        return false
    end

    return true
end

function ParseSystem:warningf(str, ...)
    if (str) then
        ba.warning(string.format("%s[%d]: " .. str .. "\n", self.path, self.currentLine - 1, ...))
    end
end

function ParseSystem:errorf(str, ...)
    if (str) then
        ba.error(string.format("%s[%d]: " .. str .. "\n", self.path, self.currentLine - 1, ...))
    end
end

function ParseSystem:getLine()
    if (self.currentLine > #self.lines) then
        return nil
    end
    local line = self.lines[self.currentLine]
    self.currentLine = self.currentLine + 1

    return line
end

function ParseSystem:setHandler(handler)
    self.handler = handler
end

function ParseSystem:lineContains(line, str)
    local found = string.find(line, str, 1, true)

    if (found) then
        return true, found
    else
        return false
    end
end

function ParseSystem:somethingToParse()
    return self.currentLine <= #self.lines
end

function ParseSystem:parseFile()
    if (not self:isValid()) then
        self:warningf("Parse system is invalid!")
        return
    end

    while (self:somethingToParse()) do
        local line = string.trim(self:getLine())

        if (line:len() > 0) then
            self.handler:processLine(line)
        end
    end
    self.handler:endOfFile()
end

function ParseSystem:parseUntilString(str)
    if (not self:isValid()) then
        self:warningf("Parse system is invalid!")
        return
    end

    local line
    while (self:somethingToParse()) do
        line = getLine()
        local b, i = self:lineContains(line, str)
        if (b) then
            line = line:sub(1, i - 1)
        end
        self.handler:processLine(line)
        if (b) then
            break
        end
    end
end

function ParseSystem:skipUntilString(str)
    if (not self:isValid()) then
        self:warningf("Parse system is invalid!")
        return
    end

    local line
    while (self:somethingToParse()) do
        line = getLine()
        if (self:lineContains(line, str)) then
            break
        end
    end
end

HandlerFunction = class()

function HandlerFunction:init(func, ...)
    self.func = func
    if (arg.n > 0) then
        if (arg.n == 1) then
            self.argTypes = arg[1]
        else
            self.argTypes = {}

            for i = 1, arg.n do
                self.argTypes[i] = arg[i]
            end
        end
    end
end

function HandlerFunction:handle(system, handler, val, key)
    if (val == nil) then
        if (self.argTypes == nil) then
            self.func(handler, nil, key, nil, nil)
        else
            local msg
            if (type(self.argTypes) == "string") then
                msg = string.format("%q needs a value of type %q but there is none present!", key, self.argTypes)
            else
                local types = ""
                for i, v in ipairs(self.argTypes) do
                    types = types .. v

                    if (i ~= #self.argTypes) then
                        types = types .. ", "
                    end
                end

                msg = string.format("%q requires a value but there is none present! Requires one of the following types:\n%s", key, msg)
            end

            system:warningf(msg)
        end

        return
    end

    local realVal = val
    local typee
    if (self.argTypes) then
        val, typee = system:convert(self.argTypes, val)
    end

    if (val ~= nil) then
        self.func(handler, val, key, realVal, typee)
    end
end

ParseHandler = class()

function ParseHandler:init(parseSystem, delimiter)
    self.system = parseSystem
    self.delim = delimiter

    self.handlerFunctions = {}
end

function ParseHandler:processLine(line)
    if (type(line) ~= "string") then
        return false
    end

    local found = line:find(self.delim, 1, true)
    if (found) then
        local front = string.trim(line:sub(1, found - 1))
        local back = string.trim(line:sub(found + 1, line:len()))

        if (back:starts(self.system.multilineStartStatement)) then
            while (self.system:somethingToParse()) do
                local line = self.system:getLine()

                local found, endIndex = line:find(self.system.multilineEndStatement, 1, true)
                if (found) then
                    line = line:sub(1, endIndex)
                    back = back .. "\n" .. line
                    break
                end

                back = back .. "\n" .. line
            end

            back = string.trim(back:sub(self.system.multilineStartStatement:len()+1, -self.system.multilineEndStatement:len() - 1))
        end

        self:handleKeyValue(front, back)
    else
        self:handleKeyValue(string.trim(line), nil)
    end
end

function ParseHandler:handleKeyValue(key, value)
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

function ParseHandler:addHandlerFunction(ident, func, ...)
    if (type(func) ~= "function") then
        warningf("Tried to add invalid handler function of type %q for ident %q!", type(func), ident)
        return
    end
    if (not self.handlerFunctions) then
        self.handlerFunctions = {}
    end

    self.handlerFunctions[ident] = HandlerFunction(func, ...)
end

function ParseHandler:setDefaultFunction(func)
    if (func ~= nil and type(func) ~= "function") then
        stackErrorf("Expected type %q. Got %q!", "function", type(func))
        return
    end

    self.defaultFunction = func
end

function ParseHandler:removeHandlerFunction(ident)
    if (not self.handlerFunctions) then
        return
    end

    self.handlerFunctions[ident] = nil
end

function ParseHandler:endOfFile()
end
