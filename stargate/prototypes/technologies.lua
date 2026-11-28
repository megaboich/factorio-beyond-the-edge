local packs = {
  {"automation-science-pack", 1}, {"logistic-science-pack", 1}, {"chemical-science-pack", 1},
  {"production-science-pack", 1}, {"utility-science-pack", 1}, {"space-science-pack", 1},
  {"metallurgic-science-pack", 1}, {"agricultural-science-pack", 1},
  {"electromagnetic-science-pack", 1}, {"cryogenic-science-pack", 1}
}

local base_icon = {icon = "__bte-stargate__/graphics/technology/stargate.png", icon_size = 256, scale = 0.5, shift = {0, 0}}

local function badge(icon, shift)
  return {icon = icon, icon_size = 64, scale = 0.65, shift = shift}
end

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
      ingredients = packs
    },
    order = "z-stargate-a"
  },
  {
    type = "technology",
    name = "bte-stargate-controlled-jumps",
    icons = {
      base_icon,
      badge("__space-age__/graphics/icons/quantum-processor.png", {-42, 42}),
      badge("__base__/graphics/icons/beacon.png", {42, 42})
    },
    prerequisites = {"bte-stargate-experimental-gates"},
    -- Shown but closed until the force's first jump through an unpaired gate, when scripts/gate.lua
    -- (Gate.record_jump) enables it.
    enabled = false,
    visible_when_disabled = true,
    effects = {{
      type = "nothing",
      effect_description = {"bte-stargate-technology.controlled-jumps-effect"},
      icon = "__bte-stargate__/graphics/icons/stargate.png",
      icon_size = 64
    }},
    unit = {
      count = 2000,
      time = 60,
      ingredients = packs
    },
    order = "z-stargate-c"
  },
  {
    type = "technology",
    name = "bte-stargate-rail-transit",
    icons = {
      base_icon,
      badge("__base__/graphics/icons/locomotive.png", {-42, 42}),
      badge("__base__/graphics/icons/rail-signal.png", {42, 42})
    },
    prerequisites = {"bte-stargate-controlled-jumps"},
    effects = {{
      type = "nothing",
      effect_description = {"bte-stargate-technology.rail-transit-effect"},
      icon = "__base__/graphics/icons/locomotive.png",
      icon_size = 64
    }},
    unit = {
      count = 5000,
      time = 60,
      ingredients = packs
    },
    order = "z-stargate-d"
  }
})
