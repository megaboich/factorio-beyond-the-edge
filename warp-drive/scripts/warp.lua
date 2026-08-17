local Drive = require("scripts.drive")

local Warp = {}

local PRACTICAL_TECH = "practical-warp-drive"
local CHARGE_JOULES_PER_KG = 100
local SUPPORT_WATTS_PER_KG = 10
local SUPPORT_POWER_TOLERANCE = 0.999
local WARP_RESERVE_SECONDS = 10
local ENTRY_RESERVE_RATIO = 0.1
local SPEED_EXIT_GRACE_TICKS = 5 * 60
local WARP_STREAK_COUNT = 48
local LIGHTNING_NAME = "warp-drive-lightning"
local LIGHTNING_DURATION_TICKS = 36
local LIGHTNING_DENSITY_TILES = 32 * 32
local WARP_EFFECT_FIELD_MARGIN = 64
local WARP_ENTER_SOUND = "warp-drive-enter"
local WARP_EXIT_SOUND = "warp-drive-exit"
local POWER_NAME = "warp-drive-power-interface"
local DETECTOR_REFERENCE_POWER_WATTS = 200000000
local DETECTOR_MAX_POWER_WATTS = 1000000000
local DETECTOR_PROBE_WATTS = 10000000
local DETECTOR_SHORTFALL_TOLERANCE_WATTS = 100000
local MINIMUM_SPEED = 50
local WARP_BOOST_PER_LEVEL = 10
local WARP_LEVEL_SECONDS = 2
local ENDPOINT_MARGIN_KM = 1000
local COOLDOWN_TICKS = 600
local UPDATE_TICKS = 10
local TICKS_PER_SECOND = 60

local function platform_speed_km_per_second(platform)
  return (platform.speed or 0) * TICKS_PER_SECOND
end

local function engine_warp_limit(platform)
  return math.max(0, platform_speed_km_per_second(platform)) / MINIMUM_SPEED
end

local function warp_multiplier(level)
  return WARP_BOOST_PER_LEVEL * math.max(0, level or 0)
end

local function effective_speed_km_per_second(platform, level)
  local speed = platform_speed_km_per_second(platform)
  return speed * (level and warp_multiplier(level) or 1)
end

-- LuaSpacePlatform.weight is already expressed in kilograms. Prototype weight constants use
-- grams internally, but applying that data-stage conversion here under-scales runtime loads.
local function platform_weight_kg(platform)
  return platform.weight
end

local function support_watts_per_level(platform)
  return platform_weight_kg(platform) * SUPPORT_WATTS_PER_KG
end

local function support_watts(platform, level)
  return support_watts_per_level(platform) * level
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

-- LuaSpacePlatform.speed has no travel sign. Distance deltas are therefore the authoritative
-- direction sample; retaining the last nonzero sign also bridges ticks where distance stalls.
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

-- Warp changes normalized connection distance directly, bypassing Factorio's natural arrival
-- handling. Keep the final 1,000 km unwarped so normal travel completes the endpoint transition.
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
  return technology ~= nil and technology.researched
end

local function circuit_engagement_satisfied(record)
  if not record.circuit_enabled then
    return true
  end
  local entity = record.entity
  if not entity or not entity.valid then
    return false
  end
  if not record.circuit_first_signal then
    return false
  end
  local first = entity.get_signal(
    record.circuit_first_signal,
    defines.wire_connector_id.circuit_red,
    defines.wire_connector_id.circuit_green
  )
  local second = record.circuit_second_signal and entity.get_signal(
    record.circuit_second_signal,
    defines.wire_connector_id.circuit_red,
    defines.wire_connector_id.circuit_green
  ) or math.floor(record.circuit_constant or 0)
  local comparator = record.circuit_comparator or ">"
  if comparator == ">" then
    return first > second
  elseif comparator == "<" then
    return first < second
  elseif comparator == "=" then
    return first == second
  elseif comparator == "≥" then
    return first >= second
  elseif comparator == "≤" then
    return first <= second
  end
  return first ~= second
end

local function engagement_satisfied(record)
  return record.enabled or (record.circuit_enabled and circuit_engagement_satisfied(record))
end

local function disable_power(record, power, disabled)
  power.power_usage = 0
  power.input_flow_limit = 0
  power.electric_buffer_size = 1
  power.disabled_by_script = disabled
  record.power_sample_watts = nil
end

