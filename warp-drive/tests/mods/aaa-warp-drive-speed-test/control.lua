-- This mod loads before Warp Drive so its on_tick handler runs first.
-- The runtime test selects named phases through this interface; this earlier handler then
-- establishes platform speed before Warp Drive observes that phase on the same tick.
remote.add_interface("aaa-warp-drive-speed-test", {
  set_phase = function(phase)
    storage.phase = phase
    storage.phase_started_at = game.tick
  end
})

script.on_event(defines.events.on_tick, function()
  local phase = storage.phase
  local elapsed = game.tick - (storage.phase_started_at or game.tick)
  for _, platform in pairs(game.forces.player.platforms) do
    if phase == "detector_gui" or phase == "practical_transition"
        or (phase == "warp_ramp" and elapsed <= 10) then
      platform.speed = 50 / 60
      platform.paused = false
    elseif phase == "warp_ramp" then
      platform.speed = 250 / 60
      platform.paused = false
    elseif phase == "post_warp_lockout" and elapsed >= 591 and elapsed <= 600 then
      platform.speed = 50 / 60
      platform.paused = false
    elseif phase == "post_warp_lockout" and elapsed >= 601 and elapsed <= 610 then
      platform.speed = 49 / 60
      platform.paused = false
    elseif phase == "post_warp_lockout" and elapsed >= 611 then
      platform.speed = 50 / 60
      platform.paused = false
    elseif phase == "speed_grace" and (elapsed <= 20
        or (elapsed >= 211 and elapsed <= 310))
        or phase == "reserve_brownout"
        or phase == "post_warp_lockout" or phase == "circuit_and_revocation"
        or phase == "relocation" or phase == "complete" then
      platform.speed = 100 / 60
      platform.paused = false
    elseif phase == "exit_lockout" then
      platform.speed = 50 / 60
      platform.paused = false
    else
      platform.speed = 40 / 60
      platform.paused = false
    end
  end
end)
