-- Verifies the Tachyon Science Boost: once Practical Warp Drive is researched, each idle drive's
-- powered detector adds its share of tachyon density times delivered power relative to 1 GW, up
-- to 100% of every laboratory's ordinary rate, and the boosts of several drives add up.
--
-- Two drives sit almost at the Shattered Planet, where density is close to its maximum, each on
-- a platform with a controlled power source: 2 GW first, so each detector's initial 1 GW request
-- is met at once, then none for the baseline window, then 200 MW, which the adaptive detectors
-- climb to in 10 MW steps from zero. The measured laboratories are on Nauvis only. With
-- bte-warp-drive-space-science-test the platforms select the local research branch, which before
-- Practical research would leave Nauvis unaccelerated; the boost must reach it regardless. Each
-- window spans the same two research updates.
local Research = require("__bte-warp-drive__/scripts/research")

local TECHNOLOGY = "bte-practical-warp-drive"
local ROUTE = "solar-system-edge-shattered-planet"
local DEEP_DISTANCE = 0.999
local BASELINE_TICK = 190
local REFERENCE_POWER_TICK = 430
local FULL_WATTS = 2e9
local REFERENCE_WATTS = 2e8
local LAB_COUNT = 3
local DRIVE_COUNT = 2

local function fail(message)
  error("WARP_TEST_FAIL: " .. message)
end

local function research_prerequisites(technology)
  for _, prerequisite in pairs(technology.prerequisites) do
    if not prerequisite.researched then
      research_prerequisites(prerequisite)
      prerequisite.researched = true
    end
  end
end