local function exit_warp(record, reason)
  local was_warp = record.state == "warp"
  if was_warp then
    record.state = "idle"
    record.cooldown_until = game.tick + COOLDOWN_TICKS
    record.last_exit_reason = reason or "unknown"
    local entity = record.entity
    if entity and entity.valid then
      -- Omitting position makes the transition audible to every player on this platform
      -- surface instead of attenuating it around the controller.
      entity.surface.play_sound({path = WARP_EXIT_SOUND})
    end
  end
  Drive.destroy_support(record)
  record.warp_level = nil
  record.requested_warp_level = nil
  record.warp_target = nil
  record.support_power = 0
  record.support_demand_watts = nil
  record.warp_ramp_state = nil
  record.speed_exit_at = nil
  record.warp_warning = nil
  record.lightning_bounds = nil
  record.reserve_energy = was_warp and 0 or (record.reserve_energy or 0)
  if record.power and record.power.valid then
    -- Keep the mandatory 1 J working buffer stable. Emptying a larger previous buffer here
    -- makes Factorio refill it even with zero logical usage, creating an idle power spike.
    disable_power(record, record.power, game.tick < record.cooldown_until)
  end
end

local function can_prepare(record, platform, direction)
  return engagement_satisfied(record)
    and practical_researched(platform.force)
    and platform.space_connection ~= nil
    and platform.distance ~= nil
    and not platform.paused
    and platform_speed_km_per_second(platform) >= MINIMUM_SPEED
    and endpoint_clear(platform, direction)
    and game.tick >= record.cooldown_until
end

local function immediate_exit_reason(record, platform, direction)
  if not record.enabled then
    if not record.circuit_enabled then
      return "control-disabled"
    elseif not circuit_engagement_satisfied(record) then
      return "circuit-condition"
    end
  end
  if not platform.space_connection or platform.distance == nil or platform.paused then
    return "travel-stopped"
  end
  if not endpoint_clear(platform, direction) then
    return "endpoint-clearance"
  end
end

-- Electric statistics accumulate this prototype's consumed joules. Each platform permits one
-- drive, so the delta measures local delivery without using buffer energy as a meter.
local function sample_power(record, power)
  if not power then
    record.support_power = 0
    return 0, 0
  end
  local subnetwork = power.electric_network
  local network = subnetwork and subnetwork.parent_network
  local statistics = network and network.statistics
  local input_count = statistics and statistics.get_input_count(POWER_NAME) or 0
  local network_id = subnetwork and subnetwork.id
  local elapsed = record.power_sample_tick and game.tick - record.power_sample_tick or 0
  local delivered = 0
  local sampled = record.power_sample_watts ~= nil and elapsed > 0
      and network_id == record.power_sample_network_id
      and input_count >= (record.power_sample_input_count or 0)
  if sampled then
    delivered = (input_count - record.power_sample_input_count)
      * TICKS_PER_SECOND / elapsed
  end
  record.power_sample_input_count = input_count
  record.power_sample_network_id = network_id
  record.power_sample_tick = game.tick
  if record.power_sample_watts == nil then
    record.support_power = 0
    return 0, 0, false
  end
  delivered = math.max(0, math.min(record.power_sample_watts, delivered))
  record.support_power = delivered
  return delivered, math.min(delivered, record.power_sample_support_watts or delivered), sampled
end

-- Runtime electric-flow fields use joules per tick. The interface requests exact logical demand
-- as an ordinary machine load; the serialized reserve is never exposed to the electric network.
local function request_power(record, power, watts, support_watts)
  power.disabled_by_script = false
  local joules_per_tick = watts / TICKS_PER_SECOND
  power.power_usage = joules_per_tick
  power.electric_buffer_size = math.max(1, joules_per_tick)
  power.input_flow_limit = joules_per_tick
  record.power_sample_watts = watts
  record.power_sample_support_watts = support_watts or watts
end

local function recharge_watts(platform, reserve_energy, charge)
  local missing_watts = math.max(0, charge - reserve_energy)
    * TICKS_PER_SECOND / UPDATE_TICKS
  return math.min(support_watts(platform, 1), missing_watts)
end

-- Experimental research uses the same private interface in draw-only mode.
local function initialize_detector_mode(record, power)
  if record.power_mode ~= "experimental" then
    power.energy = 0
    record.power_sample_watts = nil
    record.power_mode = "experimental"
    record.detector_request_watts = DETECTOR_MAX_POWER_WATTS
    record.migrated_reserve_energy = nil
    record.reserve_energy = 0
  end
end

