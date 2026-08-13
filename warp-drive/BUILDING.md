# Warp Drive Building Architecture

This document describes the implementation of the Warp Drive building for maintainers. `README.md` remains authoritative for player-facing mechanics and balance values. When implementation details here conflict with player-visible behavior in `README.md`, fix the implementation or update both documents deliberately.

## Why The Building Is Composite

Factorio does not provide one entity prototype that cleanly combines all required behavior: a large selectable building, continuous layered animation, circuit input and output, surplus-priority energy sampling, persistent charge storage, and a dynamically sized electrical load. The placed Warp Drive is therefore one visible controller plus hidden companion entities at the same position.

The visible controller is the ownership anchor. Hidden companions must never be independently placeable, selectable, minable, blueprintable, deconstructable, or colliding. Runtime code treats every companion as belonging to the controller stored for the same platform.

The split is driven by prototype and runtime boundaries rather than a preference for many entities:

- Electrical `usage_priority` belongs to an energy-source prototype. The experimental detector must be tertiary so it only receives surplus power, while active support must be secondary input so warp competes as a real operating load. One electrical entity cannot have both priorities at once.
- Detector energy is deliberately discarded after each sample, while activation charge must persist across updates. Sharing storage would risk turning pre-research detector energy into activation charge and would make phase transitions harder to reason about.
- The support demand changes with platform weight. An electric energy interface exposes writable runtime buffer, flow-limit, and usage fields, allowing the script to create an interval-sized power sample. An accumulator supplies the correct persistent native charging behavior for activation energy instead.
- The visible entity must accept player circuit wires and remain a normal minable 6x6 building. A constant combinator provides those interactions without pretending the building crafts a recipe or exposing an accumulator's native charge UI.
- The scripted output signals and the player's `E` input have different ownership. A hidden output combinator keeps generated slots out of the visible controller and lets the controller remain an input endpoint.
- Continuous animation is independent of detector, charge, and warp state. A zero-power animation companion avoids coupling visuals to whether an accumulator is charging or an electric interface is currently satisfied.

Earlier single-entity prototypes remain in the mod as migration inputs. They demonstrated the tradeoffs: an accumulator supplied storage but coupled graphics to accumulator behavior, an assembling machine required artificial crafting semantics, and an electric energy interface could not also provide persistent tertiary charge plus the desired circuit behavior. The composite controller is the smallest arrangement found that keeps each player-visible invariant explicit.

## Design Decisions

| Decision | Reason | Rejected alternative |
| --- | --- | --- |
| Visible `constant-combinator` controller | Provides player wire connectors, health, collision, mining, and an event target while allowing a custom GUI. | A visible accumulator exposes native accumulator behavior and cannot emit the full scripted interface; an assembling machine implies recipes and crafting state that do not exist. |
| Separate detector and charge accumulators | Encodes different capacities and lifetimes in prototypes and prevents detector samples from becoming charge. | Reconfiguring one large accumulator at research completion creates ambiguous saved energy and more migration state. |
| Tertiary detector and charge priority | Ordinary platform facilities must retain power priority; both systems consume only generation left after normal loads. | Script-estimating grid surplus would duplicate Factorio's electrical network solver and be less reliable around brownouts. |
| Secondary active support sink | Active warp is an operating load, not optional background charging. | Tertiary support could remain starved behind unrelated accumulators even when the platform was otherwise designed to sustain warp. |
| Interval-sized support buffer | Measures recently delivered energy and makes power loss observable within bounded time. | A large buffer stores historical energy and can hide a current brownout. Reading only connection status proves that a producer exists, not that it delivered the requested watts. |
| Hidden output combinator | Separates script-owned output slots from player input and mirrors outputs onto both wire colors. | Writing outputs into the visible controller exposes mutable native slots and risks mixing script output configuration with player interaction. |
| Stored references plus local recovery | Normal updates are constant work per drive and cleanup cannot affect unrelated positions. | Full-surface scans every 10 ticks are unnecessarily expensive and can delete another composite entity's companions. |
| Broad orphan sweep only on rebuild | Configuration changes can leave companions whose references were not serialized by the current version. | Never scanning would leave old hidden entities permanently; scanning continuously pays migration cost during steady state. |
| Scripted route-distance movement | Space-platform speed is readable, while no native prototype supplies a temporary `100x` drive mode. | Replacing thrusters or modifying every engine would be invasive, mod-incompatible, and would not express endpoint margins cleanly. |

