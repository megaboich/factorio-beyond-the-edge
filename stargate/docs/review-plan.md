# Stargate Implementation Review & Action Plan

Comprehensive code, design, documentation, and UPS review of `stargate/` (`bte-stargate` 0.1.0), organized into phased work items.

---

## Overall Assessment

The core architecture is sound and addresses genuine Factorio engine constraints cleanly:

- **Train station mode (`scripts/railway.lua`, `prototypes/rails.lua`):** Using an invisible `train-stop` behind the ring (`STATION_Y = -4`), a circuit-controlled vanilla `entry_signal` at the south edge (`EDGE = 7`), and an invisible `exit_signal` on the partner's arrival lane avoids RiftRail's 1-HP collider and wait-condition workarounds. Trains wait naturally at signals without cross-surface "No path" alerts, keep block reservations, cross the edge at speed, and steer themselves through switches once a forward-facing locomotive arrives without needing a fake helper locomotive.
- **Layered companions (`scripts/gate.lua`, `prototypes/entities.lua`):** Splitting the floor (`floor`), ring/towers (`object` at `RING_Z = 2`), upper arc (`elevated-object` over spidertrons), and ramped tracks (`floor-mechanics`) handles isometric depth sorting cleanly.
- **Shared power bank (`scripts/power_bank.lua`):** Adaptive probing protects shared factory grids, and direct mode offloads steady-state draw to the C++ engine once full.

The review organized findings into four phases:
- **Phase 1 — Critical Bugs, Leaks & Freezes:** Committed & pushed (`cebb51a`).
- **Phase 2 — Documentation Contradictions, Collision/GUI Polish & Dead Code:** Committed & pushed (`95e3c70`).
- **Phase 3 — Gameplay Rule Decisions:** Approved, committed & pushed (`eada8aa`).
- **Phase 4 — Steady-State UPS Optimizations:** Profiled, committed & pushed (`95e3c70`, **3× steady-state speedup** across 60 station gates, cutting `on_tick` cost by **98.7 %**).
- **Phase 5 — Cross-Mod UPS Optimizations (`power_bank.lua`, `warp-drive`, `stargate`):** Profiled & prepared in working tree (**4.5× Warp Drive fleet speedup**, **40 % faster active `PowerBank.tick`**, and **another 2.0× Stargate speedup — 4.6× cumulative**).

---

## Phase 1 — Critical Bugs, Leaks & Freezes (Committed: `cebb51a`)

1. **Cross-surface cutscene-skip crash (`scripts/transfer.lua`)** — `leave_cutscene` moves bodiless players forward to `(character.position, character.surface)` before `set_controller`; `arrive()` moves `transfer.entity` to the arrival surface before reattaching watchers; `on_cutscene_cancelled` delegates reattachment to `leave_cutscene`.
2. **`storage.rail_guard` memory leak (`scripts/railway.lua`)** — `prune_guards()` cleans expired entries as train transfers finish.
3. **22.4M-iteration freeze & single-planet miss in `Destinations` (`scripts/destinations.lua`)** — `nearest_uncharted` walks only the 4 square-ring edges ($8r$) with `floor(sqrt(best_distance))` bound, tries all visited planets in random order, and caches exhausted `(force, surface)` pairs for 600 ticks.
4. **Gate removal mid-transfer (`scripts/railway.lua`, `scripts/gate.lua`, `control.lua`)** — `Railway.gate_removed` safely ejects drivers and wrecks carriages caught on the removed gate's own rails while restoring schedules and `manual_mode` on connected carriages outside the sender or already past the partner, and releases held trains.
5. **Double-headed & reversed train acceleration + safety guards (`scripts/railway.lua`)** — `pulling()` counts only locomotives facing the entry direction (`in_sign > 0`), `restore_schedule` guards `saved.current or 1`, and `Railway.update` refreshes `train` after failed `send()`.
6. **Poleless global electric networks, wide-reach poles & minor guards (`scripts/gate.lua`, `scripts/construction.lua`)** — `Gate.check_power` supports `surface.global_electric_network_statistics` when `surface.has_global_electric_network` is true, widens `POLE_REACH` to `40` with negative-lookup caching, updates `veil_from` before `shown` in `apply()`, and guards `if restored` in `Construction`.

---

## Phase 2 — Documentation Contradictions, Collision/GUI Polish & Dead Code (Committed: `95e3c70`)

