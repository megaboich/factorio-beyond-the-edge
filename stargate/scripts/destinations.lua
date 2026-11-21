-- Random destinations, for travellers through a gate that has no partner. A destination is a planet
-- the traveller's force has visited, picked at random, and on it the unexplored (uncharted) chunk
-- closest to the force's spawn position there, which is where its landing area is; ties go at random.
-- Nothing is recorded: a planet counts as visited when the force has charted the chunk at its spawn
-- position, which landing there does. Nothing checks the ground: a traveller may land on an island
-- or in a lake.
local Destinations = {}

-- How far out, in chunks, to look for an unexplored one.
local SEARCH_CHUNKS = 256

local function is_planet(surface)
  return surface and surface.valid and surface.planet ~= nil
end

local function chunk_of(position)
  return {x = math.floor(position.x / 32), y = math.floor(position.y / 32)}
end

-- The planets the force has visited, by surface.
function Destinations.planets(force)
  local planets = {}
  for _, planet in pairs(game.planets) do
    local surface = planet.surface
    if is_planet(surface) and force.is_chunk_charted(surface, chunk_of(force.get_spawn_position(surface))) then
      planets[#planets + 1] = surface
    end
  end
  return planets
end

-- Asked for every unpaired open gate every few ticks, and each answer walks every planet (about
-- 40 microseconds in a real save), so it is kept for a second. In storage, not a module local, so
-- every multiplayer client gives the same answer.
local ANY_TICKS = 60
function Destinations.any(force)
  local cache = storage.destinations_any
  if not cache or game.tick >= cache.tick + ANY_TICKS or game.tick < cache.tick then
    cache = {tick = game.tick, forces = {}}
    storage.destinations_any = cache
  end
  local any = cache.forces[force.index]
  if any == nil then
    any = #Destinations.planets(force) > 0
    cache.forces[force.index] = any
  end
  return any
end

-- The uncharted chunk closest to `center` (a chunk position), ties at random. Walks only the four
-- edges of each square ring outwards; once any uncharted chunk is found at squared distance `d`, no
-- ring beyond floor(sqrt(d)) can hold a closer one.
local function nearest_uncharted(force, surface, center)
  local probe = {x = center.x, y = center.y}
  if not force.is_chunk_charted(surface, probe) then
    return {x = center.x, y = center.y}
  end
  local best, best_distance, ties = nil, math.huge, 0
  local limit = SEARCH_CHUNKS
  local function check(dx, dy)
    local distance = dx * dx + dy * dy
    if distance > best_distance then
      return
    end
    probe.x, probe.y = center.x + dx, center.y + dy
    if not force.is_chunk_charted(surface, probe) then
      if distance < best_distance then
        best = {x = probe.x, y = probe.y}
        best_distance = distance
        ties = 1
        limit = math.min(limit, math.floor(math.sqrt(distance)))
      else
        ties = ties + 1
        if math.random(ties) == 1 then
          best = {x = probe.x, y = probe.y}
        end
      end
    end
  end
  local radius = 1
  while radius <= limit do
    for dx = -radius, radius do
      check(dx, -radius)
      check(dx, radius)
    end
    for dy = -radius + 1, radius - 1 do
      check(-radius, dy)
      check(radius, dy)
    end
    radius = radius + 1
  end
  return best
end

-- A planet fully charted out to SEARCH_CHUNKS is remembered briefly so someone standing in an
-- unpaired portal does not rescan all 256 rings every few ticks.
local EXHAUSTED_TICKS = 600

-- Where on `surface` a traveller of `force` lands: the uncharted chunk nearest the force's spawn
-- position there, generated, or nil when everything near it is charted.
function Destinations.location(force, surface)
  local exhausted = storage.destinations_exhausted
  local key = force.index .. ":" .. surface.index
  local until_tick = exhausted and exhausted[key]
  if until_tick and game.tick < until_tick and game.tick >= until_tick - EXHAUSTED_TICKS then
    return nil
  end
  local chunk = nearest_uncharted(force, surface, chunk_of(force.get_spawn_position(surface)))
  if not chunk then
    storage.destinations_exhausted = exhausted or {}
    storage.destinations_exhausted[key] = game.tick + EXHAUSTED_TICKS
    return nil
  end
  if exhausted then
    exhausted[key] = nil
  end
  local center = {x = chunk.x * 32 + 16, y = chunk.y * 32 + 16}
  surface.request_to_generate_chunks(center, 0)
  surface.force_generate_chunk_requests()
  return surface.find_non_colliding_position("character", center, 32, 1) or center
end

-- A random destination for `force`: a surface and a position on it, or nil when it has visited no
-- planet or every chunk near the spawn is charted on all of them.
function Destinations.pick(force)
  local planets = Destinations.planets(force)
  while #planets > 0 do
    local index = math.random(#planets)
    local surface = planets[index]
    planets[index] = planets[#planets]
    planets[#planets] = nil
    local position = Destinations.location(force, surface)
    if position then
      return surface, position
    end
  end
end

return Destinations
