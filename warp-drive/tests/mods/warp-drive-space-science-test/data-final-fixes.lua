-- Stands in for any mod that makes orbital science production possible, without depending
-- on SPACELAB. Warp Drive must select its local research branch from this capability alone,
-- so this patch is the only difference between the relay and local runtime test runs.
--
-- These are exactly the four vanilla science pack recipes with planetary surface conditions.
-- Space and Promethium Science Pack require gravity 0 and are already space-only; every
-- other required pack has no surface condition at all.
local RECIPES = {
  "metallurgic-science-pack",
  "agricultural-science-pack",
  "electromagnetic-science-pack",
  "cryogenic-science-pack"
}

for _, name in pairs(RECIPES) do
  local recipe = data.raw.recipe[name]
  if not recipe then
    error("WARP_TEST_FAIL: expected vanilla recipe " .. name)
  end
  if not recipe.surface_conditions then
    error("WARP_TEST_FAIL: expected surface conditions on vanilla recipe " .. name)
  end
  recipe.surface_conditions = nil
end

-- Keep the local-branch fixture's tiny laboratory load ahead of the 1 GW detector request.
-- This changes only the test run and avoids adding generation that would alter detector power.
data.raw.lab.lab.energy_source.usage_priority = "primary-input"
