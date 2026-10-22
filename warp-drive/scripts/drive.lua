local Visuals = require("scripts.visuals")

local Drive = {}

local DRIVE_NAME = "bte-warp-drive-controller"
local DRIVE_ITEM_NAME = "bte-warp-drive"
local POWER_NAME = "bte-warp-drive-power-interface"
local SUPPORT_NAME = "bte-warp-drive-support-load"
local DETECTOR_NAME = "bte-warp-drive-detector-load"
local CHARGE_NAME = "bte-warp-drive-charge-buffer"
local LEGACY_POWER_NAMES = {
  SUPPORT_NAME,
  DETECTOR_NAME,
  "bte-warp-drive-charge-buffer-100mj",
  "bte-warp-drive-charge-buffer-1gj",
  "bte-warp-drive-charge-buffer-10gj",
  CHARGE_NAME
}
local CIRCUIT_OUTPUT_NAME = "bte-warp-drive-circuit-output"
local ANIMATION_NAME = "bte-warp-drive-animation"
local PRACTICAL_TECH = "bte-practical-warp-drive"
local CHARGE_JOULES_PER_KG = 100
local TICKS_PER_SECOND = 60
local WARP_BOOST_PER_LEVEL = 10
local WARP_LEVEL_SIGNAL = {type = "virtual", name = "signal-W"}
local DISTANCE_SIGNAL = {type = "virtual", name = "signal-D"}
local CHARGE_SIGNAL = {type = "virtual", name = "signal-C"}
local SPEED_SIGNAL = {type = "virtual", name = "signal-S"}
local TACHYON_DENSITY_SIGNAL = {type = "virtual", name = "signal-T"}
local CIRCUIT_COMPARATORS = {">", "<", "=", "≥", "≤", "≠"}
local CIRCUIT_COMPARATOR_INDEX = {
  [">"] = 1,
  ["<"] = 2,
  ["="] = 3,
  ["≥"] = 4,
  [">="] = 4,
  ["≤"] = 5,
  ["<="] = 5,
  ["≠"] = 6,
  ["!="] = 6
}
local COMPANION_FIELDS = {
  [POWER_NAME] = "power",
  [CIRCUIT_OUTPUT_NAME] = "circuit_output",
  [ANIMATION_NAME] = "animation"
}

function Drive.init_storage()
  storage.drives = storage.drives or {}
end

function Drive.records()
  Drive.init_storage()
  return storage.drives
end

function Drive.get(platform_index)
  return Drive.records()[platform_index]
end

function Drive.normalize_engagement(record)
  record.enabled = record.enabled ~= false
  record.circuit_enabled = record.circuit_enabled == true
  if record.circuit_enabled then
    record.enabled = false
  end
end

function Drive.normalize_record(record, entity, platform)
  record.entity = entity
  record.platform_index = platform.index
  Drive.normalize_engagement(record)
  -- Older versions silently supplied signal E. Clear that legacy default once; subsequent
  -- selections, including an explicit E, remain user-owned settings.
  if not record.empty_engage_signal_migrated then
    if record.circuit_first_signal and record.circuit_first_signal.type == "virtual"
        and record.circuit_first_signal.name == "signal-E" then
      record.circuit_first_signal = nil
    end
    record.empty_engage_signal_migrated = true
  end
  record.circuit_comparator = CIRCUIT_COMPARATORS[
    CIRCUIT_COMPARATOR_INDEX[record.circuit_comparator] or 1]
  record.circuit_constant = record.circuit_constant or 0
  record.output_warp_enabled = record.output_warp_enabled ~= false
  record.output_warp_signal = record.output_warp_signal or WARP_LEVEL_SIGNAL
  record.output_distance_enabled = record.output_distance_enabled == true
  record.output_distance_signal = record.output_distance_signal or DISTANCE_SIGNAL
  record.output_charge_enabled = record.output_charge_enabled ~= false
  record.output_charge_signal = record.output_charge_signal or CHARGE_SIGNAL
  record.output_speed_enabled = record.output_speed_enabled ~= false
  record.output_speed_signal = record.output_speed_signal or SPEED_SIGNAL
  record.output_tachyon_density_enabled = record.output_tachyon_density_enabled == true
  record.output_tachyon_density_signal = record.output_tachyon_density_signal
    or TACHYON_DENSITY_SIGNAL
  record.output_detector_power_enabled = nil
  record.output_detector_power_signal = nil
  record.state = record.state or "idle"
  record.cooldown_until = record.cooldown_until or 0
  record.last_distance = platform.distance
  record.direction = record.direction or 0
  return record
