data:extend({
  {
    type = "item",
    name = "bte-growth-facility",
    icon = "__bte-spacelab__/graphics/icons/growth-facility.png",
    icon_size = 64,
    subgroup = "bte-spacelab-buildings",
    order = "a[bte-growth-facility]",
    stack_size = 10,
    weight = 1 * tons,
    place_result = "bte-growth-facility"
  },
  {
    type = "item",
    name = "bte-flurolite",
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
    subgroup = "bte-spacelab-resources",
    order = "a[bte-flurolite]",
    stack_size = 50
  }
})
