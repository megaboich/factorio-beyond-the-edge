-- Verifies which laboratories receive the tachyon research bonus.
--
-- The mod under test never looks for a mod by name; it asks whether every science pack
-- Practical Warp Drive requires can be crafted on a space platform. This test flips that
-- capability with warp-drive-space-science-test, which strips the four vanilla planetary
-- surface conditions, and asserts the resulting routing from observable research progress
-- alone rather than by reading Warp Drive's internal state.
--
-- Laboratories exist only on Nauvis until tick 300, so the two branches are distinguished
-- by whether powering the detector accelerates them at all.
local EXPECT_LOCAL = script.active_mods["warp-drive-space-science-test"] ~= nil
local TECHNOLOGY = "practical-warp-drive"
-- Signal strength follows orbital distance from the star. Just outside the Solar system
-- edge is worth about 640 particles/s after 345,000 km of travel; almost at the Shattered
-- Planet, on the same connection, is near the 10000 particles/s density ceiling. Platform
-- speed multiplies both branches without a cap. Near and far windows use the 200 MW
-- reference power; the test's final 200 km/s window raises power to 1 GW and must gain the
-- expected 5x power factor as well as the speed increase.
-- The bands are wide enough to survive balance tweaks but
-- narrow enough to fail on an order-of-magnitude formula error, which is what a wrong
-- research_unit_energy conversion looks like.
local NEAR_MINIMUM = 900
local NEAR_MAXIMUM = 1200
local FAR_MINIMUM = 14000
local FAR_MAXIMUM = 18000
local OUTWARD_GAIN_MINIMUM = 5
local FAST_MINIMUM = 120000
local SPEED_POWER_GAIN_MINIMUM = 9
local SPEED_POWER_GAIN_MAXIMUM = 9.75
local UNBOOSTED_MAXIMUM = 1.5
local LAB_COUNT = 3
local ROUTE = "solar-system-edge-shattered-planet"

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

