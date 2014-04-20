include("class.lua")

Emitstate = class()

function Emitstate:init(name)
    self.name = name
end

function Emitstate:checkObject(obj)
    stackErrorf("This method must be implemented!")
end

ShipEmitstate = class(Emitstate)

function ShipEmitstate:init(name, number)
    self.number = number
end

function ShipEmitstate:checkObject(obj)
    return obj:hasShipExploded() == self.number
end

WeaponEmitstate = class(Emitstate)

function WeaponEmitstate:init(name, checkFunc)
    if (type(checkFunc) ~= "function") then
        stackErrorf("Need an argument of type \"function\". Got %q.", type(checkFunc))
    end

    self.checkFunc = checkFunc
end

function WeaponEmitstate:checkObject(obj)
    return checkFunc(obj)
end

