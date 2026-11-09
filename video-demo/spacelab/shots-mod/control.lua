-- Takes thumbnail screenshots of Stargazer after the factory has run for 5 s, with and without
-- alt-mode icons. Keep resolution at 1920x1080: taller shots (1920x2160) render in two tiles
-- whose halves repeat nearly the same picture.
local SHOTS = {
  {"growth", {-53, 90}, 0.55}, {"growth-close", {-53, 84}, 0.8},
  {"labs", {46, 114}, 0.55}, {"labs-close", {46, 112}, 0.8},
}
script.on_event(defines.events.on_tick, function()
  storage.n = (storage.n or 0) + 1
  if storage.n ~= 300 then return end
  for _, s in pairs(SHOTS) do
    for _, info in pairs{true, false} do
      game.take_screenshot{surface = "platform-8", position = s[2], zoom = s[3], resolution = {1920, 1080},
        path = "bte-thumb/" .. s[1] .. (info and "-alt" or "") .. ".png", show_entity_info = info,
        anti_alias = true, hide_clouds = true, daytime = 0}
    end
  end
  log("SHOTS requested")
end)
