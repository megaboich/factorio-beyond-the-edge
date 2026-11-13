-- The gate in three forms, all 14x14 on one footprint so each replaces the last in place
-- (scripts/construction.lua):
--   bte-stargate-construction-site   a chest the player fills with the bill of materials
--   bte-stargate-assembling          the gate going up over a minute, through one picture per stage
--   bte-stargate                     the finished gate; cannot be mined or deconstructed, only destroyed
-- Sprites are rendered by tools/sprites (models/stargate*.js): main, shadow, and additive glow-lights.
local construction = require("prototypes.construction")

local site_sprites = "__bte-stargate__/graphics/entity/construction-site/construction-site-"
local assembling_sprites = "__bte-stargate__/graphics/entity/assembling/assembling-"
local gate_sprites = "__bte-stargate__/graphics/entity/stargate/stargate-"

-- The building's centre is one tile south-east of its origin (see `footprint`), so its sprites are too.
local function sprite(path, options)
  options.scale = 0.5
  options.priority = "high"
  options.shift = {1, 1}
  return util.sprite_load(path, options)
end

local function picture(path, glow)
  local layers = {
    sprite(path .. "main", {}),
    sprite(path .. "shadow", {draw_as_shadow = true})
  }
  if glow then
    layers[#layers + 1] = sprite(path .. "glow-lights", {blend_mode = "additive", draw_as_glow = true})
  end
  return {layers = layers}
end

-- One picture per stage; the runtime switches `graphics_variation` as the build progresses. The first
-- stage is the construction site's own picture, so the site does not visibly change when its delivery
-- is complete.
local stage_sprites = {site_sprites, assembling_sprites .. "1-", assembling_sprites .. "2-"}
if #stage_sprites ~= construction.stages then
  error("bte-stargate: construction.stages must match the number of stage pictures")
end
local stage_pictures = {}
for stage, path in ipairs(stage_sprites) do
  stage_pictures[stage] = picture(path, false)
end

-- The 2x2 build grid snaps a 14-tile entity's origin to even coordinates, but the layout wants the
-- building centred on odd ones: rails sit at odd coordinates, and four tiles of platform, a rail, a
-- two-tile gap, a rail, and four more tiles then fall on whole rail cells with the building's edges on
-- cell edges. So the boxes (and sprites) are offset by one tile each way from the origin, which the
-- runtime must allow for: the building's centre is its position plus (1, 1).
local footprint = {
  collision_box = {{-5.9, -5.9}, {7.9, 7.9}},
  selection_box = {{-6, -6}, {8, 8}},
  -- The ring rises about nine tiles above the platform.
  drawing_box_vertical_extension = 9
}

local function building(properties)
  for key, value in pairs(footprint) do
    properties[key] = value
  end
  -- The 2x2 grid rails use.
  properties.build_grid_size = 2
  properties.corpse = "big-remnants"
  properties.dying_explosion = "big-explosion"
  properties.impact_category = "stone"
  properties.resistances = {
    {type = "impact", percent = 100},
    {type = "fire", percent = 80},
    {type = "acid", percent = 50}
  }
  return properties
end

data:extend({
  building({
    type = "container",
    name = "bte-stargate-construction-site",
    icon = "__bte-stargate__/graphics/icons/construction-kit.png",
    icon_size = 64,
    flags = {"placeable-neutral", "player-creation"},
    minable = {mining_time = 1, result = "bte-stargate-construction-kit"},
    max_health = 3000,
    -- One filtered slot per stack of each material; data-final-fixes.lua sets the size and filters
    -- once every mod has had its say on stack sizes.
    inventory_size = 1,
    inventory_type = "with_filters_and_bar",
    quality_affects_inventory_size = false,
    open_sound = {filename = "__base__/sound/machine-open.ogg", volume = 0.5},
    close_sound = {filename = "__base__/sound/machine-close.ogg", volume = 0.5},
    picture = picture(site_sprites, false)
  }),
  building({
    type = "simple-entity-with-owner",
    name = "bte-stargate-assembling",
    icon = "__bte-stargate__/graphics/icons/construction-kit.png",
    icon_size = 64,
    flags = {"placeable-neutral", "player-creation", "get-by-unit-number", "not-deconstructable",
      "not-blueprintable", "not-rotatable", "not-upgradable"},
    max_health = 5000,
    random_variation_on_create = false,
    pictures = stage_pictures
  }),
  building({
    type = "simple-entity-with-owner",
    name = "bte-stargate",
    icon = "__bte-stargate__/graphics/icons/stargate.png",
    icon_size = 64,
    flags = {"placeable-neutral", "player-creation", "get-by-unit-number", "not-deconstructable",
      "not-blueprintable", "not-rotatable", "not-upgradable"},
    max_health = 20000,
    random_variation_on_create = false,
    picture = picture(gate_sprites, true)
  })
})
