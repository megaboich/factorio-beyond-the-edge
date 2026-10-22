data:extend({
  {
    type = "recipe",
    name = "warp-drive",
    enabled = false,
    energy_required = 120,
    ingredients = {
      {type = "item", name = "quantum-processor", amount = 200},
      {type = "item", name = "superconductor", amount = 500},
      {type = "item", name = "tungsten-plate", amount = 1000},
      {type = "item", name = "carbon-fiber", amount = 500},
      {type = "item", name = "supercapacitor", amount = 500}
    },
    results = {{type = "item", name = "warp-drive", amount = 1}},
    allow_productivity = false,
    main_product = "warp-drive"
  }
})
