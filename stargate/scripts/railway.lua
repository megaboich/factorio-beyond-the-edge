-- The gate as a train station: rails through its lanes and trains sent through the ring, one carriage
-- at a time, to the partner's arrival lane.
--
-- Layout. A gate in station mode (record.railway) has vanilla straight rails (bte-stargate-rail, which
-- only the script places, drawn just above the gate's floor) laid from its south edge to the ring, where
-- they seem to end, rails drawn under the ground (bte-stargate-rail-hidden) on behind the ring, and a
-- hidden train stop (bte-stargate-station) named after the gate beside the departure lane at its edge,
-- where trains wait for the gate. LAYOUTS gives the lanes'
-- x offsets from the gate's centre: one central track used both ways, or two tracks with departures
-- on the right or on the left (as seen by a train driving into the gate). Trains always enter heading
-- north and come out of the partner heading south, so the two gates' lanes are always parallel.
--
-- Sending. Every Gate.TRANSFER_TICKS, an open gate whose partner is also a station takes any train
-- whose front has reached the gate's edge on its departure lane (a train stopping at the station stops
-- there, and a manually driven one passes it). From then on, every tick (Railway.update), the train is
-- held in manual mode and driven into the ring at SPEED; each carriage that has passed wholly behind
-- the veil is rotated, cloned onto the partner's arrival lane (clone keeps its cargo, fuel, fluid, equipment,
-- health, colour, and name), and removed, as in the RiftRail mod. The clones couple as they are
-- placed behind the partner's veil, each a coupling length behind the last, while the arriving part is driven out at the same speed. Crew
-- move with their carriage. When the last carriage is through, the arriving train gets the old
-- train's schedule, interrupts, and group, its current stop moved past the gate's station, and leaves
-- in the mode it came in.
--
-- Each carriage gets its own splash and sound at its lane on both gates (splash()), covering the
-- moment it vanishes and appears.
--
-- Unlike RiftRail, the schedule is copied only once, to the complete train, so cargo interrupts never
-- see a half-arrived train, and no leading locomotive is needed: the script drives the train while
-- it is assembled. A gate's arrival lane takes one train at a time (it is locked by the transfer).
local Gate = require("scripts.gate")

local Railway = {}

local RAIL = "bte-stargate-rail"
local STATION = "bte-stargate-station"
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
-- A train is taken once its front reaches the gate's edge: a train waiting at the station stops
-- with its front 0.6 inside it.
local REACH = 0.1
-- The station, beside the departure lane on a northbound train's right, at the gate's south edge.
local STATION_DX = 2
local STATION_Y = 6
-- Lane offsets from the centre for each mode; the departure lane takes the station.
local LAYOUTS = {
  single = {depart = 0, arrive = 0},
  right = {depart = 2, arrive = -2},
  left = {depart = -2, arrive = 2}
}
Railway.MODES = {"single", "right", "left"}
-- Tiles a tick (64.8 km/h) at which trains are drawn into the ring and driven out of the partner.
local SPEED = 0.3
-- How long an arrived carriage is not sent back (a single-track gate's arrivals start on its
-- departure lane).
local GUARD_TICKS = 300
local NORTH = defines.direction.north

function Railway.init_storage()
  storage.rail_transfers = storage.rail_transfers or {}
  storage.rail_guard = storage.rail_guard or {}
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
local LAYOUT = 2

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
  record.rail_layout = LAYOUT
end

-- Removes the rails and station (Gate.remove_railway also clears carriages off them).
local function clear(record)
  Gate.remove_railway(record)
end
Railway.clear = clear

