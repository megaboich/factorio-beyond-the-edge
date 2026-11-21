# Stargate Implementation Review & Action Plan

Comprehensive code, design, documentation, and UPS review of `stargate/` (`bte-stargate` 0.1.0), organized into phased work items.

---

## Overall Assessment

The core architecture is sound and addresses genuine Factorio engine constraints cleanly:

- **Train station mode (`scripts/railway.lua`, `prototypes/rails.lua`):** Using an invisible `train-stop` behind the ring (`STATION_Y = -4`), a circuit-controlled vanilla `entry_signal` at the south edge (`EDGE = 7`), and an invisible `exit_signal` on the partner's arrival lane avoids RiftRail's 1-HP collider and wait-condition workarounds. Trains wait naturally at signals without cross-surface "No path" alerts, keep block reservations, cross the edge at speed, and steer themselves through switches once a forward-facing locomotive arrives without needing a fake helper locomotive.
- **Layered companions (`scripts/gate.lua`, `prototypes/entities.lua`):** Splitting the floor (`floor`), ring/towers (`object` at `RING_Z = 2`), upper arc (`elevated-object` over spidertrons), and ramped tracks (`floor-mechanics`) handles isometric depth sorting cleanly.
- **Shared power bank (`scripts/power_bank.lua`):** Adaptive probing protects shared factory grids, and direct mode offloads steady-state draw to the C++ engine once full.

However, the review uncovered **6 high-priority runtime bugs/leaks/freezes (Phase 1)**, **smaller edge-case bugs & doc contradictions (Phase 2)**, **gameplay rule edge cases to decide on (Phase 3)**, and **steady-state UPS optimizations (Phase 4)**.

---

## Phase 1 — Critical Bugs, Leaks & Freezes (Prepared in Working Tree)

Unambiguous bugs that crash, leak memory, freeze the game, or break train/power state without changing intended gameplay rules:

1. **Cross-surface cutscene-skip crash (`scripts/transfer.lua:156-176, 335-349, 488-509`)**
   - **Problem:** Skipping the cutscene during the 128-tick departure phase (`TRANSIT_TICKS`) on a cross-surface trip removes the watcher, moves `character` to the destination surface in `finish()`, and calls `player.set_controller({type = defines.controllers.character, character = watcher.character})` while `player` is still on the departure surface — throwing `LuaEntity belongs to surface <B> but a LuaEntity belonging to surface <A> was expected`. Furthermore, in a multi-rider vehicle where one player skips during `TRANSIT_TICKS`, `leave_cutscene` in `finish()` sees `char2.surface ~= player2.surface` and teleports the arrived vehicle *backward* to `player2`'s departure surface.
   - **Fix:** Have `leave_cutscene` move the bodiless `player` to `(character.position, character.surface)` (`LuaControl.teleport` supports characterless players cross-surface) instead of dragging `character`/vehicle back to `player.surface`; move `transfer.entity` to the arrival surface before reattaching watchers in `arrive()`; and call `leave_cutscene(player, watcher.character)` after `finish()` in `on_cutscene_cancelled`.

2. **Unbounded memory & save-file leak in `storage.rail_guard` (`scripts/railway.lua:421-429, 726, 963`)**
   - **Problem:** Every cloned carriage of every train writes `storage.rail_guard[unit_number] = {tick = ..., gate = ...}` in `send()` and `finish()`, but expired entries are only deleted inside `guarded()`, which is only called for manual trains (`not automatic`). Automatic trains clone to new `unit_number`s on every trip, leaking dead tables in `storage.rail_guard` forever.
   - **Fix:** Prune expired entries (`guard.tick <= game.tick`) in `finish()` whenever any rail transfer ends or aborts (matching `storage.arrived` in `scripts/transfer.lua`).

3. **Severe 22.4M-iteration freeze & single-planet miss in `Destinations` (`scripts/destinations.lua:53-109`)**
   - **Problem:** `nearest_uncharted` iterates the entire filled square `(-radius..radius)^2` for each ring up to `SEARCH_CHUNKS = 256` and filters `math.max(math.abs(dx), math.abs(dy)) == radius` ($\approx 22.4\text{M}$ Lua loop iterations and up to $263\text{k}$ `is_chunk_charted` C++ calls in one tick). If the randomly chosen planet is fully charted within 256 chunks of spawn, `Destinations.pick` returns `nil` without trying other visited planets, and `Gate.update` repeats the 22.4M-iteration scan every 3 ticks while anything stands in the portal.
   - **Fix:** Walk only the 4 perimeter edges of each square ring ($8r$ chunks instead of $(2r+1)^2$, up to 170× fewer iterations) with exact Euclidean bound `math.floor(math.sqrt(best_distance))`; try remaining visited planets in random order if one is exhausted; and cache exhausted `(force, surface)` pairs in `storage` for 600 ticks.

