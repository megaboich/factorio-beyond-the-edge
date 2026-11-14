# Beyond the Edge: Stargate — development plan

**Status:** construction implemented (`bte-stargate` 0.1.0: kit, construction site, finished gate); everything else below is still a plan. **Restructured:** 2026-11-12.

[VISION.md](VISION.md) describes the standalone experience. This plan owns construction and transport; [Mechanoids](../mechanoids/PLAN.md) owns enemies, and [Homecoming Journey](../homecoming-journey/PLAN.md) owns the ancient-network campaign and ending. Candidate values and API observations below are not implemented mechanics.

## 1. Scope and dependencies

- Planned identity: `bte-stargate`, title `Beyond the Edge: Stargate`.
- Required dependencies: `base >= 2.1.0`, `space-age >= 2.1.0`; confirm the minimum API version during implementation.
- No hard dependency on any other family mod. Mechanoids + Stargate without Homecoming remains two standalone experiences.
- Own experimental kits, material-fed assembly, gate records/lifecycle, power, player transfer, endpoint pairing, rail upgrades, train transfer, and transport GUI.
- Do not own guardian AI, artifact rewards, fifteen-site discovery, campaign route restrictions, enormous capstone research, orbital finale, or victory state.
- Implemented so far: the loadable mod scaffold, the construction kit, the filtered construction site that becomes a finished gate when the bill of materials is delivered, and the Experimental Gates technology. Their behaviour lives in [README.md](README.md) and is tested by `tests/prototypes.py` and `tests/run-runtime-tests.sh`. Since then the finished gate has a first slice of S0: a window with a name, mutual pairing by selector, an on/off switch, and the engine's circuit enable condition; power from a 10 GJ power bank shared with Warp Drive (docs/power.md: leaking, charged adaptively from spare power, full to open, spending 80 % on opening, then running the 1 GW upkeep while refilling); red status lights while short of charge; the veil as its working visualisation; open, close, departure, and arrival sounds; and character transfer through a limbo surface with cutscenes and ripple animations to the front of the partner, checked every 3 ticks. It also sends travellers through an unpaired gate to a random destination: a random planet the force has visited, at the uncharted chunk nearest its spawn position (no ground or safety check, no return). Cars, tanks, spidertrons, and units (biters, spitters, pentapods) travel too (see Vehicle passage). It has no travel cost, train passage, or pairing validation beyond "same force" yet. The delivery is checked by a 30-tick poll rather than the staged commit described in section 5. The build then runs as a one-minute script timer in three picture phases (the first the construction site's own look) with a progress bar and no power requirement.
- Implemented layout and art: the site, the gate under construction, and the finished gate share a 14x14 footprint on the rails' 2x2 grid, offset so the building's edges fall on rail cell edges and its two lanes (4 | rail | gap | rail | 4) on rail positions. The art is the modern, human-built gate: a steel ring standing in a concrete basin with a trench under it, so the whole ring shows while its opening clears a train on either lane, between two support towers with machinery housings in the lower corners. The portal is still empty and the collision box solid: rail lanes through the gate, and the bridges and tracks drawn by `tools/sprites/models/stargate-rail.js` (previewed, not exported), belong to train passage.
- Planned art: an ancient Fulgoran gate of the same footprint for Homecoming Journey's ancient network, built as a separate model later.

## 2. Standalone progression

| Stage | Entry / unlock | Player-visible result |
| --- | --- | --- |
| Experimental gate research | Accessible basic experimental technology; exact prerequisites TBD | Experimental gate kit and construction site |
| Material-fed assembly | Place kit and deliver required components | Completed experimental gate |
| First experiment | Ready source and safe, validated random destination | Uncontrolled player jump; successful transfer records experiment completion |
| Controllable Stargate Jumps | Experiment complete, then paid research | Build second endpoint, pair gates, repeatable controlled player travel |
| Rail transit | Controlled travel technology, then paid research | Rail hardware and train passage between upgraded paired endpoints |

Success enables the next research; it does not mark paid research complete. Gates should be much easier to obtain than the old campaign design. Do not copy its quantum-processor-heavy construction bill, million-unit research, 1 GW startup, or 500 MW upkeep into standalone balance without new playtests.

