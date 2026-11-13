data:extend({
  {
    type = "item",
    name = "bte-stargate-construction-kit",
    icon = "__bte-stargate__/graphics/icons/construction-kit.png",
    icon_size = 64,
    subgroup = "space-related",
    order = "z[bte]-a[stargate]-a[construction-kit]",
    stack_size = 1,
    -- One kit per cargo rocket, like the Growth Facility.
    weight = 1000 * kg,
    place_result = "bte-stargate-construction-site"
  }
})
