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
    name = "bte-theoretical-warp-drive",
    icon = "__bte-warp-drive__/graphics/technology/warp-drive.png",
    icon_size = 256,
    prerequisites = {"promethium-science-pack"},
    effects = {{type = "unlock-recipe", recipe = "bte-warp-drive"}},
    unit = {
      count = 10000,
      time = 120,
      ingredients = full_science_set
    },
    order = "z[bte-warp-drive]-a[theoretical]"
  },
  {
    type = "technology",
    name = "bte-practical-warp-drive",
    icon = "__bte-warp-drive__/graphics/technology/warp-drive.png",
    icon_size = 256,
    prerequisites = {"bte-theoretical-warp-drive"},
    unit = {
      count = 1000000000,
      time = 120,
      ingredients = full_science_set
    },
    essential = true,
    order = "z[bte-warp-drive]-b[practical]"
  }
})
