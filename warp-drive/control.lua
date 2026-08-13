local DRIVE_NAME = "warp-drive-controller"
local LEGACY_DRIVE_NAME = "warp-drive"
local LEGACY_VISUAL_NAME = "warp-drive-visual"
local LEGACY_MACHINE_NAME = "warp-drive-machine"
local LEGACY_STRUCTURE_NAME = "warp-drive-structure"
local DRIVE_ITEM_NAME = "warp-drive"
local SUPPORT_NAME = "warp-drive-support-load"
local DETECTOR_NAME = "warp-drive-detector-load"
local CHARGE_NAME = "warp-drive-charge-buffer"
local CIRCUIT_OUTPUT_NAME = "warp-drive-circuit-output"
local ANIMATION_NAME = "warp-drive-animation"
local PRACTICAL_TECH = "practical-warp-drive"
local CHARGE_JOULES_PER_KG = 500
local SUPPORT_WATTS_PER_KG = 20
local DETECTOR_POWER_WATTS = 200000000
local BASE_TACHYONS_PER_SECOND = 1
local MINIMUM_SPEED = 50
local WARP_MULTIPLIER = 100
local ENDPOINT_MARGIN_KM = 1000
local COOLDOWN_TICKS = 600
local UPDATE_TICKS = 10
local RESEARCH_UPDATE_TICKS = 60
local GUI_NAME = "warp_drive_window"
local GUI_TOGGLE = "warp_drive_enabled"
local GUI_CIRCUIT_TOGGLE = "warp_drive_circuit_enabled"
local GUI_CLOSE = "warp_drive_close"
local ENGAGE_SIGNAL = {type = "virtual", name = "signal-E"}
local COMPANION_FIELDS = {
  [SUPPORT_NAME] = "support",
  [DETECTOR_NAME] = "detector",
  [CHARGE_NAME] = "charge",
  [CIRCUIT_OUTPUT_NAME] = "circuit_output",
  [ANIMATION_NAME] = "animation"
}
local CIRCUIT_SIGNALS = {
  {type = "virtual", name = "signal-W"},
  {type = "virtual", name = "signal-C"},
  {type = "virtual", name = "signal-S"},
  {type = "virtual", name = "signal-P"}
}
local SPACELAB_INTEGRATION_ENABLED = false -- Temporary standalone testing switch.

local function storage_root()
  storage.drives = storage.drives or {}
  storage.direction_samples = storage.direction_samples or {}
end

local function destroy_support(record)
  if record and record.support and record.support.valid then
    record.support.destroy()
  end
  if record then
    record.support = nil
  end
end

local function destroy_detector(record)
  if record and record.detector and record.detector.valid then
    record.detector.destroy()
  end
  if record then
    record.detector = nil
    record.detector_power = 0
    record.detector_power_ratio = 0
  end
end

local function destroy_charge(record)
  if record and record.charge and record.charge.valid then
    record.charge.destroy()
  end
  if record then
    record.charge = nil
  end
end

local function destroy_circuit_output(record)
  if record and record.circuit_output and record.circuit_output.valid then
    record.circuit_output.destroy()
  end
  if record then
    record.circuit_output = nil
  end
end

local function destroy_animation(record)
  if record and record.animation and record.animation.valid then
    record.animation.destroy()
  end
  if record then
    record.animation = nil
  end
end

local function find_companion(record, field, name)
  local entity = record and record.entity
  if not entity or not entity.valid then
    return nil
  end
  local companion = record[field]
  if companion and companion.valid
      and companion.surface.index == entity.surface.index
      and companion.position.x == entity.position.x
      and companion.position.y == entity.position.y then
    return companion
  end
  if companion and companion.valid then
    companion.destroy()
  end
  record[field] = nil
  for _, candidate in pairs(entity.surface.find_entities_filtered({name = name, position = entity.position})) do
    if not record[field] then
      record[field] = candidate
    else
      candidate.destroy()
    end
  end
  return record[field]
end

local function recover_orphan_companions(record)
  local entity = record and record.entity
  if not entity or not entity.valid then
    return
  end
  for name, field in pairs(COMPANION_FIELDS) do
    find_companion(record, field, name)
  end
  for name, field in pairs(COMPANION_FIELDS) do
    for _, companion in pairs(entity.surface.find_entities_filtered({name = name})) do
      if companion ~= record[field] then
        companion.destroy()
      end
    end
  end
end

local function ensure_support(record)
  local support = find_companion(record, "support", SUPPORT_NAME)
  if support then
    return support
  end
  local entity = record.entity
  if not entity or not entity.valid then
    return nil
  end
  record.support = entity.surface.create_entity({
    name = SUPPORT_NAME,
    position = entity.position,
    force = entity.force,
    create_build_effect_smoke = false
  })
  return record.support
end

