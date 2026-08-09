# SPACELAB Final Game Proposal

> Design status: speculative. Nothing in this document is implemented or part of the current player-facing feature set. `README.md` remains the source of truth for released gameplay.

## Executive Recommendation

Add a final expedition called **Deep-Space Convergence** whose central reward is a usable **Spacefold Drive**. The player builds a dedicated **Promethean Observatory** on a space platform, sends that platform more than **100,000 km toward the Shattered Planet**, and researches **Spacefold Propulsion** there while the ship survives the asteroid field.

The observatory consumes every science pack in the complete late-game science set. Research progress belongs to that observatory and platform, pauses when the platform retreats below 100,000 km or its inputs fail, and permanently completes the force-wide technology when the project finishes. Spacefold Propulsion unlocks a large platform-only drive that consumes an extreme amount of electricity while charging, then moves its platform almost instantly to just short of the active connection's destination.

This is preferable to ordinary laboratory research because Factorio technologies are force-wide and have no prototype field that restricts research to a planet, route, or platform. A runtime-controlled project can enforce the intended location without disabling unrelated research.

Use **100,000 km toward the Shattered Planet** as the research boundary. This is deliberately beyond the furthest official 60,000 km route achievement, but only 2.5% of the 4,000,000 km connection. It requires a genuinely deep-space platform without turning the unlock into a multi-hour literal-arrival test.

## Design Goals

- Give SPACELAB a transformative final technology rather than another infinite science multiplier.
- Make the final test an operating factory aboard a ship, not only a large item payment made at home.
- Require every science pack and thereby exercise the complete late-game factory, including SPACELAB's orbital production systems.
- Reward ship endurance, power management, storage, circuit control, and production balance simultaneously.
- Keep normal research available while the expedition runs.
- Make multiplayer ownership and completion simple: one qualifying platform can complete the objective for its force.
- Make the reward materially change space travel while preserving the normal platform and schedule model.
- Avoid adding a landable planet, new terrain generation, or an entire second campaign for the first version.

## Why the Voyage Should Be the Challenge

The official Factorio Wiki describes the Shattered Planet as a post-game location, gives its route a length of 4,000,000 km, and states that the player is not expected to reach it because asteroid density eventually overwhelms even a well-equipped ship. The same page lists achievements at 10,000 km, 30,000 km, and 60,000 km, which provide useful recognized milestones short of literal arrival.[^wiki-shattered]

Players have nevertheless turned reaching it into an engineering discipline. A long-running ship-sharing discussion includes varied platform sizes, travel times, ammunition strategies, storage plans, circuit controls, and power systems, reinforcing that the route is an open-ended engineering challenge rather than one solved design.[^forum-ships]

Community proposals commonly start from the desire for something meaningful at the end of the route, whether a final factory, a new surface, or a transformative technology.[^forum-surface][^forum-expectations] A deep-space research project makes time spent on the route productive, while the drive it unlocks gives that effort a concrete payoff.

## Proposed Final Project

### 1. Unlock Deep-Space Research

Completing all current SPACELAB technology branches unlocks the Promethean Observatory and reveals **Spacefold Propulsion**. Spacefold Propulsion uses a scripted research trigger, cannot be placed in the ordinary laboratory queue, and cannot be completed by laboratories on a planet or a platform near a normal destination.

Its trigger description directs the player to construct and operate the observatory aboard a platform traveling from the Solar System Edge toward the Shattered Planet.

### 2. Prepare a Self-Sufficient Platform

The observatory accepts every pack in SPACELAB's complete late-game science set: Automation, Logistic, Military, Chemical, Production, Utility, Space, Metallurgic, Electromagnetic, Agricultural, Cryogenic, and Promethium science. This preserves the mod's existing all-science identity and proves the force can supply every planetary and orbital branch.

Exact pack consumption, observatory power draw, and duration should be selected through playtesting rather than fixed by this proposal. The intended bottleneck is balanced continuous operation in deep space, not stockpiling one enormous payment and inserting it at the threshold.

### 3. Enter the Convergence Zone

The project becomes eligible only when all of these conditions hold:

- The platform belongs to the same force as the observatory.
- It is traveling on `solar-system-edge-shattered-planet` toward the Shattered Planet.
- Its route distance is greater than 100,000 km, equivalent to normalized distance `> 0.025` on the 4,000,000 km connection.
- The observatory is intact, powered, and supplied.

The threshold should be a startup setting only if playtesting demonstrates a clear need. The intended default and documented balance target is 100,000 km.

### 4. Sustain the Experiment

