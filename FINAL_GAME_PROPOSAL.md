# SPACELAB Final Game Proposal

> Design status: speculative. Nothing in this document is implemented or part of the current player-facing feature set. `README.md` remains the source of truth for released gameplay.

## Executive Recommendation

Add a two-stage **Deep Space Warp Drive** progression after the existing SPACELAB technology branches, centered on one new building: the **Warp Drive**.

1. **Theoretical Warp Drive** unlocks the Warp Drive building in an experimental state.
2. **Practical Warp Drive** is a regular technology with an enormous, deliberately impractical laboratory research cost. A placed Warp Drive detects Subspace Tachyon Particles and converts its location into a research-speed multiplier for eligible laboratories on that same space platform, making the technology practical to complete in deep space.
3. Practical Warp Drive makes every placed Warp Drive functional. It engages at sufficient platform speed while its GUI or circuit engagement condition remains true and disengages as soon as that condition is no longer met.

Warp is accelerated travel, not teleportation. The script advances the platform gradually along its active connection so a route that normally takes about three minutes takes roughly ten seconds in warp. This preserves smooth platform-icon movement on the space map, normal route direction, and Factorio's schedule and arrival flow.

While warped, the platform travels through subspace. Ordinary asteroid chunks are removed immediately upon entry and continuously suppressed because they do not exist in that plane. Blue-white streaks and lighting make the state visible on the platform surface.

## Design Goals

- Add only one new gameplay building and no new particle item or dedicated research facility.
- Allow exactly one Warp Drive to be built on each space platform.
- Let that building guide the player from theoretical discovery through practical unlock and operation.
- Turn deep-space laboratory operation into the practical means of completing an otherwise prohibitive technology.
- Make deep and dangerous routes the best places to complete the experiment.
- Make warp visibly fast travel rather than an instantaneous endpoint jump.
- Preserve normal platform schedules, surfaces, route direction, map animation, and multiplayer ownership.
- Support automatic operation and explicit circuit control.
- Keep Practical Warp Drive in Factorio's ordinary technology queue with normal science-pack consumption and progress.

## Why Deep Space Should Matter

The Shattered Planet route is 4,000,000 km long, and official milestones at 10,000 km, 30,000 km, and 60,000 km already frame distance as a post-game achievement.[^wiki-shattered] Asteroid density eventually makes the route an open-ended platform-engineering challenge rather than an expected ordinary destination.

The Warp Drive turns that challenge into progression. It detects transient Subspace Tachyon Particles without materializing them as inventory items. Their effective density rises with distance from inhabited space and peaks around the anomalous core represented by the far end of the Shattered Planet connection. The resulting point multiplier speeds eligible laboratories on that same platform, allowing an enduring deep-space research platform to complete Practical Warp Drive far faster than laboratories parked safely near a planet.

## Technology Progression

### 1. Research Theoretical Warp Drive

Theoretical Warp Drive becomes available after all current SPACELAB technology branches. It is an ordinary force-wide technology using the complete late-game science set, following the mod's established post-Solar System Edge research pattern.

It unlocks the Warp Drive item, recipe, and platform-only building. At this stage the building cannot propel its platform. It instead acts as a platform-local laboratory accelerator and practical-research guide. Its interface shows:

- Why the drive is still experimental.
- Current Subspace Tachyon Particle density.
- Current point multiplier derived from the drive's location.
- Effective research-speed bonus granted to eligible laboratories on this platform.
- Force-wide progress toward Practical Warp Drive.
- Estimated time to completion at the current location.
- The higher-value regions available farther into space.

This keeps discovery, guidance, research, and eventual operation attached to one recognizable object.

### 2. Research Practical Warp Drive

Practical Warp Drive is a regular technology with ordinary prerequisites, science-pack ingredients, unit time, and laboratory research progress. Its unit count is intentionally enormous: technically researchable without a Warp Drive multiplier, but prohibitively slow in practice. It must appear in and occupy the normal research queue, consume science packs normally, and complete through ordinary laboratory research rather than a scripted research trigger.

Each powered Warp Drive passively detects tachyon events and applies its current point multiplier to eligible laboratories on the same space platform while Practical Warp Drive is the active research. No intermediate particle item, recipe, harvester, research-array entity, parallel point pool, or scripted completion is required.

For this purpose, an eligible laboratory is a lab on the Warp Drive's current platform whose runtime status is `working` while Practical Warp Drive is the force's active research. The game continues applying every lab's ordinary contribution. The script calculates the eligible platform labs' additional contribution from their resolved research speeds and adds only the bonus represented by `(point multiplier - 1)` to the force's ordinary Practical Warp Drive progress, avoiding double-counting the baseline `1x` contribution.

