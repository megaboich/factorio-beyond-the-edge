# Beyond the Edge: Mechanoids — Guardians of the Ruins — development plan

**Status:** documentation-only placeholder. **Restructured:** 2026-11-12.

[VISION.md](VISION.md) describes the experience. This plan inherits the enemy research from the former combined Stargate design; campaign placement and rewards now belong to [Homecoming Journey](../homecoming-journey/PLAN.md). Gate construction and transport belong to [Stargate](../stargate/PLAN.md).

## 1. Scope and independent play

- Planned identity: `bte-mechanoids`, title `Beyond the Edge: Mechanoids — Guardians of the Ruins`.
- Required dependencies: `base >= 2.1.0`, `space-age >= 2.1.0`. No family dependency, gate requirement, or campaign victory condition.
- Own enemy prototypes, attacks, animation/sound, guardian force, encounter manifests, bounded guarding, damage persistence, removal tracking, and standalone placement.
- Standalone direction is **provisionally Fulgora-only**, because it already has ruins. Frequency, defended objects, salvage, and exact relationship to vanilla ruins are unresolved. Do not treat them as settled mechanics.
- Homecoming can request authored encounters on other planets through a supported API. Those requests are not automatic global enemy spawning merely because Stargate is installed.
- No loadable mod metadata yet. Build/test enrollment follows the first actual implementation.

## 2. Standalone placement proposal

First establish combat in a test arena; then prototype guarded areas associated with suitable Fulgoran ruins. Do not infer one encounter per vanilla ruin entity: inspect actual generation density and terrain first.

Candidate policy: deterministic finite defended sites on newly explored Fulgoran terrain, bounded placement jobs, no expansion or respawn. For existing saves, add only where safe; never erase established factories or suddenly populate their interiors. Decide whether safe uncharted-but-generated areas are eligible, rather than equating generation with player exploration.

Site selection must check a whole usable island footprint, approaches, and nearby player infrastructure. Reject tiny or inaccessible islands; do not terraform a factory or oil ocean to force placement. Lightning behavior needs real prototype/runtime checks.

Each site needs a reason to clear it without gates or artifacts. Evaluate safe ruin access and modest finite salvage; exact rewards remain open. No unique quest reward on a random corpse. Standalone pacing must be tuned for Fulgora access equipment, not copied from the old late-game campaign encounter stats.

Homecoming-owned sites are separately keyed. Registering them must not also invoke a second standalone encounter generator at the same location. Decide suppression/spacing rules when a campaign site intersects the standalone placement domain; preserve existing cleared sites and do not silently delete encounters when changing modes.

## 3. Roster and native prototype contract

Ordinary ground `unit` prototypes provide pathfinding and weapon actions. Mechanical art does not require `car`, `spider-vehicle`, or owner/lifetime-based `combat-robot` entities.

The following **inherited candidate arena stats** are not standalone release balance. Movement is tiles/tick at 60 ticks/second; damage is per attack before modifiers.

| Role / proposed prototype | Role | Candidate baseline |
| --- | --- | --- |
| Skirmisher — `bte-mechanoids-skirmisher` | Low quadruped, closes distance | 1,400 HP; speed 0.14; melee range 1.5; 40 physical / 30 ticks |
| Sentinel — `bte-mechanoids-sentinel` | Ranged approach defender | 2,200 HP; speed 0.10; range 18; 45 physical / 30 ticks |
| Bulwark — `bte-mechanoids-bulwark` | Slow heavy, readable projectile and recovery | 12,000 HP; speed 0.06; range 26; 200 explosion / 120 ticks, small splash |

Start with Skirmisher and Sentinel; add Bulwark after they are fun. Names formerly proposed as `bte-stargate-mechanoid-*` were never implemented/published; this split assigns them to Mechanoids. Use modest light physical resistance and stronger heavy armor, not blanket elemental/artillery immunity. Leave alternate weapon strategies useful.

Explicit prototype requirements:

- `attack_parameters` includes attack animation and `ammo_type`; engine handles attacks, damage, cooldowns, projectiles, and resistances.
- Set movement, sight/range, collision, pursuit, corpse/loot, and sounds. Remove inappropriate inherited acid, blood, healing, and pollution participation.
- Start with normal quality. Use intrinsic weapon ammo actions, not hidden inventories or refill scripts.
- No spawners; `absorptions_to_join_attack = {}` and no autonomous attack-group participation.
- Verify normal weapons, personal lasers, combat robots, turrets, mines, artillery, and vehicles acquire and damage the machines.

Reviewed **2.1.24** settings:

```lua
ai_settings = {
  destroy_when_commands_fail = false,
  allow_try_return_to_spawner = false,
  join_attacks = false,
  do_separation = true
}
```

The API field is `destroy_when_commands_fail`; inspected Robot Army source contains `allow_destroy_when_commands_fail`. Normalize borrowed fields and assert resolved prototypes. Pathfinding failure must not delete a guardian and award clearance. Current individual commands use valid `entity.commandable.set_command(...)`, not old `unit.set_command(...)` assumptions.

