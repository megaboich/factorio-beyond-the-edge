data:extend({
  {
    type = "technology",
    name = "bte-stargate-experimental-gates",
    icon = "__bte-stargate__/graphics/technology/stargate.png",
    icon_size = 256,
    prerequisites = {
      "quantum-processor", "fusion-reactor",
      "speed-module-3", "productivity-module-3", "efficiency-module-3", "quality-module-3"
    },
    effects = {{type = "unlock-recipe", recipe = "bte-stargate-construction-kit"}},
    -- Provisional: every pack the prerequisites need, without military or promethium science.
    unit = {
      count = 1000,
      time = 60,
      ingredients = {
        {"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1},
        {"production-science-pack", 1}, {"utility-science-pack", 1}, {"space-science-pack", 1},
        {"metallurgic-science-pack", 1}, {"agricultural-science-pack", 1},
        {"electromagnetic-science-pack", 1}, {"cryogenic-science-pack", 1}
      }
    },
    order = "z-stargate-a"
  }
})