local function ensure_detector(record)
  local detector = find_companion(record, "detector", DETECTOR_NAME)
  if detector then
    return detector
  end
  local entity = record.entity
  if not entity or not entity.valid then
    return nil
  end
  record.detector = entity.surface.create_entity({
    name = DETECTOR_NAME,
    position = entity.position,
    force = entity.force,
    create_build_effect_smoke = false
  })
  return record.detector
end

local function ensure_charge(record)
  local charge = find_companion(record, "charge", CHARGE_NAME)
  if charge then
    return charge
  end
  local entity = record.entity
  if not entity or not entity.valid then
    return nil
  end
  record.charge = entity.surface.create_entity({
    name = CHARGE_NAME,
    position = entity.position,
    force = entity.force,
    create_build_effect_smoke = false
  })
  return record.charge
end

local function ensure_animation(record)
  local animation = find_companion(record, "animation", ANIMATION_NAME)
  if animation then
    return animation
  end
  local entity = record.entity
  if not entity or not entity.valid then
    return nil
  end
  record.animation = entity.surface.create_entity({
    name = ANIMATION_NAME,
    position = entity.position,
    direction = entity.direction,
    force = entity.force,
    create_build_effect_smoke = false
  })
  return record.animation
end

local function connect_circuit_wire(source, target, wire_id)
  local source_connector = source.get_wire_connector(wire_id, true)
  local target_connector = target.get_wire_connector(wire_id, true)
  if source_connector and target_connector then
    source_connector.connect_to(target_connector, false, defines.wire_origin.script)
  end
end

local function circuit_wire_connections(entity, wire_id)
  local connector = entity.get_wire_connector(wire_id, false)
  local connections = {}
  if connector then
    for _, connection in pairs(connector.connections) do
      connections[#connections + 1] = {
        target_entity = connection.target.owner,
        target_wire_id = connection.target.wire_connector_id,
        origin = connection.origin
      }
    end
  end
  return connections
end

local function restore_circuit_wires(entity, wire_id, connections)
  local connector = entity.get_wire_connector(wire_id, true)
  if not connector then
    return
  end
  for _, connection in pairs(connections) do
    local target = connection.target_entity.valid
      and connection.target_entity.get_wire_connector(connection.target_wire_id, false)
    if target then
      connector.connect_to(target, false, connection.origin)
    end
  end
end

local function ensure_circuit_output(record)
  local circuit_output = find_companion(record, "circuit_output", CIRCUIT_OUTPUT_NAME)
  if circuit_output then
    return circuit_output
  end
  local entity = record.entity
  if not entity or not entity.valid then
    return nil
  end
  record.circuit_output = entity.surface.create_entity({
    name = CIRCUIT_OUTPUT_NAME,
    position = entity.position,
    force = entity.force,
    create_build_effect_smoke = false
  })
  if record.circuit_output then
    connect_circuit_wire(entity, record.circuit_output, defines.wire_connector_id.circuit_red)
    connect_circuit_wire(entity, record.circuit_output, defines.wire_connector_id.circuit_green)
  end
  return record.circuit_output
end

local function set_output_signals(record, platform)
  local output = ensure_circuit_output(record)
  if not output then
    return
  end
  local behavior = output.get_or_create_control_behavior()
  local section = behavior and (behavior.get_section(1) or behavior.add_section())
  if not section then
    return
  end
  local charge = record.charge and record.charge.valid and record.charge.energy or 0
  local required = platform.weight / 1000 * CHARGE_JOULES_PER_KG
  local charge_percent = required > 0 and math.min(100, math.floor(charge / required * 100)) or 0
  local values = {
    record.state == "warp" and 1 or 0,
    charge_percent,
    math.floor(platform.speed * (record.state == "warp" and WARP_MULTIPLIER or 1)),
    math.floor((record.detector_power_ratio or 0) * 100)
  }
  for index, signal in ipairs(CIRCUIT_SIGNALS) do
    section.set_slot(index, {
      value = {type = signal.type, name = signal.name, quality = "normal"},
      min = values[index]
    })
  end
end

local function migrate_legacy_entity(record)
  local legacy = record.entity
  if not legacy or not legacy.valid
      or (legacy.name ~= LEGACY_DRIVE_NAME
        and legacy.name ~= LEGACY_VISUAL_NAME
        and legacy.name ~= LEGACY_MACHINE_NAME
        and legacy.name ~= LEGACY_STRUCTURE_NAME) then
    return
  end
  local surface = legacy.surface
  local position = legacy.position
  local direction = legacy.direction
  local force = legacy.force
  local health_ratio = legacy.health and legacy.max_health > 0
    and legacy.health / legacy.max_health or 1
  local technology = force.technologies[PRACTICAL_TECH]
  local stored_charge = technology and technology.researched and legacy.energy or 0
  local red_connections = circuit_wire_connections(legacy, defines.wire_connector_id.circuit_red)
  local green_connections = circuit_wire_connections(legacy, defines.wire_connector_id.circuit_green)
  legacy.destroy()
  local replacement = surface.create_entity({
    name = DRIVE_NAME,
    position = position,
    direction = direction,
    force = force,
    create_build_effect_smoke = false
  })
  if replacement and replacement.valid then
    restore_circuit_wires(replacement, defines.wire_connector_id.circuit_red, red_connections)
    restore_circuit_wires(replacement, defines.wire_connector_id.circuit_green, green_connections)
  end
  record.entity = replacement
  if replacement and replacement.valid then
    replacement.health = replacement.max_health * health_ratio
    if stored_charge > 0 then
      local charge = ensure_charge(record)
      if charge then
        charge.energy = math.min(stored_charge, charge.electric_buffer_size)
      end
    end
  end
