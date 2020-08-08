--- pattern
-- @classmod pattern

local pattern = {}
pattern.__index = pattern

--- constructor
function pattern.new(id)
  local i = {}
  setmetatable(i, pattern)
  i.rec_state = 0
  i.play_state = 0
  i.overdub_state = 0
  i.prev_time = 0
  i.curr_time = {}
  i.event = {}
  i.time = {}
  i.time_beats = {}
  i.quantum = {}
  i.count = 0
  i.step = 0
  i.runner = 1
  i.time_factor = 1
  i.loop_state = 1
  i.start_point = 0
  i.end_point = 0
  i.clock = nil
  i.clock_time = 4
  i.rec_clock = nil -- placeholder for clocked recording
  i.rec_duration = 8 -- how many beats the clocked recording will record for
  i.quantized = false -- pattern playback quantization
  i.sync_record = false -- sync record start to next bar
  i.record_pending = false -- synced record start is currently pending
  i.sync_start = false -- replaying a pattern will sync to the specified launch_timing
  i.launch_timing = "bar" -- if synced_start, then wait till next bar or beat to restart pattern
  i.start_pending = false -- synced restart is currently pending
  i.name = id

  i.metro = metro.init(function() i:next_event() end,1,1)

  i.process = function(_) print("event") end

  if i.name == nil then
    i.name = "pattern"
  end
  params:add_group("PATTERNS",6)
  params:add_separator(i.name)
  params:add_option(i.name.."_sync_recording","sync record to clock?",{"no","yes"})
  params:set_action(i.name.."_sync_recording", function(option) -- x -> option to reflect param type
    i.sync_record = (option == 1) and false or true             -- consistent with other ternary statements
  --i.sync_record = if (option == 1) then false else true end   -- might be a little more readable
  end
  )
  params:add_number(i.name.."_rec_duration","---> rec duration (beats)",1,256,8)
  params:set_action(i.name.."_rec_duration", function(n)        -- x -> n to reflect number
    i.rec_duration = n
  end
  )
  params:add_option(i.name.."_sync_start","sync launch to clock?",{"no","yes"})
  params:set_action(i.name.."_sync_start", function(option)     -- rename cont.
    i.sync_start = (option == 1) and false or true              -- ternary cont.
  end
  )
  params:add_option(i.name.."_launch_timing","---> timing",{"bar","beat"})
  params:set_action(i.name.."_launch_timing", function(option)
    i.launch_timing = (option == 1) and "bar" or "beat"         -- parenthesize for readability
  end
  )
  params:add_option(i.name.."_quantization","quantization",{"off","on"})
  params:set_action(i.name.."_quantization", function(option)   -- rename cont.
    i:quantize(option - 1)
  end
  )

  return i
end

--- clear this pattern
function pattern:clear()
  if not self.quantized then
    self.metro:stop()
  else
    if self.quant_clock ~= nil then
      clock.cancel(self.quant_clock)
    end
  end
  if self.clock ~= nil then
    clock.cancel(self.clock)
  end
  self.rec_state = 0
  self.play_state = 0
  self.overdub_state = 0
  self.prev_time = 0
  self.curr_time = {}
  self.event = {}
  self.time = {}
  self.time_beats = {}
  self.quantum = {}
  self.count = 0
  self.step = 0
  self.runner = 1
  self.time_factor = 1
  self.start_point = 0
  self.end_point = 0
  self.clock = nil
  self.clock_time = 4
  self.rec_clock = nil
end

--- adjust the time factor of this pattern.
-- @tparam number n time factor
function pattern:set_time_factor(n)            -- f -> n
  self.time_factor = n or 1                    -- is type safety important?
end

--- start recording
function pattern:rec(state)
  if state == 1 then
    print("pattern rec start")
    if self.sync_record then
      self.rec_clock = clock.run(function() self:synced_record_start() end)
    else
      self.rec_state = 1
    end
  elseif state == 0 then
    if self.rec_state == 1 then
      self.rec_state = 0
      if self.count ~= 0 then
        print("count "..self.count)
        local t = self.prev_time
        self.prev_time = util.time()
        self.time[self.count] = self.prev_time - t
        self.time_beats[self.count] = self.time[self.count] / clock.get_beat_sec()
        self.start_point = 1
        self.end_point = self.count
        for i = 1,self.count do
          self:calculate_quantum(i)
        end
        self:print()
        --self:clamp_quantum()
        -- self:calculate_duration()
      else
        print("no events recorded")
      end
    else print("not recording")
    end
    if self.rec_clock ~= nil then
      clock.cancel(self.rec_clock)
      self.rec_clock = nil
    end
  else
    print("invalid argument to ':rec', use 1 or 0")
  end
