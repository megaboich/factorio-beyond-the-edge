-- Finished gates: their names, pairing, on/off switch, power, lights, and sending travellers.
-- A gate is an assembling machine running a hidden no-op recipe on a void energy source
-- (prototypes/entities.lua), so the engine applies its circuit condition and loops its working sound
-- while this module lets it work, which is while its portal is open. Its power is a companion
-- electric energy interface, the capacitor, which charges from spare power whenever it can. A
-- switched-on gate whose circuit condition allows it opens once the capacitor is full, then draws
-- UPKEEP from its store and closes when it is switched off, closed by the circuit, or the store runs dry.
-- Its status lights, on its body and top companions, turn red while a switched-on gate charges or an
-- open one gets less than its upkeep.
-- Every TRANSFER_TICKS this module hands any traveller (character, vehicle, or enemy) in an open
-- gate's portal to scripts/transfer.lua, which sends it to the front of the partner, or with no partner to a random
-- destination. A receiving gate needs no power and may be off.
local Destinations = require("scripts.destinations")
local PowerBank = require("scripts.power_bank")

local Gate = {}

local GATE = "bte-stargate"
-- The building's centre is one tile south-east of its position (prototypes/entities.lua).
local CENTER = 1
-- The ring stands this far south of the centre (tools/sprites/lib/stargate-parts.js, RING_Z).
-- Invisible blocks (prototypes/entities.lua, BARRIERS below) cover only the machinery: the west and
-- east strips from PORTAL_HALF_WIDTH out, and the two front corners' cabinet and rack. Characters walk
-- anywhere else, through the ring and behind it, and vehicles go everywhere. A traveller is in the
-- portal, from either side, when its centre lies within PORTAL_HALF_WIDTH of the centre line (the
-- whole gap between the side blocks, so neither people nor vehicles hugging the side slip past) and
-- from PORTAL_BACK to PORTAL_FRONT about the ring's plane. The zone is 2.5 tiles deep, more than a
-- fast car on refined concrete covers between two checks (TRANSFER_TICKS). Travellers arrive in front
-- of the partner's ring, just clear of its zone, and beside the rails on a station gate (Gate.arrival).
local RING_Z = 2
local PORTAL_HALF_WIDTH = 3
local PORTAL_BACK = -1
local PORTAL_FRONT = 1.5
-- A character (box 0.2 from its centre) arrives 1.9 tiles south of the ring; on a single-track
-- station gate, where the rail runs down the middle, arrivals step out beside it (-2.5); two-track
-- gates keep the centre strip between the two lanes.
local ARRIVAL_MARGIN = 0.2
local SINGLE_ARRIVAL_DX = -2.5
-- Each block's prototype and centre, in tiles from the building's centre.
local BARRIERS = {
  west = {"bte-stargate-side-block", -4.975, -1.675},
  east = {"bte-stargate-side-block", 4.975, -1.675},
  cabinet = {"bte-stargate-cabinet-block", -5.4, 6.1},
  rack = {"bte-stargate-rack-block", 5.4, 5.65}
}
local CAPACITOR = "bte-stargate-capacitor"
local BODY = "bte-stargate-body"
local TOP = "bte-stargate-top"
local VEIL = {veil = "bte-stargate-veil", veil_top = "bte-stargate-veil-top"}
-- The open veil's cyan light on its surroundings, centred where the veil's middle is drawn: the
-- ring's centre stands 2.8 tiles high on the ring's line, about 1.6 tiles up on screen.
local VEIL_LIGHT = {sprite = "utility/light_medium", scale = 5, intensity = 0.55, color = {0.2, 0.8, 1}}
local VEIL_LIGHT_UP = 1.6
-- The gate's power (prototypes/entities.lua): the store's capacity, the open portal's upkeep
-- (1 GW), and the most a closed gate charges at (charge_rate) or an open one refills at beyond its
-- upkeep (refill), both on top of the leak: 1.05 GW while charging, 1.25 GW while open and refilling.
-- Cached: reading `data` converts the whole prototype table to Lua on every call, and the power is
-- read for every gate every tick. Prototypes cannot change while a save runs, and the cache is a
-- module local rebuilt with the script on every load.
local power_data
local function power()
  power_data = power_data or prototypes.mod_data["bte-stargate-power"].data
  return power_data
