-- Subspace anomalies: large pastel clouds drifting behind the ship while warp holds.
--
-- They are background, independent of the lightning: LuaRendering animations on the "under-tiles"
-- layer, so the platform deck hides them and they show only in open space. Each anomaly draws two
-- cloud shapes from the warp-field anomaly sheet around one drifting centre. Every tick moves it
-- south at 1/20th of the subspace streak speed, scaled by the active warp level; every 10-tick
-- update swells or shrinks it, turns each shape, crossfades between the shapes so its form
-- changes, and shifts its hue, in steps too small to see, and it fades in and out over its life.
-- The whole field fades in at warp entry and out after exit.
--
-- State lives in record.anomalies. Each render object also expires on its own shortly after its
-- anomaly would end, so objects outlive a removed drive by at most one anomaly lifetime.
local Anomalies = {}

local ANIMATION = "bte-warp-drive-anomaly"
-- Frames of the anomaly sheet (tools/sprites/models/warp-field.js), each a separate shape.
local SHAPES = 6
local LAYER = "under-tiles"
local TILES_PER_ANOMALY = 36 * 36
-- Each anomaly costs two render objects; very large ships stop here.
local MAX_ANOMALIES = 250
local LIFE_MIN = 30 * 60
local LIFE_MAX = 60 * 60
-- Fraction of its life an anomaly spends fading in, and again fading out.
local FADE = 0.3
local FIELD_FADE_TICKS = 120
-- Downward speed in tiles per tick at Warp-1 (20x slower than WARP_STREAK_SPEED = 0.555 in
-- scripts/warp.lua), scaled linearly with the current warp level.
local SOUTH_SPEED = 0.555 / 20
-- Small organic wander in tiles per tick around the main southward flow.
local DRIFT = 0.005
-- Scale of the sheet's roughly 5-tile shapes: anomalies span about 30 to 60 tiles.
local SCALE_MIN = 6
local SCALE_MAX = 11
-- Turns per tick, at most one turn in about seven minutes.
local SPIN = 1 / 25000
local SATURATION = 0.45
local BRIGHTNESS = 0.5

local function smoothstep(x)
  x = math.max(0, math.min(1, x))
  return x * x * (3 - 2 * x)
end

local function between(low, high)
  return low + math.random() * (high - low)
end

-- Reused scratch tables so per-tick movement and 10-tick posing allocate nothing.
local TARGET = {0, 0}
local COLOR = {0, 0, 0, 0}

-- A pastel colour of `hue` (0 to 1, wrapping), premultiplied by `alpha` for additive drawing.
local function pastel(hue, alpha)
  local h = (hue % 1) * 6
  local i = math.floor(h)
  local f = h - i
  local p, q, t = 1 - SATURATION, 1 - SATURATION * f, 1 - SATURATION * (1 - f)
  local r, g, b
  if i == 0 then r, g, b = 1, t, p
  elseif i == 1 then r, g, b = q, 1, p
  elseif i == 2 then r, g, b = p, 1, t
  elseif i == 3 then r, g, b = p, q, 1
  elseif i == 4 then r, g, b = t, p, 1
  else r, g, b = 1, p, q end
  COLOR[1], COLOR[2], COLOR[3], COLOR[4] = r * alpha, g * alpha, b * alpha, alpha
  return COLOR
end

-- Flattens legacy `anomaly.layers` records from older saves so the hot per-tick loop indexes fields directly.
local function upgrade_anomaly(anomaly)
  local layers = anomaly.layers
  if layers then
    local l1, l2 = layers[1], layers[2]
    anomaly.dx1, anomaly.dy1, anomaly.s1, anomaly.t1, anomaly.sp1, anomaly.obj1 =
      l1.dx, l1.dy, l1.stretch, l1.turn, l1.spin, l1.object
    anomaly.dx2, anomaly.dy2, anomaly.s2, anomaly.t2, anomaly.sp2, anomaly.obj2 =
      l2.dx, l2.dy, l2.stretch, l2.turn, l2.spin, l2.object
    anomaly.layers = nil
  end
end

local function destroy_anomaly(anomaly)
  if anomaly.layers then
    upgrade_anomaly(anomaly)
  end
  if anomaly.obj1 and anomaly.obj1.valid then
    anomaly.obj1.destroy()
  end
  if anomaly.obj2 and anomaly.obj2.valid then
    anomaly.obj2.destroy()
  end
end

