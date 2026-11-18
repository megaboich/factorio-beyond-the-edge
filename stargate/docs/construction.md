# Stargate: Construction

Maintainer reference for how a gate is built: the kit and the construction site, the build phases, and the footprint's grid. Player-facing amounts and times are in the [README](../README.md). Code: `prototypes/construction.lua`, `data-final-fixes.lua`, `scripts/construction.lua`.

## Bill of materials

- The scarce high-end parts go into the kit recipe and the bulk into the construction site, whose bill is written only in `prototypes/construction.lua` (the README table and `tests/prototypes.py` mirror it).
- The site is a `container` with one filtered slot per stack of each material, so only the bill can be delivered. `data-final-fixes.lua` lays the slots out from final stack sizes and publishes them (with the amounts, build time, and stage count) as a `mod-data` prototype, which `scripts/construction.lua` reads through `prototypes.mod_data`.
- Every bulk amount must be a whole number of stacks: then a material's slots hold exactly its amount and a delivery cannot overshoot, which is the only insertion limit a chest can give (the Factorio 2.1 prototype API has none, and re-filtering slots and taking overshoot back out proved fragile with inserters). `tests/prototypes.py` checks the alignment against the game's stack sizes. If another mod changes stack sizes anyway, completion still tests for at least the bill, consumes it, and spills the surplus beside the gate.

## Three entities, one footprint

Construction is three entities on one 14x14 footprint, each replacing the last in place with its health fraction: the site (a `container`), `bte-stargate-assembling`, and the finished `bte-stargate`.

- The assembling entity has one picture per phase in `pictures`: the first is the construction site's own sprites (so the site does not visibly change when its delivery completes), then `graphics/entity/assembling/assembling-<n>-*`. The runtime sets `graphics_variation` as `build_ticks` passes; `stages` (6) and `build_ticks` live in the mod-data, and `prototypes/entities.lua` errors if the picture list and `stages` disagree.
- Its progress bar is two `LuaRenderObject` rectangles on the `entity-info-icon-above` render layer, because the tall ring covers a bar drawn at the default layer.
- The assembling gate is a `simple-entity-with-owner`; the finished gate is described in [gate.md](gate.md).

## Grid and offsets

All three entities set `build_grid_size = 2`, the grid rails use. Measured (headless, `create_entity` snaps by default, with throwaway entities of several widths): on that grid an even-width entity's origin snaps to even coordinates and an odd-width one's to even + 0.5, regardless of the width of the box, while straight rails snap to odd coordinates (`tile_width` can be set to override the width used).

No setting centres a 14-wide entity on an odd coordinate, so the boxes are offset from the origin instead: collision `{{-5.9, -5.9}, {7.9, 7.9}}`, selection `{{-6, -6}, {8, 8}}`, sprites shifted `{1, 1}`.

- The building's centre is its position plus (1, 1), which the runtime must allow for (`CENTER` in `scripts/construction.lua`).
- Its edges are on rail cell edges, and the two rail beds (centres two tiles either side of the centre, so at odd coordinates) are on rail positions, with four tiles of platform either side: 4 | rail | gap | rail | 4.
- Entity corpses and anything else keyed to the origin sit one tile north-west of the building's centre.
- `tests/mods/bte-stargate-runtime-test` pins the snapping and that rails fit flush against all edges but not overlapping, and `tests/prototypes.py` that every sprite's shift follows the boxes.
- Blueprint and cursor snapping still need a visible-game check.