end

local function register_drive(entity)
  if not entity or not entity.valid or entity.name ~= DRIVE_NAME then
    return
  end
  local platform = entity.surface.platform
  if not platform then
    entity.destroy({raise_destroy = true})
    return
  end
  local existing = storage.drives[platform.index]
  if existing and existing.entity and existing.entity.valid and existing.entity ~= entity then
    entity.surface.spill_item_stack({
      position = entity.position,
      stack = {name = DRIVE_ITEM_NAME, count = 1},
      force = entity.force,
      allow_belts = false
    })
    entity.destroy({raise_destroy = true})
    platform.force.print({"warp-drive.duplicate"})
    return
  end
  if existing and existing.entity ~= entity then
    destroy_support(existing)
    destroy_detector(existing)
    destroy_charge(existing)
    destroy_animation(existing)
    destroy_circuit_output(existing)
  end
  local record = existing or {}
  record.entity = entity
  record.platform_index = platform.index
  record.enabled = record.enabled ~= false
  record.circuit_enabled = record.circuit_enabled == true
  record.state = record.state or "idle"
  record.cooldown_until = record.cooldown_until or 0
  record.last_distance = platform.distance
  record.direction = record.direction or 0
  storage.drives[platform.index] = record
  recover_orphan_companions(record)
  ensure_animation(record)
  ensure_circuit_output(record)
end

local function register_drive_from_event(event)
  local entity = event.entity
  register_drive(entity)
  if not entity or not entity.valid then
    return
  end
  local platform = entity.surface.platform
  local record = platform and storage.drives[platform.index]
  if record and event.tags and event.tags.warp_drive_circuit_enabled ~= nil then
    record.circuit_enabled = event.tags.warp_drive_circuit_enabled == true
  end
end

local function rebuild_drives()
  storage_root()
  local old_drives = storage.drives
  storage.drives = {}
  for _, force in pairs(game.forces) do
    for _, platform in pairs(force.platforms) do
      local entities = platform.surface.find_entities_filtered({name = DRIVE_NAME})
      if #entities > 0 then
        local old = old_drives[platform.index]
        local record = old or {}
        record.entity = entities[1]
        record.platform_index = platform.index
        record.enabled = record.enabled ~= false
        record.circuit_enabled = record.circuit_enabled == true
        record.state = record.state or "idle"
        record.cooldown_until = record.cooldown_until or 0
        record.last_distance = platform.distance
        storage.drives[platform.index] = record
        recover_orphan_companions(record)
        ensure_animation(record)
        ensure_circuit_output(record)
        for index = 2, #entities do
          entities[index].destroy({raise_destroy = true})
        end
      end
    end
  end
  for platform_index, old in pairs(old_drives) do
    if not storage.drives[platform_index] then
      destroy_support(old)
      destroy_detector(old)
      destroy_charge(old)
      destroy_animation(old)
      destroy_circuit_output(old)
    end
  end
end

local function migrate_legacy_drives()
  for _, force in pairs(game.forces) do
    for _, platform in pairs(force.platforms) do
      for _, legacy in pairs(platform.surface.find_entities_filtered({
        name = {LEGACY_DRIVE_NAME, LEGACY_VISUAL_NAME, LEGACY_MACHINE_NAME, LEGACY_STRUCTURE_NAME}
      })) do
        local record = storage.drives[platform.index] or {platform_index = platform.index}
        record.entity = legacy
        migrate_legacy_entity(record)
        storage.drives[platform.index] = record
      end
    end
  end
end

local function platform_weight_kg(platform)
  return platform.weight / 1000
end

local function required_charge(platform)
  return platform_weight_kg(platform) * CHARGE_JOULES_PER_KG
end

local function connection_margin(platform)
  local connection = platform.space_connection
  if not connection or connection.length <= 0 then
    return nil
  end
  return ENDPOINT_MARGIN_KM / connection.length
end

local function update_direction(record, platform)
  local distance = platform.distance
  if not distance then
    record.last_distance = nil
    record.direction = 0
    return 0
  end
  if record.last_distance then
    local delta = distance - record.last_distance
    if math.abs(delta) > 0.000000001 then
      record.direction = delta > 0 and 1 or -1
    end
  end
  record.last_distance = distance
  return record.direction