1. **Resolved contradictions in `stargate/README.md`:**
   - Removed the stale collision tail at line 87 (*"Everything behind the ring is solid… While the gate is closed the portal is solid too"*), which contradicted line 63.
   - Updated line 3 (*"trains are planned"*) and line 13 (*"The portal is empty for now"*), which contradicted the implemented Train Station section.
2. **Synced maintainer docs, locale, GUI status & comments:**
   - `changelog.txt`: removed *"with 95 % efficiency"*, changed *"three phases"* → *"six phases"*, and clarified trains are taken at the gate's edge.
   - `locale/en/strings.cfg` & `scripts/gui.lua`: updated `station-tooltip` (*"reaches the gate's edge"*), and added `status-open-unpaired-station` so unpaired station gates no longer claim *"the paired gate is not a station"*.
   - `docs/gate.md`, `docs/railway.md`, `docs/testing.md`, `prototypes/entities.lua`, `prototypes/recipes.lua`, `AGENTS.md`: updated stale comments and references.
3. **Barrier collision-mask polish (`data-final-fixes.lua`):**
   - Added `bte-stargate-barrier` only to `character`, `spider-leg`, `car`, and `unit` prototypes that already collide on `player`, so ground biters/units cannot walk through solid towers and capacitor banks while modded flying vehicles/characters stay unblocked.
4. **Dead code removal:**
   - Removed unused `Railway.sync_name`, unused `Gate.request`, and the unused `on_entity_cloned` registration (gates and assembling gates are `not-blueprintable` and `not-deconstructable`, matching `warp-drive/control.lua`; kept `Gate.destination` for runtime portal-boundary tests and `bte-stargate-rail-hidden` for existing saves and layout-upgrade tests).

---

## Phase 3 — Gameplay Rule Decisions (Committed: `eada8aa`)

1. **Planetary gravity requirement (`prototypes/entities.lua`):**
   - Added `surface_conditions = {{property = "gravity", min = 0.1}}` to `bte-stargate-construction-site`, `bte-stargate-assembling`, and `bte-stargate` so player-built gates require planetary/moon gravity and cannot be built on Space Platforms (leaving deep-space orbital gates to Homecoming Journey while keeping scripted zero-gravity gate creation functional).
2. **Unpaired gate activation & random jumps (confirmed unchanged):**
   - Kept unpaired random jumps dangerous by design (no ground check or enemy filtering; players decide whether to jump prepared with a jetpack/mech armor and whether to leave unpaired gates powered).
3. **Foot/vehicle travel on Station Mode gates (`scripts/gate.lua`):**
   - Kept foot, vehicle, and unit travel active on Station Mode gates: single-track gates offset arrivals beside the centre rail (`SINGLE_ARRIVAL_DX = -2.5`), while two-track gates keep `dx = 0` down the clear centre strip between the two lanes (`±2`).
4. **Unified center-based portal trigger (`scripts/gate.lua`):**
   - Unified `Gate.update` to check `in_portal(record, entity.position)` by center for cars and tanks just like characters, spidertrons, and units, widened `PORTAL_BACK` from `-0.5` to `-1.0` (`2.5`-tile portal depth so fast cars on refined concrete cannot skip a 3-tick check), and tightened `record.search_filter.area` to the `6 × 2.5` portal zone (`PORTAL_HALF_WIDTH = 3` covers the full 6-tile opening between side barriers so vehicles hugging the side still trigger).

---

## Phase 4 — Steady-State UPS Optimizations (Committed: `95e3c70`)

Measured in headless Factorio 2.1.24 with `helpers.create_profiler()` over 3,000 steady-state ticks on 60 station gates (15 open direct-mode pairs + 15 switched-off pairs):

| Handler | Baseline (3,000 ticks) | Optimized (3,000 ticks) | Change |
| --- | --- | --- | --- |
| `on_tick` (`Gate.collect`) | `318.30 ms` | `4.26 ms` | **−98.7 % (74.7× faster)** |
| `on_nth_tick(3)` (`Gate.update`) | `158.18 ms` | `120.30 ms` | **−23.9 %** |
| `on_nth_tick(3)` (`Railway.check`) | `118.87 ms` | `71.98 ms` | **−39.4 %** |
| `on_nth_tick(30)` (upkeep) | `1.42 ms` | `1.94 ms` | (absorbed layout upkeep) |
| `on_nth_tick(60)` (`Gate.check_power`) | `3.69 ms` | `3.93 ms` | unchanged |
| **Total (3,000 ticks / avg per tick)** | **`600.45 ms` (`0.200 ms/tick`)** | **`202.42 ms` (`0.067 ms/tick`)** | **−66.3 % (3.0× faster)** |

