--- pattern
-- @classmod pattern

local pattern_event = include 'lib/pattern_event'

local pattern = {}
pattern.__index = pattern

--- constructor
function pattern.new(id, handle_event)
  local i = {}
  setmetatable(i, pattern)
  i.id = id
  i.handle_event = handle_event or function(data) print(data) end
  i.rec_state = 0
  i.play_state = 0
  i.overdub_state = 0
  i.events = {}
  i.event_count = 0
  i.rate = 1
  i.loop_type = 0
  i.loop_start = 0
  i.loop_end = 0
  i.rec_start_time = 0
  return i
end

--- clear this pattern
function pattern:clear()
  self.rec_state = 0
  self.play_state = 0
  self.overdub_state = 0
  self.events = {}
  self.event_count = 0
  self.rate = 1
  self.loop_type = 0
  self.loop_start = 0
  self.loop_end = 0
  self.rec_start_time = 0 -- works for overdub start time too
end

--- start recording
function pattern:rec(state)
    if      state == 1 then
        self.rec_state = 1
        self.rec_start_time = util.time()
    else if state == 0 then
        self.rec_state = 0
    else
        print("invalid argument 'state' to 'pattern:rec', use 1 or 0")
    end
end

--- record event
function pattern:rec_event(data, event_container)
    if self.rec_state == 0 then return end

    local events = event_container or self.events
    local t = util.time() - self.rec_start_time

    events[c] = pattern_event:new(data, t)
end

--- start overdubbing
function pattern:overdub(state)
  if state == 1 and self.play_state == 1 and self.rec_state == 0 then
    self.overdub_state = 1
    self.rec_start_time = util.time()
  else
    self.overdub_state = 0
    self:merge_overdub()
  end
end

--- overdub event
function pattern:overdub_event(data)
    if self.overdub_state == 0 then return end
    self:rec_event(data, self.overdub_event_container)
end

function pattern:merge_overdub()
    -- sorted insert of every event in overdub into events
    -- sorted by time from start of recording, i.e. 't'
end

--- start playing
function pattern:play(state)
  if state == 1 then
      -- record stop?
      -- overdub stop?
  elseif state == 0 then
      -- stop play
  else
    print("invalid argument to ':play', use 1 or 0")
  end
end

--- play event
function pattern:play_event(event)
    -- wait duration * rate
    -- pass event to pattern_time to be quantized
end

function pattern:loop_start(pos)
    if pos < 0 or pos > 1 then
        print("invalid argument 'pos' to ':loop_start', must be 0 <= pos <= 1 ")
    else
        self.loop_start = pos
    end
end

function pattern:loop_end(pos)
    if pos < 0 or pos > 1 then
        print("invalid argument 'pos' to ':loop_end', must be 0 <= pos <= 1 ")
    else
        self.loop_end = pos
    end
end

return pattern