## Prototype Composition

| Prototype | Type | Lifetime | Responsibility |
| --- | --- | --- | --- |
| `warp-drive-controller` | `constant-combinator` | Always | Visible 6x6 building, collision and selection, mining, health, circuit wire endpoint, GUI target, and runtime ownership anchor. |
| `warp-drive-animation` | `electric-energy-interface` | Always | Continuously renders the 100-frame structure, additive emission, and shadow above the controller's static placement sprite. It consumes no power. |
| `warp-drive-detector-load` | `accumulator` | Before Practical Warp Drive | Samples up to `200 MW` at tertiary priority. Its `34 MJ` buffer covers one 10-tick sample with rounding headroom. |
| `warp-drive-charge-buffer` | `accumulator` | After Practical Warp Drive | Stores up to `100 GJ`, accepts up to `200 MW` at tertiary priority, and supplies activation charge accounting. It never outputs power. |
| `warp-drive-support-load` | `electric-energy-interface` | During warp only | Measures whether the platform delivered the current weight-dependent support demand during the preceding 10-tick interval. |
| `warp-drive-circuit-output` | `constant-combinator` | Always | Emits scripted `W`, `C`, `S`, and `P` signals. It is invisibly connected to both circuit colors on the visible controller. |

The hidden circuit output is separate because the visible controller also receives the optional `E` engagement signal. Keeping scripted output in a hidden combinator avoids exposing output slots through the visible controller's native combinator behavior.

The legacy prototypes `warp-drive`, `warp-drive-visual`, `warp-drive-machine`, and `warp-drive-structure` remain hidden solely so old saves can load and migrate. New placement always uses `warp-drive-controller` through the `warp-drive` item's `place_result`.

## Graphics And Wire Geometry

The controller renders frame 1 as its static sprite so placement previews and normal entity rendering have a stable image. The animation companion renders the full animation, additive emission, and repeated shadow on `higher-object-under`. Both use the same scale and `util.by_pixel(0, -16)` shift.

The controller uses one circuit connection definition copied to all four directions because the artwork and footprint are rotationally symmetric. Red and green endpoints sit near the artwork's top-left terminal. Their shadow points retain the elevated-wire displacement from each matching wire point.

Vanilla combinator definitions place red and green endpoints in a consistent order for each orientation and move their shadows as matching pairs. Warp Drive follows that convention rather than treating endpoint colors as interchangeable; reversing only the visible endpoints causes otherwise parallel red and green wires to cross on their way to a pole.

When changing connection coordinates:

- Keep red and green wire points visually ordered like vanilla circuit-capable buildings so parallel wires to a pole do not cross.
- Move each color's shadow point with its wire point; do not exchange only the visible coordinates.
- Inspect actual red and green wires in game. Prototype loading and scripted tests cannot validate sag, overlap, or apparent attachment to the artwork.

## Runtime Record

`storage.drives` is keyed by `LuaSpacePlatform.index`. Exactly one record and one visible controller are allowed per platform. A record owns these important values:

| Field | Meaning |
| --- | --- |
| `entity` | Visible `warp-drive-controller` and ownership anchor. |
| `platform_index` | Platform identity used to reject moved or stale records. |
| `animation`, `detector`, `charge`, `support`, `circuit_output` | Stored `LuaEntity` references to hidden companions. |
| `enabled` | Player automatic-engagement toggle. |
| `circuit_enabled` | Whether positive circuit signal `E` is required. |
| `state` | Current display and state-machine value. |
| `cooldown_until` | Tick at which charging and re-entry may resume. |
| `last_distance`, `direction` | Samples used to infer travel direction before scripted movement. |
| `detector_power`, `detector_power_ratio` | Most recently sampled detector delivery. |
| `support_check_after` | Startup grace limit before support-power failure can exit warp. |

## Placement And Ownership

Build events call `register_drive`. Placement outside a space platform is destroyed. If a valid controller is already registered on the platform, the duplicate is destroyed, its item is refunded on the platform surface, and the force receives the duplicate warning.

Companion ownership follows these invariants:

- Every companion is on the controller's surface and exact position.
- A valid stored reference at that position is authoritative.
- If a reference is absent or stale, `find_companion` adopts one matching entity at the controller position and destroys same-position duplicates.
- `recover_orphan_companions` performs broad cleanup only during registration or rebuild. The 10-tick update path never performs full-surface companion scans.
- Normal mining, death, scripted destruction, invalid-record cleanup, and replacement destroy companions through stored references.

`rebuild_drives` reconstructs records from visible controllers during initialization and configuration changes. It adopts valid companions, removes orphan companions, recreates permanent companions, and destroys duplicate visible controllers.

## Electrical Model

### Experimental Detector

Before Practical Warp Drive, `update_drive` destroys any charge buffer and ensures the detector accumulator exists. Every 10 ticks, `update_detector` converts stored joules into average delivered watts:

```text
watts = detector energy * 60 / update ticks
```

The result is capped at `200 MW`, stored for GUI, circuit, and research calculations, and the detector is drained to zero for the next interval. Tertiary input priority makes this a surplus-power measurement rather than a load that competes with ordinary facilities.

Using a real tertiary accumulator is intentional. Factorio's electrical solver decides what surplus power exists, including interactions with all other consumers and storage. Reconstructing that decision from production statistics in Lua would be an approximation and could disagree with the actual network.

### Activation Charge

After Practical Warp Drive, the detector is destroyed and the charge accumulator is created. Required activation energy is:

```text
platform weight in kg * 500 J/kg
```

The buffer charges at tertiary priority. It is disabled during warp and cooldown. Entering warp drains it completely, even when the platform required less than its stored capacity.

### Active Support

Warp support demand is:

```text
platform weight in kg * 20 W/kg
```

On entry and each 10-tick update, runtime code sets the support entity's buffer to exactly one interval of required energy and its input flow limit to the requested watts. `support_satisfied` checks for at least 95% of the interval requirement, then drains the entity. Draining is essential: energy from an earlier powered interval must not mask a later brownout.

The first support failure check is delayed by two update intervals after entry so the newly created sink has time to receive power. After that grace period, insufficient delivery exits warp immediately.

`is_connected_to_electric_network` is not enough for this check: it reports whether the network has a possible producer, not whether the requested energy was delivered. Measuring a bounded real buffer preserves Factorio's brownout behavior and makes the 95% tolerance explicit.

## State Machine

`update_drive` runs every 10 ticks. The meaningful states are:

| State | Conditions and behavior |
| --- | --- |
| `detector-offline` | Practical research is incomplete and sampled detector power is at most 1%. |
| `detecting` | Practical research is incomplete and detector power exceeds 1%. |
| `charging` | Practical research is complete but stored activation energy is insufficient. |
| `ready` | Charge is sufficient but one or more engagement conditions are not met. |
| `warp` | Charge was consumed and all continuous travel and support conditions remain true. |
| `cooldown` | A warp exit occurred less than 600 ticks ago; charging and re-entry are disabled. |

Warp entry requires all of the following:

- Automatic engagement is enabled.
- If circuit control is enabled, combined red/green input contains positive `E`.
- Practical Warp Drive is researched.
- The platform is on a connection with a valid distance.
- The platform is not paused.
- Platform speed is at least `50`.
- Travel direction has been observed from changing connection distance.
- The platform is more than `1,000 km` from both endpoints.
- Cooldown has expired.
- Activation charge is sufficient.

During warp, runtime adds the other `99x` of movement every update, clamps movement to the endpoint margin, and destroys asteroid chunks. Losing any preparation condition or support power calls `exit_warp`, destroys the support sink, and starts the 600-tick lockout. Revoking Practical Warp Drive while active also exits warp before restoring detector mode.

## Research Bonus

Once per second, `add_research_bonus` operates only when Practical Warp Drive is the current research and the detector reported power. It finds working labs on the same platform, derives their research rate from prototype speed, bonuses, and productivity, applies the location and detector-power multipliers, and adds bounded progress to Factorio's ordinary research queue.

The detector does not replace labs or science consumption. It adds progress relative to the work currently performed by eligible platform labs. Optional SPACELAB amplification remains disabled by `SPACELAB_INTEGRATION_ENABLED` until separately validated.

## Circuit Interface