-- Draws one anomaly at a random place in `bounds`. The first fill starts each part-way through
-- its life (`pre_aged`), so they do not all fade in and out together.
local function spawn(surface, bounds, pre_aged)
  local life = math.random(LIFE_MIN, LIFE_MAX)
  local age = pre_aged and math.random(0, life - 1) or 0
  local angle = math.random() * 2 * math.pi
  local speed = DRIFT * math.sqrt(math.random())
  local x = between(bounds.left, bounds.right)
  local y = between(bounds.top, bounds.bottom)
  local first = math.random(SHAPES)
  local second = (first + math.random(SHAPES - 1) - 1) % SHAPES + 1
  local dx1, dy1 = between(-6, 6), between(-6, 6)
  local dx2, dy2 = between(-6, 6), between(-6, 6)
  local ttl = life - age + FIELD_FADE_TICKS
  return {
    born = game.tick - age,
    life = life,
    x = x,
    y = y,
    vx = speed * math.cos(angle),
    vy = SOUTH_SPEED + speed * math.sin(angle),
    scale_from = between(SCALE_MIN, SCALE_MAX),
    scale_to = between(SCALE_MIN, SCALE_MAX),
    hue_from = math.random(),
    hue_shift = between(-0.25, 0.25),
    morph_phase = math.random() * 2 * math.pi,
    -- Radians per tick: the two shapes trade places every 10 to 25 seconds.
    morph_rate = math.pi / math.random(600, 1500),
    dx1 = dx1, dy1 = dy1, s1 = between(0.75, 1.3), t1 = math.random(), sp1 = between(-SPIN, SPIN),
    obj1 = rendering.draw_animation({
      animation = ANIMATION,
      animation_speed = 0,
      animation_offset = first - 1,
      surface = surface,
      target = {x + dx1, y + dy1},
      render_layer = LAYER,
      tint = {0, 0, 0, 0},
      time_to_live = ttl
    }),
    dx2 = dx2, dy2 = dy2, s2 = between(0.75, 1.3), t2 = math.random(), sp2 = between(-SPIN, SPIN),
    obj2 = rendering.draw_animation({
      animation = ANIMATION,
      animation_speed = 0,
      animation_offset = second - 1,
      surface = surface,
      target = {x + dx2, y + dy2},
      render_layer = LAYER,
      tint = {0, 0, 0, 0},
      time_to_live = ttl
    })
  }
end

-- Scales, turns, recolours, and fades one anomaly for `now`. Positions are already updated by
-- Anomalies.tick; slow sub-degree spin and scale changes update every 30 ticks.
local function pose(anomaly, field, now)
  local age = now - anomaly.born
  local progress = age / anomaly.life
  local fade = smoothstep(progress / FADE) * smoothstep((1 - progress) / FADE) * field * BRIGHTNESS
  local hue = anomaly.hue_from + anomaly.hue_shift * progress
  local morph = 0.5 + 0.5 * math.cos(anomaly.morph_phase + anomaly.morph_rate * age)
  local obj1, obj2 = anomaly.obj1, anomaly.obj2
  if not anomaly.posed_at or now - anomaly.posed_at >= 30 then
    anomaly.posed_at = now
    local scale = anomaly.scale_from + (anomaly.scale_to - anomaly.scale_from) * smoothstep(progress)
    local s1, s2 = anomaly.s1, anomaly.s2
    obj1.x_scale = scale * s1
    obj1.y_scale = scale / s1
    obj1.orientation = (anomaly.t1 + anomaly.sp1 * age) % 1
    obj2.x_scale = scale * s2
    obj2.y_scale = scale / s2
    obj2.orientation = (anomaly.t2 + anomaly.sp2 * age) % 1
  end
  -- Each shape keeps some presence, so the anomaly never thins to one half.
  local a1 = fade * (0.3 + 0.7 * morph)
  local a2 = fade * (1 - 0.7 * morph)
  if not anomaly.a1 or math.abs(a1 - anomaly.a1) > 0.003 or math.abs(a2 - anomaly.a2) > 0.003 then
    anomaly.a1, anomaly.a2 = a1, a2
    obj1.color = pastel(hue, a1)
    obj2.color = pastel(hue + 0.08, a2)
  end
end

function Anomalies.destroy(record)
  for _, anomaly in pairs(record.anomalies or {}) do
    destroy_anomaly(anomaly)
  end
  record.anomalies = nil
  record.anomaly_bounds = nil
  record.anomaly_tick = nil
  record.anomaly_field_since = nil
  record.anomaly_field_until = nil
end