While eligible, the observatory consumes all science packs and accumulates Spacefold Propulsion research progress. Losing power, running out of any pack, leaving the connection, traveling back toward the Solar System Edge, or falling below 100,000 km pauses progress. It should not erase completed progress; catastrophic failure already carries the cost of repairing or replacing the ship.

This produces a readable failure loop:

- Insufficient defenses cause physical damage.
- Insufficient production causes the experiment to pause.
- Insufficient power forces a choice between propulsion, defense, and research.
- Poor circuit control causes buffers to starve or overflow.

### 5. Unlock the Spacefold Drive

When one observatory completes the project:

- Permanently mark Spacefold Propulsion researched for the force.
- Unlock the Spacefold Drive item, recipe, and platform building.
- Present a clear breakthrough message and record the completing platform and distance.
- Change the observatory to an idle or completed state as visible proof of the breakthrough.
- Leave the save playable and leave all other platforms unchanged.

The technology should not award another science-productivity bonus. SPACELAB's stated purpose is to escape the loop of producing more science only to produce more science. The Spacefold Drive is a direct capability upgrade that changes what platforms can do.

### 6. Charge and Engage the Drive

The Spacefold Drive is a large building restricted to space platforms. It contains a very large electric-energy buffer and charges only while fully powered. Charge is local to that drive and survives ordinary pauses, but is lost if the building is destroyed.

When fully charged, the drive can engage only while its platform is traveling on a valid space connection. Engagement:

1. Confirms the platform's active connection and direction of travel.
2. Consumes the entire stored charge.
3. Moves `LuaSpacePlatform.distance` to a small safety margin before the destination, such as `0.999` when traveling toward `connection.to` or `0.001` when traveling toward `connection.from`.
4. Lets the platform cover the short remainder and arrive through Factorio's normal platform state and schedule flow.

The drive affects only the platform carrying it. It does not create a replacement surface, copy entities, bypass locked destinations, or select an arbitrary location outside the current schedule. Manual activation should be the first implementation; circuit activation can follow after the failure states are understood.

Warp travel appears both in community proposals and in an existing endgame mod as a thematic payoff.[^forum-expectations][^mod-nexus] Writing the existing platform's normalized route distance makes this narrower design substantially safer than teleporting entities or reconstructing a platform.

## Technology Gating Feasibility

### What Data-Stage Prototypes Can Do

A technology prototype can define prerequisites, science ingredients, effects, and whether it is enabled.[^api-technology-prototype] It cannot express "research only while a platform is this far along a particular space connection." Recipes can use surface properties, but route progress is not a surface property and therefore cannot provide this gate by itself.

### Minimal Runtime Gate

The smallest fallback implementation is:

1. Define Spacefold Propulsion as disabled at game start with ordinary all-science research units.
2. Periodically inspect `LuaForce.platforms`.
3. Find a platform whose `space_connection.name` is `solar-system-edge-shattered-planet`, whose normalized `distance` is greater than `0.025`, and whose sampled distance is increasing.
4. Permanently enable the technology for that force.

`LuaTechnology.enabled` is writable at runtime.[^api-technology-enabled] This makes only the *unlock* location-dependent: once enabled, ordinary labs anywhere can research it. That does not satisfy the intended rule that the all-science research itself must occur beyond 100,000 km, so it is a technical prototype or compatibility fallback rather than the recommended design.

### Strict Platform-Bound Project

The recommended implementation keeps the technology out of the normal research queue and treats the observatory as a scripted final objective:

1. Poll relevant platforms with `on_nth_tick`, not every tick.
2. Determine eligibility from the platform's connection and normalized distance. Infer outward travel from an increase since the previous distance sample rather than relying on an undocumented direction flag.
3. Inspect each observatory on that platform and advance only supplied, powered entities.
4. Store progress by force and unit number or platform identity.
5. On completion, call `LuaForce::script_trigger_research()` for Spacefold Propulsion so Factorio handles its scripted research trigger and unlock effects normally.

`LuaSpacePlatform` exposes `space_connection` and normalized `distance`, and `LuaForce` exposes its platforms and technologies.[^api-platform][^api-force] The 4,000,000 km connection means a kilometer threshold can be converted to normalized distance as `threshold_km / 4000000`. Factorio supports `type = "scripted"` research triggers, and `LuaForce::script_trigger_research()` completes such a technology.[^api-research-trigger][^api-script-research]

`on_space_platform_changed_state` is useful for departures, arrivals, and interrupted travel, but it does not report every distance change. Distance eligibility therefore requires periodic polling.[^api-events]

Do not use `LuaForce::disable_research()` for this feature because it disables research for the whole force rather than only the final project. Do not repeatedly enable and disable the final technology as platforms move; that creates confusing queue behavior and multiplayer edge cases.

