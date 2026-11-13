-- Stargate construction. The player fills a construction site (a chest whose slots are filtered to the
-- bill of materials, laid out by data-final-fixes.lua). Every 30 ticks each site is checked, and once
-- it holds the full bill it is replaced in place by an assembling gate, which plays through its stage
-- pictures with a progress bar and, after `build_ticks`, is replaced in turn by the finished gate.
-- The three prototypes share one 14x14 footprint. The bill is a whole number of stacks per material,
-- so a delivery cannot exceed it; anything that still does (another mod changing stack sizes, say) is
-- spilled beside the assembling gate rather than lost.
local Construction = {}

local SITE = "bte-stargate-construction-site"
local ASSEMBLING = "bte-stargate-assembling"
local GATE = "bte-stargate"
local PLAN = "bte-stargate-construction"

-- Half the footprint, in tiles; surplus is spilled just south of it. The building's centre is one tile
-- south-east of its position (prototypes/entities.lua), so positions are shifted by CENTER before use.
local HALF = 7
local CENTER = 1
-- The progress bar lies across the front of the platform, this far south of the centre.
local BAR_WIDTH = 8
local BAR_OFFSET = 5.2
-- Ticks before a gate that could not be finished tries again (see finish).
local RETRY_TICKS = 600

local function plan()
  return prototypes.mod_data[PLAN].data
end

function Construction.init_storage()
  storage.sites = storage.sites or {}
  storage.builds = storage.builds or {}
end

-- Filters each material's slots, so only the bill of materials can be delivered, and starts watching the site.
function Construction.register(site)
  if not (site and site.valid) then
    return
  end
  local inventory = site.get_inventory(defines.inventory.chest)
  for _, requirement in ipairs(plan().requirements) do
    for slot = requirement.first_slot, requirement.first_slot + requirement.slots - 1 do
      -- Any quality at or above normal; a bare name would accept normal quality only.
      inventory.set_filter(slot, {name = requirement.name, quality = "normal", comparator = ">="})
    end
  end
  storage.sites[site.unit_number] = site
end

-- Registers every site that already exists, for new and updated games. Assembling gates keep their
-- own records in storage.
function Construction.rebuild()
  Construction.init_storage()
  for _, surface in pairs(game.surfaces) do
    for _, site in pairs(surface.find_entities_filtered({name = SITE})) do
      Construction.register(site)
    end
  end
end

local function totals(contents)
  local counts = {}
  for _, item in pairs(contents) do
    counts[item.name] = (counts[item.name] or 0) + item.count
  end
  return counts
end

local function is_complete(contents)
  local counts = totals(contents)
  for _, requirement in ipairs(plan().requirements) do
    if (counts[requirement.name] or 0) < requirement.amount then
      return false
    end
  end
  return true
end

-- Spills whatever the bill did not need, material by material, in the order the contents list it.
local function spill_surplus(surface, position, contents)
  local needed = {}
  for _, requirement in ipairs(plan().requirements) do
    needed[requirement.name] = requirement.amount
  end
  for _, item in pairs(contents) do
    local used = math.min(item.count, needed[item.name] or 0)
    needed[item.name] = (needed[item.name] or 0) - used
    if item.count > used then
      surface.spill_item_stack({
        position = {position.x + CENTER, position.y + CENTER + HALF + 0.5},
        stack = {name = item.name, count = item.count - used, quality = item.quality},
        enable_looted = false,
        allow_belts = false
      })
    end
  end
end

-- Destroys `old` and creates `name` in its place, keeping position, force, quality, health fraction,
-- and last user. If that fails, which only another mod's entity in the footprint should be able to
-- cause, the old building is put back and returned second.
local function replace(old, name)
  local surface, position, force, quality = old.surface, old.position, old.force, old.quality
  local old_name = old.name
  local health_ratio, last_user = old.get_health_ratio(), old.last_user
  old.destroy({raise_destroy = true})
  local new = surface.create_entity({
    name = name, position = position, force = force, quality = quality, raise_built = true
  })
  if not new then
    log("bte-stargate: could not place " .. name .. " at " .. serpent.line(position) .. "; restoring " .. old_name)
    local restored = surface.create_entity({
      name = old_name, position = position, force = force, quality = quality, raise_built = true
    })
    return nil, restored
  end
  new.health = new.max_health * health_ratio
  if last_user then
    new.last_user = last_user
  end
  return new, nil
