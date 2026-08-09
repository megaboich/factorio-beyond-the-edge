data:extend({
  {
    type = "item",
    name = "spacelab-growth-facility",
    icon = "__spacelab__/graphics/icons/growth-facility.png",
    icon_size = 64,
    subgroup = "spacelab-buildings",
    order = "a[spacelab-growth-facility]",
    stack_size = 10,
    weight = 1 * tons,
    place_result = "spacelab-growth-facility"
  },
  {
    type = "item",
    name = "spacelab-flurolite",
    icons = {{
      icon = "__space-age__/graphics/icons/calcite.png",
      icon_size = 64,
      tint = {r = 0.3, g = 0.8, b = 1, a = 1}
    }},
    pictures = {
      { filename = "__space-age__/graphics/icons/calcite.png", size = 64, scale = 0.5, mipmap_count = 4, tint = {r = 0.3, g = 0.8, b = 1, a = 1} },
      { filename = "__space-age__/graphics/icons/calcite-1.png", size = 64, scale = 0.5, mipmap_count = 4, tint = {r = 0.3, g = 0.8, b = 1, a = 1} },
      { filename = "__space-age__/graphics/icons/calcite-2.png", size = 64, scale = 0.5, mipmap_count = 4, tint = {r = 0.3, g = 0.8, b = 1, a = 1} },
      { filename = "__space-age__/graphics/icons/calcite-3.png", size = 64, scale = 0.5, mipmap_count = 4, tint = {r = 0.3, g = 0.8, b = 1, a = 1} }
    },
    subgroup = "spacelab-resources",
    order = "a[spacelab-flurolite]",
    stack_size = 50
  }
})
