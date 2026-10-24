local Drive = require("__bte-warp-drive__/scripts/drive")
local Gui = require("__bte-warp-drive__/scripts/gui")
local Research = require("__bte-warp-drive__/scripts/research")
local Warp = require("__bte-warp-drive__/scripts/warp")

local POWER_INTERFACE_NAME = "bte-warp-drive-power-interface"
local SHIP_LOAD_NAME = "bte-warp-drive-test-ship-load"

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
  remote.call("aaa-bte-warp-drive-speed-test", "set_phase", name)
end

local function phase_elapsed()
  return game.tick - storage.runtime_test.started_at
end

local function circuit_signal(name)
  local platform = storage.platform
  local output = platform.surface.find_entities_filtered({name = "bte-warp-drive-circuit-output"})[1]
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
  return remote.call("bte-warp-drive-runtime-test", "reserve_energy", platform.index)
end

local function set_reserve_energy(platform, energy)
  remote.call("bte-warp-drive-runtime-test", "reserve_energy", platform.index, energy)
end

-- The drive-core overlay animations drawn on `entity`, sorted and comma-joined.
local function overlay_names(entity)
  local names = {}
  for _, object in pairs(rendering.get_all_objects("bte-warp-drive")) do
    if object.type == "animation" and object.target.entity == entity then
      names[#names + 1] = object.animation
    end
  end
  table.sort(names)
  return table.concat(names, ",")
end

-- Warp lightning strikes only around the drive: every bolt (25 tiles south of its cloud at the
-- entity position) lands within 10 tiles of it, never in open space.
local function check_lightning_placement(platform)
  local drive = storage.drive.position
  for _, lightning in pairs(platform.surface.find_entities_filtered({type = "lightning"})) do
    local p = lightning.position
    local dx, dy = p.x - drive.x, p.y + 25 - drive.y
    if lightning.name ~= "bte-warp-drive-lightning" then
      fail("unexpected lightning during warp: " .. lightning.name)
    elseif dx * dx + dy * dy > 10.01 * 10.01 then
      fail(string.format("warp lightning struck away from the drive: x=%s y=%s", p.x, p.y))
    end
  end
end

local function field_hums(platform)
  return #platform.surface.find_entities_filtered({name = "bte-warp-drive-field-hum"})
end

local function sound_state(platform)
  return remote.call("bte-warp-drive-runtime-test", "sound_state", platform.index)
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

local function assert_research_gui_snapshot(frame, record)
  local snapshot = Research.snapshot(record)
  local branch = frame and find_gui_element(frame, "bte_warp_drive_research_branch")
  local bonus = frame and find_gui_element(frame, "bte_warp_drive_research_bonus")
  if not snapshot or not branch or type(branch.caption) ~= "table"
      or branch.caption[1] ~= "bte-warp-drive.branch-" .. snapshot.branch then
    fail("research GUI branch did not match its module snapshot")
  end
  if not bonus or type(bonus.caption) ~= "table"
      or bonus.caption[1] ~= "bte-warp-drive.research-rate-value"
      or bonus.caption[2] ~= string.format("%.2f", snapshot.bonus_rate) then
    fail("research GUI bonus estimate did not match its module snapshot")
  end
end

local A_SIGNAL = {type = "virtual", name = "signal-A"}
local B_SIGNAL = {type = "virtual", name = "signal-B"}

-- Drive tags with the default outputs and the given conditions, keyed activate, deactivate,
-- detector_start, and detector_stop; omitted conditions are disabled.
local function drive_tags(conditions)
  conditions = conditions or {}
  return {
    bte_warp_drive_activate = conditions.activate or {enabled = false},
    bte_warp_drive_deactivate = conditions.deactivate or {enabled = false},
    bte_warp_drive_detector_start = conditions.detector_start or {enabled = false},
    bte_warp_drive_detector_stop = conditions.detector_stop or {enabled = false},
    bte_warp_drive_output_warp_enabled = true,
    bte_warp_drive_output_warp_signal = {type = "virtual", name = "signal-W"},
    bte_warp_drive_output_distance_enabled = true,
    bte_warp_drive_output_distance_signal = {type = "virtual", name = "signal-D"},
    bte_warp_drive_output_charge_enabled = true,
    bte_warp_drive_output_charge_signal = {type = "virtual", name = "signal-C"},
    bte_warp_drive_output_speed_enabled = true,
    bte_warp_drive_output_speed_signal = {type = "virtual", name = "signal-S"},
    bte_warp_drive_output_tachyon_density_enabled = true,
    bte_warp_drive_output_tachyon_density_signal = {type = "virtual", name = "signal-T"}
  }
end

local function settings_test_tags()
  return {
    bte_warp_drive_activate = {enabled = true, first_signal = A_SIGNAL, comparator = "≤",
      second_signal = B_SIGNAL, constant = 73},
    bte_warp_drive_deactivate = {enabled = false, first_signal = B_SIGNAL, comparator = "=",
      constant = -5},
    bte_warp_drive_output_warp_enabled = false,
    bte_warp_drive_output_warp_signal = {type = "virtual", name = "signal-Z"},
    bte_warp_drive_output_distance_enabled = true,
    bte_warp_drive_output_distance_signal = {type = "virtual", name = "signal-D"},
    bte_warp_drive_output_charge_enabled = false,
    bte_warp_drive_output_charge_signal = {type = "virtual", name = "signal-C"},
    bte_warp_drive_output_speed_enabled = true,
    bte_warp_drive_output_speed_signal = {type = "virtual", name = "signal-S"},
    bte_warp_drive_output_tachyon_density_enabled = false,
    bte_warp_drive_output_tachyon_density_signal = {type = "virtual", name = "signal-T"}
  }
end

-- Sets the drive's circuit conditions the way a blueprint or settings paste does.
local function configure_conditions(conditions)
  script.raise_script_revive({entity = storage.drive, tags = drive_tags(conditions)})
end

local function engage(platform)
  if not remote.call("bte-warp-drive-runtime-test", "engage", platform.index) then
    fail("the Engage button was refused although the drive was ready")
  end
end

-- Reopens the drive window so it shows freshly configured conditions.
local function reopen_gui(player)
  local frame = player.gui.screen.bte_warp_drive_window
  if frame then
    frame.destroy()
  end
  player.opened = storage.drive
end

script.on_init(function()
  if not helpers.is_valid_sprite_path(Gui.TITLE_SPRITE) then
    fail("drive window title sprite " .. Gui.TITLE_SPRITE .. " does not exist")
  end
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
  for x = -16, 16 do
    for y = -16, 16 do
      tiles[#tiles + 1] = {name = "space-platform-foundation", position = {x, y}}
    end
  end
  platform.surface.set_tiles(tiles)

  local source = platform.surface.create_entity({
    name = "bte-warp-drive-test-power-source",
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
    position = {6, 4},
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
    name = "bte-warp-drive-controller",
    position = {0.5, 9.5},
    force = force,
    raise_built = true
  })
  if not drive then
    fail("drive creation returned nil")
  end
  local duplicate = platform.surface.create_entity({
    name = "bte-warp-drive-controller",
    position = {10.5, 9.5},
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
    if item.stack and item.stack.valid_for_read and item.stack.name == "bte-warp-drive" then
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
  for x = -16, 16 do
    for y = -16, 16 do
      settings_tiles[#settings_tiles + 1] = {
        name = "space-platform-foundation",
        position = {x, y}
      }
    end
  end
  settings_platform.surface.set_tiles(settings_tiles)
  local settings_drive = settings_platform.surface.create_entity({
    name = "bte-warp-drive-controller",
    position = {0.5, 9.5},
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
    area = {{-4, 5}, {5, 14}}
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
  if not blueprint_tags or not blueprint_tags.bte_warp_drive_activate
      or blueprint_tags.bte_warp_drive_activate.comparator ~= "≤"
      or blueprint_tags.bte_warp_drive_activate.constant ~= 73
      or blueprint_tags.bte_warp_drive_deactivate.comparator ~= "="
      or blueprint_tags.bte_warp_drive_deactivate.enabled ~= false
      or blueprint_tags.bte_warp_drive_output_warp_enabled ~= false
      or blueprint_tags.bte_warp_drive_output_tachyon_density_signal.name ~= "signal-T"
      or blueprint_tags.bte_warp_drive_output_detector_power_signal ~= nil then
    fail("blueprint did not serialize the complete drive configuration")
  end
  local ghosts = blueprint.build_blueprint({
    surface = settings_platform.surface,
    force = force,
    position = {0.5, -9.5}
  })
  local blueprint_ghost
  for _, ghost in pairs(ghosts) do
    if ghost.valid and ghost.ghost_name == "bte-warp-drive-controller" then
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

script.on_event(defines.events.on_tick, function()
  local test = storage.runtime_test
  if test and test.stray_tick and game.tick == test.stray_tick + 1 then
    if test.stray_asteroid.valid then
      fail("an asteroid spawned during warp survived into the next tick")
    end
    test.stray_asteroid = nil
    test.stray_tick = nil
  end
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
    script.raise_script_revive({entity = drive, tags = drive_tags()})
    local detector = platform.surface.find_entities_filtered({name = POWER_INTERFACE_NAME})
    if #detector ~= 1 then
      fail("expected one experimental detector")
    end
    local player = game.players[1]
    if player then
      local frame = player.gui.screen.add({type = "frame", name = "bte_warp_drive_scroll_test"})
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
    if player and not player.gui.screen.bte_warp_drive_window then
      fail("opening the Warp Drive did not create its GUI")
    end
    if player then
      local frame = player.gui.screen.bte_warp_drive_window
      local tabs = find_gui_element(frame, "bte_warp_drive_tabs")
      local status_text = find_gui_element(frame, "bte_warp_drive_status_text")
      local route = find_gui_element(frame, "bte_warp_drive_route")
      local warp_locked = find_gui_element(frame, "bte_warp_drive_warp_locked")
      local requirements = find_gui_element(frame, "bte_warp_drive_requirements")
      local circuit_state = find_gui_element(frame, "bte_warp_drive_detector_start_state")
      local activate = find_gui_element(frame, "bte_warp_drive_detector_start_enabled")
      local deactivate = find_gui_element(frame, "bte_warp_drive_detector_stop_enabled")
      local warp_activate = find_gui_element(frame, "bte_warp_drive_activate_header")
      local start = find_gui_element(frame, "bte_warp_drive_engage")
      local stop = find_gui_element(frame, "bte_warp_drive_disengage")
      local boost_controls = find_gui_element(frame, "bte_warp_drive_boost_controls")
      local warp_output = find_gui_element(frame, "bte_warp_drive_output_warp_enabled")
      local distance_output = find_gui_element(frame, "bte_warp_drive_output_distance_enabled")
      local charge_output = find_gui_element(frame, "bte_warp_drive_output_charge_enabled")
      local speed_output = find_gui_element(frame, "bte_warp_drive_output_speed_enabled")
      local density_output = find_gui_element(frame,
        "bte_warp_drive_output_tachyon_density_enabled")
      if not tabs or tabs.selected_tab_index ~= 2
        or not status_text or (status_text.caption[1] ~= "bte-warp-drive.header-detecting"
          and status_text.caption[1] ~= "bte-warp-drive.header-detector-no-power")
        or not route or route.caption[1] ~= "bte-warp-drive.location-transit-distance"
        or not warp_locked or not warp_locked.visible
        or not requirements or requirements.visible
        or not circuit_state or circuit_state.sprite ~= "utility/status_inactive"
        or not activate or activate.state
        or type(activate.caption) ~= "table"
        or activate.caption[1] ~= "bte-warp-drive.research-detector-start-condition"
        or not warp_activate or warp_activate.visible
        or not deactivate or deactivate.state
        or type(deactivate.caption) ~= "table"
        or deactivate.caption[1] ~= "bte-warp-drive.research-detector-stop-condition"
        or not start or start.enabled or start.caption[1] ~= "bte-warp-drive.start-detector"
        or not stop or not stop.enabled or stop.caption[1] ~= "bte-warp-drive.stop-detector"
        or not boost_controls or boost_controls.visible
        or not warp_output or warp_output.parent.visible
        or not distance_output or distance_output.parent.visible
        or not charge_output or charge_output.parent.visible
        or not speed_output or speed_output.parent.visible
        or not density_output or not density_output.parent.visible then
        fail("research GUI did not open on the detector tab with research-mode controls")
      end
      local platform_record = Drive.get(platform.index)
      assert_research_gui_snapshot(frame, platform_record)
      local default_first = find_gui_element(frame, "bte_warp_drive_activate_first_signal")
      if platform_record.activate.first_signal ~= nil
          or not default_first or default_first.elem_value ~= nil then
        fail("new drive preselected a circuit engagement signal")
      end
      local requirement_rows = {
        "bte_warp_drive_requirement_travel",
        "bte_warp_drive_requirement_clearance", "bte_warp_drive_requirement_cooldown",
        "bte_warp_drive_requirement_speed", "bte_warp_drive_requirement_power",
        "bte_warp_drive_requirement_acceleration"
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
      local settings_frame = player.gui.screen.bte_warp_drive_window
      local activate = settings_frame and find_gui_element(settings_frame,
        "bte_warp_drive_activate_enabled")
      local deactivate = settings_frame and find_gui_element(settings_frame,
        "bte_warp_drive_deactivate_enabled")
      local first = settings_frame and find_gui_element(settings_frame,
        "bte_warp_drive_activate_first_signal")
      local comparator = settings_frame and find_gui_element(settings_frame,
        "bte_warp_drive_activate_comparator")
      local second = settings_frame and find_gui_element(settings_frame,
        "bte_warp_drive_activate_second_signal")
      local constant = settings_frame and find_gui_element(settings_frame,
        "bte_warp_drive_activate_constant")
      local warp_toggle = settings_frame and find_gui_element(settings_frame,
        "bte_warp_drive_output_warp_enabled")
      local warp_signal = settings_frame and find_gui_element(settings_frame,
        "bte_warp_drive_output_warp_signal")
      local distance_toggle = settings_frame and find_gui_element(settings_frame,
        "bte_warp_drive_output_distance_enabled")
      local distance_signal = settings_frame and find_gui_element(settings_frame,
        "bte_warp_drive_output_distance_signal")
      local charge_toggle = settings_frame and find_gui_element(settings_frame,
        "bte_warp_drive_output_charge_enabled")
      local charge_signal = settings_frame and find_gui_element(settings_frame,
        "bte_warp_drive_output_charge_signal")
      local speed_toggle = settings_frame and find_gui_element(settings_frame,
        "bte_warp_drive_output_speed_enabled")
      local speed_signal = settings_frame and find_gui_element(settings_frame,
        "bte_warp_drive_output_speed_signal")
      local density_toggle = settings_frame and find_gui_element(settings_frame,
        "bte_warp_drive_output_tachyon_density_enabled")
      local density_signal = settings_frame and find_gui_element(settings_frame,
        "bte_warp_drive_output_tachyon_density_signal")
      local settings_record = Drive.get(settings_platform.index)
      assert_research_gui_snapshot(settings_frame, settings_record)
      if Research.branch(platform.surface) == Research.branch(settings_platform.surface) then
        fail("differently configured platform surfaces selected the same research branch")
      end
      if not activate or not activate.state or not deactivate or deactivate.state
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
          or not settings_record.activate.enabled or settings_record.deactivate.enabled then
        fail("output toggle changed drive engagement")
      end
      deactivate.state = true
      Gui.handlers.on_gui_checked_state_changed({
        player_index = player.index,
        element = deactivate
      })
      if not settings_record.deactivate.enabled or not settings_record.activate.enabled then
        fail("enabling the deactivate condition changed the activate condition")
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
      if settings_record.activate.first_signal ~= nil
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
      if settings_record.activate.comparator ~= "≠" then
        fail("comparator selection did not map to the stored operator")
      end
      constant.text = "2147483648"
      Gui.handlers.on_gui_text_changed({
        player_index = player.index,
        element = constant
      })
      if settings_record.activate.constant ~= 2147483647 then
        fail("circuit constant text was not clamped to int32")
      end
      constant.text = "-2147483649"
      Gui.handlers.on_gui_confirmed({
        player_index = player.index,
        element = constant
      })
      if settings_record.activate.constant ~= -2147483648
          or constant.text ~= "-2147483648" then
        fail("confirmed circuit constant was not clamped and normalized")
      end
      Gui.handlers.on_display_changed({player_index = player.index})
      local page = find_gui_element(settings_frame, "bte_warp_drive_warp_page")
      local expected_height = math.max(240, math.min(440,
        player.display_resolution.height / player.display_scale - 360))
      if not page or page.style.maximal_height ~= expected_height then
        fail("display change did not update GUI height")
      end
      local close = find_gui_element(settings_frame, "bte_warp_drive_close")
      Gui.handlers.on_gui_click({player_index = player.index, element = close})
      if player.gui.screen.bte_warp_drive_window then
        fail("close handler did not destroy the Warp Drive GUI")
      end
      player.opened = drive
      local closed = player.gui.screen.bte_warp_drive_window
      Gui.handlers.on_gui_closed({player_index = player.index, element = closed})
      if player.gui.screen.bte_warp_drive_window then
        fail("GUI-closed handler did not destroy the Warp Drive GUI")
      end
      player.opened = drive
      local stale = player.gui.screen.bte_warp_drive_window
      local stale_route = stale and find_gui_element(stale, "bte_warp_drive_route")
      if not stale_route then
        fail("could not create the stale GUI fixture")
      end
      stale_route.destroy()
    end
  elseif phase == "detector_gui" and elapsed == 30 then
    if circuit_signal("signal-D") ~= nil
        or circuit_signal("signal-T") ~= math.floor(Research.tachyon_density(platform)) then
      fail("research mode did not suppress distance while reading tachyon density")
    end
    if not remote.call("bte-warp-drive-runtime-test", "disengage", platform.index)
        or remote.call("bte-warp-drive-runtime-test", "disengage", platform.index) then
      fail("Stop did not switch the running detector off exactly once")
    end
  elseif phase == "detector_gui" and elapsed == 40 then
    local detector = charge_buffer(platform)
    if not detector or detector.power_usage ~= 0 then
      fail("Stop did not disable detector demand")
    end
    -- A start condition without a signal is incomplete and never true.
    configure_conditions({detector_start = {enabled = true, comparator = ">", constant = 0}})
  elseif phase == "detector_gui" and elapsed == 50 then
    local detector = charge_buffer(platform)
    if not detector or detector.power_usage ~= 0 then
      fail("an incomplete start condition did not keep detection off")
    end
    configure_conditions()
    engage(platform)
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
    local overlays = overlay_names(drive)
    if overlays ~= "bte-warp-drive-detecting-glow,bte-warp-drive-detecting-interior" then
      fail("powered tachyon detection did not show the detecting overlays: " .. overlays)
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
    remote.call("bte-warp-drive-runtime-test", "disengage", platform.index)
    game.forces.player.technologies["bte-practical-warp-drive"].researched = true
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
    local support = platform.surface.find_entities_filtered({name = "bte-warp-drive-support-load"})
    if #support ~= 0 then
      fail("legacy support interface survived migration")
    end
    local output = platform.surface.find_entities_filtered({name = "bte-warp-drive-circuit-output"})
    if #output ~= 1 then
      fail("expected one circuit output companion")
    end
    local animation = platform.surface.find_entities_filtered({name = "bte-warp-drive-animation"})
    if #animation ~= 1 then
      fail("expected one animation companion")
    end
    script.raise_script_revive({entity = drive, tags = drive_tags()})
    -- Keep unrelated platform accumulators from affecting the controlled generation used by
    -- acceleration assertions. A later test adds an explicit ordinary secondary-input load.
    for _, accumulator in pairs(platform.surface.find_entities_filtered({type = "accumulator"})) do
      accumulator.energy = accumulator.electric_buffer_size
    end
    local asteroid = platform.surface.create_entity({
      name = "small-metallic-asteroid",
      position = {0.5, -30},
      velocity = {0, 0}
    })
    if not asteroid then
      fail("could not create an asteroid for warp suppression testing")
    end
    storage.runtime_test.warp_asteroid = asteroid
    platform.create_asteroid_chunks({{
      name = "metallic-asteroid-chunk",
      position = {0.5, -30},
      movement = {0, 0}
    }})
    platform.distance = 0.51
    platform.speed = 50 / 60
    platform.paused = false
    -- Engage starts charging at once; a full reserve then enters warp at the next update.
    engage(platform)
    if sound_state(platform).state ~= "charging" then
      fail("Engage did not start charging immediately")
    end
    set_reserve_energy(platform, required_charge)
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
    -- The activation shockwave, sent 30 ticks after entry, sweeps asteroids away; until it
    -- reaches them they stay.
    if not storage.runtime_test.warp_asteroid.valid
      or #platform.find_asteroid_chunks_filtered({area = {{-0.5, -31}, {1.5, -29}}}) ~= 1 then
      fail("warp entry removed asteroids before the activation shockwave reached them")
    end
    check_lightning_placement(platform)
    local overlays = overlay_names(storage.drive)
    if overlays ~= "bte-warp-drive-activation-glow,bte-warp-drive-activation-interior" then
      fail("warp entry did not start the activation pulse overlays: " .. overlays)
    end
    if circuit_signal("signal-W") ~= 1 then
      fail("circuit output did not report active warp")
    end
    local speed = circuit_signal("signal-S")
    if speed ~= 500 then
      fail("circuit speed output was " .. tostring(speed) .. ", expected 500 km/s at Warp-1")
    end
  elseif phase == "warp_ramp" and elapsed >= 20 and elapsed <= 560 then
    if sound_state(platform).shockwaves > 0 then
      storage.runtime_test.shockwave_seen = true
    end
    local swept = storage.runtime_test.warp_asteroid
    if swept and not swept.valid then
      -- Warp entry is at elapsed 10. The rings leave 30 ticks later at the building's 4.5-tile
      -- edge and grow 2.4 tiles per tick. The asteroid and chunk sit 39.5 tiles ahead of the
      -- drive, 50.6 tiles along the ring's oval (0.78 deep), so the front reaches them about 19
      -- ticks after that, at elapsed 60.
      if elapsed < 50 or elapsed > 70
          or #platform.find_asteroid_chunks_filtered({area = {{-0.5, -31}, {1.5, -29}}}) ~= 0 then
        fail("the activation shockwave did not sweep the asteroid and chunk as it reached them: "
          .. "elapsed " .. elapsed)
      end
      storage.runtime_test.warp_asteroid = nil
    elseif swept and elapsed > 70 then
      fail("the activation shockwave did not sweep the asteroid in its path")
    end
    -- After the sweep, asteroids spawned during warp must go on the next tick, not wait for the
    -- 10-tick update; the on_tick handler checks it.
    if elapsed == 520 then
      storage.runtime_test.stray_asteroid = platform.surface.create_entity({
        name = "small-metallic-asteroid",
        position = {10, -40},
        velocity = {0, 0}
      })
      storage.runtime_test.stray_tick = game.tick
    end
    if elapsed == 200 then
      local overlays = overlay_names(storage.drive)
      if overlays ~= "bte-warp-drive-warp-glow,bte-warp-drive-warp-interior" then
        fail("activation overlays did not hand off to the warp overlays: " .. overlays)
      end
      if field_hums(platform) ~= 1 then
        fail("warp did not create exactly one positional field hum companion")
      end
      if sound_state(platform).shockwaves_sent ~= 2 then
        fail("warp activation did not send both ship-wide shockwaves")
      end
      if not storage.runtime_test.shockwave_seen or sound_state(platform).shockwaves ~= 0 then
        fail("activation shockwaves were not drawn, or their rings were not cleaned up")
      end
      -- The small test platform's field, 128 tiles beyond it on every side, holds about 64.
      if sound_state(platform).anomalies < 50 then
        fail("warp did not fill the field with background anomalies: "
          .. sound_state(platform).anomalies)
      end
      check_lightning_placement(platform)
      local sound = sound_state(platform)
      if sound.background_index ~= 1
          or sound.warp_next_tick ~= storage.runtime_test.started_at + 310 then
        fail("warp background segment 01 was not scheduled for the end of the 5-second activation")
      end
    elseif elapsed == 560 then
      local sound = sound_state(platform)
      if sound.background_index ~= 2
          or sound.warp_next_tick ~= storage.runtime_test.started_at + 670 then
        fail("activation did not hand off to background segment 01, then schedule segment 02")
      end
    end
    if elapsed == 30 then
      local player = game.players[1]
      if player then
        local frame = player.gui.screen.bte_warp_drive_window
        local function caption(name)
          local element = find_gui_element(frame, name)
          return element and type(element.caption) == "table" and element.caption[1]
        end
        local function visible(name)
          local element = find_gui_element(frame, name)
          return element and element.visible
        end
        local engage_button = find_gui_element(frame, "bte_warp_drive_engage")
        local disengage_button = find_gui_element(frame, "bte_warp_drive_disengage")
        local destination = find_gui_element(frame, "bte_warp_drive_requirement_travel")
        local acceleration_icon = find_gui_element(frame, "bte_warp_drive_requirement_acceleration_icon")
        local density_signal = find_gui_element(frame, "bte_warp_drive_output_tachyon_density_signal")
        if caption("bte_warp_drive_status_text") ~= "bte-warp-drive.active-warp-level"
          or caption("bte_warp_drive_status_detail") ~= "bte-warp-drive.header-warp-detail"
          or visible("bte_warp_drive_status_progress")
          or caption("bte_warp_drive_route") ~= "bte-warp-drive.location-transit-distance"
          or not engage_button or engage_button.enabled
          or engage_button.caption[1] ~= "bte-warp-drive.engage"
          or engage_button.tooltip[1] ~= "bte-warp-drive.engage-blocked-warp"
          or not disengage_button or not disengage_button.enabled
          or disengage_button.caption[1] ~= "bte-warp-drive.disengage"
          or caption("bte_warp_drive_tab_detector") ~= "bte-warp-drive.tab-boost"
          or visible("bte_warp_drive_warp_locked") or not visible("bte_warp_drive_requirements")
          or not visible("bte_warp_drive_field") or visible("bte_warp_drive_field_idle")
          or caption("bte_warp_drive_reserve") ~= "bte-warp-drive.charge-value"
          or caption("bte_warp_drive_requirement_power") ~= "bte-warp-drive.field-power"
          or caption("bte_warp_drive_reserve_detail") ~= "bte-warp-drive.field-outage"
          or caption("bte_warp_drive_warp_level") ~= "bte-warp-drive.field-warp-level"
          or caption("bte_warp_drive_requirement_acceleration") ~= "bte-warp-drive.ramp-accelerating"
          or not acceleration_icon or acceleration_icon.sprite ~= "utility/check_mark_green"
          or caption("bte_warp_drive_requirement_clearance") ~= "bte-warp-drive.requirement-clearance-clear"
          or caption("bte_warp_drive_requirement_speed") ~= "bte-warp-drive.requirement-speed-value"
          or not destination or not string.find(destination.caption[2],
            "[space-location=shattered-planet]", 1, true)
          or caption("bte_warp_drive_activate_enabled") ~= "bte-warp-drive.activate-condition"
          or caption("bte_warp_drive_deactivate_enabled") ~= "bte-warp-drive.deactivate-condition"
          or caption("bte_warp_drive_detector_start_enabled") ~= "bte-warp-drive.detector-start-condition"
          or not visible("bte_warp_drive_boost_controls")
          or caption("bte_warp_drive_circuit_red_network") ~= "bte-warp-drive.circuit-network-disconnected"
          or not visible("bte_warp_drive_output_distance_enabled_row")
          or not density_signal or density_signal.elem_value.name ~= "signal-T" then
          fail("practical GUI did not show warp in the header and the warp field on the Warp tab")
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
      local frame = player.gui.screen.bte_warp_drive_window
      local acceleration = find_gui_element(frame, "bte_warp_drive_requirement_acceleration")
      local icon = find_gui_element(frame, "bte_warp_drive_requirement_acceleration_icon")
      if not acceleration or type(acceleration.caption) ~= "table"
        or acceleration.caption[1] ~= "bte-warp-drive.ramp-engine-limited"
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
    if distance ~= expected_distance or detector ~= nil
        or density ~= math.floor(Research.tachyon_density(platform)) or level ~= 2 then
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
      local frame = player.gui.screen.bte_warp_drive_window
      local speed_icon = find_gui_element(frame, "bte_warp_drive_requirement_speed_icon")
      local speed_label = find_gui_element(frame, "bte_warp_drive_requirement_speed_label")
      local speed = find_gui_element(frame, "bte_warp_drive_requirement_speed")
      local status_icon = find_gui_element(frame, "bte_warp_drive_status_icon")
      local status_text = find_gui_element(frame, "bte_warp_drive_status_text")
      local status_detail = find_gui_element(frame, "bte_warp_drive_status_detail")
      if not speed_icon or speed_icon.sprite ~= "utility/status_yellow"
        or not speed_label or speed_label.style.name ~= "orange_label"
        or not speed or type(speed.caption) ~= "table"
        or speed.caption[1] ~= "bte-warp-drive.requirement-speed-warning"
        or not status_icon or status_icon.sprite ~= "utility/status_yellow"
        or not status_text or status_text.caption[1] ~= "bte-warp-drive.active-warp-level"
        or not status_detail
        or status_detail.caption[1] ~= "bte-warp-drive.requirement-speed-warning" then
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
    if player and player.gui.screen.bte_warp_drive_window then
      local frame = player.gui.screen.bte_warp_drive_window
      local status_text = find_gui_element(frame, "bte_warp_drive_status_text")
      local reason = find_gui_element(frame, "bte_warp_drive_status_detail")
      if not status_text or type(status_text.caption) ~= "table"
        or status_text.caption[1] ~= "bte-warp-drive.header-lockout"
        or not reason or type(reason.caption) ~= "table"
        or reason.caption[1] ~= "bte-warp-drive.last-deactivation-reason"
        or type(reason.caption[2]) ~= "table"
        or reason.caption[2][1] ~= "bte-warp-drive.deactivation-reason-insufficient-speed" then
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
    -- The Tachyon Science Boost may be switched on at any time, but it waits out the lockout.
    if not remote.call("bte-warp-drive-runtime-test", "start_detector", platform.index) then
      fail("Start boost was refused")
    end
    local player = game.players[1]
    if player then
      local frame = player.gui.screen.bte_warp_drive_window
      if frame then
        frame.destroy()
      end
      player.opened = drive
      local cooldown = find_gui_element(player.gui.screen.bte_warp_drive_window,
        "bte_warp_drive_requirement_cooldown")
      if not cooldown or type(cooldown.caption) ~= "table"
          or cooldown.caption[1] ~= "bte-warp-drive.requirement-cooldown-waiting"
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
      fail("the drive consumed electrical energy during its re-entry lockout")
    end
    if remote.call("bte-warp-drive-runtime-test", "engage", platform.index) then
      fail("Engage was accepted during the re-entry lockout")
    end
    storage.power_source.power_production = 60e9 / 60
    storage.power_source.output_flow_limit = 60e9 / 60
  elseif phase == "exit_lockout" and elapsed == 600 then
    -- A warp exit does not re-engage by itself: the next jump needs Engage again, and with a
    -- full reserve Engage enters warp at once.
    local detector = charge_buffer(platform)
    if sound_state(platform).state ~= "idle" or not detector
        or detector.power_usage * 60 ~= 1e9 then
      fail("the Tachyon Science Boost did not resume demand once the lockout ended")
    end
    if not remote.call("bte-warp-drive-runtime-test", "stop_detector", platform.index) then
      fail("Stop boost was refused")
    end
    set_reserve_energy(platform, platform.weight * 100)
    engage(platform)
    if sound_state(platform).state ~= "warp" then
      fail("Engage with a full reserve did not enter warp immediately")
    end
  elseif phase == "exit_lockout" and elapsed == 610 then
    local support = charge_buffer(platform)
    local charge = charge_buffer(platform)
    local required_charge = platform.weight * 100
    if not support or circuit_signal("signal-W") ~= 1 or not charge then
      fail("Engage did not re-enter warp after the low-speed exit lockout")
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
    local charging_watts = platform.weight * 10 * 0.5
    storage.power_source.power_production = charging_watts / 60
    storage.power_source.output_flow_limit = charging_watts / 60
    platform.distance = 0.51
    platform.speed = 49 / 60
    platform.paused = false
  elseif phase == "post_warp_lockout" and elapsed == 600 then
    engage(platform)
    set_reserve_energy(platform, platform.weight * 50)
    local charge = charge_buffers(platform)
    local support = charge_buffer(platform)
    if #charge ~= 1 or reserve_energy(platform) < platform.weight * 50 or not support then
      fail("charging did not begin before the speed interruption")
    end
    local sound = sound_state(platform)
    if not sound.charge_step then
      fail("ready preparation did not begin its audible hum")
    end
    if field_hums(platform) ~= 0 then
      fail("the field hum outlived warp")
    end
    if sound_state(platform).anomalies ~= 0 then
      fail("background anomalies outlived warp")
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
    -- From here the engage condition, not the button, starts the next jump.
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
    section.set_slot(1, {value = {type = "virtual", name = "signal-A", quality = "normal"}, min = 1})
    storage.circuit_input = input
    storage.circuit_section = section
    configure_conditions({activate = {enabled = true, first_signal = A_SIGNAL, comparator = ">",
      constant = 0}})
  elseif phase == "post_warp_lockout" and elapsed == 910 then
    local charge = charge_buffers(platform)
    local support = charge_buffer(platform)
    local expected_watts = platform.weight * 10
    if #charge ~= 1 or reserve_energy(platform) ~= 0 or not support
      or math.abs(support.power_usage * 60 - expected_watts) > expected_watts * 0.001 then
      fail("a true engage condition did not begin charging once the lockout ended")
    end
    local sound = sound_state(platform)
    if sound.charge_step ~= 1
        or not sound.charge_next_tick
        or sound.charge_next_tick <= game.tick
        or sound.charge_next_tick > game.tick + 30 then
      fail("charging did not start its half-second progress hum scheduler")
    end
  elseif phase == "post_warp_lockout" and elapsed == 920 then
    local player = game.players[1]
    if player and player.gui.screen.bte_warp_drive_window then
      local frame = player.gui.screen.bte_warp_drive_window
      local power = find_gui_element(frame, "bte_warp_drive_requirement_power")
      local power_icon = find_gui_element(frame, "bte_warp_drive_requirement_power_icon")
      local acceleration_row = find_gui_element(frame, "bte_warp_drive_requirement_acceleration_row")
      local status_icon = find_gui_element(frame, "bte_warp_drive_status_icon")
      local status_text = find_gui_element(frame, "bte_warp_drive_status_text")
      local status_detail = find_gui_element(frame, "bte_warp_drive_status_detail")
      local charge_progress = find_gui_element(frame, "bte_warp_drive_status_progress")
      local required_charge = platform.weight * 100
      local charge_ratio = reserve_energy(platform) / required_charge
      if not power or type(power.caption) ~= "table"
        or power.caption[1] ~= "bte-warp-drive.field-power-charging"
        or not power_icon or power_icon.sprite ~= "utility/status_yellow"
        or not acceleration_row or acceleration_row.visible
        or not status_icon or status_icon.sprite ~= "utility/status_yellow"
        or not status_text or status_text.caption[1] ~= "bte-warp-drive.charging-status"
        or not status_detail or status_detail.caption[1] ~= "bte-warp-drive.charging-remaining"
        or not charge_progress or not charge_progress.visible
        or math.abs(charge_progress.value - charge_ratio) > 0.001
        or type(charge_progress.caption) ~= "table"
        or charge_progress.caption[1] ~= "bte-warp-drive.percent-value" then
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
        or sound.warp_next_tick > game.tick + 300 then
      fail("warp activation did not replace charging audio and schedule its background handoff")
    end
    -- The disengage condition wins over the still-true engage condition.
    configure_conditions({
      activate = {enabled = true, first_signal = A_SIGNAL, comparator = ">", constant = 0},
      deactivate = {enabled = true, first_signal = A_SIGNAL, comparator = "=", constant = 1}
    })
  elseif phase == "post_warp_lockout" and elapsed == 940 then
    local sound = sound_state(platform)
    if sound.state == "warp" or circuit_signal("signal-W") ~= 0
        or sound.last_exit_reason ~= "circuit-deactivate" then
      fail("a true disengage condition did not drop out of warp: state=" .. tostring(sound.state)
        .. " reason=" .. tostring(sound.last_exit_reason))
    end
    configure_conditions()
    game.forces.player.technologies["bte-practical-warp-drive"].researched = false
    set_phase("circuit_and_revocation")
  elseif phase == "circuit_and_revocation" and elapsed == 10 then
    local support = charge_buffers(platform)
    local charge = charge_buffers(platform)
    if #support ~= 1 or #charge ~= 1 or reserve_energy(platform) ~= 0 then
      fail("power interface was not reconfigured for experimental research")
    end
    if sound_state(platform).detector_on then
      fail("the detector was running before its start condition was set")
    end
    storage.circuit_section.clear_slot(1)
    local player = game.players[1]
    if player then
      player.opened = drive
    end
  elseif phase == "circuit_and_revocation" and elapsed == 20 then
    local player = game.players[1]
    if player then
      local frame = player.gui.screen.bte_warp_drive_window
      local green_network = find_gui_element(frame, "bte_warp_drive_circuit_green_network")
      local tooltip = green_network and green_network.tooltip
      if type(green_network.caption) ~= "table"
        or green_network.caption[1] ~= "bte-warp-drive.circuit-network-connected"
        or #green_network.caption ~= 4
        or type(tooltip) ~= "table" or #tooltip ~= 2
        or type(tooltip[2]) ~= "table"
        or tooltip[2][1] ~= "bte-warp-drive.circuit-network-tooltip-heading" then
        fail("empty circuit network reported a signal count")
      end
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
    configure_conditions({detector_start = {enabled = true, first_signal = A_SIGNAL,
      comparator = ">", second_signal = B_SIGNAL}})
    if player then
      reopen_gui(player)
    end
  elseif phase == "circuit_and_revocation" and elapsed == 30 then
    if not sound_state(platform).detector_on then
      fail("signal-to-signal start condition A > B did not start the detector")
    end
    local player = game.players[1]
    if player then
      local state = find_gui_element(player.gui.screen.bte_warp_drive_window,
        "bte_warp_drive_detector_start_state")
      local green_network = find_gui_element(player.gui.screen.bte_warp_drive_window,
        "bte_warp_drive_circuit_green_network")
      local tooltip = green_network and green_network.tooltip
      local signal_text = tooltip and tooltip[#tooltip]
      if not state or state.sprite ~= "utility/status_working"
        or type(state.tooltip) ~= "table" or state.tooltip[1] ~= "bte-warp-drive.condition-true"
        or type(green_network.caption) ~= "table"
        or green_network.caption[1] ~= "bte-warp-drive.circuit-network-connected-signals"
        or green_network.caption[4] ~= 1 or green_network.caption[5] < 2
        or type(tooltip) ~= "table" or tooltip[1] ~= ""
        or type(tooltip[2]) ~= "table"
        or tooltip[2][1] ~= "bte-warp-drive.circuit-network-tooltip-heading-signals"
        or tooltip[2][5] < 2
        or type(signal_text) ~= "string"
        or not string.find(signal_text, "[virtual-signal=signal-A]", 1, true) then
        fail("signal-to-signal circuit condition A > B was not shown as satisfied")
      end
    end
    platform.distance = 0.51
    -- The still-true start condition loses to the stop condition.
    configure_conditions({
      detector_start = {enabled = true, first_signal = A_SIGNAL, comparator = ">",
        second_signal = B_SIGNAL},
      detector_stop = {enabled = true, first_signal = A_SIGNAL, comparator = "<", constant = 8}
    })
    if player then
      reopen_gui(player)
    end
    set_phase("relocation")
  elseif phase == "relocation" and elapsed == 10 then
    if sound_state(platform).detector_on then
      fail("signal-to-constant stop condition A < 8 did not stop the detector")
    end
    local player = game.players[1]
    if player then
      local frame = player.gui.screen.bte_warp_drive_window
      local first = find_gui_element(frame, "bte_warp_drive_detector_stop_first_signal")
      local comparator = find_gui_element(frame, "bte_warp_drive_detector_stop_comparator")
      local second = find_gui_element(frame, "bte_warp_drive_detector_stop_second_signal")
      local threshold = find_gui_element(frame, "bte_warp_drive_detector_stop_constant")
      local state = find_gui_element(frame, "bte_warp_drive_detector_stop_state")
      local start = find_gui_element(frame, "bte_warp_drive_engage")
      if first.elem_value.name ~= "signal-A" or comparator.selected_index ~= 2
        or second.elem_value ~= nil or not threshold.visible or threshold.text ~= "8"
        or not state or state.sprite ~= "utility/status_working"
        or start.enabled or start.tooltip[1] ~= "bte-warp-drive.start-detector-blocked-deactivate" then
        fail("signal-to-constant circuit condition A < 8 was not shown as satisfied")
      end
    end
    drive.destroy()
    local orphan = platform.surface.create_entity({
      name = "bte-warp-drive-animation",
      position = {-9.5, 9.5},
      force = game.forces.player,
      snap_to_grid = false
    })
    local duplicate_orphan = platform.surface.create_entity({
      name = "bte-warp-drive-animation",
      position = {-9.5, 9.5},
      force = game.forces.player,
      snap_to_grid = false
    })
    local stray_output = platform.surface.create_entity({
      name = "bte-warp-drive-circuit-output",
      position = {8, 8},
      force = game.forces.player
    })
    if not orphan or not duplicate_orphan or not stray_output then
      fail("could not create orphan companion fixtures")
    end
    storage.orphan_animations = {orphan, duplicate_orphan}
    storage.drive = platform.surface.create_entity({
      name = "bte-warp-drive-controller",
      position = {-9.5, 9.5},
      force = game.forces.player,
      raise_built = true
    })
    if not storage.drive then
      fail("replacement drive creation returned nil")
    end
  elseif phase == "relocation" and elapsed == 20 then
    if select(2, string.gsub(overlay_names(storage.drive), "[^,]+", "")) ~= 2 then
      fail("replacement drive did not get exactly one interior and one glow overlay")
    end
    local companion_names = {
      "bte-warp-drive-animation",
      POWER_INTERFACE_NAME,
      "bte-warp-drive-circuit-output"
    }
    for _, name in pairs(companion_names) do
      local companions = platform.surface.find_entities_filtered({name = name})
      if #companions ~= 1 or companions[1].position.x ~= -9.5 or companions[1].position.y ~= 9.5 then
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
      name = "bte-warp-drive-circuit-output",
      position = {8, 8}
    })
    if #stray_outputs ~= 0 then
      fail("orphan circuit output survived companion recovery")
    end
    if not platform.surface.can_place_entity({
      name = "bte-warp-drive-controller",
      position = {0.5, 9.5},
      force = game.forces.player
    }) then
      fail("hidden companion blocked rebuilding at the old drive position")
    end
  elseif phase == "relocation" and elapsed == 30 then
    log("WARP_TEST_PASS: detector, duplicate, warp visuals, asteroid suppression, ramp, speed grace, reserve, warnings, lockout, circuit condition, revocation, and relocation paths completed")
    set_phase("complete")
  end
end)
