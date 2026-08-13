local function fail(message)
  error("WARP_TEST_FAIL: " .. message)
end

script.on_nth_tick(5, function()
  if storage.checked then
    return
  end
  storage.checked = true

  local platform = game.forces.player.platforms[1]
  if not platform or not platform.valid then
    fail("migration platform is missing")
  end
  local surface = platform.surface
  local legacy = surface.find_entities_filtered({name = "warp-drive-structure"})
  if #legacy ~= 0 then
    fail("legacy drive survived migration")
  end

  local drives = surface.find_entities_filtered({name = "warp-drive-controller"})
  if #drives ~= 1 then
    fail("expected one migrated controller, got " .. #drives)
  end
  local drive = drives[1]
  if drive.direction ~= defines.direction.north then
    fail("migrated controller direction was not preserved")
  end
  if math.abs(drive.health - drive.max_health / 2) > 0.01 then
    fail("migrated controller health was not preserved")
  end

  local combinator = surface.find_entities_filtered({name = "constant-combinator"})[1]
  local drive_connector = drive.get_wire_connector(defines.wire_connector_id.circuit_red, false)
  local combinator_connector = combinator
    and combinator.get_wire_connector(defines.wire_connector_id.circuit_red, false)
  if not drive_connector or not combinator_connector
      or not drive_connector.is_connected_to(combinator_connector) then
    fail(string.format(
      "migrated controller circuit connection was not preserved (drive=%s, target=%s)",
      drive_connector and drive_connector.connection_count or "missing",
      combinator_connector and combinator_connector.connection_count or "missing"
    ))
  end

  local animations = surface.find_entities_filtered({name = "warp-drive-animation"})
  local outputs = surface.find_entities_filtered({name = "warp-drive-circuit-output"})
  local detectors = surface.find_entities_filtered({name = "warp-drive-detector-load"})
  if #animations ~= 1 or #outputs ~= 1 or #detectors ~= 1 then
    fail("migrated controller companions were not created")
  end

  log("WARP_TEST_PASS: legacy drive, health, direction, circuit wire, and companions migrated")
end)