Because the bonus is added through `LuaForce.research_progress`, eligible labs consume science packs at their ordinary working rate rather than at the multiplied rate. The point multiplier therefore represents tachyon-assisted research efficiency as well as faster completion: the technology retains its enormous nominal prototype cost, but deep-space labs need fewer science packs to complete it. Attempting to remove thousands of additional packs per lab cycle to emulate `5,000x` physical throughput would make the intended multiplier unusable and is not part of this design.

| Drive location | Point multiplier |
| --- | ---: |
| Planet surface | `1x` |
| Orbit around a space location | `10x` |
| Deep-space connection | `100x` to `1,000x` |
| Near the Shattered Planet anomalous core | `5,000x+` |

The deep-space multiplier scales with route depth and distance rather than jumping directly from `100x` to `1,000x`. The anomalous-core bonus begins only in the final portion of the Solar System Edge to Shattered Planet connection and continues rising toward its far endpoint. Other long connections still receive generic deep-space scaling for compatibility, but only the canonical anomaly receives the special curve.

Technology progress remains force-wide, as with every regular technology, so eligible laboratories on multiple platforms may cooperate. Each drive's multiplier applies only to laboratories on its own platform; it must not accelerate planetary laboratories or laboratories on another platform.

When ordinary research completes Practical Warp Drive, its technology effects make existing Warp Drives functional immediately without replacement.

### 3. Configure the Functional Drive

After Practical Warp Drive is researched, opening a Warp Drive shows operational status and controls:

- Practical technology state.
- Active connection and destination.
- Current platform speed and minimum engagement speed.
- Automatic warp enabled or disabled.
- The configured GUI or circuit engagement condition.
- Current state: `IDLE`, `READY`, `WARP`, or `COOLDOWN`.
- Estimated normal and warp travel times.

The building should expose circuit signals for readiness, active warp, current speed, current point multiplier, and Practical Warp Drive research progress. Exact signal names and defaults should be selected during implementation to avoid conflicting meanings.

### 4. Engage and Disengage Warp

A platform is eligible to enter warp when:

- Its single Warp Drive is functional.
- It is traveling on a valid space connection.
- Its measured `LuaSpacePlatform.speed` is at least `50`.[^api-platform]
- It is moving toward one endpoint rather than stopped, departing, or arriving.
- It is not inside an activation cooldown.

The platform's Warp Drive has one sustained **warp engagement** condition:

- Without a circuit condition, the GUI toggle acts as a constant true or false value.
- With a circuit condition, warp engages when that condition and all platform eligibility conditions are true.
- If the condition becomes false while warped, warp disengages immediately at the platform's current route position.
- Losing eligibility, pausing the platform, or reaching the destination also disengages warp.

The drive GUI remains usable without circuits. Players can toggle the engagement condition directly for commissioning and troubleshooting. Circuit-connected drives use Factorio's normal configurable circuit-condition model rather than dedicated command signals.

A primary automation pattern is resource-aware travel. Because ordinary asteroids do not exist in subspace, collectors cannot replenish asteroid chunks while warp is active. A separate decider combinator can monitor the platform's chunk reserves and hold the Warp Drive's engagement condition true only while enough feedstock remains. When reserves fall below the configured threshold, the condition becomes false, the platform returns to normal space, and collectors can gather Metallic, Carbonic, Oxide, and Promethium asteroid chunks. Once reserves recover, the circuit permits warp again.

The Warp Drive should not hard-code resource thresholds or inspect particular chunk types for this behavior. Standard circuit signals and combinators let each platform define which resources are critical, how much reserve it needs, and whether several conditions must be satisfied before entering warp.

### 5. Travel Smoothly Through Warp

Warp gradually advances the platform's writable normalized `LuaSpacePlatform.distance` in its existing direction.[^api-platform] It must not set the platform directly near the endpoint in one update.

The intended target is approximately:

- Normal representative route: about 180 seconds.
- Same route in warp: about 10 seconds.
- Approximate travel acceleration: `18x`, subject to prototype testing.

The update loop should derive a warp delta from elapsed ticks and connection length so travel duration remains stable and the map icon moves smoothly:

1. Sample the current connection, distance, direction, and tick.
2. Calculate the remaining normalized route distance.
3. Add only the small delta appropriate for the update interval and target warp speed.
4. Clamp just short of `0` or `1`, then let Factorio perform its normal arrival transition.
5. Stop immediately if connection, direction, platform state, or engagement condition changes.