end

local function discard_build(id, build)
  for _, key in pairs({"bar_background", "bar_fill"}) do
    if build[key] and build[key].valid then
      build[key].destroy()
    end
  end
  storage.builds[id] = nil
end

-- Starts timing an assembling gate and draws its progress bar over the front of the platform.
local function start_build(entity, finish_tick)
  local x, y = entity.position.x + CENTER - BAR_WIDTH / 2, entity.position.y + CENTER + BAR_OFFSET
  local build = {entity = entity, finish_tick = finish_tick, stage = 1, bar_left = x, bar_top = y}
  -- Above the building, whose ring is tall enough to cover a bar drawn at the default layer.
  build.bar_background = rendering.draw_rectangle({
    color = {0.06, 0.06, 0.06, 0.85}, filled = true, surface = entity.surface,
    left_top = {x - 0.12, y - 0.12}, right_bottom = {x + BAR_WIDTH + 0.12, y + 0.47},
    render_layer = "entity-info-icon-above"
  })
  build.bar_fill = rendering.draw_rectangle({
    color = {0.12, 0.78, 0.94, 1}, filled = true, surface = entity.surface,
    left_top = {x, y}, right_bottom = {x, y + 0.35}, render_layer = "entity-info-icon-above"
  })
  storage.builds[entity.unit_number] = build
end

-- Replaces a full site with an assembling gate and starts the clock. If the gate cannot be placed the
-- site is put back with everything that was in it.
local function complete(site)
  local contents = site.get_inventory(defines.inventory.chest).get_contents()
  local position, surface = site.position, site.surface
  local assembling, restored = replace(site, ASSEMBLING)
  if not assembling then
    for _, item in pairs(contents) do
      restored.insert(item)
    end
    return
  end
  spill_surplus(surface, position, contents)
  start_build(assembling, game.tick + plan().build_ticks)
end

-- Replaces an assembling gate with the finished one. If that fails, the assembling gate is restored
-- and tries again shortly.
local function finish(id, build)
  local entity = build.entity
  discard_build(id, build)
  local gate, restored = replace(entity, GATE)
  if not gate then
    start_build(restored, game.tick + RETRY_TICKS)
  end
end

-- Shows the stage picture and bar for the fraction of the build that has passed.
local function show_progress(build, remaining)
  local bill = plan()
  local fraction = math.min(1, math.max(0, 1 - remaining / bill.build_ticks))
  local stage = math.min(bill.stages, math.floor(fraction * bill.stages) + 1)
  if stage ~= build.stage then
    build.entity.graphics_variation = stage
    build.stage = stage
  end
  build.bar_fill.right_bottom = {build.bar_left + BAR_WIDTH * fraction, build.bar_top + 0.35}
end

function Construction.update()
  -- Replacing an entity registers its successor, so decide first and change the tables afterwards.
  local ready, finished = {}, {}
  for id, site in pairs(storage.sites) do
    if not site.valid then
      storage.sites[id] = nil
    elseif is_complete(site.get_inventory(defines.inventory.chest).get_contents()) then
      ready[#ready + 1] = site
    end
  end
  for id, build in pairs(storage.builds) do
    local remaining = build.finish_tick - game.tick
    if not build.entity.valid then
      discard_build(id, build)
    elseif remaining <= 0 then
      finished[#finished + 1] = id
    else
      show_progress(build, remaining)
    end
  end
  for _, site in pairs(ready) do
    storage.sites[site.unit_number] = nil
    complete(site)
  end
  for _, id in pairs(finished) do
    finish(id, storage.builds[id])
  end
end

return Construction
