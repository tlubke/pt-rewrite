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
    i.clock = nil
    i.quantization = -1
    i.sync = false
    i.sync_duration = 0
    return i
end

function pattern_time:new_pattern(id, handle_event)
    local p = pattern:new(id, handle_event)
    self.pattern[id] = p
    self.current_pattern = p
    -- attach observer for param menu
end

function pattern_time:rec(id, state)
    local p = self:get_pattern_by_id(id)
    if self.sync 1 then
        clock.run(function() clock.sync(self.sync_duration) end)
    end
    if      state == 1 then
        p:rec(1) -- record on
    else if state == 0 then
        p:rec(0) -- record off
    else
        print("invalid argument 'state' to ':rec', use 1 or 0")
    end
    return p.rec_state
end

function pattern_time:overdub(id, state)
    local p = self:get_pattern_by_id(id)
    if self.sync then
        clock.run(function() clock.sync(self.sync_duration) end)
    end
    if      state == 1 then
        p:overdub(1) -- overdub on
    else if state == 0 then
        p:overdub(0) -- overdub off
    else
        print("invalid argument 'state' to ':overdub', use 1 or 0")
    end
end

function pattern_time:play(id, state)
    local p = self:get_pattern_by_id(id)
    if self.sync 1 then
        clock.run(function() clock.sync(self.sync_duration) end)
    end
    if      state == 1 then
        p:play(1) -- play on
    else if state == 0 then
        p:play(0) -- play off
    else
        print("invalid argument 'state' to ':play', use 1 or 0")
    end
    -- cycle through events using handle_event on each
    -- quantize to self.quantize beat value if not '-1'
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

function pattern_time:quantize(n)
    -- get clock and set if n not 0
    -- quantize n is beat value
end

return pattern_time
