# Beyond the Edge: Homecoming Journey — development plan

**Status:** documentation-only placeholder. **Restructured:** 2026-11-12.

[VISION.md](VISION.md) preserves the former Stargate campaign vision. This plan owns story/content/orchestration, not duplicate implementations of [Mechanoids combat](../mechanoids/PLAN.md) or [Stargate transport](../stargate/PLAN.md). Candidate budgets, timings, APIs, and encounter behavior still require prototypes and playtests.

## 1. Identity, hard dependencies, and ownership

Planned identity: `bte-homecoming-journey`, title `Beyond the Edge: Homecoming Journey`.

Required installation:

| Dependency | Role |
| --- | --- |
| `base >= 2.1.0`, `space-age >= 2.1.0` | Game and expansion |
| `bte-spacelab` | Orbital production and research infrastructure |
| `bte-warp-drive` | Opening detection, tachyon-assisted research, deep-space travel |
| `bte-mechanoids` | Guardian prototypes and finite encounter lifecycle |
| `bte-stargate` | Construction, powered player travel, connections, and train passage |

All four family dependencies are **hard**, not optional. Read their actual versions from their metadata when implementing; declare supported minimum versions after integration contracts exist. No standalone campaign fallback. These directories remain placeholders without `info.json`; do not advertise them as installable.

Homecoming owns discovery signals, fifteen ancient site identities/layouts, ancient-network topology, inspection/deciphering, restoration requirements, artifacts, journal/clues/puzzle, campaign research/balance, Massive Space Gate, route qualification, and ending.

Mechanoids owns enemy behavior/rosters. Stargate owns gate companions, construction accounting, operational power, transfer safety, pairing/connection enforcement, and train sessions. Homecoming requests and queries these capabilities; it does not reach into private `storage`, share Lua files across packages, or copy their implementations.

## 2. Campaign versus standalone progression

The campaign's ancient ruins are not Stargate's easy standalone experimental kit route. The family mods retain useful independent play; installing Homecoming deliberately adds a harder authored journey.

| Without Homecoming | With Homecoming |
| --- | --- |
| Mechanoids provisionally guards Fulgoran ruins | Campaign requests additional finite guards at authored sites on all five planets |
| Stargate: experimental research → kit/material assembly → random first jump → controlled pairs → trains | Ancient discovery → guarded ruins → decipher/restoration → authored connections → artifacts/research → orbital homecoming |
| Player-built gate pairs, no story route constraints | Campaign-managed ancient links enforce allowed connections and journal milestones |
| Standalone construction/research/power tuned for accessibility | Ancient gate budgets and enormous capstone tuned for full-family endgame |

**Unresolved integration decision:** how experimental kits and freely paired player-built gates coexist with the ancient campaign. A direct player-built Nauvis–Aquilo pair could undermine the intended multi-hop gate journey. Before campaign implementation, choose an explicit policy: campaign-specific research/access gating, restrictions on campaign-mode links, or accepting such infrastructure outside the authored route. Do not claim a globally enforced no-shortcut campaign while leaving this unresolved. Any campaign-wide change must be visible, documented, scoped to this mod's presence, and preserve existing saves rather than silently deleting gates or revoking completed research.

Installing only Mechanoids + Stargate does not trigger a campaign, increase all gate costs, populate five planets with campaign encounters, or add victory prerequisites.

## 3. Discovery and fifteen-site network

Warp Drive's **first successful activation reveals unusual tachyon activity on Nauvis**, in a distant unexplored region. Inspecting the secured ruin enables paid **Ruin Deciphering** research. Restoration then accepts high-tech components and powered commissioning.

Initial normal progression: Nauvis → Gleba. First arrival is near an unrestored gate and must have a recoverable prepaid return. Returning normally through the **restored Gleba gate** reveals Vulcanus coordinates exactly once per force; an emergency return from its unrestored receiver does not advance this milestone.

Later discoveries expose Vulcanus, Fulgora, and Aquilo with planet-specific variations. Three sites per existing planet, **fifteen total**:

| Role | Purpose / reward |
| --- | --- |
| Anchor | Arrival, foothold, local network knowledge |
| Archive | Stronger restoration/clearance challenge, one planetary artifact, cipher clue |
| Relay | Optional infrastructure, route flexibility, redundant lore/hints |

Stable IDs such as `nauvis:anchor` are record keys, not prototype names. Roles/location seeds persist through reload, destruction, and replacement. Artifacts and address reveals are distinct progress events. Finding a site physically may record it early; visit, discovery, and authorized connection are separate facts.

