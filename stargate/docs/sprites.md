# Stargate: Sprites

Maintainer reference for the gate's generated graphics. Every sprite is generated; edit the models, never the PNG or `.lua` output. The regeneration commands for every mod are in the Generated Assets table of `AGENTS.md`.

## The model

Change `tools/sprites/lib/stargate-parts.js` or the thin models around it (`models/stargate*.js`), then re-export from `tools/sprites/`:

```sh
node render.mjs stargate stargate-site stargate-stage1 stargate-stage2 stargate-stage3 stargate-stage4 stargate-stage5 stargate-icon stargate-kit-icon stargate-technology --export
```

`stargate-parts.js` is one parameterised build of the modern, human-built gate:

- concrete floor, segmented steel ring with a tungsten core, steel support towers with fans and grilles;
- machinery housings (`housing()`) filling the lower corners between the towers and the ring;
- the power bank's capacitor cans (`capacitors()`, in groups: the front east rack, the west and the east banks) along the west and east walls behind the towers and in the front east corner, kept off the lanes and the apron;
- cyan status lights, and an empty portal, which the finished gate's animated `glow-veil` layer (the `active` variant, `drawVeil()`) fills while open.

Its `STATES` table is the `site`, `stage1` to `stage5`, and `complete`: six construction pictures, each adding to the last on the finished floor inside hazard tape (`tape()`), with dark lamps; the finished gate drops the tape and lights up. Its `tracks` option draws station mode's track and chevrons ([railway.md](railway.md)). The kit icon renders the `stage2` state.

## Geometry

- The ring stands in the x-y plane, `RING_Z` (2 tiles) south of the platform's centre so its height does not pile up behind the building, between two towers, with the lanes along z centred two tiles either side of the platform's centre (see [construction.md](construction.md) for the grid).
- The floor (`floorHeight`) is level with the ground at the border, slopes down to a basin (`DECK`), and has a trench under the ring (`TRENCH`) whose south side is a slope so the camera sees the ring's lowest point. The ring's inner edge is 3.1 tiles from its axis at deck level, clearing both lanes. Geometry below y = 0 renders normally.
- The finished floor wears vanilla `base/graphics/terrain/concrete/refined-concrete.png` (one 512 px variant per 9 tiles, tinted to match the game's brightness), loaded through `factorioTexture` in `lib/textures.js`, so rendering needs `FACTORIO_DATA`.
- `lean()` fakes vanilla's slight perspective (orthographic renders make vertical sides look like flat cut-outs): every vertex above ground moves towards x = 0 by `LEAN` per tile of height, so the towers and ring lean in and show their outer faces.

## Previews

- The finished gate's preview (`out/stargate-preview.html`) shows Nauvis grass (the model's `ground`) and every construction stage as `{model: ...}` references, so render `stargate-site` and `stargate-stage1` to `-stage5` before `stargate`.
- `stargate-rail.js` is the finished gate with tracks; it has `export: null`, so `render.mjs --export` only previews it.
- How the layers are split between the gate and its companions is in [gate.md](gate.md).
- A later ancient (Fulgoran) gate for Homecoming Journey is planned as a separate build of the same footprint.