end

function Drive.destroy_support(record)
  if record and record.support and record.support.valid then
    record.support.destroy()
  end
  if record then
    record.support = nil
    record.support_sample_watts = nil
    record.support_sample_demand_watts = nil
    record.support_sample_joules = nil
  end
end

function Drive.destroy_detector(record)
  if record and record.detector and record.detector.valid then
    record.detector.destroy()
  end
  if record then
    record.detector = nil
    record.detector_power = 0
    record.detector_power_ratio = 0
  end
end

function Drive.destroy_charge(record)
  if record and record.charge and record.charge.valid then
    record.charge.destroy()
  end
  if record then
    record.charge = nil
  end
end

local function destroy_power(record)
  if record and record.power and record.power.valid then
    record.power.destroy()
  end
  if record then
    record.power = nil
    record.power_sample_watts = nil
    record.power_sample_support_watts = nil
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

function Drive.destroy_companions(record)
  Drive.destroy_support(record)
  Drive.destroy_detector(record)
  Drive.destroy_charge(record)
  destroy_power(record)
  destroy_animation(record)
  destroy_circuit_output(record)
  Visuals.reset(record)
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

-- Rebuilds and scripted controller replacement can invalidate stored references. Preserve
-- exactly one colocated companion of each type and remove all other companions on the platform.
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
  local migrated_energy = 0
  for _, name in ipairs(LEGACY_POWER_NAMES) do
    for _, companion in pairs(entity.surface.find_entities_filtered({name = name})) do
      if string.find(name, "bte-warp-drive-charge-buffer", 1, true) then
        migrated_energy = math.max(migrated_energy, companion.energy)
      end
      companion.destroy()
    end
  end
  if migrated_energy > 0 then
    record.migrated_reserve_energy = math.max(record.migrated_reserve_energy or 0,
      migrated_energy)
  end
  record.support = nil
  record.detector = nil
  record.charge = nil
end

local function create_companion(record, field, name, direction)
  local companion = find_companion(record, field, name)
  if companion then
    return companion
  end
  local entity = record.entity
  if not entity or not entity.valid then
    return nil
  end
  -- Zero-size companions would snap to tile corners, while the odd-sized controller sits on a tile
  -- centre (or, in saves from the 6x6 drive, on a corner); keep them exactly on the controller.
  record[field] = entity.surface.create_entity({
    name = name,
    position = entity.position,
    direction = direction,
    force = entity.force,
    snap_to_grid = false,
    create_build_effect_smoke = false
  })
  return record[field]
end

function Drive.ensure_support(record)
  return create_companion(record, "support", SUPPORT_NAME)
end

function Drive.ensure_detector(record)
  return create_companion(record, "detector", DETECTOR_NAME)
end

function Drive.ensure_power(record)
  local power = create_companion(record, "power", POWER_NAME)
  if power and power.electric_interface_mode ~= defines.electric_interface_mode.secondary_input then
    -- Tertiary EEIs are counted as accumulator storage. Secondary input gives this draw-only
    -- interface ordinary machine semantics without exposing its one-tick buffer as storage.
    power.electric_interface_mode = defines.electric_interface_mode.secondary_input
  end
  return power
end

function Drive.ensure_animation(record)
  local entity = record and record.entity
  return create_companion(record, "animation", ANIMATION_NAME,
    entity and entity.valid and entity.direction or nil)
end

local function connect_circuit_wire(source, target, wire_id)
  -- Internal script-origin wires make the composite independent of player wire reach while
  -- retaining the controller's visible connectors for external red and green networks.
  local source_connector = source.get_wire_connector(wire_id, true)
  local target_connector = target.get_wire_connector(wire_id, true)
  if source_connector and target_connector then
    source_connector.connect_to(target_connector, false, defines.wire_origin.script)
  end
end

function Drive.ensure_circuit_output(record)
  local output = create_companion(record, "circuit_output", CIRCUIT_OUTPUT_NAME)
  local entity = record and record.entity
  if output and entity and entity.valid then
    connect_circuit_wire(entity, output, defines.wire_connector_id.circuit_red)
    connect_circuit_wire(entity, output, defines.wire_connector_id.circuit_green)
  end
  return output
end

