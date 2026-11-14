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
-- - the store loses the machine's load and its leak, and gains EFFICIENCY of what the network
--   delivered (the rest is lost in conversion). The leak is LEAK_PER_SECOND of the charge per second,
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
-- A bank table holds only numbers, so it can live in storage: charge, request, step, hold_until,
-- applied, received, tick, and the delivery sums read by PowerBank.delivered.
local PowerBank = {}

PowerBank.LEAK_PER_SECOND = 0.005
-- The share of delivered energy that reaches the store; the rest is lost in conversion.
PowerBank.EFFICIENCY = 0.95
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

--- The leak of a store holding `charge` joules, in watts.
function PowerBank.leak(charge)
  return charge * PowerBank.LEAK_PER_SECOND
end

--- The most a bank should ask for: what keeps a full store of `capacity` joules full under `load`
--- watts, plus `refill` watts into the store, all grossed up for conversion losses.
function PowerBank.max_draw(capacity, load, refill)
  return (load + PowerBank.leak(capacity) + refill) / PowerBank.EFFICIENCY
end

--- How long a store holding `charge` joules carries `load` watts with no input, in seconds.
--- Solves dE/dt = -load - LEAK_PER_SECOND * E.
function PowerBank.cover_seconds(charge, load)
  local k = PowerBank.LEAK_PER_SECOND
  if load <= 0 then
    return math.huge
  end
  return math.log(1 + k * charge / load) / k
end

--- Advances the bank one tick through its interface `unit`. `options`:
--- - capacity: the store's size in joules (0 with `sink`);
--- - load: watts the machine takes from the store this tick;
--- - max_draw: the most the interface may ask for, in watts (0 stops charging);
--- - sink: nothing is stored; what arrives is spent at once (a machine without a store).
--- Returns the joules delivered since the last tick.
function PowerBank.tick(bank, unit, options)
  -- Interface modes and buffer sizes are saved per entity and survive prototype changes.
  if unit.electric_interface_mode ~= defines.electric_interface_mode.secondary_input then
    unit.electric_interface_mode = defines.electric_interface_mode.secondary_input
  end
  local ticks = game.tick - (bank.tick or game.tick)
  bank.tick = game.tick
  local got = unit.energy
  unit.energy = 0
  bank.received = got
  bank.delivered_joules = (bank.delivered_joules or 0) + got
  bank.delivered_ticks = (bank.delivered_ticks or 0) + ticks

  local capacity = options.sink and 0 or options.capacity
  local load = options.load or 0
  if not options.sink then
    local charge = bank.charge or 0
    charge = charge - (load + PowerBank.leak(charge)) * ticks / TICKS_PER_SECOND
    bank.charge = math.max(0, math.min(capacity, charge + got * PowerBank.EFFICIENCY))
  end

  local request = bank.request or MAX_STEP
  local step = bank.step or MAX_STEP
  local asked = math.min(unit.electric_buffer_size, (bank.applied or 0) / TICKS_PER_SECOND * ticks)
  if ticks > 0 and asked > 1 then
    if got < asked * MET then
      local missing = (asked - got) * TICKS_PER_SECOND / ticks
      -- No lower than half of what arrived: a sudden large drop (accumulators running empty, a
      -- generator lost) would otherwise cut the request to nothing and hold it there.
      local arrived = got * TICKS_PER_SECOND / ticks
      request = math.max(arrived / 2, math.min(arrived, request - math.max(step, missing * SHORTFALL_FACTOR)))
      step = MIN_STEP
      -- Nothing arrived: the network has nothing to protect, so climb again as soon as it does.
      bank.hold_until = got > 0 and game.tick + HOLD_TICKS or nil
    elseif game.tick >= (bank.hold_until or 0) and (bank.applied or 0) >= request then
      -- Raised only when the whole request was asked for: a draw capped by max_draw or a nearly
      -- full store says nothing about whether the network could give more.
      request = request + step
      step = math.min(MAX_STEP, step * STEP_GROWTH)
    end
  elseif ticks > 0 and request < MIN_STEP then
    request = MIN_STEP
  end
  local max_draw = options.max_draw or 0
  -- Never learn a request above what the bank may ask for, or a capped bank would climb forever.
  request = math.min(request, math.max(max_draw, MIN_STEP))
  bank.request, bank.step = request, step

  local room = options.sink and math.huge
    or ((capacity - bank.charge) * TICKS_PER_SECOND + load + PowerBank.leak(bank.charge))
      / PowerBank.EFFICIENCY
  local applied = math.max(0, math.min(request, max_draw, room))
  bank.applied = applied
  unit.power_usage = 0
  unit.input_flow_limit = applied / TICKS_PER_SECOND
  unit.electric_buffer_size = math.max(1, applied / TICKS_PER_SECOND)
  return got
end

--- The average power delivered since the last call, in watts, for callers that update less often
--- than every tick.
function PowerBank.delivered(bank)
  local ticks = bank.delivered_ticks or 0
  local watts = ticks > 0 and (bank.delivered_joules or 0) * TICKS_PER_SECOND / ticks or 0
  bank.delivered_joules, bank.delivered_ticks = 0, 0
  return watts
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
  bank.charge = 0
  bank.request, bank.step, bank.hold_until, bank.applied = nil, nil, nil, nil
  bank.delivered_joules, bank.delivered_ticks = 0, 0
end

return PowerBank
