-- The gate as a train station: rails, a station, and signals through its lanes, and trains sent
-- through the ring one carriage at a time to the partner's arrival lane. How it works, what was
-- measured, and how it differs from RiftRail, whose carriage-by-carriage clone technique it follows:
-- docs/railway.md.
--
-- In short: the entry signal at the departure edge is red until the gate could send a train, so
-- trains wait in front of it under their schedule. Railway.check (every Gate.TRANSFER_TICKS) syncs
-- that signal and takes a train whose front crosses the edge; Railway.update (every tick) drives it
-- in, clones each carriage behind the veil onto the partner's arrival lane, drives the arriving part
-- out, smashes carriages that cannot come out, and gives the complete train its schedule back.
local Gate = require("scripts.gate")

local Railway = {}

local RAIL = "bte-stargate-rail"
local STATION = "bte-stargate-station"
local EXIT_SIGNAL = "bte-stargate-exit-signal"
local ENTRY_SIGNAL = "bte-stargate-entry-signal"
local ENTRY_CONTROL = "bte-stargate-entry-control"
-- The entry signal closes while its control sends this signal.
local CLOSE_SIGNAL = {type = "virtual", name = "signal-red"}
-- Signals sit beside a lane's rail end: west of it facing north guards southbound trains, east of it
-- facing south northbound ones (measured; any other side or direction is placed but never attached).
local SIGNAL_DX = 1.5
local ROLLING_STOCK = {"locomotive", "cargo-wagon", "fluid-wagon", "artillery-wagon", "infinity-cargo-wagon"}
-- The building's centre is one tile south-east of its position (prototypes/entities.lua).
local CENTER = 1
-- Rail pieces' centres, in tiles south of the gate's centre: the visible track from the gate's south
-- edge (7) to the ring (2, ending a tile behind its plane), then hidden track behind it to RAIL_END,
-- long enough for a carriage to pass wholly behind the veil.
local RAIL_Y = {2, 4, 6}
local HIDDEN_Y = {-4, -2, 0}
local RAIL_END = -5
local EDGE = 7
-- The ring's plane. A carriage is taken once its rear has passed it, so it has driven in under the
-- veil (sorted behind the ring's body companion once its centre is past) before it disappears.
local RING_PLANE = 2
-- A train is taken once its front reaches the gate's edge.
local REACH = 0.1
-- The station, beside the departure lane on a northbound train's right, at the far end of the hidden
-- rails behind the ring. A train brakes to stop there, so it still crosses the edge, where it is
-- taken, at speed (it would stop with its front 1.4 tiles short of the rails' end).
local STATION_DX = 2
local STATION_Y = -4
-- Lane offsets from the centre for each mode; the departure lane takes the station.
local LAYOUTS = {
  single = {depart = 0, arrive = 0},
  right = {depart = 2, arrive = -2},
  left = {depart = -2, arrive = 2}
}
Railway.MODES = {"single", "right", "left"}
-- Tiles a tick (64.8 km/h): the slowest a train is driven through the ring, if it came in slower and
-- has no locomotive to speed it up, and the speed the splash timings were tuned at.
local SPEED = 0.3
-- A train passing through keeps the speed it came in with and gathers speed as it would on its own:
-- vanilla trains gain about ACCELERATION * (locomotives * fuel acceleration multiplier) / weight tiles
-- a tick each tick from a standstill (measured: 0.0011 for one locomotive and four wagons on coal,
-- the same for two and eight, three times that on nuclear fuel). Air resistance, which slows the gain
-- near top speed, is left out; the train's own top speed caps it.
local ACCELERATION = 6.8
-- How long an arrived carriage is not sent back (a single-track gate's arrivals start on its
-- departure lane).
local GUARD_TICKS = 300
local NORTH = defines.direction.north

function Railway.init_storage()
  storage.rail_transfers = storage.rail_transfers or {}
  storage.rail_guard = storage.rail_guard or {}
  storage.rail_held = storage.rail_held or {}
end

-- Held trains by id; created on first use too, for saves from before holding.
local function held_trains()
  storage.rail_held = storage.rail_held or {}
  return storage.rail_held
end

local function center(record)
  local position = record.entity.position
  return {x = position.x + CENTER, y = position.y + CENTER}
end

local function layout(record)
  return record.railway and LAYOUTS[record.railway]
end

-- The lanes a mode uses, as x offsets.
local function lanes(mode)
  local spec = LAYOUTS[mode]
  if spec.depart == spec.arrive then
    return {spec.depart}
  end
  return {spec.depart, spec.arrive}
end

local function lane_area(record, dx, from, to)
  local c = center(record)
  return {{c.x + dx - 0.9, c.y + from}, {c.x + dx + 0.9, c.y + to}}
end

local HIDDEN = "bte-stargate-rail-hidden"

-- Rolling stock anywhere on the gate's rails.
local function stock_on_rails(record, mode)
  local found = {}
  for _, dx in pairs(lanes(mode)) do
    for _, car in pairs(record.entity.surface.find_entities_filtered({type = ROLLING_STOCK, area = lane_area(record, dx, RAIL_END - 0.5, EDGE + 0.5)})) do
      found[#found + 1] = car
    end
  end
  return found
end

local function busy(record)
  local id = record.entity.unit_number
  for _, transfer in pairs(storage.rail_transfers or {}) do
    if transfer.from == id or transfer.to == id then
      return true
    end
  end
  return false
end

-- The layout's version: gates built with an earlier one get the missing pieces and a moved station.
local LAYOUT = 7

-- Places the rails and station for record.railway, adding whatever is missing (after a configuration
-- change, or a layout from an earlier version: then a train may stand on the rails, so nothing is
-- removed but a misplaced station).
local function build(record)
  local spec = layout(record)
  if not spec then
    return
  end
  local gate = record.entity
  local surface = gate.surface
  local c = center(record)
  local rails = {}
  for _, rail in pairs(record.rails or {}) do
    if rail.valid then
      rails[#rails + 1] = rail
    end
  end
  for _, dx in pairs(lanes(record.railway)) do
    for name, ys in pairs({[RAIL] = RAIL_Y, [HIDDEN] = HIDDEN_Y}) do
      for _, dy in pairs(ys) do
        local position = {c.x + dx, c.y + dy}
        if not surface.find_entity(name, position) then
          local rail = surface.create_entity({name = name, position = position, direction = NORTH,
            force = gate.force, create_build_effect_smoke = false})
          if rail then
            rail.destructible = false
            rails[#rails + 1] = rail
          end
        end
      end
    end
  end
  record.rails = rails
  -- A departure-lane piece inside the entry signal (the edge piece is cut by it): its block, the
  -- gate's lane, tells whether a train is in.
  record.edge_rail = surface.find_entity(RAIL, {c.x + spec.depart, c.y + RAIL_Y[2]})
  local at = {x = c.x + spec.depart + STATION_DX, y = c.y + STATION_Y}
  local station = record.station
  if station and station.valid and (station.position.x ~= at.x or station.position.y ~= at.y) then
    station.destroy()
  end
  if not (record.station and record.station.valid) then
    station = surface.create_entity({name = STATION, position = at, direction = NORTH, force = gate.force,
      create_build_effect_smoke = false})
    if station then
      station.destructible = false
      station.backer_name = record.name
      record.station = station
    end
  end
  local signals = {}
  for _, old in pairs(record.signals or {}) do
    if old.valid then
      signals[#signals + 1] = old
    end
  end
  local function signal(name, dx, direction)
    local position = {c.x + dx, c.y + EDGE - 0.5}
    local found = surface.find_entity(name, position)
    if found then
      return found
    end
    local created = surface.create_entity({name = name, position = position, direction = direction,
      force = gate.force, create_build_effect_smoke = false})
    if created then
      created.destructible = false
      signals[#signals + 1] = created
    end
    return created
  end
  signal(EXIT_SIGNAL, spec.arrive - SIGNAL_DX, NORTH)
  local entry = signal(ENTRY_SIGNAL, spec.depart + SIGNAL_DX, defines.direction.south)
  record.signals = signals
  -- The entry signal's switch, closed until Railway.check finds the gate ready.
  if entry and not (record.entry_control and record.entry_control.valid) then
    local control = surface.create_entity({name = ENTRY_CONTROL, position = entry.position, force = gate.force,
      create_build_effect_smoke = false})
    if control then
      control.destructible = false
      local behavior = control.get_or_create_control_behavior()
      behavior.get_section(1).set_slot(1, {value = {type = CLOSE_SIGNAL.type, name = CLOSE_SIGNAL.name, quality = "normal"}, min = 1})
      behavior.enabled = true
      control.get_wire_connector(defines.wire_connector_id.circuit_red, true).connect_to(
        entry.get_wire_connector(defines.wire_connector_id.circuit_red, true), false, defines.wire_origin.script)
      local signal_behavior = entry.get_or_create_control_behavior()
      signal_behavior.close_signal = true
      signal_behavior.circuit_condition = {first_signal = CLOSE_SIGNAL, comparator = ">", constant = 0}
      record.entry_control, record.entry_open = control, false
    end
  end
  record.rail_layout = LAYOUT
end

-- Whether the block out of `target`'s arrival lane is free and not reserved, as its exit signal
-- shows. A gate without the signal (it could not be placed) is not held back.
local function exit_clear(target)
  for _, signal in pairs(target.signals or {}) do
    if signal.valid and signal.name == EXIT_SIGNAL then
      return signal.signal_state == defines.signal_state.open
    end
  end
  return true
end

-- Switches station mode: nil (off) or one of Railway.MODES. Refused, returning false and a reason,
-- while a train is on the gate's rails or passing through either way.
function Railway.set_mode(record, mode)
  if mode == record.railway then
    return true
  end
  if record.railway and (busy(record) or #stock_on_rails(record, record.railway) > 0) then
    return false, {"bte-stargate-gui.station-occupied"}
  end
  -- Removes the rails, station, and signals, and clears carriages off them.
  Gate.remove_railway(record)
  record.railway = mode
  build(record)
  Gate.refresh(record)
  return true
end

-- The gate's station, if it is in station mode.
function Railway.station(record)
  return record.station and record.station.valid and record.station or nil
end

-- The gate that owns `station`.
function Railway.gate_of(station)
  for _, record in pairs(storage.gates) do
    if record.station == station then
      return record
    end
  end
end

-- Keeps the station's name the gate's.
function Railway.sync_name(record)
  if record.station and record.station.valid and record.station.backer_name ~= record.name then
    record.station.backer_name = record.name
  end
end

-- After a configuration change: rebuilds what is missing, and drops transfers that lost a gate.
function Railway.rebuild()
  Railway.init_storage()
  for _, record in pairs(storage.gates) do
    if record.entity.valid and record.railway then
      build(record)
    end
  end
end

-- Which way a positive speed moves `train` along a north-south track: 1 south, -1 north. Positive
-- speed moves a train towards its front stock; with one carriage, the way that carriage faces.
local function south_sign(train)
  local front, back = train.front_stock, train.back_stock
  if front ~= back then
    return front.position.y > back.position.y and 1 or -1
  end
  return math.cos(front.orientation * 2 * math.pi) < 0 and 1 or -1
end

-- Drives `train` along the lanes at `speed` tiles a tick: south (out of a gate) or north (into one).
local function drive(train, south, speed)
  train.manual_mode = true
  train.speed = speed * south_sign(train) * (south and 1 or -1)
end

-- How fast `train`, about to be driven north into a gate, gains speed each tick, and its top speed
-- that way (prototypes and fuel, see ACCELERATION).
local function pulling(train)
  local force = 0
  for _, loco in pairs(train.locomotives.front_movers) do
    local burning = loco.burner and loco.burner.currently_burning
    force = force + (burning and burning.name.fuel_acceleration_multiplier or (loco.burner and 0 or 1))
  end
  for _, loco in pairs(train.locomotives.back_movers) do
    local burning = loco.burner and loco.burner.currently_burning
    force = force + (burning and burning.name.fuel_acceleration_multiplier or (loco.burner and 0 or 1))
  end
  local north = south_sign(train) < 0
  local top = north and train.max_forward_speed or train.max_backward_speed
  return ACCELERATION * force / math.max(train.weight, 1), top
end

-- The carriage of `train` furthest in (northmost).
local function leading(train)
  local best, best_y
  for _, car in pairs(train.carriages) do
    local y = car.bounding_box.left_top.y
    if not best_y or y < best_y then
      best, best_y = car, y
    end
  end
  return best
end

-- The distance between the centres of two coupled carriages, from their prototypes (7 for vanilla).
local function half_length(name)
  local prototype = prototypes.entity[name]
  return ((prototype.joint_distance or 4) + (prototype.connection_distance or 3)) / 2
end

-- Where the next carriage of kind `name` appears: on the partner's arrival lane, its front at the
-- end of the hidden rails behind the ring (a vanilla locomotive's centre 3.5 tiles south of the rail
-- end, its rear still behind the ring's plane), so it drives out through the veil. After the first,
-- each is placed exactly one coupling length behind the previous one, which room() lets move at
-- least that far first: at speed it has moved up to a tick's travel further, and a clone placed at
-- the rail end then would not couple.
local function spawn_position(target, name, last)
  local c = center(target)
  -- Half a tile further south than the hidden rails' end allows, so no part of the carriage shows
  -- above the ring's top on screen; it still lies wholly behind the veil.
  local y = c.y + RAIL_END + half_length(name) - 0.5
  if last and last.valid then
    y = math.max(y, last.position.y - half_length(last.name) - half_length(name))
  end
  return {x = c.x + layout(target).arrive, y = y}
end

-- Whether the arrival lane has room for a carriage of kind `name`: the previous clone has moved a
-- coupling's length on, or for the first, nothing stands there.
local function room(transfer, target, name)
  local spawn = spawn_position(target, name)
  local last = transfer.last
  if last and last.valid then
    return last.position.y - spawn.y >= half_length(last.name) + half_length(name) - 0.01
  end
  return target.entity.surface.count_entities_filtered({type = ROLLING_STOCK,
    area = lane_area(target, layout(target).arrive, RAIL_END - 0.5, RAIL_END + 2 * half_length(name) + 0.5), limit = 1}) == 0
end

local function guarded(car)
  local until_tick = storage.rail_guard[car.unit_number]
  if until_tick and game.tick < until_tick then
    return true
  end
  storage.rail_guard[car.unit_number] = nil
  return false
end

local function in_transfer(train)
  for _, transfer in pairs(storage.rail_transfers) do
    if transfer.car and transfer.car.valid and transfer.car.train == train then
      return true
    end
  end
  return false
end

-- Whether the partner's arrival lane is free of other transfers.
local function receiving(target)
  local id = target.entity.unit_number
  for _, transfer in pairs(storage.rail_transfers) do
    if transfer.to == id then
      return true
    end
  end
  return false
end

-- One carriage meeting the veil at lane `dx` of `record`'s gate: the splash animation (32 frames, two
-- ticks each, starting on its first frame whatever the tick), centred on the lane and covering the
-- column of the veil the carriage fills on screen as it vanishes or appears, and a short sound there.
local SPLASH_FRAMES = 32
local SPLASH_TICKS = 64
local function splash(record, dx, sound)
  local gate = record.entity
  local speed = SPLASH_FRAMES / SPLASH_TICKS
  rendering.draw_animation({
    animation = "bte-stargate-splash", target = {gate.position.x + dx, gate.position.y}, surface = gate.surface,
    render_layer = "higher-object-above", animation_speed = speed,
    animation_offset = (SPLASH_FRAMES - (game.tick * speed) % SPLASH_FRAMES) % SPLASH_FRAMES, time_to_live = SPLASH_TICKS
  })
  local c = center(record)
  gate.surface.play_sound({path = sound, position = {c.x + dx, c.y + RING_PLANE}})
  -- A short bright cyan light on the surroundings while the splash plays (scripts/gate.lua VEIL_LIGHT).
  rendering.draw_light({sprite = "utility/light_medium", scale = 3.5, intensity = 0.9, color = {0.3, 0.85, 1},
    surface = gate.surface, target = {c.x + dx, c.y + RING_PLANE - 1.6}, time_to_live = 48})
end

-- The splash brightens for its first quarter before it peaks, so each starts this many ticks before
-- the moment it should hide: the arriving carriage appearing, when it is sent, and the departing one
-- vanishing, which on screen happens earlier, once its centre passes the ring's line and it is drawn
-- behind the ring and the veil.
local SPLASH_PEAK_TICKS = 16
-- The departing carriage is seen to vanish a little after its centre passes the line, so its splash
-- starts later than the peak alone would say (tuned in game).
local DEPART_LEAD_TICKS = 11

local function start(record, target, train, car)
  local schedule = train.get_schedule()
  -- A held train came in automatic.
  local held = held_trains()
  local saved = {manual = train.manual_mode and not held[train.id]}
  held[train.id] = nil
  if schedule then
    saved.records = schedule.get_records()
    saved.interrupts = schedule.get_interrupts()
    saved.group = schedule.group
    saved.current = schedule.current
  end
  saved.station = record.station and record.station.valid and record.station.backer_name or record.name
  local acceleration, top = pulling(train)
  local speed = math.abs(train.speed)
  storage.rail_transfers[#storage.rail_transfers + 1] = {
    from = record.entity.unit_number, to = target.entity.unit_number, car = car, saved = saved,
    speed = speed, acceleration = acceleration, top = math.max(top, speed, SPEED)
  }
  drive(train, false, speed)
end

-- How far beyond the gate's edge a held train may stand and still be held; a train moved further
-- away (by hand) goes back to its schedule.
local HOLD_REACH = 12

-- Whether `train` stands on `record`'s departure lane, between the ring and HOLD_REACH beyond the edge.
local function on_departure_lane(record, train)
  local front = train.front_stock
  if not (front and front.valid and front.surface == record.entity.surface) then
    return false
  end
  local c, spec = center(record), layout(record)
  for _, car in pairs({front, train.back_stock}) do
    local position = car.position
    if math.abs(position.x - c.x - spec.depart) < 1 and position.y > c.y + RAIL_END and position.y < c.y + EDGE + HOLD_REACH then
      return true
    end
  end
  return false
end

local function hold(train, record)
  held_trains()[train.id] = {train = train, gate = record.entity.unit_number}
  train.manual_mode = true
  train.speed = 0
end

-- Lets go of held trains the gate can no longer take: its gate is gone or out of station mode, the
-- train was moved off the lane, or someone switched it back to automatic.
local function release_held()
  local trains = held_trains()
  for id, held in pairs(trains) do
    local train = held.train
    if not (train.valid and train.manual_mode) then
      trains[id] = nil
    else
      local record = Gate.get(held.gate)
      if not (record and record.entity.valid and layout(record) and on_departure_lane(record, train)) then
        trains[id] = nil
        train.manual_mode = false
      end
    end
  end
end

-- Sends any train that has reached the ring of an open station gate whose partner is a station too.
function Railway.check()
  if next(held_trains()) then
    release_held()
  end
  for _, record in pairs(storage.gates) do
    if record.railway and record.rail_layout ~= LAYOUT and record.entity.valid then
      build(record)
    end
    local spec = layout(record)
    local target = spec and record.entity.valid and Gate.partner(record)
    -- The partner can take a train: a station with no other train arriving there.
    local linked = (target and layout(target) and not receiving(target)) == true
    -- The entry signal is green only while a train could go through now, so automatic trains wait in
    -- front of it, still heading for the gate's station, and none looks for a path beyond the gate.
    -- Room behind the partner's veil is not checked: an entity search per gate every check was three
    -- quarters of this sync's cost (measured), and a free exit with no transfer running nearly always
    -- means room.
    local ready = linked and Gate.is_open(record) and exit_clear(target)
    local control = spec and record.entry_control
    if control and control.valid and record.entry_open ~= ready then
      control.get_control_behavior().enabled = not ready
      record.entry_open = ready
    end
    local rail = record.edge_rail
    if spec and rail and rail.valid and rail.trains_in_block > 0 then
      local c, open = center(record), Gate.is_open(record)
      for _, car in pairs(record.entity.surface.find_entities_filtered({type = ROLLING_STOCK,
          area = lane_area(record, spec.depart, RAIL_END - 0.5, EDGE + REACH)})) do
        local train = car.train
        if train and car.bounding_box.left_top.y <= c.y + EDGE + REACH and not guarded(car)
          and not in_transfer(train) and train.speed * south_sign(train) <= 0.01 then
          -- An automatic train is here only because the signal let it in, or it had reserved its way
          -- through before the signal closed and, as at any vanilla signal, kept going: it goes,
          -- whatever has changed since. A train driven by hand goes while the gate is open, as if
          -- it ran a red signal; carriages that cannot come out are wrecked.
          local automatic = not train.manual_mode or held_trains()[train.id]
          if linked and (automatic or open) then
            start(record, target, train, car)
            break
          elseif automatic then
            -- The partner cannot take a train: stopped here, or it would drive on into the ring
            -- towards the station behind it.
            hold(train, record)
          end
        end
      end
    end
  end
end

-- The character riding a carriage (rolling stock seats only a driver), put out to be seated in its
-- clone, and the players looking at it, to look at the clone.
local function crew(car)
  local driver = car.get_driver()
  if driver then
    car.set_driver(nil)
    if driver.object_name == "LuaPlayer" then
      -- Driven remotely: put out, the view left where it was, as for vehicles (scripts/transfer.lua).
      local position, surface = driver.position, driver.surface
      if driver.controller_type == defines.controllers.remote then
        driver.set_controller({type = defines.controllers.remote, position = position, surface = surface})
      end
      driver = nil
    end
  end
  local watchers = {}
  for _, player in pairs(game.connected_players) do
    if player.opened == car then
      watchers[#watchers + 1] = player
    end
  end
  return driver, watchers
end

-- Moves one carriage through: from the departure lane to a clone on the partner's arrival lane.
-- Returns false, with the carriage as it was, if it could not be turned or cloned.
local function send(transfer, record, target, car)
  local position = spawn_position(target, car.name, transfer.last)
  -- The clone keeps the carriage's orientation, and it must leave the partner facing the way it
  -- entered relative to its motion: lanes always run north into one gate and south out of the other,
  -- so every carriage is turned first, which needs it uncoupled.
  car.disconnect_rolling_stock(defines.rail_direction.front)
  car.disconnect_rolling_stock(defines.rail_direction.back)
  local turned = car.rotate()
  local clone = turned and car.clone({position = position, surface = target.entity.surface, force = car.force,
    create_build_effect_smoke = false})
  if not clone then
    if turned then
      car.rotate()
    end
    car.connect_rolling_stock(defines.rail_direction.front)
    car.connect_rolling_stock(defines.rail_direction.back)
    return false
  end
  local driver, watchers = crew(car)
  if driver and driver.valid then
    driver.teleport(clone.position, clone.surface)
    clone.set_driver(driver)
  end
  for _, player in pairs(watchers) do
    if player.valid then
      player.opened = clone
    end
  end
  car.destroy()
  storage.rail_guard[clone.unit_number] = game.tick + GUARD_TICKS
  transfer.last = clone
  return true
end

-- How many ticks the arrived part must stand still, with the next carriage due, before that carriage
-- is smashed: a train pushed each tick moves on the next one unless something stops it.
local STUCK_TICKS = 3

-- Whether the next carriage can never come through: the arrived part has stopped (a dead end, or a
-- train in its way), or something else stands on the arrival lane.
local function blocked(transfer)
  local last = transfer.last
  if not (last and last.valid) then
    return true
  end
  local y = last.position.y
  if transfer.last_y == y then
    transfer.stuck = (transfer.stuck or 0) + 1
  else
    transfer.last_y, transfer.stuck = y, 0
  end
  return transfer.stuck >= STUCK_TICKS
end

-- Destroys one carriage at `position` on `target`'s surface, with its cargo: its explosion and
-- remnants appear there, and its driver lands on the floor beside the arrival lane, towards the
-- gate's centre (between the tracks of a two-track gate, east of a single one: a train coming out
-- has it on its left), clear of the track where carriages may stand and in front of the portal.
local function wreck(target, car, position)
  local surface = target.entity.surface
  local driver = crew(car)
  if driver and driver.valid then
    local c, arrive = center(target), layout(target).arrive
    local x = c.x + (arrive == 0 and 2 or arrive / 2)
    local spot = surface.find_non_colliding_position("character", {x, c.y + EDGE - 1}, 4, 0.25)
    driver.teleport(spot or {x, c.y + EDGE - 1}, surface)
  end
  local explosion = car.name .. "-explosion"
  surface.create_entity({name = prototypes.entity[explosion] and explosion or "big-explosion", position = position})
  local remnants = car.name .. "-remnants"
  if prototypes.entity[remnants] then
    surface.create_entity({name = remnants, position = position, direction = defines.direction.south})
  end
  car.destroy({raise_destroy = true})
end

-- How far a carriage's rear may still be behind the ring's plane for it to count as out: a
-- locomotive stopped at the gate's edge, with no track beyond, has its rear 0.2 tiles behind.
local EMERGED_SLACK = 0.5

-- Whether `car`, arrived at `target`, has come out of the ring: wholly, or all but the slack.
local function out_of_ring(target, car)
  return car.bounding_box.left_top.y >= center(target).y + RING_PLANE - EMERGED_SLACK
end

-- Crushes the arrived carriages that have not come out of the ring once the arrived part has
-- stopped: only what has come out survives.
local function crush(transfer, target)
  local last = transfer.last
  while last and last.valid and not out_of_ring(target, last) do
    local ahead
    for _, direction in pairs({defines.rail_direction.front, defines.rail_direction.back}) do
      local other = last.get_connected_rolling_stock(direction)
      if other and other.position.y > last.position.y then
        ahead = other
      end
    end
    wreck(target, last, last.position)
    last = ahead
  end
  transfer.last = last
end

-- Whether the arrived part's rearmost carriage has come out.
local function emerged(transfer, target)
  local last = transfer.last
  return not (last and last.valid) or out_of_ring(target, last)
end

-- A carriage that finds no room at the partner crashes into what stands there: after the arrived
-- carriages still in the ring (crush()), against the rear of the carriage ahead.
local function crash(transfer, target, car)
  crush(transfer, target)
  local last = transfer.last
  local position = spawn_position(target, car.name)
  if last and last.valid then
    position.y = last.bounding_box.left_top.y - 1
  end
  wreck(target, car, position)
end

-- The saved schedule with the gate's own stop passed: rail records name places on the old surface
-- and are dropped; a temporary stop at the gate is removed, a permanent one skipped.
local function restore_schedule(train, saved)
  if not saved.records or #saved.records == 0 then
    return
  end
  local records, current = {}, saved.current or 1
  for index, record in ipairs(saved.records) do
    if record.rail then
      if index < saved.current then
        current = current - 1
      end
    else
      records[#records + 1] = record
    end
  end
  if #records == 0 then
    return
  end
  current = math.max(1, math.min(current, #records))
  if not saved.manual and records[current] and records[current].station == saved.station then
    if records[current].temporary then
      table.remove(records, current)
      if current > #records then
        current = 1
      end
    else
      current = current % #records + 1
    end
  end
  if #records == 0 then
    return
  end
  local schedule = train.get_schedule()
  if saved.group then
    -- The group brings its own records and interrupts; only the train's temporary stops are added.
    schedule.group = saved.group
    for index, record in ipairs(records) do
      if record.temporary then
        record.index = {schedule_index = index}
        schedule.add_record(record)
      end
    end
  else
    schedule.set_records(records)
    schedule.set_interrupts(saved.interrupts or {})
  end
  if not saved.manual then
    schedule.go_to_station(math.min(current, schedule.get_record_count() or current))
  end
end

-- Once an automatic train's arrived part has a locomotive facing out, gives it its schedule back
-- so that it can drive itself; transfer.stop, its current stop, marks that from then on.
local function steer(transfer)
  local last = transfer.last
  local train = last and last.valid and last.train
  if not train or transfer.saved.manual or transfer.stop then
    return
  end
  local movers = south_sign(train) > 0 and train.locomotives.front_movers or train.locomotives.back_movers
  if #movers == 0 then
    return
  end
  -- Restoring the schedule leaves a fresh clone standing; the carriages behind would then wait at
  -- the ring for it and the whole train crawl (seen in game).
  local current = math.max(math.abs(train.speed), transfer.speed or SPEED)
  restore_schedule(train, transfer.saved)
  local schedule = train.get_schedule()
  if (schedule.get_record_count() or 0) > 0 then
    transfer.stop = schedule.current
  end
  train.speed = current * south_sign(train)
end

-- Puts the arrived part (back) in automatic mode, heading for its stop, at the speed it has.
-- Needed after every coupling, which makes a train manual and sets its schedule back to the first
-- record (measured).
local function drive_itself(transfer, train)
  local current = train.speed
  train.get_schedule().go_to_station(transfer.stop)
  train.manual_mode = false
  train.speed = current
end

-- Moves the arrived part on each tick while carriages are still coming.
-- * Without its schedule back (driven by hand, or no locomotive facing out yet): driven straight
--   out at the transfer speed.
-- * With it: drives itself, so the game picks its branches like any train's.
-- * Once it would slow down (its speed drops, or it brakes for a signal or station, or has no path),
--   it is pushed straight on instead (transfer.pushing) until the transfer ends, gathering speed
--   with the part still going in. Left to brake, it stopped in the ring and every carriage behind
--   was crushed (seen in game). The push is manual because the game ignores a speed set on an
--   automatic train that wants to stop (measured).
local function move_out(transfer, target, speed)
  local last = transfer.last
  local train = last and last.valid and last.train
  if not train then
    return
  end
  if not transfer.stop then
    drive(train, true, speed)
    return
  end
  if transfer.pushing then
    transfer.pushing = math.max(transfer.pushing, speed)
    drive(train, true, math.max(transfer.pushing, SPEED))
    return
  end
  -- Just handed back after a coupling, the train still reports its manual state for this tick.
  local handed = train.manual_mode
  if handed then
    drive_itself(transfer, train)
  end
  local current = math.abs(train.speed)
  local pace = transfer.pace or current
  if (not handed and train.state ~= defines.train_state.on_the_path) or current < pace - 1e-4 then
    transfer.pushing = math.max(pace, current, speed)
    drive(train, true, math.max(transfer.pushing, SPEED))
  else
    transfer.pace = current
  end
end

local function finish(index, transfer)
  table.remove(storage.rail_transfers, index)
  local last = transfer.last
  if not (last and last.valid and last.train) then
    return
  end
  local train = last.train
  for _, car in pairs(train.carriages) do
    storage.rail_guard[car.unit_number] = game.tick + GUARD_TICKS
  end
  if transfer.stop then
    -- It drives itself from here, at the speed it has.
    drive_itself(transfer, train)
    return
  end
  restore_schedule(train, transfer.saved)
  train.manual_mode = transfer.saved.manual
  -- Leaves at the speed it came through; an automatic train then follows its path.
  train.speed = (transfer.speed or SPEED) * south_sign(train)
end

-- A transfer whose gate or partner is gone stops: the carriages still at the sender stay there with
-- their schedule, and those already through keep the copy.
local function abort(index, transfer)
  local car = transfer.car
  if car and car.valid and car.train then
    car.train.manual_mode = transfer.saved.manual
  end
  finish(index, transfer)
end

-- Runs every tick while a train is passing through.
function Railway.update()
  for index = #storage.rail_transfers, 1, -1 do
    local transfer = storage.rail_transfers[index]
    local record, target = Gate.get(transfer.from), Gate.get(transfer.to)
    if not (record and target and layout(record) and layout(target)) then
      abort(index, transfer)
    else
      -- Both parts gather speed together, as one train would; one with no locomotive working
      -- (wagons pushed in, or out of fuel) is driven at SPEED at least.
      local acceleration = transfer.acceleration or 0
      local speed = math.min(transfer.top or SPEED, (transfer.speed or SPEED) + acceleration)
      if acceleration <= 0 then
        speed = math.max(speed, SPEED)
      end
      -- Once out, the train drives itself and may pull away faster than the script feeds it: the
      -- part still going in keeps up, as the rest of one train would, or the next carriage appears
      -- falling behind and does not couple (seen in game).
      local out = transfer.last
      if out and out.valid and out.train then
        speed = math.max(speed, math.abs(out.train.speed))
      end
      transfer.speed = speed
      local car = transfer.car
      local train = car and car.valid and car.train
      if not train then
        -- Everything is sent: the arrived part is driven out until its last carriage has emerged;
        -- if it stops first, what is still in the ring is crushed.
        if emerged(transfer, target) then
          finish(index, transfer)
        elseif blocked(transfer) then
          crush(transfer, target)
          finish(index, transfer)
        else
          move_out(transfer, target, speed)
        end
      else
        -- The train's northmost carriage, found once: afterwards each carriage sent leaves the next
        -- one in front, so transfer.car stays it without walking every carriage's box each tick.
        if not transfer.led then
          transfer.car, transfer.led = leading(train), true
        end
        local front = transfer.car
        local box = front.bounding_box
        local front_y, rear = box.left_top.y, box.right_bottom.y
        local c = center(record)
        local lead = speed * SPLASH_PEAK_TICKS
        transfer.flashed = transfer.flashed or {}
        local flashed = transfer.flashed[front.unit_number] or 0
        if flashed < 1 and (front_y + rear) / 2 <= c.y + RING_PLANE + speed * DEPART_LEAD_TICKS then
          flashed = 1
          splash(record, layout(record).depart, "bte-stargate-car-in")
        end
        if flashed < 2 and rear <= c.y + RING_PLANE + lead then
          flashed = 2
          splash(target, layout(target).arrive, "bte-stargate-car-out")
        end
        transfer.flashed[front.unit_number] = flashed
        local ready = rear <= c.y + RING_PLANE
        local fits = ready and room(transfer, target, front.name)
        if ready and (fits or blocked(transfer)) then
          local rest = front.get_connected_rolling_stock(defines.rail_direction.front)
          if not rest or rest == front then
            rest = front.get_connected_rolling_stock(defines.rail_direction.back)
          end
          local last = transfer.last
          local arriving = last and last.valid and last.train and math.abs(last.train.speed)
          local gone = fits and send(transfer, record, target, front)
          if gone then
            transfer.failed = nil
            -- Coupling slows the arrived part for the added weight; it keeps the speed it had.
            if arriving and transfer.last.train then
              transfer.last.train.speed = arriving * south_sign(transfer.last.train)
            end
            steer(transfer)
          elseif fits then
            -- A carriage that cannot be turned or cloned (something else in the way at the partner)
            -- is tried again next tick, but a started train must finish: after STUCK_TICKS failures
            -- it counts as blocked.
            transfer.failed = (transfer.failed or 0) + 1
          end
          if not gone and (not fits or transfer.failed >= STUCK_TICKS) then
            crash(transfer, target, front)
            transfer.failed, gone = nil, true
          end
          if gone then
            transfer.car = rest
            train = rest and rest.valid and rest.train
            rear = train and rest.bounding_box.right_bottom.y
          end
        end
        if train and train.valid then
          if rear <= c.y + RING_PLANE then
            train.manual_mode = true
            train.speed = 0
          else
            drive(train, false, speed)
          end
        end
        move_out(transfer, target, speed)
      end
    end
  end
end

function Railway.active()
  return storage.rail_transfers and storage.rail_transfers[1] ~= nil
end

return Railway