function Drive.serialize_settings(record)
  return {
    bte_warp_drive_enabled = record.enabled,
    bte_warp_drive_circuit_enabled = record.circuit_enabled,
    bte_warp_drive_circuit_first_signal = record.circuit_first_signal,
    bte_warp_drive_circuit_comparator = record.circuit_comparator,
    bte_warp_drive_circuit_second_signal = record.circuit_second_signal,
    bte_warp_drive_circuit_constant = record.circuit_constant,
    bte_warp_drive_output_warp_enabled = record.output_warp_enabled,
    bte_warp_drive_output_warp_signal = record.output_warp_signal,
    bte_warp_drive_output_distance_enabled = record.output_distance_enabled,
    bte_warp_drive_output_distance_signal = record.output_distance_signal,
    bte_warp_drive_output_charge_enabled = record.output_charge_enabled,
    bte_warp_drive_output_charge_signal = record.output_charge_signal,
    bte_warp_drive_output_speed_enabled = record.output_speed_enabled,
    bte_warp_drive_output_speed_signal = record.output_speed_signal,
    bte_warp_drive_output_tachyon_density_enabled = record.output_tachyon_density_enabled,
    bte_warp_drive_output_tachyon_density_signal = record.output_tachyon_density_signal
  }
end

function Drive.tag_blueprint(blueprint, mapping)
  if not blueprint
      or (blueprint.object_name == "LuaItemStack" and not blueprint.valid_for_read)
      or (blueprint.object_name == "LuaRecord" and not blueprint.valid)
      or not blueprint.is_blueprint_setup() then
    return
  end
  if mapping and mapping.object_name == "LuaLazyLoadedValue" then
    -- Blueprint event mappings are event-scoped lazy values; resolve them before matching
    -- blueprint entity numbers to live controller records.
    mapping = mapping.get()
  end
  mapping = mapping or {}
  for _, blueprint_entity in pairs(blueprint.get_blueprint_entities() or {}) do
    if blueprint_entity.name == DRIVE_NAME then
      local entity = mapping[blueprint_entity.entity_number]
      local platform = entity and entity.valid and entity.surface.platform
      local record = platform and Drive.get(platform.index)
      if record then
        blueprint.set_blueprint_entity_tags(blueprint_entity.entity_number,
          Drive.serialize_settings(record))
      end
    end
  end
end

function Drive.apply_settings(record, tags)
  if not record or not tags or tags.bte_warp_drive_circuit_enabled == nil then
    return false
  end
  record.enabled = tags.bte_warp_drive_enabled ~= false
  record.circuit_enabled = tags.bte_warp_drive_circuit_enabled == true
  Drive.normalize_engagement(record)
  record.circuit_first_signal = tags.bte_warp_drive_circuit_first_signal
  record.circuit_comparator = CIRCUIT_COMPARATORS[
    CIRCUIT_COMPARATOR_INDEX[tags.bte_warp_drive_circuit_comparator] or 1]
  record.circuit_second_signal = tags.bte_warp_drive_circuit_second_signal
  record.circuit_constant = tags.bte_warp_drive_circuit_constant or 0
  record.output_warp_enabled = tags.bte_warp_drive_output_warp_enabled ~= false
  record.output_warp_signal = tags.bte_warp_drive_output_warp_signal or WARP_LEVEL_SIGNAL
  record.output_distance_enabled = tags.bte_warp_drive_output_distance_enabled == true
  record.output_distance_signal = tags.bte_warp_drive_output_distance_signal or DISTANCE_SIGNAL
  record.output_charge_enabled = tags.bte_warp_drive_output_charge_enabled ~= false
  record.output_charge_signal = tags.bte_warp_drive_output_charge_signal or CHARGE_SIGNAL
  record.output_speed_enabled = tags.bte_warp_drive_output_speed_enabled ~= false
  record.output_speed_signal = tags.bte_warp_drive_output_speed_signal or SPEED_SIGNAL
  record.output_tachyon_density_enabled = tags.bte_warp_drive_output_tachyon_density_enabled == true
  record.output_tachyon_density_signal = tags.bte_warp_drive_output_tachyon_density_signal
    or TACHYON_DENSITY_SIGNAL
  record.output_detector_power_enabled = nil
  record.output_detector_power_signal = nil
  return true
end

function Drive.register(entity, tags)
  if not entity or not entity.valid or entity.name ~= DRIVE_NAME then
    return nil
  end
  local platform = entity.surface.platform
  if not platform then
    entity.destroy({raise_destroy = true})
    return nil
  end
  local drives = Drive.records()
  local existing = drives[platform.index]
  if existing and existing.entity and existing.entity.valid and existing.entity ~= entity then
    entity.surface.spill_item_stack({
      position = entity.position,
      stack = {name = DRIVE_ITEM_NAME, count = 1},
      force = entity.force,
      allow_belts = false
    })
    entity.destroy({raise_destroy = true})
    platform.force.print({"bte-warp-drive.duplicate"})
    return nil
  end
  if existing and existing.entity ~= entity then
    Drive.destroy_companions(existing)
  end
  local record = Drive.normalize_record(existing or {}, entity, platform)
  drives[platform.index] = record
  recover_orphan_companions(record)
  Drive.ensure_animation(record)
  Drive.ensure_circuit_output(record)
  Drive.apply_settings(record, tags)
  return record
