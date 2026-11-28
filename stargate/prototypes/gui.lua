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
