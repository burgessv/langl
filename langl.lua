-- langl: arc grains looper
-- by @burgess
-- based on angl by @tehn
-- engine: glut @artfwo
--
-- load files via param menu
--
-- E2 to switch modes:
--
-- SPEED
-- -- K2 then touch arc to
--    set speed to zero
--
-- LOOP
-- -- K2 sets loop window
--
-- PITCH
-- -- K2 sets coarse control
--
-- VOLUME, DENSITY, SIZE,
-- JITTER, SPREAD
-- -- K2 sets fine control


engine.name = 'Glut'

tau = math.pi * 2
pi = math.pi
pitch_limit = 24
VOICES = 4
positions = {-1,-1,-1,-1}
modes = {"SPEED", "LOOP", "PITCH", "VOLUME", "DENSITY", "SIZE", "JITTER", "SPREAD"}
mode = 1
encoder_mode_position = 0
hold = false
track_speed = {100, 100, 100, 100}
track_pitch = {0, 0, 0, 0}
loop_center_pos = {0, 0, 0, 0}
speed_mark_pos = 0

loop_data = {}
for i = 1, VOICES do
  loop_data[i] = {
    percent = 1,
    current_percent = 0,
    loop_reset_pos = 0,
    loop_in = 0,
    loop_out = 1,
    loop_over_seam = true
  }
end

REFRESH_RATE = 0.02

function set_loop_ends(v)
    local half_percent = loop_data[v].percent/2
    loop_data[v].loop_in  = (loop_center_pos[v] - half_percent) % 1
    loop_data[v].loop_out = (loop_center_pos[v] + half_percent) % 1
end

function update_position(v, pos)
  positions[v] = pos
  
  local ref_pos = track_speed[v] > 0 and loop_data[v].loop_in or loop_data[v].loop_out
  local dist_from_ref_pos = math.abs(pos - ref_pos)
  loop_data[v].loop_over_seam = loop_data[v].loop_out < loop_data[v].loop_in
  
  if loop_data[v].loop_over_seam then
    if (track_speed[v] > 0) then
      if pos < loop_data[v].loop_out and pos < loop_data[v].loop_in then
        dist_from_ref_pos = 1 - dist_from_ref_pos
      end
    else
      if pos > loop_data[v].loop_out and pos > loop_data[v].loop_in then
        dist_from_ref_pos = 1 - dist_from_ref_pos
      end
    end
  end

  loop_data[v].loop_reset_pos = ref_pos
  loop_data[v].current_percent = dist_from_ref_pos 
end

function loop_pos(v)
  if loop_data[v].loop_over_seam then
    if positions[v] > loop_data[v].loop_out and positions[v] < loop_data[v].loop_in then
      update_position(v, loop_data[v].loop_reset_pos)
      engine.seek(v, loop_data[v].loop_reset_pos)
    end
  else
    if loop_data[v].current_percent >= loop_data[v].percent then
      update_position(v, loop_data[v].loop_reset_pos)
      engine.seek(v, loop_data[v].loop_reset_pos)
    end     
  end
end

key = function(n,z)
  if n==2 then hold = z==1 and true or false end
  redraw()
end

enc = function(n,d)
  if n==2 then
    encoder_mode_position = (encoder_mode_position + d/4)
    mode = util.round(encoder_mode_position%7, 1) + 1
    redraw()
  end
end

a = arc.connect()

