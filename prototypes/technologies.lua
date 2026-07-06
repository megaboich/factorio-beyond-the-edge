local function recipe_exists(name)
  return data.raw.recipe and data.raw.recipe[name] ~= nil
end

local function technology_exists(name)
  return data.raw.technology and data.raw.technology[name] ~= nil
end

local function science_pack(name)
  if data.raw.item and data.raw.item[name] then
    return {name, 1}
  end
  if data.raw.tool and data.raw.tool[name] then
    return {name, 1}
  end
  return nil
end

local function add_science_pack(ingredients, name)
  local pack = science_pack(name)
  if pack then
    table.insert(ingredients, pack)
  end
end

local function unlocks(recipe_names)
  local effects = {}
  for _, recipe_name in pairs(recipe_names) do
    if recipe_exists(recipe_name) then
      table.insert(effects, {type = "unlock-recipe", recipe = recipe_name})
    end
  end
  return effects
end

local function prerequisites(names)
  local result = {}
  for _, name in pairs(names) do
    if technology_exists(name) then
      table.insert(result, name)
    end
  end
  return result
end

local function add_technology(technology)
  if #technology.effects > 0 then
    data:extend({technology})
  end
end

local asteroid_science = {}
add_science_pack(asteroid_science, "automation-science-pack")
add_science_pack(asteroid_science, "logistic-science-pack")
add_science_pack(asteroid_science, "chemical-science-pack")
add_science_pack(asteroid_science, "space-science-pack")

local flurolite_science = {}
add_science_pack(flurolite_science, "automation-science-pack")
add_science_pack(flurolite_science, "logistic-science-pack")
add_science_pack(flurolite_science, "chemical-science-pack")
add_science_pack(flurolite_science, "space-science-pack")
add_science_pack(flurolite_science, "production-science-pack")

local growth_science = {}
add_science_pack(growth_science, "automation-science-pack")
add_science_pack(growth_science, "logistic-science-pack")
add_science_pack(growth_science, "chemical-science-pack")
add_science_pack(growth_science, "space-science-pack")
add_science_pack(growth_science, "agricultural-science-pack")

add_technology({
  type = "technology",
  name = "spacelab-asteroid-stone-processing",
  icon = "__spacelab__/graphics/icons/flurolite.png",
  icon_size = 64,
  prerequisites = prerequisites({"space-platform"}),
  effects = unlocks({
    "spacelab-metallic-asteroid-crushing-stone-focused",
    "spacelab-carbonic-asteroid-crushing-stone-focused",
    "spacelab-oxide-asteroid-crushing-stone-focused",
    "spacelab-ammonia-extraction"
  }),
  unit = {
    count = 250,
    time = 30,
    ingredients = asteroid_science
  },
  order = "z-spacelab-a"
})

add_technology({
  type = "technology",
  name = "spacelab-flurolite-processing",
  icon = "__spacelab__/graphics/icons/flurolite.png",
  icon_size = 64,
  prerequisites = prerequisites({"spacelab-asteroid-stone-processing", "production-science-pack"}),
  effects = unlocks({
    "spacelab-metallic-asteroid-crushing-flurolite-focused",
    "spacelab-carbonic-asteroid-crushing-flurolite-focused",
    "spacelab-oxide-asteroid-crushing-flurolite-focused",
    "spacelab-shattered-synthesis",
    "spacelab-lithium-focused-condensation",
    "spacelab-fluorine-focused-condensation"
  }),
  unit = {
    count = 500,
    time = 45,
    ingredients = flurolite_science
  },
  order = "z-spacelab-b"
})

add_technology({
  type = "technology",
  name = "spacelab-growth-facility",
  icon = "__spacelab__/graphics/technology/growth-facility.png",
  icon_size = 128,
  prerequisites = prerequisites({"spacelab-flurolite-processing", "agricultural-science-pack"}),
  effects = unlocks({
    "spacelab-growth-facility",
    "spacelab-yumako-cultivation",
    "spacelab-jellynut-cultivation",
    "spacelab-biter-egg-incubation",
    "spacelab-pentapod-egg-incubation"
  }),
  unit = {
    count = 750,
    time = 60,
    ingredients = growth_science
  },
  order = "z-spacelab-c"
})
