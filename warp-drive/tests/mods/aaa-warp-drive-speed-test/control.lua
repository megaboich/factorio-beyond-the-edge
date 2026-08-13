-- This mod loads before Warp Drive so its on_tick handler runs first.
script.on_event(defines.events.on_tick, function()
  for _, platform in pairs(game.forces.player.platforms) do
    if game.tick <= 50 or (game.tick >= 650 and game.tick <= 670) then
      platform.speed = 60
      platform.paused = false
    end
  end
end)
