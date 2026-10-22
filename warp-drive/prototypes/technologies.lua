local full_science_set = {
  {"automation-science-pack", 1},
  {"logistic-science-pack", 1},
  {"military-science-pack", 1},
  {"chemical-science-pack", 1},
  {"production-science-pack", 1},
  {"utility-science-pack", 1},
  {"space-science-pack", 1},
  {"metallurgic-science-pack", 1},
  {"electromagnetic-science-pack", 1},
  {"agricultural-science-pack", 1},
  {"cryogenic-science-pack", 1},
  {"promethium-science-pack", 1}
}

data:extend({
  {
    type = "technology",
    name = "theoretical-warp-drive",
    icon = "__warp-drive__/graphics/icons/warp-drive-big.png",
    icon_size = 640,
    prerequisites = {"promethium-science-pack"},
    effects = {{type = "unlock-recipe", recipe = "warp-drive"}},
    unit = {
      count = 10000,
      time = 120,
      ingredients = full_science_set
    },
    order = "z[warp-drive]-a[theoretical]"
  },
  {
    type = "technology",
    name = "practical-warp-drive",
    icon = "__warp-drive__/graphics/icons/warp-drive-big.png",
    icon_size = 640,
    prerequisites = {"theoretical-warp-drive"},
    unit = {
      count = 1000000000,
      time = 120,
      ingredients = full_science_set
    },
    essential = true,
    order = "z[warp-drive]-b[practical]"
  }
})
