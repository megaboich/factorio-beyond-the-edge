local helpers = require("prototypes.helpers")

local prototype_exists = helpers.prototype_exists
local recipe_icon_layer = helpers.recipe_icon_layer
local add_recipe = helpers.add_recipe
local item = helpers.item
local fluid = helpers.fluid
local ammonia_ingredient = helpers.ammonia_ingredient
local add_optional_ingredient = helpers.add_optional_ingredient

-- The Growth Facility draws one capsule-contents overlay per growth recipe, each tinted by its own
-- recipe tint channel (spacelab/prototypes/entities.lua). A recipe turns its channel on (white)
-- and the others off (transparent), so only its own specimens show.
local on = {r = 1, g = 1, b = 1, a = 1}
local off = {r = 0, g = 0, b = 0, a = 0}
local growth_recipe_tints = {
  yumako = {primary = on, secondary = off, tertiary = off, quaternary = off},
  jellynut = {primary = off, secondary = on, tertiary = off, quaternary = off},
  biter_egg = {primary = off, secondary = off, tertiary = on, quaternary = off},
  pentapod_egg = {primary = off, secondary = off, tertiary = off, quaternary = on}
}

add_recipe({
  type = "recipe",
  name = "bte-growth-facility",
  categories = {"crafting"},
  energy_required = 10,
  ingredients = {
    item("cryogenic-plant", 1),
    item("low-density-structure", 40),
    item("pump", 4),
    item("heat-exchanger", 1),
    item("small-lamp", 100),
    item("refined-concrete", 100),
    item("overgrowth-yumako-soil", 50),
    item("overgrowth-jellynut-soil", 50)
  },
  results = {item("bte-growth-facility", 1)},
  enabled = false,
  subgroup = "bte-spacelab-buildings",
  order = "a[bte-growth-facility]",
  always_show_made_in = true
})

add_recipe({
  type = "recipe",
  name = "bte-metallic-asteroid-crushing-stone-focused",
  categories = {"crushing"},
  energy_required = 2,
  ingredients = {item("metallic-asteroid-chunk", 1)},
  results = {
    item("iron-ore", 1),
    item("copper-ore", 1),
    item("stone", 4)
  },
  icons = {
    recipe_icon_layer(item("metallic-asteroid-chunk", 1), 0.62, {0, 0}),
    recipe_icon_layer(item("iron-ore", 1), 0.28, {-11, -11}),
    recipe_icon_layer(item("copper-ore", 1), 0.28, {11, -11}),
    recipe_icon_layer(item("stone", 1), 0.28, {-11, 11})
  },
  enabled = false,
  subgroup = "bte-spacelab-asteroid-processing",
  order = "a[metallic]-a[stone]",
  allow_productivity = true,
  always_show_made_in = true
})

add_recipe({
  type = "recipe",
  name = "bte-carbonic-asteroid-crushing-stone-focused",
  categories = {"crushing"},
  energy_required = 2,
  ingredients = {item("carbonic-asteroid-chunk", 1)},
  results = {
    item("carbon", 2),
    item("stone", 4)
  },
  icons = {
    recipe_icon_layer(item("carbonic-asteroid-chunk", 1), 0.62, {0, 0}),
    recipe_icon_layer(item("carbon", 1), 0.28, {-11, -11}),
    recipe_icon_layer(item("stone", 1), 0.28, {11, -11})
  },
  enabled = false,
  subgroup = "bte-spacelab-asteroid-processing",
  order = "b[carbonic]-a[stone]",
  allow_productivity = true,
  always_show_made_in = true
})

add_recipe({
  type = "recipe",
  name = "bte-oxide-asteroid-crushing-stone-focused",
  categories = {"crushing"},
  energy_required = 2,
  ingredients = {item("oxide-asteroid-chunk", 1)},
  results = {
    item("ice", 2),
    item("stone", 4)
  },
  icons = {
    recipe_icon_layer(item("oxide-asteroid-chunk", 1), 0.62, {0, 0}),
    recipe_icon_layer(item("ice", 1), 0.28, {-11, -11}),
    recipe_icon_layer(item("stone", 1), 0.28, {11, -11})
  },
  enabled = false,
  subgroup = "bte-spacelab-asteroid-processing",
  order = "c[oxide]-a[stone]",
  allow_productivity = true,
  always_show_made_in = true
})

add_recipe({
  type = "recipe",
  name = "bte-metallic-asteroid-crushing-flurolite-focused",
  categories = {"crushing"},
  energy_required = 3,
  ingredients = {item("metallic-asteroid-chunk", 1)},
  results = {
    item("iron-ore", 1),
    item("copper-ore", 1),
    item("stone", 2),
    {type = "item", name = "bte-flurolite", amount = 1, independent_probability = 0.05},
    {type = "item", name = "uranium-ore", amount = 1, independent_probability = 0.01}
  },
  icons = {
    recipe_icon_layer(item("metallic-asteroid-chunk", 1), 0.62, {0, 0}),
    recipe_icon_layer(item("iron-ore", 1), 0.28, {-11, -11}),
    recipe_icon_layer(item("copper-ore", 1), 0.28, {11, -11}),
    recipe_icon_layer(item("stone", 1), 0.28, {-11, 11}),
    recipe_icon_layer(item("bte-flurolite", 1), 0.28, {11, 11})
  },
  enabled = false,
  subgroup = "bte-spacelab-asteroid-processing",
  order = "a[metallic]-b[flurolite]",
  allow_productivity = true,
  always_show_made_in = true
})