## Spacefold Drive Feasibility

The drive itself requires runtime scripting, but it does not require teleporting individual entities or rebuilding a platform. `LuaSpacePlatform.distance` is writable, so the script can reposition the existing platform along its current connection while its surface, entities, inventories, players, and schedule remain attached to it.[^api-platform]

The recommended implementation is:

1. Register built drives and associate each with its platform.
2. Represent charging with the drive entity's electric-energy buffer and persist whether it is ready.
3. Allow engagement only when the drive is fully charged and the platform has a current space connection.
4. Infer direction from recent distance samples, then set distance near the corresponding endpoint rather than exactly on it.
5. Consume the entire charge before changing distance and impose a short script cooldown to prevent duplicate activation.
6. Let Factorio complete the remaining route and transition naturally to the destination.

The safety margin is important. Setting an exact endpoint could race the engine's own arrival transition; stopping just short gives Factorio one normal movement interval in which to finish the trip. The implementation should initially support any active, already-unlocked connection, not arbitrary destination selection. This preserves the schedule as the source of truth and prevents the drive from bypassing progression locks.

Release-quality work is concentrated in edge cases rather than the jump itself: activation during departure or arrival, direction changes between samples, multiple drives, a drive destroyed while charging, multiplayer activation, save migration, and compatibility with mods that alter platform travel. A manual entity button or shortcut with a confirmation dialog is preferable for the first version; circuit activation should be added only after these transitions are reliable.

## State and Multiplayer Rules

- **Permanent completion:** Once completed, Spacefold Propulsion never becomes unavailable if the platform retreats or is destroyed.
- **Any-platform policy:** Any one platform owned by the force may qualify. Requiring every player or platform to be present would punish multiplayer forces and automated fleets.
- **Independent attempts:** Multiple observatories may accumulate independent progress, but only the first completion matters to the force-wide technology.
- **Pause, do not reset:** Retreat, starvation, or power loss pauses an attempt. Destruction removes only the progress attached to that observatory unless playtesting shows this is too punitive.
- **Save migration:** On configuration change, rebuild the observatory index and preserve already completed force state. Existing platforms beyond the threshold become eligible but should not receive free project progress.
- **Removed or changed routes:** If another mod removes the vanilla connection, keep the final project unavailable and emit one clear compatibility message rather than erroring.
- **Performance:** Poll at a coarse interval and stop scanning a force after completion. The route takes minutes or hours, so sub-second precision has no gameplay value.

## Scope Alternatives

| Option | Description | Advantages | Problems | Recommendation |
| --- | --- | --- | --- | --- |
| Arrival unlock | Enable normal research after any platform crosses a threshold. | Small script; normal Factorio research UI. | Research itself can happen anywhere; weak final test. | Good MVP or fallback. |
| Scripted arrival completion | Complete the technology immediately at the threshold. | Very small and unambiguous. | Rewards travel only; does not test SPACELAB production. | Reject as the primary finale. |
| Promethean Observatory | Consume all science packs aboard a qualifying platform beyond 100,000 km. | Tests the whole mod; progress makes the voyage meaningful. | Requires runtime state, UI feedback, and migration handling. | Recommended. |
| Literal Shattered Planet arrival | Require normalized distance `1` on the full route. | Maximum prestige and simple fiction. | Multi-hour default, costly iteration, contrary to official expectation. | Optional hardcore preset. |
| Landable Shattered Planet | Add terrain, resources, enemies, and another factory campaign. | Largest content expansion. | Very large art, balancing, compatibility, and implementation scope. | Separate future mod or expansion. |

## Community Ideas Worth Preserving

Community discussion is not unanimous and should not be treated as product requirements. It does reveal useful design pressures:

- **Some players want a reason to arrive.** Detailed proposals imagine a final factory, a new ending, or technology that justifies the journey.[^forum-surface][^forum-expectations]
- **The ship-building challenge is already compelling.** Players publish highly varied endurance, compact, and novelty ships, suggesting the voyage should remain central rather than be bypassed.[^forum-ships]
- **A new landable surface is one recurring proposal.** Examples use fragmented islands, constrained build space, unusual logistics, and combinations of mechanics from earlier planets.[^forum-surface][^forum-landing]
- **A final reward should change what the player can do.** Suggestions include warp travel, quality tools, unusual logistics, or a definitive new ending rather than another percentage upgrade.[^forum-expectations][^forum-surface]
- **Existing mods demonstrate the idea's scope.** Shattered Planet and Nexus each add a planet-scale production campaign; both combine earlier planetary mechanics and end in a new technology or escape objective.[^mod-shattered][^mod-nexus]

