local helpers = require("prototypes.helpers")

local item_icon_layer = helpers.item_icon_layer
local fluid_icon_layer = helpers.fluid_icon_layer
local unlocks = helpers.unlocks
local prerequisites = helpers.prerequisites
local add_technology = helpers.add_technology
local final_research_productivity_science = helpers.final_research_productivity_science

add_technology({
  type = "technology",
  name = "spacelab-asteroid-stone-processing",
  icons = {
    item_icon_layer("stone", 1.6, {0, 0}),
    item_icon_layer("metallic-asteroid-chunk", 0.7, {-52, -48}),
    item_icon_layer("carbonic-asteroid-chunk", 0.7, {52, -48}),
    item_icon_layer("oxide-asteroid-chunk", 0.7, {-52, 48}),
    fluid_icon_layer("ammonia", 0.7, {52, 48})
  },
  prerequisites = prerequisites({"promethium-science-pack"}),
  effects = unlocks({
    "spacelab-metallic-asteroid-crushing-stone-focused",
    "spacelab-carbonic-asteroid-crushing-stone-focused",
    "spacelab-oxide-asteroid-crushing-stone-focused",
    "spacelab-ammonia-extraction"
  }),
  unit = {
    count = 1200,
    time = 120,
    ingredients = final_research_productivity_science()
  },
  order = "z-spacelab-a"
})

add_technology({
  type = "technology",
  name = "spacelab-flurolite-processing",
  icons = {
    item_icon_layer("spacelab-flurolite", 1.6, {0, 0}),
    item_icon_layer("promethium-asteroid-chunk", 0.7, {-52, -48}),
    item_icon_layer("holmium-ore", 0.65, {52, -48}),
    fluid_icon_layer("lithium-brine", 0.7, {-52, 48}),
    fluid_icon_layer("fluorine", 0.7, {52, 48})
  },
  prerequisites = prerequisites({"promethium-science-pack"}),
  effects = unlocks({
    "spacelab-metallic-asteroid-crushing-flurolite-focused",
    "spacelab-carbonic-asteroid-crushing-flurolite-focused",
    "spacelab-oxide-asteroid-crushing-flurolite-focused",
    "spacelab-shattered-synthesis",
    "spacelab-lithium-focused-condensation",
    "spacelab-fluorine-focused-condensation"
  }),
  unit = {
    count = 1200,
    time = 120,
    ingredients = final_research_productivity_science()
  },
  order = "z-spacelab-b"
})

add_technology({
  type = "technology",
  name = "spacelab-growth-facility",
  icons = {
    {icon = "__spacelab__/graphics/technology/growth-facility.png", icon_size = 128, scale = 1.0, shift = {0, 0}},
    item_icon_layer("yumako", 0.7, {-52, -48}),
    item_icon_layer("jellynut", 0.7, {52, -48}),
    item_icon_layer("biter-egg", 0.7, {-52, 48}),
    item_icon_layer("pentapod-egg", 0.7, {52, 48})
  },
  prerequisites = prerequisites({"promethium-science-pack"}),
  effects = unlocks({
    "spacelab-growth-facility",
    "spacelab-yumako-cultivation",
    "spacelab-jellynut-cultivation",
    "spacelab-biter-egg-incubation",
    "spacelab-pentapod-egg-incubation"
  }),
  unit = {
    count = 1200,
    time = 120,
    ingredients = final_research_productivity_science()
  },
  order = "z-spacelab-c"
})