end

--- watch
function pattern:watch(e) -- "e" is event? maybe match rec_event and name it watch_event(e)
  if self.rec_state == 1 then
    self:rec_event(e)
  elseif self.overdub_state == 1 then
    self:overdub_event(e)
  end
end

--- record event
function pattern:rec_event(e)
  local c = self.count + 1
  if c == 1 then
    self.prev_time = util.time()
  else
    local t = self.prev_time
    self.prev_time = util.time()
    self.time[c-1] = self.prev_time - t
    self.time_beats[c-1] = self.time[c-1] / clock.get_beat_sec()
  end
  self.count = c
  self.event[c] = e
end

function pattern:calculate_quantum(target)
  self.quantum[target] = util.round(self.time_beats[target],0.125)
  if self.quantum[target] == 0 then
    self.quantum[target] = 0.125
  end
end

-- function pattern:clamp_quantum()
--   local total = 0
--   for i = 1,self.count do
--     total = self.quantum[i] + total
--   end
--   if total > self.rec_duration then
--     self.quantum[self.count] = self.quantum[self.count] - (total-self.rec_duration)
--   end
-- end

function pattern:overdub_event(e)
  local c = self.step + 1
  local t = self.prev_time
  self.prev_time = util.time()
  local a = self.time[c-1]
  local q_a = self.time_beats[c-1]
  local previous_quantum_total = self.quantum[c-1]
  self.time[c-1] = self.prev_time - t
  self.time_beats[c-1] = self.time[c-1] / clock.get_beat_sec()
  table.insert(self.time, c, a - self.time[c-1])
  table.insert(self.event, c, e)
  table.insert(self.time_beats, c, self.time[c] / clock.get_beat_sec()) -- should work...
  local new = self.time_beats[c]
  if not self.quantized then
    self.step = self.step + 1
  end
  self.count = self.count + 1
  self.end_point = self.count
  self.time_beats[c] = new
  for i = 1,self.count do
    self.quantum[i] = util.round(self.time_beats[i],0.125)
    if self.quantum[i] == 0 then
      self.quantum[i] = 0.125
    end
  end
  self.quantum[c] = previous_quantum_total - self.quantum[c-1]
  if self.runner > self.quantum[self.step]*8 then
    self.step = self.step + 1
    self.runner = 1
    --print("runner was over...")
  end
end

-- function pattern:calculate_duration()
--   local total_time = 0
--   for i = 1,#self.time_beats do
--     total_time = total_time + self.time_beats[i]
--   end
--   self.rec_duration = util.round(total_time)
-- end

function pattern:print()
  for i = 1,self.count do
    print("time: "..self.time[i], "quantum: "..self.quantum[i])
  end
  local total_q = 0
  local total_t = 0
  for i = 1,self.count do
    total_q = self.quantum[i] + total_q
    total_t = self.time[i] + total_t
  end
  print("time total: "..total_t, "quantum total: "..total_q)
end

function pattern:play(state)
  if state == 1 then
    if self.sync_start then
      clock.run(function() self:synced_start() end)
    else
      self:unsynced_start()
    end
  elseif state == 0 then
    if self.clock ~= nil then
      clock.cancel(self.clock)
    end
    self.clock = nil
    self:unsynced_stop()
  else
    print("invalid argument to ':play', use 1 or 0")
  end
end

function pattern:synced_start()
  self.start_pending = true
  clock.sync(self.launch_timing == "beat" and 1 or 4)
  print("synced restart")
  self.clock = clock.run(function() self:synced_loop() end)
  self.start_pending = false
end

function pattern:unsynced_start()
  print("restarting on beat: "..clock.get_beats()%4)
  if self.count > 0 and self.rec_state == 0 then
    if not self.quantized then
      self.prev_time = util.time()
      self.process(self.event[self.start_point])
      self.play_state = 1
      self.step = self.start_point
      self.metro.time = self.time[self.start_point] * self.time_factor
      self.metro:start()
    else
      self:quantize_start()
    end
  end
end

