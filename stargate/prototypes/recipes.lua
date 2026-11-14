data:extend({
  {
    type = "recipe",
    name = "bte-stargate-construction-kit",
    categories = {"crafting"},
    energy_required = 60,
    -- The scarce high-end parts, plus a little structural material so the kit is plausibly a kit; the
    -- bulk goes to the construction site (prototypes/construction.lua).
    ingredients = {
      {type = "item", name = "steel-plate", amount = 100},
      {type = "item", name = "refined-concrete", amount = 100},
      {type = "item", name = "low-density-structure", amount = 50},
      {type = "item", name = "quantum-processor", amount = 20},
      {type = "item", name = "speed-module-3", amount = 10},
      {type = "item", name = "productivity-module-3", amount = 10},
      {type = "item", name = "efficiency-module-3", amount = 10},
      {type = "item", name = "quality-module-3", amount = 10},
      {type = "item", name = "supercapacitor", amount = 50},
      {type = "item", name = "fusion-power-cell", amount = 20}
    },
    results = {{type = "item", name = "bte-stargate-construction-kit", amount = 1}},
    main_product = "bte-stargate-construction-kit",
    enabled = false,
    subgroup = "space-related",
    order = "z[bte]-a[stargate]-a[construction-kit]"
  },
  -- The open portal: what the finished gate (an assembling machine, prototypes/entities.lua) "crafts"
  -- while it is enabled, so it draws its 1 GW and shows its veil. No ingredients, no results.
  {
    type = "recipe-category",
    name = "bte-stargate-portal"
  },
  {
    type = "recipe",
    name = "bte-stargate-portal",
    icon = "__bte-stargate__/graphics/icons/stargate.png",
    icon_size = 64,
    categories = {"bte-stargate-portal"},
    energy_required = 60,
    ingredients = {},
    results = {},
    enabled = true,
    hidden = true,
    hide_from_player_crafting = true
  }
})
