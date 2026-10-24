local Anomalies = require("scripts.anomalies")
local Drive = require("scripts.drive")
local Shockwaves = require("scripts.shockwaves")
local Visuals = require("scripts.visuals")

local Warp = {}

local PRACTICAL_TECH = "bte-practical-warp-drive"
local CHARGE_JOULES_PER_KG = 100
local SUPPORT_WATTS_PER_KG = 10
local SUPPORT_POWER_TOLERANCE = 0.999
local WARP_RESERVE_SECONDS = 10
local ENTRY_RESERVE_RATIO = 0.1
local SPEED_EXIT_GRACE_TICKS = 5 * 60
-- Streaks on screen: one per this many tiles of effect field, at least 48, at most 900.
local WARP_STREAK_TILES = 512
local WARP_STREAK_MIN = 48
local WARP_STREAK_MAX = 900
-- Streak particles (prototypes/entities.lua): their life in ticks, and their speed south in tiles
-- per tick, 50% faster than the earlier 3.7 tiles per 10 ticks.
local WARP_STREAK_NAME = "bte-warp-drive-streak"
local WARP_STREAK_LIFE = 120
local WARP_STREAK_SPEED = 0.555
local LIGHTNING_NAME = "bte-warp-drive-lightning"
-- A strike draws its cloud at the entity position and its bolt this many tiles south of it,
-- the length of the prototypes' source_offset.
local LIGHTNING_BOLT_LENGTH = 25
-- Ship-wide activation shockwaves (scripts/shockwaves.lua) grow to the smallest of these reaches,
-- in tiles, that covers the platform, or further to sweep away every asteroid present at warp
-- entry, up to SHOCKWAVE_MAX_REACH.
local SHOCKWAVE_REACHES = {32, 64, 128, 256}
local SHOCKWAVE_MAX_REACH = 512
-- Lightning strikes only around the drive: each bolt lands within LIGHTNING_DRIVE_RADIUS of it.
local LIGHTNING_DRIVE_RADIUS = 10
-- Chance per 10-tick update of a strike near the drive: about one every 1.7 seconds.
local LIGHTNING_DRIVE_STRIKE_CHANCE = 0.1
-- Effects fill this far around the platform, beyond what the most zoomed-out game view shows of
-- open space around a ship.
local WARP_EFFECT_FIELD_MARGIN = 128
local CHARGE_SOUND_COUNT = 20
local CHARGE_SOUND_TICKS = 30
local WARP_ACTIVATION_SOUND = "bte-warp-drive-activation"
local WARP_DEACTIVATION_SOUND = "bte-warp-drive-deactivation"
local FAILED_ACTIVATION_COOLDOWN_TICKS = 5 * 60
-- Length of warp-activation.ogg; the background loop starts where its tail hands off.
local WARP_ACTIVATION_SOUND_TICKS = 5 * 60
local WARP_BACKGROUND_TICKS = 6 * 60
local POWER_NAME = "bte-warp-drive-power-interface"
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

-- True when a condition is enabled, has a first signal, and holds on the summed red and green
-- networks. A disabled or incomplete condition is never true.
local function condition_true(record, condition)
  if not condition or not condition.enabled or not condition.first_signal then
    return false
  end
  local entity = record.entity
  if not entity or not entity.valid then
    return false
  end
  local first = entity.get_signal(
    condition.first_signal,
    defines.wire_connector_id.circuit_red,
    defines.wire_connector_id.circuit_green
  )
  local second = condition.second_signal and entity.get_signal(
    condition.second_signal,
    defines.wire_connector_id.circuit_red,
    defines.wire_connector_id.circuit_green
  ) or math.floor(condition.constant or 0)
  local comparator = condition.comparator or ">"
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

local function activate_requested(record)
  return condition_true(record, record.activate)
end

-- The deactivate condition wins over the activate condition and the Engage button.
local function deactivate_requested(record)
  return condition_true(record, record.deactivate)
end

local function play_global_sound(record, path)
  local entity = record.entity
  if entity and entity.valid then
    -- Omitting position makes drive audio global on the platform surface instead of
    -- attenuating it around the controller.
    entity.surface.play_sound({path = path})
  end
end

local function reset_charge_sound(record)
  record.charge_sound_next_tick = nil
  record.charge_sound_step = nil
end


