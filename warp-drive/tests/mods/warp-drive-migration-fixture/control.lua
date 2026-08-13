local function fail(message)
  error("WARP_TEST_FAIL: " .. message)
end

script.on_init(function()
  local force = game.forces.player
  local platform = force.create_space_platform({
    name = "Warp migration test",
    planet = "nauvis",
    starter_pack = "space-platform-starter-pack"
  })
  if not platform then
    fail("migration platform creation returned nil")
  end
  platform.apply_starter_pack()

  local tiles = {}
  for x = -12, 12 do
    for y = -12, 12 do
      tiles[#tiles + 1] = {name = "space-platform-foundation", position = {x, y}}
    end
  end
  platform.surface.set_tiles(tiles)

  local legacy = platform.surface.create_entity({
    name = "warp-drive-structure",
    position = {0, 8},
    force = force
  })
  local combinator = platform.surface.create_entity({
    name = "constant-combinator",
    position = {7, 8},
    force = force
  })
  if not legacy or not combinator then
    fail("migration fixture entity creation failed")
  end
  legacy.health = legacy.max_health / 2

  local legacy_connector = legacy.get_wire_connector(defines.wire_connector_id.circuit_red, true)
  local combinator_connector = combinator.get_wire_connector(defines.wire_connector_id.circuit_red, true)
  if not legacy_connector or not combinator_connector
      or not legacy_connector.connect_to(combinator_connector, false) then
    fail("migration fixture circuit connection failed")
  end
end)
