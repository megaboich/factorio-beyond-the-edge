local circuit_source = data.raw["assembling-machine"]["cryogenic-plant"]
local combinator_source = data.raw["constant-combinator"]["constant-combinator"]
local smoke_animations = require("__base__.prototypes.entity.smoke-animations")
local animation_speed = 0.35
local empty_sprite = {filename = "__core__/graphics/empty.png", width = 1, height = 1}

local function empty_directional_sprites()
  return {
    north = empty_sprite,
    east = empty_sprite,
    south = empty_sprite,
    west = empty_sprite
  }
end

local function static_drive_sprite()
  return {
    filename = "__warp-drive__/graphics/entity/warp-drive/quantum-stabilizer-hr-animation-1.png",
    priority = "high",
    width = 410,
    height = 410,
    scale = 0.5,
    shift = util.by_pixel(0, -16)
  }
end

local function static_drive_directional_sprites()
  local sprite = static_drive_sprite()
  return {
    north = sprite,
    east = table.deepcopy(sprite),
    south = table.deepcopy(sprite),
    west = table.deepcopy(sprite)
  }
end

local function drive_wire_connection_points()
  local point = {
    wire = {
      red = util.by_pixel(-57.44, -61.44),
      green = util.by_pixel(-65.44, -61.44)
    },
    shadow = {
      red = util.by_pixel(-8.44, -18.44),
      green = util.by_pixel(-15.44, -18.44)
    }
  }
  local points = {}
  for index = 1, 4 do
    points[index] = table.deepcopy(point)
  end
  return points
end

local function striped_animation(prefix, blend_mode)
  return {
    width = 410,
    height = 410,
    frame_count = 100,
    stripes = {
      {filename = prefix .. "-1.png", width_in_frames = 8, height_in_frames = 8},
      {filename = prefix .. "-2.png", width_in_frames = 8, height_in_frames = 5}
    },
    animation_speed = animation_speed,
    scale = 0.5,
    shift = util.by_pixel(0, -16),
    blend_mode = blend_mode,
    draw_as_glow = blend_mode ~= nil
  }
end

local function animation_layers()
  return {
    striped_animation("__warp-drive__/graphics/entity/warp-drive/quantum-stabilizer-hr-animation"),
    striped_animation("__warp-drive__/graphics/entity/warp-drive/quantum-stabilizer-hr-emission", "additive"),
    {
      filename = "__warp-drive__/graphics/entity/warp-drive/quantum-stabilizer-hr-shadow.png",
      priority = "high",
      width = 900,
      height = 420,
      frame_count = 1,
      repeat_count = 100,
      animation_speed = animation_speed,
      scale = 0.5,
      shift = util.by_pixel(38, 5),
      draw_as_shadow = true
    }
  }
end

local drive = {
  type = "constant-combinator",
  name = "warp-drive-controller",
  localised_name = {"entity-name.warp-drive"},
  icon = "__warp-drive__/graphics/icons/warp-drive.png",
  icon_size = 64,
  flags = {"placeable-neutral", "placeable-player", "player-creation"},
  minable = {mining_time = 1, result = "warp-drive"},
  max_health = 3000,
  corpse = "nuclear-reactor-remnants",
  dying_explosion = "nuclear-reactor-explosion",
  collision_box = {{-2.8, -2.8}, {2.8, 2.8}},
  selection_box = {{-3, -3}, {3, 3}},
  drawing_box_vertical_extension = 0.5,
  surface_conditions = {{property = "pressure", min = 0, max = 0}},
  item_slot_count = 1,
  sprites = static_drive_directional_sprites(),
  activity_led_sprites = empty_directional_sprites(),
  activity_led_light_offsets = {{0, 0}, {0, 0}, {0, 0}, {0, 0}},
  circuit_wire_connection_points = drive_wire_connection_points(),
  circuit_wire_max_distance = circuit_source.circuit_wire_max_distance,
  draw_copper_wires = false,
  impact_category = "metal-large"
}

local drive_animation = {
  type = "electric-energy-interface",
  name = "warp-drive-animation",
  localised_name = {"entity-name.warp-drive"},
  icon = "__warp-drive__/graphics/icons/warp-drive.png",
  icon_size = 64,
  flags = {"not-on-map", "not-blueprintable", "not-deconstructable", "not-flammable", "not-repairable"},
  hidden = true,
  selectable_in_game = false,
  collision_mask = {layers = {}},
  collision_box = {{0, 0}, {0, 0}},
  selection_box = {{0, 0}, {0, 0}},
  energy_source = {
    type = "electric",
    buffer_capacity = "1J",
    usage_priority = "tertiary",
    input_flow_limit = "0W",
    output_flow_limit = "0W",
    render_no_power_icon = false
  },
  energy_production = "0W",
  energy_usage = "0W",
  gui_mode = "none",
  render_layer = "higher-object-under",
  allow_copy_paste = false,
  continuous_animation = true,
  animation = {layers = animation_layers()}
}