end

local function endpoint_clear(platform, direction)
  local margin = connection_margin(platform)
  local distance = platform.distance
  if not margin or not distance or margin * 2 >= 1 or direction == 0 then
    return false
  end
  if direction > 0 then
    return distance > margin and distance < 1 - margin
  end
  return distance < 1 - margin and distance > margin
end

local function practical_researched(force)
  local technology = force.technologies[PRACTICAL_TECH]
  return technology and technology.researched
end

local function circuit_engagement_satisfied(record)
  if not record.circuit_enabled then
    return true
  end
  local entity = record.entity
  if not entity or not entity.valid then
    return false
  end
  return entity.get_signal(
    ENGAGE_SIGNAL,
    defines.wire_connector_id.circuit_red,
    defines.wire_connector_id.circuit_green
  ) > 0
end

local function exit_warp(record)
  if record.state == "warp" then
    record.state = "idle"
    record.cooldown_until = game.tick + COOLDOWN_TICKS
  end
  destroy_support(record)
  if record.charge and record.charge.valid then
    record.charge.disabled_by_script = game.tick < record.cooldown_until
  end
end

local function can_prepare(record, platform, direction)
  return record.enabled
    and circuit_engagement_satisfied(record)
    and practical_researched(platform.force)
    and platform.space_connection ~= nil
    and platform.distance ~= nil
    and not platform.paused
    and platform.speed >= MINIMUM_SPEED
    and endpoint_clear(platform, direction)
    and game.tick >= record.cooldown_until
end

local function support_satisfied(record, watts)
  local support = ensure_support(record)
  if not support then
    return false
  end
  local required_energy = watts * UPDATE_TICKS / 60
  support.power_usage = 0
  support.electric_buffer_size = required_energy
  support.input_flow_limit = watts
  local satisfied = support.energy >= required_energy * 0.95
  support.energy = 0
  return satisfied
end

local function update_detector(record)
  local detector = ensure_detector(record)
  if not detector then
    record.detector_power_ratio = 0
    record.detector_power = 0
    return
  end
  record.detector_power = math.min(DETECTOR_POWER_WATTS, detector.energy * 60 / UPDATE_TICKS)
  record.detector_power_ratio = record.detector_power / DETECTOR_POWER_WATTS
  detector.energy = 0
end

local function enter_warp(record, platform)
  local charge = required_charge(platform)
  local buffer = ensure_charge(record)
  if not buffer or buffer.energy + 1 < charge then
    return false
  end
  buffer.energy = 0
  buffer.disabled_by_script = true
  record.state = "warp"
  local support = ensure_support(record)
  if support then
    local watts = platform_weight_kg(platform) * SUPPORT_WATTS_PER_KG
    support.power_usage = 0
    support.electric_buffer_size = watts * UPDATE_TICKS / 60
    support.input_flow_limit = watts
    support.energy = 0
    record.support_check_after = game.tick + UPDATE_TICKS * 2
  end
  platform.destroy_asteroid_chunks({})
  return true
end

local function update_drive(record)
  migrate_legacy_entity(record)
  local entity = record.entity
  if not entity or not entity.valid then
    destroy_support(record)
    destroy_detector(record)
    destroy_charge(record)
    destroy_animation(record)
    destroy_circuit_output(record)
    return false
  end
  local platform = entity.surface.platform
  if not platform or platform.index ~= record.platform_index then
    destroy_support(record)
    destroy_detector(record)
    destroy_charge(record)
    destroy_animation(record)
    destroy_circuit_output(record)
    return false
  end
  ensure_animation(record)
  ensure_circuit_output(record)
  local direction = update_direction(record, platform)
  if not practical_researched(platform.force) then
    exit_warp(record)
    destroy_charge(record)
    update_detector(record)
    record.state = record.detector_power_ratio > 0.01 and "detecting" or "detector-offline"
    return true
  end
  destroy_detector(record)
  local charge_buffer = ensure_charge(record)
  if not charge_buffer then
    record.state = "charging"
    return true
  end
  if record.state == "warp" then
    local watts = platform_weight_kg(platform) * SUPPORT_WATTS_PER_KG
    local support_available = support_satisfied(record, watts)
    if not can_prepare(record, platform, direction)
        or (game.tick >= (record.support_check_after or 0) and not support_available) then
      exit_warp(record)
      return true
    end
    local connection = platform.space_connection
    local margin = connection_margin(platform)
    local extra_distance = direction * (WARP_MULTIPLIER - 1) * platform.speed * (UPDATE_TICKS / 60) / connection.length
    local boundary = direction > 0 and 1 - margin or margin
    local target = platform.distance + extra_distance
    if (direction > 0 and target >= boundary) or (direction < 0 and target <= boundary) then
      platform.distance = boundary
      exit_warp(record)
    else
      platform.distance = target
      record.last_distance = target
      platform.destroy_asteroid_chunks({})
    end
    return true
  end

  destroy_support(record)
  record.detector_power = 0
  record.detector_power_ratio = 0
  if game.tick < record.cooldown_until then
    charge_buffer.disabled_by_script = true
    record.state = "cooldown"
    return true
  end
  charge_buffer.disabled_by_script = false
  local charge = required_charge(platform)
  if charge_buffer.energy + 1 >= charge then
    if can_prepare(record, platform, direction) then
      enter_warp(record, platform)
    else
      record.state = "ready"
    end
  else
    record.state = "charging"
  end
  return true
