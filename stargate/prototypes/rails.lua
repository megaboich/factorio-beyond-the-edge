-- The gate's train station mode (scripts/railway.lua): plain vanilla rails laid through the lanes from
-- the gate's south edge to the ring, where they seem to end, hidden rails on behind it, and a hidden train stop beside the departure
-- lane that names the gate in train schedules. Both are placed and removed by the script only.
--
-- The rail is the vanilla straight rail, pictures and all, on the `rail` collision layer alone: the
-- gate's own mask (item, object, ...) would otherwise reject it, while player rails, which also use
-- `rail`, still cannot be built over it and join it at the gate's edge like any other rail.
local rail = table.deepcopy(data.raw["straight-rail"]["straight-rail"])
rail.name = "bte-stargate-rail"
rail.localised_name = {"entity-name.straight-rail"}
rail.flags = {"placeable-neutral", "player-creation", "building-direction-8-way", "not-blueprintable",
  "not-deconstructable", "not-upgradable", "no-copy-paste", "not-in-kill-statistics"}
rail.minable = nil
rail.placeable_by = nil
rail.hidden = true
rail.selectable_in_game = false
rail.collision_mask = {layers = {rail = true}}
rail.corpse = nil
rail.fast_replaceable_group = nil
rail.next_upgrade = nil
-- Never drawn: the gate draws its own track (bte-stargate-tracks, prototypes/entities.lua) on a ramp
-- that the game's rails, below the gate's floor, could not follow. `zero` is under the ground.
rail.pictures.render_layers = {stone_path_lower = "zero", stone_path = "zero", tie = "zero", screw = "zero", metal = "zero"}

-- The same track behind the ring, where trains drive on until each carriage is through the veil and
-- where arrivals appear.
local hidden = table.deepcopy(rail)
hidden.name = "bte-stargate-rail-hidden"
hidden.pictures.render_layers = {stone_path_lower = "zero", stone_path = "zero", tie = "zero", screw = "zero", metal = "zero"}

-- The station: invisible, with no collision box, since it stands inside the gate's machinery. The gate
-- window opens its train stop window (scripts/gui.lua).
local stop = table.deepcopy(data.raw["train-stop"]["train-stop"])
stop.name = "bte-stargate-station"
stop.localised_name = {"entity-name.bte-stargate-station"}
stop.flags = {"placeable-neutral", "player-creation", "not-blueprintable", "not-deconstructable",
  "not-upgradable", "no-copy-paste", "not-in-kill-statistics"}
stop.minable = nil
stop.placeable_by = nil
stop.hidden = true
stop.selectable_in_game = false
stop.collision_mask = {layers = {}}
stop.fast_replaceable_group = nil
stop.next_upgrade = nil
stop.corpse = nil
stop.animations = util.empty_animation()
stop.top_animations = util.empty_animation()
stop.rail_overlay_animations = util.empty_animation()
stop.light1 = nil
stop.light2 = nil
stop.drawing_boxes = nil
stop.water_reflection = nil
stop.working_sound = nil

data:extend({rail, hidden, stop})