-- The first available technology, by name, with enough units to outlast the test and packs an
-- ordinary laboratory accepts.
local function pick_technology(force)
  local lab_inputs = {}
  for _, name in pairs(prototypes.entity["lab"].lab_inputs) do
    lab_inputs[name] = true
  end
  local names = {}
  for name in pairs(force.technologies) do
    names[#names + 1] = name
  end
  table.sort(names)
  for _, name in ipairs(names) do
    local technology = force.technologies[name]
    local usable = technology.enabled and not technology.researched
      and not technology.prototype.research_trigger
      and technology.research_unit_count >= 100
      and #technology.research_unit_ingredients > 0
    for _, prerequisite in pairs(usable and technology.prerequisites or {}) do
      usable = usable and prerequisite.researched
    end
    for _, ingredient in pairs(usable and technology.research_unit_ingredients or {}) do
      usable = usable and lab_inputs[ingredient.name] == true
    end
    if usable then
      return technology
    end
  end
  fail("no technology is available to boost")
end

local function set_platform_power(watts)
  for _, source in pairs(storage.platform_sources) do
    source.power_production = watts / 60
    source.output_flow_limit = watts / 60
    source.electric_buffer_size = math.max(1, watts / 60)
  end
end

local function build_platform(force, index)
  local platform = force.create_space_platform({
    name = "Warp boost test " .. index,
    planet = "nauvis",
    starter_pack = "space-platform-starter-pack"
  })
  platform.apply_starter_pack()
  local platform_tiles = {}
  for x = -16, 16 do
    for y = -16, 16 do
      platform_tiles[#platform_tiles + 1] = {name = "space-platform-foundation", position = {x, y}}
    end
  end
  platform.surface.set_tiles(platform_tiles)
  local drive = platform.surface.create_entity({
    name = "bte-warp-drive-controller",
    position = {0.5, 10.5},
    force = force,
    raise_built = true
  })
  local source = platform.surface.create_entity({
    name = "electric-energy-interface",
    position = {0, 0},
    force = force
  })
  platform.surface.create_entity({name = "substation", position = {6, 4}, force = force})
  if not drive or not source then
    fail("could not build boost test platform " .. index)
  end
  source.input_flow_limit = 0
  source.energy = 0
  platform.space_connection = ROUTE
  return platform, source
end

script.on_init(function()
  local force = game.forces.player
  local practical = force.technologies[TECHNOLOGY]
  research_prerequisites(practical)
  practical.researched = true
  local technology = pick_technology(force)
  force.research_queue = {technology.name}
  if not force.current_research or force.current_research.name ~= technology.name then
    fail("could not select " .. technology.name .. " as the active research")
  end

  local nauvis = game.surfaces.nauvis
  local tiles = {}
  for x = 16, 56 do
    for y = 16, 40 do
      tiles[#tiles + 1] = {name = "grass-1", position = {x, y}}
    end
  end
  nauvis.set_tiles(tiles)
  for _, entity in pairs(nauvis.find_entities_filtered({area = {{16, 16}, {56, 40}}})) do
    if entity.valid and entity.type ~= "character" then
      entity.destroy()
    end
  end
  local source = nauvis.create_entity({name = "electric-energy-interface", position = {20, 20}, force = force})
  source.power_production = 1e9 / 60
  for index = 1, LAB_COUNT do
    local x = 24 + index * 6
    nauvis.create_entity({name = "substation", position = {x, 24}, force = force})
    local lab = nauvis.create_entity({name = "lab", position = {x, 28}, force = force})
    for _, ingredient in pairs(technology.research_unit_ingredients) do
      lab.insert({name = ingredient.name, count = 200})
    end
  end
  nauvis.create_entity({name = "substation", position = {22, 22}, force = force})

  storage.platforms = {}
  storage.platform_sources = {}
  for index = 1, DRIVE_COUNT do
    storage.platforms[index], storage.platform_sources[index] = build_platform(force, index)
  end
  storage.technology = technology.name
  storage.samples = {}
  set_platform_power(FULL_WATTS)
end)

-- Platform physics would carry the platform to its destination, where the density collapses;
-- pin it in place, and keep the field's asteroids off the undefended platform.
script.on_event(defines.events.on_tick, function()
  for _, platform in pairs(storage.platforms) do
    platform.paused = false
    platform.speed = 1
    platform.distance = DEEP_DISTANCE
    for _, entity in pairs(platform.surface.find_entities_filtered({
      type = {"asteroid", "solar-panel", "accumulator"}
    })) do
      entity.destroy()
    end
  end
end)

script.on_nth_tick(10, function()
  local force = game.forces.player
  local samples = storage.samples
  if force.current_research == nil or force.current_research.name ~= storage.technology then
    fail("the boosted research stopped being active")
  end
  if game.tick == BASELINE_TICK then
    set_platform_power(0)
  elseif game.tick == REFERENCE_POWER_TICK then
    set_platform_power(REFERENCE_WATTS)
  elseif game.tick == 60 then
    samples.full0 = force.research_progress
  elseif game.tick == 180 then
    samples.full1 = force.research_progress
  elseif game.tick == 300 then
    samples.base0 = force.research_progress
  elseif game.tick == 420 then
    samples.base1 = force.research_progress
  elseif game.tick == 720 then
    samples.reference0 = force.research_progress
  elseif game.tick == 840 then
    local baseline = samples.base1 - samples.base0
    if baseline <= 0 then
      fail("ordinary laboratory research did not advance during the unpowered window")
    end
    local share = Research.tachyon_density(storage.platforms[1]) / 10000
    local full = (samples.full1 - samples.full0) / baseline
    local reference = (force.research_progress - samples.reference0) / baseline
    local detail = string.format("density share=%.4f full=%.4fx reference=%.4fx", share, full,
      reference)
    if share < 0.95 then
      fail("the test platform was not near maximum tachyon density: " .. detail)
    end
    if math.abs(full - (1 + DRIVE_COUNT * share)) > 0.05 * DRIVE_COUNT then
      fail(DRIVE_COUNT .. " drives at 1 GW did not each add their density share: " .. detail)
    end
    if reference < 1 + 0.15 * DRIVE_COUNT * share or reference > 1 + 0.21 * DRIVE_COUNT * share then
      fail(DRIVE_COUNT .. " drives at 200 MW did not each add a fifth of their density share: "
        .. detail)
    end
    log("WARP_TEST_PASS: Tachyon Science Boost from " .. DRIVE_COUNT .. " drives reached "
      .. string.format("%.3f", full) .. "x at 1 GW and " .. string.format("%.3f", reference)
      .. "x at 200 MW (" .. (script.active_mods["bte-warp-drive-space-science-test"]
        and "local" or "relay") .. " branch)")
  end
end)
