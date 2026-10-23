-- Subspace anomalies: large pastel clouds drifting behind the ship while warp holds.
--
-- They are background, independent of the lightning: LuaRendering animations on the "under-tiles"
-- layer, so the platform deck hides them and they show only in open space. Each anomaly draws two
-- cloud shapes from the warp-field anomaly sheet around one drifting centre. Every 10-tick update
-- moves it, swells or shrinks it, turns each shape, crossfades between the shapes so its form
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
-- Each anomaly costs two render objects updated every 10 ticks; very large ships stop here.
local MAX_ANOMALIES = 250
local LIFE_MIN = 30 * 60
local LIFE_MAX = 60 * 60
-- Fraction of its life an anomaly spends fading in, and again fading out.
local FADE = 0.3
local FIELD_FADE_TICKS = 120
-- Tiles per tick, about 0.3 tiles a second at most: small enough steps every 10 ticks.
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
  return {r = r * alpha, g = g * alpha, b = b * alpha, a = alpha}
end

local function destroy_anomaly(anomaly)
  for _, layer in pairs(anomaly.layers) do
    if layer.object.valid then
      layer.object.destroy()
    end
  end
end

-- Draws one anomaly at a random place in `bounds`. The first fill starts each part-way through
-- its life (`pre_aged`), so they do not all fade in and out together.
local function spawn(surface, bounds, pre_aged)
  local life = math.random(LIFE_MIN, LIFE_MAX)
  local age = pre_aged and math.random(0, life - 1) or 0
  local angle = math.random() * 2 * math.pi
  local speed = DRIFT * math.sqrt(math.random())
  local anomaly = {
    born = game.tick - age,
    life = life,
    x = between(bounds.left, bounds.right),
    y = between(bounds.top, bounds.bottom),
    vx = speed * math.cos(angle),
    vy = speed * math.sin(angle),
    scale_from = between(SCALE_MIN, SCALE_MAX),
    scale_to = between(SCALE_MIN, SCALE_MAX),
    hue_from = math.random(),
    hue_shift = between(-0.25, 0.25),
    morph_phase = math.random() * 2 * math.pi,
    -- Radians per tick: the two shapes trade places every 10 to 25 seconds.
    morph_rate = math.pi / math.random(600, 1500),
    layers = {}
  }
  local first = math.random(SHAPES)
  for index = 1, 2 do
    local shape = index == 1 and first or (first + math.random(SHAPES - 1) - 1) % SHAPES + 1
    local stretch = between(0.75, 1.3)
    anomaly.layers[index] = {
      dx = between(-6, 6),
      dy = between(-6, 6),
      stretch = stretch,
      turn = math.random(),
      spin = between(-SPIN, SPIN),
      object = rendering.draw_animation({
        animation = ANIMATION,
        animation_speed = 0,
        animation_offset = shape - 1,
        surface = surface,
        target = {anomaly.x, anomaly.y},
        render_layer = LAYER,
        tint = {0, 0, 0, 0},
        time_to_live = life - age + FIELD_FADE_TICKS
      })
    }
  end
  return anomaly
end

-- Moves, scales, turns, recolours, and fades one anomaly for the current tick.
local function pose(anomaly, field)
  local age = game.tick - anomaly.born
  local progress = age / anomaly.life
  local fade = smoothstep(progress / FADE) * smoothstep((1 - progress) / FADE) * field * BRIGHTNESS
  local scale = anomaly.scale_from + (anomaly.scale_to - anomaly.scale_from) * smoothstep(progress)
  local hue = anomaly.hue_from + anomaly.hue_shift * progress
  local morph = 0.5 + 0.5 * math.cos(anomaly.morph_phase + anomaly.morph_rate * age)
  local x = anomaly.x + anomaly.vx * age
  local y = anomaly.y + anomaly.vy * age
  for index, layer in pairs(anomaly.layers) do
    local weight = index == 1 and morph or 1 - morph
    local object = layer.object
    object.target = {x + layer.dx, y + layer.dy}
    object.x_scale = scale * layer.stretch
    object.y_scale = scale / layer.stretch
    object.orientation = (layer.turn + layer.spin * age) % 1
    -- Each shape keeps some presence, so the anomaly never thins to one half.
    object.color = pastel(hue + (index - 1) * 0.08, fade * (0.3 + 0.7 * weight))
  end
end

function Anomalies.destroy(record)
  for _, anomaly in pairs(record.anomalies or {}) do
    destroy_anomaly(anomaly)
  end
  record.anomalies = nil
  record.anomaly_field_since = nil
  record.anomaly_field_until = nil
end

--- Keeps the field filled while `active` (warp holds) over `bounds`, and fades it out otherwise.
function Anomalies.update(record, surface, bounds, active)
  local tick = game.tick
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
  for index = #anomalies, 1, -1 do
    local anomaly = anomalies[index]
    local valid = anomaly.layers[1].object.valid and anomaly.layers[2].object.valid
    if not valid or tick - anomaly.born >= anomaly.life then
      destroy_anomaly(anomaly)
      table.remove(anomalies, index)
    end
  end
  if active and bounds then
    local target = math.min(MAX_ANOMALIES, math.floor(
      (bounds.right - bounds.left) * (bounds.bottom - bounds.top) / TILES_PER_ANOMALY))
    for _ = #anomalies + 1, target do
      anomalies[#anomalies + 1] = spawn(surface, bounds, first_fill)
    end
  end
  for _, anomaly in pairs(anomalies) do
    pose(anomaly, field)
  end
end

return Anomalies
