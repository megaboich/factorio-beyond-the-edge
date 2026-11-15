-- The gate in three forms, all 14x14 on one footprint so each replaces the last in place
-- (scripts/construction.lua):
--   bte-stargate-construction-site   a chest the player fills with the bill of materials
--   bte-stargate-assembling          the gate going up over a minute, through one picture per stage
--   bte-stargate                     the finished gate; cannot be mined or deconstructed, only destroyed
-- Sprites are rendered by tools/sprites (models/stargate*.js): main, shadow, and additive glow-lights,
-- and for the finished gate the animated glow-veil shown while the portal is open.
--
-- The finished gate is an assembling machine running a hidden recipe with no ingredients or results
-- (prototypes/recipes.lua) on a void energy source. That gives it a circuit connection with the
-- standard enable condition, and scripts/gate.lua stops it working while the portal is closed. Its power is a hidden
-- companion, bte-stargate-capacitor: an electric energy interface over the same footprint whose
-- buffer must be full before the gate opens and which draws the open portal's upkeep. Its building
-- and status lights are another companion, bte-stargate-body (cyan, or red while short of power),
-- and the open portal's veil two more (bte-stargate-veil, bte-stargate-veil-top).
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
local stage_sprites = {site_sprites}
for stage = 1, 5 do
  stage_sprites[stage + 1] = assembling_sprites .. stage .. "-"
end
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

-- The veil: VEIL_FRAMES frames that loop once every 64 ticks, matching models/stargate.js.
local VEIL_FRAMES = 16

-- At the foot of the west tower's front face; one per direction, though the gate never rotates.
local connector = {
  variation = 26, main_offset = util.by_pixel(-150, 150), shadow_offset = util.by_pixel(-146, 154), show_shadow = true
}
local gate_connector = circuit_connector_definitions.create_vector(universal_connector_template,
  {connector, connector, connector, connector})

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
    type = "assembling-machine",
    name = "bte-stargate",
    icon = "__bte-stargate__/graphics/icons/stargate.png",
    icon_size = 64,
    flags = {"placeable-neutral", "player-creation", "get-by-unit-number", "not-deconstructable",
      "not-blueprintable", "not-rotatable", "not-upgradable"},
    max_health = 20000,
    -- A building's mask without `player` and `is_object`, the two layers characters collide on, so they
    -- walk through the footprint and can step into the portal (scripts/gate.lua).
    collision_mask = {layers = {item = true, meltable = true, object = true, water_tile = true,
      is_lower_object = true}},
    crafting_categories = {"bte-stargate-portal"},
    fixed_recipe = "bte-stargate-portal",
    crafting_speed = 1,
    -- Powered through bte-stargate-capacitor instead.
    energy_usage = "1W",
    energy_source = {type = "void"},
    module_slots = 0,
    allowed_effects = {},
    effect_receiver = {uses_module_effects = false, uses_beacon_effects = false, uses_surface_effects = false},
    show_recipe_icon = false,
    show_recipe_icon_on_map = false,
    circuit_connector = gate_connector,
    circuit_wire_max_distance = 9,
    open_sound = {filename = "__base__/sound/machine-open.ogg", volume = 0.5},
    close_sound = {filename = "__base__/sound/machine-close.ogg", volume = 0.5},
    -- People and vehicles move through the gate, so its picture is split (models/stargate.js): the
    -- concrete floor is the integration patch, drawn under everything (on `floor`, so rails laid
    -- through the gate later draw over it), and the building itself with its lights is
    -- bte-stargate-body, a companion standing on the ring's line, as is the veil. The gate keeps the shadow.
    graphics_set = {
      animation = {layers = {sprite(gate_sprites .. "shadow", {draw_as_shadow = true})}},
      integration_patch = sprite(gate_sprites .. "floor", {}),
      integration_patch_render_layer = "floor"
    }
  })
})

