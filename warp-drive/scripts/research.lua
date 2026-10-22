local Research = {}

local PRACTICAL_TECH = "practical-warp-drive"
local IMPATIENT_SETTING = "warp-drive-severely-impatient"
local IMPATIENT_MULTIPLIER = 1000
local BASE_TACHYONS_PER_SECOND = 2
local LOCATION_MULTIPLIER_MINIMUM = 10
local LOCATION_MULTIPLIER_MAXIMUM = 5000
local DETECTOR_SPEED_REFERENCE = 100
local RESEARCH_UPDATE_TICKS = 60
local TICKS_PER_SECOND = 60
local CRAFTING_MACHINE_TYPES = {
  ["assembling-machine"] = true,
  ["furnace"] = true,
  ["rocket-silo"] = true
}
local SPACELAB_INTEGRATION_ENABLED = false -- Temporary standalone testing switch.

local function init_storage()
  storage.research_branches = storage.research_branches or {}
end

function Research.reset_caches()
  storage.research_branch = nil
  storage.research_branches = {}
  storage.travel_map = nil
end

local function platform_speed_km_per_second(platform)
  return (platform.speed or 0) * TICKS_PER_SECOND
end

-- Tachyon density follows kilometres actually travelled through each connected route graph.
-- Space-location distance is only a starmap drawing radius and cannot represent route depth.
local function travel_maps()
  if storage.travel_map and storage.travel_map.by_location then
    return storage.travel_map
  end
  local neighbours = {}
  for _, connection in pairs(prototypes.space_connection) do
    local length = connection.length
    if length and length > 0 then
      local from, to = connection.from.name, connection.to.name
      neighbours[from] = neighbours[from] or {}
      neighbours[to] = neighbours[to] or {}
      table.insert(neighbours[from], {name = to, length = length})
      table.insert(neighbours[to], {name = from, length = length})
    end
  end
  local maps = {by_location = {}}
  local visited = {}
  for start in pairs(neighbours) do
    if not visited[start] then
      local names = {start}
      local deepest_name = start
      local deepest_distance = prototypes.space_location[start].distance or 0
      local unit
      visited[start] = true
      local index = 1
      while index <= #names do
        local name = names[index]
        for _, edge in pairs(neighbours[name]) do
          if not unit or edge.length < unit then
            unit = edge.length
          end
          if not visited[edge.name] then
            visited[edge.name] = true
            names[#names + 1] = edge.name
            local distance = prototypes.space_location[edge.name].distance or 0
            if distance > deepest_distance then
              deepest_distance = distance
              deepest_name = edge.name
            end
          end
        end
        index = index + 1
      end
      local remaining = {[deepest_name] = 0}
      -- Route graphs are tiny and this runs once per configuration, so repeated relaxation
      -- is clearer than retaining a priority queue or a mutable module-local cache.
      for _ = 1, #names do
        local changed = false
        for _, name in pairs(names) do
          local base = remaining[name]
          if base then
            for _, edge in pairs(neighbours[name]) do
              local candidate = base + edge.length
              if not remaining[edge.name] or candidate < remaining[edge.name] then
                remaining[edge.name] = candidate
                changed = true
              end
            end
          end
        end
        if not changed then
          break
        end
      end
      local farthest = 0
      for _, value in pairs(remaining) do
        if value > farthest then
          farthest = value
        end
      end
      local map = {
        remaining = remaining,
        farthest = farthest,
        unit = unit or 1,
        deepest_name = deepest_name
      }
      for _, name in pairs(names) do
        maps.by_location[name] = map
      end
    end
  end
  storage.travel_map = maps
  return maps
end

local function travel_map(platform)
  local name = platform.space_location and platform.space_location.name
    or (platform.space_connection and platform.space_connection.from.name)
  return travel_maps().by_location[name] or {remaining = {}, farthest = 0, unit = 1}
end

local function travel_depth(platform)
  local map = travel_map(platform)
  local location = platform.space_location
  if location then
    local remaining = map.remaining[location.name]
    return remaining and math.max(0, map.farthest - remaining) or nil
  end
  local connection = platform.space_connection
  local fraction = platform.distance
  if not connection or not fraction then
    return nil
  end
  local from = map.remaining[connection.from.name]
  local to = map.remaining[connection.to.name]
  local length = connection.length
  if not from or not to or not length then
    return nil
  end
  local remaining = math.min(from + fraction * length, to + (1 - fraction) * length)
  return math.max(0, map.farthest - remaining)
end

local function travel_ratio(platform)
  local map = travel_map(platform)
  local depth = travel_depth(platform)
  if not depth or map.farthest <= map.unit then
    return 0
  end
  local span = math.log(map.farthest / map.unit)
  if span <= 0 then
    return 0
  end
  local ratio = math.log(math.max(depth, map.unit) / map.unit) / span
  return math.max(0, math.min(1, ratio))
end

local function location_multiplier(platform)
  return LOCATION_MULTIPLIER_MINIMUM
    * (LOCATION_MULTIPLIER_MAXIMUM / LOCATION_MULTIPLIER_MINIMUM) ^ travel_ratio(platform)
end

function Research.tachyon_density(platform)
  return platform and BASE_TACHYONS_PER_SECOND * location_multiplier(platform) or 0
end

local function spacelab_multiplier(surface)
  if not SPACELAB_INTEGRATION_ENABLED or not script.active_mods.spacelab then
    return 1
  end
  local working = 0
  for _, entity in pairs(surface.find_entities_filtered({name = "spacelab-growth-facility"})) do
    if entity.status == defines.entity_status.working then
      working = working + 1
    end
  end
  return math.min(2, 1 + working * 0.05)
end

local function working_lab_metrics(surface, force)
  local count = 0
  local total_rate = 0
  for _, lab in pairs(surface.find_entities_filtered({type = "lab", force = force})) do
    if lab.status == defines.entity_status.working then
      local base_speed = lab.prototype.get_researching_speed(lab.quality.name) or 0
      count = count + 1
      total_rate = total_rate + base_speed * (1 + lab.speed_bonus) * (1 + lab.productivity_bonus)
    end
  end
  return count, total_rate
end

local function force_lab_metrics(force)
  local count = 0
  local total_rate = 0
  for _, surface in pairs(game.surfaces) do
    local surface_count, surface_rate = working_lab_metrics(surface, force)
    count = count + surface_count
    total_rate = total_rate + surface_rate
  end
  return count, total_rate
end

local function surface_conditions_met(conditions, surface)
  if not conditions or surface.ignore_surface_conditions then
    return true
  end
  for _, condition in pairs(conditions) do
    local value = surface.get_property(condition.property)
    if not value or value < condition.min or value > condition.max then
      return false
    end
  end
  return true
end

-- Select capability rather than a named integration. Relay is required whenever any science
-- pack cannot be produced by an applicable machine and recipe on this platform surface.
local function compute_branch(surface)
  local technology = prototypes.technology[PRACTICAL_TECH]
  if not technology then
    return "relay"
  end
  local categories = {}
  for _, machine in pairs(prototypes.entity) do
    if CRAFTING_MACHINE_TYPES[machine.type]
        and surface_conditions_met(machine.surface_conditions, surface) then
      for category in pairs(machine.crafting_categories or {}) do
        categories[category] = true
      end
    end
  end
  local craftable = {}
  for _, recipe in pairs(prototypes.recipe) do
    if surface_conditions_met(recipe.surface_conditions, surface) then
      local supported = false
      for _, category in pairs(recipe.categories) do
        if categories[category] then
          supported = true
          break
        end
      end
      if supported then
        -- Recycling consumes the same pack it returns, so it is not a source of that pack.
        local consumed = {}
        for _, ingredient in pairs(recipe.ingredients) do
          consumed[ingredient.name] = true
        end
        for _, product in pairs(recipe.products) do
          if product.type == "item" and not consumed[product.name] then
            craftable[product.name] = true
          end
        end
      end
    end
  end
  for _, ingredient in pairs(technology.research_unit_ingredients) do
    if not craftable[ingredient.name] then
      return "relay"
    end
  end
  return "local"
end

function Research.branch(surface)
  if not surface or not surface.valid or not surface.platform then
    return nil
  end
  init_storage()
  local cached = storage.research_branches[surface.index]
  if not cached or cached.surface ~= surface
      or cached.ignore_surface_conditions ~= surface.ignore_surface_conditions then
    cached = {
      surface = surface,
      ignore_surface_conditions = surface.ignore_surface_conditions,
      branch = compute_branch(surface)
    }
    storage.research_branches[surface.index] = cached
  end
  return cached.branch
end

local function detector_speed_factor(platform)
  return 1 + math.max(0, platform_speed_km_per_second(platform)) / DETECTOR_SPEED_REFERENCE
end

local function tachyon_bonus_factor()
  local setting = settings.global[IMPATIENT_SETTING]
  return setting and setting.value and IMPATIENT_MULTIPLIER or 1
end

local function detector_signal(record, power_ratio)
  local entity = record.entity
  local platform = entity and entity.valid and entity.surface.platform
  if not platform then
    return 0, 0
  end
  local signal = BASE_TACHYONS_PER_SECOND
    * location_multiplier(platform)
    * detector_speed_factor(platform)
    * spacelab_multiplier(entity.surface)
  return signal, signal * power_ratio * tachyon_bonus_factor()
end

-- research_unit_energy is ticks, despite technology unit time being authored in seconds.
local function research_seconds(research)
  return research.research_unit_energy / TICKS_PER_SECOND
end

-- Both GUI estimates and progress updates use this aggregation. Relay signals are summed
-- before one force-wide lab scan; local signals use only labs on their detector surfaces.
local function aggregate_bonus_rates(target_force, target_research)
  local buckets = {}
  for _, record in pairs(storage.drives or {}) do
    local entity = record.entity
    local power_ratio = record.detector_power_ratio or 0
    if entity and entity.valid and power_ratio > 0 and entity.surface.platform
        and (not target_force or entity.force == target_force) then
      local force = entity.force
      local research = target_force and target_research or force.current_research
      if research and research.name == PRACTICAL_TECH then
        local _, bonus_multiplier = detector_signal(record, power_ratio)
        if bonus_multiplier > 0 then
          local bucket = buckets[force.index]
          if not bucket then
            bucket = {force = force, research = research, local_work = 0, relay_signal = 0}
            buckets[force.index] = bucket
          end
          if Research.branch(entity.surface) == "relay" then
            bucket.relay_signal = bucket.relay_signal + bonus_multiplier
          else
            local _, platform_rate = working_lab_metrics(entity.surface, force)
            bucket.local_work = bucket.local_work + platform_rate * bonus_multiplier
          end
        end
      end
    end
  end
  for _, bucket in pairs(buckets) do
    local work = bucket.local_work
    if bucket.relay_signal > 0 then
      local _, force_rate = force_lab_metrics(bucket.force)
      work = work + force_rate * bucket.relay_signal
    end
    bucket.rate = work / research_seconds(bucket.research)
  end
  return buckets
end

function Research.snapshot(record)
  local entity = record and record.entity
  local platform = entity and entity.valid and entity.surface.platform
  if not platform then
    return nil
  end
  local force = entity.force
  local practical = force.technologies[PRACTICAL_TECH]
  local complete = practical ~= nil and practical.researched
  local branch = Research.branch(entity.surface)
  local power_ratio = complete and 0 or (record.detector_power_ratio or 0)
  local _, bonus_multiplier = detector_signal(record, power_ratio)
  local lab_count, lab_rate
  if branch == "relay" then
    lab_count, lab_rate = force_lab_metrics(force)
  else
    lab_count, lab_rate = working_lab_metrics(entity.surface, force)
  end
  local research = force.current_research
  local researching_practical = research ~= nil and research.name == PRACTICAL_TECH
  local seconds = researching_practical and research_seconds(research) or 0
  local bonus_rate = researching_practical and lab_rate * bonus_multiplier / seconds or 0
  local ordinary_lab_rate = 0
  local force_bonus_rate = 0
  local total_rate = 0
  if researching_practical then
    _, ordinary_lab_rate = force_lab_metrics(force)
    local bucket = aggregate_bonus_rates(force, research)[force.index]
    force_bonus_rate = bucket and bucket.rate or 0
    total_rate = ordinary_lab_rate / seconds + force_bonus_rate
  end
  local map = travel_map(platform)
  local progress_km = travel_depth(platform) or 0
  local deepest_name = map.deepest_name
  return {
    branch = branch,
    practical = complete,
    research = research,
    researching_practical = researching_practical,
    research_seconds = seconds,
    power_ratio = power_ratio,
    detector_signal = bonus_multiplier,
    detector_speed = math.max(0, platform_speed_km_per_second(platform)),
    detector_speed_factor = detector_speed_factor(platform),
    density = Research.tachyon_density(platform),
    maximum_density = BASE_TACHYONS_PER_SECOND * LOCATION_MULTIPLIER_MAXIMUM,
    lab_count = lab_count,
    lab_rate = lab_rate,
    average_lab_rate = lab_count > 0 and lab_rate / lab_count / math.max(1, seconds) or 0,
    bonus_rate = bonus_rate,
    ordinary_lab_rate = ordinary_lab_rate,
    force_bonus_rate = force_bonus_rate,
    total_rate = total_rate,
    progress = force.research_progress,
    remaining_units = researching_practical
      and research.research_unit_count * (1 - force.research_progress) or 0,
    progress_km = progress_km,
    progress_ratio = map.farthest > 0 and progress_km / map.farthest or 0,
    deepest_location = deepest_name and prototypes.space_location[deepest_name] or nil
  }
end

local function apply_research_progress(bucket)
  local force = bucket.force
  local research = bucket.research
  if bucket.rate <= 0 or force.current_research ~= research then
    return
  end
  if research.research_unit_count <= 0 then
    return
  end
  local progress = bucket.rate * (RESEARCH_UPDATE_TICKS / TICKS_PER_SECOND)
    / research.research_unit_count
  -- Factorio completes research through its own bookkeeping. Leaving progress below 1 keeps
  -- current_research and technology completion events consistent with ordinary lab progress.
  force.research_progress = math.min(0.999999999, force.research_progress + progress)
end

-- Practical Warp Drive is the only eligible technology, and each force receives one
-- aggregated progress write per update regardless of its number of local or relay drives.
function Research.update()
  for _, bucket in pairs(aggregate_bonus_rates()) do
    apply_research_progress(bucket)
  end
end

return Research
