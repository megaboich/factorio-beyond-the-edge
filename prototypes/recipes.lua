local item_like_types = {
  "item",
  "capsule",
  "tool",
  "module",
  "ammo",
  "armor",
  "gun",
  "item-with-entity-data",
  "rail-planner",
  "repair-tool",
  "spidertron-remote",
  "space-platform-starter-pack"
}

local function prototype_exists(type_name, name)
  return data.raw[type_name] and data.raw[type_name][name] ~= nil
end

local function item_like_prototype(name)
  for _, type_name in pairs(item_like_types) do
    if data.raw[type_name] and data.raw[type_name][name] then
      return data.raw[type_name][name]
    end
  end
  return nil
end

local function item_like_exists(name)
  return item_like_prototype(name) ~= nil
end

local function ingredient_exists(ingredient)
  if ingredient.type == "fluid" then
    return prototype_exists("fluid", ingredient.name)
  end
  return item_like_exists(ingredient.name)
end

local function all_ingredients_exist(ingredients)
  for _, ingredient in pairs(ingredients) do
    if not ingredient_exists(ingredient) then
      return false
    end
  end
  return true
end

local function all_results_exist(results)
  for _, result in pairs(results) do
    if result.type == "fluid" then
      if not prototype_exists("fluid", result.name) then
        return false
      end
    elseif not item_like_exists(result.name) then
      return false
    end
  end
  return true
end

local function category_exists(category)
  return category == "crafting" or category == "advanced-crafting" or data.raw["recipe-category"] and data.raw["recipe-category"][category] ~= nil
end

local function categories_exist(categories)
  if not categories then
    return true
  end
  for _, category in pairs(categories) do
    if not category_exists(category) then
      return false
    end
  end
  return true
end

local function product_prototype(product)
  if product.type == "fluid" then
    return data.raw.fluid and data.raw.fluid[product.name]
  end
  return item_like_prototype(product.name)
end

local function product_icon_layer(product)
  local prototype = product_prototype(product)
  if not prototype then
    return nil
  end

  if prototype.icons and prototype.icons[1] then
    local layer = table.deepcopy(prototype.icons[1])
    layer.icon_size = layer.icon_size or prototype.icon_size or 64
    return layer
  end

  if prototype.icon then
    return {
      icon = prototype.icon,
      icon_size = prototype.icon_size or 64
    }
  end

  return nil
end

local function recipe_icon_layer(product, scale, shift)
  local layer = product_icon_layer(product)
  if layer then
    layer.scale = scale
    layer.shift = shift
  end
  return layer
end

local function ensure_recipe_icon(recipe)
  if recipe.icon or recipe.icons or recipe.main_product then
    return
  end

  if recipe.results and #recipe.results == 1 and recipe.results[1].name then
    recipe.main_product = recipe.results[1].name
  end
end

local function add_recipe(recipe)
  if categories_exist(recipe.categories) and all_ingredients_exist(recipe.ingredients or {}) and all_results_exist(recipe.results or {}) then
    ensure_recipe_icon(recipe)
    data:extend({recipe})
  end
end

local function item(name, amount)
  return {type = "item", name = name, amount = amount}
end

local function fluid(name, amount)
  return {type = "fluid", name = name, amount = amount}
end

local growth_recipe_tints = {
  yumako = {
    primary = {r = 0.55, g = 0.02, b = 0.02, a = 1},
    secondary = {r = 0.85, g = 0.08, b = 0.08, a = 1}
  },
  jellynut = {
    primary = {r = 1, g = 0.18, b = 0.62, a = 1},
    secondary = {r = 1, g = 0.55, b = 0.82, a = 1}
  },
  biter_egg = {
    primary = {r = 1, g = 0.38, b = 0.02, a = 1},
    secondary = {r = 1, g = 0.62, b = 0.12, a = 1}
  },
  pentapod_egg = {
    primary = {r = 0.25, g = 0.95, b = 0.12, a = 1},
    secondary = {r = 0.55, g = 1, b = 0.32, a = 1}
  }
}

local function ammonia_ingredient(amount)
  if prototype_exists("fluid", "ammonia") then
    return fluid("ammonia", amount)
  end
  if prototype_exists("fluid", "ammoniacal-solution") then
    return fluid("ammoniacal-solution", amount)
  end
  return nil
end

local function add_optional_ingredient(ingredients, ingredient)
  if ingredient and ingredient_exists(ingredient) then
    table.insert(ingredients, ingredient)
  end
end

add_recipe({
  type = "recipe",
  name = "spacelab-growth-facility",
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
  results = {item("spacelab-growth-facility", 1)},
  enabled = false,
  subgroup = "spacelab-buildings",
  order = "a[spacelab-growth-facility]",
  always_show_made_in = true
})

add_recipe({
  type = "recipe",
  name = "spacelab-metallic-asteroid-crushing-stone-focused",
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
  subgroup = "spacelab-asteroid-processing",
  order = "a[metallic]-a[stone]",
  allow_productivity = true,
  always_show_made_in = true
})

