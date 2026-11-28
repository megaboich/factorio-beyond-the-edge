# Stargate: Travel on Foot and by Vehicle

Maintainer reference for trips through the portal by characters, vehicles, and enemies, and for unpaired gates' random destinations. Trains are in [railway.md](railway.md). Player-facing behaviour is in the [README](../README.md). Code: `scripts/transfer.lua`, `scripts/destinations.lua`.

## Travellers

- **Characters** take the cutscene trip below.
- **Cars, tanks, and spidertrons** are teleported whole with their crew, which a cross-surface teleport keeps seated.
- **Units and spider-units** cannot be teleported across surfaces and travel as clones.
- Non-characters wait `disabled_by_script` on their own spot in limbo, and run out by `speed`, autopilot, or a `go_to_location` command.
- A destination whose surface conditions the traveller fails is refused.
- Arrivals are not sent again for 300 ticks (`storage.arrived`), because a spidertron's body could settle in an open partner's portal and bounce straight back.

### Remote drivers

A remote driver, a `LuaPlayer` from `get_driver()`, is ejected on departure with its remote view reset, since its camera otherwise followed the tank or spidertron into limbo. Movement keys still held then pan the remote view, which nothing fixes without a visible cost: remote view accepts no cutscene, pinning the view each tick looked jumpy, and a hidden frozen vehicle shows enter and leave messages.

## A character's trip

1. **Departure, 128 ticks** on the hidden `bte-stargate-limbo` surface while its player watches the gate in a cutscene (which holds the camera and ignores movement keys; a spectator controller let the keys pan the view) and the `bte-stargate-passage` animation (the model's `glow-passage` layer, `drawPassage()`) plays over the veil. A short cyan `draw_light` flash plays with it.
2. **Arrival, 64 ticks** at the partner while `bte-stargate-arrival` (the passage with a reversed `frame_sequence`, at double speed) plays there. To move the cutscene camera across surfaces, the character is briefly taken out of limbo to the arrival surface, a new cutscene started, and the character returned to limbo, all in one tick.
3. **Run out:** arrival in front of the partner and a five-tile run out of the ring (`walking_state` set every tick under a second cutscene that follows the character; with the player's own controller its input overrode the script and the run fell short).

The arrival sound waits a few ticks after the cutscene camera has moved to the arrival surface (played in that same tick it was not heard), and goes to the traveller with `LuaPlayer.play_sound` without a position and to other players on that surface at the gate.

### Cutscene pitfalls

- `on_cutscene_cancelled` and `on_cutscene_finished` complete the trip early.
- A cutscene started straight after `exit_cutscene()` had no character to return to and left the player a bodiless camera, so every cutscene exit hands the character back with `set_controller` explicitly, first moving the bodiless player to the character's surface (`LuaControl.teleport`), which `set_controller` requires (skipping the departure cutscene on a cross-surface trip otherwise left the player on the departure surface while `finish()` moved the character to the arrival surface, raising a cross-surface controller error).
- `exit_cutscene()` raises `on_cutscene_cancelled` synchronously, so the script's own exits set `storage.leaving_cutscene` for the handler to ignore; without it the handler finished the trip inside the arrival step and stranded the character in limbo.

## Random destinations

`scripts/destinations.lua` picks destinations for unpaired gates:

- A planet counts as visited when the force has charted the chunk at its spawn position, or a gate of that force already stands on it.
- Across visited planets in random order, the destination is the nearest uncharted chunk to the force's spawn position (up to 32 candidates inspected per planet out to 256 chunks) that has collision-free solid ground inside the chunk (`radius = 15`) for the traveller's prototype (`spider-vehicle` also checks `"character"` so its legs have dry ground), skipping chunks covered by water, lava, or obstacles rather than forcing placement onto the chunk centre.
- Completing an uncontrolled jump with a character (on foot or crewing a vehicle) calls `Gate.record_jump(force)`, which enables `bte-stargate-controlled-jumps` (disabled but visible until then) for research. If a paired gate's arrival area is completely blocked (`Gate.arrival` finds no spot within 24 tiles), `Transfer.landing` falls back to the sending gate; if an origin or destination surface was deleted mid-transit, it falls back to a valid planet surface.
- Whether any destination exists is cached for 60 ticks (`storage.destinations_any`), a fully charted planet is cached for 600 ticks, and an all-water candidate scan for 60 ticks (`storage.destinations_exhausted`).
