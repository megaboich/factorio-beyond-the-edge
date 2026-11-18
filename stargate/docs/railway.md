# Stargate: Train Station Mode

Maintainer reference for trains through the gate. Player-facing behaviour is in the [README](../README.md). Code: `scripts/railway.lua`, `prototypes/rails.lua`, and the station parts of `scripts/gate.lua` and `scripts/gui.lua`. The carriage-by-carriage clone technique follows RiftRail; the code is this mod's own. See [Compared with RiftRail](#compared-with-riftrail) and [Provenance](#provenance).

The rule throughout: a train behaves like a vanilla train at a vanilla signal until the gate takes it, and from then on the gate finishes what it started.

## Layout

The gate never rotates, so lanes are always north-south: trains enter heading north and leave the partner heading south. Station mode is `record.railway`: `single` (one central track used both ways), `right`, or `left` (two tracks, departures on the right or left of a train driving in); `LAYOUTS` gives each lane's x offset. `build()` places, and adds whatever is missing after a configuration change or an older layout:

- `bte-stargate-rail` pieces, centres 2, 4, and 6 tiles south of the gate's centre, from its south edge to a tile behind the ring's plane, and `bte-stargate-rail-hidden` on behind the ring to 5 tiles north of the centre, long enough for a carriage to pass wholly behind the veil and for arrivals to appear there. Both are vanilla straight rails on the `rail` collision layer alone, so they fit the gate's mask while player rails still cannot be built over them and join them at the edge.
- Vanilla rail layers are all below `floor`, where the gate's concrete is drawn, so the rails are drawn on `zero`, under the ground, and the gate draws its own track: the `bte-stargate-tracks` companion on `floor-mechanics`, from the model's `rails-single`/`rails-double` layers (a riveted steel deck, ties and rails at the game's sizes and gauge, on a ramp over the ring's lower arc), the two-track pictures adding `chevrons-right` or `chevrons-left` (`TRACK_PICTURES` in `scripts/gate.lua`). `show_body` gives the body the matching `main-<mode>` and `glow-lights[-red]-<mode>` variation, with the track cut out of the building and its lamps hidden behind it.
- The hidden `bte-stargate-station` train stop at the gate's south edge, on the departure lane, named after the gate and with no collision box. A train stopping there has its front 0.6 inside the edge. The gate window opens that stop's own window instead (`player.opened = station` works although the stop is not selectable) and attaches itself to its right as a relative GUI anchored to `train_stop_gui` (`scripts/gui.lua`).
- The signals, below.

`Gate.remove_railway` removes the rails, the station, and the signals, and clears carriages off the rails. The mode cannot change while a carriage is on the gate's rails or a transfer runs either way.

`record.rail_layout` marks the layout version (`LAYOUT`), and `Railway.check` upgrades older gates there rather than in `on_configuration_changed`, because a reinstall with the same mod version raises none: a gate built before the hidden rails left trains grinding against the old rail end in the ring.

## Signals

- `bte-stargate-exit-signal`, a rail signal on the arrival lane at the edge, west of it facing north: the only side and direction a signal guarding southbound trains attaches (measured; any other side or direction is placed but never attached). Drawn on `zero` with its lights at zero intensity.
- `bte-stargate-entry-signal` on the departure lane, east of it facing south, for trains heading in. It keeps the vanilla pictures, so players see whether the gate is ready: red while it cannot send, green, then yellow as a train reserves its way in. On a single track it also keeps the lane two-way for the pathfinder, which a signal on one side only would make one-way.
- The entry signal is switched by `bte-stargate-entry-control`, a hidden constant combinator on the same spot, wired to it with a script wire (`defines.wire_origin.script`): the signal closes while the combinator sends `signal-red` (`close_signal` with `signal-red > 0`). A signal ignores its circuit condition without a network, so the script cannot close it alone (measured).
- Both are unselectable and sit on the `rail` collision layer alone: signals must collide with signals, and the player cannot build another on the same spot.

`Railway.check` (every 3 ticks) works out for each station gate whether it could send a train now: open, partner a station that is not receiving a transfer, and the partner's exit signal `open` (its first block free and not reserved). It switches the entry signal only when that changes (`record.entry_open`). Room behind the partner's veil is left to the send itself: checking it there, an entity search per gate every check, was three quarters of the sync's cost. Measured on a save with three station gates: about 2.4 µs per gate check (profilers included); the game draws the signal's state itself, so showing it costs nothing more.

