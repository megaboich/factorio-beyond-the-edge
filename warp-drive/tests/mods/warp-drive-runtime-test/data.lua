local function interface(name, usage_priority)
  return {
    type = "electric-energy-interface",
    name = name,
    icon = "__base__/graphics/icons/accumulator.png",
    icon_size = 64,
    hidden = true,
    collision_mask = {layers = {}},
    collision_box = {{0, 0}, {0, 0}},
    selection_box = {{0, 0}, {0, 0}},
    energy_source = {
      type = "electric",
      buffer_capacity = "1J",
      usage_priority = usage_priority,
      input_flow_limit = "60GW",
      output_flow_limit = "0W"
    },
    energy_production = "0W",
    energy_usage = "1W",
    gui_mode = "none",
    picture = {filename = "__core__/graphics/empty.png", width = 1, height = 1}
  }
end

if not data.raw["constant-combinator"]["warp-drive-controller"] then
  error("WARP_TEST_FAIL: GUI title entity sprite prototype is missing")
end

local source = interface("warp-drive-test-power-source", "primary-output")
source.energy_production = "60GW"
source.energy_usage = "0W"
source.energy_source.buffer_capacity = "1GJ"
source.energy_source.input_flow_limit = "0W"
source.energy_source.output_flow_limit = "60GW"

local ship_load = interface("warp-drive-test-ship-load", "secondary-input")
ship_load.energy_source.buffer_capacity = "1GJ"

data:extend({
  source,
  ship_load
})
