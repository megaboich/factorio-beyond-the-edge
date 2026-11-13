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
-- The build lasts 240 ticks (helper data-final-fixes.lua) over three pictures, switching at 80 and 160.
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
    expect("progress bar drawn", #rendering.get_all_objects("bte-stargate"), 2)
  end},

  {110, function()
    local assembling = entities(ASSEMBLING)
    expect("still under construction", #assembling, 1)
    expect("second phase picture", assembling[1].graphics_variation, 2)
    expect("no gate yet", #entities(GATE), 0)
  end},

  {80, function()
    local assembling = entities(ASSEMBLING)
    expect("still under construction", #assembling, 1)
    expect("third phase picture", assembling[1].graphics_variation, 3)
    expect("still no gate", #entities(GATE), 0)
  end},

  {80, function()
    expect("construction is over", #entities(ASSEMBLING), 0)
    local gates = entities(GATE)
    expect("one gate stands", #gates, 1)
    expect("gate position", gates[1].position.x .. "," .. gates[1].position.y, "0,0")
    expect("gate cannot be mined", gates[1].prototype.mineable_properties.minable, false)
    expect("health fraction carries over", math.abs(gates[1].get_health_ratio() - 0.5) < 0.01, true)
    expect("progress bar removed", #rendering.get_all_objects("bte-stargate"), 0)
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
    log("STARGATE_TEST_PASS: filters, exact slots, completion, staged build, replacement, grid snapping, and mining paths completed")
  end}
}

script.on_event(defines.events.on_tick, function()
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