Implemented optimizations:
1. **Active-only `storage.active_gates` & pure-Lua idle decay (`scripts/gate.lua`):**
   - Gates in steady `direct` mode and empty switched-off gates leave `storage.active_gates`, reducing steady-state `Gate.collect()` to a single `next(active)` check; switched-off gates with residual charge zero their capacitor once and decay in pure Lua without C++ `LuaEntity` calls until empty, waking automatically on enable, circuit change, `keep_charged`, or network shortfall.
   - Kept `Gate.TRANSFER_TICKS = 3` rather than `5`: between `EDGE = 7` and `RING_PLANE = 2` (5 tiles), a max-speed nuclear train (`1.38 tiles/tick`) covers `4.15` tiles in 3 ticks (caught before the ring) vs `6.9` tiles in 5 ticks (past the ring).
2. **Reduced 3-tick polling & GUI control-behavior overhead (`scripts/gate.lua`, `scripts/railway.lua`, `scripts/gui.lua`):**
   - Precomputed static `record.surface`, `record.cx`, `record.cy`, `record.center`, `record.search_filter`, `record.exit_signal`, `record.depart_filter`, and `record.depart_edge_y` so 3-tick checks allocate no geometry/filter tables and avoid `signal.name` marshalling.
   - Replaced the 4-way string concatenation `shown` in `apply(record, true)` with an integer bitmask.
   - Short-circuited partner lookups on closed gates in `Railway.check()`, checked `record.entry_open ~= ready` before `control.valid`, and moved `rail_layout ~= LAYOUT` and `map_label` checks into 30-tick `Railway.maintain()`.
   - Changed `Gui.open` (`scripts/gui.lua`) to call `entity.get_control_behavior()` rather than `get_or_create_control_behavior()`, keeping unwired gates on the `nil` fast path in `Gate.circuit_allows`.
3. **Cached prototype lookups in module locals:**
   - Cached `extent(name)` (`scripts/gate.lua`), `half_length(name)` (`scripts/railway.lua`), and `plan()` (`scripts/construction.lua`).

---

## Phase 5 — Cross-Mod UPS Optimizations: `power_bank.lua`, `warp-drive` & `stargate` (Prepared in Working Tree)

Measured in headless Factorio 2.1.24 with `helpers.create_profiler()` over 3,000 ticks across four workloads:

### 1. Warp Drive Fleet — Non-Jumping Steady State (20 Space Platforms: 10 at 1 GW Tachyon Boost + 10 Idle, 60 Nauvis Labs)

| Handler | Baseline (3,000 ticks) | Optimized (3,000 ticks) | Change |
| --- | --- | --- | --- |
| `on_tick` (`Warp.tick`) | `86.29 ms` | `1.47 ms` | **−98.3 % (58.5× faster)** |
| `on_nth_tick(10)` (`Warp.update` + outputs) | `224.64 ms` | `42.27 ms` | **−81.2 % (5.3× faster)** |
| `on_nth_tick(60)` (`Research.update` + `Warp.check_power`) | `33.81 ms` | `32.37 ms` | **−4.3 %** |
| **Total (3,000 ticks / avg per tick)** | **`344.74 ms` (`0.115 ms/tick`)** | **`76.11 ms` (`0.025 ms/tick`)** | **−77.9 % (4.5× faster)** |

### 2. Warp Drive Fleet — Active Jumps (10 at 1 GW Boost + 8 Idle + 2 Actively Warping at Warp-5)

| Handler | Baseline (3,000 ticks) | Optimized (3,000 ticks) | Change |
| --- | --- | --- | --- |
| `on_tick` (`Warp.tick`) | `832.12 ms` | `187.75 ms` | **−77.4 % (4.4× faster)** |
| `on_nth_tick(10)` (`Warp.update` + outputs) | `445.14 ms` | `85.80 ms` | **−80.7 % (5.2× faster)** |
| `on_nth_tick(60)` (`Research.update` + `Warp.check_power`) | `35.48 ms` | `32.42 ms` | **−8.6 %** |
| **Total (3,000 ticks / avg per tick)** | **`1,312.74 ms` (`0.438 ms/tick`)** | **`305.97 ms` (`0.102 ms/tick`)** | **−76.7 % (4.3× faster)** |