-- Whether any connected player is viewing `surface` directly or through an open Warp Drive window.
-- Purely visual per-tick LuaRendering updates are skipped while nobody can see the surface, and
-- wrap cleanly to the current tick the instant a player looks at the platform.
local function surface_viewed(surface, platform_index)
  for _, player in pairs(game.connected_players) do
    if player.surface == surface then
      return true
    end
    if platform_index then
      local frame = player.gui.screen.bte_warp_drive_window
      if frame and frame.tags and frame.tags.platform_index == platform_index then
        return true
      end
    end
  end
  return false
end

--- Advances anomaly positions every tick so clouds glide smoothly southward at a speed proportional
-- to the active warp level, wrapping inside the off-screen effect margin.
function Anomalies.tick(record, force_sync)
  local anomalies = record.anomalies
  if not anomalies then
    return
  end
  local surface = record.surface or (record.entity and record.entity.valid and record.entity.surface)
  if not force_sync and (not surface or not surface_viewed(surface, record.platform_index)) then
    return
  end
  local tick = game.tick
  local dt = tick - (record.anomaly_tick or tick)
  record.anomaly_tick = tick
  if dt <= 0 then
    return
  end
  local bounds = record.anomaly_bounds or record.lightning_bounds
  local left = bounds and bounds.left or 0
  local right = bounds and bounds.right or 0
  local top = bounds and bounds.top or 0
  local bottom = bounds and bounds.bottom or 0
  local width = right - left
  local height = bottom - top
  local step = dt * math.max(1, record.warp_level or 1)
  local target = TARGET
  for index = 1, #anomalies do
    local anomaly = anomalies[index]
    if anomaly.layers then
      upgrade_anomaly(anomaly)
    end
    local vy = anomaly.vy
    if vy < SOUTH_SPEED * 0.5 then
      vy = SOUTH_SPEED
      anomaly.vy = vy
    end
    local x = anomaly.x + anomaly.vx * step
    local y = anomaly.y + vy * step
    if width > 0 and (x < left or x > right) then
      x = left + (x - left) % width
    end
    if height > 0 and y > bottom then
      y = top + (y - top) % height
    end
    anomaly.x, anomaly.y = x, y
    local obj1 = anomaly.obj1
    if obj1.valid then
      target[1], target[2] = x + anomaly.dx1, y + anomaly.dy1
      obj1.target = target
    end
    local obj2 = anomaly.obj2
    if obj2.valid then
      target[1], target[2] = x + anomaly.dx2, y + anomaly.dy2
      obj2.target = target
    end
  end
end

--- Keeps the field filled while `active` (warp holds) over `bounds`, and fades it out otherwise.
function Anomalies.update(record, surface, bounds, active)
  local tick = game.tick
  if bounds then
    record.anomaly_bounds = bounds
  end
  local field
  if active and bounds then
    record.anomaly_field_until = nil
    record.anomaly_field_since = record.anomaly_field_since or tick
    field = smoothstep((tick - record.anomaly_field_since) / FIELD_FADE_TICKS)
  else
    if not record.anomalies then
      return
    end
    record.anomaly_field_since = nil
    record.anomaly_field_until = record.anomaly_field_until or tick
    field = 1 - smoothstep((tick - record.anomaly_field_until) / FIELD_FADE_TICKS)
    if field <= 0 then
      Anomalies.destroy(record)
      return
    end
  end

  local anomalies = record.anomalies or {}
  local first_fill = record.anomalies == nil
  record.anomalies = anomalies
  if first_fill then
    record.anomaly_tick = tick
  end
  for index = #anomalies, 1, -1 do
    local anomaly = anomalies[index]
    if anomaly.layers then
      upgrade_anomaly(anomaly)
    end
    local valid = anomaly.obj1.valid and anomaly.obj2.valid
    if not valid or tick - anomaly.born >= anomaly.life then
      destroy_anomaly(anomaly)
      table.remove(anomalies, index)
    end
  end
  local spawned_from = #anomalies + 1
  if active and bounds then
    local target = math.min(MAX_ANOMALIES, math.floor(
      (bounds.right - bounds.left) * (bounds.bottom - bounds.top) / TILES_PER_ANOMALY))
    for _ = spawned_from, target do
      anomalies[#anomalies + 1] = spawn(surface, bounds, first_fill)
    end
  end
  if surface_viewed(surface, record.platform_index) then
    Anomalies.tick(record, true)
    for index = 1, #anomalies do
      pose(anomalies[index], field, tick)
    end
  else
    -- Pose newly created anomalies once so switching Remote View onto an in-flight platform shows
    -- scaled, tinted clouds on the very first frame.
    for index = spawned_from, #anomalies do
      pose(anomalies[index], field, tick)
    end
  end
end

return Anomalies