end
local function capacity()
  return power().capacity
end
-- A capacitor this close to its size counts as full, against rounding in the energy network.
local FULL = 0.999
Gate.TRANSFER_TICKS = 3

local NAMES = {
  "Abydos", "Chulak", "Dakara", "Tollana", "Vorash", "Kheb", "Hala", "Orilla", "Langara", "Edora",
  "Cimmeria", "Argos", "Hebridan", "Sahal", "Juna", "Netu", "Atlas", "Helios", "Vega", "Altair",
  "Deneb", "Rigel", "Mira", "Lyra", "Orion", "Castor", "Pollux", "Sirius", "Antares", "Polaris"
}

-- What can travel: characters on foot, cars and tanks (car), spidertrons (spider-vehicle), and
-- biters, spitters, and pentapods (unit, spider-unit) of any force.
local TRAVELLERS = {"character", "car", "spider-vehicle", "unit", "spider-unit"}

function Gate.init_storage()
  storage.gates = storage.gates or {}
  storage.active_gates = storage.active_gates or {}
end

-- Gates whose power bank needs per-tick work (charging, refilling, or leaking down). Built lazily
-- if missing so existing saves reloaded without a version bump migrate on their first tick.
local function active_gates()
  local active = storage.active_gates
  if not active then
    active = {}
    for id, record in pairs(storage.gates or {}) do
      if record.entity.valid then
        active[id] = record
      end
    end
    storage.active_gates = active
  end
  return active
end

local function wake(record)
  if record and record.entity and record.entity.valid then
    active_gates()[record.entity.unit_number] = record
  end
end