Updates should be frequent enough for smooth global-map animation, likely every tick or every few ticks for warped platforms only. Point-multiplier and laboratory-eligibility evaluation can remain on coarse staggered updates. This limits runtime cost while preserving the visible travel effect.

Warp cannot select an arbitrary destination, cross a locked connection, reverse the platform, or bypass its schedule. When the engagement condition becomes false, the platform remains at its current intermediate route position and normal travel resumes from there.

### 6. Enter Subspace

Warp represents travel through another plane of space. Ordinary asteroid chunks do not exist there, so entering warp immediately removes all chunks already present around the platform with one unfiltered call to `LuaSpacePlatform::destroy_asteroid_chunks()`.[^api-destroy-asteroids]

The script repeats that call while warp remains active because the normal connection may continue spawning chunks after activation. Total removal is part of the subspace-travel fiction, not a collision-management convenience.

Asteroid chunks are not removed before warp engages. The platform must survive normal acceleration to the engagement threshold. Disengagement returns it to normal space at its current route position, where ordinary asteroid spawning and danger resume.

### 7. Present the Effect

Warp should be unmistakable to players viewing the platform:

- Short-lived blue-white lines stream opposite the direction of travel.
- A cool light pulse surrounds each active Warp Drive.
- Activation and exit use distinct sounds and messages.
- The drive interface and circuit output report the active state.
- The global map shows the platform icon moving continuously and rapidly along the connection.

`LuaRendering::draw_line()` and `draw_light()` can create the first version without additional gameplay entities.[^api-rendering] Effects should use short lifetimes and refresh while warped so save data and rendering-object counts remain bounded.

## Research Gating Feasibility

Technology prototypes can define the enormous Practical Warp Drive unit count, science ingredients, unit time, prerequisites, and unlock effects.[^api-technology-prototype] The technology itself remains ordinary and force-wide; platform location changes the speed of eligible laboratories, not the technology's cost or accumulated progress.

`LuaForce.laboratory_speed_modifier` is writable, but it applies to the entire force.[^api-force] Setting it from one deep-space platform would accelerate planetary laboratories and laboratories on unrelated platforms, so it is not suitable for this local point multiplier. Factorio exposes writable force research progress but no documented writable per-lab research-speed property. The implementation therefore simulates platform-local acceleration by periodically enumerating labs on each Warp Drive platform, selecting only labs with `defines.entity_status.working`, and adding their multiplier-derived bonus to `LuaForce.research_progress`.[^api-entity]

For an update interval of `elapsed_ticks`, the conceptual bonus is:

```text
bonus progress = sum(eligible lab research rates)
               * (platform point multiplier - 1)
               * elapsed time
               / Practical Warp Drive total research work
```

The implementation should derive each lab's base rate from its prototype and include its resolved speed bonus, then validate the result against observed vanilla progress. It adds no bonus at `1x`, rechecks that Practical Warp Drive is still the active technology immediately before writing progress, caps completion safely, and stops as soon as research changes or completes. Labs on other surfaces continue contributing normally but are excluded from the scripted bonus. This must not maintain a separate project, bypass the technology queue, or call scripted research completion.

Counting completed research cycles per lab would be conceptually simpler, but Factorio exposes neither an individual-lab research-cycle completion event nor readable lab-cycle progress. `LuaEntity.crafting_progress` and `is_crafting()` apply to crafting machines rather than labs, and science-pack stored durability can change for reasons that do not identify an atomic completed cycle. The reliable implementation is therefore elapsed-time integration from labs whose runtime status is `working`. A virtual per-lab cycle accumulator could present discrete updates, but it would only reimplement the same calculation and is unnecessary unless playtesting shows that continuous progress updates are undesirable.

Runtime code can classify a drive from its surface and owning platform:

- A non-platform planetary surface uses `1x` if placement there is intentionally supported; otherwise the drive remains platform-only and this tier is informational.
- A platform stopped at a space location uses `10x`.
- A traveling platform uses its `space_connection`, connection `length`, and normalized `distance` to calculate deep-space depth.[^api-platform][^api-connection]
- The anomalous-core curve applies only near the Shattered Planet endpoint of its canonical connection.

Direction must be handled explicitly because normalized distance is `0` at `connection.from` and `1` at `connection.to`. Identify the Shattered Planet endpoint by prototype name rather than assuming it is always `to`.

## Warp Runtime Feasibility

The Factorio 2.1 runtime API exposes the required platform operations:

