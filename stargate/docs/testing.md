# Stargate: Runtime Tests

```sh
./stargate/tests/run-runtime-tests.sh
```

The runner packages the mod, checks the ZIP excludes `tests/`, smoke-tests a fresh save with the package alone, then runs `stargate/tests/mods/bte-stargate-runtime-test` in a headless save. The helper's `data-final-fixes.lua` shortens the build to 240 ticks, gives the site one spare unfiltered slot, and shrinks the gate's power figures ([gate.md](gate.md)). The pass marker is `STARGATE_TEST_PASS`; failures use `error("STARGATE_TEST_FAIL: ...")`.

## What it verifies

**Construction**
- the slot filters, and that each material takes exactly its amount and no more;
- that an incomplete delivery waits, and a complete one is consumed and replaced in place (position, health fraction) by the assembling gate;
- that a stray stack in the spare slot is spilled;
- that the assembling gate shows its six phase pictures in turn and has a progress bar, and that the finished gate replaces it;
- that mining a half-filled site returns the kit and the delivery, and that neither gate can be mined;
- that a gate snaps to even coordinates while a rail snaps to odd ones.

**Gates and power**
- that gates pair both ways, and unpair when the partner dies;
- that they open when on, powered, and allowed by their circuit condition (paired or unpaired);
- that an unpaired gate's landing spot is the uncharted chunk nearest the spawn (headless runs never chart, so `force.chart` does nothing there and the visited-planet choice is untested);
- power sharing (`SHARE`: three gates beside a 300 MW load with 100 MW spare) and the steady-draw mode (both on poles and on a poleless global electric network), including the window's power figures and that direct and empty switched-off gates leave `storage.active_gates` and rejoin it when power falls short.

**Travel** ([transfer.md](transfer.md))
- that a character in the portal is sent to the front of the partner, through the limbo surface, and runs out of the ring (with a bare character entity, since headless runs have no player; the spectator view is untested);
- that a car (triggered by its box), a biter, and a pentapod strafer travel A to B, inactive in limbo, a car arriving facing south with its fuel and driving out;
- that a crewed tank and a piloted spidertron cross to another surface with everyone seated and the spidertron walking out;
- that a zero-gravity surface refuses a car.

**Trains** ([railway.md](railway.md))
- that station mode lays rails, a named station, and its signals;
- that it sends a crewed train with cargo, fluid, a group schedule, and its next stop across surfaces through two-track gates, and a hand-pushed train through single-track ones;
- that it refuses a mode change with a train on the rails, and upgrades a gate laid out by an earlier version (hidden rails added, station moved to the edge);
- that it keeps a train waiting at the gate's closed entry signal, in automatic mode, while the gate is off or the partner's exit block is occupied, and that each entry signal has its wired switch;
- that it smashes the carriages that do not fit at a partner, including the last one sent when it stops still in the ring;
- that an automatic train inside a gate whose partner cannot receive stops at the edge instead of driving into the ring, is sent once the gate is paired, and arrives in automatic mode; and that a train driven by hand into a closed gate is not taken;
- that a long automatic train coming round a U-turn into a gate, its tail further north than its head, goes in at speed, and gains speed going in as the whole train would, with no tick standing still, not as its locomotive alone once that is out (chain case 6);
- that an automatic train heading for the gate's station crosses the edge at speed, gathers speed through the ring, and arrives coupled at least as fast; that a train which has reserved its way through the green entry signal is still sent when the gate closes; that a train of up to nine carriages, automatic or driven by hand at top speed, arrives whole and coupled when the sending gate, the receiving one, or both are switched off as it starts through or partway, and that every carriage appears behind the partner's veil, which failed when the part already out drove itself away faster than the rest was fed in (a seven-carriage train from a save, whose last two wagons came out loose); that an arriving train drives itself while still arriving and stops at a red signal beyond the partner; that it takes a branch right after the partner that its path needs; and that with a red signal and a standing wagon just beyond the partner, too close for the train, its locomotive comes out and survives and its rear is wrecked; that with the track broken beyond the partner (no path) the train is pushed out to the rails' end; that a train with a locomotive at each end, scheduled back through a single-track partner, turns there and is taken again at once as it reaches the ring, rather than standing there with no path; that a 31-carriage train going through four gate pairs in a row, the track on each surface between looping round from one gate's exit into the next (laid with the rail planner's extensions), goes on into each next gate while its tail still comes out of the one before, with three transfers running at once, and arrives whole, coupled, and heading for its stop; that through two pairs a train pushed by a locomotive at its rear and one driven by hand go on the same way, and that one whose next stop is not the gate its track leads into, or driven by hand into a closed gate, jams there, its rest wrecked, with no transfer left running and nothing left at the first gate (each case on fresh surfaces, the train released once every gate is open);
- that it takes carriages only once they are behind the veil and lands arrivals behind the partner's;
- that a double-headed train pulls only with its forward locomotive, that destroying a station gate mid-transfer throws a driver on its rails clear while restoring surviving carriages on both sides to automatic mode, that expired `rail_guard` entries are pruned, and that a removed gate leaves no rails behind.

## Seeing what is drawn

Positions logged by script can be right while the picture is not (the drawing glitch in [railway.md](railway.md#drawing-glitch-at-the-first-send)). To check what a player sees with nobody at the keyboard:

1. Write a probe mod (its directory named after its `info.json` name) that builds the scene in `on_init` on a lab-tile surface, as `tests/mods/bte-stargate-runtime-test` does. To use the gate's test remote interface, name the probe `bte-stargate-runtime-test` and copy that mod's `info.json` and `data-final-fixes.lua` (the test power source). In `on_tick`, around the moment of interest, call `game.take_screenshot({surface = s, position = p, resolution = {w, h}, zoom = 0.5, path = "dir/<tick>.png", show_entity_info = false, daytime = 0})` and `helpers.write_file` the positions it should match. Take one screenshot before anything moves, as a reference of the empty track.
2. Run `./tests/factorio.sh graphics TICKS <stargate directory or ZIP> <probe directory>`. A window opens and closes by itself; leave it alone. The output is in `~/Library/Caches/bte-factorio/write-data/script-output`, cleared at each graphics run. For a player's save, copy it over `base.zip` as in [Replaying a Player Save](../../AGENTS.md#replaying-a-player-save), and restore it afterwards.
3. Measure rather than eyeball. At zoom 0.5 a tile is 16 px: `px = resolution / 2 + (world - position) * 16`. Convert frames to raw grey (`ffmpeg -i f.png -vf format=gray -f rawvideo -`), subtract the reference frame (static rails otherwise dominate), sum a narrow column along the track into a profile per frame, and find the shift that best matches consecutive profiles: a train at 0.34 tiles a tick moves 5–6 px, so any other value marks a glitch. To compare one frame with logged positions, draw lines at the logged edges (`ffmpeg ... drawbox`) and look.
4. To try a change, copy the mod to a temporary directory, edit the copy, and run that, so the repository and the installed mod stay untouched. A vanilla version of the scene, without this mod, separates the engine's behaviour from the mod's.

## Not covered

Like the other suites it does not exercise GUI, visuals, or real inserter and belt feeding in a visible game. A visible game runs unattended as in [Seeing what is drawn](#seeing-what-is-drawn); for GUI, a probe there can open a window and call `game.take_screenshot{show_gui = true}`, and `player.opened` needs the character within reach.
