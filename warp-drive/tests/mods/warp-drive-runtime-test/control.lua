local function fail(message)
  error("WARP_TEST_FAIL: " .. message)
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

  platform.space_connection = "nauvis-vulcanus"
  platform.distance = 0.5
  platform.speed = 60
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
    platform.speed = 60
    platform.paused = false
  elseif game.tick == 40 then
    local support = platform.surface.find_entities_filtered({name = "warp-drive-support-load"})
    if #support ~= 1 then
      fail("expected one support load on warp entry, got " .. #support)
    end
    support[1].energy = support[1].electric_buffer_size
    local charge = platform.surface.find_entities_filtered({name = "warp-drive-charge-buffer"})
    if #charge ~= 1 or charge[1].energy ~= 0 then
      fail("warp entry did not consume drive charge")
    end
    local output = platform.surface.find_entities_filtered({name = "warp-drive-circuit-output"})[1]
    local section = output and output.get_or_create_control_behavior().get_section(1)
    local warp_value
    if section then
      for index = 1, section.filters_count do
        local filter = section.get_slot(index)
        if filter.value and filter.value.name == "signal-W" then
          warp_value = filter.min
          break
        end
      end
    end
    if warp_value ~= 1 then
      fail("circuit output did not report active warp")
    end
  elseif game.tick == 50 then
    if platform.distance <= 0.51 then
      fail("warp did not advance platform distance")
    end
  elseif game.tick == 60 then
    platform.paused = true
  elseif game.tick == 70 then
    local support = platform.surface.find_entities_filtered({name = "warp-drive-support-load"})
    if #support ~= 0 then
      fail("one full support sample masked the following power loss")
    end
    local charge = platform.surface.find_entities_filtered({name = "warp-drive-charge-buffer"})
    if #charge ~= 1 then
      fail("charge buffer disappeared after power-loss exit")
    end
    charge[1].energy = charge[1].electric_buffer_size
    platform.distance = 0.51
    platform.speed = 60
  elseif game.tick == 80 then
    local support = platform.surface.find_entities_filtered({name = "warp-drive-support-load"})
    local charge = platform.surface.find_entities_filtered({name = "warp-drive-charge-buffer"})
    if #support ~= 0 or #charge ~= 1 or charge[1].energy == 0 then
      fail("drive re-entered warp during post-warp lockout")
    end
  elseif game.tick == 650 then
    local charge = platform.surface.find_entities_filtered({name = "warp-drive-charge-buffer"})
    if #charge ~= 1 then
      fail("charge buffer disappeared during the post-warp lockout")
    end
    charge[1].energy = charge[1].electric_buffer_size
    platform.distance = 0.51
    platform.speed = 60
    platform.paused = false
  elseif game.tick == 660 then
    local support = platform.surface.find_entities_filtered({name = "warp-drive-support-load"})
    if #support ~= 1 then
      fail("drive did not re-enter warp after the lockout")
    end
    game.forces.player.technologies["practical-warp-drive"].researched = false
  elseif game.tick == 670 then
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
  elseif game.tick == 680 then
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
  elseif game.tick == 690 then
    log("WARP_TEST_PASS: detector, duplicate, revocation, warp, power-loss, lockout, and relocation paths completed")
  end
end)