- `LuaForce.platforms` enumerates force-owned platforms.[^api-force]
- `LuaForce.current_research` and writable `research_progress` expose ordinary force research state, while `laboratory_speed_modifier` is force-wide rather than platform-local.[^api-force]
- `LuaEntity.status`, `speed_bonus`, and `LuaEntityPrototype::get_researching_speed()` allow the script to identify working labs and estimate their resolved research contribution.[^api-entity]
- `LuaSpacePlatform.space_connection`, `distance`, `state`, `speed`, and `surface` expose travel state; `distance` and `speed` are writable.[^api-platform]
- `LuaSpaceConnectionPrototype.length`, `from`, and `to` describe the active route.[^api-connection]
- `LuaSpacePlatform::destroy_asteroid_chunks()` removes existing and subsequently spawned chunks when called on entry and during warp.[^api-destroy-asteroids]
- `LuaRendering` supports temporary lines, sprites, and lights on the platform surface.[^api-rendering]

No asteroid-spawn event should be assumed. Distance advancement, asteroid suppression, visual refresh, and circuit evaluation can run for active warped platforms from `on_nth_tick` or a lightweight tick handler. `on_space_platform_changed_state` remains useful for immediate cleanup on arrival or interruption.[^api-events]

The proposal specifies behavior rather than implementation-ready Lua snippets. Exact speed units, safe distance deltas, endpoint margins, circuit APIs, state transitions, and update intervals must be validated in a prototype save before balance is fixed.

## State and Multiplayer Rules

- **One building type:** Every phase uses the same Warp Drive prototype; no separate harvester, research array, or particle item is added.
- **One per platform:** A platform may contain at most one Warp Drive. Placement of a second drive is rejected and refunded with a clear player message. Build events and periodic validation enforce the rule for player, robot, and script construction.
- **Regular technology:** Practical Warp Drive uses the normal force research queue, laboratory inputs, and technology progress despite its enormous cost.
- **Local multipliers:** Each drive grants scripted bonus progress only for working laboratories on its own platform using its current location.
- **Permanent unlock:** Once Practical Warp Drive completes, losing the research platform does not revoke it.
- **Platform-local warp:** Each platform evaluates its drive, speed, and engagement condition independently.
- **Sustained control:** Warp remains active only while the configured engagement condition remains true.
- **Force changes:** A platform changing force immediately uses the new force's Practical Warp Drive technology state.
- **Save migration:** Configuration changes rebuild drive indexes, preserve completed technologies and ordinary research progress, and discard invalid references.
- **Removed routes:** Missing vanilla route prototypes disable the special anomaly curve but not generic deep-space research or warp on valid connections.
- **Performance:** Stagger platform-lab multiplier evaluation, but update only active warped platforms frequently enough for smooth map movement.

## Balance Framework

The multipliers establish the intended order of magnitude, while the Practical Warp Drive unit count, unit time, science ingredients, minimum engagement speed, and exact warp duration remain playtest values.

The target experience is:

- A newly placed drive clearly explains that Practical Warp Drive is a normal but prohibitively expensive technology and how distance accelerates eligible labs on that platform.
- Orbit is useful for commissioning but too slow for an efficient unlock.
- Deep-space operation gives a practical path to completion.
- Approaching the anomalous core is the fastest research route and a prestige challenge, not a mandatory literal arrival.
- Warp reduces a representative three-minute route to roughly ten seconds while retaining visibly continuous map movement.
- The platform must reach speed `50` under normal propulsion before entering subspace.
- Disengaging the condition restores asteroid danger immediately.
- Continuous warp prevents asteroid collection, so platforms dependent on asteroid resources must periodically travel in normal space or carry sufficient reserves.
- Circuit-controlled resource thresholds create a deliberate cycle between fast subspace travel and slower harvesting windows.
- Circuits support automation without being required for basic use.

## Suggested Delivery Plan

### Phase 1: Runtime Proof

- Add a debug-only minimal Warp Drive prototype and inspect platform speed, state, connection, and normalized distance.
- Validate scripted bonus progress from working platform labs, ordinary-rate science-pack consumption, and no bonus from labs elsewhere.
- Validate small, frequent distance writes in both directions and confirm smooth global-map icon movement.
- Measure a three-minute route and tune warp travel toward ten seconds without endpoint jumps.
- Validate immediate and continued asteroid removal, condition-based disengagement, and normal travel resumption.
- Validate circuit reads and outputs on a platform building before finalizing the command contract.
- Validate a decider-controlled journey that exits warp on low asteroid-chunk reserves and re-engages after collectors replenish them.

### Phase 2: Experimental Drive

- Add Theoretical Warp Drive and the final Warp Drive item, recipe, entity, and locale.
- Enforce the one-drive-per-platform placement rule for player, robot, and script-built entities.
- Add Practical Warp Drive as a regular technology with its deliberately enormous research cost.
- Implement location-scaled bonus progress from working laboratories on each drive's platform.
- Build the drive interface with guidance, point multiplier, effective local lab speed, progress, and estimated completion.
- Add migration and multiplayer tests.

