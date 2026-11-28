# Stargate: Sprites

Maintainer reference for the gate's generated graphics. Every sprite is generated; edit the models, never the PNG or `.lua` output. The regeneration commands for every mod are in the Generated Assets table of `AGENTS.md`.

## The model

Change `tools/sprites/lib/stargate-parts.js` or the thin models around it (`models/stargate*.js`), then re-export from `tools/sprites/`:

```sh
node render.mjs stargate stargate-site stargate-stage1 stargate-stage2 stargate-stage3 stargate-stage4 stargate-stage5 stargate-ruin stargate-icon stargate-kit-icon stargate-technology --export
```

`stargate-parts.js` is one parameterised build of the modern, human-built gate:

- concrete floor, segmented steel ring with a tungsten core, steel support towers with fans and grilles;
- machinery housings (`housing()`) filling the lower corners between the towers and the ring;
- the power bank's capacitor cans (`capacitors()`, in groups: the front east rack, the west and the east banks) along the west and east walls behind the towers and in the front east corner, kept off the lanes and the apron;
- cyan status lights, and an empty portal, which the finished gate's animated `glow-veil` layer (the `active` variant, `drawVeil()`) fills while open.

Its `STATES` table is the `site`, `stage1` to `stage5`, and `complete`: six construction pictures, each adding to the last on the finished floor inside hazard tape (`tape()`), with dark lamps; the finished gate drops the tape and lights up. A `ruin` state (`ruin()`, model `stargate-ruin.js`) is the remnants every stage leaves when destroyed (`bte-stargate-remnants`): after an explosion: a cratered, cracked floor (`ruinHeight()`, `CRATERS`) broken off unevenly round its border (`edgeBite()`, `brokenEdge()`, which pulls the border vertices in rather than dropping triangles, which left a staircase), with loose chunks along the break, ash and rubble on the ground round it, fading out over about two tiles so it blends into the terrain (the ash texture must be `SRGBColorSpace`: read as linear, its dark colour rendered as a pale haze), heavy soot spreading from the blast, ring segments thrown out and tipped with their ends dug in, the ring's broken bottom stub, burnt-out tower stumps with twisted posts, concrete chunks and rebar, blackened capacitor cans, and scattered plates, all charred, and kept low as remnants lie on their own layer. Its `tracks` option draws station mode's track and chevrons ([railway.md](railway.md)). The track sinks to ground level over its last 0.8 tiles, so its deck ends on screen at the gate's edge without covering the game's ties; only the rail heads run on 0.25 tiles, flat, to meet the game's rail metal, which starts a little inside its tile (seen in game). The kit icon renders the `stage2` state. Frozen pictures (Aquilo, unheated) come from `lib/frost.js`, which gives every material a frosted twin, after vanilla's frozen overlays: the machinery crusted in ice with grey rime in the gaps, lit and shaded like the building, and the floor chilled with a few drifts, lamps dark. The site and each stage export a `frozen` layer; the gate exports `main-frozen`, `main-single-frozen`, `main-double-frozen`, `top-frozen`, and `floor-frozen` (variants `frozen:<base>`, which frost the base variant and hide the veil). The gate's item icon (`stargate-icon.js`) is a simplified stand-in, like the Growth Facility and Warp Drive icons: a chunky ring with lit clamps, two towers framed in light trim, and a deck, with the portal open as a bright, opaque veil, so it reads at 16 to 64 px. The technology icon (`stargate-technology.js`) is the full building at 256 px, where its detail reads, with one still of the in-game veil (`drawVeil()`) recoloured brighter and opaque, as an icon has no background for an additive glow to light. The three later technologies stack badges on that picture.

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