local function update_detector(record, power)
  if not power then
    record.detector_power_ratio = 0
    record.detector_power = 0
    return
  end
  initialize_detector_mode(record, power)
  local requested = record.detector_request_watts or DETECTOR_MAX_POWER_WATTS
  local delivered, _, sampled = sample_power(record, power)
  record.detector_power = math.min(DETECTOR_MAX_POWER_WATTS, delivered)
  record.detector_power_ratio = record.detector_power / DETECTOR_REFERENCE_POWER_WATTS
  if sampled then
    if delivered + DETECTOR_SHORTFALL_TOLERANCE_WATTS < requested then
      requested = delivered
    else
      requested = math.min(DETECTOR_MAX_POWER_WATTS, requested + DETECTOR_PROBE_WATTS)
    end
  end
  record.detector_request_watts = requested
  request_power(record, power, requested, 0)
end

-- Asteroid chunks and asteroid entities are separate runtime objects. Clearing both every
-- update prevents newly spawned hazards from crossing subspace before the next 10-tick sample.
local function clear_warp_asteroids(platform)
  platform.destroy_asteroid_chunks({})
  for _, asteroid in pairs(platform.surface.find_entities_filtered({type = "asteroid"})) do
    asteroid.destroy()
  end
end

-- Cache occupied extents outside the 10-tick update so large platforms get a proportional field.
local function update_warp_effect_bounds(record, platform)
  local left
  local right
  local top
  local bottom
  for _, tile in pairs(platform.surface.find_tiles_filtered({
    name = "empty-space",
    invert = true
  })) do
    if tile.prototype.is_foundation then
      local x = tile.position.x
      local y = tile.position.y
      left = left and math.min(left, x) or x
      right = right and math.max(right, x + 1) or x + 1
      top = top and math.min(top, y) or y
      bottom = bottom and math.max(bottom, y + 1) or y + 1
    end
  end
  if not left then
    local hub = platform.hub
    local center = hub and hub.valid and hub.position or record.entity.position
    left, right = center.x - 16, center.x + 16
    top, bottom = center.y - 16, center.y + 16
  end
  record.lightning_bounds = {
    left = left - WARP_EFFECT_FIELD_MARGIN,
    right = right + WARP_EFFECT_FIELD_MARGIN,
    top = top - WARP_EFFECT_FIELD_MARGIN,
    bottom = bottom + WARP_EFFECT_FIELD_MARGIN
  }
end

local function render_warp_streaks(record, platform)
  local bounds = record.lightning_bounds
  if not bounds then
    update_warp_effect_bounds(record, platform)
    bounds = record.lightning_bounds
  end
  local phase = math.floor(game.tick / UPDATE_TICKS)
  local sign = record.direction < 0 and 1 or -1
  local width = bounds.right - bounds.left
  local height = bounds.bottom - bounds.top
  for index = 1, WARP_STREAK_COUNT do
    local x = bounds.left + ((index * 73 + platform.index * 29) % 997) / 996 * width
    local y = bounds.top + ((index * 97 + phase * 23) % 991) / 990 * height
    local length = 8 + index % 8 * 3
    rendering.draw_line({
      color = {r = 0.15, g = 0.65 + index % 3 * 0.08, b = 1, a = 0.35 + index % 4 * 0.1},
      width = 1.5 + index % 3,
      from = {x, y},
      to = {x + (index % 3 - 1) * 0.35, y + sign * length},
      surface = platform.surface,
      time_to_live = UPDATE_TICKS + 1,
      draw_on_ground = false
    })
  end
end

local function spawn_lightning(platform, bounds, count)
  for _ = 1, count do
    -- execute_lightning rejects space-platform surfaces because their planet has no lightning
    -- generator. Direct creation is the engine-supported path also used by menu simulations.
    platform.surface.create_entity({
      name = LIGHTNING_NAME,
      position = {
        x = bounds.left + math.random() * (bounds.right - bounds.left),
        y = bounds.top + math.random() * (bounds.bottom - bounds.top)
      },
      force = "neutral"
    })
  end
end

-- Starts are derived from the 36-tick lifetime to average one playing animation per 32x32 tiles.
-- Platform bounds work in freely panned remote view, whose camera position is not exposed.
local function render_warp_lightning(record, platform)
  local bounds = record.lightning_bounds
  if not bounds then
    update_warp_effect_bounds(record, platform)
    bounds = record.lightning_bounds
  end
  local target_count = (bounds.right - bounds.left) * (bounds.bottom - bounds.top)
    / LIGHTNING_DENSITY_TILES
  local expected_starts = target_count * UPDATE_TICKS / LIGHTNING_DURATION_TICKS
  local count = math.floor(expected_starts)
  if math.random() < expected_starts - count then
    count = count + 1
  end
  spawn_lightning(platform, bounds, count)