## Waiting without "no path"

A train must not look for a path to its next stop, on the other surface, before the gate takes it, or the game raises the "no path" alert (seen in a visible game: once its wait conditions at the station are met, or at once if the station is only a waypoint in its schedule).

1. While the gate cannot send, the red entry signal keeps trains in front of the gate, waiting at a signal and still heading for the station, in automatic mode.
2. Once it turns green, a train drives in and is taken as its front crosses the edge, before it stops at the station.
3. A train past the signal that the gate cannot take yet (there before the signal closed, or a fast train past a waypoint between checks) finds no path as it leaves the station. `on_train_changed_state` catches that `no_path` in the same tick, before any alert is raised (seen in a visible game), and holds the train in manual mode (`storage.rail_held`) until the gate takes it; the transfer restores automatic mode on the arriving train. A held train goes back to automatic if its gate goes or leaves station mode, or the train is moved off the lane.

## Sending

1. `Railway.check` takes a train on the departure lane whose front has reached the edge, moving in or stopped, while the gate could send (above) and the partner's arrival lane has room for the first carriage. The partner's exit signal is read only here, once.
2. From then on `Railway.update` (every tick) holds the train in manual mode and drives it in at `SPEED`. Each carriage whose rear has passed the ring's plane is disconnected, `rotate()`d (the clone keeps the orientation, and must leave facing the way it entered relative to its motion), `clone`d onto the partner's arrival lane, and destroyed. `transfer.car` follows the leading carriage, so no tick walks every carriage. A carriage that cannot be turned or cloned is put back as it was and tried again next tick; after `STUCK_TICKS` failures it is wrecked like one with no room, since a started train must finish. (`clone` ignores collisions, so an obstacle that is not rolling stock does not make it fail: a chest on the arrival lane did not.)
3. Clones appear behind the partner's veil, a locomotive's front at the hidden rails' end, and couple as they are placed: they auto-couple at one coupling length, `(joint_distance + connection_distance) / 2` per carriage (7 for vanilla), even with 0.37 tiles of overshoot (measured). No leading locomotive is needed: setting `speed` on a manual train works without locomotives or fuel (a lone cargo wagon kept the speed it was given), so the arriving part is simply driven out every tick.
4. Drivers are moved by hand, since `clone` does not copy them; a remote driver is put out as for vehicles. Players looking at a carriage's window are moved to the clone's.
5. Each carriage plays `bte-stargate-splash` (the model's `glow-splash`, at the lane's x offset), a short cyan light, and the `stargate-car-in`/`-out` sounds on both gates (`splash()`), timed so the flash peaks as it vanishes and appears.
6. When the last carriage is out, the complete train gets back its schedule, interrupts, group, and temporary stops; `rail` records name places on the old surface and are dropped; the gate's own stop is skipped, or removed if temporary. It leaves in the mode it came in, at `SPEED`.

One transfer per arrival lane at a time (`receiving`). On a single track, arrivals start on the departure lane, so arrived carriages are not taken for 300 ticks (`storage.rail_guard`), and only trains moving in or stopped are taken.

## Crashes

Once started, the whole train is sent, whatever the signals, the gate's power, or its state do. When the arrived part has stood still for `STUCK_TICKS` and a carriage finds no room (`crash()`):

- first every arrived carriage not yet out of the ring is crushed (`crush()`): its rear more than `EMERGED_SLACK` behind the ring's plane (a locomotive stopped at the edge with no track beyond has its rear 0.2 tiles behind, and survives);
- then the carriage itself, against the rear of the carriage ahead.

After the last carriage is sent, the transfer runs on until that carriage is out, or crushes it if the train stops first. `wreck()` destroys a carriage with its cargo, places its explosion and remnants at the partner, and puts its driver on the floor beside the arrival lane towards the gate's centre: between the tracks of a two-track gate, east of a single one, clear of the track and in front of the portal.

If either gate is removed during a transfer, it stops: carriages still at the sender stay there with their schedule, and those already through keep the copy.

## Known limits

