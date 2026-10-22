-- This mod loads before Warp Drive and supplies controlled continuous generation to its
-- detector. Removing starter-pack storage and generation keeps the baseline genuinely
-- unpowered and makes each later research window use an exact power ceiling.
--
-- The schedule is shared with bte-warp-drive-branch-test by tick number so the two mods need
-- no communication: the detector is starved until BASELINE_END_TICK, held at the 200 MW
-- reference through the normal windows, then saturated to 1 GW before the final window.
-- Measurement gaps allow the adaptive detector's 10 MW probes to reach each new ceiling.
-- The boundary sits after the tick 180 measurement so the whole baseline window, including
-- the research bonus applied on tick 180 itself, is genuinely unpowered.
local BASELINE_END_TICK = 190
-- Moved after the tick 640 sample, so one window is measured just outside the Solar system
-- edge and the next is measured almost at the Shattered Planet, on the same connection.
local DEEP_TICK = 650
local FAST_TICK = 770
local DETECTOR_REFERENCE_WATTS = 200000000
local DETECTOR_MAX_WATTS = 1000000000
local NEAR_DISTANCE = 0.05
local DEEP_DISTANCE = 0.999

local function ensure_power_source(platform)
  local surface = platform.surface
  local source = surface.find_entities_filtered({name = "bte-warp-drive-branch-power-source"})[1]
  if not source then
    source = surface.create_entity({
      name = "bte-warp-drive-branch-power-source",
      position = {0, 10},
      force = platform.force
    })
    surface.create_entity({name = "substation", position = {4, 10}, force = platform.force})
  end
  return source
end

script.on_nth_tick(10, function()
  for _, platform in pairs(game.forces.player.platforms) do
    local surface = platform.surface
    for _, entity in pairs(surface.find_entities_filtered({type = {"solar-panel", "accumulator"}})) do
      entity.destroy()
    end
    local source = ensure_power_source(platform)
    local watts = game.tick < BASELINE_END_TICK and 0
      or (game.tick < FAST_TICK and DETECTOR_REFERENCE_WATTS or DETECTOR_MAX_WATTS)
    source.power_production = watts / 60
    source.output_flow_limit = watts / 60
    -- Platform physics rewrites speed every tick and would eventually carry the platform to
    -- its destination, where distance becomes nil and the location multiplier collapses to 1.
    -- Pinning both keeps the signal constant so the test measures routing, not travel.
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