add_recipe({
  type = "recipe",
  name = "bte-carbonic-asteroid-crushing-flurolite-focused",
  categories = {"crushing"},
  energy_required = 3,
  ingredients = {item("carbonic-asteroid-chunk", 1)},
  results = {
    item("carbon", 2),
    item("stone", 2),
    {type = "item", name = "bte-flurolite", amount = 1, independent_probability = 0.05},
    {type = "item", name = "uranium-ore", amount = 1, independent_probability = 0.01}
  },
  icons = {
    recipe_icon_layer(item("carbonic-asteroid-chunk", 1), 0.62, {0, 0}),
    recipe_icon_layer(item("carbon", 1), 0.28, {-11, -11}),
    recipe_icon_layer(item("stone", 1), 0.28, {11, -11}),
    recipe_icon_layer(item("bte-flurolite", 1), 0.28, {-11, 11})
  },
  enabled = false,
  subgroup = "bte-spacelab-asteroid-processing",
  order = "b[carbonic]-b[flurolite]",
  allow_productivity = true,
  always_show_made_in = true
})

add_recipe({
  type = "recipe",
  name = "bte-oxide-asteroid-crushing-flurolite-focused",
  categories = {"crushing"},
  energy_required = 3,
  ingredients = {item("oxide-asteroid-chunk", 1)},
  results = {
    item("ice", 2),
    item("stone", 2),
    {type = "item", name = "bte-flurolite", amount = 1, independent_probability = 0.05},
    {type = "item", name = "uranium-ore", amount = 1, independent_probability = 0.01}
  },
  icons = {
    recipe_icon_layer(item("oxide-asteroid-chunk", 1), 0.62, {0, 0}),
    recipe_icon_layer(item("ice", 1), 0.28, {-11, -11}),
    recipe_icon_layer(item("stone", 1), 0.28, {11, -11}),
    recipe_icon_layer(item("bte-flurolite", 1), 0.28, {-11, 11})
  },
  enabled = false,
  subgroup = "bte-spacelab-asteroid-processing",
  order = "c[oxide]-b[flurolite]",
  allow_productivity = true,
  always_show_made_in = true
})

add_recipe({
  type = "recipe",
  name = "bte-shattered-synthesis",
  categories = {"crushing"},
  energy_required = 4,
  ingredients = {item("promethium-asteroid-chunk", 1)},
  results = {
    {type = "item", name = "holmium-ore", amount = 1, independent_probability = 0.2},
    item("tungsten-ore", 1),
    item("stone", 2),
    {type = "item", name = "bte-flurolite", amount = 1, independent_probability = 0.05},
    {type = "item", name = "uranium-ore", amount = 1, independent_probability = 0.03}
  },
  icons = {
    recipe_icon_layer(item("promethium-asteroid-chunk", 1), 0.62, {0, 0}),
    recipe_icon_layer(item("holmium-ore", 1), 0.28, {-11, -11}),
    recipe_icon_layer(item("tungsten-ore", 1), 0.28, {11, -11}),
    recipe_icon_layer(item("stone", 1), 0.28, {-11, 11}),
    recipe_icon_layer(item("bte-flurolite", 1), 0.28, {11, 11})
  },
  enabled = false,
  subgroup = "bte-spacelab-asteroid-processing",
  order = "d[promethium]-a[shattered-synthesis]",
  allow_productivity = true,
  always_show_made_in = true
})

local yumako_ingredients = {item("nutrients", 25), fluid("water", 500), fluid("steam", 250), item("yumako-seed", 1), item("calcite", 5), item("carbon", 10)}
add_optional_ingredient(yumako_ingredients, ammonia_ingredient(125))
add_recipe({
  type = "recipe",
  name = "bte-yumako-cultivation",
  categories = {"bte-spacelab-growth"},
  energy_required = 60,
  ingredients = yumako_ingredients,
  results = {item("yumako", 57)},
  crafting_machine_tint = growth_recipe_tints.yumako,
  preserve_products_in_machine_output = true,
  enabled = false,
  subgroup = "bte-spacelab-growth",
  order = "a[yumako]",
  allow_productivity = true,
  always_show_made_in = true
})