a.delta = function(n,d)
  if mode==1 then
    if hold == true then
      params:set(n.."speed",0)
    else
      local s = params:get(n.."speed")
      s = s + d/10
      params:set(n.."speed",s)
      track_speed[n] = s
    end
  elseif mode == 2 then
    if hold == true then
      loop_data[n].percent = util.clamp(loop_data[n].percent + d/300, 0.001, 1)
      params:set(n.."loop_percent", loop_data[n].percent)
    else
      loop_center_pos[n] = (loop_center_pos[n] + d/300) % 1
      params:set(n.."loop_center_pos", loop_center_pos[n])
    end 
    set_loop_ends(n)

  elseif mode == 3 then
    track_pitch[n] = util.clamp(track_pitch[n] + d/10, -pitch_limit, pitch_limit)

    if hold == true then
      params:set(n.."pitch", util.round(track_pitch[n], 4))
    else
      params:set(n.."pitch", track_pitch[n])
    end
  elseif mode == 4 then
    if hold == true then
      params:delta(n.."volume", d/20)
    else
      params:delta(n.."volume", d/4)
    end
  elseif mode == 5 then
    if hold == true then
      params:delta(n.."density", d/20)
    else
      params:delta(n.."density", d/4)
    end
  elseif mode == 6 then
    if hold == true then
      params:delta(n.."size", d/20)
    else
      params:delta(n.."size", d/4)
    end
  elseif mode == 7 then
    if hold == true then
      params:delta(n.."jitter", d/20)
    else
      params:delta(n.."jitter", d/4)
    end
  else
    if hold == true then
      params:delta(n.."spread", d/20)
    else
      params:delta(n.."spread", d/4)
    end
  end
end

arc_redraw = function()
  a:all(0)
  if mode == 1 then
    for v=1,VOICES do
      if loop_data[v].percent < 1 then
        update_position(v, positions[v])
        if (track_speed[v] > 0) then
          speed_mark_pos = util.linlin(0, loop_data[v].percent, 0, 1, loop_data[v].current_percent)
        else
          speed_mark_pos = util.linlin(0, loop_data[v].percent, 1, 0, loop_data[v].current_percent)
        end
      else
        speed_mark_pos = positions[v]
      end
      a:segment(v,speed_mark_pos*tau,tau*speed_mark_pos+0.2,15)
    end
  elseif mode == 2 then
    for v=1,VOICES do
      if loop_data[v].percent < 0.95 then
        a:segment(v, loop_data[v].loop_in*tau, tau*loop_data[v].loop_out+0.2, 15)
      else 
        a:segment(v, 0.001*tau, 0.999*tau, 15)
      end
    end
  elseif mode == 3 then
    for v=1,VOICES do
      local pitch = params:get(v.."pitch") / 10
      if pitch > 0 then
        a:segment(v,0.5,0.5+pitch,15)
      else
        a:segment(v,pitch-0.5,-0.5,15)
      end
    end
  elseif mode == 4 then
    for v=1,VOICES do
      local volume = params:get(v.."volume")
      if volume > 0 then
        a:segment(v,0.5,util.linlin(0, 20, 0.5, pi - 0.5, volume),15)
      else
        util.linlin(-60, 0, -pi + 0.5, -0.5, volume)
        a:segment(v,util.linlin(-60, 0, -pi + 0.5, -0.5, volume),-0.5,15)
      end
    end
  elseif mode == 5 then
    for v=1,VOICES do
      local density = params:get(v.."density")
      a:segment(v, 0, util.linlin(0, 512, 0, tau*0.999, density), 15)
    end
  elseif mode == 6 then
    for v=1,VOICES do
      local size = params:get(v.."size")
      a:segment(v, 0, util.linlin(1, 500, tau/64, tau*0.999, size), 15)
    end
  elseif mode == 7 then
    for v=1,VOICES do
      local jitter = params:get(v.."jitter")
      a:segment(v, 0, util.linlin(0, 500, 0, tau*0.999, jitter), 15)
    end
  else
    for v=1,VOICES do
      local spread = params:get(v.."spread")
      a:segment(v, 0, util.linlin(0, 100, 0, tau*0.999, spread), 15)
    end
  end
  a:refresh()
end

re = metro.init()
re.time = REFRESH_RATE
re.event = function()
  arc_redraw()
end
re:start()