### Phase 3: Functional Drive

- Activate existing drives after Practical Warp Drive completes.
- Add GUI and circuit-controlled sustained engagement and automatic disengagement.
- Add gradual route advancement, endpoint safety margins, cooldowns, and subspace asteroid removal.
- Add blue-white line and light effects, sounds, status output, and global-map verification.
- Test departures, arrivals, reversals, pauses, force changes, and duplicate placement attempts.

### Phase 4: Polish and Compatibility

- Replace placeholder visuals with original assets.
- Expose remote interfaces only if another mod has a concrete integration need.
- Add configurable balance values only where playtesting demonstrates a real need.

## Implementation Footprint

- `info.json`: keep the current Factorio 2.1 and Space Age requirements; no new runtime dependency is expected.
- `data.lua`: load the Warp Drive item, recipe, entity, technologies, signals, and visual-effect prototypes from the existing `prototypes/` structure.
- `control.lua`: own platform-local laboratory acceleration, drive UI, circuit conditions and outputs, warp state, gradual distance advancement, asteroid removal, rendering, migrations, and multiplayer events.
- `graphics/`: contain original Warp Drive, technology, signal, and warp-effect assets as they become available.
- `locale/en/strings.cfg`: follow the existing locale convention for names, guidance, state, controls, and failure messages.

The runtime proof should precede production art and balance work. Smooth incremental travel on the global map is a core requirement, so an instant endpoint write is not an acceptable fallback for the final design.

## Open Design Decisions

- What Practical Warp Drive unit count and unit time produce the desired completion times at each multiplier?
- Should lab quality, module speed, and beacon speed all contribute to the resolved rate used for scripted bonus progress?
- Where do the `100x` to `1,000x` deep-space curve and `5,000x+` anomaly curve begin?
- Should warp target a fixed route duration, a fixed kilometer speed, or an `18x` multiplier over normal travel?
- Which virtual signals should report ready and active states?
- Should the engagement control use any configurable circuit condition or a dedicated warp signal?
- Should warp consume additional electricity, or is maintaining speed `50` and owning the drive sufficient?
- Should dropping out of warp impose a brief warning before normal asteroid danger resumes?

## Sources

Official facts and API capabilities are evidence for feasibility, not confirmation that the proposed gameplay is implemented.

[^wiki-shattered]: Official Factorio Wiki, [Shattered planet](https://wiki.factorio.com/Shattered_planet), including route length, achievement distances, asteroid scaling, and the statement that reaching the destination is not expected.
[^api-platform]: Factorio 2.1 Runtime API, [`LuaSpacePlatform`](https://lua-api.factorio.com/latest/classes/LuaSpacePlatform.html), including `space_connection`, `distance`, `state`, `speed`, `surface`, and force platform usage.
[^api-connection]: Factorio 2.1 Runtime API, [`LuaSpaceConnectionPrototype`](https://lua-api.factorio.com/latest/classes/LuaSpaceConnectionPrototype.html), including `from`, `to`, and `length`.
[^api-force]: Factorio 2.1 Runtime API, [`LuaForce`](https://lua-api.factorio.com/latest/classes/LuaForce.html), including `platforms`, `current_research`, writable `research_progress`, technologies, and `laboratory_speed_modifier`.
[^api-entity]: Factorio 2.1 Runtime API, [`LuaEntity`](https://lua-api.factorio.com/latest/classes/LuaEntity.html), including `status` and `speed_bonus`, and [`LuaEntityPrototype::get_researching_speed()`](https://lua-api.factorio.com/latest/classes/LuaEntityPrototype.html#get_researching_speed).
[^api-events]: Factorio 2.1 Runtime API, [`on_space_platform_changed_state`](https://lua-api.factorio.com/latest/events.html#on_space_platform_changed_state).
[^api-destroy-asteroids]: Factorio 2.1 Runtime API, [`LuaSpacePlatform::destroy_asteroid_chunks()`](https://lua-api.factorio.com/latest/classes/LuaSpacePlatform.html#destroy_asteroid_chunks).
[^api-rendering]: Factorio 2.1 Runtime API, [`LuaRendering`](https://lua-api.factorio.com/latest/classes/LuaRendering.html), including `draw_line()`, `draw_sprite()`, and `draw_light()`.
[^api-technology-prototype]: Factorio 2.1 Prototype API, [`TechnologyPrototype`](https://lua-api.factorio.com/latest/prototypes/TechnologyPrototype.html), including prerequisites, units, research triggers, and effects.