add_recipe({
  type = "recipe",
  name = "spacelab-carbonic-asteroid-crushing-stone-focused",
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
  subgroup = "spacelab-asteroid-processing",
  order = "b[carbonic]-a[stone]",
  allow_productivity = true,
  always_show_made_in = true
})

add_recipe({
  type = "recipe",
  name = "spacelab-oxide-asteroid-crushing-stone-focused",
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
  subgroup = "spacelab-asteroid-processing",
  order = "c[oxide]-a[stone]",
  allow_productivity = true,
  always_show_made_in = true
})

add_recipe({
  type = "recipe",
  name = "spacelab-metallic-asteroid-crushing-flurolite-focused",
  categories = {"crushing"},
  energy_required = 3,
  ingredients = {item("metallic-asteroid-chunk", 1)},
  results = {
    item("iron-ore", 1),
    item("copper-ore", 1),
    item("stone", 2),
    {type = "item", name = "spacelab-flurolite", amount = 1, independent_probability = 0.05},
    {type = "item", name = "uranium-ore", amount = 1, independent_probability = 0.01}
  },
  icons = {
    recipe_icon_layer(item("metallic-asteroid-chunk", 1), 0.62, {0, 0}),
    recipe_icon_layer(item("iron-ore", 1), 0.28, {-11, -11}),
    recipe_icon_layer(item("copper-ore", 1), 0.28, {11, -11}),
    recipe_icon_layer(item("stone", 1), 0.28, {-11, 11}),
    recipe_icon_layer(item("spacelab-flurolite", 1), 0.28, {11, 11})
  },
  enabled = false,
  subgroup = "spacelab-asteroid-processing",
  order = "a[metallic]-b[flurolite]",
  allow_productivity = true,
  always_show_made_in = true
})

add_recipe({
  type = "recipe",
  name = "spacelab-carbonic-asteroid-crushing-flurolite-focused",
  categories = {"crushing"},
  energy_required = 3,
  ingredients = {item("carbonic-asteroid-chunk", 1)},
  results = {
    item("carbon", 2),
    item("stone", 2),
    {type = "item", name = "spacelab-flurolite", amount = 1, independent_probability = 0.05},
    {type = "item", name = "uranium-ore", amount = 1, independent_probability = 0.01}
  },
  icons = {
    recipe_icon_layer(item("carbonic-asteroid-chunk", 1), 0.62, {0, 0}),
    recipe_icon_layer(item("carbon", 1), 0.28, {-11, -11}),
    recipe_icon_layer(item("stone", 1), 0.28, {11, -11}),
    recipe_icon_layer(item("spacelab-flurolite", 1), 0.28, {-11, 11})
  },
  enabled = false,
  subgroup = "spacelab-asteroid-processing",
  order = "b[carbonic]-b[flurolite]",
  allow_productivity = true,
  always_show_made_in = true
})

add_recipe({
  type = "recipe",
  name = "spacelab-oxide-asteroid-crushing-flurolite-focused",
  categories = {"crushing"},
  energy_required = 3,
  ingredients = {item("oxide-asteroid-chunk", 1)},
  results = {
    item("ice", 2),
    item("stone", 2),
    {type = "item", name = "spacelab-flurolite", amount = 1, independent_probability = 0.05},
    {type = "item", name = "uranium-ore", amount = 1, independent_probability = 0.01}
  },
  icons = {
    recipe_icon_layer(item("oxide-asteroid-chunk", 1), 0.62, {0, 0}),
    recipe_icon_layer(item("ice", 1), 0.28, {-11, -11}),
    recipe_icon_layer(item("stone", 1), 0.28, {11, -11}),
    recipe_icon_layer(item("spacelab-flurolite", 1), 0.28, {-11, 11})
  },
  enabled = false,
  subgroup = "spacelab-asteroid-processing",
  order = "c[oxide]-b[flurolite]",
  allow_productivity = true,
  always_show_made_in = true
})

add_recipe({
  type = "recipe",
  name = "spacelab-shattered-synthesis",
  categories = {"crushing"},
  energy_required = 4,
  ingredients = {item("promethium-asteroid-chunk", 1)},
  results = {
    item("holmium-ore", 1),
    item("tungsten-ore", 1),
    item("stone", 2),
    {type = "item", name = "spacelab-flurolite", amount = 1, independent_probability = 0.05},
    {type = "item", name = "uranium-ore", amount = 1, independent_probability = 0.03}
  },
  icons = {
    recipe_icon_layer(item("promethium-asteroid-chunk", 1), 0.62, {0, 0}),
    recipe_icon_layer(item("holmium-ore", 1), 0.28, {-11, -11}),
    recipe_icon_layer(item("tungsten-ore", 1), 0.28, {11, -11}),
    recipe_icon_layer(item("stone", 1), 0.28, {-11, 11}),
    recipe_icon_layer(item("spacelab-flurolite", 1), 0.28, {11, 11})
  },
  enabled = false,
  subgroup = "spacelab-asteroid-processing",
  order = "d[promethium]-a[shattered-synthesis]",
  allow_productivity = true,
  always_show_made_in = true
})