function init()
  -- polls
  for v = 1, VOICES do
    local phase_poll = poll.set('phase_' .. v, function(pos) update_position(v, pos) end)
    phase_poll.time = REFRESH_RATE
    phase_poll:start()
  end
  
  local sep = ": "

  params:add_taper("reverb_mix", "*"..sep.."mix", 0, 100, 50, 0, "%")
  params:set_action("reverb_mix", function(value) engine.reverb_mix(value / 100) end)

  params:add_taper("reverb_room", "*"..sep.."room", 0, 100, 50, 0, "%")
  params:set_action("reverb_room", function(value) engine.reverb_room(value / 100) end)

  params:add_taper("reverb_damp", "*"..sep.."damp", 0, 100, 50, 0, "%")
  params:set_action("reverb_damp", function(value) engine.reverb_damp(value / 100) end)

  params:add_separator()
  for v = 1, VOICES do
    params:add_file(v.."sample", v..sep.."sample")
    params:set_action(v.."sample", function(file) engine.read(v, file) end)
  end

  for v = 1, VOICES do
    params:add_separator()

    params:add_option(v.."play", v..sep.."play", {"off","on"}, 2)
    params:set_action(v.."play", function(x) engine.gate(v, x-1) end)
    
    params:add_taper(v.."volume", v..sep.."volume", -60, 20, 0, 0, "dB")
    params:set_action(v.."volume", function(value) engine.volume(v, math.pow(10, value / 20)) end)

    params:add_taper(v.."speed", v..sep.."speed", -200, 200, 100, 0, "%")
    params:set_action(v.."speed", function(value) 
      engine.speed(v, value / 100)
      track_speed[v] = value
    end)

    params:add_taper(v.."jitter", v..sep.."jitter", 0, 500, 0, 5, "ms")
    params:set_action(v.."jitter", function(value) engine.jitter(v, value / 1000) end)

    params:add_taper(v.."size", v..sep.."size", 1, 500, 100, 5, "ms")
    params:set_action(v.."size", function(value) engine.size(v, value / 1000) end)

    params:add_taper(v.."density", v..sep.."density", 0, 512, 20, 6, "hz")
    params:set_action(v.."density", function(value) engine.density(v, value) end)

    params:add_taper(v.."pitch", v..sep.."pitch", -pitch_limit, pitch_limit, 0, 0, "st")
    params:set_action(v.."pitch", function(value) 
      engine.pitch(v, math.pow(0.5, -value / 12)) 
      track_pitch[v] = value
    end)

    params:add_taper(v.."spread", v..sep.."spread", 0, 100, 0, 0, "%")
    params:set_action(v.."spread", function(value) engine.spread(v, value / 100) end)

    params:add_taper(v.."fade", v..sep.."att / dec", 1, 9000, 1000, 3, "ms")
    params:set_action(v.."fade", function(value) engine.envscale(v, value / 1000) end)

    params:add_taper(v.."loop_center_pos", v..sep.."loop pos", 0, 1, 0, 0, "%")
    params:set_action(v.."loop_center_pos", function(value) loop_center_pos[v] = value end)

    params:add_taper(v.."loop_percent", v..sep.."loop percent", 0, 1, 1, 0, "%")
    params:set_action(v.."loop_percent", function(value) loop_data[v].percent = util.clamp(value, 0.001, 1) end)
  end

  params:bang()

  local loop_timer = metro.init()
  loop_timer.time = 0.01
  loop_timer.event = function()
    for v=1, VOICES do
      set_loop_ends(v)
      update_position(v, positions[v])
      loop_pos(v)
    end 
  end
  loop_timer:start()
end

function redraw()
  screen.clear()
  screen.font_face(7)
  screen.font_size(14)
  local height = 15
  
  for y=1, 4 do
    screen.move(0, y*height)
    local level = mode == y and 15 or 2
    if (hold == true and mode == y) then level = 8 end
    screen.level(level)
    screen.text(modes[y])  
  end
  
  for y=1, 4 do
    screen.move(64, y*height)
    local level = mode == y+4 and 15 or 2
    if (hold == true and mode == y+4) then level = 8 end
    screen.level(level)
    screen.text(modes[y+4])  
  end

  screen.update()
end