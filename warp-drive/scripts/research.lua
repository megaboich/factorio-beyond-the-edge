local Research = {}

local PRACTICAL_TECH = "bte-practical-warp-drive"
local IMPATIENT_SETTING = "bte-warp-drive-severely-impatient"
local IMPATIENT_MULTIPLIER = 1000
local MINIMUM_DENSITY = 10
local EDGE_DENSITY = 100
local MAXIMUM_DENSITY = 10000
-- Along the final connection into the deepest destination, tachyon density rises steeply through
-- the first 500,000 km (~1,000 particles/s at 100,000 km and ~5,000 particles/s at 500,000 km)
-- before tapering toward MAXIMUM_DENSITY across the remaining distance.
local FINAL_CURVE_EXPONENT = 1.4
local FINAL_CURVE_HALF_SCALE = 1 / 16
local DETECTOR_SPEED_REFERENCE = 100
-- When no laboratories exist on the drive's platform, tachyon observations are relayed to
-- planetary laboratories with a 10x telemetry loss (0.1x signal efficiency).
local RELAY_TRANSFER_FACTOR = 0.1
-- After Practical research the detector powers the Tachyon Science Boost: the same effective
-- tachyon signal (T * S * P * R) divided by this reference signal (10,000 particles/s), giving
-- +1,500% (16x) locally or +150% (2.5x) via remote planetary transfer at 10,000 particles/s,
-- 50 km/s (1.5x), and 1 GW (10x).
local SCIENCE_BOOST_SIGNAL_DIVISOR = 10000
local RESEARCH_UPDATE_TICKS = 60
local TICKS_PER_SECOND = 60
local SPACELAB_INTEGRATION_ENABLED = false -- Temporary standalone testing switch.

function Research.reset_caches()
  storage.research_branch = nil
  storage.research_branches = nil
  storage.travel_map = nil
end

local function platform_speed_km_per_second(platform)
  return (platform.speed or 0) * TICKS_PER_SECOND
end