end

local function render_warp_effect(record, platform)
  render_warp_streaks(record, platform)
  render_warp_lightning(record, platform)
end

-- Entry retains ten percent of the activation charge as support reserve. A new electric sink needs
-- two mod updates before its first complete energy sample is meaningful, so support shortfall
-- checks are deferred while Factorio attaches and services it.
local function enter_warp(record, platform)
  local charge = required_charge(platform)
  local buffer = Drive.ensure_power(record)
  if not buffer or (record.reserve_energy or 0) + 1 < charge then
    return false
  end
  record.reserve_energy = charge * ENTRY_RESERVE_RATIO
  record.state = "warp"
  record.warp_level = 1
  record.requested_warp_level = 1
  record.warp_target = engine_warp_limit(platform)
  record.support_power = 0
  record.warp_ramp_state = "stabilizing"
  record.speed_exit_at = nil
  record.warp_warning = nil
  record.last_exit_reason = nil
  local support_demand = support_watts(platform, 1)
  record.support_demand_watts = support_demand
    + recharge_watts(platform, record.reserve_energy, charge)
  request_power(record, buffer, record.support_demand_watts, support_demand)
  record.support_check_after = game.tick + UPDATE_TICKS * 2
  record.entity.surface.play_sound({path = WARP_ENTER_SOUND})
  clear_warp_asteroids(platform)
  update_warp_effect_bounds(record, platform)
  render_warp_effect(record, platform)
  return true
end

local function update_experimental(record)
  if record.state == "warp" then
    exit_warp(record, "research-revoked")
  end
  local power = Drive.ensure_power(record)
  if power then
    initialize_detector_mode(record, power)
  end
  if engagement_satisfied(record) then
    update_detector(record, power)
  else
    if power then
      disable_power(record, power, true)
    end
    record.detector_request_watts = DETECTOR_MAX_POWER_WATTS
    record.detector_power = 0
    record.detector_power_ratio = 0
  end
  record.state = record.detector_power_ratio > 0.01 and "detecting" or "detector-offline"
end

