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

-- The bill's bulk materials in slot order, each a whole number of stacks: slots 1-32, then the spare 33.
local BILL = {
  {"tungsten-plate", 1000, 1, 20}, {"superconductor", 200, 21, 21}, {"low-density-structure", 200, 22, 25},
  {"refined-concrete", 200, 26, 27}, {"steel-plate", 200, 28, 29}, {"tungsten-carbide", 100, 30, 31},
  {"advanced-circuit", 200, 32, 32}
}
local TIMED = BILL[#BILL]

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
    expect("slots (32 for the bill, 1 spare)", #inventory, 33)
    for _, material in pairs(BILL) do
      expect(material[1] .. " first slot filter", inventory.get_filter(material[3]).name, material[1])
      expect(material[1] .. " last slot filter", inventory.get_filter(material[4]).name, material[1])
    end
    expect("the spare slot is unfiltered", inventory.get_filter(33), nil)
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
    expect("a two-track station draws its track", #tracks == 1 and tracks[1].graphics_variation, 2)
    local body = ra.find_entities_filtered({name = "bte-stargate-body", area = {{-8, -8}, {10, 10}}})[1]
    expect("its body has the track cut out (two tracks, red while charging)", body.graphics_variation, 6)
    expect("and three hidden behind the ring", #ra.find_entities_filtered({name = "bte-stargate-rail-hidden"}), 6)
    local station = remote.call("bte-stargate-test", "station", g1.unit_number)
    expect("the station is named after the gate", station.backer_name, remote.call("bte-stargate-test", "state", g1.unit_number).name)
    expect("the station stands on the departure lane at the gate's edge", station.connected_rail and serpent.line(station.connected_rail.position), "{x = 3, y = 7}")
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
    expect("and its station moves to the edge", station.connected_rail and station.connected_rail.position.y, 7)
    local waiting = storage.ra.find_entities_filtered({name = "locomotive", area = {{2, 0}, {4, 80}}})[1]
    expect("a train waits at the station while the gate is off", waiting and waiting.train.state, defines.train_state.wait_station)
    expect("with its front at the gate's edge (" .. tostring(waiting and waiting.bounding_box.left_top.y) .. ")",
      waiting and math.abs(waiting.bounding_box.left_top.y - 7.4) < 0.2, true)
    remote.call("bte-stargate-test", "set_enabled", storage.g1.unit_number, true)
    expect("a station gate with a train on its rails keeps its mode", remote.call("bte-stargate-test", "set_station", storage.g1.unit_number, nil), false)
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