Players connect red or green wires to the visible controller. The hidden output combinator is script-connected to both colors, making its outputs visible on either external network. Runtime updates four signals every 10 ticks:

| Signal | Value |
| --- | --- |
| `W` | `1` while state is `warp`, otherwise `0`. |
| `C` | Activation charge percentage, capped at `100`. |
| `S` | Effective integer speed, including the `100x` warp multiplier. |
| `P` | Detector power percentage. |

When circuit engagement is enabled, the visible controller reads `E` across both red and green connectors. A positive total permits engagement. Disabling automatic engagement or losing the circuit condition while active calls `exit_warp` immediately.

Blueprint tags preserve only the circuit-control toggle. Ordinary automatic engagement remains enabled by default. Settings paste copies both runtime toggles between registered drives.

## GUI And Interaction

The visible controller has no useful native combinator GUI. Opening it is intercepted and replaced with `warp_drive_window`. Opening is ignored while the cursor holds a wire, planner, blueprint, or other item so normal tool interaction can proceed without the status dialog appearing.

The GUI is rebuilt when opened and refreshed once per second. Before Practical research it emphasizes detector power and research contribution. After Practical research it also shows charge, speed, support demand, route clearance, cooldown, automatic engagement, and circuit control.

## Migration

On configuration change, `migrate_legacy_drives` finds legacy entity prototypes and replaces them with `warp-drive-controller`. Migration preserves:

- Surface, position, direction, and force.
- Health as a ratio of maximum health.
- Red and green circuit connections, target connector IDs, and wire origin.
- Stored energy as charge only if Practical Warp Drive is already researched.

After replacement, `rebuild_drives` restores records and companions. Do not remove hidden legacy prototypes until no supported save can contain them; Factorio must be able to deserialize the old entity before migration code can replace it.

## References And Prior Art

The architecture was checked against these implementations and APIs:

- [Factorio runtime `LuaEntity`](https://lua-api.factorio.com/latest/classes/LuaEntity.html) documents `get_signal`, wire connectors, electric-network inspection, and writable electric-energy-interface fields used by the controller and support sampler.
- [Factorio runtime `LuaSurface.find_entities_filtered`](https://lua-api.factorio.com/latest/classes/LuaSurface.html#find_entities_filtered) documents that omitting `area` or `position` searches the entire surface. This is why steady-state companion recovery is position-scoped and broad sweeps are limited to rebuilds.
- [Vanilla generated circuit connector definitions](https://github.com/wube/factorio-data/blob/master/core/lualib/circuit-connector-generated-definitions.lua) are the reference for keeping connector points and shadow offsets paired.
- [Vanilla combinator pictures](https://github.com/wube/factorio-data/blob/master/base/prototypes/entity/combinator-pictures.lua) show orientation-specific red/green ordering and are the visual reference for avoiding crossed parallel wires.
- The optional local `spacelab` mod's `prototypes/entities.lua` reuses the Space Age Cryogenic Plant's `circuit_connector` and `circuit_wire_max_distance` and uses layered animation with a repeated shadow. Warp Drive follows those compatibility patterns, but SPACELAB uses one ordinary assembling machine and is not the source of the composite runtime architecture.
- [Space Exploration](https://mods.factorio.com/mod/space-exploration) is referenced for the provenance of SPACELAB's temporary Growth Facility visuals, not for Warp Drive entity lifecycle code. No Space Exploration runtime implementation was copied into this building.

Local Factorio data and documentation under `/Applications/factorio.app/Contents/data` and `/Applications/factorio.app/Contents/doc-html` match the installed game version and should be preferred when a live documentation link has moved ahead of the supported Factorio release.

## Validation Requirements

After changing prototypes or building lifecycle code:

1. Run `./make.sh`.
2. Run Factorio with `--dump-data` and inspect resolved prototypes.
3. Run `./tests/run-runtime-tests.sh`.
4. Run `git diff --check`.

The scripted suite covers initialization, placement, duplicate rejection, companion lifecycle, detector sampling, research transition and revocation, charge consumption, warp movement, support-power loss, cooldown, relocation, circuit output, and legacy migration.

Interactive validation is still required for native electrical behavior under real platform generation, GUI appearance, animation and shadow alignment, naturally sampled travel direction, robots and ghosts, asteroid removal, and red/green wire attachment and sag.