local yumako_ingredients = {item("nutrients", 5), fluid("water", 100), item("yumako-seed", 1), item("calcite", 1), item("carbon", 2)}
add_optional_ingredient(yumako_ingredients, ammonia_ingredient(25))
add_recipe({
  type = "recipe",
  name = "spacelab-yumako-cultivation",
  categories = {"spacelab-growth"},
  energy_required = 60,
  ingredients = yumako_ingredients,
  results = {item("yumako", 10)},
  crafting_machine_tint = growth_recipe_tints.yumako,
  preserve_products_in_machine_output = true,
  enabled = false,
  subgroup = "spacelab-growth",
  order = "a[yumako]",
  allow_productivity = true,
  always_show_made_in = true
})

local jellynut_ingredients = {item("nutrients", 5), fluid("water", 100), item("jellynut-seed", 1), item("calcite", 1), item("carbon", 2)}
add_optional_ingredient(jellynut_ingredients, ammonia_ingredient(25))
add_recipe({
  type = "recipe",
  name = "spacelab-jellynut-cultivation",
  categories = {"spacelab-growth"},
  energy_required = 60,
  ingredients = jellynut_ingredients,
  results = {item("jellynut", 10)},
  crafting_machine_tint = growth_recipe_tints.jellynut,
  preserve_products_in_machine_output = true,
  enabled = false,
  subgroup = "spacelab-growth",
  order = "b[jellynut]",
  allow_productivity = true,
  always_show_made_in = true
})

local biter_egg_ingredients = {item("nutrients", 10), item("bioflux", 1), fluid("water", 100), fluid("steam", 50), item("biter-egg", 1), item("calcite", 1), item("carbon", 2)}
add_optional_ingredient(biter_egg_ingredients, ammonia_ingredient(25))
add_recipe({
  type = "recipe",
  name = "spacelab-biter-egg-incubation",
  categories = {"spacelab-growth"},
  energy_required = 120,
  ingredients = biter_egg_ingredients,
  results = {item("biter-egg", 10)},
  crafting_machine_tint = growth_recipe_tints.biter_egg,
  preserve_products_in_machine_output = true,
  enabled = false,
  subgroup = "spacelab-growth",
  order = "c[biter-egg]",
  allow_productivity = true,
  always_show_made_in = true
})

local pentapod_egg_ingredients = {item("nutrients", 10), item("bioflux", 1), fluid("water", 100), fluid("steam", 50), item("pentapod-egg", 1), item("calcite", 1), item("carbon", 2)}
add_optional_ingredient(pentapod_egg_ingredients, ammonia_ingredient(25))
add_recipe({
  type = "recipe",
  name = "spacelab-pentapod-egg-incubation",
  categories = {"spacelab-growth"},
  energy_required = 120,
  ingredients = pentapod_egg_ingredients,
  results = {item("pentapod-egg", 10)},
  crafting_machine_tint = growth_recipe_tints.pentapod_egg,
  preserve_products_in_machine_output = true,
  enabled = false,
  subgroup = "spacelab-growth",
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
    name = "spacelab-ammonia-extraction",
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
    subgroup = "spacelab-cryogenics",
    order = "a[ammonia-extraction]",
    allow_productivity = true,
    always_show_made_in = true
  })
end

add_recipe({
  type = "recipe",
  name = "spacelab-lithium-focused-condensation",
  categories = {"cryogenics"},
  energy_required = 10,
  ingredients = {item("spacelab-flurolite", 1), fluid("steam", 100)},
  results = {
    fluid("lithium-brine", 40),
    fluid("fluorine", 10)
  },
  icons = {
    recipe_icon_layer(item("spacelab-flurolite", 1), 0.5, {0, 0}),
    recipe_icon_layer(fluid("lithium-brine", 1), 0.42, {-10, 0}),
    recipe_icon_layer(fluid("fluorine", 1), 0.28, {12, 0})
  },
  enabled = false,
  subgroup = "spacelab-cryogenics",
  order = "b[lithium-focused]",
  allow_productivity = true,
  always_show_made_in = true
})

add_recipe({
  type = "recipe",
  name = "spacelab-fluorine-focused-condensation",
  categories = {"cryogenics"},
  energy_required = 10,
  ingredients = {item("spacelab-flurolite", 1), fluid("steam", 100)},
  results = {
    fluid("fluorine", 40),
    fluid("lithium-brine", 10)
  },
  icons = {
    recipe_icon_layer(item("spacelab-flurolite", 1), 0.5, {0, 0}),
    recipe_icon_layer(fluid("fluorine", 1), 0.42, {-10, 0}),
    recipe_icon_layer(fluid("lithium-brine", 1), 0.28, {12, 0})
  },
  enabled = false,
  subgroup = "spacelab-cryogenics",
  order = "c[fluorine-focused]",
  allow_productivity = true,
  always_show_made_in = true
})