4. **Gate removal silently vaporizes carriages on its rails & strands surviving train halves (`scripts/gate.lua:150-159`, `scripts/railway.lua:980-988`)**
   - **Problem:** When a station gate dies or is destroyed, `Gate.removed` runs `Gate.remove_railway` immediately before `Railway.update` can run `abort()`. `remove_railway` calls bare `car.destroy()` on every carriage overlapping the gate's rails (without ejecting any seated character/remote driver or spawning explosion/remnants), invalidating `transfer.car` / `transfer.last` so `abort()` fails to restore `manual_mode` and schedules on surviving carriages outside the gate's rails.
   - **Fix:** Add `Railway.gate_removed(record)` called before `Gate.remove_railway(record)`: safely eject drivers and wreck carriages caught on the gate's own rails (which must go so the gate's rails can be destroyed), while restoring schedules and `manual_mode` (and stopping script push) on any surviving carriages outside the sender or already past the receiver, and releasing held trains. Update `README.md` and `docs/railway.md` to match.

5. **Double-headed & reversed train acceleration (`scripts/railway.lua:345-357`, plus nil/train-validity guards at `:831, :1099`)**
   - **Problem:** `pulling(train, record)` sums both `front_movers` and `back_movers`, giving double-headed `1-N-1` trains 2× their real acceleration and nonzero locomotive force to trains pushed backwards with no mover facing in. Also `restore_schedule` line 831 compares `index < saved.current` without the `or 1` fallback used on line 828, and `Railway.update` line 1099 uses a stale `LuaTrain` reference after a failed `send()` uncouples and recouples `front`.
   - **Fix:** Count only movers facing the entry direction (`in_sign(train, record) > 0`), guard `saved.current or 1`, and refresh `train = front.valid and front.train` after failed `send()`.

6. **Legendary Substations & global electric networks break `Gate.check_power` direct mode (`scripts/gate.lua:245-313, 518-525`, `scripts/construction.lua:154-173`)**
   - **Problem:** `POLE_REACH = 20` misses vanilla Legendary Substations (`14 + 6.9 = 20.9` tiles from gate center) and surfaces with `has_global_electric_network` (no poles), leaving `count == nil` so `Gate.check_power` kicks full gates out of direct mode every second and repeats a 40×40 entity scan forever. Also `apply()` computes `shown` before `show_veil` sets `veil_from` (causing a spurious companion sync 3 ticks after opening), and `Construction` recovery paths assume `restored` is non-nil.
   - **Fix:** Support `surface.global_electric_network_statistics` when `surface.has_global_electric_network` is true, widen `POLE_REACH` to `40` (cached on `record.pole`, with negative lookup remembered per network ID), update `veil_from` before computing `shown`, and guard `if restored` in `scripts/construction.lua`.

---

## Phase 2 — Documentation Contradictions, Dead Code & Minor Polish

1. **Resolve contradictions in `stargate/README.md`:**
   - Remove the stale collision paragraph at line 87 (*"Everything behind the ring is solid… While the gate is closed the portal is solid too"*), which contradicts line 63 and the actual barrier layout.
   - Fix line 3 (*"trains are planned"*) and line 13 (*"The portal is empty for now; bridges and train tracks will cross the trench once train passage exists"*), which contradict the implemented Train Station section at line 93.
2. **Sync maintainer docs, locale & comments:**
   - `changelog.txt`: remove *"with 95 % efficiency"*, change *"three phases"* → *"six phases"*, and clarify trains are taken at the gate's edge.
   - `locale/en/strings.cfg:60`: update `station-tooltip` (*"reaches the ring"* → *"reaches the gate's edge"*).
   - `scripts/gui.lua:35-38`: distinguish unpaired station gates from station gates paired to a non-station partner so unpaired gates do not say *"the paired gate is not a station"*.
   - `docs/gate.md`, `docs/testing.md`, `prototypes/entities.lua`, `prototypes/recipes.lua`: update stale comments (*"opens only when paired"*, *"5 ticks"*, *"draws its 1 GW and shows its veil"*).
3. **Barrier collision-mask polish (`data-final-fixes.lua:58-63`):**
   - Only add `bte-stargate-barrier` to prototypes that already collide on `player` (so modded flying vehicles / jetpack characters are not blocked by Stargate towers), and include `"unit"` so ground biters cannot walk through the solid towers and capacitor banks.
