--- pattern_event
-- @classmod pattern_event

local pattern_event = {}
pattern_event.__index = pattern_event

function pattern_event.new(event, t)
    local i = {}
    setmetatable(i, pattern_event)
    i.event = event or nil
    i.duration = duration or 0
    return i
end
