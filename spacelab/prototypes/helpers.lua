local helpers = {}

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

function helpers.prototype_exists(type_name, name)
  return data.raw[type_name] and data.raw[type_name][name] ~= nil
end

function helpers.item_like_prototype(name)
  for _, type_name in pairs(item_like_types) do
    if data.raw[type_name] and data.raw[type_name][name] then
      return data.raw[type_name][name]
    end
  end
  return nil
end

function helpers.item_like_exists(name)
  return helpers.item_like_prototype(name) ~= nil
end

function helpers.ingredient_exists(ingredient)
  if ingredient.type == "fluid" then
    return helpers.prototype_exists("fluid", ingredient.name)
  end
  return helpers.item_like_exists(ingredient.name)
end

function helpers.all_ingredients_exist(ingredients)
  for _, ingredient in pairs(ingredients) do
    if not helpers.ingredient_exists(ingredient) then
      return false
    end
  end
  return true
end

function helpers.all_results_exist(results)
  for _, result in pairs(results) do
    if result.type == "fluid" then
      if not helpers.prototype_exists("fluid", result.name) then
        return false
      end
    elseif not helpers.item_like_exists(result.name) then
      return false
    end
  end
  return true
end

function helpers.category_exists(category)
  return category == "crafting" or category == "advanced-crafting" or data.raw["recipe-category"] and data.raw["recipe-category"][category] ~= nil
end

function helpers.categories_exist(categories)
  if not categories then
    return true
  end
  for _, category in pairs(categories) do
    if not helpers.category_exists(category) then
      return false
    end
  end
  return true
end

function helpers.product_prototype(product)
  if product.type == "fluid" then
    return data.raw.fluid and data.raw.fluid[product.name]
  end
  return helpers.item_like_prototype(product.name)
end

function helpers.icon_layer(prototype, scale, shift)
  if not prototype then
    return nil
  end

  if prototype.icons and prototype.icons[1] then
    local layer = table.deepcopy(prototype.icons[1])
    layer.icon_size = layer.icon_size or prototype.icon_size or 64
    layer.scale = scale
    layer.shift = shift
    return layer
  end

  if prototype.icon then
    return {
      icon = prototype.icon,
      icon_size = prototype.icon_size or 64,
      scale = scale,
      shift = shift
    }
  end

  return nil
end

function helpers.product_icon_layer(product)
  return helpers.icon_layer(helpers.product_prototype(product))
end

function helpers.recipe_icon_layer(product, scale, shift)
  return helpers.icon_layer(helpers.product_prototype(product), scale, shift)
end

function helpers.item_icon_layer(name, scale, shift)
  return helpers.icon_layer(helpers.item_like_prototype(name), scale, shift)
end

function helpers.fluid_icon_layer(name, scale, shift)
  return helpers.icon_layer(data.raw.fluid and data.raw.fluid[name], scale, shift)
end

function helpers.ensure_recipe_icon(recipe)
  if recipe.icon or recipe.icons or recipe.main_product then
    return
  end

  if recipe.results and #recipe.results == 1 and recipe.results[1].name then
    recipe.main_product = recipe.results[1].name
  end
end

function helpers.add_recipe(recipe)
  if helpers.categories_exist(recipe.categories) and helpers.all_ingredients_exist(recipe.ingredients or {}) and helpers.all_results_exist(recipe.results or {}) then
    helpers.ensure_recipe_icon(recipe)
    data:extend({recipe})
  end
end

function helpers.item(name, amount)
  return {type = "item", name = name, amount = amount}
end

function helpers.fluid(name, amount)
  return {type = "fluid", name = name, amount = amount}
end

function helpers.ammonia_ingredient(amount)
  if helpers.prototype_exists("fluid", "ammonia") then
    return helpers.fluid("ammonia", amount)
  end
  if helpers.prototype_exists("fluid", "ammoniacal-solution") then
    return helpers.fluid("ammoniacal-solution", amount)
  end
  return nil
end

function helpers.add_optional_ingredient(ingredients, ingredient)
  if ingredient and helpers.ingredient_exists(ingredient) then
    table.insert(ingredients, ingredient)
  end
end

function helpers.recipe_exists(name)
  return data.raw.recipe and data.raw.recipe[name] ~= nil
end

function helpers.technology_exists(name)
  return data.raw.technology and data.raw.technology[name] ~= nil
end

function helpers.science_pack(name)
  if data.raw.item and data.raw.item[name] then
    return {name, 1}
  end
  if data.raw.tool and data.raw.tool[name] then
    return {name, 1}
  end
  return nil
end

function helpers.add_science_pack(ingredients, name)
  local pack = helpers.science_pack(name)
  if pack then
    table.insert(ingredients, pack)
  end
end

function helpers.unlocks(recipe_names)
  local effects = {}
  for _, recipe_name in pairs(recipe_names) do
    if helpers.recipe_exists(recipe_name) then
      table.insert(effects, {type = "unlock-recipe", recipe = recipe_name})
    end
  end
  return effects
end

function helpers.prerequisites(names)
  local result = {}
  for _, name in pairs(names) do
    if helpers.technology_exists(name) then
      table.insert(result, name)
    end
  end
  return result
end

function helpers.add_technology(technology)
  if #technology.effects > 0 then
    data:extend({technology})
  end
end

function helpers.final_research_productivity_science()
  local ingredients = {}
  helpers.add_science_pack(ingredients, "automation-science-pack")
  helpers.add_science_pack(ingredients, "logistic-science-pack")
  helpers.add_science_pack(ingredients, "military-science-pack")
  helpers.add_science_pack(ingredients, "chemical-science-pack")
  helpers.add_science_pack(ingredients, "production-science-pack")
  helpers.add_science_pack(ingredients, "utility-science-pack")
  helpers.add_science_pack(ingredients, "space-science-pack")
  helpers.add_science_pack(ingredients, "metallurgic-science-pack")
  helpers.add_science_pack(ingredients, "electromagnetic-science-pack")
  helpers.add_science_pack(ingredients, "agricultural-science-pack")
  helpers.add_science_pack(ingredients, "cryogenic-science-pack")
  helpers.add_science_pack(ingredients, "promethium-science-pack")
  return ingredients
end

return helpers
