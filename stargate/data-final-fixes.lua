-- Runs after every mod's data stage, so stack sizes are final: lays out the construction site's
-- slots (one filtered slot per stack of each material), describes the bill of materials in the
-- site's and the kit's tooltips, and publishes the plan to the runtime as a mod-data prototype.
local construction = require("prototypes.construction")

local item_types = {
  "item", "module", "capsule", "tool", "ammo", "armor", "gun", "repair-tool",
  "item-with-entity-data", "rail-planner", "spidertron-remote", "space-platform-starter-pack"
}

local function stack_size(name)
  for _, type_name in pairs(item_types) do
    local prototype = data.raw[type_name] and data.raw[type_name][name]
    if prototype then
      return prototype.stack_size
    end
  end
  error("bte-stargate: unknown construction material " .. name)
end

local requirements = {}
local description = {"", {"bte-stargate-construction.requirements"}}
local next_slot = 1
for _, requirement in ipairs(construction.requirements) do
  local slots = math.ceil(requirement.amount / stack_size(requirement.name))
  requirements[#requirements + 1] = {
    name = requirement.name, amount = requirement.amount, slots = slots, first_slot = next_slot
  }
  next_slot = next_slot + slots
  -- One nested list per material: a localised string takes at most 20 parameters.
  description[#description + 1] = {
    "", "\n[item=" .. requirement.name .. "] ", {"item-name." .. requirement.name}, " × " .. requirement.amount
  }
end

local site = data.raw.container["bte-stargate-construction-site"]
site.inventory_size = next_slot - 1
site.localised_description = {"", {"entity-description.bte-stargate-construction-site"}, "\n", description}
data.raw.item["bte-stargate-construction-kit"].localised_description =
  {"", {"item-description.bte-stargate-construction-kit"}, "\n", description}

data:extend({
  {
    type = "mod-data",
    name = "bte-stargate-construction",
    data = {
      build_ticks = construction.build_ticks,
      stages = construction.stages,
      requirements = requirements
    }
  }
})

-- Ground characters, spidertron and pentapod legs, cars and tanks, and ground units collide with
-- the gate's barriers (prototypes/entities.lua), which cover only the machinery, so all of them
-- pass through the lanes while modded flying vehicles or characters (which drop `player`) stay free.
-- Done last, so prototypes added by other mods are covered too.
local collision_mask_util = require("collision-mask-util")
for _, type_name in pairs({"character", "spider-leg", "car", "unit"}) do
  for _, prototype in pairs(data.raw[type_name] or {}) do
    local mask = collision_mask_util.get_mask(prototype)
    if mask.layers.player then
      mask.layers["bte-stargate-barrier"] = true
      prototype.collision_mask = mask
    end
  end
end