- Wait conditions at the gate's station do not delay a train: the gate takes it as soon as it reaches the edge. The station is a destination for schedules, not a place to wait.
- Two trains waiting at each other's single-track gates wait for ever: each stands in the other's exit block. As with a vanilla single track without a passing loop, give such routes two tracks.
- A gate has one partner, and trains always go there; there is no routing between several gates.
- A train driven by hand ignores the entry signal like any signal; the gate takes it only while it could send one, and otherwise it stands at the edge.
- A transfer costs no power beyond keeping the gate open, and a started train finishes even if the gate closes.
- Untested: a train limit on the gate's station; LTN and Cybersyn; whether `clone` keeps quality and spoilage (assumed); the look of trains at the ring in a visible game.

## Compared with RiftRail

Both move a train carriage by carriage with the same engine calls: disconnect, `rotate()`, `clone()` onto the other surface, move the driver by hand (`clone` does not copy one), destroy the original. They are the only way to move a loaded carriage across surfaces, so any mod doing this uses them; Space Exploration's elevator clones carriages too. That technique, and the engine behaviour it relies on, was studied from RiftRail's source. No RiftRail code is copied: the code around the technique is built for the gate, and everything else follows the gate's own model, closer to vanilla rail behaviour.

| | RiftRail | Stargate |
| --- | --- | --- |
| Moving a carriage | disconnect, rotate when the two portals' directions call for it (portals can face any way), clone, move the driver, destroy | the same engine calls, for fixed north-south lanes: every carriage is turned; one that cannot be turned or cloned is retried, then wrecked |
| Spacing at the exit | geometry from the portals' directions | each clone placed one coupling length behind the last, from the carriages' prototypes |
| Trigger | a train destroys a 1-HP collider on the portal track | the 3-tick check finds a train's front at the gate's edge; no collider, no damage events |
| Waiting | the train stops at the portal station; integrations add a circuit wait condition that keeps it there | the train waits in front of a script-controlled vanilla signal, automatic and still heading for the station; a manual hold is only the fallback |
| Blocked exit | the transfer stalls, the carriages waiting on both sides | the exit block is checked before a train starts; once started, carriages that cannot come out are destroyed |
| Arriving train | a helper locomotive pulls it out | driven by script; no helper locomotive |
| Schedule | copied with the first carriage; temporary "fake interrupt" stops are stripped afterwards | copied once, to the complete train, so interrupts never see a half-arrived train and the train's own temporary stops are kept |
| Routing | Entry, Exit, and Standby portals; several exits per entry, chosen by a circuit signal | one partner per gate, both ways; one or two tracks |
| Integrations | LTN, Cybersyn 2, Space Exploration | none yet |
| Other travel | players can teleport from the portal's core | the same gate carries players on foot, vehicles, and enemies ([transfer.md](transfer.md)) |

## Provenance

- Upstream: <https://github.com/VariousTrick/RiftRail>, [Mod Portal](https://mods.factorio.com/mod/RiftRail), MIT, copyright 2026 VariousTrick. Its source was studied for the technique; no code is copied. Code copied from it in future must keep its MIT notice and be recorded here.
- Local checkout: `../factorio-rift-rail/` relative to the repository root; mod root `RiftRail/`.
- Inspected 0.14.3 for Factorio 2.1 at commit `f9cc5effbf14d426baeff45a741019c36721690c` (2026-11-08); re-read at `6f8279fada47eba8bf5f9b33d9749f24d753726a` (2026-11-14) for the implementation.

| RiftRail source studied | What it does there |
| --- | --- |
| `RiftRail/scripts/teleport.lua`, `Teleport.on_collider_died`, `initialize_teleport_session` | Collider-triggered entry, destination lock, session setup |
| Same file, `Teleport.process_transfer_step` | Exit check, next carriage, clone, schedule handover, old-carriage destruction |
| `RiftRail/scripts/teleport_system/teleport_factory.lua`, `spawn_next_car_intelligently` | Orientation, source disconnection and rotation, cloning, driver transfer |
| `RiftRail/scripts/teleport_system/teleport_math.lua` | Orientation, spacing, movement-direction geometry |
| `RiftRail/scripts/schedule.lua`, `Schedule.copy_schedule` | Schedules, groups and interrupts, portal-stop adjustment |
| `RiftRail/scripts/teleport_system/teleport_utils.lua` | Train state restoration, carriage window viewers |
| `RiftRail/scripts/compat/ltn.lua`, `cs2.lua` | The circuit wait condition at the portal stop |
