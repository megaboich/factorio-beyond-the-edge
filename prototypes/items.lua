data:extend({
  {
    type = "item",
    name = "spacelab-growth-facility",
    icon = "__spacelab__/graphics/icons/growth-facility.png",
    icon_size = 64,
    subgroup = "spacelab-buildings",
    order = "a[spacelab-growth-facility]",
    stack_size = 10,
    place_result = "spacelab-growth-facility"
  },
  {
    type = "item",
    name = "spacelab-flurolite",
    icon = "__spacelab__/graphics/icons/flurolite.png",
    icon_size = 64,
    pictures = {
      { filename = "__spacelab__/graphics/icons/flurolite.png", size = 64, scale = 0.5 },
      { filename = "__spacelab__/graphics/icons/flurolite-01.png", size = 64, scale = 0.5 },
      { filename = "__spacelab__/graphics/icons/flurolite-02.png", size = 64, scale = 0.5 },
      { filename = "__spacelab__/graphics/icons/flurolite-03.png", size = 64, scale = 0.5 }
    },
    subgroup = "spacelab-resources",
    order = "a[spacelab-flurolite]",
    stack_size = 50
  }
})
