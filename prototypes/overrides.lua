for _, recipe_name in pairs({
  "agricultural-science-pack",
  "cryogenic-science-pack",
  "electromagnetic-science-pack",
  "metallurgic-science-pack",
}) do
  local recipe = data.raw.recipe[recipe_name]
  if recipe then
    recipe.surface_conditions = nil
  end
end
