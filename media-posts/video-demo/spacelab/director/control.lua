-- Plays scenes.lua: glides the remote-view camera between keyframes, opens building windows,
-- and shows a full black frame before t=0 and after the end so the recording can be cut exactly.
local S = require("scenes")
local PRE = 240

local function ease(f) return f * f * (3 - 2 * f) end

local function camera(t)
  local k = S.keys
  if t <= k[1][1] then return k[1][2], k[1][3], k[1][4] end
  for i = 1, #k - 1 do
    local a, b = k[i], k[i + 1]
    if t <= b[1] then
      local f = b[1] > a[1] and ease((t - a[1]) / (b[1] - a[1])) or 1
      local z = math.exp(math.log(a[4]) + (math.log(b[4]) - math.log(a[4])) * f)
      return a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f, z
    end
  end
  local l = k[#k]
  return l[2], l[3], l[4]
end

local function blackout(p, on)
  if on and not storage.black then
    storage.black = rendering.draw_rectangle{color = {0, 0, 0, 1}, filled = true,
      left_top = {-2000, -2000}, right_bottom = {2000, 2000}, surface = S.surface, players = {p}}
  elseif not on and storage.black then
    storage.black.destroy()
    storage.black = nil
  end
end

-- Picks the machine to show, nearest the camera among the best-scoring ones:
-- 3 = crafting with room in its output, 2 = crafting, 1 = idle but not starved or blocked,
-- 0 = anything else. Others with the same recipe may be stopped by a full belt.
local BAD = {}
for _, k in pairs{"item_ingredient_shortage", "fluid_ingredient_shortage", "full_output", "no_power",
  "low_power", "no_ingredients", "waiting_for_space_in_destination", "disabled_by_control_behavior",
  "output_full", "missing_required_fluid", "no_input_fluid"} do
  if defines.entity_status[k] then BAD[defines.entity_status[k]] = true end
end
local function score(e)
  local working = e.status == defines.entity_status.working and e.is_crafting()
  if working then
    local out = e.get_output_inventory()
    if out and not out.is_full() then return 3 end
    return 2
  end
  return BAD[e.status] and 0 or 1
end

local function find(name, recipe, x, y)
  local best, bs, bd
  for _, e in pairs(game.surfaces[S.surface].find_entities_filtered{name = name, position = {x, y}, radius = 40}) do
    local r = e.get_recipe()
    if r and r.name == recipe then
      local s, d = score(e), (e.position.x - x) ^ 2 + (e.position.y - y) ^ 2
      if not bs or s > bs or (s == bs and d < bd) then best, bs, bd = e, s, d end
    end
  end
  if best and bs < 2 then log("DIRECTOR no working " .. name .. " " .. recipe .. " (score " .. bs .. ")") end
  return best
end

script.on_event(defines.events.on_tick, function()
  storage.n = (storage.n or 0) + 1
  local p = game.players[1]
  if not p then return end
  local t = storage.n - PRE
  if storage.n == 1 then
    local v = p.game_view_settings
    for _, key in pairs{"show_controller_gui", "show_minimap", "show_research_info", "show_side_menu",
      "show_alert_gui", "show_quickbar", "show_shortcut_bar", "show_surface_list", "show_tool_bar",
      "show_hotkey_suggestions", "show_entity_tooltip", "update_entity_selection", "show_pins_gui",
      "show_map_view_options", "show_crafting_queue"} do v[key] = false end
    v.show_entity_info = true
    p.clear_selected_entity()
    storage.ev = 1
    log("DIRECTOR ready")
  end
  local x, y, z = camera(math.max(t, 0))
  p.set_controller{type = defines.controllers.remote, surface = S.surface, position = {x, y}}
  p.zoom = z
  blackout(p, t < 0 or t > S.total)
  if t == 0 then log("DIRECTOR start") end
  local e = S.events[storage.ev]
  while e and e[1] <= t do
    if e[2] == "pick" then
      -- Retarget this scene's glide and hold keyframes (1-based e[7], e[8]) to the chosen
      -- machine, shifted so it sits at the left edge of the frame, just clear of its window,
      -- which covers 22-78% of the width at 1080p. 23 tiles at zoom 1 = 736 px puts it at 12%.
      local ent = find(e[3], e[4], e[5], e[6])
      storage.picked = ent
      if ent then
        for _, i in pairs{e[7], e[8]} do
          local k = S.keys[i]
          k[2], k[3] = ent.position.x + 23 / k[4], ent.position.y
        end
      else
        log("DIRECTOR missing " .. e[3] .. " " .. e[4])
      end
    elseif e[2] == "open" then
      -- Selection drives the hovered-entity panel; with update_entity_selection off it would
      -- otherwise stay on whatever the idle mouse pointer last covered.
      if storage.picked and storage.picked.valid then
        p.selected = storage.picked
        p.opened = storage.picked
      end
    else
      p.opened = nil
      p.clear_selected_entity()
    end
    storage.ev = storage.ev + 1
    e = S.events[storage.ev]
  end
  if t == S.total + 60 then log("DIRECTOR done") end
end)
