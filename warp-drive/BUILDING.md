# Warp Drive Composite Building

**Document role:** this is the maintainer reference for the Warp Drive's composite entity: its prototypes, companion ownership, electrical roles, lifecycle, wiring, rendering, and migration. It does not specify gameplay balance, research routing, or location calculations. `README.md` is authoritative for player-facing behavior and values; `PLAN.md` tracks unfinished work.

## Why It Is Composite

No single Factorio entity provides a large selectable building, continuous animation, circuit input and output, surplus-priority sampling, persistent charge, and a dynamic electrical load. The placed drive therefore consists of one visible controller and hidden companions at the same position.

The controller owns the composite. Companions are never independently placeable, selectable, minable, blueprintable, deconstructable, or colliding.

| Need | Composition choice |
| --- | --- |
| Player interaction and circuit input | Visible `constant-combinator` controller |
| Continuous layered graphics | Zero-power animation companion |
| Surplus detector sampling | Tertiary accumulator drained after each sample |
| Persistent activation charge | Separate tertiary accumulator |
| Weight-dependent support load | Runtime-configured electric energy interface |
| Scripted circuit output | Hidden output combinator |

Detector and charge storage remain separate so experimental detector energy cannot become activation charge. Support uses a separate interface because it needs secondary-input priority and a runtime-sized interval buffer.

## Prototype Composition

| Prototype | Type | Lifetime | Role |
| --- | --- | --- | --- |
| `warp-drive-controller` | `constant-combinator` | Always | Visible 6x6 entity, ownership anchor, health, collision, mining, circuit input, and GUI target |
| `warp-drive-animation` | `electric-energy-interface` | Always | Zero-power 100-frame animation, emission, and shadow |
| `warp-drive-detector-load` | `accumulator` | Before Practical research | Tertiary `1 GW` detector sample with a `167 MJ` buffer |
| `warp-drive-charge-buffer` | `accumulator` | After Practical research | Tertiary `100 GJ` store with `200 MW` input and no output |
| `warp-drive-support-load` | `electric-energy-interface` | During warp | Secondary-input sample of the current support demand |
| `warp-drive-circuit-output` | `constant-combinator` | Always | Scripted `W`, `C`, `S`, and `P` outputs on both wire colors |

Legacy prototypes `warp-drive`, `warp-drive-visual`, `warp-drive-machine`, and `warp-drive-structure` remain hidden only for save migration. New items place `warp-drive-controller`.

## Rendering And Wires

The controller renders the first structure frame for placement previews. The animation companion renders the full animation, additive emission, and repeated shadow on `higher-object-under`. Both use the same scale and `util.by_pixel(0, -16)` shift.

The symmetric footprint reuses one circuit connection definition in all directions. When adjusting it:

- Keep red and green endpoints ordered like vanilla entities to avoid crossed wires.
- Move each endpoint with its matching shadow point.
- Validate attachment, sag, and overlap in game.

## Runtime Ownership

`storage.drives` is keyed by `LuaSpacePlatform.index`. Each platform may own one record and one controller.

| Field | Role |
| --- | --- |
| `entity`, `platform_index` | Controller reference and platform identity |
| `animation`, `detector`, `charge`, `support`, `circuit_output` | Companion references |
| `enabled`, `circuit_enabled` | Player engagement settings |
| `state`, `cooldown_until` | Composite state and lockout |
| `last_distance`, `direction` | Travel samples used by movement logic |
| `detector_power`, `detector_power_ratio` | Latest detector sample and factor relative to `200 MW` |
| `warp_level`, `requested_warp_level`, `warp_target` | Current, probed, and sustainable warp levels |
| `support_power`, `support_sample_watts`, `support_check_after` | Delivered power, requested power, and startup grace |
| `warp_ramp_state` | GUI acceleration status |

Build events call `register_drive`. Invalid off-platform placement is destroyed. A duplicate controller is destroyed, refunded on the platform surface, and reported to the force.

Companion invariants:

- Every companion shares the controller's surface and exact position.
- A valid stored reference at that position is authoritative.
- `find_companion` recovers a missing reference locally and removes same-position duplicates.
- Broad orphan scans run only during registration or rebuild, never during the 10-tick update.
- Mining, death, scripted destruction, and invalid-record cleanup remove companions through stored references.

`rebuild_drives` reconstructs records from controllers during initialization and configuration changes. It removes orphans and duplicates, adopts valid companions, and recreates permanent companions.

## Electrical Lifecycle

### Detector

Before Practical research, the charge companion is absent and the detector companion is present. Every 10 ticks, stored detector energy is converted to delivered watts and then drained:

```text
watts = stored joules * 60 / update ticks
```

The result is capped at `1 GW`. Research scales against a `200 MW` reference, so the power factor ranges continuously from `0` to `5`. A real tertiary accumulator lets Factorio's network solver determine surplus power.

### Charge

After Practical research, the detector is removed and the charge accumulator is created. Required energy is `platform weight in kg * 500 J/kg`. Charging is disabled during warp and cooldown. Entry drains the buffer completely.

### Support

During warp, the support interface's buffer is set to one 10-tick interval of `platform weight in kg * 20 W/kg * requested warp level`. The requested level is one update step above the current level while acceleration is possible. Each update converts stored energy to delivered watts, drains the sample, and configures the next request. Two update intervals of startup grace let a new sink receive power.

The interval buffer measures current delivery; electric-network connection alone does not prove that the requested load was supplied. At least 99.9% delivery permits the requested step. Partial delivery derives a lower sustainable level and applies it immediately; less than 99.9% of Warp-1 demand exits warp.

### Companion States

| State | Companion effect |
| --- | --- |
| `detector-offline`, `detecting` | Detector exists; charge and support do not |
| `charging`, `ready` | Charge exists and may accept power; detector and support do not |
| `warp` | Charge input is disabled; support exists and is sampled |
| `cooldown` | Support is removed and charge input remains disabled |

Research revocation while active exits warp, removes support, removes charge, and restores detector mode. Any warp exit removes support and starts the 600-tick lockout.

## Circuit Composition

The visible controller reads the optional `E` input. The hidden combinator owns output slots and is script-connected to both controller wire colors.

| Signal | Output |
| --- | --- |
| `W` | `1` in warp, otherwise `0` |
| `C` | Charge percentage, capped at `100` |
| `S` | Effective integer speed |
| `P` | Detector power percentage relative to the `200 MW` reference, capped at `500` |

Blueprint tags preserve the circuit-control toggle. Settings paste copies both runtime toggles. Opening the controller is intercepted for the custom GUI unless the cursor holds a wire, planner, blueprint, or other tool.

## Migration

On configuration change, `migrate_legacy_drives` replaces legacy entities with `warp-drive-controller` while preserving:

- Surface, position, direction, and force
- Health ratio
- Red and green circuit connections, connector IDs, and wire origin
- Stored energy as charge only when Practical Warp Drive is researched

`rebuild_drives` then restores records and companions. Legacy prototypes must remain until supported saves can no longer contain them, because Factorio must deserialize an entity before migration can replace it.

## Validation

After changing composition prototypes or lifecycle code:

1. Run `./make.sh`.
2. Run Factorio with `--dump-data` and inspect resolved prototypes.
3. Run `./tests/run-runtime-tests.sh`.
4. Run `git diff --check`.

The scripted suite covers placement, duplicate rejection, companion recovery and cleanup, electrical transitions, circuit output, research revocation, relocation, and legacy migration. Interactive checks remain necessary for electrical behavior, graphics, GUI interception, robots and ghosts, and wire geometry.