Candidate names: `bte-stargate-experimental-gates`, `bte-stargate-controlled-jumps`, `bte-stargate-rail-transit`, and `bte-stargate-experimental-gate-kit`. These are unpublished proposals, not migration obligations.

### First random landing

The agreed experience is a random planet, an unexplored chunk, and a long but walkable distance from an already explored area. The destination is not the campaign's fixed Gleba receiver.

Proposed conservative prototype policy, still to confirm:

1. Select among other accessible planets with an explored foothold for the traveling force. Do not silently bypass normal planet discovery or send a player to a world with no known area to walk toward.
2. Select from a bounded set of candidates beyond that force's charted frontier. **Uncharted is not the same as ungenerated.** Never overwrite existing construction, even in an uncharted chunk.
3. Generate and inspect the arrival footprint and approach corridor. Find a collision-free landing using the actual character prototype.
4. Validate a practical walking route to a charted foothold, not merely straight-line distance. Water, lava, Fulgoran island gaps, and Aquilo's heating needs make geometric proximity insufficient.
5. Commit a deterministic destination for the attempt so repeated clicks or reloads cannot reroll an unsafe attempt indefinitely. Recheck eligibility before departure.
6. If no suitable destination exists, explain why and leave the player at the source without charging for a successful jump or unlocking research.

Open: exact eligible worlds, distance/walking-time band, terrain/path validation method, required supplies, destination marker, and recovery mechanism. Do not promise all five planets as safe first-experiment candidates until their traversal is demonstrated. A provisional emergency-return entitlement is a safety proposal, not an already agreed permanent second gate.

Complete the experiment only after `teleport` succeeds. Persist force-level completion independently of character death. Co-op must not unlock research multiple times or strand a second traveler. The first experiment does not secretly grant repeatable controlled travel before its research and second endpoint.

### Pairing and second-end construction

- Players deliver a second kit and construction materials to the other end, using normal Space Age logistics or other explicitly supported means.
- Begin with one named partner per gate. Pairing is reciprocal, force/access checked, and persisted by stable gate IDs, not entity references alone.
- GUI previews require confirmation and validation at commit. A stale GUI cannot redirect a pending transfer after re-pairing.
- Unpairing, endpoint destruction, mining, and force merges must update both ends and refuse unsafe changes during accepted transfers.
- Whether later gates support multiple links or routing is unresolved. No all-to-all travel or multi-hop automation is implied by simple pairing.
- Campaign-owned connections need a supported policy distinct from freely re-pairable player-built endpoints. Homecoming supplies allowed links; Stargate enforces admission without understanding artifacts or story stages.

## 3. First coding milestone: two gates and safe return

Keep the minimum useful implementation unchanged: a test helper supplies two gates on planetary surfaces; an on-foot engineer uses **Travel** to reach the other and return.

- Use a placeholder prototype, one orientation, and a small GUI; no enemies, procedural placement, custom art, research, or trains required.
- Move the existing character with `LuaPlayer.teleport`, not a serialized replacement character.
- Test same-surface and Nauvis–Gleba travel, 100 round trips, blocked arrival, duplicate clicks, stale GUI, simultaneous cooperative arrivals, save/load, and configuration changes.
- Keep character, inventory, armor, equipment, health, force, and carried state intact.
- Visible player/controller checks remain required; headless fixtures do not validate real GUI behavior.

Exit: a bidirectional in-game demonstration and repeatable runtime tests. Test endpoints are fixtures, not a public progression shortcut.

## 4. Player-travel safety contract

Revalidate at execution, not only when drawing a green GUI button:

1. Valid player and existing character, supported on-foot controller, physically near source (candidate **8 tiles**).
2. Current valid gate IDs/entities, force/access permission, reciprocal pairing or a valid experimental/campaign admission.
3. Construction, research, power, and endpoint availability satisfy the requested mode.
4. Generated landing area, bounded collision-free position outside gate geometry, and short-lived reservation preventing overlapping co-op arrivals.
5. No existing transfer or arrival cooldown (candidate **60 ticks**).