-- Switches station mode: nil (off) or one of Railway.MODES. Refused, returning false and a reason,
-- while a train is on the gate's rails or passing through either way.
function Railway.set_mode(record, mode)
  if mode == record.railway then
    return true
  end
  if record.railway and (busy(record) or #stock_on_rails(record, record.railway) > 0) then
    return false, {"bte-stargate-gui.station-occupied"}
  end
  clear(record)
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

local function drive(train, south)
  train.manual_mode = true
  train.speed = SPEED * south_sign(train) * (south and 1 or -1)
end

-- The carriage of `train` furthest in (northmost), its leading edge, and its rear.
local function leading(train)
  local best, best_y
  for _, car in pairs(train.carriages) do
    local y = car.bounding_box.left_top.y
    if not best_y or y < best_y then
      best, best_y = car, y
    end
  end
  return best, best_y, best and best.bounding_box.right_bottom.y
end

local function stock_prototype(name)
  return prototypes.entity[name]
end

-- The distance between the centres of two coupled carriages, from their prototypes (7 for vanilla).
local function half_length(name)
  local prototype = stock_prototype(name)
  return ((prototype.joint_distance or 4) + (prototype.connection_distance or 3)) / 2
end

-- Where the next carriage of kind `name` appears: on the partner's arrival lane, its front at the
-- end of the hidden rails behind the ring (a vanilla locomotive's centre 3.5 tiles south of the rail
-- end, its rear still behind the ring's plane), so it drives out through the veil.
local function spawn_position(target, name)
  local c = center(target)
  return {x = c.x + layout(target).arrive, y = c.y + RAIL_END + half_length(name) - 1}
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

-- One carriage meeting the veil at lane `dx` of `record`'s gate: the splash animation (16 frames, two
-- ticks each, starting on its first frame whatever the tick), centred on the lane and covering the
-- column of the veil the carriage fills on screen as it vanishes or appears, and a short sound there.
local SPLASH_FRAMES = 16
local SPLASH_TICKS = 32
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
end

local function start(record, target, train, car)
  local schedule = train.get_schedule()
  local saved = {manual = train.manual_mode}
  if schedule then
    saved.records = schedule.get_records()
    saved.interrupts = schedule.get_interrupts()
    saved.group = schedule.group
    saved.current = schedule.current
  end
  saved.station = record.station and record.station.valid and record.station.backer_name or record.name
  storage.rail_transfers[#storage.rail_transfers + 1] = {
    from = record.entity.unit_number, to = target.entity.unit_number, car = car, saved = saved, start = game.tick
  }
  drive(train, false)
end

-- Sends any train that has reached the ring of an open station gate whose partner is a station too.
function Railway.check()
  for _, record in pairs(storage.gates) do
    if record.railway and record.rail_layout ~= LAYOUT and record.entity.valid then
      build(record)
    end
    local spec = layout(record)
    local target = spec and record.entity.valid and Gate.partner(record)
    if target and layout(target) and Gate.is_open(record) and not receiving(target) then
      local c = center(record)
      for _, car in pairs(record.entity.surface.find_entities_filtered({type = ROLLING_STOCK,
          area = lane_area(record, spec.depart, RAIL_END - 0.5, EDGE + REACH)})) do
        local train = car.train
        if train and car.bounding_box.left_top.y <= c.y + EDGE + REACH and not guarded(car)
          and not in_transfer(train) and train.speed * south_sign(train) <= 0.01
          -- Only into a free arrival lane, so a train that cannot go stays in its schedule.
          and room({}, target, car.name) then
          start(record, target, train, car)
          break
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
local function send(transfer, record, target, car)
  local position = spawn_position(target, car.name)
  local driver, watchers = crew(car)
  -- The clone keeps the carriage's orientation, and it must leave the partner facing the way it
  -- entered relative to its motion, so the carriage is turned first; turning needs it uncoupled.
  car.disconnect_rolling_stock(defines.rail_direction.front)
  car.disconnect_rolling_stock(defines.rail_direction.back)
  car.rotate()
  local clone = car.clone({position = position, surface = target.entity.surface, force = car.force, create_build_effect_smoke = false})
  if not clone then
    car.rotate()
    car.connect_rolling_stock(defines.rail_direction.front)
    car.connect_rolling_stock(defines.rail_direction.back)
    if driver then
      car.set_driver(driver)
    end
    return false
  end
  if driver and driver.valid then
    driver.teleport(clone.position, clone.surface)
    clone.set_driver(driver)
  end
  for _, player in pairs(watchers) do
    if player.valid then
      player.opened = clone
    end
  end
  splash(record, layout(record).depart, "bte-stargate-car-in")
  splash(target, layout(target).arrive, "bte-stargate-car-out")
  car.destroy()
  storage.rail_guard[clone.unit_number] = game.tick + GUARD_TICKS
  transfer.last = clone
  return true
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
  restore_schedule(train, transfer.saved)
  train.manual_mode = transfer.saved.manual
  -- Leaves at the speed it came through; an automatic train then follows its path.
  train.speed = SPEED * south_sign(train)
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
      local car = transfer.car
      local train = car and car.valid and car.train
      if not train then
        finish(index, transfer)
      else
        local front, _, rear = leading(train)
        local c = center(record)
        if rear <= c.y + RING_PLANE and room(transfer, target, front.name) then
          local rest = front.get_connected_rolling_stock(defines.rail_direction.front)
          if not rest or rest == front then
            rest = front.get_connected_rolling_stock(defines.rail_direction.back)
          end
          if send(transfer, record, target, front) then
            transfer.car = rest
            train = rest and rest.valid and rest.train
          end
        end
        if train and train.valid then
          local _, _, next_rear = leading(train)
          if next_rear <= c.y + RING_PLANE then
            train.manual_mode = true
            train.speed = 0
          else
            drive(train, false)
          end
        end
        if transfer.last and transfer.last.valid and transfer.last.train then
          drive(transfer.last.train, true)
        end
        if not (transfer.car and transfer.car.valid) then
          finish(index, transfer)
        end
      end
    end
  end
end

function Railway.active()
  return storage.rail_transfers and storage.rail_transfers[1] ~= nil
end

return Railway