local function update_active_warp(record, platform, direction, charge_buffer)
  local delivered_watts, delivered_support_watts = sample_power(record, charge_buffer)
  local immediate_reason = immediate_exit_reason(record, platform, direction)
  if immediate_reason then
    exit_warp(record, immediate_reason)
    return
  end
  local speed = platform_speed_km_per_second(platform)
  if speed < MINIMUM_SPEED then
    record.speed_exit_at = record.speed_exit_at or game.tick + SPEED_EXIT_GRACE_TICKS
    record.warp_warning = "speed"
    if game.tick >= record.speed_exit_at then
      exit_warp(record, "insufficient-speed")
      return
    end
  else
    record.speed_exit_at = nil
    record.warp_warning = nil
  end
  local charge = required_charge(platform)
  local delivered_recharge_watts = math.max(0, delivered_watts - delivered_support_watts)
  record.reserve_energy = math.min(charge, (record.reserve_energy or 0)
    + delivered_recharge_watts * UPDATE_TICKS / TICKS_PER_SECOND)
  -- During the grace period, retain Warp-1 rather than collapsing the level to zero.
  local engine_limit = math.max(record.speed_exit_at and 1 or 0, engine_warp_limit(platform))
  local level = math.min(record.warp_level or 1, engine_limit)
  local requested_level = record.requested_warp_level or level
  local power_limited = false
  local reserve_active = false
  local target_level = engine_limit
  -- Active support is allocated before reserve replenishment. Delivered power determines
  -- whether the current and next levels are sustainable; only delivery beyond support refills.
  if game.tick >= (record.support_check_after or 0) then
    local watts_per_level = support_watts_per_level(platform)
    local power_limit = watts_per_level > 0 and delivered_support_watts / watts_per_level or 0
    local required_watts = support_watts(platform, level)
    if delivered_support_watts < required_watts * SUPPORT_POWER_TOLERANCE then
      -- Unsatisfied usage drains only the interface's private reserve. Other ship machinery
      -- cannot consume it because the interface has no electrical output.
      reserve_active = true
      power_limited = true
      target_level = math.min(engine_limit, power_limit)
      requested_level = level
      local deficit = required_watts > 0
        and math.max(0, math.min(1, 1 - delivered_support_watts / required_watts)) or 1
      record.reserve_energy = math.max(0, record.reserve_energy
        - charge * deficit * UPDATE_TICKS / (WARP_RESERVE_SECONDS * TICKS_PER_SECOND))
      if record.reserve_energy <= 1 then
        exit_warp(record, "reserve-depleted")
        return
      end
      if not record.warp_warning then
        record.warp_warning = "power"
      end
    elseif delivered_support_watts
        >= support_watts(platform, requested_level) * SUPPORT_POWER_TOLERANCE then
      level = math.min(requested_level, engine_limit)
    else
      power_limited = true
      target_level = math.min(engine_limit, power_limit)
    end
  end
  local level_step = UPDATE_TICKS / TICKS_PER_SECOND / WARP_LEVEL_SECONDS
  local next_level = reserve_active and level or math.min(engine_limit, level + level_step)
  record.warp_level = level
  record.requested_warp_level = next_level
  record.warp_target = target_level
  if reserve_active then
    record.warp_ramp_state = "reserve"
  elseif power_limited then
    record.warp_ramp_state = "power-limited"
  elseif level + 0.0001 < engine_limit then
    record.warp_ramp_state = "accelerating"
  else
    record.warp_ramp_state = "engine-limited"
  end
  local support_demand = support_watts(platform, next_level)
  record.support_demand_watts = support_demand
    + recharge_watts(platform, record.reserve_energy, charge)
  request_power(record, charge_buffer, record.support_demand_watts, support_demand)
  -- Platform distance is a 0..1 fraction of connection.length. Add only the speed above
  -- natural travel, because Factorio advances the ordinary one-times speed itself.
  local connection = platform.space_connection
  local margin = connection_margin(platform)
  local extra_distance = direction * (warp_multiplier(level) - 1) * platform.speed
    * UPDATE_TICKS / connection.length
  local boundary = direction > 0 and 1 - margin or margin
  local target = platform.distance + extra_distance
  if (direction > 0 and target >= boundary) or (direction < 0 and target <= boundary) then
    platform.distance = boundary
    exit_warp(record, "endpoint-clearance")
  else
    platform.distance = target
    record.last_distance = target
    clear_warp_asteroids(platform)
    render_warp_effect(record, platform)
  end
end

local function update_cooldown(record, charge_buffer)
  Drive.destroy_support(record)
  disable_power(record, charge_buffer, true)
  record.reserve_energy = 0
  record.state = "cooldown"
end

local function reset_preparation(record, charge_buffer, reason)
  Drive.destroy_support(record)
  disable_power(record, charge_buffer, true)
  record.reserve_energy = 0
  record.support_power = 0
  record.support_demand_watts = nil
  record.state = "idle"
  if reason then
    record.last_exit_reason = reason
  end
end

local function update_idle_or_charging(record, platform, direction, charge_buffer)
  record.detector_power = 0
  record.detector_power_ratio = 0
  if not engagement_satisfied(record) then
    -- Interrupted preparation loses its accumulated reserve; reaching full charge must be one
    -- continuous final step after every other entry requirement is satisfied.
    reset_preparation(record, charge_buffer)
    return
  end
  local charge = required_charge(platform)
  if not can_prepare(record, platform, direction) then
    local reason = record.state == "charging"
      and platform_speed_km_per_second(platform) < MINIMUM_SPEED
      and "charging-speed-interrupted" or nil
    reset_preparation(record, charge_buffer, reason)
    return
  end
  -- Charging requests Warp-1 support power. Since reserve capacity is ten seconds of that
  -- mass-scaled demand, adequate generation fills an empty reserve in exactly ten seconds.
  charge_buffer.disabled_by_script = false
  record.reserve_energy = math.min(record.reserve_energy or 0, charge)
  if record.reserve_energy + 1 >= charge then
    enter_warp(record, platform)
  else
    local delivered_watts = sample_power(record, charge_buffer)
    record.reserve_energy = math.min(charge, record.reserve_energy
      + delivered_watts * UPDATE_TICKS / TICKS_PER_SECOND)
    record.support_demand_watts = support_watts(platform, 1)
    request_power(record, charge_buffer, record.support_demand_watts, 0)
    record.state = "charging"
  end
end

