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

function Destinations.any(force)
  return #Destinations.planets(force) > 0
end

-- The uncharted chunk closest to `center` (a chunk position), ties at random. Searches square rings
-- outwards; once one holds an uncharted chunk, the rings out to that distance times sqrt(2) may still
-- hold a closer one (by straight-line distance), so those are searched too.
local function nearest_uncharted(force, surface, center)
  local best, best_distance, ties = nil, math.huge, 0
  local limit = SEARCH_CHUNKS
  local radius = 0
  while radius <= limit do
    for dx = -radius, radius do
      for dy = -radius, radius do
        if math.max(math.abs(dx), math.abs(dy)) == radius then
          local chunk = {x = center.x + dx, y = center.y + dy}
          if not force.is_chunk_charted(surface, chunk) then
            local distance = dx * dx + dy * dy
            if distance < best_distance then
              best, best_distance, ties = chunk, distance, 1
            elseif distance == best_distance then
              ties = ties + 1
              if math.random(ties) == 1 then
                best = chunk
              end
            end
          end
        end
      end
    end
    if best and limit == SEARCH_CHUNKS then
      limit = math.ceil(radius * 1.415)
    end
    radius = radius + 1
  end
  return best
end

-- Where on `surface` a traveller of `force` lands: the uncharted chunk nearest the force's spawn
-- position there, generated, or nil when everything near it is charted.
function Destinations.location(force, surface)
  local chunk = nearest_uncharted(force, surface, chunk_of(force.get_spawn_position(surface)))
  if not chunk then
    return nil
  end
  local center = {x = chunk.x * 32 + 16, y = chunk.y * 32 + 16}
  surface.request_to_generate_chunks(center, 0)
  surface.force_generate_chunk_requests()
  return surface.find_non_colliding_position("character", center, 32, 1) or center
end

-- A random destination for `force`: a surface and a position on it, or nil when it has visited no
-- planet or every chunk near the spawn is charted.
function Destinations.pick(force)
  local planets = Destinations.planets(force)
  if #planets == 0 then
    return nil
  end
  local surface = planets[math.random(#planets)]
  local position = Destinations.location(force, surface)
  if position then
    return surface, position
  end
end

return Destinations
