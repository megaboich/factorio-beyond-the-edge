local Drive = require("__warp-drive__/scripts/drive")
local Gui = require("__warp-drive__/scripts/gui")
local Research = require("__warp-drive__/scripts/research")
local Warp = require("__warp-drive__/scripts/warp")

local POWER_INTERFACE_NAME = "warp-drive-power-interface"
local SHIP_LOAD_NAME = "warp-drive-test-ship-load"

local function fail(message)
  local phase = storage.runtime_test and storage.runtime_test.phase or "initialization"
  error("WARP_TEST_FAIL [" .. phase .. "]: " .. message)
end

local PHASE_DEADLINES = {
  detector_gui = 170,
  practical_transition = 10,
  warp_ramp = 560,
  speed_grace = 620,
  exit_lockout = 610,
  reserve_brownout = 70,
  post_warp_lockout = 950,
  circuit_and_revocation = 30,
  relocation = 30
}

local function set_phase(name)
  storage.runtime_test.phase = name
  storage.runtime_test.started_at = game.tick
  remote.call("aaa-warp-drive-speed-test", "set_phase", name)
end

local function phase_elapsed()
  return game.tick - storage.runtime_test.started_at
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

local function charge_buffers(platform)
  return platform.surface.find_entities_filtered({name = POWER_INTERFACE_NAME})
end

local function charge_buffer(platform)
  return charge_buffers(platform)[1]
end

local function reserve_energy(platform)
  return remote.call("warp-drive-runtime-test", "reserve_energy", platform.index)
end

local function set_reserve_energy(platform, energy)
  remote.call("warp-drive-runtime-test", "reserve_energy", platform.index, energy)
end

local function sound_state(platform)
  return remote.call("warp-drive-runtime-test", "sound_state", platform.index)
end

local function find_gui_element(parent, name)
  if parent.name == name then
    return parent
  end
  for _, child in pairs(parent.children) do
    local result = find_gui_element(child, name)
    if result then
      return result
    end
  end
end

local function child_index(parent, child)
  for index, candidate in pairs(parent.children) do
    if candidate == child then
      return index
    end
  end
end

local function assert_research_gui_snapshot(frame, record)
  local snapshot = Research.snapshot(record)
  local branch = frame and find_gui_element(frame, "warp_drive_research_branch")
  local bonus = frame and find_gui_element(frame, "warp_drive_research_bonus")
  if not snapshot or not branch or type(branch.caption) ~= "table"
      or branch.caption[1] ~= "warp-drive.branch-" .. snapshot.branch then
    fail("research GUI branch did not match its module snapshot")
  end
  if not bonus or type(bonus.caption) ~= "table"
      or bonus.caption[1] ~= "warp-drive.research-rate-value"
      or bonus.caption[2] ~= string.format("%.2f", snapshot.bonus_rate) then
    fail("research GUI bonus estimate did not match its module snapshot")
  end
end

local function drive_tags(enabled, circuit_enabled)
  return {
    warp_drive_enabled = enabled,
    warp_drive_circuit_enabled = circuit_enabled,
    warp_drive_output_warp_enabled = true,
    warp_drive_output_warp_signal = {type = "virtual", name = "signal-W"},
    warp_drive_output_distance_enabled = true,
    warp_drive_output_distance_signal = {type = "virtual", name = "signal-D"},
    warp_drive_output_charge_enabled = true,
    warp_drive_output_charge_signal = {type = "virtual", name = "signal-C"},
    warp_drive_output_speed_enabled = true,
    warp_drive_output_speed_signal = {type = "virtual", name = "signal-S"},
    warp_drive_output_tachyon_density_enabled = true,
    warp_drive_output_tachyon_density_signal = {type = "virtual", name = "signal-T"}
  }
end

local function settings_test_tags()
  return {
    warp_drive_enabled = true,
    warp_drive_circuit_enabled = true,
    warp_drive_circuit_first_signal = {type = "virtual", name = "signal-A"},
    warp_drive_circuit_comparator = "≤",
    warp_drive_circuit_second_signal = {type = "virtual", name = "signal-B"},
    warp_drive_circuit_constant = 73,
    warp_drive_output_warp_enabled = false,
    warp_drive_output_warp_signal = {type = "virtual", name = "signal-Z"},
    warp_drive_output_distance_enabled = true,
    warp_drive_output_distance_signal = {type = "virtual", name = "signal-D"},
    warp_drive_output_charge_enabled = false,
    warp_drive_output_charge_signal = {type = "virtual", name = "signal-C"},
    warp_drive_output_speed_enabled = true,
    warp_drive_output_speed_signal = {type = "virtual", name = "signal-S"},
    warp_drive_output_tachyon_density_enabled = false,
    warp_drive_output_tachyon_density_signal = {type = "virtual", name = "signal-T"}
  }
end

local function configure_circuit_condition(player, first_signal, comparator_index,
    second_signal, constant)
  local frame = player.gui.screen.warp_drive_window
  local first = frame and find_gui_element(frame, "warp_drive_circuit_first_signal")
  local comparator = frame and find_gui_element(frame, "warp_drive_circuit_comparator")
  local second = frame and find_gui_element(frame, "warp_drive_circuit_second_signal")
  local threshold = frame and find_gui_element(frame, "warp_drive_circuit_constant")
  local enabled = frame and find_gui_element(frame, "warp_drive_circuit_enabled")
  if not first or not comparator or not second or not threshold or not enabled then
    fail("configurable circuit-condition controls were not created")
  end
  script.raise_script_revive({
    entity = storage.drive,
    tags = {
      warp_drive_circuit_enabled = true,
      warp_drive_circuit_first_signal = first_signal,
      warp_drive_circuit_comparator = ({">", "<", "=", "≥", "≤", "≠"})[comparator_index],
      warp_drive_circuit_second_signal = second_signal,
      warp_drive_circuit_constant = constant
    }
  })
  frame.destroy()
  player.opened = storage.drive
end

script.on_init(function()
  storage.runtime_test = {}
  set_phase("detector_gui")

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

  local source = platform.surface.create_entity({
    name = "warp-drive-test-power-source",
    position = {-9, -8},
    force = force
  })
  local source_pole = platform.surface.create_entity({
    name = "substation",
    position = {-7, -5},
    force = force
  })
  local drive_pole = platform.surface.create_entity({
    name = "substation",
    position = {4, 8},
    force = force
  })
  local ship_load = platform.surface.create_entity({
    name = SHIP_LOAD_NAME,
    position = {-4, 0},
    force = force
  })
  if not source or not source_pole or not drive_pole or not ship_load then
    fail("could not create the real electric network for support-power testing")
  end
  ship_load.power_usage = 0
  ship_load.input_flow_limit = 0
  source.power_production = 60e9 / 60
  source.output_flow_limit = 60e9 / 60

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
  local refunds = platform.surface.find_entities_filtered({
    type = "item-entity"
  })
  local refunded = false
  for _, item in pairs(refunds) do
    if item.stack and item.stack.valid_for_read and item.stack.name == "warp-drive" then
      refunded = true
      item.destroy()
    end
  end
  if not refunded then
    fail("duplicate drive was not refunded")
  end

  local settings_platform = force.create_space_platform({
    name = "Warp settings paste test",
    planet = "nauvis",
    starter_pack = "space-platform-starter-pack"
  })
  if not settings_platform then
    fail("settings paste platform creation returned nil")
  end
  settings_platform.apply_starter_pack()
  local settings_tiles = {}
  for x = -12, 12 do
    for y = -12, 12 do
      settings_tiles[#settings_tiles + 1] = {
        name = "space-platform-foundation",
        position = {x, y}
      }
    end
  end
  settings_platform.surface.set_tiles(settings_tiles)
  local settings_drive = settings_platform.surface.create_entity({
    name = "warp-drive-controller",
    position = {0, 8},
    force = force,
    raise_built = true
  })
  if not settings_drive then
    fail("settings paste destination creation returned nil")
  end

  platform.space_connection = "solar-system-edge-shattered-planet"
  platform.distance = 0.5
  platform.speed = 50 / 60
  platform.paused = false

  storage.platform = platform
  storage.drive = drive
  storage.power_source = source
  storage.ship_load = ship_load
  storage.settings_drive = settings_drive
  script.raise_script_revive({
    entity = drive,
    tags = settings_test_tags()
  })

  local blueprint_inventory = game.create_inventory(1)
  local blueprint = blueprint_inventory[1]
  if not blueprint.set_stack({name = "blueprint"}) then
    fail("could not create blueprint fixture")
  end
  local mapping = blueprint.create_blueprint({
    surface = platform.surface,
    force = force,
    area = {{-3, 5}, {3, 11}}
  })
  local blueprint_entity
  for entity_number, source_entity in pairs(mapping) do
    if source_entity == drive then
      blueprint_entity = entity_number
      break
    end
  end
  if not blueprint_entity then
    fail("drive was not included in blueprint fixture")
  end
  storage.drives = storage.drives or {}
  local blueprint_record = {}
  Drive.apply_settings(blueprint_record, settings_test_tags())
  storage.drives[platform.index] = blueprint_record
  Drive.tag_blueprint(blueprint, mapping)
  local blueprint_tags = blueprint.get_blueprint_entity_tags(blueprint_entity)
  if not blueprint_tags or blueprint_tags.warp_drive_circuit_comparator ~= "≤"
      or blueprint_tags.warp_drive_output_warp_enabled ~= false
      or blueprint_tags.warp_drive_output_tachyon_density_signal.name ~= "signal-T"
      or blueprint_tags.warp_drive_output_detector_power_signal ~= nil then
    fail("blueprint did not serialize the complete drive configuration")
  end
  local ghosts = blueprint.build_blueprint({
    surface = settings_platform.surface,
    force = force,
    position = {8, 8}
  })
  local blueprint_ghost
  for _, ghost in pairs(ghosts) do
    if ghost.valid and ghost.ghost_name == "warp-drive-controller" then
      blueprint_ghost = ghost
      break
    end
  end
  if not blueprint_ghost or not blueprint_ghost.tags then
    fail("blueprint did not restore drive tags onto a ghost")
  end
  settings_drive.destroy({raise_destroy = true})
  local _, restored_drive = blueprint_ghost.silent_revive({raise_revive = true})
  if not restored_drive or not restored_drive.valid then
    fail("blueprint drive could not be restored")
  end
  storage.settings_drive = restored_drive
  blueprint_inventory.destroy()
end)

