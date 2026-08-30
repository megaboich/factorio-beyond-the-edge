# Warp Drive Composite Building

**Document role:** this is the maintainer reference for the Warp Drive's composite entity: its prototypes, companion ownership, electrical roles, lifecycle, wiring, and rendering. It does not specify gameplay balance, research routing, location calculations, or audio implementation. `README.md` is authoritative for player-facing behavior and values; `AUDIO.md` covers sound assets and runtime playback; `PLAN.md` tracks unfinished work.

## Why It Is Composite

No single Factorio entity provides a large selectable building, continuous animation, circuit input and output, persistent charge, and a runtime-sized electrical load. The placed drive therefore consists of one visible controller and hidden companions at the same position.

The controller owns the composite. Companions are never independently placeable, selectable, minable, blueprintable, deconstructable, or colliding.

| Need | Composition choice |
| --- | --- |
| Player interaction and circuit input | Visible `constant-combinator` controller |
| Continuous layered graphics | Zero-power animation companion |
| Detector, charging, and support sampling | Runtime-configured secondary-input electric energy interface |
| Persistent warp support reserve | Serialized joule value in the drive record |
| Scripted circuit output | Hidden output combinator |

The shared power interface uses consumer-only secondary-input mode, the same priority as ordinary machines, and requests its exact current logical demand. Factorio classifies every tertiary interface buffer as accumulator storage even when it cannot output power; secondary mode keeps this interface out of the accumulator-charge display. Runtime code transfers measured charging delivery into the serialized reserve, and switching from experimental to practical mode discards detector energy so it cannot become activation charge.

## Prototype Composition

| Prototype | Type | Lifetime | Role |
| --- | --- | --- | --- |
| `warp-drive-controller` | `constant-combinator` | Always | Visible 6x6 entity, ownership anchor, health, collision, mining, circuit input, and GUI target |
| `warp-drive-animation` | `electric-energy-interface` | Always | Zero-power 100-frame animation, emission, and shadow |
| `warp-drive-power-interface` | `electric-energy-interface` | Always | Runtime-sized secondary-priority detector, charging, and support sink; prototype permits requests up to `60 GW` and forbids output |
| `warp-drive-circuit-output` | `constant-combinator` | Always | Scripted practical `W`, `C`, and `S` outputs, `D`, and pre-Practical `T`, on both wire colors |

Legacy detector, support, and tiered charge-buffer prototypes remain defined only so supported saves can load and migrate their companions and stored energy.

## Rendering And Wires

The controller renders the first structure frame for placement previews. The animation companion renders the full animation, additive emission, and repeated shadow on `higher-object-under`. Both use the same scale and `util.by_pixel(0, -16)` shift. During warp, 48 short-lived cyan streaks are regenerated every 10 ticks. A harmless clone of Space Age's Fulgora lightning prototype provides its full procedurally forked bolt, eight ground-streamer variants, shader layers, and native 36-tick lifecycle while removing the endpoint explosion, damage, attractor energy, sound, camera flash, debris, and smoke. Cached platform foundation bounds, expanded by 64 tiles on each side, define the shared streak and lightning field, averaging one active strike per `32 x 32` tiles and working in freely panned remote view. Tile events refresh the bounds without scanning in the 10-tick update. Whole strikes start at randomized moments rather than being seeded partway through an animation.

Drive audio is owned by the warp lifecycle rather than a companion entity. See
[`AUDIO.md`](AUDIO.md) for assets, runtime scheduling, persistent state, and
regeneration.

The symmetric footprint reuses one circuit connection definition in all directions. When adjusting it:

- Keep red and green endpoints ordered like vanilla entities to avoid crossed wires.
- Move each endpoint with its matching shadow point.
- Validate attachment, sag, and overlap in game.

## Runtime Ownership

`storage.drives` is keyed by `LuaSpacePlatform.index`. Each platform may own one record and one controller.