end

function Drive.register_from_event(event)
  return Drive.register(event.entity, event.tags)
end

function Drive.remove(platform_index, record)
  local drives = Drive.records()
  local current = drives[platform_index]
  if current and (not record or current == record) then
    Drive.destroy_companions(current)
    drives[platform_index] = nil
  end
end

function Drive.unregister_entity(entity)
  if not entity or entity.name ~= DRIVE_NAME then
    return
  end
  for platform_index, record in pairs(Drive.records()) do
    if record.entity == entity then
      Drive.remove(platform_index, record)
      return
    end
  end
end

function Drive.rebuild()
  Drive.init_storage()
  local old_drives = storage.drives
  local rebuilt = {}
  storage.drives = rebuilt
  for _, force in pairs(game.forces) do
    for _, platform in pairs(force.platforms) do
      local entities = platform.surface.find_entities_filtered({name = DRIVE_NAME})
      if #entities > 0 then
        local record = Drive.normalize_record(old_drives[platform.index] or {}, entities[1], platform)
        rebuilt[platform.index] = record
        -- Overlay animations may have changed with the mod version; redraw them on the next update.
        Visuals.reset(record)
        recover_orphan_companions(record)
        Drive.ensure_animation(record)
        Drive.ensure_circuit_output(record)
        for index = 2, #entities do
          entities[index].destroy({raise_destroy = true})
        end
      end
    end
  end
  for platform_index, old in pairs(old_drives) do
    if not rebuilt[platform_index] then
      Drive.destroy_companions(old)
    end
  end
end

-- The controller owns visible circuit connectors while a hidden constant combinator owns
-- their values, allowing lifecycle repair without replacing player-created wires.
function Drive.update_output_signals(record, platform, tachyon_density)
  local output = Drive.ensure_circuit_output(record)
  if not output then
    return
  end
  local behavior = output.get_or_create_control_behavior()
  local section = behavior and (behavior.get_section(1) or behavior.add_section())
  if not section then
    return
  end
  local charge = record.reserve_energy or 0
  local required = platform.weight * CHARGE_JOULES_PER_KG
  local charge_percent = required > 0 and math.min(100, math.floor(charge / required * 100)) or 0
  local remaining_distance = 0
  local connection = platform.space_connection
  if connection and platform.distance then
    remaining_distance = (record.direction < 0 and platform.distance
      or 1 - platform.distance) * connection.length
  end
  local slots = {}
  local practical = platform.force.technologies[PRACTICAL_TECH]
  practical = practical and practical.researched
  if practical and record.output_warp_enabled ~= false then
    slots[#slots + 1] = {
      signal = record.output_warp_signal or WARP_LEVEL_SIGNAL,
      value = record.state == "warp" and math.floor(record.warp_level or 1) or 0
    }
  end
  if record.output_distance_enabled then
    slots[#slots + 1] = {
      signal = record.output_distance_signal or DISTANCE_SIGNAL,
      value = math.max(0, math.min(2147483647, math.ceil(remaining_distance)))
    }
  end
  if record.output_charge_enabled ~= false then
    slots[#slots + 1] = {
      signal = record.output_charge_signal or CHARGE_SIGNAL,
      value = charge_percent
    }
  end
  if practical and record.output_speed_enabled ~= false then
    local speed = (platform.speed or 0) * TICKS_PER_SECOND
    if record.state == "warp" then
      speed = speed * WARP_BOOST_PER_LEVEL * (record.warp_level or 1)
    end
    slots[#slots + 1] = {
      signal = record.output_speed_signal or SPEED_SIGNAL,
      value = math.floor(speed)
    }
  end
  if not practical and record.output_tachyon_density_enabled then
    slots[#slots + 1] = {
      signal = record.output_tachyon_density_signal or TACHYON_DENSITY_SIGNAL,
      value = math.max(0, math.min(2147483647, math.floor(tachyon_density or 0)))
    }
  end
  for index = 1, 5 do
    section.clear_slot(index)
  end
  for index, slot in ipairs(slots) do
    local signal = slot.signal
    section.set_slot(index, {
      value = {type = signal.type, name = signal.name, quality = "normal"},
      min = slot.value
    })
  end
end

return Drive
