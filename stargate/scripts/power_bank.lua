-- A power bank: an energy store of capacitors, charged from an electric network through a hidden
-- electric-energy-interface, shared by the Beyond the Edge mods' high-power machines.
--
-- This file is the original. Mods cannot share code, so stargate/scripts/power_bank.lua is a
-- verbatim copy: change this one, then copy it over. The behaviour, its formulas, and charts are
-- in docs/power.md at the repository root.
--
-- The store lives in script storage (bank.charge), not in the interface: Factorio counts the
-- buffer of a tertiary interface as accumulator storage, and the network would never let a
-- machine own its charge. The interface is an ordinary secondary-input consumer whose buffer holds
-- one tick of the current request and is emptied into the store every tick (PowerBank.tick). With
-- a larger buffer emptied less often, input_flow_limit did not hold back the refill, which took
-- several ticks' worth in one tick and dipped the network each time.
--
-- Each tick:
-- - the store loses the machine's load and its leak, and gains what the network delivered. The leak is LEAK_PER_SECOND of the charge per second,
--   as a real store's self-discharge scales with what it holds: a full store loses 0.5 % a second, an
--   almost empty one almost nothing, and one left alone decays exponentially (to 37 % in 200 s);
-- - the request adapts: a tick delivered in full raises it by the step, which grows by
--   STEP_GROWTH from MIN_STEP up to MAX_STEP; a shortfall cuts it to at most what arrived, less
--   the step or SHORTFALL_FACTOR times what was missing (but not below half of what arrived),
--   resets the step to MIN_STEP, and holds it for HOLD_TICKS (no hold when nothing arrived). When
--   a network is short Factorio gives every machine-priority consumer the same fraction of its
--   demand, so backing off by more than the bank's own shortfall ends the factory's dip sooner;
--   the constants were tuned with stargate/tests/power-model.py;
-- - the interface asks for the request, at most options.max_draw and what the store can take.
--
-- Direct mode: a full store (or an unstored sink at max_draw) that has been fed in full for
-- DIRECT_AFTER_TICKS needs only a steady draw (its load and leak, or max_draw), so the bank hands
-- that draw to the engine: the interface consumes it as its power_usage every tick and the script
-- stops ticking the bank. The caller checks periodically from the network's flow statistics that
-- the interfaces got what direct mode assumed (PowerBank.expected), and on any shortfall charges it
-- to the store and leaves direct mode (PowerBank.shortfall), so the adaptive request takes over
-- again. A change of load or draw limit leaves direct mode too (PowerBank.direct_need).
--
-- A bank table holds only numbers, so it can live in storage: charge, request, step, hold_until,
-- applied, received, tick, fed_since, direct, direct_from, drawn, and the delivery sums read by
-- PowerBank.delivered.
local PowerBank = {}

local LEAK_PER_SECOND = 0.005
PowerBank.LEAK_PER_SECOND = LEAK_PER_SECOND
-- Activation spends this share of a full store, leaving the rest as the running reserve.
PowerBank.ACTIVATION_SHARE = 0.8

local MIN_STEP = 10e6
local MAX_STEP = 50e6
local STEP_GROWTH = 1.1
local SHORTFALL_FACTOR = 2
local HOLD_TICKS = 120
-- A delivery below this share of what was asked counts as a shortfall.
local MET = 0.999
local TICKS_PER_SECOND = 60
-- How long a full store must be fed in full before it goes direct.
PowerBank.DIRECT_AFTER_TICKS = 300
-- A store this close to its capacity counts as full for direct mode.
local FULL = 0.999
local SECONDARY_INPUT = defines.electric_interface_mode.secondary_input
-- Transient per-VM record of interfaces whose mode, usage, and buffer already match bank.applied,
-- so consecutive ticks skip redundant C++ reads and writes while reloads re-verify every entity.
local verified = {}

--- The leak of a store holding `charge` joules, in watts.
function PowerBank.leak(charge)
  return charge * LEAK_PER_SECOND
end

--- The most a bank should ask for: what keeps a full store of `capacity` joules full under `load`
--- watts, plus `refill` watts into the store.
function PowerBank.max_draw(capacity, load, refill)
  return load + capacity * LEAK_PER_SECOND + refill
end

--- How long a store holding `charge` joules carries `load` watts with no input, in seconds.
--- Solves dE/dt = -load - LEAK_PER_SECOND * E.
function PowerBank.cover_seconds(charge, load)
  if load <= 0 then
    return math.huge
  end
  return math.log(1 + LEAK_PER_SECOND * charge / load) / LEAK_PER_SECOND
end