script.on_nth_tick(10, function()
  local platform = storage.platform
  local drive = storage.drive
  if not platform or not platform.valid or not drive or not drive.valid then
    fail("test objects became invalid")
  end

  local phase = storage.runtime_test.phase
  if phase == "complete" then
    return
  end
  local elapsed = phase_elapsed()
  local deadline = PHASE_DEADLINES[phase]
  if not deadline then
    fail("unknown runtime test phase")
  elseif elapsed > deadline then
    fail("phase exceeded its " .. deadline .. "-tick deadline")
  end

  if phase == "detector_gui" and elapsed == 10 then
    storage.settings_drive.copy_settings(drive, game.players[1])
    script.raise_script_revive({entity = drive, tags = drive_tags(true, false)})
    local detector = platform.surface.find_entities_filtered({name = POWER_INTERFACE_NAME})
    if #detector ~= 1 then
      fail("expected one experimental detector")
    end
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
      player.opened = drive
    end
  elseif phase == "detector_gui" and elapsed == 20 then
    local player = game.players[1]
    if player and not player.gui.screen.warp_drive_window then
      fail("opening the Warp Drive did not create its GUI")
    end
    if player then
      local frame = player.gui.screen.warp_drive_window
      local reserve = find_gui_element(frame, "warp_drive_requirement_charge")
      local reserve_icon = find_gui_element(frame, "warp_drive_requirement_charge_icon")
      local power = find_gui_element(frame, "warp_drive_requirement_power")
      local power_icon = find_gui_element(frame, "warp_drive_requirement_power_icon")
      local location_heading = find_gui_element(frame, "warp_drive_location_heading")
      local location_label = find_gui_element(frame, "warp_drive_location_label")
      local circuit_state = find_gui_element(frame, "warp_drive_circuit_state")
      local automatic = find_gui_element(frame, "warp_drive_enabled")
      local circuit = find_gui_element(frame, "warp_drive_circuit_enabled")
      local warp_output = find_gui_element(frame, "warp_drive_output_warp_enabled")
      local charge_output = find_gui_element(frame, "warp_drive_output_charge_enabled")
      local speed_output = find_gui_element(frame, "warp_drive_output_speed_enabled")
      local density_output = find_gui_element(frame,
        "warp_drive_output_tachyon_density_enabled")
      local progress = find_gui_element(frame, "warp_drive_progress")
      if not reserve or reserve.style.name ~= "grey_label"
        or not reserve_icon or reserve_icon.sprite ~= "utility/status_inactive"
        or not power or power.style.name ~= "grey_label"
        or not power_icon or power_icon.sprite ~= "utility/status_inactive" then
        fail("disabled warp control did not grey out dependent checklist rows")
      end
      if not location_heading or type(location_heading.caption) ~= "table"
        or location_heading.caption[1] ~= "warp-drive.location-section"
        or not location_label or not location_label.visible
        or not circuit_state or circuit_state.visible
        or not automatic or not automatic.enabled
        or type(automatic.caption) ~= "table"
        or automatic.caption[1] ~= "warp-drive.research-enabled"
        or not circuit or not circuit.enabled
        or type(circuit.caption) ~= "table"
         or circuit.caption[1] ~= "warp-drive.research-circuit-enabled"
         or not warp_output or warp_output.parent.visible
         or not charge_output or charge_output.parent.visible
         or not speed_output or speed_output.parent.visible
        or not density_output or not density_output.parent.visible then
        fail("research GUI did not retain its position-and-signal layout")
      end
      if progress then
        fail("research GUI retained the redundant route-progress statistic")
      end
      local platform_record = Drive.get(platform.index)
      assert_research_gui_snapshot(frame, platform_record)
      local default_first = find_gui_element(frame, "warp_drive_circuit_first_signal")
      if platform_record.circuit_first_signal ~= nil
          or not default_first or default_first.elem_value ~= nil then
        fail("new drive preselected a circuit engagement signal")
      end
      local requirement_rows = {
        "warp_drive_requirement_control", "warp_drive_requirement_travel",
        "warp_drive_requirement_clearance", "warp_drive_requirement_cooldown",
        "warp_drive_requirement_charge", "warp_drive_requirement_power",
        "warp_drive_requirement_speed", "warp_drive_requirement_acceleration"
      }
      for _, requirement_name in pairs(requirement_rows) do
        local row = find_gui_element(frame, requirement_name .. "_row")
        if not row or row.style.top_margin ~= 0 or row.style.bottom_margin ~= 0 then
          fail("warp checklist rows did not use uniform vertical spacing")
        end
      end
      local density = Research.snapshot(platform_record).density
      if circuit_signal("signal-T") ~= math.floor(density)
          or circuit_signal("signal-W") ~= nil
          or circuit_signal("signal-S") ~= nil
          or circuit_signal("signal-P") ~= nil then
        fail("research circuit outputs did not expose only the configured tachyon density")
      end
      local settings_platform = storage.settings_drive.surface.platform
      settings_platform.surface.ignore_surface_conditions = true
      player.opened = storage.settings_drive
      local settings_frame = player.gui.screen.warp_drive_window
      local automatic = settings_frame and find_gui_element(settings_frame, "warp_drive_enabled")
      local circuit = settings_frame and find_gui_element(settings_frame,
        "warp_drive_circuit_enabled")
      local first = settings_frame and find_gui_element(settings_frame,
        "warp_drive_circuit_first_signal")
      local comparator = settings_frame and find_gui_element(settings_frame,
        "warp_drive_circuit_comparator")
      local second = settings_frame and find_gui_element(settings_frame,
        "warp_drive_circuit_second_signal")
      local constant = settings_frame and find_gui_element(settings_frame,
        "warp_drive_circuit_constant")
      local warp_toggle = settings_frame and find_gui_element(settings_frame,
        "warp_drive_output_warp_enabled")
      local warp_signal = settings_frame and find_gui_element(settings_frame,
        "warp_drive_output_warp_signal")
      local distance_toggle = settings_frame and find_gui_element(settings_frame,
        "warp_drive_output_distance_enabled")
      local distance_signal = settings_frame and find_gui_element(settings_frame,
        "warp_drive_output_distance_signal")
      local charge_toggle = settings_frame and find_gui_element(settings_frame,
        "warp_drive_output_charge_enabled")
      local charge_signal = settings_frame and find_gui_element(settings_frame,
        "warp_drive_output_charge_signal")
      local speed_toggle = settings_frame and find_gui_element(settings_frame,
        "warp_drive_output_speed_enabled")
      local speed_signal = settings_frame and find_gui_element(settings_frame,
        "warp_drive_output_speed_signal")
      local density_toggle = settings_frame and find_gui_element(settings_frame,
        "warp_drive_output_tachyon_density_enabled")
      local density_signal = settings_frame and find_gui_element(settings_frame,
        "warp_drive_output_tachyon_density_signal")
      local settings_record = Drive.get(settings_platform.index)
      assert_research_gui_snapshot(settings_frame, settings_record)
      if Research.branch(platform.surface) == Research.branch(settings_platform.surface) then
        fail("differently configured platform surfaces selected the same research branch")
      end
      if not automatic or automatic.state or not circuit or not circuit.state
        or not first or first.elem_value.name ~= "signal-A"
        or not comparator or comparator.selected_index ~= 5
        or not second or second.elem_value.name ~= "signal-B"
        or not constant or constant.text ~= "73"
        or not warp_toggle or warp_toggle.state
        or not warp_signal or warp_signal.elem_value.name ~= "signal-Z"
        or not distance_toggle or not distance_toggle.state
        or not distance_signal or distance_signal.elem_value.name ~= "signal-D"
        or not charge_toggle or charge_toggle.state
        or not charge_signal or charge_signal.elem_value.name ~= "signal-C"
        or not speed_toggle or not speed_toggle.state
        or not speed_signal or speed_signal.elem_value.name ~= "signal-S"
        or not density_toggle or density_toggle.state
        or not density_signal or density_signal.elem_value.name ~= "signal-T" then
        fail("settings paste did not preserve the complete normalized configuration")
      end
      warp_toggle.state = true
      Gui.handlers.on_gui_checked_state_changed({
        player_index = player.index,
        element = warp_toggle
      })
      if not settings_record.output_warp_enabled
          or settings_record.enabled or not settings_record.circuit_enabled then
        fail("output toggle changed drive engagement")
      end
      automatic.state = true
      Gui.handlers.on_gui_checked_state_changed({
        player_index = player.index,
        element = automatic
      })
      if not settings_record.enabled or settings_record.circuit_enabled then
        fail("automatic engagement did not disable circuit engagement")
      end
      circuit.state = true
      Gui.handlers.on_gui_checked_state_changed({
        player_index = player.index,
        element = circuit
      })
      if settings_record.enabled or not settings_record.circuit_enabled then
        fail("circuit engagement did not disable automatic engagement")
      end
      first.elem_value = nil
      Gui.handlers.on_gui_elem_changed({
        player_index = player.index,
        element = first
      })
      warp_signal.elem_value = nil
      Gui.handlers.on_gui_elem_changed({
        player_index = player.index,
        element = warp_signal
      })
      if settings_record.circuit_first_signal ~= nil
          or first.elem_value ~= nil
          or settings_record.output_warp_signal.name ~= "signal-W"
          or warp_signal.elem_value.name ~= "signal-W" then
        fail("cleared circuit condition signal was not empty or output signal lost its default")
      end
      comparator.selected_index = 6
      Gui.handlers.on_gui_selection_state_changed({
        player_index = player.index,
        element = comparator
      })
      if settings_record.circuit_comparator ~= "≠" then
        fail("comparator selection did not map to the stored operator")
      end
      constant.text = "2147483648"
      Gui.handlers.on_gui_text_changed({
        player_index = player.index,
        element = constant
      })
      if settings_record.circuit_constant ~= 2147483647 then
        fail("circuit constant text was not clamped to int32")
      end
      constant.text = "-2147483649"
      Gui.handlers.on_gui_confirmed({
        player_index = player.index,
        element = constant
      })
      if settings_record.circuit_constant ~= -2147483648
          or constant.text ~= "-2147483648" then
        fail("confirmed circuit constant was not clamped and normalized")
      end
      Gui.handlers.on_display_changed({player_index = player.index})
      local scroll = settings_frame.warp_drive_body.warp_drive_content_scroll
      local expected_height = math.max(300,
        player.display_resolution.height / player.display_scale - 100)
      if scroll.style.maximal_height ~= expected_height then
        fail("display change did not update GUI height")
      end
      local close = find_gui_element(settings_frame, "warp_drive_close")
      Gui.handlers.on_gui_click({player_index = player.index, element = close})
      if player.gui.screen.warp_drive_window then
        fail("close handler did not destroy the Warp Drive GUI")
      end
      player.opened = drive
      local closed = player.gui.screen.warp_drive_window
      Gui.handlers.on_gui_closed({player_index = player.index, element = closed})
      if player.gui.screen.warp_drive_window then
        fail("GUI-closed handler did not destroy the Warp Drive GUI")
      end
      player.opened = drive
      local stale = player.gui.screen.warp_drive_window
      local stale_content = stale and stale.warp_drive_body.warp_drive_content_scroll
        .warp_drive_content
      if not stale_content then
        fail("could not create the stale GUI fixture")
      end
      stale_content.warp_drive_mode_help.destroy()
    end
  elseif phase == "detector_gui" and elapsed == 30 then
    remote.call("warp-drive-runtime-test", "set_engagement", platform.index, false, false)
  elseif phase == "detector_gui" and elapsed == 40 then
    local detector = charge_buffer(platform)
    if not detector or detector.power_usage ~= 0 then
      fail("manual research control did not disable detector demand")
    end
    remote.call("warp-drive-runtime-test", "set_engagement", platform.index, false, true)
  elseif phase == "detector_gui" and elapsed == 50 then
    local detector = charge_buffer(platform)
    if not detector or detector.power_usage ~= 0 then
      fail("unsatisfied research circuit condition did not keep detection disabled")
    end
    remote.call("warp-drive-runtime-test", "set_engagement", platform.index, true, false)
  elseif phase == "detector_gui" and elapsed == 60 then
    local detector = charge_buffers(platform)
    if #detector ~= 1 or detector[1].power_usage * 60 ~= 1e9
        or detector[1].electric_buffer_size ~= detector[1].power_usage
        or detector[1].electric_interface_mode ~= defines.electric_interface_mode.secondary_input
        or detector[1].output_flow_limit ~= 0 then
      fail("experimental detector did not use one steady draw-only power interface")
    end
    local network = detector[1].electric_network
    local flow = network and network.parent_network.flow_last_tick
    local accumulator_capacity = 0
    for _, accumulator in pairs(platform.surface.find_entities_filtered({type = "accumulator"})) do
      local accumulator_network = accumulator.electric_network
      if accumulator_network and network
          and accumulator_network.parent_network.network_id == network.parent_network.network_id then
        accumulator_capacity = accumulator_capacity + accumulator.electric_buffer_size
      end
    end
    if not flow or math.abs(flow.accumulator_capacity - accumulator_capacity) > 1 then
      fail(string.format(
        "power interface appeared in accumulator charge: network=%s entities=%s",
        flow and flow.accumulator_capacity or "nil", accumulator_capacity))
    end
    storage.ship_load.power_usage = 200e6 / 60
    storage.ship_load.input_flow_limit = 200e6 / 60
    storage.power_source.power_production = 700e6 / 60
    storage.power_source.output_flow_limit = 700e6 / 60
    storage.power_source.energy = 0
    for _, accumulator in pairs(platform.surface.find_entities_filtered({type = "accumulator"})) do
      accumulator.energy = 0
    end
  elseif phase == "detector_gui" and elapsed == 90 then
    local power = charge_buffer(platform)
    local network = power and power.electric_network
    local statistics = network and network.parent_network.statistics
    storage.runtime_test.detector_ship_input = statistics
      and statistics.get_input_count(SHIP_LOAD_NAME) or 0
    storage.runtime_test.detector_ship_input_tick = game.tick
  elseif phase == "detector_gui" and elapsed == 150 then
    local detector = charge_buffer(platform)
    local requested = detector and detector.power_usage * 60 or 0
    local network = detector and detector.electric_network
    local statistics = network and network.parent_network.statistics
    local input = statistics and statistics.get_input_count(SHIP_LOAD_NAME) or 0
    local input_elapsed = game.tick - (storage.runtime_test.detector_ship_input_tick or game.tick)
    local ship_watts = input_elapsed > 0
      and (input - (storage.runtime_test.detector_ship_input or input)) * 60 / input_elapsed or 0
    if requested < 495e6 or requested > 511e6 or ship_watts < 195e6 then
      fail(string.format(
        "experimental detector did not converge on spare generation: request=%s ship=%s",
        requested, ship_watts))
    end
    storage.power_source.power_production = 900e6 / 60
    storage.power_source.output_flow_limit = 900e6 / 60
  elseif phase == "detector_gui" and elapsed == 160 then
    local detector = charge_buffer(platform)
    storage.runtime_test.detector_recovery_request = detector and detector.power_usage * 60 or 0
  elseif phase == "detector_gui" and elapsed == 170 then
    local detector = charge_buffer(platform)
    local requested = detector and detector.power_usage * 60 or 0
    local previous = storage.runtime_test.detector_recovery_request or requested
    if math.abs(requested - previous - 10e6) > 1 then
      fail(string.format(
        "experimental detector did not probe increased capacity by 10 MW: before=%s after=%s",
        previous, requested))
    end
    storage.ship_load.power_usage = 0
    storage.ship_load.input_flow_limit = 0
    storage.power_source.power_production = 60e9 / 60
    storage.power_source.output_flow_limit = 60e9 / 60
    remote.call("warp-drive-runtime-test", "set_engagement", platform.index, false, true)
    game.forces.player.technologies["practical-warp-drive"].researched = true
    set_phase("practical_transition")
  elseif phase == "practical_transition" and elapsed == 10 then
    local detector = platform.surface.find_entities_filtered({name = POWER_INTERFACE_NAME})
    local charge = charge_buffers(platform)
    if #charge ~= 1 or charge[1].energy > 1 then
      fail("expected one dormant power interface after Practical research completion")
    end
    local required_charge = platform.weight * 100
    if charge[1].type ~= "electric-energy-interface" or charge[1].output_flow_limit ~= 0 then
      fail("power interface exposed the private reserve to the ship network")
    end
    local support = platform.surface.find_entities_filtered({name = "warp-drive-support-load"})
    if #support ~= 0 then
      fail("legacy support interface survived migration")
    end
    local output = platform.surface.find_entities_filtered({name = "warp-drive-circuit-output"})
    if #output ~= 1 then
      fail("expected one circuit output companion")
    end
    local animation = platform.surface.find_entities_filtered({name = "warp-drive-animation"})
    if #animation ~= 1 then
      fail("expected one animation companion")
    end
    script.raise_script_revive({entity = drive, tags = drive_tags(true, false)})
    set_reserve_energy(platform, required_charge)
    -- Keep unrelated platform accumulators from affecting the controlled generation used by
    -- acceleration assertions. A later test adds an explicit ordinary secondary-input load.
    for _, accumulator in pairs(platform.surface.find_entities_filtered({type = "accumulator"})) do
      accumulator.energy = accumulator.electric_buffer_size
    end
    local asteroid = platform.surface.create_entity({
      name = "small-metallic-asteroid",
      position = {10, 0},
      velocity = {0, 0}
    })
    if not asteroid then
      fail("could not create an asteroid for warp suppression testing")
    end
    platform.create_asteroid_chunks({{
      name = "metallic-asteroid-chunk",
      position = {-10, 0},
      movement = {0, 0}
    }})
    platform.distance = 0.51
    platform.speed = 50 / 60
    platform.paused = false
    set_phase("warp_ramp")
  elseif phase == "warp_ramp" and elapsed == 10 then
    local support = charge_buffer(platform)
    if not support then
      fail("power interface disappeared on warp entry")
    end
    local charge = charge_buffers(platform)
    local required_charge = platform.weight * 100
    if #charge ~= 1 or math.abs(reserve_energy(platform) - required_charge * 0.1) > 1 then
      fail(string.format(
        "warp entry did not retain ten percent of the activation charge: energy=%s required=%s",
        reserve_energy(platform), required_charge))
    end
    if #platform.surface.find_entities_filtered({type = "asteroid"}) ~= 0
      or #platform.find_asteroid_chunks_filtered({}) ~= 0 then
      fail("warp entry did not remove asteroid entities and chunks")
    end
    local streaks = 0
    for _, object in pairs(rendering.get_all_objects("warp-drive")) do
      if object.type == "line" then
        streaks = streaks + 1
        local position = object.from.position
        if position.x < -76 or position.x > 77 or position.y < -76 or position.y > 77 then
          fail(string.format(
            "subspace streak escaped 64-tile platform field: x=%s y=%s",
            position.x, position.y))
        end
      end
    end
    if streaks < 48 then
      fail("warp entry did not create the subspace streak field")
    end
    if #platform.surface.find_entities_filtered({name = "warp-drive-lightning"}) < 1 then
      fail("warp entry did not create full procedural Fulgora lightning")
    end
    if circuit_signal("signal-W") ~= 1 then
      fail("circuit output did not report active warp")
    end
    local speed = circuit_signal("signal-S")
    if speed ~= 500 then
      fail("circuit speed output was " .. tostring(speed) .. ", expected 500 km/s at Warp-1")
    end
  elseif phase == "warp_ramp" and elapsed >= 20 and elapsed <= 560 then
    if elapsed == 200 then
      local sound = sound_state(platform)
      if sound.background_index ~= 2
          or sound.warp_next_tick ~= storage.runtime_test.started_at + 460 then
        fail("activation did not hand off to warp background segment 01 after 1.5 seconds")
      end
    elseif elapsed == 560 then
      local sound = sound_state(platform)
      if sound.background_index ~= 1
          or sound.warp_next_tick ~= storage.runtime_test.started_at + 820 then
        fail("warp background did not alternate to segment 02 after six seconds")
      end
    end
    if elapsed == 30 then
      local player = game.players[1]
      if player then
        local frame = player.gui.screen.warp_drive_window
        local panel = find_gui_element(frame, "warp_drive_circuit_panel")
        local networks = find_gui_element(frame, "warp_drive_circuit_networks")
        local main = find_gui_element(frame, "warp_drive_content_scroll")
        local body = find_gui_element(frame, "warp_drive_body")
        local red_network = find_gui_element(frame, "warp_drive_circuit_red_network")
        local green_network = find_gui_element(frame, "warp_drive_circuit_green_network")
        local distance_toggle = find_gui_element(frame, "warp_drive_output_distance_enabled")
        local automatic_toggle = find_gui_element(frame, "warp_drive_enabled")
        local circuit_toggle = find_gui_element(frame, "warp_drive_circuit_enabled")
        local warp_signal = find_gui_element(frame, "warp_drive_output_warp_signal")
        local charge_signal = find_gui_element(frame, "warp_drive_output_charge_signal")
        local speed_signal = find_gui_element(frame, "warp_drive_output_speed_signal")
        local density_signal = find_gui_element(frame, "warp_drive_output_tachyon_density_signal")
        local requirement_control_icon = find_gui_element(frame,
          "warp_drive_requirement_control_icon")
        local requirement_control_label = find_gui_element(frame,
          "warp_drive_requirement_control_label")
        local requirement_control = find_gui_element(frame, "warp_drive_requirement_control")
        local requirement_charge = find_gui_element(frame, "warp_drive_requirement_charge")
        local requirement_speed = find_gui_element(frame, "warp_drive_requirement_speed")
        local requirement_speed_label = find_gui_element(frame,
          "warp_drive_requirement_speed_label")
        local requirement_power = find_gui_element(frame, "warp_drive_requirement_power")
        local requirement_acceleration = find_gui_element(frame,
          "warp_drive_requirement_acceleration")
        local requirement_acceleration_icon = find_gui_element(frame,
          "warp_drive_requirement_acceleration_icon")
        local requirement_clearance = find_gui_element(frame, "warp_drive_requirement_clearance")
        local requirement_destination = find_gui_element(frame, "warp_drive_requirement_travel")
        local requirement_cooldown_label = find_gui_element(frame,
          "warp_drive_requirement_cooldown_label")
        local requirement_cooldown = find_gui_element(frame, "warp_drive_requirement_cooldown")
        local location = find_gui_element(frame, "warp_drive_location")
        local location_heading = find_gui_element(frame, "warp_drive_location_heading")
        local location_label = find_gui_element(frame, "warp_drive_location_label")
        local research_section = find_gui_element(frame, "warp_drive_research_section")
        local warp_section = find_gui_element(frame, "warp_drive_warp_section")
        if not panel or panel.style.width ~= 272 or not main or main.style.width ~= 544
          or not body or body.style.horizontal_spacing ~= 4 or body.style.width ~= 820
          or not networks or panel.children[2] ~= networks
          or not red_network or not green_network
          or type(red_network.caption) ~= "table"
          or red_network.caption[1] ~= "warp-drive.circuit-network-disconnected"
          or type(green_network.caption) ~= "table"
          or green_network.caption[1] ~= "warp-drive.circuit-network-disconnected"
          or not automatic_toggle or automatic_toggle.type ~= "checkbox"
          or type(automatic_toggle.caption) ~= "table"
          or automatic_toggle.caption[1] ~= "warp-drive.enabled"
          or not circuit_toggle or circuit_toggle.type ~= "checkbox"
          or type(circuit_toggle.caption) ~= "table"
          or circuit_toggle.caption[1] ~= "warp-drive.circuit-enabled"
          or not distance_toggle or not distance_toggle.state
          or type(distance_toggle.caption) ~= "table"
          or distance_toggle.caption[1] ~= "warp-drive.output-distance"
          or warp_signal.elem_value.name ~= "signal-W"
          or charge_signal.elem_value.name ~= "signal-C"
          or speed_signal.elem_value.name ~= "signal-S"
          or density_signal.elem_value.name ~= "signal-T"
          or density_signal.parent.visible
          or not requirement_control_icon
          or requirement_control_icon.sprite ~= "utility/check_mark_green"
          or not requirement_control_label
          or requirement_control_label.style.name ~= "green_label"
          or type(requirement_control_label.caption) ~= "table"
          or requirement_control_label.caption[1] ~= "warp-drive.requirement-control-label"
          or not requirement_control or requirement_control.style.name ~= "label"
          or type(requirement_control.caption) ~= "table"
          or requirement_control.caption[1] ~= "warp-drive.requirement-control-automatic"
          or not requirement_charge or type(requirement_charge.caption) ~= "table"
          or requirement_charge.caption[1] ~= "warp-drive.charge-value"
          or not requirement_speed or type(requirement_speed.caption) ~= "table"
          or requirement_speed.caption[1] ~= "warp-drive.requirement-speed-value"
          or not requirement_speed_label or type(requirement_speed_label.caption) ~= "table"
          or requirement_speed_label.caption[1] ~= "warp-drive.requirement-speed-label"
          or not requirement_power or type(requirement_power.caption) ~= "table"
          or requirement_power.caption[1] ~= "warp-drive.requirement-power-value"
          or type(requirement_power.caption[2]) ~= "string"
          or requirement_power.caption[3] ~= nil
          or not requirement_acceleration
          or type(requirement_acceleration.caption) ~= "table"
          or requirement_acceleration.caption[1] ~= "warp-drive.ramp-accelerating"
          or not requirement_acceleration_icon
          or requirement_acceleration_icon.sprite ~= "utility/check_mark_green"
          or not requirement_clearance or requirement_clearance.style.name ~= "label"
          or type(requirement_clearance.caption) ~= "table"
          or requirement_clearance.caption[1]
            ~= "warp-drive.requirement-clearance-clear"
          or #requirement_clearance.caption ~= 1
          or not requirement_destination or type(requirement_destination.caption) ~= "table"
          or requirement_destination.caption[1] ~= ""
          or not string.find(requirement_destination.caption[2],
            "[space-location=shattered-planet]", 1, true)
          or not requirement_cooldown_label
          or type(requirement_cooldown_label.caption) ~= "table"
          or requirement_cooldown_label.caption[1] ~= "warp-drive.requirement-cooldown-label"
          or not requirement_cooldown or type(requirement_cooldown.caption) ~= "table"
          or find_gui_element(frame, "warp_drive_warp_status")
          or find_gui_element(frame, "warp_drive_warp_charge_progress")
          or find_gui_element(frame, "warp_drive_warp_boost")
          or find_gui_element(frame, "warp_drive_effective_speed")
          or not location or type(location.caption) ~= "table"
          or location.caption[1] ~= "warp-drive.location-transit-distance"
          or type(location.caption[4]) ~= "string"
          or location.style.width ~= 480
          or not location_heading or type(location_heading.caption) ~= "table"
          or location_heading.caption[1] ~= "warp-drive.current-position-section"
          or not location_label or location_label.visible
          or not research_section
          or find_gui_element(frame, "warp_drive_activation_charge")
          or find_gui_element(frame, "warp_drive_charge_bar")
          or find_gui_element(frame, "warp_drive_platform_speed")
          or find_gui_element(frame, "warp_drive_warp_level")
          or find_gui_element(frame, "warp_drive_route_clearance")
          or find_gui_element(frame, "warp_drive_cooldown")
          or find_gui_element(frame, "warp_drive_warp_ramp")
          or find_gui_element(frame, "warp_drive_support_demand")
          or find_gui_element(frame, "warp_drive_support_delivery")
          or find_gui_element(frame, "warp_drive_warp_target") then
          fail("two-column circuit panel did not expose the default output controls")
        end
        local ordered_requirements = {
          requirement_control.parent,
          requirement_destination.parent,
          requirement_clearance.parent,
          requirement_cooldown.parent,
          requirement_charge.parent,
          requirement_power.parent,
          requirement_speed.parent,
          requirement_acceleration.parent
        }
        for index = 2, #ordered_requirements do
          if not warp_section
            or child_index(warp_section, ordered_requirements[index - 1])
              >= child_index(warp_section, ordered_requirements[index]) then
            fail("warp checklist rows were not grouped in operational order")
          end
        end
        local content = find_gui_element(player.gui.screen.warp_drive_window,
          "warp_drive_content")
        if content.warp_drive_detector_section.visible
          or content.warp_drive_research_section.visible
          or content.warp_drive_mode_help.visible then
          fail("completed-research GUI retained experimental sections")
        end
        local alert = content.warp_drive_alert
        local alert_details = alert and alert.warp_drive_alert_details
        local alert_header = alert_details and alert_details.warp_drive_alert_header
        local alert_sprite = alert_header and alert_header.warp_drive_alert_sprite
        local alert_text = alert_header and alert_header.warp_drive_alert_text
        local alert_boost = alert_details and alert_details.warp_drive_alert_boost
        local alert_speed = alert_details and alert_details.warp_drive_alert_speed
        local charge_progress = alert_details
          and alert_details.warp_drive_alert_charge_progress
        local snapshot = Warp.snapshot(platform_record)
        if content.warp_drive_mode_banner
          or not alert or not alert.visible or alert.style.height ~= 76
          or not alert_header or alert_header.style.vertical_align ~= "center"
          or not alert_sprite or alert_sprite.parent ~= alert_header
          or alert_sprite.sprite ~= "utility/status_working"
          or alert_header.style.horizontal_spacing ~= 8
          or alert_text.style.left_margin ~= 0
          or alert_boost.style.left_margin ~= 26
          or alert_speed.style.left_margin ~= 26
          or not alert_text or alert_text.parent ~= alert_header
          or alert_text.style.name ~= "label"
          or type(alert_text.caption) ~= "table"
          or alert_text.caption[1] ~= "warp-drive.active-warp-level"
          or alert_text.caption[2] ~= string.format("%.1f", platform_record.warp_level)
          or not alert_boost or not alert_boost.visible
          or type(alert_boost.caption) ~= "table"
          or alert_boost.caption[1] ~= "warp-drive.active-warp-boost"
          or alert_boost.caption[2] ~= string.format("%.2f", snapshot.warp_boost)
          or not alert_speed or not alert_speed.visible
          or type(alert_speed.caption) ~= "table"
          or alert_speed.caption[1] ~= "warp-drive.active-warp-effective-speed"
          or alert_speed.caption[2] ~= string.format("%.2f", snapshot.effective_speed)
          or not charge_progress or charge_progress.visible then
          fail("operational status did not replace the mode banner and bottom warp stats")
        end
      end
    end
    if platform.distance <= 0.51 then
      fail("warp did not advance platform distance")
    end
    local support = charge_buffer(platform)
    if not support then
      fail("support load disappeared during powered acceleration")
    end
    if elapsed == 20 then
      local network = support.electric_network
      local source_network = storage.power_source.electric_network
      if not network or not source_network or network.parent_network ~= source_network.parent_network then
        fail("support load and power source are not on the same electric network")
      end
    end
    if elapsed == 30 then
      local speed = circuit_signal("signal-S")
      local charge = charge_buffer(platform)
      local required_charge = platform.weight * 100
      if not speed or speed <= 2500 or speed >= 5000 then
        fail("warp did not begin its timed acceleration after engine speed increased")
      end
      if not charge or reserve_energy(platform) <= required_charge * 0.1
          or reserve_energy(platform) >= required_charge then
        fail(string.format(
          "delivered active power did not begin replenishing the entry reserve: energy=%s required=%s input=%s usage=%s",
          reserve_energy(platform), required_charge,
          charge and charge.input_flow_limit * 60 or "nil",
          charge and charge.power_usage * 60 or "nil"))
      end
      local minimum_watts = platform.weight * 10 * 2
      if support.power_usage * 60 <= minimum_watts
          or support.power_usage ~= support.input_flow_limit then
        fail("acceleration did not request support plus reserve replenishment")
      end
    elseif elapsed == 140 then
      local speed = circuit_signal("signal-S")
      if math.abs((speed or 0) - 5000) > 1 then
        fail("circuit speed output was " .. tostring(speed)
          .. ", expected 5000 km/s at Warp-2")
      end
    elseif elapsed == 500 then
      local speed = circuit_signal("signal-S")
      if math.abs((speed or 0) - 12500) > 1 then
        fail("circuit speed output was " .. tostring(speed) .. ", expected 12500 km/s at Warp-5")
      end
    elseif elapsed == 560 then
      local speed = circuit_signal("signal-S")
      local charge = charge_buffer(platform)
      local required_charge = platform.weight * 100
      if math.abs((speed or 0) - 12500) > 1 then
        fail("circuit speed output changed after reaching Warp-5")
      end
      if not charge or math.abs(reserve_energy(platform) - required_charge) > 1 then
        fail("delivered active power did not replenish the warp reserve to full")
      end
      local expected_watts = platform.weight * 10 * 5
      if math.abs(support.power_usage * 60 - expected_watts) > expected_watts * 0.001 then
        fail("Warp-5 did not request five times the mass-scaled Warp-1 power")
      end
      set_phase("speed_grace")
    end
  elseif phase == "speed_grace" and elapsed == 10 then
    local support = charge_buffer(platform)
    local speed = circuit_signal("signal-S")
    if not support or speed ~= 2000 then
      fail("engine-speed loss did not lower Warp-5 immediately to Warp-2")
    end
    local player = game.players[1]
    if player then
      local frame = player.gui.screen.warp_drive_window
      local acceleration = find_gui_element(frame, "warp_drive_requirement_acceleration")
      local icon = find_gui_element(frame, "warp_drive_requirement_acceleration_icon")
      if not acceleration or type(acceleration.caption) ~= "table"
        or acceleration.caption[1] ~= "warp-drive.ramp-engine-limited"
        or not icon or icon.sprite ~= "utility/status_yellow" then
        fail("engine-limited acceleration was not shown as an orange checklist state")
      end
    end
  elseif phase == "speed_grace" and elapsed == 20 then
    local expected_distance = math.ceil((1 - platform.distance) * platform.space_connection.length)
    local distance = circuit_signal("signal-D")
    local detector = circuit_signal("signal-P")
    local density = circuit_signal("signal-T")
    local level = circuit_signal("signal-W")
    if distance ~= expected_distance or detector ~= nil or density ~= nil or level ~= 2 then
      fail(string.format(
        "configurable outputs were incorrect: D=%s expected=%s P=%s T=%s W=%s",
        tostring(distance), tostring(expected_distance), tostring(detector), tostring(density),
        tostring(level)))
    end
  elseif phase == "speed_grace" and elapsed == 70 then
    local support = charge_buffers(platform)
    if #support ~= 1 or circuit_signal("signal-W") ~= 1 then
      fail("temporary low speed did not retain Warp-1")
    end
    local player = game.players[1]
    if player then
      local frame = player.gui.screen.warp_drive_window
      local speed_icon = find_gui_element(frame, "warp_drive_requirement_speed_icon")
      local speed_label = find_gui_element(frame, "warp_drive_requirement_speed_label")
      local speed = find_gui_element(frame, "warp_drive_requirement_speed")
      local alert = find_gui_element(frame, "warp_drive_alert")
      local alert_text = find_gui_element(frame, "warp_drive_alert_text")
      if not speed_icon or speed_icon.sprite ~= "utility/status_yellow"
        or not speed_label or speed_label.style.name ~= "orange_label"
        or not speed or type(speed.caption) ~= "table"
        or speed.caption[1] ~= "warp-drive.requirement-speed-warning"
        or not alert or not alert.visible or alert.style.height ~= 76
        or not alert_text or type(alert_text.caption) ~= "table"
        or alert_text.caption[1] ~= "warp-drive.active-warp-level" then
        fail("speed-exit grace period was not contained in the orange checklist state")
      end
    end
  elseif phase == "speed_grace" and elapsed == 250 then
    if circuit_signal("signal-W") ~= 1 then
      fail("restored engine speed did not cancel the pending warp exit")
    end
  elseif phase == "speed_grace" and elapsed == 370 then
    if circuit_signal("signal-W") ~= 1 then
      fail("sustained low speed did not retain Warp-1 during the exit countdown")
    end
  elseif phase == "speed_grace" and elapsed == 620 then
    local support = charge_buffers(platform)
    if #support ~= 1 or circuit_signal("signal-W") ~= 0 then
      fail("sustained low speed did not exit warp after five seconds")
    end
    local player = game.players[1]
    if player and player.gui.screen.warp_drive_window then
      local frame = player.gui.screen.warp_drive_window
      local alert_header = find_gui_element(frame, "warp_drive_alert_header")
      local alert_sprite = find_gui_element(frame, "warp_drive_alert_sprite")
      local alert_text = find_gui_element(frame, "warp_drive_alert_text")
      local reason = find_gui_element(frame, "warp_drive_alert_boost")
      if not alert_header or alert_header.style.vertical_align ~= "center"
        or not alert_sprite or alert_sprite.parent ~= alert_header
        or alert_sprite.sprite ~= "utility/status_not_working"
        or not alert_text or alert_text.parent ~= alert_header
        or type(alert_text.caption) ~= "table"
        or alert_text.caption[1] ~= "warp-drive.inactive-status"
        or not reason or not reason.visible or type(reason.caption) ~= "table"
        or reason.caption[1] ~= "warp-drive.last-deactivation-reason"
        or type(reason.caption[2]) ~= "table"
        or reason.caption[2][1] ~= "warp-drive.deactivation-reason-insufficient-speed" then
        fail("normal warp exit did not show the inactive status and labeled reason")
      end
    end
    set_phase("exit_lockout")
  elseif phase == "exit_lockout" and elapsed == 10 then
    local power = charge_buffer(platform)
    local network = power and power.electric_network
    local statistics = network and network.parent_network.statistics
    if not power or power.power_usage ~= 0 or power.input_flow_limit ~= 0
        or power.electric_buffer_size ~= 1 then
      fail("inactive drive retained active electrical demand or buffer capacity")
    end
    storage.runtime_test.inactive_power_input = statistics
      and statistics.get_input_count(POWER_INTERFACE_NAME) or 0
    local player = game.players[1]
    if player then
      local frame = player.gui.screen.warp_drive_window
      if frame then
        frame.destroy()
      end
      player.opened = drive
      local cooldown = find_gui_element(player.gui.screen.warp_drive_window,
        "warp_drive_requirement_cooldown")
      if not cooldown or type(cooldown.caption) ~= "table"
          or cooldown.caption[1] ~= "warp-drive.requirement-cooldown-waiting"
          or type(cooldown.caption[2]) ~= "number"
          or cooldown.caption[2] ~= math.ceil(590 / 60) then
        fail("re-entry lockout did not display whole seconds rounded up")
      end
    end
  elseif phase == "exit_lockout" and elapsed == 590 then
    local charge = charge_buffer(platform)
    if not charge then
      fail("charge buffer disappeared during the low-speed exit lockout")
    end
    local network = charge.electric_network
    local statistics = network and network.parent_network.statistics
    local input = statistics and statistics.get_input_count(POWER_INTERFACE_NAME) or 0
    if input - (storage.runtime_test.inactive_power_input or input) > 1 then
      fail("inactive drive periodically consumed electrical energy")
    end
    set_reserve_energy(platform, platform.weight * 100)
    storage.power_source.power_production = 60e9 / 60
    storage.power_source.output_flow_limit = 60e9 / 60
  elseif phase == "exit_lockout" and elapsed == 610 then
    local support = charge_buffer(platform)
    local charge = charge_buffer(platform)
    local required_charge = platform.weight * 100
    if not support or circuit_signal("signal-W") ~= 1 or not charge then
      fail("drive did not re-enter warp after the low-speed exit lockout")
    end
    set_reserve_energy(platform, required_charge * 0.1)
    local warp_one_watts = platform.weight * 10
    local ship_load_watts = warp_one_watts * 2
    storage.ship_load.power_usage = ship_load_watts / 60
    storage.ship_load.input_flow_limit = ship_load_watts / 60
    local brownout_watts = ship_load_watts + warp_one_watts * 0.5
    storage.power_source.power_production = brownout_watts / 60
    storage.power_source.output_flow_limit = brownout_watts / 60
    storage.power_source.energy = 0
    for _, accumulator in pairs(platform.surface.find_entities_filtered({type = "accumulator"})) do
      accumulator.energy = 0
    end
    set_phase("reserve_brownout")
  elseif phase == "reserve_brownout" and elapsed == 10 then
    local support = charge_buffer(platform)
    local charge = charge_buffer(platform)
    local required_charge = platform.weight * 100
    local speed = circuit_signal("signal-S")
    local network = storage.power_source.electric_network
    local flow = network and network.parent_network.flow_last_tick
    if not flow or flow.secondary_demand_usage >= 0.999
        or flow.secondary_demand_usage <= 0 then
      fail(string.format(
        "controlled brownout did not proportionally limit secondary consumers: secondary=%s/%s tertiary=%s/%s source=%s/%s load=%s support=%s",
        flow and flow.secondary_demand or "nil",
        flow and flow.secondary_demand_usage or "nil",
        flow and flow.tertiary_demand or "nil",
        flow and flow.tertiary_demand_usage or "nil",
        storage.power_source.power_production,
        storage.power_source.output_flow_limit,
        storage.ship_load.power_usage,
        support and support.power_usage or "nil"))
    end
    if not support or speed ~= 1000 or not charge
        or reserve_energy(platform) <= 0
        or reserve_energy(platform) >= required_charge * 0.1 then
      fail(string.format(
        "shared secondary brownout did not hold warp by draining reserve: speed=%s charge=%s support=%s source=%s/%s secondary=%s/%s tertiary=%s/%s transfer=%s",
        tostring(speed), reserve_energy(platform),
        support and support.power_usage or "nil",
        storage.power_source.power_production, storage.power_source.output_flow_limit,
        flow and flow.secondary_demand or "nil", flow and flow.secondary_demand_usage or "nil",
        flow and flow.tertiary_demand or "nil", flow and flow.tertiary_demand_usage or "nil",
        flow and flow.total_transfer or "nil"))
    end
    storage.ship_load.power_usage = 0
    storage.ship_load.input_flow_limit = 0
    storage.power_source.power_production = 0
    storage.power_source.output_flow_limit = 0
  elseif phase == "reserve_brownout" and elapsed == 40 then
    local support = charge_buffers(platform)
    local charge = charge_buffers(platform)
    local required_charge = platform.weight * 100
    if #support ~= 1 or #charge ~= 1 or reserve_energy(platform) <= 0
      or reserve_energy(platform) >= required_charge then
      fail("complete support-power loss did not begin draining the warp support reserve")
    end
    if circuit_signal("signal-W") ~= 1 or circuit_signal("signal-S") ~= 1000 then
      fail("drive did not maintain its current warp level while reserve power was available")
    end
  elseif phase == "reserve_brownout" and elapsed == 70 then
    local support = charge_buffers(platform)
    local charge = charge_buffers(platform)
    if #support ~= 1 or #charge ~= 1 or reserve_energy(platform) ~= 0 or circuit_signal("signal-W") ~= 0 then
      fail("ten-percent warp support reserve did not deplete after one second of outage")
    end
    set_reserve_energy(platform, 1)
    platform.distance = 0.51
    platform.speed = 50 / 60
    set_phase("post_warp_lockout")
  elseif phase == "post_warp_lockout" and elapsed == 10 then
    local support = charge_buffers(platform)
    local charge = charge_buffers(platform)
    if #support ~= 1 or #charge ~= 1 or reserve_energy(platform) ~= 0 then
      fail("post-warp lockout did not keep the reserve empty")
    end
  elseif phase == "post_warp_lockout" and elapsed == 590 then
    local charge = charge_buffers(platform)
    if #charge ~= 1 then
      fail("charge buffer disappeared during the post-warp lockout")
    end
    set_reserve_energy(platform, platform.weight * 50)
    local charging_watts = platform.weight * 10 * 0.5
    storage.power_source.power_production = charging_watts / 60
    storage.power_source.output_flow_limit = charging_watts / 60
    platform.distance = 0.51
    platform.speed = 49 / 60
    platform.paused = false
  elseif phase == "post_warp_lockout" and elapsed == 600 then
    local charge = charge_buffers(platform)
    local support = charge_buffer(platform)
    if #charge ~= 1 or reserve_energy(platform) < platform.weight * 50 or not support then
      fail("charging did not begin before the speed interruption")
    end
    local sound = sound_state(platform)
    if not sound.charge_step or not sound.readiness_announced
        or sound.readiness_sound_tick ~= game.tick then
      fail("ready preparation did not announce once before beginning its audible hum")
    end
  elseif phase == "post_warp_lockout" and elapsed == 610 then
    local charge = charge_buffers(platform)
    local support = charge_buffers(platform)
    if #charge ~= 1 or reserve_energy(platform) ~= 0 or #support ~= 1 then
      fail("failed minimum speed did not reset the partial charging reserve")
    end
    local sound = sound_state(platform)
    if sound.state ~= "cooldown"
        or sound.cooldown_until ~= game.tick + 300
        or sound.last_exit_reason ~= "charging-speed-interrupted"
        or sound.readiness_announced or sound.readiness_sound_tick ~= nil
        or sound.charge_step ~= nil or sound.charge_next_tick ~= nil then
      fail(string.format(
        "failed activation lockout mismatch: state=%s deadline=%s expected=%s reason=%s step=%s next=%s",
        tostring(sound.state), tostring(sound.cooldown_until), tostring(game.tick + 300),
        tostring(sound.last_exit_reason), tostring(sound.charge_step),
        tostring(sound.charge_next_tick)))
    end
  elseif phase == "post_warp_lockout" and elapsed == 620 then
    local charge = charge_buffers(platform)
    local power = charge_buffer(platform)
    if #charge ~= 1 or reserve_energy(platform) ~= 0 or not power
        or power.power_usage ~= 0 or power.input_flow_limit ~= 0
        or power.electric_buffer_size ~= 1 or not power.disabled_by_script then
      fail("failed-activation lockout did not keep the reserve and power interface disabled")
    end
  elseif phase == "post_warp_lockout" and elapsed == 900 then
    local sound = sound_state(platform)
    if sound.state ~= "cooldown" or sound.cooldown_until ~= game.tick + 10 then
      fail("failed-activation lockout ended before its existing cooldown deadline")
    end
  elseif phase == "post_warp_lockout" and elapsed == 910 then
    local charge = charge_buffers(platform)
    local support = charge_buffer(platform)
    local expected_watts = platform.weight * 10
    if #charge ~= 1 or reserve_energy(platform) ~= 0 or not support
      or math.abs(support.power_usage * 60 - expected_watts) > expected_watts * 0.001 then
      fail("charging did not begin after the final non-reserve requirement was met")
    end
    local sound = sound_state(platform)
    if not sound.readiness_announced or sound.readiness_sound_tick ~= game.tick
        or sound.charge_step ~= 1
        or not sound.charge_next_tick
        or sound.charge_next_tick <= game.tick
        or sound.charge_next_tick > game.tick + 30 then
      fail("charging did not start its half-second progress hum scheduler")
    end
  elseif phase == "post_warp_lockout" and elapsed == 920 then
    local sound = sound_state(platform)
    if not sound.readiness_announced
        or sound.readiness_sound_tick ~= storage.runtime_test.started_at + 910 then
      fail("continuous readiness replayed or cleared the one-shot warp command")
    end
    local player = game.players[1]
    if player and player.gui.screen.warp_drive_window then
      local content = find_gui_element(player.gui.screen.warp_drive_window,
        "warp_drive_content")
      local power = find_gui_element(content, "warp_drive_requirement_power")
      local power_icon = find_gui_element(content, "warp_drive_requirement_power_icon")
      local reserve_icon = find_gui_element(content, "warp_drive_requirement_charge_icon")
      local alert = find_gui_element(content, "warp_drive_alert")
      local alert_header = find_gui_element(content, "warp_drive_alert_header")
      local alert_sprite = find_gui_element(content, "warp_drive_alert_sprite")
      local alert_text = find_gui_element(content, "warp_drive_alert_text")
      local alert_boost = find_gui_element(content, "warp_drive_alert_boost")
      local alert_speed = find_gui_element(content, "warp_drive_alert_speed")
      local charge_progress = find_gui_element(content, "warp_drive_alert_charge_progress")
      local charge = charge_buffer(platform)
      local required_charge = platform.weight * 100
      local charge_ratio = charge and reserve_energy(platform) / required_charge or 0
      if find_gui_element(content, "warp_drive_mode_banner")
        or not power or type(power.caption) ~= "table"
        or power.caption[1] ~= "warp-drive.requirement-power-value"
        or power.style.name ~= "label"
        or not power_icon or power_icon.sprite ~= "utility/status_yellow"
        or not reserve_icon or reserve_icon.sprite ~= "utility/status_yellow"
        or find_gui_element(content, "warp_drive_warp_status")
        or find_gui_element(content, "warp_drive_warp_charge_progress")
        or not alert or alert.style.height ~= 76
        or not alert_header or alert_header.style.vertical_align ~= "center"
        or not alert_sprite or alert_sprite.parent ~= alert_header
        or alert_sprite.sprite ~= "utility/status_yellow"
        or not alert_text or alert_text.parent ~= alert_header
        or type(alert_text.caption) ~= "table"
        or alert_text.style.name ~= "orange_label"
        or alert_text.caption[1] ~= "warp-drive.charging-status"
        or not alert_boost or alert_boost.visible
        or not charge_progress or not charge_progress.visible
        or math.abs(charge_progress.value - charge_ratio) > 0.001
        or type(charge_progress.caption) ~= "table"
        or charge_progress.caption[1] ~= "warp-drive.percent-value"
        or charge_progress.caption[2] ~= math.floor(charge_ratio * 100)
        or not alert_speed or not alert_speed.visible
        or type(alert_speed.caption) ~= "table"
        or alert_speed.caption[1] ~= "warp-drive.charging-remaining" then
        fail("GUI did not report charging progress in the top status")
      end
    end
    local charge = charge_buffers(platform)
    local required_charge = platform.weight * 100
    if #charge ~= 1 or reserve_energy(platform) <= 0 or reserve_energy(platform) >= required_charge then
      fail("available ship power did not visibly charge the warp support reserve")
    end
    set_reserve_energy(platform, required_charge)
    storage.power_source.power_production = 60e9 / 60
    storage.power_source.output_flow_limit = 60e9 / 60
  elseif phase == "post_warp_lockout" and elapsed == 930 then
    local support = charge_buffers(platform)
    if #support ~= 1 then
      fail("drive did not re-enter warp after the lockout")
    end
    local sound = sound_state(platform)
    if sound.charge_next_tick ~= nil or sound.charge_step ~= nil
        or sound.background_index ~= 1
        or not sound.warp_next_tick
        or sound.warp_next_tick <= game.tick
        or sound.warp_next_tick > game.tick + 90 then
      fail("warp activation did not replace charging audio and schedule its background handoff")
    end
    game.forces.player.technologies["practical-warp-drive"].researched = false
    set_phase("circuit_and_revocation")
  elseif phase == "circuit_and_revocation" and elapsed == 10 then
    local support = charge_buffers(platform)
    local charge = charge_buffers(platform)
    if #support ~= 1 or #charge ~= 1 or reserve_energy(platform) ~= 0 then
      fail("power interface was not reconfigured for experimental research")
    end
    local input = platform.surface.create_entity({
      name = "constant-combinator",
      position = {7, 8},
      force = game.forces.player
    })
    local drive_connector = drive.get_wire_connector(
      defines.wire_connector_id.circuit_green, true)
    local input_connector = input
      and input.get_wire_connector(defines.wire_connector_id.circuit_green, true)
    if not input or not drive_connector or not input_connector
      or not drive_connector.connect_to(input_connector, false) then
      fail("could not create the circuit-condition input")
    end
    local section = input.get_or_create_control_behavior().add_section()
    storage.circuit_input = input
    storage.circuit_section = section
    local player = game.players[1]
    if player then
      player.opened = drive
    end
  elseif phase == "circuit_and_revocation" and elapsed == 20 then
    local player = game.players[1]
    if player then
      local frame = player.gui.screen.warp_drive_window
      local green_network = find_gui_element(frame, "warp_drive_circuit_green_network")
      local tooltip = green_network and green_network.tooltip
      if type(green_network.caption) ~= "table"
        or green_network.caption[1] ~= "warp-drive.circuit-network-connected"
        or #green_network.caption ~= 4
        or type(tooltip) ~= "table" or #tooltip ~= 2
        or type(tooltip[2]) ~= "table"
        or tooltip[2][1] ~= "warp-drive.circuit-network-tooltip-heading" then
        fail("empty circuit network reported a signal count")
      end
      storage.circuit_section.set_slot(1, {
        value = {type = "virtual", name = "signal-A", quality = "normal"},
        min = 7
      })
      storage.circuit_section.set_slot(2, {
        value = {type = "virtual", name = "signal-B", quality = "normal"},
        min = 5
      })
      platform.distance = 0.01
      configure_circuit_condition(player,
        {type = "virtual", name = "signal-A"}, 1,
        {type = "virtual", name = "signal-B"}, 0)
    end
  elseif phase == "circuit_and_revocation" and elapsed == 30 then
    local player = game.players[1]
    if player then
      local state = find_gui_element(player.gui.screen.warp_drive_window,
        "warp_drive_circuit_state")
      local state_icon = find_gui_element(state, "warp_drive_circuit_state_icon")
      local state_label = find_gui_element(state, "warp_drive_circuit_state_label")
      local control = find_gui_element(player.gui.screen.warp_drive_window,
        "warp_drive_requirement_control").caption
      local clearance = find_gui_element(player.gui.screen.warp_drive_window,
        "warp_drive_requirement_clearance").caption
      local green_network = find_gui_element(player.gui.screen.warp_drive_window,
        "warp_drive_circuit_green_network")
      local tooltip = green_network and green_network.tooltip
      local signal_text = tooltip and tooltip[#tooltip]
      if not state or not state.visible
        or not state_icon or state_icon.sprite ~= "utility/status_working"
        or not state_label or type(state_label.caption) ~= "table"
        or state_label.caption[1] ~= "warp-drive.circuit-condition-active"
        or state_label.style.name ~= "green_label"
        or type(control) ~= "table"
        or control[1] ~= "warp-drive.requirement-control-circuit-active"
        or type(clearance) ~= "table"
        or clearance[1] ~= "warp-drive.requirement-clearance-blocked"
        or type(clearance[3]) ~= "table"
        or not string.find(clearance[3][2], "[planet=nauvis]", 1, true)
        or type(green_network.caption) ~= "table"
        or green_network.caption[1] ~= "warp-drive.circuit-network-connected-signals"
        or green_network.caption[4] ~= 1 or green_network.caption[5] < 2
        or type(tooltip) ~= "table" or tooltip[1] ~= ""
        or type(tooltip[2]) ~= "table"
        or tooltip[2][1] ~= "warp-drive.circuit-network-tooltip-heading-signals"
        or tooltip[2][5] < 2
        or type(signal_text) ~= "string"
        or not string.find(signal_text, "[virtual-signal=signal-A]", 1, true) then
        fail("signal-to-signal circuit condition A > B was not satisfied")
      end
      platform.distance = 0.51
      configure_circuit_condition(player,
        {type = "virtual", name = "signal-A"}, 2, nil, 8)
    end
    set_phase("relocation")
  elseif phase == "relocation" and elapsed == 10 then
    local player = game.players[1]
    if player then
      local frame = player.gui.screen.warp_drive_window
      local first = find_gui_element(frame, "warp_drive_circuit_first_signal")
      local comparator = find_gui_element(frame, "warp_drive_circuit_comparator")
      local second = find_gui_element(frame, "warp_drive_circuit_second_signal")
      local threshold = find_gui_element(frame, "warp_drive_circuit_constant")
      local state = find_gui_element(player.gui.screen.warp_drive_window,
        "warp_drive_circuit_state")
      if first.elem_value.name ~= "signal-A" or comparator.selected_index ~= 2
        or second.elem_value ~= nil or not threshold.visible or threshold.text ~= "8"
        or not state or not state.visible then
        fail("signal-to-constant circuit condition A < 8 was not satisfied")
      end
    end
    drive.destroy()
    local orphan = platform.surface.create_entity({
      name = "warp-drive-animation",
      position = {-8, 8},
      force = game.forces.player
    })
    local duplicate_orphan = platform.surface.create_entity({
      name = "warp-drive-animation",
      position = {-8, 8},
      force = game.forces.player
    })
    local stray_output = platform.surface.create_entity({
      name = "warp-drive-circuit-output",
      position = {8, 8},
      force = game.forces.player
    })
    if not orphan or not duplicate_orphan or not stray_output then
      fail("could not create orphan companion fixtures")
    end
    storage.orphan_animations = {orphan, duplicate_orphan}
    storage.drive = platform.surface.create_entity({
      name = "warp-drive-controller",
      position = {-8, 8},
      force = game.forces.player,
      raise_built = true
    })
    if not storage.drive then
      fail("replacement drive creation returned nil")
    end
  elseif phase == "relocation" and elapsed == 20 then
    local companion_names = {
      "warp-drive-animation",
      POWER_INTERFACE_NAME,
      "warp-drive-circuit-output"
    }
    for _, name in pairs(companion_names) do
      local companions = platform.surface.find_entities_filtered({name = name})
      if #companions ~= 1 or companions[1].position.x ~= -8 or companions[1].position.y ~= 8 then
        fail(name .. " was not moved with the replacement drive")
      end
    end
    local surviving_orphans = 0
    for _, orphan in pairs(storage.orphan_animations) do
      if orphan.valid then
        surviving_orphans = surviving_orphans + 1
      end
    end
    if surviving_orphans ~= 1 then
      fail("replacement drive did not adopt exactly one existing animation companion")
    end
    local stray_outputs = platform.surface.find_entities_filtered({
      name = "warp-drive-circuit-output",
      position = {8, 8}
    })
    if #stray_outputs ~= 0 then
      fail("orphan circuit output survived companion recovery")
    end
    if not platform.surface.can_place_entity({
      name = "warp-drive-controller",
      position = {0, 8},
      force = game.forces.player
    }) then
      fail("hidden companion blocked rebuilding at the old drive position")
    end
  elseif phase == "relocation" and elapsed == 30 then
    log("WARP_TEST_PASS: detector, duplicate, warp visuals, asteroid suppression, ramp, speed grace, reserve, warnings, lockout, circuit condition, revocation, and relocation paths completed")
    set_phase("complete")
  end
end)
