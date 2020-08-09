--- pattern_event
-- @classmod pattern_event

local pattern_event = {}
pattern_event.__index = pattern_event

function pattern_event.new(data, t)
    local i = {}
    setmetatable(i, pattern_event)
    i.data = data or nil
    i.duration = duration or 0
    return i
end

return pattern_event