--- Advances the bank one tick through its interface `unit`. `options`:
--- - capacity: the store's size in joules (0 with `sink`);
--- - load: watts the machine takes from the store this tick;
--- - max_draw: the most the interface may ask for, in watts (0 stops charging);
--- - sink: nothing is stored; what arrives is spent at once (a machine without a store).
--- Returns the joules delivered since the last tick.
function PowerBank.tick(bank, unit, options)
  local now = game.tick
  local prev_tick = bank.tick
  local ticks = prev_tick and (now - prev_tick) or 0
  bank.tick = now
  local prev_applied = bank.applied
  local fast = ticks == 1 and prev_applied ~= nil and verified[bank] == unit
  -- Interface modes and buffer sizes are saved per entity and survive prototype changes.
  if not fast and unit.electric_interface_mode ~= SECONDARY_INPUT then
    unit.electric_interface_mode = SECONDARY_INPUT
  end
  local got = unit.energy
  if got > 0 then
    unit.energy = 0
  end
  bank.received = got
  bank.drawn = (bank.drawn or 0) + got
  bank.delivered_joules = (bank.delivered_joules or 0) + got
  bank.delivered_ticks = (bank.delivered_ticks or 0) + ticks

  local sink = options.sink
  local capacity = sink and 0 or options.capacity
  local load = options.load or 0
  local charge = bank.charge or 0
  if not sink then
    charge = charge - (load + charge * LEAK_PER_SECOND) * ticks / TICKS_PER_SECOND
    charge = math.max(0, math.min(capacity, charge + got))
    bank.charge = charge
  end

  local request = bank.request or MAX_STEP
  local step = bank.step or MAX_STEP
  local asked = fast and (prev_applied / TICKS_PER_SECOND)
    or math.min(unit.electric_buffer_size, (prev_applied or 0) / TICKS_PER_SECOND * ticks)
  if ticks > 0 and asked > 1 then
    if got < asked * MET then
      bank.fed_since = nil
      local missing = (asked - got) * TICKS_PER_SECOND / ticks
      -- No lower than half of what arrived: a sudden large drop (accumulators running empty, a
      -- generator lost) would otherwise cut the request to nothing and hold it there.
      local arrived = got * TICKS_PER_SECOND / ticks
      request = math.max(arrived / 2, math.min(arrived, request - math.max(step, missing * SHORTFALL_FACTOR)))
      step = MIN_STEP
      -- Nothing arrived: the network has nothing to protect, so climb again as soon as it does.
      bank.hold_until = got > 0 and now + HOLD_TICKS or nil
    else
      bank.fed_since = bank.fed_since or now
      if now >= (bank.hold_until or 0) and (prev_applied or 0) >= request then
        -- Raised only when the whole request was asked for: a draw capped by max_draw or a nearly
        -- full store says nothing about whether the network could give more.
        request = request + step
        step = math.min(MAX_STEP, step * STEP_GROWTH)
      end
    end
  elseif ticks > 0 and request < MIN_STEP then
    request = MIN_STEP
  end
  local max_draw = options.max_draw or 0
  -- Never learn a request above what the bank may ask for, or a capped bank would climb forever.
  request = math.min(request, math.max(max_draw, MIN_STEP))
  bank.request, bank.step = request, step

  local room = sink and math.huge
    or (capacity - charge) * TICKS_PER_SECOND + load + charge * LEAK_PER_SECOND
  local applied = math.max(0, math.min(request, max_draw, room))
  bank.applied = applied
  if not fast then
    unit.power_usage = 0
    local per_tick = applied / TICKS_PER_SECOND
    unit.input_flow_limit = per_tick
    unit.electric_buffer_size = math.max(1, per_tick)
    verified[bank] = unit
  elseif applied ~= prev_applied then
    local per_tick = applied / TICKS_PER_SECOND
    unit.input_flow_limit = per_tick
    unit.electric_buffer_size = math.max(1, per_tick)
  end
  return got
end

--- The average power delivered since the last call, in watts, for callers that update less often
--- than every tick. While direct with no ticked samples pending, returns the steady direct draw.
function PowerBank.delivered(bank)
  local ticks = bank.delivered_ticks or 0
  local watts = ticks > 0 and (bank.delivered_joules or 0) * TICKS_PER_SECOND / ticks or 0
  bank.delivered_joules, bank.delivered_ticks = 0, 0
  if bank.direct and ticks == 0 then
    return bank.direct
  end
  return watts
end

