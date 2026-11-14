-- Finished gates: their names, pairing, on/off switch, power, lights, and sending travellers.
-- A gate is an assembling machine running a hidden no-op recipe on a void energy source
-- (prototypes/entities.lua), so the engine applies its circuit condition and shows the veil exactly
-- while this module lets it work, which is while its portal is open. Its power is a companion
-- electric energy interface, the capacitor, which charges from spare power whenever it can. A
-- switched-on gate whose circuit condition allows it opens once the capacitor is full, then draws
-- UPKEEP from its store and closes when it is switched off, closed by the circuit, or the store runs dry.
-- Its status lights, on its body companion, turn red while a switched-on gate's capacitor is not full.
-- Every TRANSFER_TICKS this module hands any character standing in an open gate's portal to
-- scripts/transfer.lua, which sends it to the front of the partner, or with no partner to a random
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
-- anywhere else, through the ring and behind it, and vehicles go everywhere. A character is in the
-- portal, from either side, within PORTAL_HALF_WIDTH of the centre line (the whole gap between the
-- side blocks, so nobody slips past at the ring's edge) and from PORTAL_BACK to PORTAL_FRONT about the
-- ring's plane. The zone is two tiles deep, more than the fastest runner covers between two checks
-- (TRANSFER_TICKS). Travellers arrive ARRIVAL tiles south of the partner's ring, just clear of its zone.
local RING_Z = 2
local PORTAL_HALF_WIDTH = 3
local PORTAL_BACK = -0.5
local PORTAL_FRONT = 1.5
local ARRIVAL = 1.9
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
-- The gate's power (prototypes/entities.lua): the store's capacity, the open portal's upkeep
-- (1 GW), and the most a closed gate charges at (charge_rate) or an open one refills at beyond its
-- upkeep (refill), both on top of the leak: 1.05 GW while charging, 1.25 GW while open and refilling.
local function power()
  return prototypes.mod_data["bte-stargate-power"].data
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

function Gate.init_storage()
  storage.gates = storage.gates or {}
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

local function center(record)
  local position = record.entity.position
  return {x = position.x + CENTER, y = position.y + CENTER}
end

-- The capacitor, placed (or replaced) on demand so gates from older versions get one too.
local function capacitor(record)
  if not (record.capacitor and record.capacitor.valid) then
    local gate = record.entity
    record.capacitor = gate.surface.create_entity({name = CAPACITOR, position = center(record), force = gate.force})
    record.capacitor.destructible = false
  end
  return record.capacitor
end

local function remove_companions(record)
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
  for _, key in pairs({"body", "top", "veil", "veil_top", "lights", "lights_high"}) do
    if record[key] and record[key].valid then
      record[key].destroy()
    end
  end
  record.capacitor, record.body, record.lights, record.lights_high, record.lights_state, record.top = nil, nil, nil, nil, nil, nil
  record.veil, record.veil_top = nil, nil
end

-- The gate's store is a power bank (scripts/power_bank.lua, a copy of Warp Drive's; see
-- docs/power.md): charged through the capacitor, leaking 0.5 % of its size a second, with an
-- adaptive request. Opening spends 80 % of a full store; the rest is the reserve the upkeep runs
-- from while the network refills it.
local function bank(record)
  if not record.bank then
    -- Gates from before the bank kept their charge on the record.
    record.bank = {charge = record.charge or 0}
    record.charge, record.request, record.step, record.applied, record.received = nil, nil, nil, nil, nil
    record.hold_until, record.charge_tick = nil, nil
  end
  return record.bank
end

-- One tick of the gate's power: a gate that is switched off, or closed by its circuit, charges
-- only if set to keep charged; otherwise its charge leaks away.
local function collect(record)
  local spec = power()
  local cap = spec.capacity
  local charging = record.keep_charged or (record.enabled and Gate.circuit_allows(record))
  local load = record.open and spec.upkeep or 0
  local refill = record.open and spec.refill or spec.charge_rate
  PowerBank.tick(bank(record), capacitor(record), {
    capacity = cap, load = load,
    max_draw = charging and PowerBank.max_draw(cap, load, refill) or 0
  })
end

-- Runs every tick: charges every gate's store from its capacitor.
function Gate.collect()
  for _, record in pairs(storage.gates) do
    if record.entity.valid then
      collect(record)
    end
  end
end

-- The power the gate has learned it can ask the grid for, in watts.
function Gate.request(record)
  return bank(record).request or 0
end

