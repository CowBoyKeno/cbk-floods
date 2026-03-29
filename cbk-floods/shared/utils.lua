CBKFloods = CBKFloods or {}

function CBKFloods.deepCopy(tbl)
    if type(tbl) ~= 'table' then return tbl end

    local copy = {}
    for key, value in pairs(tbl) do
        copy[key] = CBKFloods.deepCopy(value)
    end
    return copy
end

function CBKFloods.round(num, precision)
    local mult = 10 ^ (precision or 0)
    return math.floor((num * mult) + 0.5) / mult
end

function CBKFloods.clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

function CBKFloods.formatSeconds(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    local minutes = math.floor(seconds / 60)
    local remain = seconds % 60
    return ('%02d:%02d'):format(minutes, remain)
end
