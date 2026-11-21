local Construction = require("scripts.construction")
local Gate = require("scripts.gate")
local Gui = require("scripts.gui")
local Transfer = require("scripts.transfer")
local Destinations = require("scripts.destinations")
local Railway = require("scripts.railway")

local UPDATE_TICKS = 30
local GATE = "bte-stargate"
local BUILT = {
  {filter = "name", name = "bte-stargate-construction-site"},
  {filter = "name", name = GATE}
}

local function rebuild()
  Construction.rebuild()
  Gate.rebuild(Railway.gate_removed)
  Gui.init_storage()
  Transfer.init_storage()
  Railway.rebuild()
end

script.on_init(rebuild)
script.on_configuration_changed(rebuild)

local function built(entity)
  if entity.name == GATE then
    Gate.register(entity)
  else
    Construction.register(entity)
  end
end

for _, event in pairs({
  defines.events.on_built_entity,
  defines.events.on_robot_built_entity,
  defines.events.on_space_platform_built_entity,
  defines.events.script_raised_built,
  defines.events.script_raised_revive
}) do
  script.on_event(event, function(event_data)
    built(event_data.entity)
  end, BUILT)
end

for _, event in pairs({defines.events.on_entity_died, defines.events.script_raised_destroy}) do
  script.on_event(event, function(event_data)
    Gate.removed(event_data.entity, Railway.gate_removed)
  end, {{filter = "name", name = GATE}})
end

script.on_nth_tick(UPDATE_TICKS, function()
  Construction.update()
  Gate.prune(Railway.gate_removed)
  Railway.maintain()
  Gui.update()
end)
-- Gates fed in full run their steady draw without the script (scripts/power_bank.lua, direct mode);
-- this checks the network gave it.
script.on_nth_tick(60, Gate.check_power)
script.on_nth_tick(Gate.TRANSFER_TICKS, function()
  Gate.update(Transfer.start)
  Railway.check()
end)
-- Gates charge every tick. Ripples, arrivals, and the run out of the ring are timed per tick, but only
-- while someone travels.
script.on_event(defines.events.on_tick, function()
  Gate.collect()
  if (storage.transfers and next(storage.transfers)) or (storage.exits and next(storage.exits)) then
    Transfer.update()
  end
  if Railway.active() then
    Railway.update()
  end
end)

script.on_event({defines.events.on_cutscene_cancelled, defines.events.on_cutscene_finished}, Transfer.on_cutscene_cancelled)
script.on_event(defines.events.on_gui_opened, Gui.on_opened)
-- A gate's station renamed in its train stop window renames the gate.
script.on_event(defines.events.on_entity_renamed, function(event_data)
  local entity = event_data.entity
  local record = entity.valid and entity.name == "bte-stargate-station" and Railway.gate_of(entity)
  if record then
    Gate.set_name(record, entity.backer_name)
  end
end)
script.on_event(defines.events.on_gui_closed, Gui.on_closed)
script.on_event(defines.events.on_gui_click, Gui.on_click)
script.on_event(defines.events.on_gui_text_changed, Gui.on_text_changed)
script.on_event(defines.events.on_gui_selection_state_changed, Gui.on_selection_changed)
script.on_event(defines.events.on_gui_elem_changed, Gui.on_elem_changed)
script.on_event(defines.events.on_gui_checked_state_changed, Gui.on_checked)

-- Lets the headless runtime test drive what the window does; registered only alongside its helper mod.
if script.active_mods["bte-stargate-runtime-test"] then
  remote.add_interface("bte-stargate-test", {
    state = function(id)
      local record = Gate.get(id)
      return record and {name = record.name, partner = record.partner, enabled = record.enabled}
    end,
    pair = function(a, b)
      Gate.pair(Gate.get(a), b and Gate.get(b))
    end,
    set_enabled = function(id, enabled)
      Gate.set_enabled(Gate.get(id), enabled)
    end,
    set_keep_charged = function(id, keep)
      Gate.set_keep_charged(Gate.get(id), keep)
    end,
    rail_transfers = function()
      return #storage.rail_transfers
    end,
    rail_guards = function()
      return table_size(storage.rail_guard or {})
    end,
    active_gates = function()
      return table_size(storage.active_gates or {})
    end,
    set_station = function(id, mode)
      return Railway.set_mode(Gate.get(id), mode)
    end,
    -- Makes a station gate look built by an earlier layout: no hidden rails, the station at the ring.
    forget_layout = function(id)
      local record = Gate.get(id)
      for _, rail in pairs(record.rails) do
        if rail.valid and rail.name == "bte-stargate-rail-hidden" then
          rail.destroy()
        end
      end
      record.station.teleport({record.station.position.x, record.station.position.y - 4})
      record.rail_layout = nil
    end,
    station = function(id)
      return Railway.station(Gate.get(id))
    end,
    can_enter = function(entity)
      return Transfer.can_enter(entity)
    end,
    is_open = function(id)
      return Gate.is_open(Gate.get(id))
    end,
    -- Headless runs do not chart, so no planet counts as visited there; this tests the landing spot.
    charge = function(id)
      return Gate.charge(Gate.get(id))
    end,
    -- Empties the store and returns what arrived from the network in the last update.
    take_charge = function(id)
      return Gate.take_charge(Gate.get(id))
    end,
    bank = function(id)
      return Gate.get(id).bank
    end,
    power_flow = function(id)
      return Gate.power_flow(Gate.get(id))
    end,
    random_location = function(force, surface)
      local position = Destinations.location(game.forces[force], game.get_surface(surface))
      return position and {x = position.x or position[1], y = position.y or position[2]}
    end,
    destination = function(id, x, y)
      local surface, position = Gate.destination(Gate.get(id), {x = x, y = y})
      return surface and {surface = surface.name, x = position.x or position[1], y = position.y or position[2]}
    end
  })
end
