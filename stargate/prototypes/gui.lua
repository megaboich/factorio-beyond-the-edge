-- The station-mode diagrams shown under the gate window's station drop-down (scripts/gui.lua),
-- drawn by graphics/gui/generate.py.
for _, mode in pairs({"single", "right", "left"}) do
  data:extend({{
    type = "sprite",
    name = "bte-stargate-station-" .. mode,
    filename = "__bte-stargate__/graphics/gui/station-" .. mode .. ".png",
    size = 112,
    flags = {"gui-icon"}
  }})
end

-- The gate on the map, closed and open (scripts/gate.lua), drawn from the inventory icon's model by
-- tools/sprites/models/stargate-map.js and stargate-map-open.js.
for _, name in pairs({"bte-stargate-map", "bte-stargate-map-open"}) do
  data:extend({{
    type = "sprite",
    name = name,
    filename = "__bte-stargate__/graphics/map/" .. name:gsub("^bte%-", "") .. ".png",
    size = 256
  }})
end
