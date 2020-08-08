--- pattern_time
-- @classmod pattern_time

local pattern = include 'lib/pattern'

local pattern_time = {}
pattern_time.__index = pattern_time

function pattern_time.new()
    local i = {}
    setmetatable(i, pattern_time)
    i.patterns = {}
    i.current_pattern = nil
    i.quantization = -1
    i.sync = false
    i.sync_duration = 0
    i.rate = 1
    i.loop = 0
    i.clock = nil
    return i
end

function pattern_time:new_pattern(id, handle_event)
    local p = pattern:new(id, handle_event)
    table.insert(self:patterns, p, #self.patterns + 1)
    self.current_pattern = p
    -- attach observer for param menu
end

function pattern_time:rec(state)
    if self.sync > 1 then
        clock.run(function() clock.sync(self.sync_duration) end)
    end
    if      state == 1 then
        self.current_pattern:rec(1) -- record on
    else if state == 0 then
        self.current_pattern:rec(0) -- record off
    else
        print("invalid argument 'state' to ':rec', use 1 or 0")
    end
    return self.current_pattern.rec_state
end

function pattern_time:play(state)
    if self.sync then
        clock.run(function() clock.sync(self.sync_duration) end)
    end
    -- cycle through events using handle_event on each
    -- then either wait duration (modified by rate) between next event
    -- or quantize to self.quantize beat value
    -- ... 
end

function pattern_time:sync_state_change_to_beat(beat)
    self.sync_duration = beat
end

function pattern_time:sync(bool)
    if type(sync) ~= "Bool" then
        print("invalid argument 'bool' to ':sync', use true or false")
    else
        self.sync = sync
    end
end

function pattern_time:rate(rate)
    self.rate = util.clamp(0.001, 10, rate)
end

return pattern_time