local function required_packs()
  local packs = {}
  for _, ingredient in pairs(prototypes.technology[TECHNOLOGY].research_unit_ingredients) do
    packs[#packs + 1] = ingredient.name
  end
  if #packs == 0 then
    fail("Practical Warp Drive declares no research unit ingredients")
  end
  return packs
end

-- A substation is placed beside every lab and beside the power source. Substations reach
-- 18 tiles, so the cluster forms one electric network without depending on exact spacing.
local LAB_OFFSETS = {{-6, -6}, {-6, 6}, {6, 6}, {0, -8}, {8, 0}}

local function build_substation(surface, force, position)
  local place = surface.find_non_colliding_position("substation", position, 20, 1)
  local pole = place and surface.create_entity({name = "substation", position = place, force = force})
  if not pole then
    fail("substation creation returned nil")
  end
  pole.destructible = false
end

local function build_power(surface, force, center)
  local place = surface.find_non_colliding_position(
    "electric-energy-interface", {center.x, center.y}, 20, 1)
  local source = place and surface.create_entity({
    name = "electric-energy-interface",
    position = place,
    force = force
  })
  if not source then
    fail("power source creation returned nil")
  end
  source.destructible = false
  build_substation(surface, force, {place.x + 3, place.y})
end

local function build_labs(surface, force, center, count)
  local packs = required_packs()
  local labs = {}
  for index = 1, count do
    local offset = LAB_OFFSETS[index]
    local place = surface.find_non_colliding_position(
      "lab", {center.x + offset[1], center.y + offset[2]}, 20, 1)
    local lab = place and surface.create_entity({name = "lab", position = place, force = force})
    if not lab then
      fail("lab creation returned nil")
    end
    for _, pack in pairs(packs) do
      lab.insert({name = pack, count = 200})
    end
    lab.destructible = false
    build_substation(surface, force, {lab.position.x + 3, lab.position.y})
    labs[#labs + 1] = lab
  end
  return labs
end

local function working_labs(surface, force)
  local count = 0
  for _, lab in pairs(surface.find_entities_filtered({type = "lab", force = force})) do
    if lab.status == defines.entity_status.working then
      count = count + 1
    end
  end
  return count
end

script.on_init(function()
  local force = game.forces.player
  local technology = force.technologies[TECHNOLOGY]
  if not technology then
    fail("Practical Warp Drive technology is missing")
  end
  research_prerequisites(technology)
  force.research_queue = {TECHNOLOGY}
  if not force.current_research or force.current_research.name ~= TECHNOLOGY then
    fail("could not select Practical Warp Drive as the active research")
  end

  local nauvis = game.surfaces.nauvis
  local area = {{16, 16}, {56, 40}}
  local tiles = {}
  for x = 16, 56 do
    for y = 16, 40 do
      tiles[#tiles + 1] = {name = "grass-1", position = {x, y}}
    end
  end
  nauvis.set_tiles(tiles)
  for _, entity in pairs(nauvis.find_entities_filtered({area = area})) do
    if entity.valid and entity.type ~= "character" then
      entity.destroy()
    end
  end
  build_power(nauvis, force, {x = 30, y = 28})
  build_labs(nauvis, force, {x = 30, y = 28}, LAB_COUNT)

  local platform = force.create_space_platform({
    name = "Warp branch test",
    planet = "nauvis",
    starter_pack = "space-platform-starter-pack"
  })
  if not platform then
    fail("platform creation returned nil")
  end
  platform.apply_starter_pack()
  local platform_tiles = {}
  for x = -14, 14 do
    for y = -14, 14 do
      platform_tiles[#platform_tiles + 1] = {name = "space-platform-foundation", position = {x, y}}
    end
  end
  platform.surface.set_tiles(platform_tiles)

  local drive = platform.surface.create_entity({
    name = "warp-drive-controller",
    position = {0, 10},
    force = force,
    raise_built = true
  })
  if not drive then
    fail("drive creation returned nil")
  end
  drive.destructible = false
  if platform.hub and platform.hub.valid then
    platform.hub.destructible = false
  end

  platform.space_connection = ROUTE
  platform.distance = 0.5
  platform.speed = 1
  platform.paused = false

  storage.platform = platform
  storage.drive = drive
  storage.samples = {}
end)

script.on_nth_tick(10, function()
  local platform = storage.platform
  local drive = storage.drive
  local force = game.forces.player
  local nauvis = game.surfaces.nauvis
  if not platform or not platform.valid or not drive or not drive.valid then
    fail(string.format("test objects became invalid at tick %d: platform=%s drive=%s",
      game.tick, tostring(platform and platform.valid), tostring(drive and drive.valid)))
  end
  if game.tick == 60 then
    if force.current_research == nil or force.current_research.name ~= TECHNOLOGY then
      fail("Practical Warp Drive stopped being the active research")
    end
    local count = working_labs(nauvis, force)
    if count ~= LAB_COUNT then
      fail(string.format("expected %d working Nauvis laboratories, got %d", LAB_COUNT, count))
    end
    storage.samples.p0 = force.research_progress
  elseif game.tick == 180 then
    storage.samples.p1 = force.research_progress
  elseif game.tick == 300 then
    storage.samples.p2 = force.research_progress
    -- Only the local branch needs laboratories on the platform. Leaving the relay run with
    -- Nauvis laboratories alone keeps every measured window built from the same lab count,
    -- so a window divided by the baseline is directly comparable between the two branches.
    if EXPECT_LOCAL then
      build_power(platform.surface, force, {x = -9, y = -9})
      build_labs(platform.surface, force, {x = -9, y = -9}, LAB_COUNT)
    end
  elseif game.tick == 310 and EXPECT_LOCAL then
    local count = working_labs(platform.surface, force)
    if count ~= LAB_COUNT then
      fail(string.format("expected %d working platform laboratories, got %d", LAB_COUNT, count))
    end
  elseif game.tick == 420 then
    -- The helper moves the platform out to the far end of the same connection right after
    -- this sample, so anything the next window gains is attributable to depth alone.
    storage.samples.p3 = force.research_progress
  elseif game.tick == 540 then
    storage.samples.p4 = force.research_progress
  elseif game.tick == 660 then
    local samples = storage.samples
    local baseline = samples.p1 - samples.p0
    if baseline <= 0 then
      fail("ordinary laboratory research did not advance during the unpowered window")
    end
    -- Every window is the same length and every lab is identical, so a window divided by
    -- the unpowered baseline is the effective research multiplier in lab-seconds. Checking
    -- that absolute number, not merely "faster", is what catches a wrong unit conversion.
    local near = (EXPECT_LOCAL and (samples.p3 - samples.p2) or (samples.p2 - samples.p1)) / baseline
    local far = (samples.p4 - samples.p3) / baseline
    local fast = (force.research_progress - samples.p4) / baseline
    local detail = string.format("baseline=%.12g near=%.4gx far=%.4gx fast=%.4gx",
      baseline, near, far, fast)
    local function check(name, value, minimum, maximum)
      if value < minimum or value > maximum then
        fail(string.format("%s multiplier was %.4gx, expected %g to %g: %s",
          name, value, minimum, maximum, detail))
      end
    end
    if EXPECT_LOCAL then
      local off_platform = (samples.p2 - samples.p1) / baseline
      if off_platform > UNBOOSTED_MAXIMUM then
        fail(string.format(
          "local branch accelerated laboratories off the drive's platform by %.4gx: %s",
          off_platform, detail))
      end
    end
    check("near", near, NEAR_MINIMUM, NEAR_MAXIMUM)
    check("far", far, FAR_MINIMUM, FAR_MAXIMUM)
    if fast < FAST_MINIMUM then
      fail(string.format("200 km/s and 1 GW signal did not exceed 120000x: %s", detail))
    end
    if far < near * OUTWARD_GAIN_MINIMUM then
      fail(string.format(
        "travelling further out did not strengthen the signal by at least %gx: %s",
        OUTWARD_GAIN_MINIMUM, detail))
    end
    local speed_power_gain = fast / far
    if speed_power_gain < SPEED_POWER_GAIN_MINIMUM or speed_power_gain > SPEED_POWER_GAIN_MAXIMUM then
      fail(string.format(
        "raising speed from 60 to 200 km/s and power from 200 MW to 1 GW changed the signal by %.4gx, expected %g to %g: %s",
        speed_power_gain, SPEED_POWER_GAIN_MINIMUM, SPEED_POWER_GAIN_MAXIMUM, detail))
    end
    if EXPECT_LOCAL then
      log("WARP_TEST_PASS: local research branch accelerated platform laboratories only")
    else
      log("WARP_TEST_PASS: relay research branch accelerated force-wide laboratories")
    end
  end
end)