-- Factorio cannot stop or retain runtime sounds. Half-second one-shots therefore emulate a
-- loop and only select a new charge step at a file boundary, avoiding mid-waveform clicks.
local function update_charge_sound(record, platform)
  if record.state ~= "charging" then
    reset_charge_sound(record)
    return
  end
  if record.charge_sound_next_tick and game.tick < record.charge_sound_next_tick then
    return
  end
  local charge = required_charge(platform)
  local ratio = charge > 0 and math.min(1, (record.reserve_energy or 0) / charge) or 0
  -- The reserve grows in 10-tick increments, so at full power each half-second boundary lands
  -- exactly on a step edge. Rounding before flooring keeps float error (0.45 * 20 = 8.9999...)
  -- from repeating one step and then skipping the next.
  local step = math.min(CHARGE_SOUND_COUNT,
    math.floor(ratio * CHARGE_SOUND_COUNT + 0.000001) + 1)
  play_global_sound(record, string.format("bte-warp-drive-buzz-%02d", step))
  record.charge_sound_step = step
  record.charge_sound_next_tick = game.tick + CHARGE_SOUND_TICKS
end

local function reset_warp_background_sound(record)
  record.warp_sound_next_tick = nil
  record.warp_background_sound_index = nil
  Drive.destroy_field_hum(record)
end

-- The activation's last seconds fade in the end of the synthesized background loop. Segment
-- 01 begins exactly when activation ends, then the two six-second phase-contiguous files alternate.
local function start_warp_sound(record)
  reset_charge_sound(record)
  play_global_sound(record, WARP_ACTIVATION_SOUND)
  record.warp_background_sound_index = 1
  record.warp_sound_next_tick = game.tick + WARP_ACTIVATION_SOUND_TICKS
end

local function update_warp_background_sound(record)
  if record.state ~= "warp" then
    reset_warp_background_sound(record)
    return
  end
  -- Fades in under the activation; also restores the hum after a rebuild or in older saves.
  Drive.ensure_field_hum(record)
  if not record.warp_sound_next_tick then
    -- An active save from before custom audio has no recoverable playback phase. Start its
    -- background at a segment boundary rather than guessing partway through a sound.
    record.warp_background_sound_index = 1
    record.warp_sound_next_tick = game.tick
  end
  if game.tick < record.warp_sound_next_tick then
    return
  end
  local index = record.warp_background_sound_index or 1
  play_global_sound(record, string.format("bte-warp-drive-background-%02d", index))
  record.warp_background_sound_index = index == 1 and 2 or 1
  record.warp_sound_next_tick = game.tick + WARP_BACKGROUND_TICKS
end

local function disable_power(record, power, disabled)
  power.power_usage = 0
  power.input_flow_limit = 0
  power.electric_buffer_size = 1
  power.disabled_by_script = disabled
  record.power_sample_watts = nil
end

local function start_cooldown(record, ticks, reason)
  record.cooldown_until = math.max(record.cooldown_until or 0, game.tick + ticks)
  record.last_exit_reason = reason
end

local function start_failed_activation(record, reason)
  local step = record.state == "charging" and record.charge_sound_step
  if not step then
    return false
  end
  play_global_sound(record, string.format("bte-warp-drive-failed-activation-%02d", step))
  start_cooldown(record, FAILED_ACTIVATION_COOLDOWN_TICKS,
    reason or "activation-interrupted")
  reset_charge_sound(record)
  record.reserve_energy = 0
  record.state = "cooldown"
  return true
end

local function exit_warp(record, reason)
  local was_warp = record.state == "warp"
  if was_warp then
    record.state = "idle"
    start_cooldown(record, COOLDOWN_TICKS, reason or "unknown")
    play_global_sound(record, WARP_DEACTIVATION_SOUND)
  else
    start_failed_activation(record, reason)
  end
  reset_charge_sound(record)
  reset_warp_background_sound(record)
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
  record.asteroid_sweep = nil
  Shockwaves.cancel(record)
  record.reserve_energy = was_warp and 0 or (record.reserve_energy or 0)
  if record.power and record.power.valid then
    -- Keep the mandatory 1 J working buffer stable. Emptying a larger previous buffer here
    -- makes Factorio refill it even with zero logical usage, creating an idle power spike.
    disable_power(record, record.power, game.tick < record.cooldown_until)
  end
end

