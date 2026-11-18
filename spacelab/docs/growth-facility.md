# Space Lab: Growth Facility

Maintainer reference for the Growth Facility's prototype and graphics. Player-facing recipes and values are in the [README](../README.md). Code: `prototypes/entities.lua`, `prototypes/recipes.lua`; model: `tools/sprites/models/growth-facility*.js`.

## Prototype

- Circuit connector data and wire distance are copied from the Space Age Cryogenic Plant.

## One recipe, one tint channel

Each growth recipe owns one `crafting_machine_tint` channel, set opaque white while the other three are transparent:

| Recipe | Channel |
| --- | --- |
| Yumako | primary |
| Jellynut | secondary |
| Biter egg | tertiary |
| Pentapod egg | quaternary |

- The building's matching `specimens-<recipe>` overlay, its tinted copies of the shared `fluid`, `glow-vat-bottom`, and `glow-vat-top` overlays, and its recipe light use that channel, so one building shows only the running recipe's contents.
- The vat glows are drawn before the specimens, so the light shows them as silhouettes instead of washing them out.
- A new growth recipe needs a free channel; there are only four.
- Fluid colours are duplicated between `prototypes/entities.lua` and the model's `VARIANT_COLORS`.

## Generated graphics

Edit the models, never the PNG or `.lua` output; re-export from `tools/sprites/`:

| Output | Model | Command |
| --- | --- | --- |
| `graphics/entity/growth-facility/` (building sheets) | `growth-facility.js` | `node render.mjs growth-facility --export` |
| `graphics/icons/growth-facility.png` (a 120x64 strip with custom mipmaps) | the simplified `growth-facility-icon.js` | `node render.mjs growth-facility-icon --export` |
| `graphics/technology/growth-facility.png` (256 px, main layer) | `growth-facility-technology.js`, the same model | `node render.mjs growth-facility-technology --export` |
| `docs/*.gif` (README) | `growth-facility.js` preview | `node render.mjs growth-facility && node gif.mjs growth-facility --out=../../spacelab/docs` |

Round parts (tanks, caps) are squashed front to back by `ROUND_DEPTH` (0.78); see the note in `AGENTS.md`.
