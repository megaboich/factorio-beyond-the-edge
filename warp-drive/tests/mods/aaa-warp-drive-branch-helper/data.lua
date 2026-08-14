-- A deeper disconnected route must not replace the Shattered Planet as the destination for
-- platforms in the vanilla route graph. Its large starmap radii reproduce that modded-map
-- edge case in both research-branch runs.
data:extend({
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
