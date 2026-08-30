-- Pins down the Factorio API and vanilla prototype facts that control.lua silently depends
-- on. None of these are stated plainly in the runtime documentation, every one of them was
-- established by measurement, and each has already produced a real bug in this mod:
--
--   * research_unit_energy is in ticks, not milliticks. Reading it as milliticks inflated
--     the research bonus by exactly 1000x.
--   * platform.distance is a 0..1 fraction of the connection, not kilometres. The location
--     curve indexes into it directly.
--   * space location prototypes expose an orbital distance, which is what orders the
--     tachyon signal from the inner system out to the Shattered Planet.
--   * recycling recipes return the item they consume, so a naive "is this item craftable
--     in space" scan reports every science pack as craftable and the research branch
--     always resolves to local.
--   * LuaForce.current_research is read only; the research queue is the writable path.
--
-- If a Factorio update changes any of these, this test fails with a precise message rather
-- than the mod quietly misbehaving.
local TECHNOLOGY = "practical-warp-drive"
-- prototypes/technologies.lua declares unit.time = 120 for this technology.
local DECLARED_UNIT_TIME = 120
local CRAFTING_MACHINE_TYPES = {
  ["assembling-machine"] = true,
  ["furnace"] = true,
  ["rocket-silo"] = true
}
local PLANETARY_PACK_RECIPES = {
  "metallurgic-science-pack",
  "agricultural-science-pack",
  "electromagnetic-science-pack",
  "cryogenic-science-pack"
}
local ORBITAL_ORDER = {"nauvis", "aquilo", "solar-system-edge", "shattered-planet"}
local ROUTE = "nauvis-vulcanus"
local WARP_SOUNDS = {
  "warp-drive-command",
  "warp-drive-activation",
  "warp-drive-deactivation",
  "warp-drive-background-01",
  "warp-drive-background-02"
}

