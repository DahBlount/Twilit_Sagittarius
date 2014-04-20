function string.trim(s)
    return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

function string.split(str, sep)
    local sep, fields = sep or ":", {}
    local pattern = string.format("([^%s]+)", sep)
    str:gsub(pattern, function(c) fields[#fields + 1] = c end)
    return fields
end