local function random_name()
  return NAMES[math.random(#NAMES)] .. "-" .. math.random(100, 999)
end

function Gate.get(unit_number)
  local record = storage.gates[unit_number]
  if record and record.entity.valid then
    return record
  end
end

local function place_barrier(record, name, dx, dy)
  local gate = record.entity
  local barrier = gate.surface.create_entity({
    name = name, position = {gate.position.x + CENTER + dx, gate.position.y + CENTER + dy},
    force = gate.force, create_build_effect_smoke = false
  })
  if barrier then
    barrier.destructible = false
  end
  return barrier
end

local function destroy_barrier(barrier)
  if barrier and barrier.valid then
    barrier.destroy()
  end
end

local function remove_barriers(record)
  for _, barrier in pairs(record.barriers or {}) do
    destroy_barrier(barrier)
  end
  record.barriers = nil
end

-- Places the barriers over the machinery, once; gates from before this layout get the new set.
local function sync_barriers(record)
  local barriers = record.barriers
  if barriers and not barriers.cabinet then
    remove_barriers(record)
    barriers = nil
  end
  if not barriers then
    barriers = {}
    for key, spec in pairs(BARRIERS) do
      barriers[key] = place_barrier(record, spec[1], spec[2], spec[3])
    end
    record.barriers = barriers
  end
end

local function partner_of(record)
  return record.partner and Gate.get(record.partner)
end

-- Static geometry for an immovable gate, cached on the record so the frequent portal scan never
-- crosses into C++ for position or surface or allocates search tables.
local function geometry(record)
  if not record.search_filter or not record.count_filter then
    local gate = record.entity
    local position = gate.position
    local cx, cy = position.x + CENTER, position.y + CENTER
    local ry = cy + RING_Z
    local area = {{cx - PORTAL_HALF_WIDTH, ry + PORTAL_BACK}, {cx + PORTAL_HALF_WIDTH, ry + PORTAL_FRONT}}
    record.unit_number = gate.unit_number
    record.surface = gate.surface
    record.cx, record.cy = cx, cy
    record.center = {x = cx, y = ry - RING_Z}
    record.search_filter = {type = TRAVELLERS, area = area}
    record.count_filter = {type = TRAVELLERS, area = area, limit = 1}
  end
  return record.center
end

local function center(record)
  return geometry(record)
end

-- The capacitor, placed (or replaced) on demand so gates from older versions get one too.
local function capacitor(record)
  if not (record.capacitor and record.capacitor.valid) then
    local gate = record.entity
    record.capacitor = gate.surface.create_entity({name = CAPACITOR, position = center(record), force = gate.force})
    record.capacitor.destructible = false
    record.capacitor_idle = nil
    if record.bank then
      record.bank.applied = nil
    end
  end
  return record.capacitor
end

-- Removes station mode's rails and stop (scripts/railway.lua), and any carriage on those rails first:
-- a rail cannot be removed from under one.
function Gate.remove_railway(record)
  for _, rail in pairs(record.rails or {}) do
    if rail.valid then
      for _, car in pairs(rail.surface.find_entities_filtered({type = {"locomotive", "cargo-wagon", "fluid-wagon",
          "artillery-wagon", "infinity-cargo-wagon"}, area = rail.bounding_box})) do
        car.destroy()
      end
      rail.destroy()
    end
  end
  if record.station and record.station.valid then
    record.station.destroy()
  end
  for _, signal in pairs(record.signals or {}) do
    if signal.valid then
      signal.destroy()
    end
  end
  if record.entry_control and record.entry_control.valid then
    record.entry_control.destroy()
  end
  if storage.station_gates then
    local id = record.unit_number or (record.entity and record.entity.valid and record.entity.unit_number)
    if id then
      storage.station_gates[id] = nil
    end
  end
  record.rails, record.edge_rail, record.station = nil, nil, nil
  record.signals, record.exit_signal, record.entry_control, record.entry_open = nil, nil, nil, nil
  record.depart_filter, record.depart_edge_y = nil, nil
end

local function remove_companions(record)
  Gate.remove_railway(record)
  if record.capacitor and record.capacitor.valid then
    record.capacitor.destroy()
  end
  -- Render objects of earlier versions (lights_high) go too.
  for _, fx in pairs(record.veil_fx or {}) do
    if fx.valid then
      fx.destroy()
    end
  end
  record.veil_fx = nil
  for _, key in pairs({"body", "top", "veil", "veil_top", "veil_light", "lights", "lights_high", "tracks"}) do
    if record[key] and record[key].valid then
      record[key].destroy()
    end
  end
  record.capacitor, record.capacitor_idle = nil, nil
  record.body, record.lights, record.lights_high, record.lights_state, record.top = nil, nil, nil, nil, nil
  record.veil, record.veil_top, record.veil_light, record.tracks = nil, nil, nil, nil
end

-- The gate's store is a power bank (scripts/power_bank.lua, a copy of Warp Drive's; see
-- docs/power.md): charged through the capacitor, leaking 0.5 % of its size a second, with an
-- adaptive request. Opening spends 80 % of a full store; the rest is the reserve the upkeep runs
-- from while the network refills it. While a closed gate is not charging, its capacitor is zeroed
-- once and its exponential leak is evaluated analytically on demand (decay_from), so inactive gates
-- leave storage.active_gates on the next tick instead of ticking for an hour until empty.
local DECAY_PER_TICK = 1 - PowerBank.LEAK_PER_SECOND / 60

local function sync_decay(store)
  local from = store.decay_from
  if from then
    local now = game.tick
    local dt = now - from
    if dt > 0 then
      local next_charge = (store.charge or 0) * (DECAY_PER_TICK ^ dt)
      store.charge = next_charge < 1 and 0 or next_charge
      store.received = 0
      store.delivered_ticks = (store.delivered_ticks or 0) + dt
    end
    store.decay_from = (store.charge or 0) > 0 and now or nil
    store.tick = now
  end
  return store
end

local function bank(record)
  local store = record.bank
  if not store then
    -- Gates from before the bank kept their charge on the record.
    store = {charge = record.charge or 0}
    record.bank = store
    record.charge, record.request, record.step, record.applied, record.received = nil, nil, nil, nil, nil
    record.hold_until, record.charge_tick = nil, nil
  elseif store.decay_from then
    sync_decay(store)
  end
  return store
end

-- One tick of an active gate's power: a gate that is switched off, or closed by its circuit,
-- charges only if set to keep charged; otherwise its capacitor is zeroed once and its decay runs
-- analytically via decay_from, so both direct and idle gates leave storage.active_gates immediately.
local OPTIONS = {}
local function collect(id, record, active)
  local spec = power()
  local cap = spec.capacity
  -- record.ready is the switch and circuit condition as apply() last read them, every few ticks.
  local charging = record.keep_charged or record.ready
  local load = record.open and spec.upkeep or 0
  local refill = record.open and spec.refill or spec.charge_rate
  local options = OPTIONS
  options.capacity, options.load = cap, load
  options.max_draw = charging and PowerBank.max_draw(cap, load, refill) or 0
  local store = bank(record)
  if store.direct then
    -- The engine draws the steady need (PowerBank.enter_direct) and Gate.check_power watches it; a
    -- change of state, or opening spending the store, ends that.
    if store.direct == PowerBank.direct_need(options) and store.charge >= cap * FULL then
      active[id] = nil
      return
    end
    PowerBank.leave_direct(store, record.capacitor)
    record.capacitor_idle = nil
  end
  if not charging and not record.open then
    if not record.capacitor_idle then
      local unit = capacitor(record)
      PowerBank.tick(store, unit, options)
      record.capacitor_idle = true
    end
    if (store.charge or 0) >= 1 then
      store.decay_from = game.tick
    else
      store.charge, store.decay_from = 0, nil
    end
    active[id] = nil
    return
  end
  store.decay_from = nil
  record.capacitor_idle = nil
  local unit = capacitor(record)
  PowerBank.tick(store, unit, options)
  if PowerBank.ready_for_direct(store, options) then
    PowerBank.enter_direct(store, unit, PowerBank.direct_need(options), cap)
    active[id] = nil
  end
end

-- Once a second: compares what each network's capacitors drew, from its flow statistics, with what
-- the gates' banks assumed (PowerBank.expected), and charges any shortfall to the direct banks there,
-- returning them to the adaptive request. The statistics are per network and prototype, so the
-- gates of one network are judged together: in a shortage the engine gives each the same share.
-- A network seen for the first time, or after it changed, is only measured, not judged.
local function network_statistics(record)
  local sub = record.capacitor and record.capacitor.electric_network
  return sub and sub.parent_network.statistics
end

function Gate.check_power()
  local networks = {}
  for _, record in pairs(storage.gates) do
    local store = record.bank
    if store and record.entity.valid and record.capacitor and record.capacitor.valid then
      local id = record.capacitor.electric_network_id
      if not id then
        -- Off every network: it draws nothing, so it cannot stay direct.
        PowerBank.expected(store)
        if store.direct then
          PowerBank.leave_direct(store, record.capacitor)
          record.capacitor_idle = nil
          wake(record)
        end
      else
        local network = networks[id] or {records = {}, expected = 0, direct = 0}
        networks[id] = network
        local joules = PowerBank.expected(store)
        network.records[#network.records + 1] = {record = record, joules = joules}
        network.expected = network.expected + joules
        if store.direct then
          network.direct = network.direct + joules
          network.any_direct = true
        end
      end
    end
  end
  local counts = {}
  for id, network in pairs(networks) do
    local stats = network_statistics(network.records[1].record)
    local count = stats and stats.get_input_count(CAPACITOR)
    counts[id] = count
    local last = storage.power_counts and storage.power_counts[id]
    if network.any_direct and count and last then
      local missing = network.expected - (count - last)
      -- Smart banks' figures are exact, so what is missing is the direct banks'; a tick's worth of
      -- timing slack is allowed.
      if missing > network.direct / 60 + 1e3 then
        for _, entry in pairs(network.records) do
          local store = entry.record.bank
          if store.direct then
            PowerBank.shortfall(store, entry.record.capacitor, missing * entry.joules / network.direct)
            entry.record.capacitor_idle = nil
            wake(entry.record)
          end
        end
      end
    elseif network.any_direct and not count then
      for _, entry in pairs(network.records) do
        if entry.record.bank.direct then
          PowerBank.leave_direct(entry.record.bank, entry.record.capacitor)
          entry.record.capacitor_idle = nil
          wake(entry.record)
        end
      end
    end
  end
  storage.power_counts = counts
end

-- Runs every tick: advances only the gates whose banks are actively charging or leaking down.
function Gate.collect()
  local active = active_gates()
  if not next(active) then
    return
  end
  for id, record in pairs(active) do
    if record.entity.valid then
      collect(id, record, active)
    else
      active[id] = nil
    end
  end
end

-- Empties the store, wakes the bank, and returns what arrived from the network in the last update.
function Gate.take_charge(record)
  local store = bank(record)
  store.charge = 0
  store.decay_from = nil
  if store.direct then
    PowerBank.leave_direct(store, record.capacitor)
  end
  record.capacitor_idle = nil
  wake(record)
  return store.received or 0
end

-- Whether an open gate's store is draining: the network gave less than the upkeep last tick.
function Gate.short_of_power(record)
  return record.open and (bank(record).received or 0) * 60 < power().upkeep * 0.999
end

-- What the gate draws from the network, in watts, split by use: the open portal's upkeep, the
-- store's leak, and charging. The draw covers the upkeep first and
-- the leak next; what is left charges the store. Averaged since the last call (a direct bank draws
-- its steady need), and kept for the rest of the tick so every open window shows the same figures.
function Gate.power_flow(record)
  local flow = record.flow
  if flow and flow.tick == game.tick then
    return flow
  end
  local store = bank(record)
  local drawn = PowerBank.delivered(store)
  if store.direct then
    drawn = store.direct
  end
  local upkeep = math.min(drawn, record.open and power().upkeep or 0)
  local leak = math.min(drawn - upkeep, PowerBank.leak(store.charge or 0))
  flow = {tick = game.tick, upkeep = upkeep, leak = leak, charging = math.max(0, drawn - upkeep - leak)}
  record.flow = flow
  return flow
end

-- The store's fill, 0 to 1.
function Gate.charge(record)
  return (bank(record).charge or 0) / capacity()
end

-- Whether the circuit condition, if the gate uses one, lets it open.
function Gate.circuit_allows(record)
  local behavior = record.entity.get_control_behavior()
  return not (behavior and behavior.circuit_enable_disable and behavior.disabled)
end

-- The building and its status lights (prototypes/entities.lua): bte-stargate-body on the ring's
-- line, so Factorio draws characters behind the ring under it and those in front over it, and
-- bte-stargate-top, the upper arc again, over spidertrons. Variation 1 has cyan lights, 2 red.
-- Created on demand, so gates from earlier versions get them and lose the render objects they drew.
local TRACK_MODES = {single = 1, right = 2, left = 2}
-- The track companion's picture: one track, or two with chevrons for each layout.
local TRACK_PICTURES = {single = 1, right = 2, left = 3}
local function show_body(record, red)
  -- The station's track (scripts/railway.lua) is a companion of its own, and the body's picture for
  -- it has the track cut out where it crosses the ring's lower arc (prototypes/entities.lua).
  local mode = TRACK_MODES[record.railway] or 0
  local variation = mode * 2 + (red and 2 or 1)
  local tracks = record.tracks
  if mode == 0 or not (tracks and tracks.valid) then
    if tracks and tracks.valid and mode == 0 then
      tracks.destroy()
    end
    record.tracks = nil
    if mode > 0 then
      local c = center(record)
      tracks = record.entity.surface.create_entity({name = "bte-stargate-tracks", position = {c.x, c.y + RING_Z},
        force = record.entity.force, create_build_effect_smoke = false})
      tracks.destructible = false
      record.tracks = tracks
    end
  end
  local picture = TRACK_PICTURES[record.railway]
  if record.tracks and record.tracks.graphics_variation ~= picture then
    record.tracks.graphics_variation = picture
  end
  for key, name in pairs({body = BODY, top = TOP}) do
    local entity = record[key]
    -- Earlier versions kept a render object under `top`.
    if entity and entity.valid and entity.object_name ~= "LuaEntity" then
      entity.destroy()
      entity = nil
    end
    if not (entity and entity.valid) then
      for _, old in pairs({"lights", "lights_high"}) do
        if record[old] and record[old].valid then
          record[old].destroy()
        end
        record[old] = nil
      end
      record.lights_state = nil
      local gate = record.entity
      local c = center(record)
      entity = gate.surface.create_entity({
        name = name, position = {c.x, c.y + RING_Z}, force = gate.force, create_build_effect_smoke = false
      })
      entity.destructible = false
      record[key] = entity
    end
    local wanted = key == "body" and variation or (red and 2 or 1)
    if entity.graphics_variation ~= wanted then
      entity.graphics_variation = wanted
    end
  end
end

-- Plays the portal forming or collapsing once (prototypes/entities.lua, 4 ticks a frame), its lower
-- half with objects and its upper half over spidertrons, like the veil companions.
local TRANSITIONS = {opening = {frames = 32, ticks = 128}, closing = {frames = 18, ticks = 72}}
local function play_transition(record, name)
  for _, fx in pairs(record.veil_fx or {}) do
    if fx.valid then
      fx.destroy()
    end
  end
  local spec = TRANSITIONS[name]
  local speed = 1 / 4
  record.veil_fx = {}
  for part, layer in pairs({[""] = "object", ["-high"] = "elevated-object"}) do
    record.veil_fx[#record.veil_fx + 1] = rendering.draw_animation({
      animation = "bte-stargate-" .. name .. part, target = record.entity, surface = record.entity.surface,
      render_layer = layer, animation_speed = speed,
      -- Starts on the first frame whatever the tick.
      animation_offset = (spec.frames - (game.tick * speed) % spec.frames) % spec.frames,
      time_to_live = spec.ticks
    })
  end
end

-- The open portal's veil (prototypes/entities.lua): two companions on the ring's line, the lower
-- part sorted with characters and the upper drawn over spidertrons, present only while open, once
-- the opening animation has played (record.veil_from); closing plays its collapse instead.
local function show_veil(record, was_open)
  if record.open and not was_open then
    play_transition(record, "opening")
  elseif was_open and not record.open then
    play_transition(record, "closing")
  end
  for key, name in pairs(VEIL) do
    local entity = record[key]
    if record.open and game.tick >= (record.veil_from or 0) and not (entity and entity.valid) then
      local gate = record.entity
      local c = center(record)
      entity = gate.surface.create_entity({
        name = name, position = {c.x, c.y + RING_Z}, force = gate.force, create_build_effect_smoke = false
      })
      entity.destructible = false
      record[key] = entity
    elseif not record.open and entity then
      if entity.valid then
        entity.destroy()
      end
      record[key] = nil
    end
  end
  local light = record.veil_light
  if record.open and game.tick >= (record.veil_from or 0) and not (light and light.valid) then
    local c = center(record)
    record.veil_light = rendering.draw_light({sprite = VEIL_LIGHT.sprite, scale = VEIL_LIGHT.scale,
      intensity = VEIL_LIGHT.intensity, color = VEIL_LIGHT.color, surface = record.entity.surface,
      target = {c.x, c.y + RING_Z - VEIL_LIGHT_UP}})
  elseif not record.open and light then
    if light.valid then
      light.destroy()
    end
    record.veil_light = nil
  end
end

-- Opens or closes the portal from the switch, pairing, circuit condition, and charge, and keeps the
-- engine's state, the capacitor's draw, the lights, and the barriers in step.
--
-- With `quick` (the frequent update), the companions are only touched when what they show changes:
-- checking each one every few ticks cost more than the rest of the gate's script. They are
-- indestructible, and every other call, including configuration changes, checks them all.
local SHOWN_RAILWAY = {single = 8, right = 16, left = 24}

local function apply(record, quick, now)
  if not quick then
    capacitor(record)
  end
  now = now or game.tick
  -- A gate without a partner opens too: it sends travellers to random destinations.
  local was_ready = record.ready
  local ready = record.enabled and Gate.circuit_allows(record)
  record.ready = ready
  local was_open = record.open
  local store = bank(record)
  local spec = power()
  local cap = spec.capacity
  if record.open then
    record.open = ready and (store.charge or 0) > 1
  elseif ready and (store.charge or 0) >= cap * FULL then
    -- Opening spends 80 % of the full store; the upkeep then runs from the rest.
    record.open = PowerBank.activate(store, cap * FULL)
  end
  if not quick or ready ~= was_ready or record.open ~= was_open then
    wake(record)
  end
  if was_open ~= record.open or not quick then
    record.entity.disabled_by_script = not record.open
  end
  if record.open and not was_open then
    record.veil_from = now + 120
  elseif not record.open then
    record.veil_from = nil
  end
  -- Red while a switched-on gate charges, or while an open one is short of power.
  local red = record.enabled and (record.open and (store.received or 0) * 60 < spec.upkeep * 0.999
    or (not record.open and (store.charge or 0) < cap * FULL))
  -- Everything the companions show, packed as an integer so the 3-tick poll allocates no strings.
  local shown = (SHOWN_RAILWAY[record.railway] or 0) + (red and 4 or 0) + (record.open and 2 or 0)
    + (record.open and now >= (record.veil_from or 0) and 1 or 0)
  if quick and shown == record.shown and was_open == record.open then
    return
  end
  record.shown = shown
  show_body(record, red)
  show_veil(record, was_open)
  if was_open ~= record.open and (was_open or record.open) then
    local c = center(record)
    record.surface.play_sound({path = record.open and "bte-stargate-open" or "bte-stargate-close", position = c})
  end
  sync_barriers(record)
end

-- Brings a gate's state and companions up to date, as after a change of station mode.
Gate.refresh = apply

function Gate.register(entity)
  if not (entity and entity.valid) or storage.gates[entity.unit_number] then
    return
  end
  local record = {entity = entity, name = random_name(), enabled = true, open = false}
  geometry(record)
  storage.gates[entity.unit_number] = record
  apply(record)
end

local function unpair(record)
  local partner = partner_of(record)
  record.partner = nil
  if partner and partner.partner == record.entity.unit_number then
    partner.partner = nil
    apply(partner)
  end
  apply(record)
end

-- Pairs two gates both ways, breaking their earlier pairs; `other` nil just unpairs.
function Gate.pair(record, other)
  unpair(record)
  if other and other ~= record then
    unpair(other)
    record.partner = other.entity.unit_number
    other.partner = record.entity.unit_number
    apply(other)
  end
  apply(record)
end

function Gate.partner(record)
  return partner_of(record)
end

function Gate.set_enabled(record, enabled)
  record.enabled = enabled
  apply(record)
end

function Gate.set_keep_charged(record, keep)
  record.keep_charged = keep
  wake(record)
end

function Gate.set_name(record, name)
  record.name = name
  -- The station of a gate in station mode carries its name (scripts/railway.lua).
  if record.station and record.station.valid and record.station.backer_name ~= name then
    record.station.backer_name = name
  end
end

-- Every other gate of the record's force, by name, for the pairing selector.
function Gate.candidates(record)
  local list = {}
  for _, other in pairs(storage.gates) do
    if other ~= record and other.entity.valid and other.entity.force == record.entity.force then
      list[#list + 1] = other
    end
  end
  table.sort(list, function(a, b)
    return a.name < b.name or (a.name == b.name and a.entity.unit_number < b.entity.unit_number)
  end)
  return list
end

-- Drops records of gates that are gone, unpairing their partners.
local function prune(on_removed)
  for id, record in pairs(storage.gates) do
    if not record.entity.valid then
      remove_barriers(record)
      if on_removed then
        on_removed(id, record)
      end
      remove_companions(record)
      storage.gates[id] = nil
      if storage.active_gates then
        storage.active_gates[id] = nil
      end
      for _, other in pairs(storage.gates) do
        if other.partner == id then
          other.partner = nil
          if other.entity.valid then
            apply(other)
          end
        end
      end
    end
  end
end

function Gate.rebuild(on_removed)
  Gate.init_storage()
  prune(on_removed)
  for _, surface in pairs(game.surfaces) do
    for _, entity in pairs(surface.find_entities_filtered({name = GATE})) do
      Gate.register(entity)
    end
  end
  for _, record in pairs(storage.gates) do
    -- Placed afresh, so a configuration change also repairs any that went missing.
    record.search_filter, record.count_filter = nil, nil
    geometry(record)
    remove_barriers(record)
    apply(record)
  end
end

function Gate.removed(entity, on_removed)
  local id = entity.unit_number
  local record = storage.gates[id]
  if record then
    unpair(record)
    remove_barriers(record)
    if on_removed then
      on_removed(id, record)
    end
    remove_companions(record)
    storage.gates[id] = nil
    if storage.active_gates then
      storage.active_gates[id] = nil
    end
  end
end

-- Open, and with somewhere to send travellers: its partner, or a planet its force has visited.
function Gate.is_open(record)
  if not record.open then
    return false
  end
  return partner_of(record) ~= nil or Destinations.any(record.entity.force)
end

local function in_portal(record, position)
  geometry(record)
  local dy = position.y - (record.cy + RING_Z)
  return math.abs(position.x - record.cx) < PORTAL_HALF_WIDTH and dy > PORTAL_BACK and dy < PORTAL_FRONT
end

-- How far a traveller's collision box reaches from its centre in any direction.
local extents = {}
local function extent(name)
  local cached = extents[name]
  if not cached then
    local box = prototypes.entity[name].collision_box
    cached = math.max(-box.left_top.x, -box.left_top.y, box.right_bottom.x, box.right_bottom.y)
    extents[name] = cached
  end
  return cached
end

-- Where a gate receives a traveller (a prototype name, "character" by default): in front of its
-- portal (and west of the centre rail on a single-track station gate), its box just clear of the
-- zone, at the nearest free spot for its kind.
function Gate.arrival(target, name)
  name = name or "character"
  geometry(target)
  local surface = target.surface
  local dx = target.railway == "single" and SINGLE_ARRIVAL_DX or 0
  local front = {target.cx + dx, target.cy + RING_Z + PORTAL_FRONT + extent(name) + ARRIVAL_MARGIN}
  local position = surface.find_non_colliding_position(name, front, 8, 0.1) or front
  return surface, position
end

-- Where a character at `position` beside an open, paired gate is sent, or nil outside the portal.
function Gate.destination(record, position)
  local partner = partner_of(record)
  if not (partner and in_portal(record, position)) then
    return nil
  end
  return Gate.arrival(partner)
end

-- Updates every gate's barriers and calls `enter(entity, record)` for each traveller whose centre is
-- in an open portal. A character in a vehicle travels with the vehicle.
function Gate.update(enter)
  local now = game.tick
  local gates = storage.gates
  for _, record in pairs(gates) do
    if (record.enabled or record.open or not record.shown) and record.entity.valid then
      apply(record, true, now)
      if record.open and ((record.partner and gates[record.partner] ~= nil) or Destinations.any(record.entity.force)) then
        geometry(record)
        local surface = record.surface
        if surface.count_entities_filtered(record.count_filter) > 0 then
          for _, entity in pairs(surface.find_entities_filtered(record.search_filter)) do
            if entity.valid and not (entity.type == "character" and entity.vehicle) and in_portal(record, entity.position) then
              enter(entity, record)
            end
          end
        end
      end
    end
  end
end

Gate.prune = prune

return Gate
