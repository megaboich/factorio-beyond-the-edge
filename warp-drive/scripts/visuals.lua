-- Drive-core overlays: the state-dependent part of the Warp Drive's graphics.
--
-- The controller draws the static hull and the animation companion its status lamps. The rings,
-- core, and energy effects inside and around the column change with the drive's state, which an
-- entity animation cannot follow, so they are LuaRendering animations on the controller: one
-- interior (normal blending) and one glow (additive) object per state. Each 10-tick update keeps
-- them matching the record; the game destroys them with the controller.
--
-- Sheets and frame counts come from tools/sprites/models/warp-drive.js, where one 32-frame loop
-- lasts 64 ticks (0.5 frames per tick).
local Visuals = {}

local PREFIX = "bte-warp-drive-"
local RENDER_LAYER = "higher-object-under"
local LOOP_SPEED = 0.5
-- Frames and base speed of each state's overlays; a single-frame interior holds still. Tachyon
-- detection is the charging animation in green.
local STATES = {
  standby = {frames = 32, speed = LOOP_SPEED / 2},
  detecting = {frames = 32, speed = LOOP_SPEED},
  charging = {frames = 32, speed = LOOP_SPEED},
  -- The one-shot pulse matches warp-activation.ogg: 30 frames over 90 ticks.
  activation = {frames = 30, speed = 30 / 90},
  warp = {frames = 32, speed = LOOP_SPEED}
}
local ACTIVATION_TICKS = 90
-- Charging and detecting run from half to double their base speed and brighten as the level rises.
local CHARGING_MIN_SPEED = 0.5
local CHARGING_MAX_SPEED = 2
local CHARGING_MIN_GLOW = 0.45
-- Speed or brightness changes smaller than this are not worth reissuing.
local CHANGE_TOLERANCE = 0.02

local function destroy_objects(record)
  for _, field in pairs({"visual_interior", "visual_glow"}) do
    local object = record[field]
    if object and object.valid then
      object.destroy()
    end
    record[field] = nil
  end
end

--- Removes the overlays and forgets their state, so the next update recreates them; used on
--- removal and after configuration changes, which may replace the animation prototypes.
function Visuals.reset(record)
  if not record then
    return
  end
  destroy_objects(record)
  record.visual_state = nil
  record.visual_speed = nil
  record.visual_glow_level = nil
  record.visual_activation_until = nil
end

local function wanted_state(record)
  if record.state == "warp" then
    if record.visual_activation_until and game.tick < record.visual_activation_until then
      return "activation"
    end
    return "warp"
  elseif record.state == "charging" or record.state == "detecting" then
    return record.state
  end
  return "standby"
end

-- LuaRendering shows frame (tick * speed + offset) modulo the frame count. Keeping the frame at
-- `tick` where it was when the speed changes avoids a jump.
local function offset_for(frame, speed, frames)
  return (frame - game.tick * speed) % frames
end

local function draw(record, state, suffix, speed, offset, tint)
  local entity = record.entity
  return rendering.draw_animation({
    animation = PREFIX .. state .. "-" .. suffix,
    target = entity,
    surface = entity.surface,
    render_layer = RENDER_LAYER,
    animation_speed = speed,
    animation_offset = offset,
    tint = tint
  })
end

local function glow_tint(level)
  return {r = level, g = level, b = level, a = level}
end

--- Brings the overlays in line with the record's state. `level` (0 to 1) is charging progress,
--- or detector power while researching; it speeds up and brightens the charging or detecting overlay.
function Visuals.update(record, level)
  local entity = record.entity
  if not entity or not entity.valid then
    return
  end
  local previous = record.visual_state
  if record.state == "warp" and (previous == "standby" or previous == "charging") then
    record.visual_activation_until = game.tick + ACTIVATION_TICKS
  elseif record.state ~= "warp" then
    record.visual_activation_until = nil
  end
  local state = wanted_state(record)
  local config = STATES[state]
  local speed = config.speed
  local glow_level = 1
  if state == "charging" or state == "detecting" then
    level = math.max(0, math.min(1, level or 0))
    speed = config.speed * (CHARGING_MIN_SPEED + (CHARGING_MAX_SPEED - CHARGING_MIN_SPEED) * level)
    glow_level = CHARGING_MIN_GLOW + (1 - CHARGING_MIN_GLOW) * level
  end

  local valid = record.visual_interior and record.visual_interior.valid
    and record.visual_glow and record.visual_glow.valid
  if state ~= previous or not valid then
    destroy_objects(record)
    -- The activation starts on its first frame; loops start wherever the tick puts them.
    local offset = state == "activation" and offset_for(0, speed, config.frames) or 0
    record.visual_interior = draw(record, state, "interior", speed, offset)
    record.visual_glow = draw(record, state, "glow", speed, offset, glow_tint(glow_level))
    record.visual_state = state
    record.visual_speed = speed
    record.visual_glow_level = glow_level
    return
  end
  if math.abs(speed - record.visual_speed) > CHANGE_TOLERANCE * record.visual_speed then
    local glow = record.visual_glow
    local frame = game.tick * glow.animation_speed + glow.animation_offset
    local offset = offset_for(frame, speed, config.frames)
    for _, object in pairs({record.visual_interior, glow}) do
      object.animation_speed = speed
      object.animation_offset = offset
    end
    record.visual_speed = speed
  end
  if math.abs(glow_level - record.visual_glow_level) > CHANGE_TOLERANCE then
    record.visual_glow.color = glow_tint(glow_level)
    record.visual_glow_level = glow_level
  end
end

return Visuals
