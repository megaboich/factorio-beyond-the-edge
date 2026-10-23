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
-- Sheets rendered by tools/sprites (models/growth-facility.js). Each layer's .lua carries the
-- width, height, shift, and line_length that util.sprite_load reads, as vanilla graphics do.
local sprite_path = "__bte-spacelab__/graphics/entity/growth-facility/growth-facility-"
local frame_count = 32

local function sprite_layer(name, options)
  options.frame_count = options.frame_count or frame_count
  options.animation_speed = animation_speed
  options.scale = 0.5
  return util.sprite_load(sprite_path .. name, options)
end

-- Each growth recipe owns one recipe tint channel, which it sets to white while the others are
-- transparent (growth_recipe_tints in recipes.lua). Its specimens, fluid tint, and light use that
-- channel, so only the running recipe shows. Contents stay drawn, frozen, while the machine idles.
-- Specimens grow through their life cycle over 8 building loops: 64 frames at a quarter of the
-- building's frame rate. Fluid colours match VARIANT_COLORS in tools/sprites/models/growth-facility.js.
local specimen_frames = 64
local specimen_speed = animation_speed * specimen_frames / (8 * frame_count)
local recipe_channels = {
  {name = "yumako", channel = "primary", fluid = {0.72, 0.38, 0.31}, light = {r = 0.85, g = 0.25, b = 0.15}},
  {name = "jellynut", channel = "secondary", fluid = {0.78, 0.58, 0.79}, light = {r = 0.9, g = 0.45, b = 0.9}},
  {name = "biter-egg", channel = "tertiary", fluid = {0.86, 0.65, 0.37}, light = {r = 1, g = 0.6, b = 0.2}},
  {name = "pentapod-egg", channel = "quaternary", fluid = {0.54, 0.77, 0.45}, light = {r = 0.45, g = 0.95, b = 0.3}}
}
local no_recipe_tint = {
  primary = {0, 0, 0, 0}, secondary = {0, 0, 0, 0}, tertiary = {0, 0, 0, 0}, quaternary = {0, 0, 0, 0}
}

-- The fluid, then the light from each tank's base and surface (neutral additive glows tinted with
-- the fluid colour), then the specimens over them as soft silhouettes, so the glow does not wash
-- them out. This matches the order the model renders and previews them in.
local working_visualisations = {}
for _, recipe in pairs(recipe_channels) do
  table.insert(working_visualisations, {
    apply_recipe_tint = recipe.channel,
    always_draw = true,
    animation = sprite_layer("fluid", {tint = recipe.fluid, draw_as_glow = true})
  })
end
for _, glow in pairs({"bottom", "top"}) do
  for _, recipe in pairs(recipe_channels) do
    table.insert(working_visualisations, {
      apply_recipe_tint = recipe.channel,
      always_draw = true,
      animation = sprite_layer("glow-vat-" .. glow, {
        frame_count = 1, tint = recipe.fluid, blend_mode = "additive", draw_as_glow = true
      })
    })
  end
end
for _, recipe in pairs(recipe_channels) do
  local specimens = sprite_layer("specimens-" .. recipe.name, {frame_count = specimen_frames, draw_as_glow = true})
  specimens.animation_speed = specimen_speed
  table.insert(working_visualisations, {apply_recipe_tint = recipe.channel, always_draw = true, animation = specimens})
end
table.insert(working_visualisations, {
  -- Status lamps, consoles, grow lights, and the roof beacon.
  fadeout = true,
  animation = sprite_layer("glow-lights", {blend_mode = "additive", draw_as_glow = true})
})
table.insert(working_visualisations, {
  effect = "uranium-glow",
  light = {intensity = 0.25, size = 18, shift = {0, 0}, color = {r = 0.7, g = 0.8, b = 1}}
})
for _, recipe in pairs(recipe_channels) do
  table.insert(working_visualisations, {
    apply_recipe_tint = recipe.channel,
    effect = "flicker",
    fadeout = true,
    light = {intensity = 1, size = 18, shift = {0, 0}, color = recipe.light}
  })
end

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
  drawing_box_vertical_extension = 1.8,
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
        sprite_layer("main", {priority = "high"}),
        sprite_layer("shadow", {priority = "high", frame_count = 1, repeat_count = frame_count, draw_as_shadow = true})
      }
    },
    default_recipe_tint = no_recipe_tint,
    recipe_not_set_tint = no_recipe_tint,
    working_visualisations = working_visualisations
  },
  crafting_categories = {"bte-spacelab-growth"},
  crafting_speed = 4,
  energy_source = {
    type = "electric",
    usage_priority = "secondary-input",
    emissions_per_minute = { pollution = 4 }
  },
  energy_usage = "100MW",
  module_slots = 8,
  allowed_effects = {"consumption"}
}

data:extend({growth_facility})