-- Whether an open gate's store is draining: the network gave less than the upkeep last tick.
function Gate.short_of_power(record)
  return record.open and (bank(record).received or 0) * 60 * PowerBank.EFFICIENCY < power().upkeep * 0.999
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
local function show_body(record, red)
  local variation = red and 2 or 1
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
    if entity.graphics_variation ~= variation then
      entity.graphics_variation = variation
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
    record.veil_from = game.tick + 120
  elseif was_open and not record.open then
    play_transition(record, "closing")
    record.veil_from = nil
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
end

-- Opens or closes the portal from the switch, pairing, circuit condition, and charge, and keeps the
-- engine's state, the capacitor's draw, the lights, and the barriers in step.
local function apply(record)
  capacitor(record)
  -- A gate without a partner opens too: it sends travellers to random destinations.
  local ready = record.enabled and Gate.circuit_allows(record)
  local was_open = record.open
  local store = bank(record)
  if record.open then
    record.open = ready and store.charge > 1
  elseif ready and Gate.charge(record) >= FULL then
    -- Opening spends 80 % of the full store; the upkeep then runs from the rest.
    record.open = PowerBank.activate(store, capacity() * FULL)
  end
  record.entity.disabled_by_script = not record.open
  -- Red while a switched-on gate charges, or while an open one is short of power.
  local red = record.enabled and (record.open and Gate.short_of_power(record) or (not record.open and Gate.charge(record) < FULL))
  show_body(record, red)
  show_veil(record, was_open)
  if was_open ~= record.open and (was_open or record.open) then
    record.entity.surface.play_sound({path = record.open and "bte-stargate-open" or "bte-stargate-close", position = center(record)})
  end
  sync_barriers(record)
end

function Gate.register(entity)
  if not (entity and entity.valid) or storage.gates[entity.unit_number] then
    return
  end
  local record = {entity = entity, name = random_name(), enabled = true, open = false}
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
end

function Gate.set_name(record, name)
  record.name = name
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
local function prune()
  for id, record in pairs(storage.gates) do
    if not record.entity.valid then
      remove_barriers(record)
      remove_companions(record)
      storage.gates[id] = nil
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

function Gate.rebuild()
  Gate.init_storage()
  prune()
  for _, surface in pairs(game.surfaces) do
    for _, entity in pairs(surface.find_entities_filtered({name = GATE})) do
      Gate.register(entity)
    end
  end
  for _, record in pairs(storage.gates) do
    -- Placed afresh, so a configuration change also repairs any that went missing.
    remove_barriers(record)
    apply(record)
  end
end

function Gate.removed(entity)
  local record = storage.gates[entity.unit_number]
  if record then
    unpair(record)
    remove_barriers(record)
    remove_companions(record)
    storage.gates[entity.unit_number] = nil
  end
end

-- Open, and with somewhere to send travellers: its partner, or a planet its force has visited.
function Gate.is_open(record)
  return record.open == true and (partner_of(record) ~= nil or Destinations.any(record.entity.force))
end

local function in_portal(record, position)
  local gate = record.entity.position
  local dy = position.y - (gate.y + CENTER + RING_Z)
  return math.abs(position.x - (gate.x + CENTER)) < PORTAL_HALF_WIDTH and dy > PORTAL_BACK and dy < PORTAL_FRONT
end

-- Where a gate receives travellers: just in front of its portal, clear of its zone.
function Gate.arrival(target)
  local gate, surface = target.entity.position, target.entity.surface
  local front = {gate.x + CENTER, gate.y + CENTER + RING_Z + ARRIVAL}
  local position = surface.find_non_colliding_position("character", front, 8, 0.1) or front
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

-- The portal's area, a little larger than in_portal() so the search finds everyone it could accept.
local function portal_area(record)
  local x, y = record.entity.position.x + CENTER, record.entity.position.y + CENTER + RING_Z
  return {{x - PORTAL_HALF_WIDTH, y + PORTAL_BACK - 0.3}, {x + PORTAL_HALF_WIDTH, y + PORTAL_FRONT + 0.3}}
end

-- Updates every gate's barriers and calls `enter(character, record)` for each character in an open portal.
function Gate.update(enter)
  for _, record in pairs(storage.gates) do
    if record.entity.valid then
      apply(record)
      if Gate.is_open(record) then
        for _, character in pairs(record.entity.surface.find_entities_filtered({type = "character", area = portal_area(record)})) do
          if in_portal(record, character.position) and not character.vehicle then
            enter(character, record)
          end
        end
      end
    end
  end
end

Gate.prune = prune

return Gate
