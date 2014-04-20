function getWeaponLivingTime(weapon)
    if (weapon == nil or not weapon:isValid()) then
        return -1
    end

    local maxLife = weapon.Class.LifeMax
    local lifeLeft = weapon.LifeLeft

    if (weapon.Class:isMissile() and weapon.HomingObject:isValid()) then
        maxLife = maxLife * 1.2 -- "fix" for LiveLeft altering in weapon/weapons.cpp
    end

    return maxLife - lifeLeft
end

function table.doAdditiveCopy(from, to)
    if (type(from) ~= "table" or type(to) ~= table) then
        stackErrorf("Both arguments should be of type table but they are %q and %q!", type(from), type(to))

        return
    end

    for i, v in pairs(from) do
        local toData = to[i]

        if (toData == nil) then
            to[i] = v
        elseif (type(toData) == "table" and type(v) == "table") then
            table.doAdditive(v, toData)
        end
    end
end

function findFirstTurretWeapon(turret)
    if (not turret or not turret:isValid() or not turret:isTurret()) then
        return nil
    end

    if (turret.PrimaryBanks:isValid()) then
        if (#turret.PrimaryBanks > 0) then
            return turret.PrimaryBanks[1].WeaponClass
        end
    end

    if (turret.SecondaryBanks:isValid()) then
        if (#turret.SecondaryBanks > 0) then
            return turret.SecondaryBanks[1].WeaponClass
        end
    end

    return nil
end

function safeRand(min, max, exact)
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

function string.filterInvisible(str)
    local index = str:find("#", 0, true)

    if (index ~= nil) then
        str = str:sub(1, index - 1)
    end

    return str
end
