-- Drives the Stargate construction flow in a headless save and fails loudly on the first deviation.
local SITE = "bte-stargate-construction-site"
local ASSEMBLING = "bte-stargate-assembling"
local GATE = "bte-stargate"

local function fail(message)
  error("STARGATE_TEST_FAIL [" .. (storage.phase or "setup") .. "]: " .. message)
end

local function expect(label, actual, expected)
  if actual ~= expected then
    fail(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
  end
end

-- The power-sharing case (see its steps).
SHARE = {supply = 400e6, load = 300e6, gates = 3}
SHARE_TICKS = 900
-- The factory beside the direct-mode gates.
DIRECT_LOAD = 300e6

local function surface()
  return game.surfaces.nauvis
end

local function build_site(x)
  local site = surface().create_entity({name = SITE, position = {x, 0}, force = "player", raise_built = true})
  if not site then
    fail("could not place a construction site at x=" .. x)
  end
  return site
end

-- The mod's render objects of one type ("rectangle") or showing one animation.
-- How many gate bodies show red lights (graphics variation 2).
local function red_bodies()
  local count = 0
  for _, body in pairs(game.surfaces.nauvis.find_entities_filtered({name = "bte-stargate-body"})) do
    if body.graphics_variation == 2 then
      count = count + 1
    end
  end
  return count
end

local function drawn(kind)
  local count = 0
  for _, object in pairs(rendering.get_all_objects("bte-stargate")) do
    if object.type == kind or (object.type == "animation" and object.animation == kind) then
      count = count + 1
    end
  end
  return count
end

local function entities(name)
  return surface().find_entities_filtered({name = name})
end

local function ground_count(item)
  local total = 0
  for _, entity in pairs(surface().find_entities_filtered({name = "item-on-ground"})) do
    if entity.stack.name == item then
      total = total + entity.stack.count
    end
  end
  return total
end

-- The bill's bulk materials in slot order, each a whole number of stacks: slots 1-11, then the spare 12.
local BILL = {
  {"tungsten-plate", 250, 1, 5}, {"holmium-plate", 300, 6, 8}, {"superconductor", 200, 9, 9},
  {"supercapacitor", 200, 10, 11}
}
local TIMED = BILL[#BILL]

-- Switching gates off while a long train is partway through: it still arrives in one piece. Each
-- case names the gates switched off and how many carriages have come out by then (0: as the
-- transfer starts; on_tick), and optionally a train driven by hand at that speed into the gate.
local MID_CASES = {
  {gates = {"a"}, at = 0, wagons = 8, from = 600},
  {gates = {"a"}, at = 3, wagons = 8, from = 600},
  {gates = {"a"}, at = 0, wagons = 8, from = 600, manual = 1.38},
  {gates = {"b"}, at = 2},
  {gates = {"a", "b"}, at = 3},
  -- No gate switched off: the train from a save that came out with its last two wagons loose. Its
  -- part already out, lighter than the whole train, drives itself away faster than the rest is fed.
  {gates = {}, at = 0, wagons = 6, from = 600, fuel = "rocket-fuel"},
}

local function start_mid(case)
  local fast = storage.fast
  remote.call("bte-stargate-test", "set_enabled", fast.a.unit_number, true)
  remote.call("bte-stargate-test", "set_enabled", fast.b.unit_number, true)
  fast.entry, fast.top, fast.close, fast.loco, fast.mid = nil, 0, false, fast.train(case.from or 370, nil, case.wagons or 4, case.cargo, case.fuel), case
  if case.manual then
    fast.loco.train.manual_mode = true
    fast.loco.train.speed = case.manual
  end
end

local function check_mid()
  local fast = storage.fast
  local cars = fast.fb.find_entities_filtered({type = {"locomotive", "cargo-wagon"}})
  local case = serpent.line(fast.mid) .. " switched off"
  expect(case .. ": switched off partway through", fast.mid_closed, true)
  local whole = 1 + (fast.mid.wagons or 4)
  expect(case .. ": it arrives whole", #cars, whole)
  expect(case .. ": and coupled", cars[1] and #cars[1].train.carriages, whole)
  expect(case .. ": every carriage appears behind the veil (" .. tostring(fast.outside) .. ")", (fast.outside or 0) <= 3 + 0.5, true)
  for _, car in pairs(cars) do
    car.destroy()
  end
  fast.mid, fast.mid_closed, fast.seen, fast.outside = nil, nil, nil, nil
end

-- A long train through gates in a row: A to B, then B's track loops round into C, paired with D, and
-- so on for `pairs` pairs. Its head reaches each next gate while its tail is still coming out of the
-- one before. Cases: a locomotive leading; one pushing from the rear (`pushed`), so no locomotive
-- faces out ahead when the head reaches the next gate; a train driven by hand (`manual`); one whose
-- next stop is not the gate its track leads into (`skip`); and one meeting a closed gate (`closed`).
-- The last two jam (`jam`): what was still coming out of the gate before is wrecked. With `approach`
-- no gate comes before: the train runs south and round the U-turn into the first gate, its tail still
-- further north than its head (a save: it was taken only once almost stopped at the station).
local CHAIN_CASES = {
  {id = 1, pairs = 4, wagons = 30},
  {id = 2, pairs = 2, wagons = 14, pushed = true},
  {id = 3, pairs = 2, wagons = 14, manual = true},
  {id = 4, pairs = 2, wagons = 14, skip = true, jam = true},
  {id = 5, pairs = 2, wagons = 14, manual = true, closed = true, jam = true},
  {id = 6, pairs = 1, wagons = 20, approach = true},
}

local function start_chain(case)
  local function lab(name, y, radius)
    local s = game.create_surface(name)
    s.generate_with_lab_tiles = true
    s.request_to_generate_chunks({0, y}, radius)
    s.force_generate_chunk_requests()
    return s
  end
  local function straight(s, x, from, to)
    for y = from, to, 2 do
      s.create_entity({name = "straight-rail", position = {x, y}, direction = defines.direction.north, force = "player"})
    end
  end
  local function gate(s, x, mode)
    local g = s.create_entity({name = GATE, position = {x, 0}, force = "player", raise_built = true})
    remote.call("bte-stargate-test", "set_station", g.unit_number, mode)
    return g
  end
  local function power(s, x)
    s.create_entity({name = "substation", position = {x - 10, -6}, force = "player"})
    local source = s.create_entity({name = "bte-stargate-test-power", position = {x - 12, -6}, force = "player"})
    source.power_production, source.electric_buffer_size, source.energy = 1e9, 1e10, 1e10
  end
  -- From the end of the track out of the gate at x 0, a U-turn: always the rail planner's sharpest
  -- turn to the east until the track heads north again, then north to a gate's edge. Returns that
  -- gate's x.
  local function loop(s)
    straight(s, 3, 9, 21)
    local rail = s.find_entity("straight-rail", {3, 21})
    local tail
    for _, way in pairs({defines.rail_direction.front, defines.rail_direction.back}) do
      local e = rail.get_rail_end(way)
      if e.location.direction == defines.direction.south then
        tail = e
      end
    end
    for _ = 1, 40 do
      local direction = tail.location.direction
      if direction == defines.direction.north then
        break
      end
      local best, turn
      for _, extension in pairs(tail.get_rail_extensions("rail")) do
        local t = (direction - extension.goal.direction) % 16
        if extension.goal.rail_layer == 0 and t > 0 and t < 8 and (not turn or t < turn) then
          best, turn = extension, t
        end
      end
      local built = s.create_entity({name = best.name, position = best.position, direction = best.direction, force = "player"})
      for _, way in pairs({defines.rail_direction.front, defines.rail_direction.back}) do
        local e = built.get_rail_end(way)
        local at = e.location.position
        if e.location.direction == best.goal.direction and math.abs(at.x - best.goal.position.x) < 0.01
          and math.abs(at.y - best.goal.position.y) < 0.01 then
          tail = e
        end
      end
    end
    local lane = tail.location.position.x
    straight(s, lane, 9, tail.location.position.y - 1)
    -- The next gate's departure lane, on its right, is the new northbound track.
    return lane - 3
  end
  local surfaces = {lab("bte-test-chain-" .. case.id .. "-1", case.approach and 0 or 200, 8)}
  local first
  if case.approach then
    straight(surfaces[1], 3, -201, 7)
    local x = loop(surfaces[1])
    first = gate(surfaces[1], x, "right")
    power(surfaces[1], x + 22)
  else
    straight(surfaces[1], 3, 9, 401)
    first = gate(surfaces[1], 0, "right")
    power(surfaces[1], 0)
  end
  local departures, previous = {first}, first
  for k = 2, case.pairs + 1 do
    local s = lab("bte-test-chain-" .. case.id .. "-" .. k, 100, 6)
    surfaces[k] = s
    local arrival = gate(s, 0, "left")
    remote.call("bte-stargate-test", "pair", previous.unit_number, arrival.unit_number)
    power(s, 0)
    if k <= case.pairs then
      local x = loop(s)
      previous = gate(s, x, "right")
      power(s, x + 22)
      departures[#departures + 1] = previous
    else
      straight(s, 3, 9, 401)
      s.create_entity({name = "train-stop", position = {1, 391}, direction = defines.direction.south, force = "player"}).backer_name = "bte-test-chain-far"
    end
  end
  storage.chain = {surfaces = surfaces, both = 0, case = case, departures = departures}
end

-- Releases the chain's train once every gate it goes through is open: fresh gates charge first, and a
-- train driven by hand is taken only by an open gate.
local function chain_train(chain)
  local case, surfaces, departures = chain.case, chain.surfaces, chain.departures
  for _, g in pairs(departures) do
    if not remote.call("bte-stargate-test", "is_open", g.unit_number) then
      return
    end
  end
  -- The locomotive leads, or with `pushed` pushes from the rear, facing the same way.
  local loco_at = case.pushed and case.wagons or 0
  local loco
  for k = 0, case.wagons do
    local car = surfaces[1].create_entity({name = k == loco_at and "locomotive" or "cargo-wagon",
      position = case.approach and {3, -50 - 7 * k} or {3, 90 + 7 * k},
      direction = case.approach and defines.direction.south or defines.direction.north, force = "player"})
    if k == loco_at then
      loco = car
    end
    -- The last wagon, which goes in last.
    chain.rest = car
  end
  loco.insert({name = "nuclear-fuel", count = 2})
  local schedule = loco.train.get_schedule()
  local stops = case.skip and {departures[1]} or departures
  for _, g in pairs(stops) do
    schedule.add_record({station = remote.call("bte-stargate-test", "station", g.unit_number).backer_name, wait_conditions = {}})
  end
  schedule.add_record({station = "bte-test-chain-far", wait_conditions = {{type = "time", ticks = 6000}}})
  schedule.go_to_station(1)
  loco.train.manual_mode = false
  if case.manual then
    loco.train.manual_mode = true
  end
  if case.closed then
    remote.call("bte-stargate-test", "set_enabled", departures[2].unit_number, false)
  end
  chain.loco = loco

end

local function check_chain()
  local chain = storage.chain
  storage.chain = nil
  local case = chain.case
  local stock = {type = {"locomotive", "cargo-wagon"}}
  local counts = {}
  for k, s in pairs(chain.surfaces) do
    counts[k] = s.count_entities_filtered(stock)
  end
  local last = chain.surfaces[#chain.surfaces]
  local cars = last.find_entities_filtered(stock)
  local name = "chain " .. case.id .. ": "
  log("STARGATE_TEST_INFO: " .. name .. "carriages per surface " .. serpent.line(counts) .. ", most transfers at once "
    .. chain.both .. ", still running " .. remote.call("bte-stargate-test", "rail_transfers"))
  expect(name .. "no transfer is left running", remote.call("bte-stargate-test", "rail_transfers"), 0)
  expect(name .. "nothing is left at the first gate", counts[1], 0)
  if case.jam then
    -- The next gate cannot take it: what was still coming out of the gate before is wrecked.
    expect(name .. "it stops at the next gate", counts[#counts], 0)
    expect(name .. "and some of it is wrecked", counts[2] < case.wagons + 1, true)
  else
    local whole = case.wagons + 1
    expect(name .. "it arrives whole through " .. case.pairs .. " gate pairs in a row", #cars, whole)
    expect(name .. "and coupled", cars[1] and #cars[1].train.carriages, whole)
    if case.approach then
      expect(name .. "it goes in at speed (" .. chain.entry .. "), not after braking almost to a stop", chain.entry > 0.15, true)
      -- A train of one locomotive and 20 wagons on nuclear fuel gains about 0.0008 a tick; the
      -- locomotive alone, once out, several times that.
      expect(name .. "it gains speed going in as the whole train would (" .. tostring(chain.gain) .. "), not as its locomotive alone",
        (chain.gain or 1) < 0.0015, true)
    else
      expect(name .. "its head went on through the next gate while its tail still came out of the one before",
        chain.both >= math.min(case.pairs, 3), true)
    end
    if not case.manual then
      local stop = cars[1] and (cars[1].train.station or cars[1].train.path_end_stop)
      expect(name .. "and it drives on to its stop", stop and stop.backer_name, "bte-test-chain-far")
    end
  end
  for _, s in pairs(chain.surfaces) do
    game.delete_surface(s)
  end
end

-- Each step runs once, `delay` ticks after the previous one; the mod checks its sites every 30 ticks.
-- The build lasts 240 ticks (helper data-final-fixes.lua) over six pictures, one every 40 ticks;
-- on_tick records each picture shown (storage.stages_seen).
local steps = {
  {1, function()
    surface().request_to_generate_chunks({30, 0}, 3)
    surface().force_generate_chunk_requests()
    for _, entity in pairs(surface().find_entities_filtered({area = {{-12, -12}, {70, 12}}})) do
      if entity.type ~= "character" then
        entity.destroy()
      end
    end
    local tiles = {}
    for x = -12, 70 do
      for y = -12, 12 do
        tiles[#tiles + 1] = {name = "concrete", position = {x, y}}
      end
    end
    surface().set_tiles(tiles)
    storage.site = build_site(0)
    local inventory = storage.site.get_inventory(defines.inventory.chest)
    expect("slots (11 for the bill, 1 spare)", #inventory, 12)
    for _, material in pairs(BILL) do
      expect(material[1] .. " first slot filter", inventory.get_filter(material[3]).name, material[1])
      expect(material[1] .. " last slot filter", inventory.get_filter(material[4]).name, material[1])
    end
    expect("the spare slot is unfiltered", inventory.get_filter(12), nil)
  end},

  -- A delivery cannot overshoot: every material's slots hold exactly its amount.
  {5, function()
    local site = storage.site
    -- The stray stack takes the spare slot first, so it cannot absorb any overshoot below.
    expect("a stray stack fits in the spare slot", site.insert({name = "iron-plate", count = 10}), 10)
    expect("only that one stray stack fits", site.insert({name = "copper-plate", count = 10}), 0)
    for _, material in pairs(BILL) do
      if material ~= TIMED then
        expect(material[1] .. " takes exactly the bill", site.insert({name = material[1], count = material[2] * 2}), material[2])
      end
    end
    site.health = site.max_health * 0.5
  end},

  {70, function()
    expect("an incomplete site waits", storage.site.valid, true)
    expect("an incomplete site builds nothing", #entities(ASSEMBLING) + #entities(GATE), 0)
    expect("the last material takes exactly the bill", storage.site.insert({name = TIMED[1], count = TIMED[2] * 2}), TIMED[2])
  end},

  {40, function()
    expect("the site is consumed", storage.site.valid, false)
    expect("no construction site remains", #entities(SITE), 0)
    local assembling = entities(ASSEMBLING)
    expect("one gate is under construction", #assembling, 1)
    expect("assembling position", assembling[1].position.x .. "," .. assembling[1].position.y, "0,0")
    expect("assembling gate cannot be mined", assembling[1].prototype.mineable_properties.minable, false)
    expect("health fraction carries over", math.abs(assembling[1].get_health_ratio() - 0.5) < 0.01, true)
    expect("first phase keeps the construction site picture", assembling[1].graphics_variation, 1)
    expect("the delivery is consumed, not spilled", ground_count("tungsten-plate"), 0)
    expect("the stray stack is spilled", ground_count("iron-plate"), 10)
    expect("progress bar drawn", drawn("rectangle"), 2)
  end},

  {110, function()
    expect("still under construction", #entities(ASSEMBLING), 1)
    expect("no gate yet", #entities(GATE), 0)
  end},

  {80, function()
    expect("still under construction", #entities(ASSEMBLING), 1)
    expect("still no gate", #entities(GATE), 0)
  end},

  {80, function()
    local seen = {}
    for stage in pairs(storage.stages_seen or {}) do
      seen[#seen + 1] = stage
    end
    table.sort(seen)
    expect("the assembling gate shows its six pictures in turn", table.concat(seen, ","), "1,2,3,4,5,6")
    expect("construction is over", #entities(ASSEMBLING), 0)
    local gates = entities(GATE)
    expect("one gate stands", #gates, 1)
    expect("gate position", gates[1].position.x .. "," .. gates[1].position.y, "0,0")
    expect("gate cannot be mined", gates[1].prototype.mineable_properties.minable, false)
    expect("health fraction carries over", math.abs(gates[1].get_health_ratio() - 0.5) < 0.01, true)
    expect("progress bar removed", drawn("rectangle"), 0)
    expect("the finished gate draws its status lights, red until charged", red_bodies(), 1)
    gates[1].die()
    expect("a destroyed gate leaves no kit", ground_count("bte-stargate-construction-kit"), 0)
  end},

  -- The rails' 2x2 grid. The origin snaps to even coordinates, the building's centre is one tile
  -- south-east of it (boxes 14 wide from origin-6 to origin+8), so its edges are on rail cell edges and
  -- its rail beds, two tiles either side of the centre, are on rail positions. create_entity snaps by default.
  {5, function()
    local gate = surface().create_entity({name = GATE, position = {41, 3}, force = "player"})
    expect("a gate is placed", gate ~= nil, true)
    local x, y = gate.position.x, gate.position.y
    expect("the origin snaps to even coordinates", x % 2 == 0 and y % 2 == 0, true)
    expect("the gate snapped to the expected origin", x .. "," .. y, "42,4")
    for _, bed in pairs({-2, 2}) do
      expect("rail beds are on odd (rail) coordinates", (x + 1 + bed) % 2 == 1 and (y + 1) % 2 == 1, true)
    end
    local function can_rail(rail_x, rail_y)
      return surface().can_place_entity({name = "straight-rail", position = {rail_x, rail_y}, direction = defines.direction.north, force = "player"})
    end
    -- The box runs x from origin-6 to origin+8 and y likewise: rails fit flush against it, not overlapping.
    expect("a rail fits flush against the east edge", can_rail(x + 9, y + 1), true)
    expect("a rail cannot overlap the east edge", can_rail(x + 7, y + 1), false)
    expect("a rail fits flush against the west edge", can_rail(x - 7, y + 1), true)
    expect("a rail cannot overlap the west edge", can_rail(x - 5, y + 1), false)
    expect("a rail fits flush against the north edge", can_rail(x + 1, y - 7), true)
    expect("a rail cannot overlap the north edge", can_rail(x + 1, y - 5), false)
    gate.destroy()
  end},

  -- Pairing, power, the on/off switch, the circuit condition, and player transfer. Gates A and B stand
  -- side by side at x 0 and 20 (origins), A powered by an electric energy interface on a substation.
  {5, function()
    local a = surface().create_entity({name = GATE, position = {0, 0}, force = "player", raise_built = true})
    local b = surface().create_entity({name = GATE, position = {20, 0}, force = "player", raise_built = true})
    expect("two gates placed", a ~= nil and b ~= nil, true)
    storage.a, storage.b = a, b
    local names = remote.call("bte-stargate-test", "state", a.unit_number)
    expect("a new gate gets a name", type(names.name) == "string" and #names.name > 0, true)
    expect("an unpaired gate is disabled by script", a.disabled_by_script, true)
    local function barriers(gate, name)
      local c = {x = gate.position.x + 1, y = gate.position.y + 1}
      return #surface().find_entities_filtered({name = name, area = {{c.x - 7, c.y - 7}, {c.x + 7, c.y + 7}}})
    end
    expect("an uncharged gate shows red lights", red_bodies(), 2)
    -- A's centre is (1, 1) and its ring's plane y 3. Only the machinery is blocked.
    expect("blocks cover the west and east machinery", barriers(a, "bte-stargate-side-block"), 2)
    expect("a block covers the control cabinet", barriers(a, "bte-stargate-cabinet-block"), 1)
    expect("a block covers the capacitor rack", barriers(a, "bte-stargate-rack-block"), 1)
    local body = surface().find_entities_filtered({name = "bte-stargate-body"})
    expect("each gate has a body on its ring's line", #body == 2 and body[1].position.y == 3, true)
    expect("each gate draws its upper arc over spidertrons", #surface().find_entities_filtered({name = "bte-stargate-top"}), 2)
    local function stands(x, y)
      local found = surface().find_non_colliding_position("character", {x, y}, 0.3, 0.05)
      return found ~= nil
    end
    expect("a character can stand behind the ring", stands(1, -2), true)
    expect("a character can stand in a closed gate's portal", stands(1, 3), true)
    expect("a character can stand at the lane's edge in the ring", stands(3.7, 3), true)
    expect("nobody stands in the capacitor banks", stands(6.5, -2), false)
    expect("nobody stands in a tower", stands(6.5, 3), false)
    expect("a car can stand behind the ring", surface().can_place_entity({name = "car", position = {1, -3}, force = "player"}), true)
    expect("a tank can stand in the lane through the ring", surface().can_place_entity({name = "tank", position = {1, 3}, force = "player"}), true)
    expect("a tank cannot stand in a tower", surface().can_place_entity({name = "tank", position = {6.5, 3}, force = "player"}), false)
    surface().create_entity({name = "substation", position = {-8, -6}, force = "player"})
    local source = surface().create_entity({name = "bte-stargate-test-power", position = {-10, -6}, force = "player"})
    source.power_production = 1e9
    source.electric_buffer_size = 1e10
    source.energy = 1e10
    storage.source = source
    remote.call("bte-stargate-test", "pair", a.unit_number, b.unit_number)
    expect("pairing is mutual", remote.call("bte-stargate-test", "state", b.unit_number).partner, a.unit_number)
    expect("a paired gate stays closed until charged", a.disabled_by_script, true)
    expect("paired gates short of charge show red lights", red_bodies(), 2)
    expect("each gate has a capacitor", #surface().find_entities_filtered({name = "bte-stargate-capacitor"}), 2)
  end},

  {150, function()
    local a, b = storage.a, storage.b
    expect("the charged gate is open", a.status, defines.entity_status.working)
    local capacitor = surface().find_entities_filtered({name = "bte-stargate-capacitor", position = {1, 1}})[1]
    expect("the capacitor never holds more than a few ticks of charge", capacitor.electric_buffer_size <= 1e9 / 60 * 3 + 1, true)
    expect("the capacitor draws as an ordinary consumer", capacitor.electric_interface_mode, defines.electric_interface_mode.secondary_input)
    expect("an unpowered gate does not charge", remote.call("bte-stargate-test", "charge", b.unit_number), 0)
    expect("the unpowered partner is not", b.status ~= defines.entity_status.working, true)
    expect("the open gate reports open", remote.call("bte-stargate-test", "is_open", a.unit_number), true)
    -- The veil forms over 120 ticks before its companions take over.
    local veils = #surface().find_entities_filtered({name = {"bte-stargate-veil", "bte-stargate-veil-top"}})
    expect("the open gate shows its veil or its opening", veils >= 2 or drawn("bte-stargate-opening") == 1 and drawn("bte-stargate-opening-high") == 1, true)
    -- Headless runs have no player, so check where the portal sends a character rather than moving one.
    -- A's centre is (1, 1) and its ring two tiles south; B's centre is (21, 1).
    local to = remote.call("bte-stargate-test", "destination", a.unit_number, 1, 3)
    expect("the portal sends to the partner's surface", to and to.surface, "nauvis")
    expect("the portal sends in front of the partner (" .. serpent.line(to) .. ")", math.abs(to.x - 21) < 2 and to.y > 3.5 and to.y < 7, true)
    expect("beside the portal sends nowhere", remote.call("bte-stargate-test", "destination", a.unit_number, 1, 5), nil)
    expect("well behind the ring sends nowhere", remote.call("bte-stargate-test", "destination", a.unit_number, 1, 2.4), nil)
    expect("just behind the ring sends too", remote.call("bte-stargate-test", "destination", a.unit_number, 1, 2.6) ~= nil, true)
    expect("the ring's edge by the side block sends too", remote.call("bte-stargate-test", "destination", a.unit_number, 3.9, 3) ~= nil, true)
    expect("off the portal's width sends nowhere", remote.call("bte-stargate-test", "destination", a.unit_number, 6, 3), nil)
    remote.call("bte-stargate-test", "set_enabled", b.unit_number, false)
  end},

  {10, function()
    expect("a switched-off receiving gate still receives", remote.call("bte-stargate-test", "is_open", storage.a.unit_number), true)
    local a = storage.a
    remote.call("bte-stargate-test", "set_enabled", a.unit_number, false)
    expect("switching off disables the gate", a.disabled_by_script, true)
    remote.call("bte-stargate-test", "set_enabled", a.unit_number, true)
    local behavior = a.get_or_create_control_behavior()
    behavior.circuit_enable_disable = true
    behavior.circuit_condition = {first_signal = {type = "virtual", name = "signal-A"}, comparator = ">", constant = 0}
    local combinator = surface().create_entity({name = "constant-combinator", position = {-6, 6}, force = "player"})
    storage.combinator = combinator
    local wire = combinator.get_wire_connector(defines.wire_connector_id.circuit_red, true)
    expect("the combinator wires to the gate", wire.connect_to(a.get_wire_connector(defines.wire_connector_id.circuit_red, true)), true)
  end},

  {30, function()
    local a = storage.a
    expect("a false condition closes the gate", remote.call("bte-stargate-test", "is_open", a.unit_number), false)
    expect("the closing gate plays its collapse", drawn("bte-stargate-closing") >= 1 and drawn("bte-stargate-closing-high") >= 1, true)
    expect("the closed gate's veil is gone", #surface().find_entities_filtered({name = "bte-stargate-veil", position = {a.position.x + 1, a.position.y + 3}, radius = 0.5}), 0)
    storage.closed_charge = remote.call("bte-stargate-test", "charge", a.unit_number)
  end},

  {30, function()
    local a = storage.a
    -- The leak is 0.5 % of the charge a second: half a second loses 0.25 % of what it held.
    local lost = storage.closed_charge - remote.call("bte-stargate-test", "charge", a.unit_number)
    local expected = storage.closed_charge * (1 - math.exp(-0.0025))
    expect("a closed gate stops charging and leaks 0.5 % of its charge a second (" .. lost .. ")",
      storage.closed_charge > 0.01 and math.abs(lost - expected) < expected * 0.05, true)
    remote.call("bte-stargate-test", "set_keep_charged", a.unit_number, true)
  end},

  {30, function()
    local a = storage.a
    local charge = remote.call("bte-stargate-test", "charge", a.unit_number)
    expect("a closed gate set to keep charged tops up (" .. charge .. ")", charge > 0.99, true)
    remote.call("bte-stargate-test", "set_keep_charged", a.unit_number, false)
    local section = storage.combinator.get_or_create_control_behavior().get_section(1)
    section.set_slot(1, {value = {type = "virtual", name = "signal-A", quality = "normal"}, min = 1})
  end},

  {30, function()
    local a, b = storage.a, storage.b
    expect("a true condition opens it again", a.status, defines.entity_status.working)
    -- Opening spent 80 % of the full store; at most half a second of refill has come back since.
    local charge = remote.call("bte-stargate-test", "charge", a.unit_number)
    expect("opening spends 80 % of the store (" .. charge .. ")", charge > 0.15 and charge < 0.7, true)
    -- A character stepping into the portal leaves the world, then arrives in front of B (y 4.9, just
    -- clear of its portal zone) and runs south five tiles.
    storage.traveller = surface().create_entity({name = "character", position = {1, 3}, force = "player"})
    expect("a character stands in the portal", storage.traveller ~= nil, true)
  end},

  {10, function()
    local traveller = storage.traveller
    expect("the traveller is in transit, out of the world", traveller.surface.name, "bte-stargate-limbo")
    expect("the veil plays its passage animation", drawn("bte-stargate-passage"), 1)
  end},

  {125, function()
    local traveller = storage.traveller
    expect("arriving, the traveller is still out of the world", traveller.surface.name, "bte-stargate-limbo")
    expect("the partner plays the reversed ripples", drawn("bte-stargate-arrival"), 1)
  end},

  {69, function()
    local traveller = storage.traveller
    expect("the traveller arrives on the partner's surface", traveller.surface.name, "nauvis")
    local p = traveller.position
    expect("the traveller arrives in front of the partner (" .. serpent.line(p) .. ")", math.abs(p.x - 21) < 2 and p.y > 3.5 and p.y < 9, true)
  end},

  {80, function()
    local p = storage.traveller.position
    expect("the traveller runs out of the ring and stops (" .. serpent.line(p) .. ")", p.y > 9.6 and p.y < 10.8, true)
    storage.traveller.destroy()
  end},

  -- Vehicles and enemies, A to B on one surface. A car stopped behind the ring with only its box in the
  -- zone (its centre 1.7, box to 2.7; the zone starts at 2.5) goes; one parked further back stays. An
  -- enemy biter and a pentapod strafer (a spider-unit) in the portal go too, as clones.
  {5, function()
    storage.car = surface().create_entity({name = "car", position = {1, 1.7}, force = "player"})
    storage.parked = surface().create_entity({name = "car", position = {1, -3}, force = "player"})
    storage.car.insert({name = "coal", count = 7})
    surface().create_entity({name = "small-biter", position = {3, 3.5}, force = "enemy"})
    surface().create_entity({name = "small-strafer-pentapod", position = {-1, 3.5}, force = "enemy"})
  end},

  {10, function()
    expect("a car touching the zone is in transit", storage.car.surface.name, "bte-stargate-limbo")
    expect("a car short of the zone stays", storage.parked.surface.name, "nauvis")
    expect("a vehicle waits inactive", storage.car.active, false)
    local limbo = game.get_surface("bte-stargate-limbo")
    expect("the biter waits in limbo", limbo.count_entities_filtered({name = "small-biter"}), 1)
    expect("the strafer waits in limbo", limbo.count_entities_filtered({name = "small-strafer-pentapod"}), 1)
    expect("the biter has left the portal", surface().count_entities_filtered({name = "small-biter", area = {{-6, -6}, {8, 8}}}), 0)
    for _, unit in pairs(limbo.find_entities_filtered({type = {"unit", "spider-unit"}})) do
      expect("units wait inactive", unit.active, false)
    end
  end},

  {190, function()
    local car = storage.car
    expect("the car arrives on the partner's surface", car.surface.name, "nauvis")
    local p = car.position
    -- B's ring is at y 3; the car's box (1 tile from its centre) arrives clear of the zone's front, 4.5.
    expect("the car arrives in front of the partner (" .. serpent.line(p) .. ")", math.abs(p.x - 21) < 2 and p.y > 5.4 and p.y < 12, true)
    expect("the car faces south", car.orientation, 0.5)
    expect("the car is active again", car.active, true)
    expect("the car keeps its fuel", car.get_item_count("coal"), 7)
    local near_b = {{15, 3}, {27, 16}}
    expect("the biter arrives in front of the partner", surface().count_entities_filtered({name = "small-biter", area = near_b}), 1)
    expect("the strafer arrives in front of the partner", surface().count_entities_filtered({name = "small-strafer-pentapod", area = near_b}), 1)
    expect("limbo is empty", game.get_surface("bte-stargate-limbo").count_entities_filtered({type = {"car", "unit", "spider-unit"}}), 0)
    storage.car_arrival = p.y
  end},

  {60, function()
    local p = storage.car.position
    expect("the car drives out of the ring (" .. serpent.line(p) .. ")", p.y > storage.car_arrival + 4, true)
    for _, entity in pairs(surface().find_entities_filtered({name = {"car", "small-biter", "small-strafer-pentapod"}})) do
      entity.destroy()
    end
    -- Across surfaces: gate C on another surface, a tank with a driver and a passenger, and a
    -- spidertron with a driver and an old autopilot target.
    local far = game.create_surface("bte-test-far")
    far.generate_with_lab_tiles = true
    far.request_to_generate_chunks({0, 0}, 2)
    far.force_generate_chunk_requests()
    storage.c = far.create_entity({name = GATE, position = {0, 0}, force = "player", raise_built = true})
    remote.call("bte-stargate-test", "pair", storage.a.unit_number, storage.c.unit_number)
    local tank = surface().create_entity({name = "tank", position = {2.5, 3}, force = "player"})
    tank.insert({name = "coal", count = 9})
    storage.tank, storage.driver, storage.passenger = tank,
      surface().create_entity({name = "character", position = {8, 8}, force = "player"}),
      surface().create_entity({name = "character", position = {9, 8}, force = "player"})
    tank.set_driver(storage.driver)
    tank.set_passenger(storage.passenger)
    local spider = surface().create_entity({name = "spidertron", position = {-0.5, 3}, force = "player"})
    storage.pilot = surface().create_entity({name = "character", position = {10, 8}, force = "player"})
    spider.set_driver(storage.pilot)
    storage.spider = spider
  end},

  {200, function()
    local tank, spider = storage.tank, storage.spider
    expect("the tank crosses to the partner's surface", tank.surface.name, "bte-test-far")
    expect("its driver stays seated", tank.get_driver(), storage.driver)
    expect("its passenger stays seated", tank.get_passenger(), storage.passenger)
    expect("the crew is on the new surface", storage.driver.surface.name .. storage.passenger.surface.name, "bte-test-farbte-test-far")
    expect("the tank keeps its fuel", tank.get_item_count("coal"), 9)
    expect("the tank arrives in front of C (" .. serpent.line(tank.position) .. ")", math.abs(tank.position.x - 1) < 2.5 and tank.position.y > 5.7, true)
    expect("the spidertron crosses too", spider.surface.name, "bte-test-far")
    expect("its driver stays seated", spider.get_driver(), storage.pilot)
    local goal = spider.autopilot_destinations[1]
    expect("the spidertron walks five tiles south (" .. serpent.line(goal) .. ")",
      goal ~= nil and math.abs(goal.y - spider.position.y) <= 5.01 and goal.y > spider.position.y + 3, true)
    expect("an arrival is not sent straight back through its gate", remote.call("bte-stargate-test", "can_enter", spider), false)
    for _, entity in pairs({tank, spider, storage.driver, storage.passenger, storage.pilot}) do
      entity.destroy()
    end
    -- A gate on a surface without gravity takes no car: Space Age cars need gravity.
    local zero = game.create_surface("bte-test-zero-g")
    zero.generate_with_lab_tiles = true
    zero.request_to_generate_chunks({0, 0}, 2)
    zero.force_generate_chunk_requests()
    zero.set_property("gravity", 0)
    storage.z = zero.create_entity({name = GATE, position = {0, 0}, force = "player", raise_built = true})
    remote.call("bte-stargate-test", "pair", storage.a.unit_number, storage.z.unit_number)
    storage.car = surface().create_entity({name = "car", position = {1, 3}, force = "player"})
  end},

  {20, function()
    expect("a car is refused by a surface without gravity", storage.car.surface.name, "nauvis")
    storage.car.destroy()
    storage.c.destroy()
    storage.z.destroy()
    remote.call("bte-stargate-test", "pair", storage.a.unit_number, storage.b.unit_number)
    local a, b = storage.a, storage.b
    b.die()
    expect("losing the partner unpairs", remote.call("bte-stargate-test", "state", a.unit_number).partner, nil)
    -- With no partner it leads to the unexplored chunk closest to the spawn of a visited planet.
    -- Headless runs do not chart, so the visited-planet choice is untested here; the landing spot is.
    local to = remote.call("bte-stargate-test", "random_location", "player", "nauvis")
    local chunk = to and {x = math.floor(to.x / 32), y = math.floor(to.y / 32)}
    expect("a random destination is an unexplored chunk", chunk ~= nil and not game.forces.player.is_chunk_charted(surface(), chunk), true)
    expect("it is the one nearest the spawn", chunk and math.abs(chunk.x) <= 1 and math.abs(chunk.y) <= 1, true)
    expect("an unpaired gate stays open", a.disabled_by_script, false)
    a.destroy()
  end},

  {31, function()
    expect("gone gates leave no lights", #rendering.get_all_objects("bte-stargate"), 0)
    expect("gone gates leave no barriers", #surface().find_entities_filtered({name = {"bte-stargate-capacitor", "bte-stargate-body", "bte-stargate-top", "bte-stargate-veil", "bte-stargate-veil-top", "bte-stargate-side-block", "bte-stargate-cabinet-block", "bte-stargate-rack-block"}}), 0)
  end},

  -- Gates charging beside a factory share its spare power: SHARE gates on a SUPPLY network with a
  -- LOAD (a machine-priority consumer). Their stores are emptied every tick so they keep asking.
  -- Over the last two thirds of SHARE_TICKS the factory must keep nearly all its power and the gates
  -- together take most of the spare. The case is the hardest modelled one: three gates and a 300 MW
  -- factory with 100 MW spare.
  {5, function()
    surface().create_entity({name = "substation", position = {52, 34}, force = "player"})
    local source = surface().create_entity({name = "bte-stargate-test-power", position = {50, 34}, force = "player"})
    source.power_production = SHARE.supply / 60
    source.electric_buffer_size = SHARE.supply / 60
    local load = surface().create_entity({name = "bte-stargate-test-load", position = {50, 36}, force = "player"})
    load.power_production = 0
    load.power_usage = SHARE.load / 60
    load.electric_buffer_size = SHARE.load / 60
    local gates = {}
    for index = 1, SHARE.gates do
      local gate = surface().create_entity({name = GATE, position = {44 + 16 * index, 40}, force = "player", raise_built = true})
      surface().create_entity({name = "substation", position = {44 + 16 * index - 8, 34}, force = "player"})
      -- Switched off so it never opens, but kept charging.
      remote.call("bte-stargate-test", "set_enabled", gate.unit_number, false)
      remote.call("bte-stargate-test", "set_keep_charged", gate.unit_number, true)
      gates[index] = gate
    end
    storage.share = {gates = gates, load = load, start = game.tick, fed = 0, got = 0, n = 0}
  end},

  {SHARE_TICKS, function()
    local share = storage.share
    local fed, used = share.fed / share.n, share.got / share.n * 60 / (SHARE.supply - SHARE.load)
    log(string.format("SHARE supply %d load %d gates %d: factory fed %.4f, lost %.1f MJ, gates use %.2f of spare",
      SHARE.supply / 1e6, SHARE.load / 1e6, SHARE.gates, fed, share.lost / 1e6, used))
    expect("the factory keeps its power beside charging gates (" .. fed .. ")", fed > 0.995, true)
    expect("the gates take most of the spare power (" .. used .. ")", used > 0.6 and used < 1.01, true)
    for _, gate in pairs(share.gates) do
      gate.destroy()
    end
    storage.share = nil
  end},

  -- Direct mode (scripts/power_bank.lua): two paired, open gates beside a 300 MW factory on a 3 GW
  -- supply hand their steady draw to the engine once full and fed for five seconds, and stay so;
  -- cutting the supply below the total sends them back to the adaptive request within a check, and
  -- the factory keeps its power.
  {5, function()
    local s = game.create_surface("bte-test-direct")
    s.generate_with_lab_tiles = true
    s.request_to_generate_chunks({0, 0}, 3)
    s.force_generate_chunk_requests()
    s.create_entity({name = "substation", position = {-8, -6}, force = "player"})
    s.create_entity({name = "substation", position = {8, -6}, force = "player"})
    local source = s.create_entity({name = "bte-stargate-test-power", position = {0, -10}, force = "player"})
    source.power_production, source.electric_buffer_size = 3e9 / 60, 3e9 / 60
    local load = s.create_entity({name = "bte-stargate-test-load", position = {0, -8}, force = "player"})
    load.power_production, load.power_usage, load.electric_buffer_size = 0, DIRECT_LOAD / 60, DIRECT_LOAD / 60
    local a = s.create_entity({name = GATE, position = {-8, 0}, force = "player", raise_built = true})
    local b = s.create_entity({name = GATE, position = {8, 0}, force = "player", raise_built = true})
    remote.call("bte-stargate-test", "pair", a.unit_number, b.unit_number)
    storage.direct = {gates = {a, b}, source = source, load = load, fed = 0, n = 0}
  end},
  {600, function()
    local direct = storage.direct
    for _, gate in pairs(direct.gates) do
      expect("an open gate fed in full goes direct", remote.call("bte-stargate-test", "bank", gate.unit_number).direct ~= nil, true)
      -- The window's figures: the test's 30 MW upkeep and the full 0.3 GJ store's 1.5 MW leak, and
      -- nothing left to charge.
      local flow = remote.call("bte-stargate-test", "power_flow", gate.unit_number)
      expect("the window shows the upkeep (" .. flow.upkeep .. ")", math.abs(flow.upkeep - 30e6) < 1e3, true)
      expect("the window shows the leak (" .. flow.leak .. ")", math.abs(flow.leak - 1.5e6) < 1e3, true)
      expect("the window shows no charging (" .. flow.charging .. ")", flow.charging < 1e3, true)
    end
    -- The factory and the gates' upkeep (about 66 MW with the test's figures) on 330 MW.
    direct.source.power_production, direct.source.electric_buffer_size = 330e6 / 60, 330e6 / 60
    direct.cut = true
  end},
  {90, function()
    local direct = storage.direct
    for _, gate in pairs(direct.gates) do
      local bank = remote.call("bte-stargate-test", "bank", gate.unit_number)
      expect("a direct gate short of power returns to the adaptive request", bank.direct, nil)
      expect("its shortfall comes out of the store", bank.charge < 0.3e9 * 0.999, true)
    end
    local fed = direct.fed / direct.n
    expect("the factory keeps its power once the gates back off (" .. fed .. ")", fed > 0.98, true)
    for _, gate in pairs(direct.gates) do
      gate.destroy()
    end
    storage.direct = nil
  end},

  -- A train sent towards a partner with no track beyond its own: the locomotive comes out and stops
  -- at the partner's edge; the wagon behind it, not yet out of the ring, and the last wagon are
  -- smashed, and the last one's driver lands beside the arrival lane, towards the gate's centre.
  {5, function()
    local function lab(name)
      local s = game.create_surface(name)
      s.generate_with_lab_tiles = true
      s.request_to_generate_chunks({0, 0}, 3)
      s.force_generate_chunk_requests()
      return s
    end
    local ca, cb = lab("bte-test-crash-a"), lab("bte-test-crash-b")
    local a = ca.create_entity({name = GATE, position = {0, 0}, force = "player", raise_built = true})
    local b = cb.create_entity({name = GATE, position = {0, 0}, force = "player", raise_built = true})
    ca.create_entity({name = "substation", position = {-10, -6}, force = "player"})
    local source = ca.create_entity({name = "bte-stargate-test-power", position = {-12, -6}, force = "player"})
    source.power_production, source.electric_buffer_size, source.energy = 1e9, 1e10, 1e10
    remote.call("bte-stargate-test", "set_station", a.unit_number, "right")
    remote.call("bte-stargate-test", "set_station", b.unit_number, "left")
    remote.call("bte-stargate-test", "pair", a.unit_number, b.unit_number)
    for y = 9, 41, 2 do
      ca.create_entity({name = "straight-rail", position = {3, y}, direction = defines.direction.north, force = "player"})
    end
    ca.create_entity({name = "locomotive", position = {3, 22}, direction = defines.direction.north, force = "player"})
    ca.create_entity({name = "cargo-wagon", position = {3, 29}, direction = defines.direction.north, force = "player"})
    local wagon = ca.create_entity({name = "cargo-wagon", position = {3, 36}, direction = defines.direction.north, force = "player"})
    storage.crash_driver = ca.create_entity({name = "character", position = {6, 36}, force = "player"})
    wagon.set_driver(storage.crash_driver)
    storage.crash = {ca = ca, cb = cb}
    -- A second pair at x 40 with four tiles of track beyond the partner's edge: the locomotive gets
    -- out, and the one wagon behind it, sent with room to spare, stops before it has emerged and is
    -- crushed with nothing left to send.
    local a2 = ca.create_entity({name = GATE, position = {40, 0}, force = "player", raise_built = true})
    local b2 = cb.create_entity({name = GATE, position = {40, 0}, force = "player", raise_built = true})
    ca.create_entity({name = "substation", position = {30, -6}, force = "player"})
    local source2 = ca.create_entity({name = "bte-stargate-test-power", position = {28, -6}, force = "player"})
    source2.power_production, source2.electric_buffer_size, source2.energy = 1e9, 1e10, 1e10
    remote.call("bte-stargate-test", "set_station", a2.unit_number, "right")
    remote.call("bte-stargate-test", "set_station", b2.unit_number, "left")
    remote.call("bte-stargate-test", "pair", a2.unit_number, b2.unit_number)
    for y = 9, 41, 2 do
      ca.create_entity({name = "straight-rail", position = {43, y}, direction = defines.direction.north, force = "player"})
    end
    for y = 9, 11, 2 do
      cb.create_entity({name = "straight-rail", position = {43, y}, direction = defines.direction.north, force = "player"})
    end
    ca.create_entity({name = "locomotive", position = {43, 22}, direction = defines.direction.north, force = "player"})
    ca.create_entity({name = "cargo-wagon", position = {43, 29}, direction = defines.direction.north, force = "player"})
  end},
  {200, function()
    local cars = storage.crash.ca.find_entities_filtered({type = {"locomotive", "cargo-wagon"}})
    local where = {}
    for _, car in pairs(cars) do
      where[#where + 1] = car.name .. "@" .. car.position.y .. "/" .. #car.train.carriages
    end
    expect("the crash trains are whole before they go (" .. table.concat(where, " ") .. ")", #cars, 5)
    local trains = {}
    for _, car in pairs(cars) do
      trains[car.train.id] = car.train
    end
    for _, train in pairs(trains) do
      train.manual_mode = true
      train.speed = (train.front_stock.position.y < train.back_stock.position.y and 1 or -1) * 0.3
    end
  end},
  {700, function()
    local crash = storage.crash
    local STOCK = {"locomotive", "cargo-wagon"}
    expect("the whole train left", crash.ca.count_entities_filtered({type = STOCK}), 0)
    local first, second = {{-8, -8}, {10, 40}}, {{32, -8}, {50, 40}}
    expect("the locomotive came through", crash.cb.count_entities_filtered({type = "locomotive", area = first}), 1)
    expect("no wagon survives", crash.cb.count_entities_filtered({type = "cargo-wagon", area = first}), 0)
    expect("both left remnants", crash.cb.count_entities_filtered({name = "cargo-wagon-remnants", area = first}), 2)
    local loco = crash.cb.find_entities_filtered({type = "locomotive", area = second})[1]
    expect("the second locomotive got out", loco and loco.position.y > 3, true)
    local w = crash.cb.find_entities_filtered({type = "cargo-wagon", area = second})[1]
    expect("its wagon, the last one sent, was crushed in the ring (" .. (w and w.position.y or "-") .. ", loco " .. (loco and loco.position.y or "-") .. ")", crash.cb.count_entities_filtered({type = "cargo-wagon", area = second}), 0)
    expect("and left remnants", crash.cb.count_entities_filtered({name = "cargo-wagon-remnants", area = second}), 1)
    local driver = storage.crash_driver
    expect("the wagon's driver was thrown clear at the partner", driver.valid and driver.surface.name, "bte-test-crash-b")
    -- The partner is a left-hand gate: its arrival lane is at x 3, the centre at x 1.
    expect("between the tracks (" .. serpent.line(driver.position) .. ")", math.abs(driver.position.x - 2) < 1 and driver.position.y > 3, true)
    expect("no transfer is left running", remote.call("bte-stargate-test", "rail_transfers"), 0)
    storage.crash, storage.crash_driver = nil, nil
  end},

  -- The stop at the edge: an automatic train inside a gate whose partner cannot take it (not paired
  -- yet) stops at the edge, held in manual mode, instead of driving on into the ring; once paired it
  -- is sent, arriving in automatic mode. Then a train driven by hand into a closed gate is not taken.
  {5, function()
    local function lab(name)
      local s = game.create_surface(name)
      s.generate_with_lab_tiles = true
      s.request_to_generate_chunks({0, 0}, 3)
      s.force_generate_chunk_requests()
      return s
    end
    local ha, hb = lab("bte-test-hold-a"), lab("bte-test-hold-b")
    local a = ha.create_entity({name = GATE, position = {0, 0}, force = "player", raise_built = true})
    local b = hb.create_entity({name = GATE, position = {0, 0}, force = "player", raise_built = true})
    ha.create_entity({name = "substation", position = {-10, -6}, force = "player"})
    local source = ha.create_entity({name = "bte-stargate-test-power", position = {-12, -6}, force = "player"})
    source.power_production, source.electric_buffer_size, source.energy = 1e9, 1e10, 1e10
    remote.call("bte-stargate-test", "set_station", a.unit_number, "right")
    remote.call("bte-stargate-test", "set_station", b.unit_number, "left")
    for y = 9, 41, 2 do
      ha.create_entity({name = "straight-rail", position = {3, y}, direction = defines.direction.north, force = "player"})
      hb.create_entity({name = "straight-rail", position = {3, y}, direction = defines.direction.north, force = "player"})
    end
    hb.create_entity({name = "train-stop", position = {1, 31}, direction = defines.direction.south, force = "player"}).backer_name = "bte-test-hold-far"
    -- Inside the gate's block, just short of the edge.
    local loco = ha.create_entity({name = "locomotive", position = {3, 12}, direction = defines.direction.north, force = "player"})
    loco.insert({name = "coal", count = 20})
    local schedule = loco.train.get_schedule()
    schedule.add_record({station = remote.call("bte-stargate-test", "station", a.unit_number).backer_name, wait_conditions = {}})
    schedule.add_record({station = "bte-test-hold-far", wait_conditions = {{type = "time", ticks = 6000}}})
    schedule.go_to_station(1)
    loco.train.manual_mode = false
    storage.hold = {ha = ha, hb = hb, a = a, b = b, loco = loco}
  end},
  {120, function()
    local hold = storage.hold
    expect("an automatic train at a gate with no partner is stopped at the edge",
      hold.loco.valid and hold.loco.train.manual_mode and hold.loco.train.speed == 0
      and hold.loco.bounding_box.left_top.y > 6.5, true)
    remote.call("bte-stargate-test", "pair", hold.a.unit_number, hold.b.unit_number)
  end},
  {400, function()
    local hold = storage.hold
    local arrived = hold.hb.find_entities_filtered({type = "locomotive"})[1]
    expect("the held train is sent once the gate is paired", arrived ~= nil and not hold.loco.valid, true)
    expect("and arrives in automatic mode", arrived and arrived.train.manual_mode, false)
    arrived.destroy()
    remote.call("bte-stargate-test", "set_enabled", hold.a.unit_number, false)
    hold.loco = hold.ha.create_entity({name = "locomotive", position = {3, 20}, direction = defines.direction.north, force = "player"})
    hold.loco.train.manual_mode = true
    hold.loco.train.speed = (math.cos(hold.loco.orientation * 2 * math.pi) > 0 and 1 or -1) * 0.2
  end},
  {200, function()
    local hold = storage.hold
    expect("a train driven by hand into a closed gate is not taken", hold.loco.valid
      and hold.hb.count_entities_filtered({type = "locomotive"}), 0)
    storage.hold = nil
  end},

  -- Speed: an automatic train from far off, heading for the gate's station behind the ring, still
  -- crosses the edge at speed, gathers speed through the ring, and arrives coupled, at that speed.
  {5, function()
    local function lab(name)
      local s = game.create_surface(name)
      s.generate_with_lab_tiles = true
      s.request_to_generate_chunks({0, 340}, 11)
      s.force_generate_chunk_requests()
      return s
    end
    local fa, fb = lab("bte-test-fast-a"), lab("bte-test-fast-b")
    local a = fa.create_entity({name = GATE, position = {0, 0}, force = "player", raise_built = true})
    local b = fb.create_entity({name = GATE, position = {0, 0}, force = "player", raise_built = true})
    fa.create_entity({name = "substation", position = {-10, -6}, force = "player"})
    local source = fa.create_entity({name = "bte-stargate-test-power", position = {-12, -6}, force = "player"})
    source.power_production, source.electric_buffer_size, source.energy = 1e9, 1e10, 1e10
    remote.call("bte-stargate-test", "set_station", a.unit_number, "right")
    remote.call("bte-stargate-test", "set_station", b.unit_number, "left")
    remote.call("bte-stargate-test", "pair", a.unit_number, b.unit_number)
    for y = 9, 681, 2 do
      fa.create_entity({name = "straight-rail", position = {3, y}, direction = defines.direction.north, force = "player"})
      fb.create_entity({name = "straight-rail", position = {3, y}, direction = defines.direction.north, force = "player"})
    end
    fb.create_entity({name = "train-stop", position = {1, 391}, direction = defines.direction.south, force = "player"}).backer_name = "bte-test-fast-far"
    local function train(y, destination, wagons, cargo, fuel)
      local loco = fa.create_entity({name = "locomotive", position = {3, y}, direction = defines.direction.north, force = "player"})
      for k = 1, wagons or 2 do
        local wagon = fa.create_entity({name = "cargo-wagon", position = {3, y + 7 * k}, direction = defines.direction.north, force = "player"})
        if cargo then
          wagon.insert({name = cargo, count = 10000})
        end
      end
      loco.insert({name = fuel or "nuclear-fuel", count = 2})
      local schedule = loco.train.get_schedule()
      schedule.add_record({station = remote.call("bte-stargate-test", "station", a.unit_number).backer_name, wait_conditions = {}})
      schedule.add_record({station = destination or "bte-test-fast-far", wait_conditions = {{type = "time", ticks = 6000}}})
      schedule.go_to_station(1)
      loco.train.manual_mode = false
      return loco
    end
    storage.fast = {fa = fa, fb = fb, a = a, b = b, train = train, loco = train(370), top = 0}
  end},
  {900, function()
    local fast = storage.fast
    expect("a train heading for the gate's station crosses the edge at speed", (fast.entry or 0) > 0.25, true)
    expect("it gathers speed through the ring and leaves at least as fast", (fast.top or 0) >= (fast.entry or 1), true)
    expect("its locomotive comes out at the speed it went in, not standing", (fast.first or 0) >= (fast.entry or 1), true)
    local arrived = fast.fb.find_entities_filtered({type = "locomotive"})[1]
    expect("and arrives coupled", arrived and #arrived.train.carriages, 3)
    log("STARGATE_TEST_INFO: edge speed " .. tostring(fast.entry) .. ", first out " .. tostring(fast.first) .. ", out " .. tostring(fast.top))
    for _, car in pairs(fast.fb.find_entities_filtered({type = {"locomotive", "cargo-wagon"}})) do
      car.destroy()
    end
    -- Commitment: the gate closes once the next train, 30 tiles out, has reserved its way through the
    -- green signal; it is sent anyway.
    fast.entry, fast.top, fast.loco, fast.close = nil, 0, fast.train(370), true
  end},
  {900, function()
    local fast = storage.fast
    expect("the gate closed once a train had reserved its way through the entry signal", fast.closed and fast.reserved, true)
    expect("which is sent all the same", fast.fb.count_entities_filtered({type = "locomotive"}) == 1
      and fast.fa.count_entities_filtered({type = "locomotive"}) == 0, true)
    for _, car in pairs(fast.fb.find_entities_filtered({type = {"locomotive", "cargo-wagon"}})) do
      car.destroy()
    end
    start_mid(MID_CASES[1])
  end},
  {1500, function() check_mid() start_mid(MID_CASES[2]) end},
  {1500, function() check_mid() start_mid(MID_CASES[3]) end},
  {1500, function() check_mid() start_mid(MID_CASES[4]) end},
  {1500, function() check_mid() start_mid(MID_CASES[5]) end},
  {1500, function() check_mid() start_mid(MID_CASES[6]) end},
  {1500, function()
    check_mid()
    local fast = storage.fast
    -- A red signal 50 tiles beyond the partner, a wagon standing behind it: the fast arrival drives
    -- itself, automatic while still arriving, and stops at the signal.
    fast.fb.create_entity({name = "rail-signal", position = {1.5, 59.5}, direction = defines.direction.north, force = "player"})
    fast.blocker = fast.fb.create_entity({name = "cargo-wagon", position = {3, 80}, direction = defines.direction.north, force = "player"})
    remote.call("bte-stargate-test", "set_enabled", fast.a.unit_number, true)
    remote.call("bte-stargate-test", "set_enabled", fast.b.unit_number, true)
    fast.entry, fast.top, fast.close, fast.loco, fast.auto = nil, 0, false, fast.train(370), nil
  end},
  {900, function()
    local fast = storage.fast
    local arrived = fast.fb.find_entities_filtered({type = "locomotive"})[1]
    log("STARGATE_TEST_INFO: red signal: edge " .. tostring(fast.entry) .. ", auto while arriving " .. tostring(fast.auto)
      .. ", loco " .. tostring(arrived and arrived.position.y) .. " cars " .. tostring(arrived and #arrived.train.carriages)
      .. " blocker health " .. tostring(fast.blocker.valid and fast.blocker.health) .. " state " .. tostring(arrived and arrived.train.state))
    expect("an arriving train drives itself while its carriages still come through", fast.auto, true)
    expect("and stops at a red signal beyond the partner", arrived and arrived.train.carriages[1].valid
      and arrived.position.y < 59.5 and fast.blocker.valid and fast.blocker.health == fast.blocker.max_health, true)
    for _, car in pairs(fast.fb.find_entities_filtered({type = {"locomotive", "cargo-wagon"}})) do
      car.destroy()
    end
    fast.fb.find_entity("rail-signal", {1.5, 59.5}).destroy()
    -- A branch right after the partner: a curve off the straight track to a parallel one with T1 on
    -- it. The arriving train must take the curve, as its path says, rather than run on straight.
    for _, r in pairs({{"curved-rail-a", 3, 44, 10}, {"half-diagonal-rail", 1, 49, 2}, {"half-diagonal-rail", -1, 53, 2},
        {"curved-rail-a", -3, 58, 2}}) do
      fast.fb.create_entity({name = r[1], position = {r[2], r[3]}, direction = r[4], force = "player"})
    end
    for y = 61, 101, 2 do
      fast.fb.create_entity({name = "straight-rail", position = {-3, y}, direction = defines.direction.north, force = "player"})
    end
    fast.fb.create_entity({name = "train-stop", position = {-5, 95}, direction = defines.direction.south, force = "player"}).backer_name = "bte-test-fast-t1"
    fast.entry, fast.top, fast.auto, fast.loco = nil, 0, nil, fast.train(370, "bte-test-fast-t1")
  end},
  {900, function()
    local fast = storage.fast
    local arrived = fast.fb.find_entities_filtered({type = "locomotive"})[1]
    log("STARGATE_TEST_INFO: branch: loco " .. tostring(arrived and serpent.line(arrived.position)) .. " state "
      .. tostring(arrived and arrived.train.state) .. " cars " .. tostring(arrived and #arrived.train.carriages))
    expect("an arriving train takes the branch its path needs", arrived and arrived.position.x < 0
      and arrived.train.state == defines.train_state.wait_station and #arrived.train.carriages, 3)
    for _, car in pairs(fast.fb.find_entities_filtered({type = {"locomotive", "cargo-wagon"}})) do
      car.destroy()
    end
    -- Too little room: a red signal 6 tiles beyond the partner, shorter than the train, a wagon
    -- standing right behind it. The train is pushed out until each carriage is out of the ring, so its
    -- front survives and the carriages still to come are wrecked, not the locomotive.
    fast.fb.create_entity({name = "rail-signal", position = {1.5, 13.5}, direction = defines.direction.north, force = "player"})
    fast.fb.create_entity({name = "cargo-wagon", position = {3, 18}, direction = defines.direction.north, force = "player"})
    fast.entry, fast.top, fast.auto, fast.loco = nil, 0, nil, fast.train(370)
  end},
  {900, function()
    local fast = storage.fast
    local arrived = fast.fb.find_entities_filtered({type = "locomotive"})[1]
    log("STARGATE_TEST_INFO: short block: loco " .. tostring(arrived and serpent.line(arrived.position)) .. " cars "
      .. tostring(arrived and #arrived.train.carriages) .. " remnants " .. fast.fb.count_entities_filtered({name = "cargo-wagon-remnants"}))
    expect("with too little room the locomotive comes out and survives", arrived ~= nil and not fast.loco.valid, true)
    expect("and the rear is wrecked", fast.fb.count_entities_filtered({name = "cargo-wagon-remnants"}) >= 1, true)
    for _, e in pairs(fast.fb.find_entities_filtered({type = {"locomotive", "cargo-wagon", "rail-signal", "cargo-wagon-remnants", "locomotive-remnants"},
        area = {{-10, 9}, {10, 60}}})) do
      e.destroy()
    end
    -- Broken track 16 tiles beyond the partner: the train has no path, and is pushed out to the
    -- rails' end rather than stopping in the ring, so its front survives.
    for _, y in pairs({25, 27}) do
      fast.fb.find_entity("straight-rail", {3, y}).destroy()
    end
    fast.entry, fast.top, fast.auto, fast.loco = nil, 0, nil, fast.train(370)
  end},
  {900, function()
    local fast = storage.fast
    local arrived = fast.fb.find_entities_filtered({type = "locomotive"})[1]
    log("STARGATE_TEST_INFO: broken track: loco " .. tostring(arrived and serpent.line(arrived.position)) .. " cars "
      .. tostring(arrived and #arrived.train.carriages))
    expect("with the track broken beyond the partner the locomotive is pushed out and survives",
      arrived ~= nil and arrived.position.y > 12 and not fast.loco.valid, true)
    storage.fast = nil
  end},

  -- Station mode: gate R1 on one surface sends a train to R2 on another. R1 departs on its right lane
  -- (x 3) and R2 receives on its left-mode arrival lane (also x 3); vanilla rails lead south from both.
  {5, function()
    local function lab(name)
      local s = game.create_surface(name)
      s.generate_with_lab_tiles = true
      s.request_to_generate_chunks({0, 0}, 3)
      s.force_generate_chunk_requests()
      return s
    end
    local ra, rb = lab("bte-test-rail-a"), lab("bte-test-rail-b")
    local g1 = ra.create_entity({name = GATE, position = {0, 0}, force = "player", raise_built = true})
    local g2 = rb.create_entity({name = GATE, position = {0, 0}, force = "player", raise_built = true})
    ra.create_entity({name = "substation", position = {-10, -6}, force = "player"})
    local source = ra.create_entity({name = "bte-stargate-test-power", position = {-12, -6}, force = "player"})
    source.power_production, source.electric_buffer_size, source.energy = 1e9, 1e10, 1e10
    expect("station mode switches on", remote.call("bte-stargate-test", "set_station", g1.unit_number, "right"), true)
    remote.call("bte-stargate-test", "set_station", g2.unit_number, "left")
    expect("two lanes of three rails", #ra.find_entities_filtered({name = "bte-stargate-rail"}), 6)
    local tracks = ra.find_entities_filtered({name = "bte-stargate-tracks", area = {{-8, -8}, {10, 10}}})
    expect("a two-track station draws its track, chevrons for its layout", #tracks == 1 and tracks[1].graphics_variation, 2)
    local partner_tracks = rb.find_entities_filtered({name = "bte-stargate-tracks", area = {{-8, -8}, {10, 10}}})
    expect("the left layout has its own chevrons", #partner_tracks == 1 and partner_tracks[1].graphics_variation, 3)
    local body = ra.find_entities_filtered({name = "bte-stargate-body", area = {{-8, -8}, {10, 10}}})[1]
    expect("its body has the track cut out (two tracks, red while charging)", body.graphics_variation, 6)
    expect("and three hidden behind the ring", #ra.find_entities_filtered({name = "bte-stargate-rail-hidden"}), 6)
    local station = remote.call("bte-stargate-test", "station", g1.unit_number)
    expect("the station is named after the gate", station.backer_name, remote.call("bte-stargate-test", "state", g1.unit_number).name)
    expect("the station stands on the departure lane behind the ring", station.connected_rail and serpent.line(station.connected_rail.position), "{x = 3, y = -3}")
    remote.call("bte-stargate-test", "pair", g1.unit_number, g2.unit_number)
    -- Off at first, so the train waits at the station; and laid out as an earlier version would be.
    remote.call("bte-stargate-test", "set_enabled", g1.unit_number, false)
    remote.call("bte-stargate-test", "forget_layout", g1.unit_number)
    expect("an old layout has no hidden rails", #ra.find_entities_filtered({name = "bte-stargate-rail-hidden"}), 0)
    for _, s in pairs({ra, rb}) do
      for _, x in pairs({-1, 3}) do
        for y = 9, 71, 2 do
          s.create_entity({name = "straight-rail", position = {x, y}, direction = defines.direction.north, force = "player"})
        end
      end
    end
    -- The train's next stop, on R2's surface beside its arrival lane, for southbound trains.
    rb.create_entity({name = "train-stop", position = {1, 61}, direction = defines.direction.south, force = "player"}).backer_name = "bte-test-far"
    local loco = ra.create_entity({name = "locomotive", position = {3, 30}, direction = defines.direction.north, force = "player"})
    local cargo = ra.create_entity({name = "cargo-wagon", position = {3, 37}, direction = defines.direction.north, force = "player"})
    local tank = ra.create_entity({name = "fluid-wagon", position = {3, 44}, direction = defines.direction.north, force = "player"})
    loco.insert({name = "coal", count = 50})
    cargo.insert({name = "iron-plate", count = 100})
    tank.insert_fluid({name = "water", amount = 1000})
    storage.rail_driver = ra.create_entity({name = "character", position = {6, 30}, force = "player"})
    loco.set_driver(storage.rail_driver)
    local schedule = loco.train.get_schedule()
    schedule.group = "bte-test-group"
    schedule.add_record({station = station.backer_name, wait_conditions = {{type = "time", ticks = 30}}})
    schedule.add_record({station = "bte-test-far", wait_conditions = {{type = "time", ticks = 6000}}})
    schedule.go_to_station(1)
    storage.g1, storage.g2, storage.ra, storage.rb = g1, g2, ra, rb
    storage.rail_watch = {deepest = math.huge, first_arrival_rear = nil}
    -- One track both ways: S1 and S2 at x 40, their lane at x 41. A train with no schedule, pushed in
    -- by hand, arrives in manual mode and rolls out.
    local s1 = ra.create_entity({name = GATE, position = {40, 0}, force = "player", raise_built = true})
    local s2 = rb.create_entity({name = GATE, position = {40, 0}, force = "player", raise_built = true})
    ra.create_entity({name = "substation", position = {30, -6}, force = "player"})
    local source2 = ra.create_entity({name = "bte-stargate-test-power", position = {28, -6}, force = "player"})
    source2.power_production, source2.electric_buffer_size, source2.energy = 1e9, 1e10, 1e10
    remote.call("bte-stargate-test", "set_station", s1.unit_number, "single")
    remote.call("bte-stargate-test", "set_station", s2.unit_number, "single")
    remote.call("bte-stargate-test", "pair", s1.unit_number, s2.unit_number)
    for _, s in pairs({ra, rb}) do
      for y = 9, 71, 2 do
        s.create_entity({name = "straight-rail", position = {41, y}, direction = defines.direction.north, force = "player"})
      end
    end
    local pushed = ra.create_entity({name = "cargo-wagon", position = {41, 20}, direction = defines.direction.south, force = "player"})
    ra.create_entity({name = "locomotive", position = {41, 27}, direction = defines.direction.north, force = "player"})
    storage.pushed, storage.s1, storage.s2 = pushed.train, s1, s2
  end},

  {200, function()
    -- Pushed towards the ring (north) once the gates have charged.
    local train = storage.pushed
    train.manual_mode = true
    train.speed = (train.front_stock.position.y < train.back_stock.position.y and 1 or -1) * 0.3
    expect("an old layout gets its hidden rails back", #storage.ra.find_entities_filtered({name = "bte-stargate-rail-hidden", area = {{-8, -8}, {10, 10}}}), 6)
    local station = remote.call("bte-stargate-test", "station", storage.g1.unit_number)
    expect("and its station moves behind the ring", station.connected_rail and station.connected_rail.position.y, -3)
    local waiting = storage.ra.find_entities_filtered({name = "locomotive", area = {{2, 0}, {4, 80}}})[1]
    -- At the gate's entry signal, red while the gate cannot send: still heading for the station, so
    -- it never looks for a path beyond the gate.
    expect("a train waits at the closed entry signal while the gate is off", waiting and waiting.train.state, defines.train_state.wait_signal)
    expect("in automatic mode", waiting and waiting.train.manual_mode, false)
    expect("with its front just outside the gate's edge (" .. tostring(waiting and waiting.bounding_box.left_top.y) .. ")",
      waiting and waiting.bounding_box.left_top.y > 8 and waiting.bounding_box.left_top.y < 9.5, true)
    remote.call("bte-stargate-test", "set_enabled", storage.g1.unit_number, true)
    -- A wagon on R1's arrival lane, inside the gate.
    local parked = storage.ra.create_entity({name = "cargo-wagon", position = {-1, 4}, direction = defines.direction.north, force = "player"})
    expect("a station gate with a train on its rails keeps its mode", remote.call("bte-stargate-test", "set_station", storage.g1.unit_number, nil), false)
    parked.destroy()
    -- Each station has an exit signal on its arrival lane and an entry signal on its departure lane;
    -- a wagon on the track out of R2 holds R1's train at R1's entry signal.
    for _, s in pairs({storage.ra, storage.rb}) do
      for _, signal in pairs(s.find_entities_filtered({name = {"bte-stargate-exit-signal", "bte-stargate-entry-signal"}})) do
        expect("the gate's signal is on its rail", #signal.get_connected_rails(), 1)
      end
    end
    expect("every station gate has an exit and an entry signal",
      storage.rb.count_entities_filtered({name = {"bte-stargate-exit-signal", "bte-stargate-entry-signal"}}), 4)
    expect("each entry signal has its switch, wired to it",
      #storage.rb.find_entities_filtered({name = "bte-stargate-entry-control"})[1].get_wire_connector(defines.wire_connector_id.circuit_red).connections, 1)
    storage.rail_blocker = storage.rb.create_entity({name = "cargo-wagon", position = {3, 40}, direction = defines.direction.north, force = "player"})
  end},

  {120, function()
    local exit = storage.rb.find_entities_filtered({name = "bte-stargate-exit-signal", area = {{-8, 0}, {10, 10}}})[1]
    expect("the exit signal reads the blocked track", exit.signal_state, defines.signal_state.closed)
    local waiting = storage.ra.find_entities_filtered({name = "locomotive", area = {{2, 0}, {4, 80}}})[1]
    expect("a train waits at the entry signal while the way out of the partner is blocked",
      waiting and waiting.train.state, defines.train_state.wait_signal)
    storage.rail_blocker.destroy()
    -- The blocker was seen as an arrival.
    storage.rail_watch.first_arrival_rear = nil
  end},

  {700, function()
    local ra, rb = storage.ra, storage.rb
    local watch = storage.rail_watch
    storage.rail_watch = nil
    -- R1's ring plane is y 3: a vanilla carriage is 4.8 to 5.2 long, so its front gets past y -1.
    expect("carriages drive in behind the veil before vanishing (" .. watch.deepest .. ")", watch.deepest < -1, true)
    expect("arrivals appear behind the partner's veil (" .. tostring(watch.first_arrival_rear) .. ")",
      watch.first_arrival_rear ~= nil and watch.first_arrival_rear <= 3, true)
    expect("each carriage splashes on both gates (" .. tostring(watch.splashes) .. " at once)", (watch.splashes or 0) >= 2, true)
    expect("the whole train has left", ra.count_entities_filtered({type = {"locomotive", "cargo-wagon", "fluid-wagon"}, area = {{-5, 0}, {8, 80}}}), 0)
    local cars = rb.find_entities_filtered({type = {"locomotive", "cargo-wagon", "fluid-wagon"}, area = {{-5, 0}, {8, 80}}})
    expect("the train arrives on the partner's surface", #cars, 3)
    local train = cars[1].train
    expect("its carriages are coupled again", #train.carriages, 3)
    expect("it keeps its cargo", train.get_item_count("iron-plate"), 100)
    expect("it keeps its fluid", math.floor(train.get_fluid_count("water")), 1000)
    local loco = train.locomotives.front_movers[1] or train.locomotives.back_movers[1]
    expect("the locomotive faces away from the ring", loco.orientation, 0.5)
    expect("its driver came along", loco.get_driver() == storage.rail_driver and storage.rail_driver.surface.name, "bte-test-rail-b")
    expect("it runs automatically again", train.manual_mode, false)
    local stop = train.station or train.path_end_stop
    expect("it went on to its next stop", stop and stop.backer_name, "bte-test-far")
    expect("the schedule moved past the gate", train.get_schedule().current, 2)
    expect("it stays in its group", train.get_schedule().group, "bte-test-group")
    local pushed = rb.find_entities_filtered({type = {"locomotive", "cargo-wagon"}, area = {{39, 0}, {43, 80}}})
    expect("the pushed train arrives through the single track", #pushed, 2)
    expect("still coupled", #pushed[1].train.carriages, 2)
    expect("in manual mode", pushed[1].train.manual_mode, true)
    expect("rolled out and not sent back (" .. serpent.line(pushed[1].position) .. ")", pushed[1].position.y > 12, true)
    expect("nothing is left at the sending single track", ra.count_entities_filtered({type = {"locomotive", "cargo-wagon"}, area = {{39, 0}, {43, 80}}}), 0)
    storage.s1.destroy()
    storage.s2.destroy()
    expect("an empty station gate changes mode", remote.call("bte-stargate-test", "set_station", storage.g1.unit_number, nil), true)
    expect("its track picture is gone", ra.count_entities_filtered({name = "bte-stargate-tracks", area = {{-8, -8}, {10, 10}}}), 0)
    expect("its rails are gone", ra.count_entities_filtered({name = {"bte-stargate-rail", "bte-stargate-rail-hidden", "bte-stargate-station"}, area = {{-8, -8}, {10, 10}}}), 0)
    storage.g1.destroy()
    storage.g2.destroy()
  end},

  {31, function()
    expect("a gone station gate leaves no rails", storage.rb.count_entities_filtered({name = {"bte-stargate-rail", "bte-stargate-rail-hidden", "bte-stargate-station"}}), 0)
  end},

  -- A train coming straight back: a locomotive at each end, scheduled from A through the single-track
  -- B and back to A. Coming out of B it reverses and drives back in at once; it must be taken as it
  -- reaches the ring, not stand there with no path while its carriages count as just arrived.
  {5, function()
    local function lab(name)
      local s = game.create_surface(name)
      s.generate_with_lab_tiles = true
      s.request_to_generate_chunks({0, 100}, 5)
      s.force_generate_chunk_requests()
      return s
    end
    local la, lb = lab("bte-test-loop-a"), lab("bte-test-loop-b")
    local a = la.create_entity({name = GATE, position = {0, 0}, force = "player", raise_built = true})
    local b = lb.create_entity({name = GATE, position = {0, 0}, force = "player", raise_built = true})
    for _, s in pairs({la, lb}) do
      s.create_entity({name = "substation", position = {-10, -6}, force = "player"})
      local source = s.create_entity({name = "bte-stargate-test-power", position = {-12, -6}, force = "player"})
      source.power_production, source.electric_buffer_size, source.energy = 1e9, 1e10, 1e10
    end
    remote.call("bte-stargate-test", "set_station", a.unit_number, "right")
    remote.call("bte-stargate-test", "set_station", b.unit_number, "single")
    remote.call("bte-stargate-test", "pair", a.unit_number, b.unit_number)
    for y = 9, 201, 2 do
      la.create_entity({name = "straight-rail", position = {3, y}, direction = defines.direction.north, force = "player"})
      lb.create_entity({name = "straight-rail", position = {1, y}, direction = defines.direction.north, force = "player"})
    end
    local loco = la.create_entity({name = "locomotive", position = {3, 100}, direction = defines.direction.north, force = "player"})
    la.create_entity({name = "cargo-wagon", position = {3, 107}, direction = defines.direction.north, force = "player"})
    local back = la.create_entity({name = "locomotive", position = {3, 114}, direction = defines.direction.south, force = "player"})
    loco.insert({name = "nuclear-fuel", count = 2})
    back.insert({name = "nuclear-fuel", count = 2})
    local schedule = loco.train.get_schedule()
    for _, gate in pairs({a, b, a}) do
      schedule.add_record({station = remote.call("bte-stargate-test", "station", gate.unit_number).backer_name, wait_conditions = {}})
    end
    schedule.go_to_station(1)
    loco.train.manual_mode = false
    storage.loop = {lb = lb, transfers = 0, stood = 0, last = 0}
  end},
  {1800, function()
    local loop = storage.loop
    storage.loop = nil
    expect("the train came back through B (" .. loop.transfers .. " transfers)", loop.transfers >= 2, true)
    expect("it did not stand at B's ring before going back in (" .. loop.stood .. " ticks)", loop.stood <= 10, true)
  end},

  {5, function() start_chain(CHAIN_CASES[1]) end},
  {4900, function() check_chain() start_chain(CHAIN_CASES[2]) end},
  {3100, function() check_chain() start_chain(CHAIN_CASES[3]) end},
  {3100, function() check_chain() start_chain(CHAIN_CASES[4]) end},
  {3100, function() check_chain() start_chain(CHAIN_CASES[5]) end},
  {3100, function() check_chain() start_chain(CHAIN_CASES[6]) end},
  {3100, check_chain},

  -- Mining a half-filled site returns the kit and everything delivered, and builds nothing.
  {5, function()
    local half = build_site(20)
    half.insert({name = "tungsten-plate", count = 100})
    local bag = game.create_inventory(10)
    half.mine({inventory = bag})
    expect("mined site returns its kit", bag.get_item_count("bte-stargate-construction-kit"), 1)
    expect("mined site returns its delivery", bag.get_item_count("tungsten-plate"), 100)
    bag.destroy()
    expect("mining builds nothing", #entities(ASSEMBLING) + #entities(GATE), 0)
    log("STARGATE_TEST_PASS: filters, exact slots, completion, staged build, replacement, grid snapping, gate pairing, power, circuit, transfer, vehicle and enemy transfer, train transfer, and mining paths completed")
  end}
}

script.on_event(defines.events.on_tick, function()
  local fast = storage.fast
  if fast and fast.loco then
    if fast.loco.valid and not fast.entry then
      if remote.call("bte-stargate-test", "rail_transfers") > 0 then
        fast.entry = fast.speed
      end
      fast.speed = math.abs(fast.loco.train.speed)
      if fast.close and not fast.closed and fast.loco.bounding_box.left_top.y < 40 then
        local entry = fast.fa.find_entities_filtered({name = "bte-stargate-entry-signal"})[1]
        fast.reserved = entry and entry.signal_state == defines.signal_state.reserved
        remote.call("bte-stargate-test", "set_enabled", fast.a.unit_number, false)
        fast.closed = true
      end
    end
    if fast.mid then
      -- Each carriage's first position on the partner: its rear must still be behind the veil (the
      -- ring's plane, y 3, give or take a tick's travel, 0.5), or the rest of the train fell behind
      -- the part already out.
      fast.seen = fast.seen or {}
      for _, car in pairs(fast.fb.find_entities_filtered({type = {"locomotive", "cargo-wagon"}})) do
        if not fast.seen[car.unit_number] then
          fast.seen[car.unit_number] = true
          fast.outside = math.max(fast.outside or -math.huge, car.bounding_box.right_bottom.y)
        end
      end
    end
    if fast.mid and fast.mid.manual and fast.loco.valid and fast.loco.surface == fast.fa
      and remote.call("bte-stargate-test", "rail_transfers") == 0 then
      fast.loco.train.speed = fast.mid.manual
    end
    if fast.mid and not fast.mid_closed and (fast.mid.near and fast.loco.valid and fast.loco.surface == fast.fa and fast.loco.position.y < fast.mid.near
      or fast.mid.at == 0 and remote.call("bte-stargate-test", "rail_transfers") > 0
      or fast.mid.at > 0 and fast.fb.count_entities_filtered({type = {"locomotive", "cargo-wagon"}}) >= fast.mid.at) then
      for _, gate in pairs(fast.mid.gates) do
        remote.call("bte-stargate-test", "set_enabled", fast[gate].unit_number, false)
      end
      fast.mid_closed = true
    end
    for _, loco in pairs(fast.fb.find_entities_filtered({type = "locomotive"})) do
      fast.top = math.max(fast.top, math.abs(loco.train.speed))
      fast.first = fast.first or math.abs(loco.train.speed)
      if remote.call("bte-stargate-test", "rail_transfers") > 0 then
        fast.auto = fast.auto or not loco.train.manual_mode
      end
    end
  end
  local chain = storage.chain
  if chain and not chain.loco then
    chain_train(chain)
  end
  if chain and chain.loco then
    local running = remote.call("bte-stargate-test", "rail_transfers")
    chain.both = math.max(chain.both or 0, running)
    if running == 0 and chain.loco.valid and chain.loco.surface == chain.surfaces[1] then
      chain.entry = math.abs(chain.loco.train.speed)
    end
    -- The most the part still going in gains in a tick, once its locomotive is out.
    if chain.case.approach and running > 0 and not (chain.loco.valid and chain.loco.surface == chain.surfaces[1]) then
      local rest = chain.rest.valid and chain.rest.surface == chain.surfaces[1] and chain.rest
      local speed = rest and rest.train and math.abs(rest.train.speed)
      if speed and chain.rest_speed then
        chain.gain = math.max(chain.gain or 0, speed - chain.rest_speed)
      end
      chain.rest_speed = speed
    end
    -- A train driven by hand: held at speed towards the first gate, as by a player, until it is taken.
    if chain.case.manual and running == 0 and chain.loco.valid and chain.loco.surface == chain.surfaces[1] then
      chain.loco.train.speed = 0.5
    end
  end
  local loop = storage.loop
  if loop then
    local running = remote.call("bte-stargate-test", "rail_transfers")
    if running > 0 and loop.last == 0 then
      loop.transfers = loop.transfers + 1
    end
    loop.last = running
    -- A train standing on B's lane at the ring, with nothing going through.
    if running == 0 and loop.transfers == 1 then
      for _, car in pairs(loop.lb.find_entities_filtered({type = "locomotive", area = {{0, -6}, {2, 12}}})) do
        if car.train.speed == 0 then
          loop.stood = loop.stood + 1
          break
        end
      end
    end
  end
  local watch = storage.rail_watch
  if watch then
    for _, car in pairs(storage.ra.find_entities_filtered({type = {"locomotive", "cargo-wagon", "fluid-wagon"}, area = {{2, -10}, {4, 80}}})) do
      watch.deepest = math.min(watch.deepest, car.bounding_box.left_top.y)
    end
    watch.splashes = math.max(watch.splashes or 0, drawn("bte-stargate-splash"))
    if not watch.first_arrival_rear then
      local arrived = storage.rb.find_entities_filtered({type = {"locomotive", "cargo-wagon", "fluid-wagon"}, area = {{2, -10}, {4, 80}}})[1]
      watch.first_arrival_rear = arrived and arrived.bounding_box.right_bottom.y
    end
  end
  local share = storage.share
  if share then
    local got = 0
    for _, gate in pairs(share.gates) do
      got = got + remote.call("bte-stargate-test", "take_charge", gate.unit_number)
    end
    if game.tick - share.start > SHARE_TICKS / 3 then
      local fed = share.load.energy / share.load.electric_buffer_size
      share.fed, share.got, share.n = share.fed + fed, share.got + got, share.n + 1
      share.lost = (share.lost or 0) + (1 - fed) * SHARE.load / 60
    end
  end
  local direct = storage.direct
  -- Up to a second can pass before the check finds the shortage; the factory is judged from then on,
  -- including the few ticks the adaptive request takes to back off.
  if direct and direct.cut and not remote.call("bte-stargate-test", "bank", direct.gates[1].unit_number).direct
    and not remote.call("bte-stargate-test", "bank", direct.gates[2].unit_number).direct then
    direct.fed = direct.fed + direct.load.energy / direct.load.electric_buffer_size
    direct.n = direct.n + 1
  end
  for _, entity in pairs(surface().find_entities_filtered({name = ASSEMBLING})) do
    storage.stages_seen = storage.stages_seen or {}
    storage.stages_seen[entity.graphics_variation] = true
  end
  storage.step = storage.step or 1
  storage.next_tick = storage.next_tick or game.tick + steps[1][1]
  local step = steps[storage.step]
  if step and game.tick >= storage.next_tick then
    storage.phase = "step " .. storage.step
    step[2]()
    storage.step = storage.step + 1
    local following = steps[storage.step]
    storage.next_tick = game.tick + (following and following[1] or 0)
  end
end)