### 3. Shared `PowerBank.tick` — Active Adaptive Probing (20 Constrained Banks Ticking Every Tick)

| Workload | Baseline (60,000 `PowerBank.tick` calls) | Optimized (60,000 `PowerBank.tick` calls) | Change |
| --- | --- | --- | --- |
| 20 gates sharing 3 GW (`on_tick`) | `195.40 ms` | `117.21 ms` | **−40.0 % (1.67× faster)** |

### 4. Stargate — 60 Station Gates (15 Open Direct Pairs + 15 Partially Charged Switched-Off Pairs)

| Handler | Post-Phase-4 Baseline (3,000 ticks) | Phase 5 Optimized (3,000 ticks) | Change |
| --- | --- | --- | --- |
| `on_tick` (`Gate.collect`) | `76.86 ms` | `3.11 ms` | **−96.0 % (24.8× faster)** |
| `on_nth_tick(3)` (`Gate.update`) | `103.97 ms` | `77.02 ms` | **−25.9 %** |
| `on_nth_tick(3)` (`Railway.check`) | `70.08 ms` | `44.11 ms` | **−37.1 %** |
| `on_nth_tick(30)` + `on_nth_tick(60)` | `5.38 ms` | `5.87 ms` | unchanged |
| **Total (3,000 ticks / avg per tick)** | **`256.29 ms` (`0.085 ms/tick`)** | **`130.10 ms` (`0.043 ms/tick`)** | **−49.2 % (2.0× faster; 4.6× vs initial `600.45 ms`)** |

Implemented optimizations:
1. **Shared `power_bank.lua` (`warp-drive/scripts/power_bank.lua` & `stargate/scripts/power_bank.lua`):**
   - Verified `electric_interface_mode`, `power_usage`, and buffer state once per VM load/reset via transient `verified[bank] = unit`, skipping `unit.electric_interface_mode` and `unit.electric_buffer_size` reads on consecutive 1-tick updates, reading `game.tick` once per call, and writing `input_flow_limit` / `electric_buffer_size` only when `applied` changes (cutting C++ crossings from ~12 to 2–3 per tick during charging and shortfall holds).
   - Extended direct steady-draw mode (`direct_need`, `ready_for_direct`, `delivered`) to unstored `sink` banks once settled at `max_draw`, and added `PowerBank.idle` for clean 1 J idling.
2. **Warp Drive (`warp-drive/`):**
   - Added `storage.active_drives` and wired `PowerBank` direct mode (`Warp.check_power` via `power.electric_network.parent_network.statistics` every 60 ticks for steady `1 GW` detectors, and every 10 ticks during active warp), dropping idle drives and settled `1 GW` Tachyon Science Boost drives out of `on_tick` completely.
   - Short-circuited valid companion lookups, connected internal red/green circuit wires once per companion instead of twice every 10 ticks, skipped `platform.name` regexes on untagged platforms, evaluated `Research.tachyon_density` only when its output is enabled, and diffed the 5 output-combinator slots so unchanged 10-tick updates perform zero combinator mutations.
   - Flattened anomaly records, eliminated per-tick `{x, y}` and `{r, g, b, a}` table allocations and duplicate `target` writes, throttled sub-degree spin/scale updates to 30 ticks, and skipped per-tick `LuaRendering` position writes when no connected player views the platform surface (wrapping cleanly to the current tick as soon as viewed).
   - Cached static laboratory base speeds by `unit_number`, tracked lab-free surfaces to avoid empty table allocations, and deduplicated planetary lab scans in `Research.snapshot`.
3. **Stargate (`stargate/`):**
   - Replaced tick-by-tick idle leak (which kept partially charged switched-off gates in `storage.active_gates` for up to 76.7 minutes until `< 1 J`) with exact closed-form analytical decay (`decay_from`, `(1 - LEAK_PER_SECOND / 60) ^ dt`), dropping switched-off gates from `storage.active_gates` on the very next tick.
   - Replaced the `POLE_REACH` electric-pole search in `Gate.check_power` with direct `capacitor.electric_network.parent_network.statistics` (O(1) on both pole networks of any reach and poleless global networks).
   - Skipped switched-off closed gates in 3-tick `Gate.update`, pre-checked empty portals with zero-allocation `count_entities_filtered(..., limit = 1)` before `find_entities_filtered`, maintained `storage.station_gates` for `Railway.check` / `Railway.maintain`, short-circuited empty `receiving(target)` in pure Lua, and indexed open GUI windows in one pass per refresh.
