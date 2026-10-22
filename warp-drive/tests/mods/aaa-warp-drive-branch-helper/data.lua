-- A deeper disconnected route must not replace the Shattered Planet as the destination for
-- platforms in the vanilla route graph. Its large starmap radii reproduce that modded-map
-- edge case in both research-branch runs.
data:extend({
  {
    type = "electric-energy-interface",
    name = "warp-drive-branch-power-source",
    icon = "__base__/graphics/icons/accumulator.png",
    hidden = true,
    collision_mask = {layers = {}},
    collision_box = {{0, 0}, {0, 0}},
    selection_box = {{0, 0}, {0, 0}},
    energy_source = {
      type = "electric",
      buffer_capacity = "1GJ",
      usage_priority = "primary-output",
      input_flow_limit = "0W",
      output_flow_limit = "1GW"
    },
    energy_production = "0W",
    energy_usage = "0W",
    gui_mode = "none",
    picture = {filename = "__core__/graphics/empty.png", width = 1, height = 1}
  },
  {
    type = "space-location",
    name = "warp-test-remote-inner",
    hidden = true,
    icon = "__core__/graphics/icons/unknown.png",
    distance = 1000,
    orientation = 0.5
  },
  {
    type = "space-location",
    name = "warp-test-remote-outer",
    hidden = true,
    icon = "__core__/graphics/icons/unknown.png",
    distance = 1100,
    orientation = 0.5
  },
  {
    type = "space-connection",
    name = "warp-test-remote-route",
    from = "warp-test-remote-inner",
    to = "warp-test-remote-outer",
    length = 1000
  }
})