for index = 1, 20 do
  WARP_SOUNDS[#WARP_SOUNDS + 1] = string.format("warp-drive-buzz-%02d", index)
  WARP_SOUNDS[#WARP_SOUNDS + 1] = string.format(
    "warp-drive-failed-activation-%02d", index)
end

local function fail(message)
  error("WARP_TEST_FAIL: " .. message)
end

local function check_research_unit_energy()
  local technology = prototypes.technology[TECHNOLOGY]
  if not technology then
    fail("technology " .. TECHNOLOGY .. " is missing")
  end
  local expected = DECLARED_UNIT_TIME * 60
  if technology.research_unit_energy ~= expected then
    fail(string.format(
      "research_unit_energy is %s, expected %s ticks for unit.time = %d. "
        .. "The seconds conversion in control.lua divides by 60 and is now wrong.",
      technology.research_unit_energy, expected, DECLARED_UNIT_TIME))
  end
end

local function check_orbital_distances()
  local previous
  for _, name in pairs(ORBITAL_ORDER) do
    local location = prototypes.space_location[name]
    if not location then
      fail("space location " .. name .. " is missing")
    end
    if type(location.distance) ~= "number" then
      fail("space location " .. name .. " has no numeric orbital distance")
    end
    if previous and location.distance <= previous.distance then
      fail(string.format(
        "%s orbits at %s, which is not further out than %s at %s. "
          .. "The tachyon location curve assumes orbital distance increases outward.",
        name, location.distance, previous.name, previous.distance))
    end
    previous = location
  end
  local deepest
  for _, location in pairs(prototypes.space_location) do
    if location.distance and (not deepest or location.distance > deepest.distance) then
      deepest = location
    end
  end
  if not deepest or deepest.name ~= "shattered-planet" then
    fail("the deepest space location is " .. (deepest and deepest.name or "nil")
      .. ", expected shattered-planet")
  end
end

-- The signal scale is driven by connection lengths in kilometres, so it breaks silently
-- if a connection ever reports a zero length or if the deepest destination is not
-- reachable from the home system. It also breaks if length and the starmap radius ever
-- become proportional, because then the radius would have been the right field all along.
local function check_connection_lengths()
  local neighbours = {}
  for name, connection in pairs(prototypes.space_connection) do
    if not connection.length or connection.length <= 0 then
      error("WARP_TEST_FAIL: space connection " .. name .. " has no positive length")
    end
    neighbours[connection.from.name] = neighbours[connection.from.name] or {}
    neighbours[connection.to.name] = neighbours[connection.to.name] or {}
    table.insert(neighbours[connection.from.name], connection.to.name)
    table.insert(neighbours[connection.to.name], connection.from.name)
  end
  local seen = {nauvis = true}
  local frontier = {"nauvis"}
  while #frontier > 0 do
    local name = table.remove(frontier)
    for _, next_name in pairs(neighbours[name] or {}) do
      if not seen[next_name] then
        seen[next_name] = true
        table.insert(frontier, next_name)
      end
    end
  end
  if not seen["shattered-planet"] then
    error("WARP_TEST_FAIL: shattered-planet is not reachable from nauvis through space connections")
  end
  local edge = prototypes.space_connection["solar-system-edge-shattered-planet"]
  local inner = prototypes.space_connection["nauvis-vulcanus"]
  if edge.length <= inner.length * 100 then
    error("WARP_TEST_FAIL: the final run is no longer far longer than an inner hop, so the "
      .. "logarithmic travel scale needs rechecking")
  end
end

local function check_recycling_returns_its_input()
  local recipe = prototypes.recipe["agricultural-science-pack-recycling"]
  if not recipe then
    fail("agricultural-science-pack-recycling is missing")
  end
  local consumes, produces = false, false
  for _, ingredient in pairs(recipe.ingredients) do
    if ingredient.name == "agricultural-science-pack" then
      consumes = true
    end
  end
  for _, product in pairs(recipe.products) do
    if product.name == "agricultural-science-pack" then
      produces = true
    end
  end
  if not (consumes and produces) then
    fail("agricultural-science-pack-recycling no longer both consumes and produces its "
      .. "pack, so the self-returning recipe filter in compute_research_branch may now be "
      .. "hiding a genuine production route")
  end
end

local function check_planetary_pack_recipes()
  for _, name in pairs(PLANETARY_PACK_RECIPES) do
    local recipe = prototypes.recipe[name]
    if not recipe then
      fail("recipe " .. name .. " is missing")
    end
    if not recipe.surface_conditions or #recipe.surface_conditions == 0 then
      fail("recipe " .. name .. " has no surface conditions, so vanilla no longer forces "
        .. "the relay research branch and the branch test fixture is meaningless")
    end
  end
end

-- control.lua only inspects assembling machines, furnaces and rocket silos when deciding
-- which recipe categories a platform can run. If a science pack ever needs a category that
-- only some other machine type provides, that check would silently under-report.
local function check_crafting_machine_coverage()
  local provided = {}
  for _, machine in pairs(prototypes.entity) do
    if CRAFTING_MACHINE_TYPES[machine.type] then
      for category in pairs(machine.crafting_categories or {}) do
        provided[category] = true
      end
    end
  end
  for _, ingredient in pairs(prototypes.technology[TECHNOLOGY].research_unit_ingredients) do
    for _, recipe in pairs(prototypes.recipe) do
      local consumes = false
      for _, item in pairs(recipe.ingredients) do
        if item.name == ingredient.name then
          consumes = true
        end
      end
      if not consumes then
        for _, product in pairs(recipe.products) do
          if product.name == ingredient.name then
            for _, category in pairs(recipe.categories) do
              if not provided[category] then
                fail(string.format(
                  "recipe %s produces %s in category %s, which no assembling machine, "
                    .. "furnace or rocket silo provides",
                  recipe.name, ingredient.name, category))
              end
            end
          end
        end
      end
    end
  end
end

local function check_lab_accepts_every_pack()
  local inputs = {}
  for _, pack in pairs(prototypes.entity["lab"].lab_inputs or {}) do
    inputs[pack] = true
  end
  for _, ingredient in pairs(prototypes.technology[TECHNOLOGY].research_unit_ingredients) do
    if not inputs[ingredient.name] then
      fail("the vanilla lab does not accept " .. ingredient.name
        .. ", so laboratories cannot research Practical Warp Drive at all")
    end
  end
end

local function check_research_queue_is_the_writable_path()
  local force = game.forces.player
  local ok = pcall(function()
    force.current_research = TECHNOLOGY
  end)
  if ok then
    fail("LuaForce.current_research became writable; the tests and control.lua can stop "
      .. "going through the research queue")
  end
end

local function check_warp_sounds()
  for _, path in pairs(WARP_SOUNDS) do
    if not helpers.is_valid_sound_path(path) then
      fail("generated sound prototype " .. path .. " is not a valid runtime sound path")
    end
  end
end

script.on_init(function()
  check_research_unit_energy()
  check_orbital_distances()
  check_connection_lengths()
  check_recycling_returns_its_input()
  check_planetary_pack_recipes()
  check_crafting_machine_coverage()
  check_lab_accepts_every_pack()
  check_research_queue_is_the_writable_path()
  check_warp_sounds()

  local force = game.forces.player
  local platform = force.create_space_platform({
    name = "Warp API invariants",
    planet = "nauvis",
    starter_pack = "space-platform-starter-pack"
  })
  if not platform then
    fail("platform creation returned nil")
  end
  platform.apply_starter_pack()
  platform.space_connection = ROUTE
  platform.distance = 0.25
  platform.paused = false
  storage.platform = platform
  storage.samples = {}
end)

script.on_nth_tick(60, function()
  local platform = storage.platform
  if not platform or not platform.valid then
    fail("the test platform became invalid")
  end
  platform.paused = false
  -- LuaSpacePlatform.speed is kilometres per tick; 1 therefore matches 60 km/s in the UI.
  platform.speed = 1
  local connection = platform.space_connection
  local distance = platform.distance
  if not connection or not distance then
    return
  end
  if distance < 0 or distance > 1 then
    fail(string.format(
      "platform.distance is %s on a connection of length %s, so it is no longer a 0..1 "
        .. "fraction and the tachyon location curve is indexing it wrongly",
      distance, connection.length))
  end
  storage.samples[#storage.samples + 1] = distance
  if game.tick >= 300 then
    local first = storage.samples[1]
    local last = storage.samples[#storage.samples]
    if last <= first then
      fail(string.format("platform.distance did not advance while travelling: %s to %s",
        first, last))
    end
    log("WARP_TEST_PASS: research unit, orbital distance, connection length, recycling, crafting category, "
      .. "lab input, research queue, sound, and platform distance invariants hold")
  end
end)