-- Invisible blocks over the gate's machinery, placed by scripts/gate.lua: the west and east strips
-- (capacitor banks, towers, housings, and the ring's sides), the control cabinet at the front left, and
-- the capacitor rack at the front right. The rest, the lanes through the ring and the floor in front
-- of and behind it, is open.
--
-- They sit on their own collision layer, which data-final-fixes.lua adds to every character and
-- spider leg, rather than on `player`: cars and tanks collide on `player` too, and must be free to
-- drive through.
local function barrier(name, half_width, half_depth)
  return {
    type = "simple-entity-with-owner",
    name = name,
    icon = "__bte-stargate__/graphics/icons/stargate.png",
    icon_size = 64,
    flags = {"placeable-off-grid", "not-on-map", "not-blueprintable", "not-deconstructable", "not-selectable-in-game",
      "not-upgradable", "no-copy-paste", "not-in-kill-statistics"},
    hidden = true,
    selectable_in_game = false,
    collision_box = {{-half_width, -half_depth}, {half_width, half_depth}},
    collision_mask = {layers = {["bte-stargate-barrier"] = true}},
    picture = util.empty_sprite()
  }
end

-- Sizes match the offsets in scripts/gate.lua (BARRIERS).
data:extend({
  {type = "collision-layer", name = "bte-stargate-barrier"},
  barrier("bte-stargate-side-block", 1.975, 5.275),
  barrier("bte-stargate-cabinet-block", 0.8, 0.5),
  barrier("bte-stargate-rack-block", 0.8, 1.3)
})

-- The gate's building and status lights, placed by scripts/gate.lua on the ring's line, BODY tiles
-- south of the gate's centre. Factorio draws objects in order of position, so a character behind
-- the ring is drawn before this and passes under the whole ring, lights and all, and one in front is
-- drawn after it and covers it; with the picture on the gate itself, sorted by the gate's position
-- three tiles north of the ring, characters between the two were drawn over the ring.
--
-- Spidertron bodies are drawn later than every ordinary object (render layer `under-elevated`), so
-- the ring's upper arc and its lights are drawn once more by bte-stargate-top, on `elevated-object`,
-- as Space Age draws elevated rails and the trains on them: over spidertrons wherever they stand.
-- Nobody in front of the ring reaches the arc on screen (models/stargate.js, TOP), so characters
-- are unaffected. The body's lights leave out the arc's, so none is drawn twice.
--
-- Variation 1 of each has cyan lights, 2 red (scripts/gate.lua sets graphics_variation).
local BODY = 2
local function companion_picture(picture, lights)
  local layers = {}
  for _, layer in pairs({
    {picture, {}},
    {lights, {blend_mode = "additive", draw_as_glow = true}}
  }) do
    local options = layer[2]
    options.scale, options.priority, options.shift = 0.5, "high", {0, -BODY}
    layers[#layers + 1] = util.sprite_load(gate_sprites .. layer[1], options)
  end
  return {layers = layers}
end
local function companion(name, render_layer, picture, lights)
  local entity = {
    type = "simple-entity-with-owner",
    name = name,
    icon = "__bte-stargate__/graphics/icons/stargate.png",
    icon_size = 64,
    localised_name = {"entity-name.bte-stargate"},
    flags = {"placeable-off-grid", "not-on-map", "not-blueprintable", "not-deconstructable", "not-selectable-in-game",
      "not-upgradable", "no-copy-paste", "not-in-kill-statistics"},
    hidden = true,
    selectable_in_game = false,
    -- Collides with nothing; the box only tells the renderer how far the picture reaches, the whole
    -- footprint around a position BODY tiles south of its centre.
    collision_box = {{-7, -7 - BODY}, {7, 7 - BODY}},
    collision_mask = {layers = {}},
    drawing_box_vertical_extension = 9,
    render_layer = render_layer,
    random_variation_on_create = false
  }
  if lights == "track" then
    -- The station track (scripts/railway.lua): variation 1 one track, 2 and 3 two tracks with
    -- chevrons for the "right" and "left" layouts, pointing the way each lane's trains run.
    local function track(name)
      return util.sprite_load(gate_sprites .. name, {scale = 0.5, priority = "high", shift = {0, -BODY}})
    end
    entity.pictures = {
      {layers = {track("rails-single")}},
      {layers = {track("rails-double"), track("chevrons-right")}},
      {layers = {track("rails-double"), track("chevrons-left")}}
    }
  elseif lights and picture == "main" then
    -- Cyan and red, for no station track, one track, and two tracks: the station's pictures have the
    -- track cut out of the building where it runs over the ring's lower arc, and their lights hidden
    -- behind it. Variation (mode * 2) + 1 is cyan, + 2 red, mode 0 none, 1 one track, 2 two tracks.
    entity.pictures = {}
    for _, suffix in pairs({"", "-single", "-double"}) do
      entity.pictures[#entity.pictures + 1] = companion_picture(picture .. suffix, lights .. suffix)
      entity.pictures[#entity.pictures + 1] = companion_picture(picture .. suffix, lights:gsub("^glow%-lights", "glow-lights-red") .. suffix)
    end
  elseif lights then
    entity.pictures = {companion_picture(picture, lights), companion_picture(picture, lights:gsub("^glow%-lights", "glow-lights-red"))}
  else
    -- The open portal's veil, VEIL_FRAMES frames looping once every 64 ticks (models/stargate.js).
    entity.animations = {util.sprite_load(gate_sprites .. picture, {
      frame_count = VEIL_FRAMES, animation_speed = VEIL_FRAMES / 64, blend_mode = "additive", draw_as_glow = true,
      scale = 0.5, priority = "high", shift = {0, -BODY}
    })}
  end
  return entity
end
-- The veil is split at the same height as the ring: its lower part sorts with characters like the
-- body, so legs and people behind the ring are drawn under it, and its upper part is drawn with the
-- upper arc over spidertron bodies. scripts/gate.lua places both only while the portal is open.
data:extend({
  companion("bte-stargate-body", "object", "main", "glow-lights"),
  companion("bte-stargate-top", "elevated-object", "top", "glow-lights-high"),
  companion("bte-stargate-veil", "object", "glow-veil"),
  companion("bte-stargate-veil-top", "elevated-object", "glow-veil-high"),
  -- Above the gate's floor and the ground, under trains and everything else.
  companion("bte-stargate-tracks", "floor-mechanics", nil, "track")
})

-- The portal forming and collapsing (models/stargate.js), played once by scripts/gate.lua as it opens
-- and closes, each split at the ring's centre like the veil. Each frame lasts four ticks; the opening
-- holds its last frame two more, to cover the wait for the veil companions (Gate.update, 5 ticks).
local transitions = {}
for _, spec in pairs({{"opening", 30, 2}, {"closing", 18, 0}}) do
  local name, frames, hold = spec[1], spec[2], spec[3]
  for _, part in pairs({"", "-high"}) do
    local animation = sprite(gate_sprites .. "glow-" .. name .. part, {
      frame_count = frames, blend_mode = "additive", draw_as_glow = true
    })
    animation.type = "animation"
    animation.name = "bte-stargate-" .. name .. part
    animation.frame_sequence = {}
    for frame = 1, frames + hold do
      animation.frame_sequence[frame] = math.min(frame, frames)
    end
    transitions[#transitions + 1] = animation
  end
end
data:extend(transitions)

-- The veil's reaction to a traveller: PASSAGE_FRAMES frames over TRANSIT_TICKS, drawn once over the
-- open gate by scripts/transfer.lua (models/stargate.js, glow-passage).
local PASSAGE_FRAMES = 32
local passage = sprite(gate_sprites .. "glow-passage", {
  frame_count = PASSAGE_FRAMES,
  blend_mode = "additive",
  draw_as_glow = true
})
passage.type = "animation"
passage.name = "bte-stargate-passage"
-- The same ripples converging, for a traveller stepping out of the partner gate.
local arrival = table.deepcopy(passage)
arrival.name = "bte-stargate-arrival"
arrival.frame_sequence = {}
for frame = PASSAGE_FRAMES, 1, -1 do
  arrival.frame_sequence[#arrival.frame_sequence + 1] = frame
end
data:extend({passage, arrival})

-- One train carriage passing the veil (models/stargate.js, glow-splash): SPLASH_FRAMES frames at two
-- ticks each, drawn once at the carriage's lane by scripts/railway.lua as it vanishes or appears.
local SPLASH_FRAMES = 32
local splash = sprite(gate_sprites .. "glow-splash", {
  frame_count = SPLASH_FRAMES,
  blend_mode = "additive",
  draw_as_glow = true
})
splash.type = "animation"
splash.name = "bte-stargate-splash"
data:extend({splash})

-- The gate's power: a hidden electric energy interface over the whole footprint, so any pole whose
-- supply area reaches the gate powers it. The gate's store (the `bte-stargate-power` mod-data
-- capacity) is kept by scripts/gate.lua, which draws through this interface as an ordinary consumer with an
-- adaptive request (50 MW steps) and empties it into the store every few ticks.
data:extend({
  {
    type = "electric-energy-interface",
    name = "bte-stargate-capacitor",
    icon = "__bte-stargate__/graphics/icons/stargate.png",
    icon_size = 64,
    localised_name = {"entity-name.bte-stargate"},
    flags = {"placeable-off-grid", "not-on-map", "not-blueprintable", "not-deconstructable", "not-selectable-in-game",
      "not-upgradable", "no-copy-paste", "not-in-kill-statistics"},
    hidden = true,
    selectable_in_game = false,
    collision_box = {{-6.9, -6.9}, {6.9, 6.9}},
    collision_mask = {layers = {}},
    energy_source = {
      type = "electric",
      usage_priority = "secondary-input",
      buffer_capacity = "1J",
      input_flow_limit = "1250MW",
      output_flow_limit = "0W"
    },
    energy_usage = "0W",
    picture = util.empty_sprite()
  },
  {
    type = "mod-data",
    name = "bte-stargate-power",
    -- The gate's power, in joules and watts (docs/power.md): the store, which must be full to
    -- open; the open portal's upkeep; the most a closed gate charges at, and the most an open one
    -- refills at beyond its upkeep (each plus the leak).
    data = {capacity = 10e9, upkeep = 1e9, charge_rate = 1e9, refill = 200e6}
  }
})

-- Positional sounds, from resources/audio/generate.py.
for _, name in pairs({"open", "close", "depart", "arrive", "car-in", "car-out"}) do
  data:extend({{
    type = "sound",
    name = "bte-stargate-" .. name,
    filename = "__bte-stargate__/resources/audio/stargate-" .. name .. ".ogg",
    volume = 0.8,
    audible_distance_modifier = 1.5
  }})
end
