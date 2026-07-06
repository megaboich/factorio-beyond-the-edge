data:extend({
  {
    type = "item-group",
    name = "spacelab-production",
    icon = "__spacelab__/graphics/icons/space_lab_icon_big.png",
    icon_size = 128,
    order = "z-spacelab"
  },
  {
    type = "item-subgroup",
    name = "spacelab-buildings",
    group = "spacelab-production",
    order = "a"
  },
  {
    type = "item-subgroup",
    name = "spacelab-resources",
    group = "spacelab-production",
    order = "b"
  },
  {
    type = "item-subgroup",
    name = "spacelab-asteroid-processing",
    group = "spacelab-production",
    order = "c"
  },
  {
    type = "item-subgroup",
    name = "spacelab-cryogenics",
    group = "spacelab-production",
    order = "d"
  },
  {
    type = "item-subgroup",
    name = "spacelab-growth",
    group = "spacelab-production",
    order = "e"
  },
  {
    type = "recipe-category",
    name = "spacelab-growth"
  },
  {
    type = "autoplace-control",
    name = "spacelab-flurolite",
    category = "resource",
    richness = true,
    order = "z-spacelab-flurolite"
  }
})
