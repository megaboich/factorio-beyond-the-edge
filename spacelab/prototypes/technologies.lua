local helpers = require("prototypes.helpers")

local item_icon_layer = helpers.item_icon_layer
local fluid_icon_layer = helpers.fluid_icon_layer
local unlocks = helpers.unlocks
local prerequisites = helpers.prerequisites
local add_technology = helpers.add_technology
local final_research_productivity_science = helpers.final_research_productivity_science

add_technology({
  type = "technology",
  name = "bte-asteroid-stone-processing",
  icons = {
    item_icon_layer("stone", 1.6, {0, 0}),
    item_icon_layer("metallic-asteroid-chunk", 0.7, {-52, -48}),
    item_icon_layer("carbonic-asteroid-chunk", 0.7, {52, -48}),
    item_icon_layer("oxide-asteroid-chunk", 0.7, {-52, 48}),
    fluid_icon_layer("ammonia", 0.7, {52, 48})
  },
  prerequisites = prerequisites({"promethium-science-pack"}),
  effects = unlocks({
    "bte-metallic-asteroid-crushing-stone-focused",
    "bte-carbonic-asteroid-crushing-stone-focused",
    "bte-oxide-asteroid-crushing-stone-focused",
    "bte-ammonia-extraction"
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
  name = "bte-flurolite-processing",
  icons = {
    item_icon_layer("bte-flurolite", 1.6, {0, 0}),
    item_icon_layer("promethium-asteroid-chunk", 0.7, {-52, -48}),
    item_icon_layer("holmium-ore", 0.65, {52, -48}),
    fluid_icon_layer("lithium-brine", 0.7, {-52, 48}),
    fluid_icon_layer("fluorine", 0.7, {52, 48})
  },
  prerequisites = prerequisites({"promethium-science-pack"}),
  effects = unlocks({
    "bte-metallic-asteroid-crushing-flurolite-focused",
    "bte-carbonic-asteroid-crushing-flurolite-focused",
    "bte-oxide-asteroid-crushing-flurolite-focused",
    "bte-shattered-synthesis",
    "bte-lithium-focused-condensation",
    "bte-fluorine-focused-condensation"
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
  name = "bte-growth-facility",
  icons = {
    {icon = "__bte-spacelab__/graphics/technology/growth-facility.png", icon_size = 256, scale = 0.5, shift = {0, 0}},
    item_icon_layer("yumako", 0.7, {-52, -48}),
    item_icon_layer("jellynut", 0.7, {52, -48}),
    item_icon_layer("biter-egg", 0.7, {-52, 48}),
    item_icon_layer("pentapod-egg", 0.7, {52, 48})
  },
  prerequisites = prerequisites({"promethium-science-pack"}),
  effects = unlocks({
    "bte-growth-facility",
    "bte-yumako-cultivation",
    "bte-jellynut-cultivation",
    "bte-biter-egg-incubation",
    "bte-pentapod-egg-incubation"
  }),
  unit = {
    count = 1200,
    time = 120,
    ingredients = final_research_productivity_science()
  },
  order = "z-spacelab-c"
})
