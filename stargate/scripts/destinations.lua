-- Random destinations, for travellers through a gate that has no partner. A destination is a planet
-- the traveller's force has visited, picked at random, and on it the nearest unexplored (uncharted)
-- chunk to the force's spawn position that has collision-free solid ground for the traveller; ties at
-- the same distance go at random. A planet counts as visited when the force has charted the chunk at
-- its spawn position, which landing there does. Islands, cliffs, and enemies are not filtered out,
-- only impassable water, lava, or completely blocked chunks.
local Destinations = {}

-- How far out, in chunks, to look for an unexplored one, and how many nearest uncharted chunks on one
-- planet to inspect before giving up when water or lava covers the closest ones.
local SEARCH_CHUNKS = 256
local MAX_CHUNK_TRIES = 32
-- Stays inside the 32x32 uncharted chunk rather than spilling into an adjacent charted chunk.
local CHUNK_SEARCH_RADIUS = 15

local collides_water = {}
local function checks_ground(name)
  local cached = collides_water[name]
  if cached == nil then
    local proto = prototypes.entity[name]
    local layers = proto and proto.collision_mask and proto.collision_mask.layers
    cached = layers ~= nil and layers.water_tile == true
    collides_water[name] = cached
  end
  return cached
end

local function is_planet(surface)
  return surface and surface.valid and surface.planet ~= nil
end

local function chunk_of(position)
  return {x = math.floor(position.x / 32), y = math.floor(position.y / 32)}
end

function Destinations.clear_cache()
  storage.destinations_any = nil
  storage.destinations_exhausted = nil
end

-- The planets the force has visited, by surface: spawn chunk charted, or a gate of that force
-- already standing on the planet (covers custom scenarios and headless runs, which never chart).
function Destinations.planets(force)
  local has_gate = {}
  for _, record in pairs(storage.gates or {}) do
    local entity = record.entity
    if entity and entity.valid and entity.force == force and is_planet(entity.surface) then
      has_gate[entity.surface.index] = true
    end
  end
  local planets = {}
  for _, planet in pairs(game.planets) do
    local surface = planet.surface
    if is_planet(surface) and (has_gate[surface.index]
        or force.is_chunk_charted(surface, chunk_of(force.get_spawn_position(surface)))) then
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

-- Up to `MAX_CHUNK_TRIES` uncharted chunks closest to `center`, sorted nearest first with random
-- tie-breaking. Walks only the four edges of each square ring outwards and stops once no outer ring
-- can beat the `MAX_CHUNK_TRIES`-th candidate's Euclidean distance.
local function nearest_uncharted_candidates(force, surface, center)
  local candidates = {}
  local probe = {x = center.x, y = center.y}
  local cutoff = math.huge
  local limit = SEARCH_CHUNKS

  local function insert_candidate(x, y, distance)
    local item = {x = x, y = y, d = distance, tie = math.random()}
    local pos = #candidates + 1
    while pos > 1 do
      local prev = candidates[pos - 1]
      if distance < prev.d or (distance == prev.d and item.tie < prev.tie) then
        candidates[pos] = prev
        pos = pos - 1
      else
        break
      end
    end
    candidates[pos] = item
    if #candidates > MAX_CHUNK_TRIES then
      candidates[MAX_CHUNK_TRIES + 1] = nil
    end
    if #candidates == MAX_CHUNK_TRIES then
      cutoff = candidates[MAX_CHUNK_TRIES].d
      limit = math.min(limit, math.floor(math.sqrt(cutoff)))
    end
  end

  local function check(dx, dy)
    local distance = dx * dx + dy * dy
    if distance > cutoff then
      return
    end
    probe.x, probe.y = center.x + dx, center.y + dy
    if not force.is_chunk_charted(surface, probe) then
      insert_candidate(probe.x, probe.y, distance)
    end
  end

  check(0, 0)
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
  return candidates
end

-- Finds solid, collision-free ground inside `chunk` for prototype `name`, or nil if water, lava, or
-- obstacles cover the whole chunk. Spidertron bodies have an empty collision mask, so they also check
-- `"character"` to keep their legs off deep ocean or lava.
local function landing_in_chunk(surface, chunk, name)
  local center = {x = chunk.x * 32 + 16, y = chunk.y * 32 + 16}
  if not surface.is_chunk_generated(chunk) then
    surface.request_to_generate_chunks(center, 0)
    surface.force_generate_chunk_requests()
  end
  if checks_ground(name) then
    return surface.find_non_colliding_position(name, center, CHUNK_SEARCH_RADIUS, 1)
  end
  local ground = surface.find_non_colliding_position("character", center, CHUNK_SEARCH_RADIUS, 1)
  if not ground then
    return nil
  end
  return surface.find_non_colliding_position(name, ground, 2, 0.5)
end

-- A planet with no usable uncharted chunk near spawn is remembered briefly so someone standing in an
-- unpaired portal does not rescan or regenerate water chunks every few ticks.
local EXHAUSTED_TICKS = 600
local BLOCKED_TICKS = 60

-- Where on `surface` a traveller of `force` (`name`, `"character"` by default) lands: the nearest
-- uncharted chunk to the force's spawn position with solid collision-free ground, or nil when none fits.
function Destinations.location(force, surface, name)
  name = name or "character"
  local exhausted = storage.destinations_exhausted
  local base_key = force.index .. ":" .. surface.index
  local until_tick = exhausted and (exhausted[base_key] or exhausted[base_key .. ":" .. name])
  if until_tick and game.tick < until_tick then
    return nil
  end
  local candidates = nearest_uncharted_candidates(force, surface, chunk_of(force.get_spawn_position(surface)))
  if #candidates == 0 then
    storage.destinations_exhausted = exhausted or {}
    storage.destinations_exhausted[base_key] = game.tick + EXHAUSTED_TICKS
    return nil
  end
  if exhausted then
    exhausted[base_key] = nil
  end
  for i = 1, #candidates do
    local position = landing_in_chunk(surface, candidates[i], name)
    if position then
      if exhausted then
        exhausted[base_key .. ":" .. name] = nil
      end
      return position
    end
  end
  storage.destinations_exhausted = exhausted or {}
  storage.destinations_exhausted[base_key .. ":" .. name] = game.tick + BLOCKED_TICKS
  return nil
end

-- A random destination for `force` and prototype `name`: a surface and a collision-free position on
-- it, or nil when no visited planet has a reachable uncharted landing spot.
function Destinations.pick(force, name)
  local planets = Destinations.planets(force)
  while #planets > 0 do
    local index = math.random(#planets)
    local surface = planets[index]
    planets[index] = planets[#planets]
    planets[#planets] = nil
    local position = Destinations.location(force, surface, name)
    if position then
      return surface, position
    end
  end
end

return Destinations