-- Every entry requirement except the reserve itself: charging may begin, or continue, only
-- while these all hold.
local function prerequisites_met(record, platform, direction)
  return practical_researched(platform.force)
    and platform.space_connection ~= nil
    and platform.distance ~= nil
    and not platform.paused
    and platform_speed_km_per_second(platform) >= MINIMUM_SPEED
    and endpoint_clear(platform, direction)
    and game.tick >= record.cooldown_until
end

local function immediate_exit_reason(record, platform, direction)
  if deactivate_requested(record) then
    return "circuit-deactivate"
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

-- Samples the adaptive detector demand and requests the next one. Both modes share it: before
-- Practical research for the research acceleration, afterwards for the Tachyon Science Boost
-- while the drive is idle.
local function update_detector(record, power)
  if not power then
    record.detector_power_ratio = 0
    record.detector_power = 0
    return
  end
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

local function stop_detector(record, power)
  if power then
    disable_power(record, power, true)
  end
  record.detector_request_watts = DETECTOR_MAX_POWER_WATTS
  record.detector_power = 0
  record.detector_power_ratio = 0
end

-- The Start and Stop buttons latch the detector; its conditions set and reset that latch while
-- they hold, the stop condition taking precedence.
local function update_detector_latch(record)
  if condition_true(record, record.detector_stop) then
    record.detector_on = false
  elseif condition_true(record, record.detector_start) then
    record.detector_on = true
  end
end

-- Asteroid chunks and asteroid entities are separate runtime objects. During warp both are
-- cleared every tick (Warp.tick): the platform keeps spawning them at the edge of its asteroid
-- field, and anything left until the 10-tick update was drawn for up to ten frames, its outline
-- blinking against the bright anomalies behind it.
local function clear_warp_asteroids(platform)
  platform.destroy_asteroid_chunks({})
  for _, asteroid in pairs(platform.surface.find_entities_filtered({type = "asteroid"})) do
    asteroid.destroy()
  end
end

-- At warp entry the activation shockwave sweeps the asteroids away instead: each vanishes the
-- tick the ring's oval front reaches it.
local function sweep_warp_asteroids(platform, center, radius)
  local depth = radius * Shockwaves.ROUND_DEPTH
  local area = {{center.x - radius, center.y - depth}, {center.x + radius, center.y + depth}}
  for _, asteroid in pairs(platform.surface.find_entities_filtered({type = "asteroid", area = area})) do
    if Shockwaves.oval_distance(center, asteroid.position) <= radius then
      asteroid.destroy()
    end
  end
  for _, chunk in pairs(platform.find_asteroid_chunks_filtered({area = area})) do
    if Shockwaves.oval_distance(center, chunk.position) <= radius then
      platform.destroy_asteroid_chunks({position = chunk.position, limit = 1})
    end
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

-- Rounds an expected number of starts per update up or down at random, keeping its average.
local function random_count(expected)
  local count = math.floor(expected)
  if math.random() < expected - count then
    count = count + 1
  end
  return count
end

-- Streaks are particles the engine moves every tick, so they glide smoothly; each update only
-- spawns enough at random places to keep about `count` alive. They always head south, the way
-- the starfield streams past a travelling platform, whichever way it is going. Spawn points
-- reach one particle's travel north of the field, so streaks are as dense at its north edge as
-- anywhere, and new streaks fade in (prototypes/entities.lua) rather than pop up.
local function render_warp_streaks(record, platform)
  local bounds = record.lightning_bounds
  if not bounds then
    update_warp_effect_bounds(record, platform)
    bounds = record.lightning_bounds
  end
  local width = bounds.right - bounds.left
  local height = bounds.bottom - bounds.top
  local count = math.floor(width * height / WARP_STREAK_TILES)
  count = math.max(WARP_STREAK_MIN, math.min(WARP_STREAK_MAX, count))
  local travel = WARP_STREAK_LIFE * WARP_STREAK_SPEED
  local spawns = random_count(count * UPDATE_TICKS / WARP_STREAK_LIFE * (height + travel) / height)
  local surface = platform.surface
  for _ = 1, spawns do
    surface.create_particle({
      name = WARP_STREAK_NAME,
      position = {
        x = bounds.left + math.random() * width,
        y = bounds.top - travel + math.random() * (height + travel)
      },
      movement = {0, WARP_STREAK_SPEED},
      height = 0,
      vertical_speed = 0,
      frame_speed = 1
    })
  end
end

