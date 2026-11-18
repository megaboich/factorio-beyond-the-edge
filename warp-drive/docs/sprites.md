# Warp Drive: Sprites

Maintainer reference for the Warp Drive's generated graphics. Every sprite is generated; edit the models in `tools/sprites/models/`, never the PNG or `.lua` output, and re-export from `tools/sprites/`. How the layers are put together in game is in [building.md](building.md).

## Building, icon, and technology

- Building sheets in `graphics/entity/warp-drive/` come from `warp-drive.js`: `node render.mjs warp-drive --export`.
- The item icon `graphics/icons/warp-drive.png` and technology icon `graphics/technology/warp-drive.png` come from `warp-drive-icon.js` and `warp-drive-technology.js`: `node render.mjs warp-drive-icon warp-drive-technology --export`.
- README GIFs in `docs/`: `node render.mjs warp-drive && node gif.mjs warp-drive --out=../../warp-drive/docs`.

## State overlays

- The model's state layers (`interior-<state>`, `glow-<state>`) map one-to-one to the `bte-warp-drive-<state>-interior` and `-glow` animation prototypes.
- Frame counts are duplicated in `prototypes/entities.lua` (`overlay_frames`) and `scripts/visuals.lua` (`STATES`), and playback speeds assume the model's 32-frame loop lasts 64 ticks.

## Warp field effects

Warp field effects in `graphics/entity/warp-field/` (the activation shockwave ring, the lightning cloud, the background anomaly shapes, and the subspace streaks) come from `warp-field.js`, which draws only additive layers: `node render.mjs warp-field --export`.

## Geometry tied to the code

- The circuit wire points in `prototypes/entities.lua` are the model's terminal insulator tips; move them with the terminal.
- Round parts (dais, caps, rings, and the activation shockwave) are squashed front to back by `ROUND_DEPTH` (0.78), duplicated in `warp-drive.js`, `warp-field.js`, and `scripts/shockwaves.lua`, which sweeps asteroids along the ring's oval. See the note in `AGENTS.md`.