An authored graph governs allowed ancient links, not an all-discovered-destinations picker. Validate full reachability, all five artifacts accessible, Nauvis–Gleba return, and **no direct Nauvis–Aquilo edge**, with at least two gate hops between them. The exact fifteen-site graph remains to design. Do not imply Stargate's initial one-partner mode already supports this graph: define multi-link support or a workable graph/selection contract during integration. Trains follow the same campaign connection policy.

Only archives and necessary approaches are mandatory initially; restoring every relay should not become fifteen identical chores. Normal Space Age transport remains useful for supplies and expeditions, subject to the still-open gate coexistence policy above.

### Warp integration and existing saves

Warp Drive currently has a test-only interface, not a production discovery API. Add a supported versioned activation event/query in its own mod before relying on it; hard dependency does not grant access to private state. Reconcile already-activated drives/eligible existing forces on configuration changes, deduplicate detection, and do not require a previously completed first activation to occur again. Exact late-game eligibility and current vanilla research IDs require resolved-prototype checks.

Its existing general-science bonus can accelerate eligible paid research under the detector's normal rules. Never apply the bonus a second time, bypass pack consumption, or change Warp Drive's research-routing implementation from campaign code.

## 4. Site generation, environments, and encounters

Deterministic bounded placement jobs:

1. Derive candidate sequence from map seed, planet, role; persist job progress.
2. Search distant uncharted locations outside established infrastructure, accounting for multiple settlements rather than only `(0, 0)`.
3. Generate footprint and approaches, validate terrain, safe arrival, restoration space, and practical access.
4. Reject player construction or incompatible terrain; never erase a factory to force a site.
5. Commit location/identity once, request gate site from Stargate and encounter from Mechanoids idempotently.
6. Chart the intended area and create force marker; do not generate all fifteen encounters on installation.

Candidate distance starts a few thousand tiles from settlement, adjusted by map settings/exploration; bounded batches and no-valid-location diagnostics prevent infinite searches. Preserve committed IDs across cross-mod retries.

| Planet | Encounter / restoration identity | Artifact theme |
| --- | --- | --- |
| Nauvis | Biters nearby and Mechanoid perimeter; learn inspection/materials/startup | Address / coordinates |
| Gleba | Pentapod pressure, several approaches, sustained remote supplies | Synchronization / living signal |
| Vulcanus | Lava-separated terrain, strong Mechanoids, nearby demolisher territory | Structure / containment |
| Fulgora | Large enough ruin islands, lightning, constrained electrical layout | Phase / resonance |
| Aquilo | Ice, heating, sparse support, dependable return | Thermal balance / control |

Do not invent native enemy factions on Fulgora or Aquilo or assume controlled demolisher spawning. Ancient anchors must survive demolishers. Coordinate lightning/heat policy for actual gate companions with Stargate; mobile enemy environmental checks belong to Mechanoids.

Pass compositions/exclusion geometry to Mechanoids; query completed placement plus no surviving guards before clearance. Native kills count. No automatic respawn on reload, re-entry, gate damage, or repair. Arrival pads lie outside initial firing envelopes, with room to retreat. Ordinary factory combat solutions remain valid. Campaign artifacts are archive rewards, never random corpse loot.

Peaceful/enemies-disabled direction: disabled security with a restoration objective rather than a compulsory ambush. Final policy must agree with Mechanoids' standalone setting behavior. Do not conflate this campaign's fifteen sites with standalone Fulgoran encounter density.

## 5. Restoration, damage, and campaign power

Campaign progress and gate operation are separate:

```text
hidden -> discovered -> secured -> deciphered -> restored
```

Homecoming records the story states; Stargate records actual construction and operational readiness. Losing power does not erase knowledge. Ancient anchors are indestructible/unmineable; restored machinery can collapse back to a ruin, retaining site identity, clearance, deciphering, and artifact credit. Prevent mining with the current API (`minable_flag`, not read-only `minable`); verify against the supported engine. Decide whether Homecoming owns the anchor entity while Stargate owns machinery, with explicit removal/rebuild contracts.

Use Stargate's material-fed assembly, not duplicate inventory logic. Secure → inspect/decipher → structural delivery → phase hardware → powered calibration. Inherited **candidate campaign bill per ordinary ancient gate**:

| Stage | Candidate budget |
| --- | --- |
| Frame | 400 steel plates, 200 tungsten plates, 80 low-density structures |
| Phase hardware | 200 superconductors, 40 supercapacitors, 40 quantum processors |
| Control/repair | 100 processing units, 200 electronic circuits, 100 repair packs |

Not standalone kit costs and not final balance. Prototype with cheap fixtures. Preserve partial materials, consume each stage once, define damage recovery/refunds without duplication, and never replenish defenders or re-award an artifact because a terminal was rebuilt.

Power targets retained from the original vision:

| Operation | Target / inherited candidate |
| --- | --- |
| Ancient planetary activation | **1 GW** charging target; candidate **30 GJ** activation charge |
| Operating reserve | Candidate **1 GJ** |
| Active ancient gate | **500 MW** per gate; manual offline state avoids active upkeep |
| Expedition | Candidate **1 GJ outbound + 1 GJ prepaid return per traveler**, beyond startup |
| Orbital activation | **10 GW**, candidate **120 seconds** in valid route band |

At full charge, 31 GJ takes 31 seconds at 1 GW; 1 GJ covers 2 seconds at 500 MW. Pair upkeep is 1 GW; fifteen always-active gates draw 7.5 GW. Orbital pulse is 1.2 TJ plus platform demand. Interpret startup as charging rate initially, not a verified hard supply threshold. Durations/reserves remain provisional.

Stargate implements actual per-gate joule accounting and safe return reservations. Homecoming supplies ancient gate profiles; the orbital device's distinct power reservoir belongs here. Test same-grid multiple gates rather than copying Warp Drive's one-drive-per-platform network statistics. Shutdown/damage must not revoke prepaid accepted returns; blocked pads wait with clear status instead of forcing placement.

## 6. Artifacts, research, and industrial scale

Five distinct artifact identities, one per planetary archive. **First unique recovery enables Massive Stargate research; all five are required for construction.** Repeated recovery, stale items, or duplicate copies of one identity cannot count as different components.

Persist force-level discoveries, archive decoding, identity recovery, issuance revision, carried/deposited state, and incorporation. Physical items carry stable identity and revision; reissue at a decoded archive invalidates older copies. Construction deposits enter recorded escrow once. Lost corpses, discarded items, and gate/platform damage must have defined recovery without resetting paid research. Prototype ledger before physical sockets, but full campaign requires physical delivery of all five.

Proposed campaign technology namespace: `bte-homecoming-journey-*`, not the former combined plan's `bte-stargate-space-gate`/matrix/deciphering identifiers. Those were never implemented or published.

| Research | Availability | Inherited candidate budget |
| --- | --- | --- |
| Ruin Deciphering | First secured ruin inspected | 10,000 units |
| Ancient Network Stabilization, if needed | First restored ancient link | 25,000 units |
| Massive Stargate | First unique artifact recovered | 100,000 units |
| Tachyon Matrix Stabilization | Massive Stargate research complete | 1,000,000 units |

Stargate owns controlled-pair and rail technologies; decide how campaign access maps to them without repeating standalone's random experiment at every ancient gate. Merely requesting a gate must not silently mark paid research complete. Exact pack lists/times and prerequisites remain open.

One million units take about 16.7 hours at 1,000 effective units/minute, or 100 minutes at 10,000. Twelve packs per unit would mean twelve million pack inputs before productivity. This is a pacing decision, not a decorative large number.

Tune against the complete factory loop: planetary production and Stargate trains, launch/platform logistics, Space Lab orbital industry, and Warp Drive's legitimate research assistance. Measure sustained science delivery, laboratory use, loading buffers, congestion, power, and capstone completion time under comparable capacity/modifiers. Players may choose gate trains plus conventional transport; completion checks research and construction, not a mandatory transport choice. Cheap developer fixtures must not dictate release ambition.

### Journal and seeded puzzle

Reading a databank records permanent force-level clues even if its item is lost. Anchors explain operating principles and local addresses; archives give artifact/clue; relays give optional redundant hints.

Candidate finale puzzle: five-symbol ordering. Seed a permutation, generate order/adjacency constraints, enumerate all 120 orders to prove the mandatory clue set has exactly one solution, and persist puzzle format/version. GUI includes clues and order/socket controls. Wrong answers preserve components and give feedback; localization, reload, and updates must not reroll the answer. Puzzle is a proposal, not a mandatory prerequisite for the first playable slice.

## 7. Orbital gate and homecoming