local TRAVEL_MAP_VERSION = 2
-- Tachyon density follows kilometres actually travelled through each connected route graph.
-- Space-location distance is only a starmap drawing radius and cannot represent route depth.
local function travel_maps()
  if storage.travel_map
      and storage.travel_map.version == TRAVEL_MAP_VERSION
      and storage.travel_map.by_location then
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
  local maps = {version = TRAVEL_MAP_VERSION, by_location = {}}
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
      local final_length = 0
      for _, edge in pairs(neighbours[deepest_name] or {}) do
        if edge.length > final_length then
          final_length = edge.length
        end
      end
      if final_length <= 0 then
        final_length = farthest
      end
      local map = {
        remaining = remaining,
        farthest = farthest,
        unit = unit or 1,
        deepest_name = deepest_name,
        final_length = final_length,
        edge_depth = math.max(0, farthest - final_length)
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
  return travel_maps().by_location[name]
    or {remaining = {}, farthest = 0, unit = 1, final_length = 0, edge_depth = 0}
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

function Research.final_stretch_density(fraction)
  local clamped = math.max(0, math.min(1, fraction or 0))
  if clamped <= 0 then
    return EDGE_DENSITY
  end
  local u = clamped ^ FINAL_CURVE_EXPONENT
  local curved = (1 + FINAL_CURVE_HALF_SCALE) * u / (u + FINAL_CURVE_HALF_SCALE)
  return EDGE_DENSITY + (MAXIMUM_DENSITY - EDGE_DENSITY) * curved
end

function Research.tachyon_density(platform)
  if not platform then
    return 0
  end
  local map = travel_map(platform)
  local depth = travel_depth(platform)
  if not depth or map.farthest <= 0 then
    return MINIMUM_DENSITY
  end
  if depth <= map.edge_depth then
    if map.edge_depth <= map.unit then
      return MINIMUM_DENSITY
    end
    local span = math.log(map.edge_depth / map.unit)
    if span <= 0 then
      return MINIMUM_DENSITY
    end
    local ratio = math.log(math.max(depth, map.unit) / map.unit) / span
    ratio = math.max(0, math.min(1, ratio))
    return MINIMUM_DENSITY * (EDGE_DENSITY / MINIMUM_DENSITY) ^ ratio
  end
  local final_length = math.max(1, map.final_length)
  return Research.final_stretch_density((depth - map.edge_depth) / final_length)
end

local function spacelab_multiplier(surface)
  if not SPACELAB_INTEGRATION_ENABLED or not script.active_mods["bte-spacelab"] then
    return 1
  end
  local working = 0
  for _, entity in pairs(surface.find_entities_filtered({name = "bte-growth-facility"})) do
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

local function planetary_lab_metrics(force)
  local count = 0
  local total_rate = 0
  for _, surface in pairs(game.surfaces) do
    if not surface.platform then
      local surface_count, surface_rate = working_lab_metrics(surface, force)
      count = count + surface_count
      total_rate = total_rate + surface_rate
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

-- Selects "local" when any laboratory building exists on this platform surface (delivering 100%
-- of the tachyon signal exclusively to laboratories on this platform), or "relay" when no
-- laboratories are built on this platform (relaying the signal to planetary laboratories with a
-- 10x remote-transfer loss).
function Research.branch(surface, force)
  if not surface or not surface.valid or not surface.platform then
    return nil
  end
  local filter = {type = "lab", limit = 1}
  if force then
    filter.force = force
  end
  if surface.count_entities_filtered(filter) > 0 then
    return "local"
  end
  return "relay"
end

local function detector_speed_factor(platform)
  return 1 + math.max(0, platform_speed_km_per_second(platform)) / DETECTOR_SPEED_REFERENCE
end

local function tachyon_bonus_factor()
  local setting = settings.global[IMPATIENT_SETTING]
  return setting and setting.value and IMPATIENT_MULTIPLIER or 1
end

local function detector_signal(record, power_ratio, branch)
  local entity = record.entity
  local platform = entity and entity.valid and entity.surface.platform
  if not platform then
    return 0, 0
  end
  branch = branch or Research.branch(entity.surface, entity.force)
  local transfer = branch == "relay" and RELAY_TRANSFER_FACTOR or 1
  local base_signal = Research.tachyon_density(platform)
    * detector_speed_factor(platform)
    * spacelab_multiplier(entity.surface)
    * transfer
  local effective_signal = base_signal * power_ratio
  return effective_signal, effective_signal * tachyon_bonus_factor()
end

local function practical_complete(force)
  local technology = force.technologies[PRACTICAL_TECH]
  return technology ~= nil and technology.researched
end

-- The Tachyon Science Boost share for one drive: uses the same effective tachyon signal
-- (T * S * P * R) divided by SCIENCE_BOOST_SIGNAL_DIVISOR (10,000), so at 10,000 particles/s,
-- 50 km/s (1.5x), and 1 GW (10x), onboard platform labs receive +1,500% (16x) and remotely
-- boosted planetary labs receive +150% (2.5x). Impatient mode does not apply.
local function science_boost(record, branch)
  local effective_signal = detector_signal(record, record.detector_power_ratio or 0, branch)
  return effective_signal / SCIENCE_BOOST_SIGNAL_DIVISOR
end

-- research_unit_energy is ticks, despite technology unit time being authored in seconds.
local function research_seconds(research)
  return research.research_unit_energy / TICKS_PER_SECOND
end

-- Both GUI estimates and progress updates use this aggregation. Relay signals are summed
-- before one planetary lab scan; local signals use only labs on their detector surfaces.
--
-- In both Practical Warp Drive research mode and post-Practical General Science Tachyon Boost
-- mode, each drive checks whether laboratories exist on its platform: if so ("local"), 100% of its
-- signal applies exclusively to working laboratories on that platform; if not ("relay"), 10% (10x
-- remote-transfer loss) applies to working planetary laboratories.
local function aggregate_bonus_rates(target_force, target_research)
  local buckets = {}
  for _, record in pairs(storage.drives or {}) do
    local entity = record.entity
    local power_ratio = record.detector_power_ratio or 0
    local platform = entity and entity.valid and entity.surface.platform
    if platform and power_ratio > 0
        and (not target_force or entity.force == target_force) then
      local force = entity.force
      local research = target_force and target_research or force.current_research
      local boost = practical_complete(force)
      if research and (boost or research.name == PRACTICAL_TECH) then
        local branch = Research.branch(entity.surface, force)
        local bonus_multiplier
        if boost then
          bonus_multiplier = science_boost(record, branch)
        else
          local _, signal = detector_signal(record, power_ratio, branch)
          bonus_multiplier = signal
        end
        if bonus_multiplier > 0 then
          local bucket = buckets[force.index]
          if not bucket then
            bucket = {force = force, research = research, boost = boost, local_signals = {},
              relay_signal = 0}
            buckets[force.index] = bucket
          end
          if branch == "relay" then
            bucket.relay_signal = bucket.relay_signal + bonus_multiplier
          else
            bucket.local_signals[entity.surface] = (bucket.local_signals[entity.surface] or 0)
              + bonus_multiplier
          end
        end
      end
    end
  end
  for _, bucket in pairs(buckets) do
    local work = 0
    for surface, signal in pairs(bucket.local_signals) do
      local _, platform_rate = working_lab_metrics(surface, bucket.force)
      work = work + platform_rate * signal
    end
    if bucket.relay_signal > 0 then
      local _, planetary_rate = planetary_lab_metrics(bucket.force)
      work = work + planetary_rate * bucket.relay_signal
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
  local branch = Research.branch(entity.surface, force)
  local power_ratio = record.detector_power_ratio or 0
  local effective_signal, bonus_multiplier = detector_signal(record, power_ratio, branch)
  local lab_count, lab_rate
  if branch == "relay" then
    lab_count, lab_rate = planetary_lab_metrics(force)
  else
    lab_count, lab_rate = working_lab_metrics(entity.surface, force)
  end
  local research = force.current_research
  local researching_practical = research ~= nil and research.name == PRACTICAL_TECH
  local seconds = research ~= nil and research_seconds(research) or 0
  local bonus_rate = (not complete and researching_practical and seconds > 0)
    and lab_rate * bonus_multiplier / seconds or 0
  local ordinary_lab_rate = 0
  local force_bonus_rate = 0
  local total_rate = 0
  if research ~= nil and (complete or researching_practical) then
    _, ordinary_lab_rate = force_lab_metrics(force)
    local bucket = aggregate_bonus_rates(force, research)[force.index]
    force_bonus_rate = bucket and bucket.rate or 0
    total_rate = seconds > 0 and (ordinary_lab_rate / seconds + force_bonus_rate) or 0
  end
  local boost = complete and science_boost(record, branch) or 0
  -- Sum the boost of all drives targeting the same laboratory pool (onboard labs on this surface
  -- when local, or all relay drives when relaying to planetary laboratories).
  local combined_boost = 0
  if complete then
    if branch == "local" then
      combined_boost = boost
    else
      for _, other in pairs(storage.drives or {}) do
        local other_entity = other.entity
        if other_entity and other_entity.valid and other_entity.force == force
            and Research.branch(other_entity.surface, force) == "relay" then
          combined_boost = combined_boost + science_boost(other, "relay")
        end
      end
    end
  end
  local map = travel_map(platform)
  local progress_km = travel_depth(platform) or 0
  local deepest_name = map.deepest_name
  local final_length = map.final_length or 0
  local edge_depth = map.edge_depth or 0
  local final_distance = math.max(0, math.min(final_length, progress_km - edge_depth))
  return {
    branch = branch,
    practical = complete,
    research = research,
    researching_practical = researching_practical,
    research_seconds = seconds,
    power_ratio = power_ratio,
    effective_signal = effective_signal,
    detector_signal = complete and effective_signal or bonus_multiplier,
    detector_speed = math.max(0, platform_speed_km_per_second(platform)),
    detector_speed_factor = detector_speed_factor(platform),
    density = Research.tachyon_density(platform),
    maximum_density = MAXIMUM_DENSITY,
    lab_count = lab_count,
    lab_rate = lab_rate,
    average_lab_rate = lab_count > 0 and lab_rate / lab_count / math.max(1, seconds) or 0,
    bonus_rate = bonus_rate,
    ordinary_lab_rate = ordinary_lab_rate,
    force_bonus_rate = force_bonus_rate,
    total_rate = total_rate,
    progress = force.research_progress,
    remaining_units = research ~= nil
      and research.research_unit_count * (1 - force.research_progress) or 0,
    progress_km = progress_km,
    progress_ratio = map.farthest > 0 and progress_km / map.farthest or 0,
    final_distance = final_distance,
    final_length = final_length,
    on_final_stretch = progress_km >= edge_depth and final_length > 0,
    deepest_location = deepest_name and prototypes.space_location[deepest_name] or nil,
    science_boost = boost,
    combined_science_boost = combined_boost,
    science_boost_rate = complete and seconds > 0 and lab_rate * combined_boost / seconds or 0
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

-- Each force receives one aggregated progress write per update regardless of its number of local
-- or relay drives: to Practical Warp Drive before it is researched, to any research afterwards.
function Research.update()
  for _, bucket in pairs(aggregate_bonus_rates()) do
    apply_research_progress(bucket)
  end
end

return Research
