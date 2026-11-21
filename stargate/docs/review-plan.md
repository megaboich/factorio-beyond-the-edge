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
- **Phase 2 — Documentation Contradictions, Collision/GUI Polish & Dead Code:** Prepared in working tree.
- **Phase 3 — Gameplay Rule Decisions:** Open design questions for S2 / standalone progression.
- **Phase 4 — Steady-State UPS Optimizations:** Profiled and prepared in working tree (**3× steady-state speedup** across 60 station gates, cutting `on_tick` cost by **98.6 %**).

---

## Phase 1 — Critical Bugs, Leaks & Freezes (Committed: `cebb51a`)

1. **Cross-surface cutscene-skip crash (`scripts/transfer.lua`)** — `leave_cutscene` moves bodiless players forward to `(character.position, character.surface)` before `set_controller`; `arrive()` moves `transfer.entity` to the arrival surface before reattaching watchers; `on_cutscene_cancelled` delegates reattachment to `leave_cutscene`.
2. **`storage.rail_guard` memory leak (`scripts/railway.lua`)** — `prune_guards()` cleans expired entries as train transfers finish.
3. **22.4M-iteration freeze & single-planet miss in `Destinations` (`scripts/destinations.lua`)** — `nearest_uncharted` walks only the 4 square-ring edges ($8r$) with `floor(sqrt(best_distance))` bound, tries all visited planets in random order, and caches exhausted `(force, surface)` pairs for 600 ticks.
4. **Gate removal mid-transfer (`scripts/railway.lua`, `scripts/gate.lua`, `control.lua`)** — `Railway.gate_removed` safely ejects drivers and wrecks carriages caught on the removed gate's own rails while restoring schedules and `manual_mode` on connected carriages outside the sender or already past the partner, and releases held trains.
5. **Double-headed & reversed train acceleration + safety guards (`scripts/railway.lua`)** — `pulling()` counts only locomotives facing the entry direction (`in_sign > 0`), `restore_schedule` guards `saved.current or 1`, and `Railway.update` refreshes `train` after failed `send()`.
6. **Poleless global electric networks, wide-reach poles & minor guards (`scripts/gate.lua`, `scripts/construction.lua`)** — `Gate.check_power` supports `surface.global_electric_network_statistics` when `surface.has_global_electric_network` is true, widens `POLE_REACH` to `40` with negative-lookup caching, updates `veil_from` before `shown` in `apply()`, and guards `if restored` in `Construction`.

---

## Phase 2 — Documentation Contradictions, Collision/GUI Polish & Dead Code (Prepared in Working Tree)

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

## Phase 3 — Gameplay Rule Decisions (Open — Needs Author Confirmation)

1. **Space Platform placement & travel:**
   - Currently zero-gravity placement is allowed (tested by the runtime suite's zero-gravity vehicle refusal check). Should `bte-stargate-construction-kit` / `bte-stargate-construction-site` eventually require `gravity >= 0.1` (blocking Space Platform placement until Homecoming Journey's dedicated orbital gate), or remain placeable in space with station mode and bare-character arrival restricted on zero-gravity surfaces?
2. **Unpaired gate activation & random jumps (Milestone S2):**
   - Should a gate stay closed (`record.open = false`, saving 8 GJ + 1.05 GW) when it has no partner and no valid destination (`not Destinations.any(force)`), eliminating the *"Open, but there is no planet to send you to"* state?
   - Should unpaired random jumps ignore enemy `unit` / `spider-unit` entities (preventing biters from triggering cross-planet chunk generation onto player-visited worlds)?
   - When `find_non_colliding_position` finds no land in the nearest uncharted chunk (e.g. ocean/oil/lava), should `Destinations.location` advance to the next uncharted chunk or refuse the jump instead of falling back to `or center` onto impassable terrain?
3. **Foot/vehicle travel on Station Mode gates:**
   - Currently `Gate.arrival` drops foot/vehicle travellers at `x = center.x` (on a single-track rail) and walks them 5 tiles south. Should foot/vehicle portal capture be disabled while `record.railway ~= nil`, or should arrivals be offset off active rail lanes?
4. **Vehicle portal trigger box (`scripts/gate.lua`):**
   - Now that the 6-tile corridor through the ring has no rear barriers, should cars/tanks trigger by center (or a smaller margin) like spidertrons and characters instead of as soon as their bounding box touches the portal zone?

---

## Phase 4 — Steady-State UPS Optimizations (Profiled & Prepared in Working Tree)

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