function pattern:synced_loop()
  print("synced loop")
  self:unsynced_start()
  self.synced_loop_runner = 1
  while true do
    clock.sync(1/8)
    if self.synced_loop_runner == self.rec_duration * 8 then
      local overdub_flag = self.overdub_state
      if self.loop_state == 1 then
        self:unsynced_stop()
        if overdub_flag == 1 then
          self.overdub_state = 1
        end
        self:unsynced_start()
        self.synced_loop_runner = 1
      else
        self:play(0)
      end
    else
      self.synced_loop_runner =  self.synced_loop_runner + 1
    end
  end
end

function pattern:synced_record_start()
  self.record_pending = true
  clock.sync(4)
  print("starting recording")
  self.rec_state = 1
  self.record_pending = false
  self:watch("pause")
  clock.run(function() self:sync_recording() end)
end

function pattern:sync_recording()
  clock.sleep((clock.get_beat_sec())*self.rec_duration)
  if self.rec_clock ~= nil then
    self:rec(0)
    if self.rec_state == 0 and self.count > 0 then 
      local total_time = 0
      for i = self.start_point,self.end_point do
        total_time = total_time + self.time[i]
      end
      local clean_bars_from_time = util.round(total_time/((clock.get_beat_sec())*4),0.25)
      local add_time = (((clock.get_beat_sec())*4) * clean_bars_from_time) - total_time
      
      self.time[#self.event] = self.time[#self.event] + add_time
      self.clock_time = 4 * clean_bars_from_time
    end
    if self.time[1] ~= nil and self.time[1] < (clock.get_beat_sec())/4 and self.event[1] == "pause" then
      self.time[2] = self.time[2] + self.time[1]
      self.time_beats[2] = self.time_beats[2] + self.time_beats[1]
      table.remove(self.event,1)
      table.remove(self.time,1)
      table.remove(self.time_beats,1)
      self.count = #self.event
      self.end_point = self.count
      for i = 1,self.count do
        self:calculate_quantum(i)
      end
      --self:clamp_quantum()
    end
    if self.count > 0 then -- just in case the recording was canceled...
      self.clock = clock.run(function() self:synced_loop() end)
    end
  end
end

function pattern:quantize(state)
  if state == 0 then
    if self.quant_clock ~= nil then
      clock.cancel(self.quant_clock)
    end
    self.quantized = false
    if self.play_state == 1 then
      self.metro:start()
    end
  elseif state == 1 then
    self.quantized = true
    self.runner = 1
    if self.play_state == 1 then
      self.metro:stop()
      self.quant_clock = clock.run(function() self:quantized_advance() end)
    end
  end
end

function pattern:quantize_start()
  self.play_state = 1
  self.step = self.start_point
  self.runner = 1
  self.quant_clock = clock.run(function() self:quantized_advance() end)
end

function pattern:quantized_advance()
  while true do
    if self.count > 0 then
      local step = self.step
      if self.runner == 1 then
        self.process(self.event[step])
        self.prev_time = util.time()
      end
      clock.sync(1/8)
      self.runner = self.runner + 1
      if self.runner > self.quantum[step]*8 then
        self.step = self.step + 1
        self.runner = 1
      end
      if self.step > self.end_point then
        self.step = self.start_point
        self.runner = 1
      end
    end
  end
end

--- process next event
function pattern:next_event()
  local diff = nil
  self.prev_time = util.time()
  if self.count == self.end_point then diff = self.count else diff = self.end_point end
  if self.step == diff and self.loop_state == 1 then
    self.step = self.start_point
  elseif self.step > diff and self.loop_state == 1 then
    self.step = self.start_point
  else
    self.step = self.step + 1
  end
  self.process(self.event[self.step])
  self.metro.time = self.time[self.step] * self.time_factor
  self.curr_time[self.step] = util.time()
  if self.step == diff and self.loop_state == 0 then
    if self.play_state == 1 then
      self.play_state = 0
      self.metro:stop()
    end
  else
    if self.step == 1 then
      print("first beat: "..clock.get_beats()%4)
    end
    self.metro:start()
  end
end

function pattern:unsynced_stop()
  if self.play_state == 1 then
    self.play_state = 0
    self.overdub_state = 0
    if not self.quantized then
      self.metro:stop()
    else
      clock.cancel(self.quant_clock)
      self.quant_clock = nil
    end
  end
end

function pattern:overdub(state)
  if state == 1 and self.play_state == 1 and self.rec_state == 0 then
    self.overdub_state = 1
  else
    self.overdub_state = 0
  end
end

function pattern:loop(state)
  if state == 1 or state == 0 then
    self.loop_state = state
  else
    print("invalid argument to ':loop', use 1 or 0")
  end
end

return pattern
