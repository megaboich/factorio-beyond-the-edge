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
- that they open only when paired, on, powered, and allowed by their circuit condition;
- that an unpaired gate still opens, and that its landing spot is the uncharted chunk nearest the spawn (headless runs never chart, so `force.chart` does nothing there and the visited-planet choice is untested);
- power sharing (`SHARE`: three gates beside a 300 MW load with 100 MW spare) and the steady-draw mode, including the window's power figures.

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
- that an automatic train heading for the gate's station crosses the edge at speed, gathers speed through the ring, and arrives coupled at least as fast; that a train which has reserved its way through the green entry signal is still sent when the gate closes; that a train of up to nine carriages, automatic or driven by hand at top speed, arrives whole and coupled when the sending gate, the receiving one, or both are switched off as it starts through or partway, and that every carriage appears behind the partner's veil, which failed when the part already out drove itself away faster than the rest was fed in (a seven-carriage train from a save, whose last two wagons came out loose); that an arriving train drives itself while still arriving and stops at a red signal beyond the partner; that it takes a branch right after the partner that its path needs; and that with a red signal and a standing wagon just beyond the partner, too close for the train, its locomotive comes out and survives and its rear is wrecked; that with the track broken beyond the partner (no path) the train is pushed out to the rails' end; that a train with a locomotive at each end, scheduled back through a single-track partner, turns there and is taken again at once as it reaches the ring, rather than standing there with no path;
- that it takes carriages only once they are behind the veil and lands arrivals behind the partner's;
- that it leaves no rails behind a removed gate.

## Not covered

Like the other suites it does not exercise GUI, visuals, or real inserter and belt feeding in a visible game. A visible game can be started with a temporary mod set, a separate write-data folder (`--config` with its own `config.ini`), and a helper mod that opens a window and calls `game.take_screenshot{show_gui = true}`; `player.opened` needs the character within reach.