The Massive Space Gate is this campaign's platform-only device, not standalone Stargate's planetary gate or a claim that trains work on platforms.

1. Recover first artifact, research design, manufacture substantial frame/emitter/control components.
2. Recover remaining artifacts, ship materials and all five validated identities to a platform.
3. Complete assembly; a staged frame is unfinished until all components are incorporated exactly once.
4. Reveal **10 GW** and **far end of the Shattered Planet route** requirements; finish decoding/calibration and matrix research.
5. Reach the region, sustain activation, open the route to the engineer's original home, and conclude the campaign.

Validate the actual platform at runtime, not pressure alone. Candidate footprint **24 × 24 tiles**, subject to art and playtesting. Set component weight/stack/rocket compatibility so the device is actually shippable/buildable while preserving hub, propulsion, defenses, and cargo access.

### Route qualification

`shattered-planet` has `fly_condition = true`; do not require parking there. Inherited candidate region: final **1% of the actual Solar System Edge–Shattered Planet connection** nearest Shattered Planet (40,000 km on vanilla 4,000,000 km route).

Use connection endpoints and normalized `LuaSpacePlatform.distance`; do not confuse starmap radius with travel distance or assume distance always increases in travel direction. Verify endpoint order, fly-through, both travel directions (location-based initial proposal), and route completion in the engine.

Show distance/remaining window, required speed/time, delivered power/reserve, and pulse progress. The valid region must hold through the pulse. High-speed Warp Drive travel must not skip the region between samples. If a 120-second pulse cannot fit, adjust communicated speed/band/duration rather than require an impossible parked state. Brownout direction: short reserve-backed grace then reset pulse only; preserve artifacts/research/puzzle.

### Ending and persistence

Record force completion and tick exactly once; present a safe return to the original home, not just an energy achievement. Decide the actual passenger/homecoming interaction in a visible prototype: ordinary planetary walk-through assumptions do not establish platform travel behavior.

Keep the factory/network available for post-victory continuation. Test `game.set_game_state` (`game_finished`, `player_won`, `can_continue`) in a save that already won vanilla and continued. Preserve unrelated scenario state; campaign ledger/presentation can remain authoritative if replaying the standard victory screen is inappropriate.

## 8. Architecture and integration contracts

Proposed modules: `scripts/campaign.lua` (story/research), `sites.lua` (jobs/anchors/layouts), `artifacts.lua` (ledger/reissue), `journal.lua` (clues/puzzle), `integrations.lua` (explicit sibling contracts), `finale.lua` (orbital assembly/power/route/completion), `gui.lua` (campaign-facing controls). Keep direct event registration in `control.lua`; no generic dispatcher framework.

Persist schema, force campaigns, stable sites, placement jobs, artifact escrow, puzzle version, orbital records/pulse, and integration IDs in **this mod's** `storage`. Only reference/query sibling-owned gate and encounter IDs; no duplicate rosters, train sessions, or planetary power ledgers. Reconcile idempotently on configuration changes and after late/deduplicated events, not through broad per-tick scans. Force merges and surface deletion need explicit policies. Cooperative one-force first; competing-force ownership/artifact access remains open.

Required future contracts:

- Warp Drive: first-activation event and existing-activation query; no new research-bonus implementation.
- Stargate: register/query campaign sites/receivers, material/power profiles, allowed-link policy, successful transfer/construction events, prepaid return, campaign-managed re-pairing locks.
- Mechanoids: idempotent encounter registration/query, finite-clear event, safe arrival exclusions, no duplicated standalone site at the same location.
- Space Lab: initially use its actual recipes/labs through normal gameplay; introduce no remote interface without a concrete integration need. Hard dependency does not mean every sibling needs a runtime API.

These are proposed contracts, not tools currently exposed by the mods. Handle missing/unsupported interfaces as explicit compatibility errors and declare minimum supported versions when real APIs exist. Never work around an absent API by reading another mod's state.

Campaign GUI shows inspection/restoration blockers, clearance, research, journal, artifacts, discovered network, and final construction/route/power progress. Stargate still owns transport UI and safety checks. Use `bte-homecoming-journey-*` names, `bte_homecoming_journey_*` GUI names, `__bte-homecoming-journey__/` assets; no cross-package graphics references. Generate art/audio through repository tools.

## 9. Milestones and validation

