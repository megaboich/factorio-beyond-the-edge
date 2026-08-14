-- This mod loads before Warp Drive so its handler runs first, which is the only way to
-- control the detector sample Warp Drive reads later in the same tick. Real platform
-- generation would otherwise leave an unpredictable surplus in the tertiary detector
-- buffer and make the unpowered baseline window meaningless.
--
-- The schedule is shared with warp-drive-branch-test by tick number so the two mods need
-- no communication: the detector is starved until BASELINE_END_TICK and saturated after it.
-- The boundary sits after the tick 180 measurement so the whole baseline window, including
-- the research bonus applied on tick 180 itself, is genuinely unpowered.
local BASELINE_END_TICK = 190
-- Moved after the tick 420 sample, so one window is measured just outside the Solar system
-- edge and the next is measured almost at the Shattered Planet, on the same connection.
local DEEP_TICK = 430
local FAST_TICK = 550
local NEAR_DISTANCE = 0.05
local DEEP_DISTANCE = 0.999

script.on_nth_tick(10, function()
  for _, surface in pairs(game.surfaces) do
    for _, detector in pairs(surface.find_entities_filtered({name = "warp-drive-detector-load"})) do
      detector.energy = game.tick < BASELINE_END_TICK and 0 or detector.electric_buffer_size
    end
  end
  -- Platform physics rewrites speed every tick and would eventually carry the platform to
  -- its destination, where distance becomes nil and the location multiplier collapses to 1.
  -- Pinning both keeps the signal constant so the test measures routing, not travel.
  for _, platform in pairs(game.forces.player.platforms) do
    platform.paused = false
    platform.speed = game.tick < FAST_TICK and 1 or (10 / 3)
    if platform.space_connection then
      platform.distance = game.tick < DEEP_TICK and NEAR_DISTANCE or DEEP_DISTANCE
    end
  end
end)

-- The run to the Shattered Planet is the densest asteroid field in the game and would
-- shred an undefended test platform long before the measurement windows close. Clearing
-- asteroids every tick keeps the test about tachyon signal strength rather than combat.
script.on_event(defines.events.on_tick, function()
  for _, platform in pairs(game.forces.player.platforms) do
    local surface = platform.surface
    if surface and surface.valid then
      for _, asteroid in pairs(surface.find_entities_filtered({type = "asteroid"})) do
        asteroid.destroy()
      end
    end
  end
end)