-- Legacy accumulators remain defined so existing saves can migrate their stored energy.
local charge_buffer = {
  type = "accumulator",
  name = "warp-drive-charge-buffer",
  localised_name = {"entity-name.warp-drive"},
  icon = "__warp-drive__/graphics/icons/warp-drive.png",
  icon_size = 64,
  flags = {"not-on-map", "not-blueprintable", "not-deconstructable", "not-flammable", "not-repairable"},
  hidden = true,
  selectable_in_game = false,
  collision_mask = {layers = {}},
  collision_box = {{0, 0}, {0, 0}},
  selection_box = {{0, 0}, {0, 0}},
  max_health = 1,
  energy_source = {
    type = "electric",
    buffer_capacity = "100GJ",
    usage_priority = "tertiary",
    input_flow_limit = "0W",
    output_flow_limit = "0W",
    render_no_power_icon = false
  },
  chargable_graphics = {
    picture = {filename = "__core__/graphics/empty.png", width = 1, height = 1},
    charge_animation = {filename = "__core__/graphics/empty.png", width = 1, height = 1},
    charge_animation_is_looped = true,
    charge_cooldown = 1,
    discharge_animation = {filename = "__core__/graphics/empty.png", width = 1, height = 1},
    discharge_cooldown = 1
  }
}

local charge_buffer_100mj = table.deepcopy(charge_buffer)
charge_buffer_100mj.name = "warp-drive-charge-buffer-100mj"
charge_buffer_100mj.energy_source.buffer_capacity = "100MJ"

local charge_buffer_1gj = table.deepcopy(charge_buffer)
charge_buffer_1gj.name = "warp-drive-charge-buffer-1gj"
charge_buffer_1gj.energy_source.buffer_capacity = "1GJ"

local charge_buffer_10gj = table.deepcopy(charge_buffer)
charge_buffer_10gj.name = "warp-drive-charge-buffer-10gj"
charge_buffer_10gj.energy_source.buffer_capacity = "10GJ"

local support_load = {
  type = "electric-energy-interface",
  name = "warp-drive-support-load",
  localised_name = {"entity-name.warp-drive"},
  icon = "__warp-drive__/graphics/icons/warp-drive.png",
  icon_size = 64,
  flags = {"not-on-map", "not-blueprintable", "not-deconstructable", "not-flammable", "not-repairable"},
  hidden = true,
  selectable_in_game = false,
  collision_mask = {layers = {}},
  collision_box = {{0, 0}, {0, 0}},
  selection_box = {{0, 0}, {0, 0}},
  energy_source = {
    type = "electric",
    buffer_capacity = "1J",
    usage_priority = "tertiary",
    input_flow_limit = "60GW",
    output_flow_limit = "0W",
    render_no_power_icon = false
  },
  energy_production = "0W",
  energy_usage = "1W",
  gui_mode = "none",
  picture = {
    filename = "__core__/graphics/empty.png",
    width = 1,
    height = 1
  }
}

local power_interface = table.deepcopy(support_load)
power_interface.name = "warp-drive-power-interface"
power_interface.energy_source.usage_priority = "secondary-input"

local subspace_smoke = {
  type = "trivial-smoke",
  name = "warp-drive-subspace-smoke",
  animation = smoke_animations.trivial_smoke_fast({
    animation_speed = 0.35,
    scale = 1.4,
    tint = {r = 0.1, g = 0.55, b = 1, a = 0.65}
  }),
  render_layer = "smoke",
  affected_by_wind = false,
  movement_slow_down_factor = 1,
  duration = 40,
  fade_away_duration = 30,
  show_when_smoke_off = true,
  start_scale = 0.45,
  end_scale = 1.4
}

local detector_load = table.deepcopy(charge_buffer)
detector_load.name = "warp-drive-detector-load"
detector_load.energy_source.buffer_capacity = "166.667MJ"
detector_load.energy_source.input_flow_limit = "1GW"

local circuit_output = table.deepcopy(combinator_source)
circuit_output.name = "warp-drive-circuit-output"
circuit_output.localised_name = {"entity-name.warp-drive"}
circuit_output.flags = {"not-on-map", "not-blueprintable", "not-deconstructable", "not-flammable", "not-repairable"}
circuit_output.hidden = true
circuit_output.selectable_in_game = false
circuit_output.collision_mask = {layers = {}}
circuit_output.minable = nil
circuit_output.placeable_by = nil
circuit_output.fast_replaceable_group = nil
circuit_output.next_upgrade = nil
circuit_output.collision_box = {{0, 0}, {0, 0}}
circuit_output.selection_box = {{0, 0}, {0, 0}}
circuit_output.item_slot_count = 4
circuit_output.sprites = empty_directional_sprites()
circuit_output.activity_led_sprites = circuit_output.sprites
circuit_output.activity_led_light_offsets = {{0, 0}, {0, 0}, {0, 0}, {0, 0}}
circuit_output.draw_copper_wires = false
circuit_output.draw_circuit_wires = false

data:extend({
  drive,
  drive_animation,
  power_interface,
  -- Legacy companions can be removed after supported saves no longer contain them.
  support_load,
  detector_load,
  charge_buffer_100mj,
  charge_buffer_1gj,
  charge_buffer_10gj,
  charge_buffer,
  circuit_output,
  subspace_smoke
})