| Milestone | Exit criterion |
| --- | --- |
| H0 — Boundaries and APIs | Gate coexistence/network policy settled; versioned sibling contracts and dependency metadata planned |
| H1 — One expedition | Warp activation → Nauvis finite encounter → inspect/research/restore → Gleba safe landing/return → restored return reveals Vulcanus |
| H2 — Five planets | Fifteen persistent sites, valid graph, all five archives, first-artifact research, recoverable ledger, optional puzzle |
| H3 — Orbital capstone | Shippable assembly, five identities, real fly-through probe, 10 GW activation, homecoming and continuation |
| H4 — Industrial release pass | Complete family, train-enabled and conventional supply comparisons, final costs, persistence, generated assets/documentation |

H1 depends on tested Mechanoids encounter support and Stargate transfer/construction APIs, not yet on train implementation. Full release H4 includes Stargate's later train logistics. Neither independent mod must wait for the full campaign to be playable or releasable.

Prototype tests cover campaign entities/items, artifacts, recipes, technology availability/costs, surface constraints, locale, anchors, orbital geometry/power, and dependency-sensitive changes. Runtime fixtures use temporary saves/mod directories; recreating saves after helper edits is mandatory.

Required runtime/interactive matrix:

- First activation and qualifying existing save; repeated initialization, events, and integration retries.
- Site generation in generated/ungenerated and charted/uncharted areas; same seed, bounded failure, no factory overwrite.
- Enemy placement/clear query, native kills, no refill, safe arrival and emergency return; peaceful variant.
- Restoration consumption/refunds, damage back to ruin, artifact duplication/loss/reissue, first-artifact research versus five-artifact construction.
- Ancient graph reachability, restored-Gleba-return milestone, forbidden direct edge, and chosen player-built-gate coexistence policy.
- Shared-grid power, accepted return reservations, co-op arrivals, force merges, surface deletion, save/configuration changes.
- Fly-through endpoint orientation, fast approaches, valid-region duration, interrupted pulse, platform loss, existing vanilla win, and continuation.
- Sustained science/material throughput, train congestion/power and spoilage, research pacing with legitimate Warp bonuses and Space Lab production.

Test Space Age baseline, each independent mod alone, Mechanoids + Stargate without campaign, relevant optional combinations, and the complete dependency-valid Homecoming stack. Negative dependency checks should reject Homecoming with any required sibling missing; do not attempt to load it alone as though it were standalone. Update shared test tooling to understand dependency closures before enrolling Homecoming.

No gameplay implementation or Factorio validation has happened here. Prior technical research used official **2.1.24** docs; check installed engine/API floor during implementation. Keep visible checks for combat, controller/GUI, camera, lightning/heating, practical walking routes, and final homecoming. Headless results cannot substitute for them.

Implemented mechanics eventually live in `homecoming-journey/README.md` with matching tests/icons. Keep overview links in the root README, exclude plans/test helpers from packages, and add metadata/build enrollment only when loadable. Run `git diff --check`; leave changes unstaged.

## 10. Evidence and remaining decisions

- [Stargate plan](../stargate/PLAN.md): preserved player/energy/train safety, Rift Rail source map, pinned MIT reference and preservation matrix.
- [Mechanoids plan](../mechanoids/PLAN.md): preserved candidate combat stats, finite-roster bookkeeping, AI details, pinned Robot Army/Castra/AbandonedRuins references and licensing.
- [Warp Drive composition](../warp-drive/control.lua), [research/route calculation](../warp-drive/scripts/research.lua), [power](../warp-drive/scripts/warp.lua).
- [Platform distance](https://lua-api.factorio.com/2.1.24/classes/LuaSpacePlatform.html#distance), [game state](https://lua-api.factorio.com/2.1.24/classes/LuaGameScript.html#set_game_state), [vanilla planet/location source](https://github.com/wube/factorio-data/blob/master/space-age/prototypes/planet/planet.lua) (moving upstream source; recheck resolved prototypes).
- [Development rules](../AGENTS.md), [packaging](../make.sh), [prototype runner](../tests/run-prototype-tests.sh).

Highest-value open decisions: standalone-gate coexistence and campaign shortcuts; exact ancient graph/multi-link semantics; existing-save first-activation detection; ancient versus player-built costs; peaceful/security policy; artifact recovery under platform loss; capstone budget and puzzle; final-route activation window; actual homecoming interaction; competitive-force site ownership.

**Next campaign action:** settle the gate progression/coexistence contract while Stargate develops S0 and Mechanoids develops M0 independently.