The observatory and drive capture the strongest of these ideas - a demanding voyage, a final factory test, and a transformative reward - without committing SPACELAB to terrain generation and another full planet.

## Suggested Delivery Plan

### Phase 1: Arrival-Gated Prototype

- Add Spacefold Propulsion, the drive prototype, and minimal locale using placeholder graphics.
- Poll force platforms and temporarily expose ordinary all-science research after crossing 100,000 km.
- Prototype drive charging and a manual jump to just short of the current destination.
- Validate route detection, writable distance, direction inference, arrival behavior, multiplayer forces, saves, and mod compatibility.

This phase answers the risky runtime questions with the least code. Its ordinary research gate is not the final gameplay design.

### Phase 2: Observatory Objective

- Add the Promethean Observatory entity and final-project inputs.
- Replace ordinary lab research with platform-bound progress.
- Add progress feedback, pause reasons, completion messaging, and migration logic.
- Fix the default research boundary at 100,000 km and playtest science cost, duration, and observatory power demand.
- Replace placeholder drive controls with clear charge, readiness, destination, and failure feedback.

### Phase 3: Drive Automation and Prestige

- Add circuit-controlled engagement if manual activation proves reliable.
- Add a full-distance arrival objective or startup setting.
- Consider a persistent score for fastest, lightest, or lowest-energy completion without tying progression to it.

## Open Design Decisions

- Should observatory progress survive destruction, or only pauses and retreat?
- Should multiple observatories on one platform increase speed, or should one platform support only one active project?
- What science cost and research duration make maintaining production past 100,000 km meaningful without turning it into idle waiting?
- What drive energy capacity and charging rate make a jump a major platform operation rather than a routine shortcut?
- Should one fully charged drive jump the platform, or should larger platforms require multiple synchronized drives based on platform mass?
- Should the first release allow jumps on every active connection, or only the Solar System Edge to Shattered Planet connection and its return direction?

## Sources

Official facts, API behavior, community opinion, and SPACELAB proposals are intentionally separated above. Community links are representative examples, not statistical evidence of consensus.

[^wiki-shattered]: Official Factorio Wiki, [Shattered planet](https://wiki.factorio.com/Shattered_planet), including route length, achievement distances, asteroid scaling, and the statement that reaching the destination is not expected.
[^api-platform]: Factorio 2.1 Runtime API, [`LuaSpacePlatform`](https://lua-api.factorio.com/latest/classes/LuaSpacePlatform.html), including `space_connection` and `distance`.
[^api-force]: Factorio 2.1 Runtime API, [`LuaForce`](https://lua-api.factorio.com/latest/classes/LuaForce.html), including force platforms and technologies.
[^api-events]: Factorio 2.1 Runtime API, [`on_space_platform_changed_state`](https://lua-api.factorio.com/latest/events.html#on_space_platform_changed_state).
[^api-research-trigger]: Factorio 2.1 Runtime API, [`ResearchTrigger`](https://lua-api.factorio.com/latest/concepts/ResearchTrigger.html), including the `scripted` trigger type and trigger description.
[^api-script-research]: Factorio 2.1 Runtime API, [`LuaForce::script_trigger_research()`](https://lua-api.factorio.com/latest/classes/LuaForce.html#script_trigger_research).
[^api-technology-prototype]: Factorio 2.1 Prototype API, [`TechnologyPrototype`](https://lua-api.factorio.com/latest/prototypes/TechnologyPrototype.html), including `enabled`, `prerequisites`, `unit`, `research_trigger`, and `effects`.
[^api-technology-enabled]: Factorio 2.1 Runtime API, [`LuaTechnology.enabled`](https://lua-api.factorio.com/latest/classes/LuaTechnology.html#enabled).
[^forum-ships]: Factorio Forums, [Ships that can get to the shattered planet](https://forums.factorio.com/viewtopic.php?t=122301), started November 20, 2024.
[^forum-surface]: Factorio Forums, [New Surface: Shattered Planet (Long post)](https://forums.factorio.com/viewtopic.php?t=132252), January 2, 2026.
[^forum-landing]: Factorio Forums, [If you could land on the Shattered Planet, what would it be like?](https://forums.factorio.com/viewtopic.php?t=130644), September 2025.
[^forum-expectations]: Factorio Forums, [Observations and expectations from a new player getting ready to go for shattered planet](https://forums.factorio.com/viewtopic.php?t=132547), January 26, 2026.
[^mod-shattered]: Factorio Mod Portal, [Shattered Planet](https://mods.factorio.com/mod/skewer_shattered_planet).
[^mod-nexus]: Factorio Mod Portal, [Nexus Extended Promethium Endgame](https://mods.factorio.com/mod/Nexus).