end

local function location_multiplier(platform)
  if platform.space_location then
    return 10
  end
  local connection = platform.space_connection
  local distance = platform.distance
  if not connection or not distance then
    return 1
  end
  local depth = math.abs(distance - 0.5) * 2
  local multiplier = 100 + 900 * depth
  local from_name = connection.from.name
  local to_name = connection.to.name
  if (from_name == "solar-system-edge" and to_name == "shattered-planet")
      or (to_name == "solar-system-edge" and from_name == "shattered-planet") then
    local anomaly_depth = to_name == "shattered-planet" and distance or 1 - distance
    if anomaly_depth > 0.8 then
      multiplier = math.max(multiplier, 1000 + 4000 * ((anomaly_depth - 0.8) / 0.2))
    end
  end
  return multiplier
end

local function spacelab_multiplier(surface)
  if not SPACELAB_INTEGRATION_ENABLED or not script.active_mods.spacelab then
    return 1
  end
  local working = 0
  for _, entity in pairs(surface.find_entities_filtered({name = "spacelab-growth-facility"})) do
    if entity.status == defines.entity_status.working then
      working = working + 1
    end
  end
  return math.min(2, 1 + working * 0.05)
end

local function working_lab_metrics(surface, force)
  local count = 0
  local total_rate = 0
  for _, lab in pairs(surface.find_entities_filtered({type = "lab", force = force})) do
    if lab.status == defines.entity_status.working then
      local base_speed = lab.prototype.get_researching_speed(lab.quality.name) or 0
      count = count + 1
      total_rate = total_rate + base_speed * (1 + lab.speed_bonus) * (1 + lab.productivity_bonus)
    end
  end
  return count, total_rate
end

local function add_research_bonus(record)
  local entity = record.entity
  if not entity or not entity.valid or (record.detector_power_ratio or 0) <= 0 then
    return
  end
  local force = entity.force
  local research = force.current_research
  if not research or research.name ~= PRACTICAL_TECH then
    return
  end
  local platform = entity.surface.platform
  if not platform then
    return
  end
  local signal_multiplier = location_multiplier(platform) * spacelab_multiplier(entity.surface)
  local multiplier = 1 + (signal_multiplier - 1) * record.detector_power_ratio
  if multiplier <= 1 then
    return
  end
  local _, total_rate = working_lab_metrics(entity.surface, force)
  if total_rate <= 0 then
    return
  end
  local research_seconds = research.research_unit_energy / 60000
  local total_work = research.research_unit_count * research_seconds
  local progress = total_rate * (multiplier - 1) * (RESEARCH_UPDATE_TICKS / 60) / total_work
  if force.current_research == research then
    force.research_progress = math.min(0.999999999, force.research_progress + progress)
  end
end

local function format_energy(joules)
  if joules >= 1000000000 then
    return string.format("%.2f GJ", joules / 1000000000)
  end
  if joules >= 1000000 then
    return string.format("%.2f MJ", joules / 1000000)
  end
  return string.format("%.2f kJ", joules / 1000)
end

local function format_power(watts)
  if watts >= 1000000000 then
    return string.format("%.2f GW", watts / 1000000000)
  end
  if watts >= 1000000 then
    return string.format("%.2f MW", watts / 1000000)
  end
  return string.format("%.2f kW", watts / 1000)
end

local function add_status_row(parent, name, label)
  local row = parent.add({type = "flow", direction = "horizontal"})
  row.style.horizontally_stretchable = true
  local label_element = row.add({type = "label", caption = label})
  label_element.style.width = 190
  local result = row.add({type = "label", name = name})
  result.style.single_line = false
  return result
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

