-- How a Stargate is built. data-final-fixes.lua turns this into the construction site's filtered
-- slots and a mod-data prototype the runtime reads. Quantities are provisional first-experiment balance.
--
-- The scarce high-end parts go into the construction kit (prototypes/recipes.lua). The site takes only
-- bulk materials, and every amount is a whole number of stacks, so each material's slots hold exactly
-- the amount needed and a delivery can never overshoot the bill. Keep it that way when editing: the
-- prototype tests check the alignment against the game's stack sizes.
return {
  -- Ticks from a complete delivery to a finished gate.
  build_ticks = 60 * 60,
  -- Pictures the gate passes through while it is built, one per equal share of the build time. The first
  -- is the construction site's own, so nothing changes the moment the delivery is complete; the rest are
  -- graphics/entity/assembling/assembling-<n>-* (see prototypes/entities.lua).
  stages = 3,
  requirements = {
    {name = "tungsten-plate", amount = 1000},
    {name = "superconductor", amount = 200},
    {name = "low-density-structure", amount = 200},
    {name = "refined-concrete", amount = 200},
    {name = "steel-plate", amount = 200},
    {name = "tungsten-carbide", amount = 100},
    {name = "advanced-circuit", amount = 200}
  }
}
