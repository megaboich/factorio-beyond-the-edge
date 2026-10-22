local pipe_pictures = nil
if data.raw["assembling-machine"] and data.raw["assembling-machine"]["assembling-machine-3"] then
  local source_fluid_boxes = data.raw["assembling-machine"]["assembling-machine-3"].fluid_boxes
  if source_fluid_boxes and source_fluid_boxes[1] then
    pipe_pictures = table.deepcopy(source_fluid_boxes[1].pipe_picture)
  end
end

local circuit_source = data.raw["assembling-machine"]["cryogenic-plant"]
local circuit_connector = table.deepcopy(circuit_source.circuit_connector)
local circuit_wire_max_distance = circuit_source.circuit_wire_max_distance

local animation_speed = (0.5 / 4) / 2

local growth_facility = {
  type = "assembling-machine",
  name = "bte-growth-facility",
  icon = "__bte-spacelab__/graphics/icons/growth-facility.png",
  icon_size = 64,
  flags = {"placeable-neutral", "placeable-player", "player-creation"},
  minable = {mining_time = 0.2, result = "bte-growth-facility"},
  max_health = 1500,
  corpse = "big-remnants",
  dying_explosion = "medium-explosion",
  alert_icon_shift = util.by_pixel(0, -12),
  collision_box = {{-4.3, -4.3}, {4.3, 4.3}},
  selection_box = {{-4.5, -4.5}, {4.5, 4.5}},
  drawing_box_vertical_extension = 0.4,
  circuit_connector = circuit_connector,
  circuit_wire_max_distance = circuit_wire_max_distance,
  resistances = {
    { type = "impact", percent = 10 }
  },
  fluid_boxes = {
    {
      production_type = "input",
      pipe_picture = pipe_pictures,
      pipe_covers = pipecoverspictures(),
      volume = 1000,
      pipe_connections = {
        {flow_direction = "input-output", position = {-4, -2}, direction = defines.direction.west},
        {flow_direction = "input-output", position = {4, -2}, direction = defines.direction.east}
      },
      secondary_draw_orders = { north = -1 }
    },
    {
      production_type = "input",
      pipe_picture = pipe_pictures,
      pipe_covers = pipecoverspictures(),
      volume = 1000,
      pipe_connections = {
        {flow_direction = "input-output", position = {-4, 0}, direction = defines.direction.west},
        {flow_direction = "input-output", position = {4, 0}, direction = defines.direction.east}
      },
      secondary_draw_orders = { north = -1 }
    },
    {
      production_type = "input",
      pipe_picture = pipe_pictures,
      pipe_covers = pipecoverspictures(),
      volume = 1000,
      pipe_connections = {
        {flow_direction = "input-output", position = {-4, 2}, direction = defines.direction.west},
        {flow_direction = "input-output", position = {4, 2}, direction = defines.direction.east}
      },
      secondary_draw_orders = { north = -1 }
    }
  },
  open_sound = {filename = "__base__/sound/machine-open.ogg", volume = 0.5},
  close_sound = {filename = "__base__/sound/machine-close.ogg", volume = 0.5},
  impact_category = "metal-large",
  working_sound = {
    apparent_volume = 1.5,
    idle_sound = {
      filename = "__base__/sound/idle1.ogg",
      volume = 0.6
    },
    sound = {
      {
        filename = "__base__/sound/chemical-plant.ogg",
        volume = 0.8
      }
    }
  },
  graphics_set = {
    animation = {
      layers = {
        {
          filename = "__bte-spacelab__/graphics/entity/growth-facility/growth-facility.png",
          priority = "high",
          width = 4032 / 7,
          height = 3360 / 5,
          frame_count = 32,
          line_length = 7,
          shift = util.by_pixel(0, -24),
          animation_speed = animation_speed,
          scale = 0.5
        },
        {
          draw_as_shadow = true,
          filename = "__bte-spacelab__/graphics/entity/growth-facility/growth-facility-shadow.png",
          priority = "high",
          width = 618,
          height = 570,
          frame_count = 1,
          line_length = 1,
          repeat_count = 32,
          shift = util.by_pixel(8, 2),
          animation_speed = animation_speed,
          scale = 0.5
        }
      }
    },
    working_visualisations = {
      {
        apply_recipe_tint = "primary",
        effect = "flicker",
        fadeout = true,
        animation = {
          filename = "__space-age__/graphics/entity/biolab/biolab-lights.png",
          blend_mode = "additive",
          draw_as_glow = true,
          width = 326,
          height = 362,
          frame_count = 32,
          line_length = 8,
          animation_speed = 0.2,
          shift = util.by_pixel(0, -18),
          scale = 1.08
        }
      },
      {
        apply_recipe_tint = "secondary",
        effect = "flicker",
        fadeout = true,
        animation = {
          filename = "__space-age__/graphics/entity/biolab/biolab-lights.png",
          blend_mode = "additive",
          draw_as_glow = true,
          width = 326,
          height = 362,
          frame_count = 32,
          line_length = 8,
          animation_speed = 0.2,
          shift = util.by_pixel(0, -18),
          scale = 0.57
        }
      },
      {
        effect = "uranium-glow",
        light = {intensity = 0.25, size = 18, shift = {0, 0}, color = {r = 0.7, g = 0.8, b = 1}}
      },
      {
        apply_recipe_tint = "primary",
        effect = "flicker",
        fadeout = true,
        light = {intensity = 1.35, size = 18, shift = {0, 0}, color = {r = 1, g = 1, b = 1}}
      },
      {
        apply_recipe_tint = "secondary",
        effect = "flicker",
        fadeout = true,
        light = {intensity = 0.675, size = 10, shift = {0, 0}, color = {r = 1, g = 1, b = 1}}
      }
    }
  },
  crafting_categories = {"bte-spacelab-growth"},
  crafting_speed = 4,
  energy_source = {
    type = "electric",
    usage_priority = "secondary-input",
    emissions_per_minute = { pollution = 4 }
  },
  energy_usage = "40000kW",
  module_slots = 8,
  allowed_effects = {"consumption"}
}

data:extend({growth_facility})