local function update_gui(player, record)
  local frame = player.gui.screen[GUI_NAME]
  if not frame or not record.entity or not record.entity.valid then
    if frame then
      frame.destroy()
    end
    return
  end
  local content = frame.warp_drive_content
  local platform = record.entity.surface.platform
  if not content or not platform then
    frame.destroy()
    return
  end
  local function gui(name)
    return find_gui_element(content, name)
  end
  frame.tags = {platform_index = record.platform_index}
  local practical = practical_researched(record.entity.force)
  gui("warp_drive_warp_section").visible = practical
  gui("warp_drive_mode").caption = practical and {"warp-drive.mode-operational"} or {"warp-drive.mode-experimental"}
  gui("warp_drive_status_sprite").sprite = record.state == "warp" and "utility/status_working"
    or (record.state == "detector-offline" and "utility/status_not_working" or "utility/status_yellow")

  local signal_multiplier = location_multiplier(platform) * spacelab_multiplier(record.entity.surface)
  local power_ratio = practical and 0 or (record.detector_power_ratio or 0)
  local effective_multiplier = 1 + (signal_multiplier - 1) * power_ratio
  local lab_count, lab_rate = working_lab_metrics(record.entity.surface, record.entity.force)
  local research = record.entity.force.current_research
  local researching_practical = research and research.name == PRACTICAL_TECH
  local bonus_rate = researching_practical
    and lab_rate * (effective_multiplier - 1) / (research.research_unit_energy / 60000) or 0
  gui("warp_drive_detector_status").caption = {"warp-drive.state-" .. (practical and "complete" or record.state)}
  gui("warp_drive_detector_power").caption = {"warp-drive.power-value", format_power(record.detector_power or 0), format_power(DETECTOR_POWER_WATTS), math.floor(power_ratio * 100)}
  gui("warp_drive_detector_bar").value = power_ratio
  gui("warp_drive_detector_bar").caption = {"warp-drive.percent-value", math.floor(power_ratio * 100)}
  gui("warp_drive_signal_multiplier").caption = {"warp-drive.multiplier-value", string.format("%.1f", signal_multiplier)}
  gui("warp_drive_tachyon_rate").caption = {"warp-drive.tachyon-value", string.format("%.2f", BASE_TACHYONS_PER_SECOND * signal_multiplier * power_ratio)}
  gui("warp_drive_working_labs").caption = tostring(lab_count)
  gui("warp_drive_research_bonus").caption = {"warp-drive.research-rate-value", string.format("%.2f", bonus_rate)}
  gui("warp_drive_research_progress").parent.visible = researching_practical
  gui("warp_drive_research_remaining").parent.visible = researching_practical
  if researching_practical then
    gui("warp_drive_research_progress").caption = {"warp-drive.percent-value", string.format("%.6f", record.entity.force.research_progress * 100)}
    gui("warp_drive_research_remaining").caption = string.format("%.0f", research.research_unit_count * (1 - record.entity.force.research_progress))
  end

  gui(GUI_TOGGLE).state = record.enabled
  gui(GUI_TOGGLE).enabled = practical
  gui(GUI_CIRCUIT_TOGGLE).state = record.circuit_enabled
  gui(GUI_CIRCUIT_TOGGLE).enabled = practical
  gui("warp_drive_circuit_state").caption = circuit_engagement_satisfied(record) and {"warp-drive.yes"} or {"warp-drive.no"}
  gui("warp_drive_warp_status").caption = {"warp-drive.state-" .. (practical and record.state or "locked")}
  local charge = required_charge(platform)
  local stored_charge = practical and record.charge and record.charge.valid and record.charge.energy or 0
  local charge_ratio = charge > 0 and math.min(1, stored_charge / charge) or 0
  gui("warp_drive_activation_charge").caption = {"warp-drive.charge-value", format_energy(stored_charge), format_energy(charge), math.floor(charge_ratio * 100)}
  gui("warp_drive_charge_bar").value = charge_ratio
  gui("warp_drive_charge_bar").caption = {"warp-drive.percent-value", math.floor(charge_ratio * 100)}
  gui("warp_drive_platform_speed").caption = string.format("%.2f", platform.speed)
  gui("warp_drive_effective_speed").caption = string.format("%.2f", platform.speed * (record.state == "warp" and WARP_MULTIPLIER or 1))
  gui("warp_drive_support_demand").caption = format_power(platform_weight_kg(platform) * SUPPORT_WATTS_PER_KG)
  gui("warp_drive_route_clearance").caption = endpoint_clear(platform, record.direction) and {"warp-drive.yes"} or {"warp-drive.no"}
  gui("warp_drive_cooldown").caption = {"warp-drive.seconds-value", string.format("%.1f", math.max(0, record.cooldown_until - game.tick) / 60)}
end