Optional later pylons can have visible power infrastructure. Destroying a supply may disable the pylon, not erase mobile guards or claim a site automatically. Do not add them before the mobile encounter works.

## 4. Guarding, forces, and finite progress

```text
guard / patrol -> engage intruder -> return to assigned area -> guard / patrol
       any live state -> removed
```

Authored posts and short patrols stay within a defended area. Alert a bounded local group. Lost targets, surface changes, or excessive pursuit trigger return while retaining health and identity. Candidate supervisory geometry: **48-tile threat search**, **96-tile site-relative leash**, active encounter check every **30 ticks**. These are tuning proposals, not a hard physical boundary. Arrival exclusions supplied by a caller override generic defaults.

Issue commands only on state/target change, completion, or scheduled retry; the engine handles movement and combat between checks. Begin with individual commands. Native groups require their own lifecycle tests; do not import a squad framework for six guards.

Blocked paths retry nearby reachable waypoints with backoff and diagnostics. Do not kill, heal, respawn, or silently teleport guards to solve path failure. Walls, inaccessible firing positions, and distant artillery are legitimate tactics; no worldwide pursuit of the firing factory.

Use a dedicated proposed force `bte-mechanoids-guardians`, not shared vanilla `enemy`. Set friendship and cease-fire in **both** directions:

| Other force | Policy |
| --- | --- |
| Participating player forces | Hostile; handle new forces and merges |
| Vanilla enemy | Hostile, allowing native creatures and machines to fight |
| Self | Friendly, consistent ordinary friendly fire |
| Neutral ruins / campaign anchors | Non-hostile; campaign protects its own anchors |

Do not modify global biter evolution or native research. Native kills count as real encounter losses. Later native arrivals do not revoke clearance. In campaign encounters, a demolisher can defeat the guards while the campaign's indestructible anchor survives.

Store deterministic per-site slots: role, home position, entity/registration reference, lifecycle status. Commit each spawn individually; blocked slots remain pending for bounded retries, not duplicated whole-roster generation. Exhausted retries need an explicit failed-placement outcome, not endless pending jobs or false clearance.

Clearance requires placement complete and zero surviving required slots. `on_entity_died` and registered `on_object_destroyed` feed the same idempotent slot transition; the latter can arrive at the end of the current/next tick. Never count twice. Configuration repair reconciles references, never respawns removed slots.

Inherited campaign composition examples: 4 Skirmishers + 2 Sentinels for an introductory anchor; 2 + 3 for a small relay; 6 + 4 + 1 Bulwark for a later archive. Homecoming chooses campaign manifests; standalone Fulgora balance needs separate tests. Difficulty freezes when a site is established; death, reload, evolution, and co-op disconnects must not silently upgrade existing guards.

Peaceful/enemies-disabled policy is unresolved for standalone play. The preferred starting direction is no surprise compulsory combat. Homecoming can use disabled security plus restoration, but owns that substitute objective. Setting changes must not refill defeated rosters. Test Fulgora lightning and requested Aquilo encounters without inventing hidden power/heat requirements for mobile units.

## 5. Architecture and integration

Keep `control.lua` a small direct composition root. Proposed feature files: `prototypes/mechanoids.lua`, attacks/corpses as needed, `scripts/encounters.lua` (manifest/clearance), `guardians.lua` (commands/force), and `sites.lua` (standalone placement). Mutable schemas, jobs, rosters, and removals live in Mechanoids' own `storage`.

Planned versioned API: register/query an encounter by caller + stable site ID, provide position/surface/formation and exclusion geometry, and observe clearance/removal. Idempotent retries and query reconciliation handle reload and cross-mod event order. Return bounded status data, never expose mutable private tables or rely on another mod's `storage`. Cancellation/surface deletion must account for owned entities, not destroy unrelated ruins or gates.

Mechanoids owns encounter truth; Homecoming owns whether its clearance unlocks inspection/research/artifacts. Neither Stargate pairing nor campaign artifact logic belongs here. Installing the three in any supported combination must not spawn two rosters at one site.

Use `bte-mechanoids-*` names, `bte_mechanoids_*` GUI names if needed, and `__bte-mechanoids__/` assets. Generate mechanical art/sound through repository tools. Confirm directional idle/run/attack/death export support; existing building renders do not prove unit-sheet support.

## 6. Milestones and acceptance

| Milestone | Exit criterion |
| --- | --- |
| M0 — Two-role arena | Native units, targeting, preserved damage, readable combat, correct force relations |
| M1 — Finite guardians | Manifest creation/removal, path retries, leash/return, reload and duplicate-event safety |
| M2 — Standalone Fulgora slice | Safe deterministic placement, meaningful clear/reward loop, existing-save policy, peaceful policy, no sibling mods |
| M3 — Campaign contract | Explicit non-Fulgora requests, arrival exclusions, query/events, no duplicate standalone placement |
| M4 — Heavy and release | Bulwark after testing, varied formations, generated assets, documentation, package/runtime audit |

