-- This mod loads before Warp Drive so its on_tick handler runs first.
script.on_event(defines.events.on_tick, function()
  for _, platform in pairs(game.forces.player.platforms) do
    if game.tick <= 40 or (game.tick >= 1150 and game.tick <= 1170) then
      platform.speed = 50 / 60
      platform.paused = false
    elseif game.tick <= 530 then
      platform.speed = 250 / 60
      platform.paused = false
    elseif game.tick <= 560 then
      platform.speed = 100 / 60
      platform.paused = false
    end
  end
end)