4. **Remove dead code & redundant prototypes:**
   - Delete unused `Railway.sync_name` (`scripts/railway.lua:271`), unused `Gate.request` (`scripts/gate.lua:325` + `control.lua:155`), and evaluate removing test-only `Gate.destination` (`scripts/gate.lua:673`).
   - Consider collapsing `bte-stargate-rail-hidden` into `bte-stargate-rail` (`prototypes/rails.lua:27-29`), since both now use `render_layers = "zero"`, and pruning pre-0.1.0 dev-save shims (`map_label`, `lights_high`, `object_name ~= "LuaEntity"`).
   - Handle `on_entity_cloned` cleanly (`control.lua:46-48`) so area-cloning a gate adopts or replaces cloned companions instead of stacking duplicates, and covers `bte-stargate-assembling`.

---

## Phase 3 — Gameplay Rule Decisions (Needs Author Confirmation)

1. **Space Platform placement & travel:**
   - Should `bte-stargate-construction-kit` / `bte-stargate-construction-site` require `gravity >= 0.1` (blocking Space Platform placement until Homecoming Journey's dedicated orbital gate), or remain placeable in space with station mode and bare-character arrival restricted on zero-gravity surfaces?
2. **Unpaired gate activation & random jumps:**
   - Should a gate stay closed (`record.open = false`, saving 8 GJ + 1.05 GW) when it has no partner and no valid destination (`not Destinations.any(force)`), eliminating the *"Open, but there is no planet to send you to"* state?
   - Should unpaired random jumps ignore enemy `unit` / `spider-unit` entities (preventing biters from triggering cross-planet chunk generation onto player-visited worlds)?
   - When `find_non_colliding_position` finds no land in the nearest uncharted chunk (e.g. ocean/oil/lava), should `Destinations.location` advance to the next uncharted chunk or refuse the jump instead of falling back to `or center` onto impassable terrain? Also pass `entity.name` instead of hardcoded `"character"`.
3. **Foot/vehicle travel on Station Mode gates:**
   - Currently `Gate.arrival` drops foot/vehicle travellers at `x = center.x` (dead center on a single-track rail) and walks them 5 tiles down the active track under a movement-locked cutscene.
   - Options: (a) disable foot/vehicle portal capture while `record.railway ~= nil` (cleanest rule and eliminates 3-tick entity scans on all rail gates), or (b) offset foot/vehicle arrivals off active rail lanes.
4. **Vehicle portal trigger box (`scripts/gate.lua:694-702`):**
   - Now that the 6-tile corridor through the ring has no rear barriers, should cars/tanks trigger by center (or a smaller margin) like spidertrons and characters so tanks don't vanish ~2.8 tiles before reaching the ring?

---

## Phase 4 — Steady-State UPS Optimizations

1. **Zero-C++-call fast path for switched-off / empty gates in `Gate.collect` (`scripts/gate.lua:212-238`):**
   - Switched-off or circuit-disabled gates (`max_draw == 0`) never enter `direct` mode, running 7 C++ `LuaEntity` reads/writes per tick forever even when `charge == 0`. Fast-pathing `not charging` (pure-Lua exponential decay while `charge > 0`, immediate return when `charge == 0` and `applied == 0`) or maintaining an active `storage.ticking_gates` set drops idle `on_tick` cost to near zero.
2. **Reduce 3-tick polling cost (`scripts/gate.lua`, `scripts/railway.lua`, `scripts/gui.lua`):**
   - Consider raising `Gate.TRANSFER_TICKS` from `3` to `5` (still catches 6-exoskeleton runners across the 2-tile portal zone while cutting `Gate.update` and `Railway.check` cost by 40%).
   - Precompute static `record.center`, `record.portal_area`, and `record.exit_signal` on `record` instead of allocating coordinate tables and scanning `target.signals` / `signal.name` every check.
   - Replace the 4-way string concatenation `shown` in `apply(record, true)` with an integer bitmask.
   - Use `entity.get_control_behavior()` instead of `get_or_create_control_behavior()` when opening the GUI (`scripts/gui.lua:204`) so gates without circuit wires short-circuit on `nil` in `Gate.circuit_allows`.
   - Move `rail_layout ~= LAYOUT` and `map_label` checks out of the 3-tick `Railway.check` loop into `Gate.prune` (30 ticks) or `rebuild`.
3. **Cache prototype lookups in module locals:**
   - Cache `half_length(name)` (`scripts/railway.lua:386`), `extent(name)` (`scripts/gate.lua:657`), and `plan()` (`scripts/construction.lua:25`) in module-local tables, matching `power_data` in `scripts/gate.lua`.
