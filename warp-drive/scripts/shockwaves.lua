-- Activation shockwaves: rings that carry the drive's own activation shockwave across the ship.
--
-- Warp entry schedules an azure ring with the core's flash and a fainter violet one just behind
-- it. Each grows from the building's edge, where the model's own shockwave fades, to `reach`
-- tiles at a steady speed and fades out over the second part of its life. The azure ring's front
-- sweeps the asteroids away (scripts/warp.lua asks for it through Shockwaves.front).
--
-- They are LuaRendering animations that update every tick rather than trivial smoke the engine
-- grows by itself: the engine skips creating smoke where no player can see it at that moment,
-- so a ring sent while the drive was off screen never appeared, even across the part of the ship
-- the player was looking at.
--
-- State lives in record.shockwave_tick, shockwaves_sent, shockwave_reach (pending rings) and
-- record.shockwaves (drawn rings). Each render object also expires on its own when its ring ends.
local Shockwaves = {}

local ANIMATION = "bte-warp-drive-shockwave"
local LAYER = "smoke"
-- Ticks after warp entry: the first with the core's flash at 0.54 s (scripts/visuals.lua).
local WAVES = {
  {delay = 30, color = {0.35, 0.75, 1}, sweep = true},
  {delay = 40, color = {0.6, 0.45, 1}}
}
-- The ring's radius in tiles at scale 1 (tools/sprites/models/warp-field.js), the building's edge
-- where it starts, its growth in tiles per tick, and the share of its life spent fading out.
local RING = 7
local START = 4.5
local SPEED = 2.4
local FADE = 0.6
-- The ring is an oval, squashed front to back like the drive's round core; duplicated from
-- warp-field.js, which draws it.
local ROUND_DEPTH = 0.78
Shockwaves.ROUND_DEPTH = ROUND_DEPTH
-- Share of its life by which the sweeping ring should reach the farthest asteroid, so it still
-- glows (at 40% brightness) as it hits the last ones.
local SWEEP_PROGRESS = 0.75

--- How far `position` is from `center` along the ring's oval, in tiles of its horizontal radius.
function Shockwaves.oval_distance(center, position)
  local dx = position.x - center.x
  local dy = (position.y - center.y) / ROUND_DEPTH
  return math.sqrt(dx * dx + dy * dy)
end

--- The reach a ring needs to sweep something `distance` tiles away (Shockwaves.oval_distance)
-- while still clearly visible.
function Shockwaves.sweep_reach(distance)
  return START + (distance - START) / SWEEP_PROGRESS
end

local function radius(ring, age)
  return START + (ring.reach - START) * age / ring.life
end

local function destroy_ring(ring)
  if ring.object.valid then
    ring.object.destroy()
  end
end

local function pose(ring, age)
  local progress = age / ring.life
  local alpha = math.min(1, (1 - progress) / FADE)
  local scale = radius(ring, age) / RING
  local object = ring.object
  object.x_scale = scale
  object.y_scale = scale
  -- Additive drawing: the colour is premultiplied by alpha.
  object.color = {ring.color[1] * alpha, ring.color[2] * alpha, ring.color[3] * alpha, alpha}
end

local function send(record, wave)
  local entity = record.entity
  local life = math.ceil((record.shockwave_reach - START) / SPEED)
  local ring = {
    born = game.tick,
    life = life,
    reach = record.shockwave_reach,
    color = wave.color,
    sweep = wave.sweep,
    center = entity.position,
    object = rendering.draw_animation({
      animation = ANIMATION,
      surface = entity.surface,
      target = entity.position,
      render_layer = LAYER,
      time_to_live = life
    })
  }
  pose(ring, 0)
  record.shockwaves = record.shockwaves or {}
  table.insert(record.shockwaves, ring)
end

--- Schedules the activation rings, each growing to `reach` tiles from the drive.
function Shockwaves.start(record, reach)
  record.shockwave_tick = game.tick
  record.shockwaves_sent = 0
  record.shockwave_reach = reach
end

--- Drops rings not sent yet, as on warp exit; rings already on their way finish.
function Shockwaves.cancel(record)
  record.shockwave_tick = nil
  record.shockwaves_sent = nil
  record.shockwave_reach = nil
end

--- Sends due rings and grows and fades the drawn ones; called every tick while any exist.
function Shockwaves.update(record)
  local started = record.shockwave_tick
  local entity = record.entity
  -- Saves from before rings had a stored reach drop the rings still pending.
  if started and not record.shockwave_reach then
    Shockwaves.cancel(record)
  elseif started and entity and entity.valid then
    local sent = record.shockwaves_sent or 0
    while WAVES[sent + 1] and game.tick - started >= WAVES[sent + 1].delay do
      sent = sent + 1
      send(record, WAVES[sent])
    end
    record.shockwaves_sent = sent
    if not WAVES[sent + 1] then
      record.shockwave_tick = nil
      record.shockwave_reach = nil
    end
  end
  local rings = record.shockwaves
  if not rings then
    return
  end
  for index = #rings, 1, -1 do
    local ring = rings[index]
    local age = game.tick - ring.born
    if age >= ring.life or not ring.object.valid then
      destroy_ring(ring)
      table.remove(rings, index)
    else
      pose(ring, age)
    end
  end
  if #rings == 0 then
    record.shockwaves = nil
  end
end

--- The sweeping ring's centre and current horizontal radius, and whether it is still to come:
-- (centre, radius) while it grows, (nil, nil, true) before it is sent, nothing once it is gone.
function Shockwaves.front(record)
  for _, ring in pairs(record.shockwaves or {}) do
    if ring.sweep then
      return ring.center, radius(ring, game.tick - ring.born)
    end
  end
  if record.shockwave_tick and (record.shockwaves_sent or 0) == 0 then
    return nil, nil, true
  end
end

function Shockwaves.destroy(record)
  for _, ring in pairs(record.shockwaves or {}) do
    destroy_ring(ring)
  end
  record.shockwaves = nil
  Shockwaves.cancel(record)
end

return Shockwaves