local function strike(surface, position)
  -- execute_lightning rejects space-platform surfaces because their planet has no lightning
  -- generator. Direct creation is the engine-supported path also used by menu simulations.
  surface.create_entity({name = LIGHTNING_NAME, position = position, force = "neutral"})
end

-- Occasional strikes around the drive, independent of the wider effect field. Each is a full
-- strike whose cloud is drawn at the entity position and whose bolt lands LIGHTNING_BOLT_LENGTH
-- tiles south, so the cloud goes that far north of the landing point. The square root spreads
-- landings evenly over the disc instead of crowding its centre.
local function render_warp_lightning(record, platform)
  local entity = record.entity
  if entity and entity.valid and math.random() < LIGHTNING_DRIVE_STRIKE_CHANCE then
    local angle = math.random() * 2 * math.pi
    local distance = LIGHTNING_DRIVE_RADIUS * math.sqrt(math.random())
    strike(platform.surface, {
      x = entity.position.x + distance * math.cos(angle),
      y = entity.position.y + distance * math.sin(angle) - LIGHTNING_BOLT_LENGTH
    })
  end
end

-- The smallest shockwave reach that covers the platform's foundation from the drive.
local function shockwave_reach(record, platform)
  local bounds = record.lightning_bounds
  local center = record.entity.position
  -- Far enough to sweep the asteroids already around the ship while the ring still glows.
  local farthest = 0
  for _, asteroid in pairs(platform.surface.find_entities_filtered({type = "asteroid"})) do
    farthest = math.max(farthest, Shockwaves.oval_distance(center, asteroid.position))
  end
  for _, chunk in pairs(platform.find_asteroid_chunks_filtered({})) do
    farthest = math.max(farthest, Shockwaves.oval_distance(center, chunk.position))
  end
  local sweep = farthest > 0 and math.min(SHOCKWAVE_MAX_REACH, Shockwaves.sweep_reach(farthest)) or 0
  local margin = WARP_EFFECT_FIELD_MARGIN
  local dx = math.max(center.x - bounds.left, bounds.right - center.x) - margin
  local dy = math.max(center.y - bounds.top, bounds.bottom - center.y) - margin
  local reach = math.sqrt(dx * dx + dy * dy)
  for _, candidate in ipairs(SHOCKWAVE_REACHES) do
    if candidate >= reach then
      return math.max(candidate, sweep)
    end
  end
  return math.max(SHOCKWAVE_REACHES[#SHOCKWAVE_REACHES], sweep)
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
  start_warp_sound(record)
  update_warp_effect_bounds(record, platform)
  Shockwaves.start(record, shockwave_reach(record, platform))
  record.asteroid_sweep = true
  render_warp_effect(record, platform)
  return true
end

local function update_experimental(record)
  start_failed_activation(record, "research-revoked")
  if record.state == "warp" then
    exit_warp(record, "research-revoked")
  end
  local power = Drive.ensure_power(record)
  if power then
    initialize_detector_mode(record, power)
  end
  update_detector_latch(record)
  if record.detector_on then
    update_detector(record, power)
  else
    stop_detector(record, power)
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
    render_warp_effect(record, platform)
  end
end

local function update_cooldown(record, charge_buffer)
  Drive.destroy_support(record)
  stop_detector(record, charge_buffer)
  record.reserve_energy = 0
  record.state = "cooldown"
end

local function reset_preparation(record, charge_buffer, reason)
  local failed_activation = start_failed_activation(record, reason)
  reset_charge_sound(record)
  Drive.destroy_support(record)
  disable_power(record, charge_buffer, true)
  record.reserve_energy = 0
  record.support_power = 0
  record.support_demand_watts = nil
  record.state = failed_activation and "cooldown" or "idle"
  if reason and not failed_activation then
    record.last_exit_reason = reason
  end
end

-- Not engaged: the reserve stays empty, and the power interface serves the Tachyon Science Boost
-- detector while it is switched on.
local function update_idle(record, charge_buffer)
  reset_charge_sound(record)
  Drive.destroy_support(record)
  record.reserve_energy = 0
  record.support_power = 0
  record.support_demand_watts = nil
  update_detector_latch(record)
  if record.detector_on then
    update_detector(record, charge_buffer)
    record.state = record.detector_power_ratio > 0.01 and "detecting" or "idle"
  else
    stop_detector(record, charge_buffer)
    record.state = "idle"
  end
end

-- Engaging pauses the detector. Its last sample is discarded, so detector energy delivered before
-- this update is never credited to the warp reserve.
local function begin_charging(record)
  record.state = "charging"
  record.power_sample_watts = nil
  record.detector_power = 0
  record.detector_power_ratio = 0
  record.detector_request_watts = DETECTOR_MAX_POWER_WATTS
end

-- Charging is the engaged state before warp: it begins from the Engage button or a true activate
-- condition, then continues on its own until warp entry. Interrupted preparation loses its
-- accumulated reserve; reaching full charge must be one continuous final step after every other
-- entry requirement is satisfied.
local function update_idle_or_charging(record, platform, direction, charge_buffer)
  local deactivate = deactivate_requested(record)
  if record.state ~= "charging" then
    if deactivate or not activate_requested(record)
        or not prerequisites_met(record, platform, direction) then
      update_idle(record, charge_buffer)
      return
    end
    begin_charging(record)
  elseif deactivate then
    reset_preparation(record, charge_buffer, "circuit-deactivate")
    return
  elseif not prerequisites_met(record, platform, direction) then
    local reason = platform_speed_km_per_second(platform) < MINIMUM_SPEED
      and "charging-speed-interrupted" or nil
    reset_preparation(record, charge_buffer, reason)
    return
  end
  local charge = required_charge(platform)
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

-- Charging progress, or detector power relative to its maximum, for the core overlays.
local function visual_level(record, platform)
  if record.state == "detecting" then
    return (record.detector_power or 0) / DETECTOR_MAX_POWER_WATTS
  end
  local charge = required_charge(platform)
  return charge > 0 and (record.reserve_energy or 0) / charge or 0
end

-- Advances the drive's electrical and warp state. Returns false when the power interface could
-- not be created, which skips this update's sound scheduling.
local function update_state(record, platform, direction)
  if not practical_researched(platform.force) then
    update_experimental(record)
    return true
  end
  local charge_buffer = Drive.ensure_power(record)
  if not charge_buffer then
    return false
  end
  local charge = required_charge(platform)
  if record.power_mode ~= "practical" then
    record.reserve_energy = math.min(record.migrated_reserve_energy or 0, charge)
    record.migrated_reserve_energy = nil
    record.power_sample_watts = nil
    record.detector_request_watts = nil
    record.detector_power = 0
    record.detector_power_ratio = 0
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
  if update_state(record, platform, direction) then
    update_charge_sound(record, platform)
    update_warp_background_sound(record)
  end
  Drive.set_name_tag(platform, record.state == "warp" and (record.warp_level or 1) or nil)
  Visuals.update(record, visual_level(record, platform))
  Anomalies.update(record, platform.surface, record.lightning_bounds, record.state == "warp")
  return true
end

--- Per-tick work, limited to what cannot wait for the 10-tick update: growing activation
-- shockwaves, and clearing asteroids while warp holds. Until the sweeping ring has passed, only
-- what its front has reached is cleared; afterwards, everything. Idle drives cost one state check.
function Warp.tick(record)
  if record.shockwave_tick or record.shockwaves then
    Shockwaves.update(record)
  end
  if record.state ~= "warp" then
    return
  end
  local entity = record.entity
  local platform = entity and entity.valid and entity.surface.platform
  if not platform then
    return
  end
  if record.asteroid_sweep then
    local center, radius, pending = Shockwaves.front(record)
    if center then
      sweep_warp_asteroids(platform, center, radius)
      return
    elseif pending then
      return
    end
    record.asteroid_sweep = nil
  end
  clear_warp_asteroids(platform)
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
  local activate_active = activate_requested(record)
  local deactivate_active = deactivate_requested(record)
  local prerequisites = prerequisites_met(record, platform, record.direction)
  local detector_start_active = condition_true(record, record.detector_start)
  local detector_stop_active = condition_true(record, record.detector_stop)
  local detector_start_blocker = record.detector_on and "running"
    or (detector_stop_active and "deactivate" or nil)
  local detector_stop_blocker = not record.detector_on and "stopped"
    or (detector_start_active and "activate" or nil)
  local engage_blocker = detector_start_blocker
  local disengage_blocker = detector_stop_blocker
  if practical then
    engage_blocker = Warp.engage_blocker(record, platform)
    disengage_blocker = record.state ~= "warp" and record.state ~= "charging" and "idle" or nil
  end
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
    activate_active = activate_active,
    deactivate_active = deactivate_active,
    detector_start_active = detector_start_active,
    detector_stop_active = detector_stop_active,
    detector_start_blocker = detector_start_blocker,
    detector_stop_blocker = detector_stop_blocker,
    detector_paused = practical and (record.state == "warp" or record.state == "charging"
      or record.state == "cooldown"),
    prerequisites_met = prerequisites,
    engage_blocker = engage_blocker,
    disengage_blocker = disengage_blocker,
    required_charge = charge,
    stored_charge = stored_charge,
    charge_ratio = charge > 0 and math.min(1, stored_charge / charge) or 0,
    speed = speed,
    speed_ready = speed >= MINIMUM_SPEED,
    effective_speed = effective_speed_km_per_second(platform,
      record.state == "warp" and (record.warp_level or 1) or nil),
    warp_boost = record.state == "warp" and warp_multiplier(record.warp_level) or 1,
    support_required = support_required,
    -- Details for the Warp tab beyond the header's headline figures.
    mass_kg = platform_weight_kg(platform),
    demand_watts = record.support_demand_watts or 0,
    engine_level_limit = engine_warp_limit(platform),
    -- How long the current reserve would carry a complete power outage during warp.
    outage_seconds = charge > 0 and stored_charge / charge * WARP_RESERVE_SECONDS or 0,
    power_ready = (record.support_power or 0)
      >= support_required * SUPPORT_POWER_TOLERANCE,
    cooldown_ready = game.tick >= record.cooldown_until,
    cooldown_seconds = math.max(0, record.cooldown_until - game.tick) / TICKS_PER_SECOND
  }
end

--- Why the Engage button cannot start warp now, or nil when it can: already engaged, waiting
-- for the switch to practical mode, held off by the deactivate condition, locked out, or
-- missing a specific entry requirement (travel, speed, or endpoint clearance).
function Warp.engage_blocker(record, platform)
  if record.state == "warp" then
    return "warp"
  elseif record.state == "charging" then
    return "charging"
  elseif record.power_mode ~= "practical" then
    return "locked"
  elseif deactivate_requested(record) then
    return "deactivate"
  elseif game.tick < record.cooldown_until then
    return "cooldown"
  elseif not platform.space_connection or not platform.distance or platform.paused then
    return "travel"
  elseif platform_speed_km_per_second(platform) < MINIMUM_SPEED then
    return "speed"
  elseif not endpoint_clear(platform, record.direction) then
    return "clearance"
  end
  return nil
end

--- The Start buttons: latch the detector on for the next update. Returns whether it changed.
function Warp.start_detector(record)
  if record.detector_on or condition_true(record, record.detector_stop) then
    return false
  end
  record.detector_on = true
  return true
end

--- The Stop buttons: latch the detector off for the next update. Returns whether it changed.
function Warp.stop_detector(record)
  if not record.detector_on or condition_true(record, record.detector_start) then
    return false
  end
  record.detector_on = false
  return true
end

--- The large left button. Before Practical research it is Start tachyon detector; after it,
-- Engage begins charging immediately rather than at the next 10-tick update, so the buildup hum
-- answers the click. Returns whether the drive engaged.
function Warp.engage(record)
  local entity = record.entity
  local platform = entity and entity.valid and entity.surface.platform
  if not platform then
    return false
  end
  if not practical_researched(platform.force) then
    return Warp.start_detector(record)
  end
  local charge_buffer = Drive.ensure_power(record)
  if not charge_buffer or Warp.engage_blocker(record, platform) then
    return false
  end
  begin_charging(record)
  update_idle_or_charging(record, platform, record.direction, charge_buffer)
  update_charge_sound(record, platform)
  return record.state == "charging" or record.state == "warp"
end

--- The large right button. Before Practical research it is Stop tachyon detector; after it,
-- Disengage abandons charging with the usual interrupted-activation lockout, or exits warp.
-- Returns whether anything was disengaged.
function Warp.disengage(record)
  local entity = record.entity
  local platform = entity and entity.valid and entity.surface.platform
  if not platform then
    return false
  end
  if not practical_researched(platform.force) then
    return Warp.stop_detector(record)
  end
  if record.state == "warp" then
    exit_warp(record, "manual")
    return true
  elseif record.state == "charging" then
    local charge_buffer = Drive.ensure_power(record)
    if charge_buffer then
      reset_preparation(record, charge_buffer, "manual")
      return true
    end
  end
  return false
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