The player stays at the source while asynchronous generation runs. Recheck proximity and consent afterward. A failed collision search never falls back to forced placement. Check the teleport return value; commit energy and progression exactly once only on success, release failed reservations exactly once, and close/refresh only this mod's GUI.

Test equipment energy/shields/inventories, ammo, durability, quality, spoilage, item tags, cursor contents, and character modifiers. Driving, dead, remote-view-only, and characterless states need clear refusal. Vehicles/spidertrons are not silently included; train passengers belong to the later train feature.

### Recovery support

Support explicit prepaid expedition return for Homecoming's unrestored receivers, and evaluate a similar limited safety mechanism for standalone experiments. Store source/destination/player, reserved energy, and consumed status. One entitlement is not an unlimited free connection. Switching off a source must not delete an accepted return reserve. Death, source damage, blocked pads, and surface deletion need documented recovery outcomes.

Campaign ancient anchors survive damage; standalone kit sites do not automatically become indestructible campaign objects. Decide recovery and destruction policy for player-built gates separately.

## 5. Construction, lifecycle, power, and architecture

Keep a reusable material-fed construction flow: place kit/site → deliver structural materials → install control hardware → powered calibration → ready gate. A terminal inventory with explicit **Commit stage** is the simplest first approach: validate/consume a complete bill once, record the stage, and preserve partial deliveries across reloads. Prevent productivity, quality, repeated crafting, extraction, or companion repair from duplicating completion/refunds.

Separate construction and electrical state:

```text
Construction: kit/site -> partial assembly -> complete -> damaged/repair
Operation: offline -> charging -> ready -> reserved -> transferring -> ready
Fault: critical failure -> close admission -> controlled repair/recharge
```

Stable gate IDs survive entity replacement. Own shell/controller, power interface, assembly terminal, landing metadata, field rendering, and later rail companions. Remove only owned companions—not adjacent player rails, poles, or buildings. Register/adopt/repair through lifecycle paths, not broad frequent scans.

Power is a per-gate reservoir with no output. Define charging watts, stored joules, upkeep, and per-operation reservations separately. Standalone values are TBD; Homecoming's **1 GW activation / 500 MW active upkeep** are a campaign profile, not a baseline requirement for experimental access. Offline gates need not consume active upkeep. Verify the supported mechanism for campaign-specific profiles rather than globally raising standalone costs.

```text
energy consumed over n ticks = watts * n / 60
runtime energy flow per tick = watts / 60
```

One owner per debit; do not double-charge through manual and engine consumption. Network statistics cannot be credited independently to every gate of the same prototype on one shared grid. Test multiple gates, brownouts, saturated buffers, shutdown, reservations, and failed-transfer refunds. A connected pole is not evidence of delivered energy.

Planned feature-owned modules: `scripts/gates.lua`, `travel.lua`, `construction.lua`, `pairing.lua`, `experiments.lua`, `power.lua`, `gui.lua`, then `trains.lua`, `train-schedules.lua`, and `train-geometry.lua`. `control.lua` remains the direct composition root; no custom event bus or DI framework.

Persist schema, gates, pairings, force experiment completion, player cooldown/return entitlements, placement jobs, and later train sessions in this mod's `storage`. No campaign artifact ledger or guardian roster. Initialize/migrate during lifecycle/configuration paths; `on_load` is not a world-repair hook.

Use `bte-stargate-*` prototypes/settings/interfaces, `bte_stargate_*` GUI names, and `__bte-stargate__/` assets. GUI explains missing materials, experiment eligibility, selected partner, actual charge/reserve, blocked arrival, and train readiness. Changing a GUI style resets custom style properties; entity previews omit rendering overlays.

### Vehicle passage (implemented)

Cars, tanks, spidertrons, and units (`unit`, `spider-unit`, any force) travel through `scripts/transfer.lua`, generalised from characters. As built:

- Detection: the 3-tick scan searches the portal area (2 tiles deeper both ways) for those types; cars and tanks trigger when their bounding box touches the zone, everything else (a spidertron by its body) by its centre. A character in a vehicle travels with the vehicle.
- Transfer: cross-surface `teleport` keeps a car's, tank's, or spidertron's driver and passenger seated and its inventories (headless probe), so vehicles are teleported whole. Units refuse cross-surface teleports and travel as clones (`move()`). Non-characters wait in limbo `disabled_by_script` on their own 10-tile parking spot (limbo is now 512 tiles; older 32-tile limbos are enlarged). Riding players controlling their characters get the cutscenes; a character in a vehicle is handed back by teleporting the vehicle, never the character.
- Arrival: in front of the partner, the box's largest extent plus 0.2 clear of the zone (`Gate.arrival(target, name)`), at a free spot for that prototype. A car or tank faces south and is driven at 0.15 tiles a tick for five tiles; a spidertron gets an autopilot destination five tiles south (its old autopilot and follow target are cleared on departure); a unit gets a `go_to_location` command five tiles south, distracted by enemies.
- Guards: a traveller whose `surface_conditions` the destination does not meet stays in the ring (Space Age cars, tanks, and spidertrons need gravity).
- Tested headless: a car by its box only and one parked short of the zone, a biter and a strafer, fuel kept, limbo inactivity, facing and driving out, a crewed tank and a piloted spidertron crossing surfaces seated, the spidertron's walk out, and a car refused by a zero-gravity surface.
- Remote driving: tanks and spidertrons can be driven remotely (cars cannot). A remote driver (`get_driver()` returns a `LuaPlayer`) is put out with `set_driver(nil)` on departure and its remote view reset to where it was; before this its camera and controls followed the vehicle into dark limbo. Known cosmetic issue: movement keys still held from driving then pan the remote view away. Tried and dropped: a cutscene (remote view accepts none; `set_controller` leaves it in remote view), pinning the view back every tick (jumpy), and seating the player in a hidden frozen car (the game shows its enter and leave vehicle messages; a plain car copy also cannot be driven remotely without `allow_remote_driving`).
- Re-entry: a spidertron's body could settle inside the partner's portal and went straight back through an open partner (fine when the partner was closed). Every arrival is now kept out of transfers for 300 ticks (`storage.arrived`, `Transfer.can_enter`).
- Checked in game: car, tank, and spidertron trips, driving in at low and high speed, and a car left rolling in after its driver jumps out (it travels empty).
- Still open: visible checks of riding players' cutscenes and skipping them, spidertron legs settling; robots out of a spidertron's roboport are left behind.

## 6. Train logistics: Rift Rail adaptation

Train passage is part of standalone Stargate, developed after reliable paired player travel. Homecoming uses it for capstone supply chains; neither mod should implement a second transfer engine.

### Train station (implemented, first version)

`scripts/railway.lua` and `prototypes/rails.lua`. What was taken from RiftRail and what differs:

- Same core: carriage-by-carriage `clone` to the destination surface, the source carriage disconnected and `rotate()`d first so the clone faces the right way, then destroyed; the entry train pushed in and the exit train pushed out at a fixed speed every tick; a lock so one destination lane takes one train; drivers moved by hand (`clone` does not copy them); carriage-GUI viewers reopened on the clone; schedule copied with `rail` records dropped and the portal stop skipped (or removed if temporary), with groups and interrupts.
- Trigger: RiftRail kills a 1-HP collider on the track. Here the gate's existing 3-tick check looks for rolling stock whose leading edge is within 0.6 of the ring's plane on the departure lane, moving in or stopped; no collider, no damage events.
- No leader locomotive: setting `speed` on a manual train works without locomotives or fuel (headless probe: a lone cargo wagon kept the speed it was given), so the arriving part is simply driven out every tick.
- The schedule is copied once, to the complete train, after the last carriage. RiftRail copies it on the first carriage and then strips "fake interrupt" temporary stops that cargo interrupts insert while the consist is still incomplete; copying once avoids creating them, and the train's own temporary stops are kept.
- Start waits for a free arrival lane, so a train that cannot go stays under its schedule instead of being held in manual mode.
- Single-track mode: arrivals are guarded for 300 ticks (`storage.rail_guard`) and only northbound or stopped trains are taken, so an arrival on the shared lane is never sent back.
- Measured (headless): a station at the ring's cell stops a train with its front 0.4 short of the ring's plane; clones auto-couple when placed exactly one coupling length (`(joint_distance + connection_distance) / 2` per car, 7 for vanilla) behind the previous one, even with 0.37 tiles of overshoot; a locomotive with its front at the rail end has its centre 3.5 tiles from it.
- Visibility: vanilla rail layers are all below `floor`, where the gate's concrete is drawn. The game's rails are therefore never drawn (`render_layers` all `zero`); the gate draws its own track on a ramp (a riveted steel deck with grating between the rails, the game's tie and rail sizes and gauge measured from its rail sheets, red side trusses and foot blocks after the vanilla rail ramp, cyan edge studs; rendered without sun shadow so both lanes match, `userData.unshadowed`) from its edge over the ring's lower arc an eighth of a tile into the ring (`lib/stargate-parts.js` `laneTrack`), as the `bte-stargate-tracks` companion on `floor-mechanics`, while the body switches to a picture with the track cut out where it crosses the arc and lights hidden behind it (6 variations: none, one, two tracks; cyan, red). Track continues behind the ring to 5 tiles north of the centre as `bte-stargate-rail-hidden`, drawn on `zero` under the ground: a carriage is taken once its rear passes the ring's plane, and arrivals appear there behind the partner's veil. The station is at the gate's south edge (a waiting train's front 0.6 inside it); a train is taken when its front crosses the edge.
- Upgrades: `record.rail_layout` (`LAYOUT`) marks the layout version; `Railway.check` adds missing pieces and moves the station for older gates without removing rails under a train. A reinstall with the same mod version raises no `on_configuration_changed`, which is why it is checked there (a gate built before the hidden rails left trains grinding against the old rail end in the ring).
- Layout: the gate never rotates, so lanes are always north-south, trains enter northbound and leave southbound. Rails at the lane's x, centres 2, 4, 6 tiles south of the gate's centre (ending one tile north of the ring's plane, at the cell edge), on the `rail` collision layer only so they fit the gate's mask; the station has no collision box.
- GUI: the gate opens the station's native train stop window (`player.opened = station`, which works although the stop is not selectable) with the gate window as a relative GUI anchored to the right of `train_stop_gui`, filtered to `bte-stargate-station`.
- Tests: `stargate/tests/mods/bte-stargate-runtime-test` sends a three-carriage train in a train group with a driver across surfaces through a two-track pair and checks cargo, fluid, orientation, driver, schedule index, group, and next stop; pushes a manual two-carriage train through a single-track pair; checks the mode cannot change with a train on the rails and that removing a gate removes its rails.
- Still open: visible checks of the GUI, the look of trains at the ring, players riding through; LTN/Cybersyn; power cost per train; brownout policy (a started train always finishes); a stuck arrival lane (dead end) holds the sender indefinitely; single-track deadlock between two waiting trains; quality and spoilage preservation by `clone` is assumed, not tested.

### Pinned reference and source map

- Upstream: <https://github.com/VariousTrick/RiftRail>, [Mod Portal](https://mods.factorio.com/mod/RiftRail).
- Local checkout: `../factorio-rift-rail/` relative to repository root; mod root `RiftRail/`.
- Inspected **0.14.3**, Factorio **2.1**, commit **`f9cc5effbf14d426baeff45a741019c36721690c`**, 2026-11-08; re-read at **`6f8279fada47eba8bf5f9b33d9749f24d753726a`** (2026-11-14) for the implementation below.
- **MIT**, copyright 2026 VariousTrick. Retain the notice and record copied/adapted provenance. Source inspection is not a compatibility test.

Paths relative to the upstream repository:

| Source | Relevant behavior observed |
| --- | --- |
| `RiftRail/scripts/logic.lua`, `Logic.teleport_player` | Directional landing offset, collision search, player teleport |
| `RiftRail/scripts/teleport.lua`, `Teleport.on_collider_died` | Rolling-stock collider death triggers entry; not simply a hidden-signal callback |
| Same file, `initialize_teleport_session` | Destination lock and session setup |
| Same file, `Teleport.process_transfer_step` | Exit check, next carriage, clone, schedule/identity transfer, old-carriage destruction |
| `RiftRail/scripts/teleport_system/teleport_factory.lua`, `spawn_next_car_intelligently` | Orientation, source disconnection/rotation, exit-rail cloning, driver transfer |
| `RiftRail/scripts/teleport_system/teleport_math.lua` | Orientation, spacing, movement-direction geometry |
| `RiftRail/scripts/schedule.lua`, `Schedule.copy_schedule` and cleanup | Full schedules, groups/interrupts, portal-stop adjustment, surface-specific temporary records, incomplete-consist interrupts |
| `RiftRail/scripts/teleport_system/teleport_utils.lua` | Train state restoration and carriage-GUI viewer remapping |
| `RiftRail/scripts/teleport.lua`, finalization | Helper locomotive, restored movement, reacquiring train after helper removal |
| `RiftRail/scripts/remote.lua`, `doc/API_EN.md` | Departure, first-carriage handoff, arrival integration events |

The documented remote API is not evidence of a reusable arbitrary-entity `teleport_train` service. Substantially reuse suitable internals under Stargate ownership, without a RiftRail runtime dependency. Preserve useful decomposition, not its whole architecture.

### Adaptation and failure contract

- Begin with upstream-style carriage-by-carriage clone-and-replace on straight rails, not a new inventory serializer.
- Rename introduced globals/prototypes/settings/GUI/interfaces; attach to this mod's gate IDs, not duplicated campaign records.
- Preserve source carriages until destination copies and essential state are established. Handle `clone` returning `nil` and `destroy` failing.
- Source disconnection/rotation can occur before cloning succeeds: failed attempts need deliberate restoration or a safe paused state.
- Explicitly test drivers, passengers, and all cargo; comments about clone preserving data are not tests.
- Preserve full schedule/group/interrupt semantics; do not strip legitimate temporary stops just because upstream does so for its routing model.
- Revalidate orientations and rolling-stock geometry. Keep LTN/Cybersyn integration optional and later than ordinary vanilla schedules.
- For player travel, borrow the offset idea but never upstream's forced target-position fallback after failed collision search.

```text
idle -> queued -> destination-reserved -> transferring -> finalizing -> idle
                                  \-> faulted / controlled recovery
```

Persist session ID, gate IDs, original/current train identities, both carriage sets, schedule state, progress, and power reservation. Entity/train IDs change while splitting and reconnecting; session ID is the stable reference. One session owns a destination mouth; serialize initially. Two visible lanes do not prove conflict-free concurrent transfers.

Save/load preserves partial consists and locks. Endpoint loss closes admission and accounts for every surviving carriage. Destroying a remaining half and refunding cargo is not recovery. Brownout policy must either reserve sufficient energy to finish a bounded accepted operation or safely pause both halves. A short player buffer is not sufficient evidence for long-train safety.

### Preservation and industrial acceptance

| Area | Cases |
| --- | --- |
| Rolling stock | Locomotive, cargo, fluid, artillery; quality; mixed consists |
| Items | Counts, quality, spoilage, tags, filters, bars, ammo/durability |
| Fluids | Type, amount, temperature, partially filled wagons |
| Equipment/fuel | Grids/energy, burner fuel, burnt results, health |
| Geometry | Orientation pairs, reversed locomotives, wagon-first entry, push-pull |
| Schedules | Index, waits, groups, interrupts, temporary stops, source-surface rails |
| Identity | Clone event, changing train IDs, first-carriage and whole-train completion |
| Players | Driver, supported passengers, carriage GUI viewers |
| Failure | Blocked exit, clone failure, endpoint removal, brownout, reload, split/merge |
| Capacity | Train length, competing sources, deterministic queues |

The visual tunnel trick requires a foreground structure actually covering disappearance, not merely a high render layer. Test every supported orientation and zoom in visible play.

Demonstrate a multi-planet supply chain with loading/unloading, buffers, congestion, spoilage, and gate power measured. Routing beyond a simple pair needs explicit design rather than assuming ordinary cross-surface pathfinding handles it. Rail transit improves production/delivery, not research directly. Keep normal platform logistics for orbital deliveries. Homecoming separately compares capstone completion time under comparable production and research modifiers.

## 7. Integration boundary

Proposed narrow versioned remote API/events, names/signatures to design during implementation:

- Register a campaign-owned construction/receiver site by caller-owned stable ID; retry safely without duplicates.
- Configure campaign gate power/access/allowed connections without reading or mutating this mod's private state.
- Query construction/availability and observe successful construction, player transfer, and train completion.
- Create and resolve explicit limited return arrangements; lock out manual re-pairing of campaign-managed links.

Homecoming owns story permission and artifacts; Stargate owns final transfer preflight and conservation. APIs must not let campaign code bypass energy, collision, train locking, or state-preservation checks. Persist policy IDs/data, not callbacks or closures. Verify cross-mod event order, serialization, version handling, and idempotent reconciliation. These APIs do not exist yet.

## 8. Milestones and validation

| Milestone | Exit criterion |
| --- | --- |
| S0 — Native transfer | Two fixture gates, safe round trips, preservation, blocked landing, reload, real player checks |
| S1 — Experimental construction | Research/kit/material-fed assembly and power work without any family mod |
| S2 — First uncontrolled jump | Bounded destination selection, practical landing/recovery, successful experiment unlocks paid controlled research |
| S3 — Controlled pairs | Player-built remote endpoint, reciprocal pairing, lifecycle/access failures, repeated powered travel |
| T1 — Rift Rail spike | Attributed borrowed core works under Stargate names with real conservation/orientation/schedule tests |
| T2 — Rail logistics | Powered paired portals, persistent partial transfers, deterministic recovery, useful sustained throughput |
| S4 — Campaign integration/release | Versioned site/policy interface, standalone regression coverage, documentation, generated assets, package audit |

Create `tests/prototypes.py` and an isolated runtime runner when implementing. Assert resolved recipes/categories, costs/unlocks, power, collisions, locale, and sprite dimensions. Runtime tests cover controller state, character/cargo, experiments, pairing, energy units/shared grids, lifecycle, force merges, surface deletion, concurrency, save/load, and train preservation. Keep visible checks for GUI, camera, sound, occlusion, and walking safety.

Enroll in `make.sh` and `tests/run-prototype-tests.sh` only once loadable. Test alone, with Mechanoids (no campaign implicitly), with each released sibling where relevant, and in the full Homecoming stack. Exclude planning docs/test helpers from packages. Implemented behavior belongs in a future `README.md` and matching tests. Do not create speculative additional documents. Run `git diff --check`.

## 9. Evidence and open decisions

Prior source/API review used **Factorio 2.1.24**; verify the installed engine and minimum supported version. No gameplay or runtime validation has occurred for this mod.

- [LuaControl.teleport](https://lua-api.factorio.com/2.1.24/classes/LuaControl.html#teleport), [bounded landing search](https://lua-api.factorio.com/2.1.24/classes/LuaSurface.html#find_non_colliding_position) (radius zero is unbounded), [planet surface creation](https://lua-api.factorio.com/2.1.24/classes/LuaPlanet.html#create_surface).
- [LuaEntity.clone](https://lua-api.factorio.com/2.1.24/classes/LuaEntity.html#clone), [LuaTrain.schedule](https://lua-api.factorio.com/2.1.24/classes/LuaTrain.html#schedule), [LuaSchedule](https://lua-api.factorio.com/2.1.24/classes/LuaSchedule.html) for full groups/interrupts.
- [Pinned Rift Rail source](https://github.com/VariousTrick/RiftRail/tree/f9cc5effbf14d426baeff45a741019c36721690c), [integration documentation](https://github.com/VariousTrick/RiftRail/blob/f9cc5effbf14d426baeff45a741019c36721690c/doc/API_EN.md).
- [Warp Drive energy implementation](../warp-drive/scripts/warp.lua) provides unit evidence, not a reusable per-gate network meter.
- [Repository rules](../AGENTS.md), [packaging](../make.sh), [prototype runner](../tests/run-prototype-tests.sh).

Highest-value open decisions: accessible experimental research/material budget; eligible random worlds; walkable distance and validation; no-candidate/recovery policy; kit damage/mining/refunds; pairing UI and routing; standalone power; accepted-train brownout handling; campaign restrictions without silently rewriting existing standalone gates.

**Next implementation action:** S0, the two-gate native player-transfer prototype.