local function draw_gui(player, record)
  local old = player.gui.screen[GUI_NAME]
  if old then
    old.destroy()
  end
  if not record.entity or not record.entity.valid then
    return
  end
  local frame = player.gui.screen.add({
    type = "frame",
    name = GUI_NAME,
    direction = "vertical"
  })
  frame.tags = {platform_index = record.platform_index}
  frame.style.width = 440
  frame.auto_center = true

  local title = frame.add({type = "flow", direction = "horizontal"})
  title.drag_target = frame
  title.add({type = "sprite", sprite = "entity/warp-drive"})
  local title_label = title.add({type = "label", caption = {"warp-drive.title"}, style = "frame_title"})
  title_label.style.left_margin = 8
  local spacer = title.add({type = "empty-widget", style = "draggable_space_header"})
  spacer.style.horizontally_stretchable = true
  spacer.style.height = 24
  spacer.drag_target = frame
  title.add({type = "sprite-button", name = GUI_CLOSE, sprite = "utility/close", style = "frame_action_button"})

  local content = frame.add({type = "frame", name = "warp_drive_content", direction = "vertical", style = "inside_shallow_frame"})
  content.style.padding = 12
  content.style.horizontally_stretchable = true
  local status = content.add({type = "flow", direction = "horizontal"})
  status.style.vertical_align = "center"
  local status_sprite = status.add({type = "sprite", name = "warp_drive_status_sprite", sprite = "utility/status_yellow"})
  status_sprite.style.size = 16
  status_sprite.style.stretch_image_to_widget_size = true
  local mode = status.add({type = "label", name = "warp_drive_mode"})
  mode.style.single_line = false
  mode.style.left_margin = 8
  mode.style.bottom_margin = 8

  content.add({type = "line"})
  content.add({type = "label", caption = {"warp-drive.detector-section"}, style = "heading_2_label"})
  add_status_row(content, "warp_drive_detector_status", {"warp-drive.detector-status"})
  add_status_row(content, "warp_drive_detector_power", {"warp-drive.detector-power"})
  local detector_bar = content.add({
    type = "progressbar",
    name = "warp_drive_detector_bar",
    value = 0,
    style = "production_progressbar"
  })
  detector_bar.style.horizontally_stretchable = true
  add_status_row(content, "warp_drive_signal_multiplier", {"warp-drive.signal-multiplier"})
  add_status_row(content, "warp_drive_tachyon_rate", {"warp-drive.tachyon-rate"})
  add_status_row(content, "warp_drive_working_labs", {"warp-drive.working-labs"})
  add_status_row(content, "warp_drive_research_bonus", {"warp-drive.research-bonus"})
  add_status_row(content, "warp_drive_research_progress", {"warp-drive.research-progress"})
  add_status_row(content, "warp_drive_research_remaining", {"warp-drive.research-remaining"})
  local help = content.add({type = "label", caption = {"warp-drive.detector-help"}})
  help.style.single_line = false
  help.style.top_margin = 8
  help.style.bottom_margin = 8

  local warp_section = content.add({type = "flow", name = "warp_drive_warp_section", direction = "vertical"})
  warp_section.style.horizontally_stretchable = true
  warp_section.add({type = "line"})
  warp_section.add({type = "label", caption = {"warp-drive.warp-section"}, style = "heading_2_label"})
  warp_section.add({type = "checkbox", name = GUI_TOGGLE, state = true, caption = {"warp-drive.enabled"}})
  warp_section.add({type = "checkbox", name = GUI_CIRCUIT_TOGGLE, state = false, caption = {"warp-drive.circuit-enabled"}, tooltip = {"warp-drive.circuit-enabled-tooltip"}})
  add_status_row(warp_section, "warp_drive_circuit_state", {"warp-drive.circuit-condition"})
  add_status_row(warp_section, "warp_drive_warp_status", {"warp-drive.warp-status"})
  add_status_row(warp_section, "warp_drive_activation_charge", {"warp-drive.activation-charge"})
  local charge_bar = warp_section.add({
    type = "progressbar",
    name = "warp_drive_charge_bar",
    value = 0,
    style = "production_progressbar"
  })
  charge_bar.style.horizontally_stretchable = true
  add_status_row(warp_section, "warp_drive_platform_speed", {"warp-drive.platform-speed"})
  add_status_row(warp_section, "warp_drive_effective_speed", {"warp-drive.effective-speed"})
  add_status_row(warp_section, "warp_drive_support_demand", {"warp-drive.support-demand"})
  add_status_row(warp_section, "warp_drive_route_clearance", {"warp-drive.route-clearance"})
  add_status_row(warp_section, "warp_drive_cooldown", {"warp-drive.cooldown-label"})
  local warp_help = warp_section.add({type = "label", caption = {"warp-drive.warp-help"}})
  warp_help.style.single_line = false
  warp_help.style.top_margin = 8
  player.opened = frame
  update_gui(player, record)
end

script.on_init(function()
  storage_root()
  rebuild_drives()
end)

script.on_configuration_changed(function()
  storage_root()
  migrate_legacy_drives()
  rebuild_drives()
end)

for _, event in pairs({
  defines.events.on_built_entity,
  defines.events.on_robot_built_entity,
  defines.events.on_space_platform_built_entity,
  defines.events.script_raised_built,
  defines.events.script_raised_revive
}) do
  script.on_event(event, function(event_data)
    register_drive_from_event(event_data)
  end, {{filter = "name", name = DRIVE_NAME}})
end