| Field | Role |
| --- | --- |
| `entity`, `platform_index` | Controller reference and platform identity |
| `animation`, `power`, `circuit_output` | Active companion references |
| `enabled`, `circuit_enabled`, `circuit_first_signal`, `circuit_comparator`, `circuit_second_signal`, `circuit_constant` | Mutually exclusive automatic/circuit engagement settings and configurable circuit condition; an absent first signal is unsatisfied |
| `output_*_enabled`, `output_*_signal` | Independent circuit output toggles and signal assignments; legacy outputs default enabled and distance defaults disabled |
| `state`, `cooldown_until` | Composite state and lockout |
| `last_distance`, `direction` | Travel samples used by movement logic |
| `detector_power`, `detector_power_ratio`, `detector_request_watts` | Latest detector sample, factor relative to `200 MW`, and adaptive next demand |
| `warp_level`, `requested_warp_level`, `warp_target` | Current, probed, and sustainable warp levels |
| `reserve_energy`, `migrated_reserve_energy` | Authoritative private reserve and one-time legacy energy capture |
| `support_power`, `power_sample_watts`, `power_sample_support_watts`, `support_demand_watts`, `support_check_after` | Delivered power, interface request, logical warp demand, and startup grace |
| `warp_ramp_state` | GUI acceleration status |
| `lightning_bounds` | Active warp effect footprint |

Build events call `register_drive`. Invalid off-platform placement is destroyed. A duplicate controller is destroyed, refunded on the platform surface, and reported to the force.

Companion invariants:

- Every companion shares the controller's surface and exact position.
- A valid stored reference at that position is authoritative.
- `find_companion` recovers a missing reference locally and removes same-position duplicates.
- Broad orphan scans run only during registration or rebuild, never during the 10-tick update.
- Mining, death, scripted destruction, and invalid-record cleanup remove companions through stored references.

`rebuild_drives` reconstructs records from controllers during initialization and configuration changes. It removes orphans and duplicates, adopts valid companions, recreates permanent companions, and discards the removed detector-power output fields.

## Electrical Lifecycle

### Detector

Before Practical research, manual or circuit control gates the shared power interface. While enabled, it adaptively requests up to `1 GW`. Every 10 ticks, runtime takes the delta of the interface prototype's cumulative electric-network input and converts those consumed joules to average delivered watts:

```text
delivered watts = consumed joules * 60 / elapsed ticks
```

The result is capped at `1 GW`. After a shortfall greater than `0.1 MW`, the next request drops to measured delivery. When the request is fully supplied within that absolute tolerance, it increases by `10 MW`. This feedback converges near generation left over after ordinary ship demand while continuing to probe changing capacity. Research scales against a `200 MW` reference, so the power factor ranges continuously from `0` to `5`. The interface's zero output limit prevents sampled energy from powering the ship.

### Charge

After Practical research, detector energy and sampling state are discarded and the same interface enters practical mode. `LuaSpacePlatform.weight` is already kilograms at runtime, so required reserve is exactly `platform.weight * 100 J/kg` with no data-stage gram conversion. `record.reserve_energy` is authoritative; the interface buffer is only a short-lived electrical sample and never stores or outputs the reserve. Once control, minimum speed, active travel, endpoint clearance, and cooldown all permit entry, an incomplete reserve makes the interface request `platform.weight * 10 W/kg`; runtime code converts measured delivered watts into joules every 10 ticks and caps the private reserve to the mass-scaled requirement. Losing any prerequisite disables the request and resets the reserve to zero. Full delivery therefore charges an empty reserve in 10 uninterrupted seconds. Warp entry spends 90% of that charge and retains 10% as support reserve. During warp, up to the same `10 W/kg` rate replenishes the reserve after support demand is satisfied. A current-level support deficit drains it in proportion to the shortfall; a complete outage lasts 1 second immediately after entry or 10 seconds once fully replenished.

### Support