Prototype tests assert locale, unit settings, attacks/ranges/cooldowns, corpses/collisions, sprites, and removal of inherited biological actions. Runtime checks cover targeting, guarding/return, damage retention, path failure, pending slots, duplicate removal events, native kills, force merges, surface deletion, peaceful configuration, reload, and campaign retries. A visible playtest checks silhouettes, attack readability, friendly fire, lightning, real pursuit, and Fulgora pacing.

Profile bounded recorded encounters and local searches; no per-tick whole-surface enemy scan. Validate at standalone expected density and the campaign's fifteen sites, not just one arena.

When loadable, add per-mod `tests/prototypes.py` and isolated runtime fixtures, then enroll in shared tooling. Test alone, with Stargate without the campaign, and with Homecoming's complete dependency set. Future implemented values belong in `mechanoids/README.md` and tests, not duplicated planning documents. Exclude plans and helper mods from packages; leave outputs unstaged.

## 7. Inspected implementation references

Source reviewed **2026-11-11**, not run as compatibility tests. Prior API review used **2.1.24**; verify engine/minimum version at implementation. No Mechanoids gameplay tests have been run.

| Reference | Entry points / reuse |
| --- | --- |
| Robot Army **2.4.28**, Factorio **2.1** | Primary **MIT** code reference: native mechanical units, intrinsic attacks, command and registration patterns |
| Castra Prime **0.9.4**, Factorio **2.1** | **GPLv3 design reference**: hostile mechanical outposts; do not relabel copied GPL code as MIT |
| AbandonedRuins, Factorio **1.1** source | **MIT** authored layouts and deferred placement patterns; old runtime code needs a 2.1 port |

- **Robot Army**, commit `414343e60114af7134eecada1e1c7976fac36001` (2026-11-01): [unit prototypes](https://github.com/kyranf/robotarmyfactorio/blob/414343e60114af7134eecada1e1c7976fac36001/prototypes/entity.lua), [squad orders](https://github.com/kyranf/robotarmyfactorio/blob/414343e60114af7134eecada1e1c7976fac36001/robolib/Squad.lua), [guard AI](https://github.com/kyranf/robotarmyfactorio/blob/414343e60114af7134eecada1e1c7976fac36001/robolib/SquadControl.lua), [registration](https://github.com/kyranf/robotarmyfactorio/blob/414343e60114af7134eecada1e1c7976fac36001/robolib/eventhandlers.lua), [MIT notice](https://github.com/kyranf/robotarmyfactorio/blob/414343e60114af7134eecada1e1c7976fac36001/LICENSE).
- Robot Army's `droid_smg`, `droid_flame`, `droid_rifle` illustrate units; `orderSquadToWander(..., guard)`, `orderSquadToAttack`, `executeGuardAI`, `processSpawnedDroid`, and `processDroidGuardStations` show commands/registration. Guard AI is **not evidence of a hard-radius leash**. Do not borrow replenishing factories, friendly-player flags, radar reveal, pickup recipes, or a full squad/class/utility framework.
- **Castra Prime**, commit `a122cab906bc233598b76f2a458c5b4cc4688099` (2026-10-12): [entity](https://github.com/pauldennis2/castra-prime/blob/a122cab906bc233598b76f2a458c5b4cc4688099/prototypes/entity.lua) (`castra-enemy-tank` from `medium-spitter`), [base generator](https://github.com/pauldennis2/castra-prime/blob/a122cab906bc233598b76f2a458c5b4cc4688099/base-generator.lua) (walls, supplied turrets/power), [runtime](https://github.com/pauldennis2/castra-prime/blob/a122cab906bc233598b76f2a458c5b4cc4688099/control.lua) (`give_tank_random_command`), [GPLv3](https://github.com/pauldennis2/castra-prime/blob/a122cab906bc233598b76f2a458c5b4cc4688099/LICENSE). Its expansion/raids differ from finite guardians.
- **AbandonedRuins**, commit `b344cd3d598cedc7a77a484ab3f9efe4c63e229d` (2022-01-27): [armed fort](https://github.com/Bilka2/AbandonedRuins/blob/b344cd3d598cedc7a77a484ab3f9efe4c63e229d/ruins/largeRuins/destroyedEnemyFort.lua), [placement](https://github.com/Bilka2/AbandonedRuins/blob/b344cd3d598cedc7a77a484ab3f9efe4c63e229d/control.lua) (`queue_ruin`, old `global`), [MIT](https://github.com/Bilka2/AbandonedRuins/blob/b344cd3d598cedc7a77a484ab3f9efe4c63e229d/LICENSE).
- Official [UnitPrototype](https://lua-api.factorio.com/2.1.24/prototypes/UnitPrototype.html), [UnitAISettings](https://lua-api.factorio.com/2.1.24/types/UnitAISettings.html), [LuaCommandable](https://lua-api.factorio.com/2.1.24/classes/LuaCommandable.html), [destruction event](https://lua-api.factorio.com/2.1.24/events.html#on_object_destroyed).

Retain required MIT notices with adapted code, record exact provenance, and generate shipped art rather than assuming upstream graphics have interchangeable licenses.

**Next implementation action:** M0, the independent two-role combat arena. Standalone placement design can proceed without blocking Stargate's S0 prototype.