for _, event in pairs({
  defines.events.on_pre_player_mined_item,
  defines.events.on_robot_pre_mined,
  defines.events.on_space_platform_pre_mined,
  defines.events.on_entity_died,
  defines.events.script_raised_destroy
}) do
  script.on_event(event, function(event_data)
    local entity = event_data.entity
    if not entity or entity.name ~= DRIVE_NAME then
      return
    end
    for platform_index, record in pairs(storage.drives) do
      if record.entity == entity then
        destroy_support(record)
        destroy_detector(record)
        destroy_charge(record)
        destroy_animation(record)
        destroy_circuit_output(record)
        storage.drives[platform_index] = nil
        break
      end
    end
  end, {{filter = "name", name = DRIVE_NAME}})
end

script.on_nth_tick(UPDATE_TICKS, function()
  for platform_index, record in pairs(storage.drives) do
    if not update_drive(record) then
      storage.drives[platform_index] = nil
    else
      local platform = record.entity.surface.platform
      if platform then
        set_output_signals(record, platform)
      end
    end
  end
end)

script.on_nth_tick(RESEARCH_UPDATE_TICKS, function()
  for _, record in pairs(storage.drives) do
    add_research_bonus(record)
  end
  for _, player in pairs(game.connected_players) do
    local frame = player.gui.screen[GUI_NAME]
    if frame then
      local record = storage.drives[frame.tags.platform_index]
      if record then
        update_gui(player, record)
      else
        frame.destroy()
      end
    end
  end
end)

script.on_event(defines.events.on_gui_opened, function(event)
  local entity = event.entity
  if not entity or entity.name ~= DRIVE_NAME then
    return
  end
  local player = game.get_player(event.player_index)
  player.opened = nil
  local cursor = player.cursor_stack
  if cursor and cursor.valid_for_read then
    return
  end
  local platform = entity.surface.platform
  local record = platform and storage.drives[platform.index]
  if record then
    draw_gui(player, record)
  end
end)

script.on_event("warp-drive-open", function(event)
  local player = game.get_player(event.player_index)
  local entity = player and player.selected
  if not entity or not entity.valid or entity.name ~= DRIVE_NAME then
    return
  end
  local cursor = player.cursor_stack
  if cursor and cursor.valid_for_read then
    return
  end
  local platform = entity.surface.platform
  local record = platform and storage.drives[platform.index]
  if record then
    player.opened = nil
    draw_gui(player, record)
  end
end)

script.on_event(defines.events.on_gui_click, function(event)
  local element = event.element
  if not element or not element.valid or element.name ~= GUI_CLOSE then
    return
  end
  local player = game.get_player(event.player_index)
  player.opened = nil
  local frame = player.gui.screen[GUI_NAME]
  if frame then
    frame.destroy()
  end
end)

script.on_event(defines.events.on_gui_checked_state_changed, function(event)
  local element = event.element
  if not element or not element.valid
      or (element.name ~= GUI_TOGGLE and element.name ~= GUI_CIRCUIT_TOGGLE) then
    return
  end
  local frame = element.parent
  while frame and frame.name ~= GUI_NAME do
    frame = frame.parent
  end
  if not frame then
    return
  end
  local record = storage.drives[frame.tags.platform_index]
  if record then
    if element.name == GUI_TOGGLE then
      record.enabled = element.state
    else
      record.circuit_enabled = element.state
    end
    if not record.enabled or not circuit_engagement_satisfied(record) then
      exit_warp(record)
    end
    update_gui(game.get_player(event.player_index), record)
  end
end)

script.on_event(defines.events.on_player_setup_blueprint, function(event)
  local player = game.get_player(event.player_index)
  local blueprint = player and player.blueprint_to_setup
  if not blueprint or not blueprint.valid_for_read or not blueprint.is_blueprint_setup() then
    return
  end
  local mapping = event.mapping.get()
  for _, blueprint_entity in pairs(blueprint.get_blueprint_entities() or {}) do
    if blueprint_entity.name == DRIVE_NAME then
      local entity = mapping[blueprint_entity.entity_number]
      local platform = entity and entity.valid and entity.surface.platform
      local record = platform and storage.drives[platform.index]
      if record then
        blueprint.set_blueprint_entity_tags(blueprint_entity.entity_number, {
          warp_drive_circuit_enabled = record.circuit_enabled
        })
      end
    end
  end
end)

script.on_event(defines.events.on_entity_settings_pasted, function(event)
  if not event.source or not event.source.valid or event.source.name ~= DRIVE_NAME
      or not event.destination or not event.destination.valid or event.destination.name ~= DRIVE_NAME then
    return
  end
  local source_platform = event.source.surface.platform
  local destination_platform = event.destination.surface.platform
  local source_record = source_platform and storage.drives[source_platform.index]
  local destination_record = destination_platform and storage.drives[destination_platform.index]
  if source_record and destination_record then
    destination_record.enabled = source_record.enabled
    destination_record.circuit_enabled = source_record.circuit_enabled
  end
end)

script.on_event(defines.events.on_gui_closed, function(event)
  local player = game.get_player(event.player_index)
  local frame = player.gui.screen[GUI_NAME]
  if frame and event.element == frame then
    frame.destroy()
  end
end)