local jellynut_ingredients = {item("nutrients", 25), fluid("water", 500), fluid("steam", 250), item("jellynut-seed", 1), item("calcite", 5), item("carbon", 10)}
add_optional_ingredient(jellynut_ingredients, ammonia_ingredient(125))
add_recipe({
  type = "recipe",
  name = "bte-jellynut-cultivation",
  categories = {"bte-spacelab-growth"},
  energy_required = 60,
  ingredients = jellynut_ingredients,
  results = {item("jellynut", 57)},
  crafting_machine_tint = growth_recipe_tints.jellynut,
  preserve_products_in_machine_output = true,
  enabled = false,
  subgroup = "bte-spacelab-growth",
  order = "b[jellynut]",
  allow_productivity = true,
  always_show_made_in = true
})

local biter_egg_ingredients = {item("nutrients", 50), item("bioflux", 5), fluid("water", 500), fluid("steam", 250), item("biter-egg", 1), item("calcite", 5), item("carbon", 10)}
add_optional_ingredient(biter_egg_ingredients, ammonia_ingredient(125))
add_recipe({
  type = "recipe",
  name = "bte-biter-egg-incubation",
  categories = {"bte-spacelab-growth"},
  energy_required = 120,
  ingredients = biter_egg_ingredients,
  results = {item("biter-egg", 19)},
  crafting_machine_tint = growth_recipe_tints.biter_egg,
  preserve_products_in_machine_output = true,
  enabled = false,
  subgroup = "bte-spacelab-growth",
  order = "c[biter-egg]",
  allow_productivity = true,
  always_show_made_in = true
})

local pentapod_egg_ingredients = {item("nutrients", 50), item("bioflux", 5), fluid("water", 500), fluid("steam", 250), item("pentapod-egg", 1), item("calcite", 5), item("carbon", 10)}
add_optional_ingredient(pentapod_egg_ingredients, ammonia_ingredient(125))
add_recipe({
  type = "recipe",
  name = "bte-pentapod-egg-incubation",
  categories = {"bte-spacelab-growth"},
  energy_required = 120,
  ingredients = pentapod_egg_ingredients,
  results = {item("pentapod-egg", 19)},
  crafting_machine_tint = growth_recipe_tints.pentapod_egg,
  preserve_products_in_machine_output = true,
  enabled = false,
  subgroup = "bte-spacelab-growth",
  order = "d[pentapod-egg]",
  allow_productivity = true,
  always_show_made_in = true
})

local ammonia_results = {}
if prototype_exists("fluid", "ammonia") then
  ammonia_results = {fluid("ammonia", 10)}
elseif prototype_exists("fluid", "ammoniacal-solution") then
  ammonia_results = {fluid("ammoniacal-solution", 10)}
end

if ammonia_results[1] then
  add_recipe({
    type = "recipe",
    name = "bte-ammonia-extraction",
    categories = {"cryogenics"},
    energy_required = 5,
    ingredients = {item("stone", 5), fluid("water", 100), fluid("steam", 50)},
    results = ammonia_results,
    icons = {
      recipe_icon_layer(item("stone", 1), 0.62, {0, 0}),
      recipe_icon_layer(fluid("water", 1), 0.28, {-11, -11}),
      recipe_icon_layer(fluid("steam", 1), 0.28, {11, -11}),
      recipe_icon_layer(ammonia_results[1], 0.28, {-11, 11})
    },
    enabled = false,
    subgroup = "bte-spacelab-cryogenics",
    order = "a[ammonia-extraction]",
    allow_productivity = true,
    always_show_made_in = true
  })
end

add_recipe({
  type = "recipe",
  name = "bte-lithium-focused-condensation",
  categories = {"cryogenics"},
  energy_required = 10,
  ingredients = {item("bte-flurolite", 1), fluid("steam", 100)},
  results = {
    fluid("lithium-brine", 40),
    fluid("fluorine", 10)
  },
  icons = {
    recipe_icon_layer(item("bte-flurolite", 1), 0.5, {0, 0}),
    recipe_icon_layer(fluid("lithium-brine", 1), 0.42, {-10, 0}),
    recipe_icon_layer(fluid("fluorine", 1), 0.28, {12, 0})
  },
  enabled = false,
  subgroup = "bte-spacelab-cryogenics",
  order = "b[lithium-focused]",
  allow_productivity = true,
  always_show_made_in = true
})

add_recipe({
  type = "recipe",
  name = "bte-fluorine-focused-condensation",
  categories = {"cryogenics"},
  energy_required = 10,
  ingredients = {item("bte-flurolite", 1), fluid("steam", 100)},
  results = {
    fluid("fluorine", 40),
    fluid("lithium-brine", 10)
  },
  icons = {
    recipe_icon_layer(item("bte-flurolite", 1), 0.5, {0, 0}),
    recipe_icon_layer(fluid("fluorine", 1), 0.42, {-10, 0}),
    recipe_icon_layer(fluid("lithium-brine", 1), 0.28, {12, 0})
  },
  enabled = false,
  subgroup = "bte-spacelab-cryogenics",
  order = "c[fluorine-focused]",
  allow_productivity = true,
  always_show_made_in = true
})