--- The steady draw, in watts, that keeps `options` satisfied once settled, if the bank may run
--- direct: for a store, its load and full-store leak; for an unstored `sink`, `options.max_draw`.
function PowerBank.direct_need(options)
  local max_draw = options.max_draw or 0
  if max_draw <= 0 then
    return nil
  end
  if options.sink then
    return max_draw
  end
  local need = (options.load or 0) + options.capacity * LEAK_PER_SECOND
  if need > max_draw then
    return nil
  end
  return need
end

--- Whether a bank ticked by PowerBank.tick with `options` should go direct: its store is full (or
--- it is a `sink`), the network has met every request for DIRECT_AFTER_TICKS, and its learned
--- request covers the need.
function PowerBank.ready_for_direct(bank, options)
  local need = PowerBank.direct_need(options)
  return need ~= nil and (options.sink or (bank.charge or 0) >= options.capacity * FULL)
    and bank.fed_since ~= nil and game.tick - bank.fed_since >= PowerBank.DIRECT_AFTER_TICKS
    and (bank.request or 0) >= need
end

--- Hands the bank's steady draw, `need` watts (PowerBank.direct_need), to its interface `unit`: from
--- the next tick the engine draws it and consumes it, and the store stays full until the bank leaves.
function PowerBank.enter_direct(bank, unit, need, capacity)
  verified[bank] = nil
  bank.direct, bank.direct_from = need, game.tick
  bank.charge = capacity or 0
  local per_tick = need / TICKS_PER_SECOND
  bank.received = per_tick
  if unit.electric_interface_mode ~= SECONDARY_INPUT then
    unit.electric_interface_mode = SECONDARY_INPUT
  end
  unit.power_usage = per_tick
  unit.input_flow_limit = per_tick
  unit.electric_buffer_size = math.max(1, per_tick)
end

--- Returns a direct bank to the adaptive request, ticked by PowerBank.tick from this tick on.
function PowerBank.leave_direct(bank, unit)
  verified[bank] = nil
  if not bank.direct then
    return
  end
  bank.drawn = (bank.drawn or 0) + bank.direct / TICKS_PER_SECOND * (game.tick - bank.direct_from)
  -- The network must earn direct mode again, and the first tick back judges nothing.
  bank.request = math.max(bank.request or 0, bank.direct)
  bank.direct, bank.direct_from, bank.fed_since, bank.applied = nil, nil, nil, 0
  bank.tick = game.tick
  if unit and unit.valid then
    unit.power_usage = 0
    unit.energy = 0
  end
end

--- Silences `unit` to a 1 J idle buffer, leaving direct mode if active and invalidating cached
--- interface state so the next PowerBank.tick re-applies everything cleanly.
function PowerBank.idle(bank, unit, disabled)
  PowerBank.leave_direct(bank, unit)
  verified[bank] = nil
  bank.applied = nil
  if unit and unit.valid then
    unit.power_usage = 0
    unit.input_flow_limit = 0
    unit.electric_buffer_size = 1
    unit.disabled_by_script = disabled == true
  end
end

--- The joules the bank assumes its interface drew since the last call: what arrived while ticked,
--- and its steady draw while direct. Compare their sum over a network with the interfaces' input
--- count in the network's flow statistics.
function PowerBank.expected(bank)
  local joules = bank.drawn or 0
  if bank.direct then
    local now = game.tick
    joules = joules + bank.direct / TICKS_PER_SECOND * (now - bank.direct_from)
    bank.direct_from = now
  end
  bank.drawn = 0
  return joules
end

--- Charges `joules` the interface did not get, though direct mode assumed it, to the store, and
--- leaves direct mode.
function PowerBank.shortfall(bank, unit, joules)
  bank.charge = math.max(0, (bank.charge or 0) - joules)
  PowerBank.leave_direct(bank, unit)
end

--- Spends ACTIVATION_SHARE of a store of `capacity` joules. Returns false, spending nothing, unless
--- the store is full.
function PowerBank.activate(bank, capacity)
  if (bank.charge or 0) + 1 < capacity then
    return false
  end
  bank.charge = capacity * (1 - PowerBank.ACTIVATION_SHARE)
  -- The running load starts now and the learned request may be a full store's small top-up:
  -- climb in full steps at once, so the reserve need not cover a slow ramp.
  bank.step, bank.hold_until = MAX_STEP, nil
  return true
end

--- Empties the store and forgets the learned request, as for a machine switched off for good.
function PowerBank.reset(bank)
  verified[bank] = nil
  bank.charge = 0
  bank.direct, bank.direct_from, bank.fed_since = nil, nil, nil
  bank.request, bank.step, bank.hold_until, bank.applied = nil, nil, nil, nil
  bank.delivered_joules, bank.delivered_ticks = 0, 0
end

return PowerBank