Once every non-reserve entry requirement is satisfied, the interface requests `platform weight in kg * 10 W/kg`. Losing any prerequisite disables that request immediately and clears the private reserve, preserving the uninterrupted charging challenge and transition. Once the audible buildup has started, interruption also starts a 300-tick re-entry lockout through the existing `cooldown_until` mechanism. During warp it requests the next level's support demand plus up to `platform weight in kg * 10 W/kg` to replenish missing reserve energy. Runtime electric-flow fields use joules per tick, so watt values are divided by `60` when setting `power_usage` and `input_flow_limit`. The GUI reports the drive's measured total electrical consumption, including support and reserve replenishment, in one checklist row.

The interface has a one-tick buffer and consumes continuously. Electric statistics report the interface prototype's actual cumulative consumption; one drive per platform makes each interval delta unambiguous even when Factorio relates multiple electrical subnetworks. Runtime resets the baseline when the interface changes subnetworks. Secondary-input mode also keeps the buffer out of Factorio's accumulator-charge totals. The interface cannot output to the ship. Runtime allocation satisfies sampled support demand first and transfers only additional delivered power into the reserve. Two update intervals of startup grace let Factorio attach and service a newly configured sink before the first shortfall check. During a brownout, Factorio proportions available power across the drive and other secondary consumers normally. At least 99.9% delivery of next-level demand permits acceleration. Delivery below current-level demand holds the current level and drains reserve. Depleting the reserve exits warp.

### Companion States

| State | Companion effect |
| --- | --- |
| `detector-offline`, `detecting` | Power interface samples experimental detector demand |
| `charging` | Power interface samples delivered charging power into the private reserve |
| `idle` | Power interface is disabled because a non-reserve entry requirement is blocked |
| `warp` | Power interface samples support plus reserve-replenishment demand |
| `cooldown` | Power interface is disabled and the private reserve remains empty |

Research revocation while active exits warp, clears the private reserve, and reconfigures the interface for detector mode. Any warp exit disables the interface request and starts the 600-tick lockout. Disabling the selected control mode, a false circuit condition, route loss, and endpoint clearance exit immediately. Engine speed below `50 km/s` instead starts a 300-tick warning while retaining Warp-1; recovery cancels the warning, otherwise expiry exits with an insufficient-speed reason. Runtime warning and last-exit reason fields drive the prominent GUI alert.

## Circuit Composition

The visible controller reads the configurable engagement condition. The hidden combinator owns configurable output slots and is script-connected to both controller wire colors. The GUI presents these settings in a narrow right-side Circuit Network panel.

| Default signal | Output |
| --- | --- |
| `W` | Completed integer warp level while engaged, otherwise `0` |
| `D` | Whole kilometres remaining to the active connection destination |
| `C` | Warp support reserve percentage, capped at `100` |
| `S` | Effective integer speed |
| `T` | Whole tachyon particles per second at the current route depth; omitted after Practical research |

Every output is independently enabled and signal-selectable. `W`, `C`, and `S` remain enabled on existing records; `D` and `T` are opt-in. Research mode hides and suppresses `W` and `S`, while practical mode hides and suppresses `T`. The removed detector-power output is not serialized or emitted. The main GUI derives a live engagement checklist from the same runtime predicates used by entry and exit, including destination identity and remaining connection kilometres for endpoint clearance. Blueprint tags and settings paste preserve control and output settings. Opening the controller is intercepted for the custom GUI unless the cursor holds a wire, planner, blueprint, or other tool.

## Validation

After changing composition prototypes or lifecycle code:

1. Run `./make.sh`.
2. Run Factorio with `--dump-data` and inspect resolved prototypes.
3. Run `./tests/run-runtime-tests.sh`.
4. Run `git diff --check`.

The scripted suite covers placement, duplicate rejection, companion recovery and cleanup, electrical transitions, circuit output, research revocation, and relocation. Interactive checks remain necessary for electrical behavior, graphics, GUI interception, robots and ghosts, and wire geometry.
