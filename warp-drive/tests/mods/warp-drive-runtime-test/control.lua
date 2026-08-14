local function fail(message)
  error("WARP_TEST_FAIL: " .. message)
end

local function circuit_signal(name)
  local platform = storage.platform
  local output = platform.surface.find_entities_filtered({name = "warp-drive-circuit-output"})[1]
  local section = output and output.get_or_create_control_behavior().get_section(1)
  if section then
    for index = 1, section.filters_count do
      local filter = section.get_slot(index)
      if filter.value and filter.value.name == name then
        return filter.min
      end
    end
  end
end

script.on_init(function()
  local force = game.forces.player
  local platform = force.create_space_platform({
    name = "Warp runtime test",
    planet = "nauvis",
    starter_pack = "space-platform-starter-pack"
  })
  if not platform then
    fail("platform creation returned nil")
  end
  platform.apply_starter_pack()

  local tiles = {}
  for x = -12, 12 do
    for y = -12, 12 do
      tiles[#tiles + 1] = {name = "space-platform-foundation", position = {x, y}}
    end
  end
  platform.surface.set_tiles(tiles)

  local drive = platform.surface.create_entity({
    name = "warp-drive-controller",
    position = {0, 8},
    force = force,
    raise_built = true
  })
  if not drive then
    fail("drive creation returned nil")
  end
  local duplicate = platform.surface.create_entity({
    name = "warp-drive-controller",
    position = {10, 8},
    force = force,
    raise_built = true
  })
  if duplicate and duplicate.valid then
    fail("duplicate drive survived")
  end

  platform.space_connection = "solar-system-edge-shattered-planet"
  platform.distance = 0.5
  platform.speed = 50 / 60
  platform.paused = false

  storage.platform = platform
  storage.drive = drive
end)

script.on_nth_tick(10, function()
  local platform = storage.platform
  local drive = storage.drive
  if not platform or not platform.valid or not drive or not drive.valid then
    fail("test objects became invalid")
  end

  if game.tick == 10 then
    local detector = platform.surface.find_entities_filtered({name = "warp-drive-detector-load"})
    if #detector ~= 1 then
      fail("expected one experimental detector")
    end
    detector[1].energy = detector[1].electric_buffer_size
    local player = game.players[1]
    if player then
      local frame = player.gui.screen.add({type = "frame", name = "warp_drive_scroll_test"})
      local scroll = frame.add({type = "scroll-pane", style = "scroll_pane_in_shallow_frame"})
      scroll.style.maximal_height = math.max(300,
        player.display_resolution.height / player.display_scale - 100)
      local content = scroll.add({type = "flow", direction = "vertical"})
      content.style.width = 512
      local row = content.add({type = "flow", direction = "horizontal"})
      local label = row.add({type = "label", caption = "Progress toward Shattered Planet"})
      label.style.width = 160
      local value = row.add({type = "label", caption = "345,000 km (8%)"})
      value.style.width = 320
      if scroll.type ~= "scroll-pane" or scroll.style.maximal_height < 300
        or content.style.width ~= 512 or label.style.width ~= 160
        or value.style.width ~= 320 then
        fail("bounded content and 33/67 status columns could not be created")
      end
      frame.destroy()
    end
  elseif game.tick == 20 then
    local detector = platform.surface.find_entities_filtered({name = "warp-drive-detector-load"})
    if #detector ~= 1 or detector[1].energy ~= 0 then
      fail("detector did not sample and drain available surplus power")
    end
    game.forces.player.technologies["practical-warp-drive"].researched = true
  elseif game.tick == 30 then
    local detector = platform.surface.find_entities_filtered({name = "warp-drive-detector-load"})
    if #detector ~= 0 then
      fail("experimental detector survived Practical research completion")
    end
    local charge = platform.surface.find_entities_filtered({name = "warp-drive-charge-buffer"})
    if #charge ~= 1 or charge[1].energy ~= 0 then
      fail("expected one empty charge buffer after Practical research completion")
    end
    local output = platform.surface.find_entities_filtered({name = "warp-drive-circuit-output"})
    if #output ~= 1 then
      fail("expected one circuit output companion")
    end
    local animation = platform.surface.find_entities_filtered({name = "warp-drive-animation"})
    if #animation ~= 1 then
      fail("expected one animation companion")
    end
    charge[1].energy = charge[1].electric_buffer_size
    platform.distance = 0.51
    platform.speed = 50 / 60
    platform.paused = false
  elseif game.tick == 40 then
    local support = platform.surface.find_entities_filtered({name = "warp-drive-support-load"})
    if #support ~= 1 then
      fail("expected one support load on warp entry, got " .. #support)
    end
    storage.warp_one_support_flow = support[1].input_flow_limit
    support[1].energy = support[1].electric_buffer_size
    local charge = platform.surface.find_entities_filtered({name = "warp-drive-charge-buffer"})
    if #charge ~= 1 or charge[1].energy ~= 0 then
      fail("warp entry did not consume drive charge")
    end
    if circuit_signal("signal-W") ~= 1 then
      fail("circuit output did not report active warp")
    end
    local speed = circuit_signal("signal-S")
    if speed ~= 500 then
      fail("circuit speed output was " .. tostring(speed) .. ", expected 500 km/s at Warp-1")
    end
  elseif game.tick >= 50 and game.tick <= 530 then
    if platform.distance <= 0.51 then
      fail("warp did not advance platform distance")
    end
    local support = platform.surface.find_entities_filtered({name = "warp-drive-support-load"})[1]
    if not support then
      fail("support load disappeared during powered acceleration")
    end
    if game.tick == 50 then
      local speed = circuit_signal("signal-S")
      if speed ~= 2500 then
        fail("warp accelerated above Warp-1 immediately after engine speed increased")
      end
      local expected = storage.warp_one_support_flow * (1 + 1 / 12)
      if math.abs(support.input_flow_limit - expected) > expected * 0.001 then
        fail("first acceleration probe did not request one 10-tick level step")
      end
    elseif game.tick == 170 then
      local speed = circuit_signal("signal-S")
      if math.abs((speed or 0) - 5000) > 1 then
        fail("circuit speed output was " .. tostring(speed) .. ", expected 5000 km/s at Warp-2")
      end
    elseif game.tick == 530 then
      local expected = storage.warp_one_support_flow * 5
      if math.abs(support.input_flow_limit - expected) > expected * 0.001 then
        fail("Warp-5 support demand did not equal five times Warp-1 demand")
      end
      local speed = circuit_signal("signal-S")
      if math.abs((speed or 0) - 12500) > 1 then
        fail("circuit speed output was " .. tostring(speed) .. ", expected 12500 km/s at Warp-5")
      end
    end
    support.energy = support.electric_buffer_size
  elseif game.tick == 540 then
    local support = platform.surface.find_entities_filtered({name = "warp-drive-support-load"})[1]
    local speed = circuit_signal("signal-S")
    if not support or speed ~= 2000 then
      fail("engine-speed loss did not lower Warp-5 immediately to Warp-2")
    end
    support.energy = support.electric_buffer_size * 0.9995 / 2
  elseif game.tick == 550 then
    local support = platform.surface.find_entities_filtered({name = "warp-drive-support-load"})[1]
    local speed = circuit_signal("signal-S")
    if not support or speed ~= 1000 then
      fail("support shortfall did not lower Warp-2 immediately to Warp-1")
    end
  elseif game.tick == 560 then
    local support = platform.surface.find_entities_filtered({name = "warp-drive-support-load"})
    if #support ~= 0 then
      fail("complete support-power loss did not exit warp")
    end
    local charge = platform.surface.find_entities_filtered({name = "warp-drive-charge-buffer"})
    if #charge ~= 1 then
      fail("charge buffer disappeared after power-loss exit")
    end
    charge[1].energy = charge[1].electric_buffer_size
    platform.distance = 0.51
    platform.speed = 50 / 60
  elseif game.tick == 570 then
    local support = platform.surface.find_entities_filtered({name = "warp-drive-support-load"})
    local charge = platform.surface.find_entities_filtered({name = "warp-drive-charge-buffer"})
    if #support ~= 0 or #charge ~= 1 or charge[1].energy == 0 then
      fail("drive re-entered warp during post-warp lockout")
    end
  elseif game.tick == 1150 then
    local charge = platform.surface.find_entities_filtered({name = "warp-drive-charge-buffer"})
    if #charge ~= 1 then
      fail("charge buffer disappeared during the post-warp lockout")
    end
    charge[1].energy = charge[1].electric_buffer_size
    platform.distance = 0.51
    platform.speed = 50 / 60
    platform.paused = false
  elseif game.tick == 1160 then
    local support = platform.surface.find_entities_filtered({name = "warp-drive-support-load"})
    if #support ~= 1 then
      fail("drive did not re-enter warp after the lockout")
    end
    game.forces.player.technologies["practical-warp-drive"].researched = false
  elseif game.tick == 1170 then
    local support = platform.surface.find_entities_filtered({name = "warp-drive-support-load"})
    if #support ~= 0 then
      fail("support load survived Practical research revocation")
    end
    local charge = platform.surface.find_entities_filtered({name = "warp-drive-charge-buffer"})
    if #charge ~= 0 then
      fail("charge buffer survived Practical research revocation")
    end
    local detector = platform.surface.find_entities_filtered({name = "warp-drive-detector-load"})
    if #detector ~= 1 then
      fail("experimental detector was not restored after Practical research revocation")
    end
    drive.destroy()
    storage.drive = platform.surface.create_entity({
      name = "warp-drive-controller",
      position = {-8, 8},
      force = game.forces.player,
      raise_built = true
    })
    if not storage.drive then
      fail("replacement drive creation returned nil")
    end
  elseif game.tick == 1180 then
    local companion_names = {
      "warp-drive-animation",
      "warp-drive-detector-load",
      "warp-drive-circuit-output"
    }
    for _, name in pairs(companion_names) do
      local companions = platform.surface.find_entities_filtered({name = name})
      if #companions ~= 1 or companions[1].position.x ~= -8 or companions[1].position.y ~= 8 then
        fail(name .. " was not moved with the replacement drive")
      end
    end
    if not platform.surface.can_place_entity({
      name = "warp-drive-controller",
      position = {0, 8},
      force = game.forces.player
    }) then
      fail("hidden companion blocked rebuilding at the old drive position")
    end
  elseif game.tick == 1190 then
    log("WARP_TEST_PASS: detector, duplicate, revocation, warp ramp, fallback, power-loss, lockout, and relocation paths completed")
  end
end)