function Warp.update(record)
  local entity = record.entity
  if not entity or not entity.valid then
    Drive.destroy_companions(record)
    return false
  end
  local platform = entity.surface.platform
  if not platform or platform.index ~= record.platform_index then
    Drive.destroy_companions(record)
    return false
  end
  Drive.ensure_animation(record)
  Drive.ensure_circuit_output(record)
  local direction = update_direction(record, platform)
  if not practical_researched(platform.force) then
    update_experimental(record)
    return true
  end
  Drive.destroy_detector(record)
  local charge_buffer = Drive.ensure_power(record)
  if not charge_buffer then
    record.state = "charging"
    return true
  end
  local charge = required_charge(platform)
  if record.power_mode ~= "practical" then
    record.reserve_energy = math.min(record.migrated_reserve_energy or 0, charge)
    record.migrated_reserve_energy = nil
    record.power_sample_watts = nil
    record.detector_request_watts = nil
    record.power_mode = "practical"
  end
  if record.state == "warp" then
    update_active_warp(record, platform, direction, charge_buffer)
  elseif game.tick < record.cooldown_until then
    update_cooldown(record, charge_buffer)
  else
    update_idle_or_charging(record, platform, direction, charge_buffer)
  end
  return true
end

function Warp.snapshot(record)
  local entity = record.entity
  local platform = entity and entity.valid and entity.surface.platform
  if not platform then
    return nil
  end
  local practical = practical_researched(entity.force)
  local connection = platform.space_connection
  local destination
  local route_from
  local route_to
  local remaining_km = 0
  if connection and platform.distance then
    destination = record.direction < 0 and connection.from or connection.to
    route_from = connection.from
    route_to = connection.to
    if record.direction < 0 then
      route_from, route_to = route_to, route_from
    end
    remaining_km = (record.direction < 0 and platform.distance
      or 1 - platform.distance) * connection.length
  end
  local closest_endpoint
  local endpoint_distance_km = 0
  if connection and platform.distance then
    if platform.distance <= 0.5 then
      closest_endpoint = connection.from
      endpoint_distance_km = platform.distance * connection.length
    else
      closest_endpoint = connection.to
      endpoint_distance_km = (1 - platform.distance) * connection.length
    end
  end
  local charge = required_charge(platform)
  local stored_charge = practical and math.min(record.reserve_energy or 0, charge) or 0
  local speed = platform_speed_km_per_second(platform)
  local support_required = support_watts(platform, math.max(1, record.warp_level or 1))
  local circuit_active = circuit_engagement_satisfied(record)
  local control_active = engagement_satisfied(record)
  return {
    practical = practical,
    location = platform.space_location,
    route_from = route_from,
    route_to = route_to,
    destination = destination,
    remaining_km = remaining_km,
    travel_active = connection ~= nil and platform.distance ~= nil and not platform.paused,
    clearance = endpoint_clear(platform, record.direction),
    closest_endpoint = closest_endpoint,
    endpoint_distance_km = endpoint_distance_km,
    endpoint_blocked = endpoint_distance_km <= ENDPOINT_MARGIN_KM,
    circuit_active = circuit_active,
    control_active = control_active,
    preparation_ready = can_prepare(record, platform, record.direction),
    required_charge = charge,
    stored_charge = stored_charge,
    charge_ratio = charge > 0 and math.min(1, stored_charge / charge) or 0,
    speed = speed,
    speed_ready = speed >= MINIMUM_SPEED,
    effective_speed = effective_speed_km_per_second(platform,
      record.state == "warp" and (record.warp_level or 1) or nil),
    warp_boost = record.state == "warp" and warp_multiplier(record.warp_level) or 1,
    support_required = support_required,
    power_ready = (record.support_power or 0)
      >= support_required * SUPPORT_POWER_TOLERANCE,
    cooldown_ready = game.tick >= record.cooldown_until,
    cooldown_seconds = math.max(0, record.cooldown_until - game.tick) / TICKS_PER_SECOND
  }
end

function Warp.engagement_changed(record, condition_only)
  if condition_only then
    if record.circuit_enabled and not circuit_engagement_satisfied(record) then
      exit_warp(record, "circuit-condition")
    end
  elseif not engagement_satisfied(record) then
    local reason = record.circuit_enabled and "circuit-condition" or "control-disabled"
    exit_warp(record, reason)
  end
end

function Warp.platform_tiles_changed(event)
  local surface = game.get_surface(event.surface_index)
  local platform = surface and surface.platform
  local record = platform and Drive.get(platform.index)
  if record and record.state == "warp" then
    update_warp_effect_bounds(record, platform)
  end
end

return Warp
