# Factorio: Beyond the Edge Development Guide

This repository holds independent Factorio: Space Age post-game mods. They share one repository, one rule set, and one build script, but each mod is packaged, versioned, and published separately.

## Repository Map

- `README.md`: umbrella overview with a short summary of each mod and links to its documentation.
- `AGENTS.md`: the single development rule set for every mod in this repository.
- `make.sh`: packages and installs one or more mods.
- `tests/`: cross-mod test tooling. `run-prototype-tests.sh` loads vanilla Space Age, each mod alone, and all mods together, then runs every mod's `tests/prototypes.py` through the shared `prototype_checks.py` helpers.
- `tools/readme-icons.py`: extracts the item, fluid, and technology icons each mod README references (`docs/icons/<prototype-name>.png`, `docs/icons/technology/<prototype-name>.png`) from the game and the mods into that mod's `docs/icons/`, and removes unreferenced ones. Run `python3 tools/readme-icons.py` after changing README icon references.
- `tools/sprites/`: sprite renderer for buildings, icons, and effects. Three.js models in `models/` (shared helpers in `lib/`) are rendered by headless Chrome (`node render.mjs`, after `npm install`) into Factorio sheets under the git-ignored `out/`: main, shadow, model-defined extra layers (such as per-variant specimens with their own frame count and speed), and additive `glow-*` layers with their `shift` metadata, plus an animated day/night preview (`<name>-preview.html`, with a no-recipe mode) beside the current and vanilla art. `gif.mjs` records README GIFs from that preview (needs `ffmpeg` and `gifsicle`). Lives outside every mod root, so it is never packaged.
- `spacelab/`: SPACELAB mod root (`info.json` name `bte-spacelab`).
- `warp-drive/`: Warp Drive mod root (`info.json` name `bte-warp-drive`).

Each mod directory is a complete Factorio mod root. Directory names are repository paths only; the published mod name always comes from `info.json`. Run commands from the repository root unless stated otherwise.

### SPACELAB

- `data.lua`: loads categories, items, entities, recipes, and technologies.
- `data-final-fixes.lua`: applies intentional vanilla overrides after other data-stage changes.
- `prototypes/helpers.lua`: prototype guards, icon lookup, recipe registration, and technology helpers.
- `prototypes/categories.lua`, `items.lua`, `entities.lua`, `recipes.lua`, `technologies.lua`, `overrides.lua`: feature-sized prototype files.
- `tests/prototypes.py`: resolved-prototype expectations; never packaged.
- `docs/`: README images such as the Growth Facility GIFs and `icons/`; never packaged. Regenerate with `node render.mjs growth-facility && node gif.mjs growth-facility --out=../../spacelab/docs` from `tools/sprites/`.

### Warp Drive

- `control.lua`: runtime composition root.
- `scripts/`: feature-owned runtime modules (`drive.lua`, `warp.lua`, `research.lua`, `gui.lua`, `visuals.lua`, `anomalies.lua`, `shockwaves.lua`).
- `prototypes/`: feature-sized prototype files.
- `graphics/`: generated building sheets, item icon, and technology icon.
- `resources/audio/`: committed sound bank and its generator.
- `docs/`: README GIFs and `icons/`; never packaged. Regenerate the GIFs with `node render.mjs warp-drive && node gif.mjs warp-drive --out=../../warp-drive/docs` from `tools/sprites/`.
- `tests/`: resolved-prototype expectations (`prototypes.py`), runtime test runner, and helper mods; never packaged.

## Documentation Rules

- Each mod's `README.md` is the single source of truth for its player-facing mechanics, recipes, yields, technology costs, balance values, dependencies, and asset attribution. Update it whenever that mod's gameplay changes.
- In mod READMEs, every ingredient and product in recipe tables and lists, every building described, and every science pack a technology needs, is preceded by its game icon, like the Factorio wiki: `<img src="docs/icons/<prototype-name>.png" width="24" height="24" alt="">`. Technology tables show the technology icon at 48 px (`docs/icons/technology/<prototype-name>.png`). Regenerate the icons with `tools/readme-icons.py`.
- The root `README.md` only summarizes each mod and links to its README. Do not copy recipes, costs, or balance values into it.
- Keep this file limited to development context. Do not duplicate player-facing information here.
- Warp Drive also keeps maintainer references with fixed roles:
  - `BUILDING.md`: composite-entity composition, ownership, electrical lifecycle, wiring, and rendering only.
  - `AUDIO.md`: sound assets, synthesis, runtime playback, scheduling state, and regeneration.
- Do not keep speculative design proposals or planning documents in the repository; implemented behavior belongs in the README.

## Naming

Factorio shares one namespace per prototype type, mod setting, locale section, and top-level GUI element across every installed mod, and a later `data:extend` with the same name silently replaces the earlier prototype. Every name these mods introduce therefore carries the `bte-` (Beyond the Edge) prefix:

- Mod names: `bte-<mod>`, such as `bte-spacelab` and `bte-warp-drive`. Graphics and sound paths use the matching `__bte-<mod>__/` root.
- Prototypes, mod settings, and custom locale sections: `bte-<name>`. SPACELAB uses `bte-<thing>` for gameplay prototypes, such as `bte-growth-facility`, and `bte-spacelab-growth` for its recipe category; its items and recipes use Space Age's own item subgroups. Warp Drive uses `bte-warp-drive*`, `bte-theoretical-warp-drive`, and `bte-practical-warp-drive`.
- GUI element names: `bte_<name>`, such as `bte_warp_drive_window`.
- Test helper mods: `bte-<mod>-*-test`; load-order helpers keep a leading `aaa-`.

All mods in this repository share the prefix, so a new name must also be unique across every mod here. Vanilla and Space Age names referenced by a recipe or override, such as `uranium-ore`, stay unprefixed. Keep names stable once published; renaming breaks existing saves without migrations.

## Mod Independence

- Every mod requires only `base >= 2.1.0` and `space-age >= 2.1.0`. Read each mod's current version from its own `info.json` rather than hard-coding it.
- Every mod must load, run, and pass validation on its own.
- Cross-mod integration is optional only (`? <mod>` dependencies) and must never become a required runtime dependency. Prefer detecting capabilities, such as whether a recipe can run in space, over checking mod names.
- Mods are packaged in isolation and cannot reference each other's files (`__bte-spacelab__/...` from Warp Drive, or the reverse) or share Lua code. Duplicate small helpers instead of adding a shared library mod.

## References

- Factorio data: `/Applications/factorio.app/Contents/data`, or the Steam app under `~/Library/Application Support/Steam/steamapps/common/Factorio/factorio.app/Contents/data`.
- Factorio API docs: `/Applications/factorio.app/Contents/doc-html`, matching the installed version; `doc-html/runtime-api.json` and `prototype-api.json` are the same docs in searchable form. Online: <https://lua-api.factorio.com/latest/>.
- Vanilla prototype source: `/Applications/factorio.app/Contents/data` locally, or <https://github.com/wube/factorio-data>. GUI styles are in `data/core/prototypes/style.lua`, utility sprites in `utility-sprites.lua`.
- Use Space Exploration as a design reference only, never as a runtime dependency. Local source root: `~/work/other/factorio-space-exploration`. The SE Growth Facility prototype is `space-exploration_0.7.57/prototypes/phase-1/entity/growth-facility.lua`; related graphics are under `space-exploration-graphics-3_0.7.3/graphics/entity/growth-facility/` and `space-exploration-graphics_0.7.6/graphics/icons/` / `graphics/technology/`.
- Use mature mods as design evidence, not templates. Krastorio 2 supports a small composition root and paired feature/GUI modules; Space Exploration's custom dispatcher, globals, and migration framework are not justified at these mods' scale.

## Factorio 2.1 Prototype Rules

- Recipes use `categories = {"..."}`, not the old `category` field.
- `type = "item"` ingredients/results may refer to item-like prototype types. Yumako, Jellynut, and Bioflux are capsules, so guards must not check only `data.raw.item`.
- Science packs are item prototypes on this installation; helper code checks items before tools.
- Multi-output recipes need explicit `icon`, `icons`, or `main_product`. Keep explicit layered icons for multi-output recipes and use `main_product` for ordinary single-output recipes.
- Use `independent_probability`, not the old `probability`, for probabilistic products.
- Set `allow_productivity = true` explicitly on production recipes intended to support productivity.
- Use explicit sound definitions rather than undefined globals such as `sounds.machine_open` or `sounds.machine_close`.
- Runtime tinting is multiplicative. Strongly colored source sprites may not tint to the requested hue; prefer neutral source art for colorized icons.
- Validate resolved `data.raw`; source inspection alone does not catch prototype normalization or changes from other installed mods.
- Keep prototype code in feature-sized files. Duplicate constants across data and runtime stages when sharing them would couple incompatible Factorio load phases.

## Factorio Runtime and GUI Behaviour

Facts found the hard way in this repository. Most are not in the API docs; each names how it was established.

- `LuaSurface.create_trivial_smoke` creates nothing where no player can see the position at that moment, so smoke started off screen never appears even after it would grow into view (Warp Drive activation rings, seen in game). Effects that must show wherever the player looks use `LuaRendering` objects updated by script instead (`warp-drive/scripts/shockwaves.lua`). Particles may be culled the same way; that is untested.
- `on_tick` runs at the start of a tick, before entity updates, and the frame is drawn after them. Something the engine spawns during a tick is drawn for that frame before any script can remove it; a 10-tick handler leaves it on screen for up to ten frames (Warp Drive asteroid clearing).
- There is no runtime API to stop a space platform spawning asteroids. During travel they appeared on a line about 70 tiles ahead of the foundation's leading edge (headless probe, small platform). The space background also draws faint decorative asteroids that are not entities and that scripts cannot remove; do not mistake them for survivors in screenshots.
- `LuaRendering` objects can be kept in `storage`. `x_scale`/`y_scale` multiply the animation prototype's own `scale`. Additive objects take colours premultiplied by alpha, and a colour channel above 1 is read as 0–255.
- `LuaSurface.execute_lightning` rejects space platform surfaces; create the lightning entity directly (`warp-drive/scripts/warp.lua`).
- Each mod has its own `storage`, so another mod reads a mod's state only through its remote interface. Handlers of a mod that depends on another run after the other mod's handlers for the same event.
- GUI: assigning `element.style = "name"` resets every custom style property set on the element, such as `width` and `single_line`; set them again afterwards. Frames reject `horizontal_spacing`; put an inner flow in the frame. `entity-preview` draws only the entity's own sprites, never `LuaRendering` overlays; a small `camera` element shows the live building.
- Ratios built from fixed increments can land just below a step edge (`0.45 * 20 = 8.999...`); add a small epsilon before `math.floor` when picking a step from them.
- GitHub's README math renderer rejects `\operatorname`; use `\mathrm{...}`.

## SPACELAB Constraints

- Load science-pack surface overrides through `data-final-fixes.lua` so they run after other data-stage changes.
- Overrides must mutate existing vanilla recipes rather than add duplicate recipes or crafting machines.
- Growth Facility circuit connector data and wire distance are copied from the Space Age Cryogenic Plant.
- Each growth recipe owns one `crafting_machine_tint` channel (Yumako primary, Jellynut secondary, Biter egg tertiary, Pentapod egg quaternary), set opaque white while the other three are transparent. The Growth Facility's matching `specimens-<recipe>` overlay, its tinted copies of the shared `fluid`, `glow-vat-bottom`, and `glow-vat-top` overlays, and its recipe light use that channel, so one building shows only the running recipe's contents. The vat glows are drawn before the specimens, so the light shows them as silhouettes instead of washing them out. A new growth recipe needs a free channel; there are only four. Fluid colours are duplicated between `spacelab/prototypes/entities.lua` and the model's `VARIANT_COLORS`.
- The Growth Facility item icon `graphics/icons/growth-facility.png` (a 120x64 strip with custom mipmaps) is generated from the simplified `tools/sprites/models/growth-facility-icon.js`; re-export with `node render.mjs growth-facility-icon --export`. The main layer of the Growth Facility technology icon, `graphics/technology/growth-facility.png` (256 px), renders the same model through `growth-facility-technology.js`; re-export with `node render.mjs growth-facility-technology --export`.
- Growth Facility building sheets in `graphics/entity/growth-facility/` are generated; change `tools/sprites/models/growth-facility.js` and re-export with `node render.mjs growth-facility --export` instead of editing the PNG or `.lua` files.

## Warp Drive Constraints

- Building sheets in `graphics/entity/warp-drive/` are generated; change `tools/sprites/models/warp-drive.js` and re-export with `node render.mjs warp-drive --export` instead of editing the PNG or `.lua` files. The item icon `graphics/icons/warp-drive.png` and technology icon `graphics/technology/warp-drive.png` come from `warp-drive-icon.js` and `warp-drive-technology.js`; re-export with `node render.mjs warp-drive-icon warp-drive-technology --export`.
- Warp field effects in `graphics/entity/warp-field/` (the activation shockwave ring, the lightning cloud, the background anomaly shapes, and the subspace streaks) are generated from `tools/sprites/models/warp-field.js`, which draws only additive layers; re-export with `node render.mjs warp-field --export`.
- The model's state layers (`interior-<state>`, `glow-<state>`) map one-to-one to the `bte-warp-drive-<state>-interior` and `-glow` animation prototypes. Frame counts are duplicated in `prototypes/entities.lua` (`overlay_frames`) and `scripts/visuals.lua` (`STATES`), and playback speeds assume the model's 32-frame loop lasts 64 ticks.
- The circuit wire points in `prototypes/entities.lua` are the model's terminal insulator tips; move them with the terminal.

Round parts of both buildings (tanks, dais, caps, rings, and the activation shockwave) are squashed front to back by `ROUND_DEPTH` (0.78), duplicated in `growth-facility.js`, `warp-drive.js`, `warp-field.js`, and `warp-drive/scripts/shockwaves.lua` (which sweeps asteroids along the ring's oval): the renderer keeps ground tiles square to match the game grid, which would otherwise draw flat circles as circles rather than the ovals vanilla art shows.

## Generated Assets

Every image and sound the mods ship, and every README image, is generated by a script in this repository; edit the generator, never the output. Generators are deterministic, so rerunning one over unchanged sources leaves `git status` clean, and any difference means the committed output is stale.

| Output | Generator | Regenerate |
| --- | --- | --- |
| `spacelab/graphics/entity/growth-facility/` | `tools/sprites/models/growth-facility.js` | `node render.mjs growth-facility --export` |
| `spacelab/graphics/icons/growth-facility.png` | `tools/sprites/models/growth-facility-icon.js` | `node render.mjs growth-facility-icon --export` |
| `spacelab/graphics/technology/growth-facility.png` (main layer) | `tools/sprites/models/growth-facility-technology.js` | `node render.mjs growth-facility-technology --export` |
| `warp-drive/graphics/entity/warp-drive/` | `tools/sprites/models/warp-drive.js` | `node render.mjs warp-drive --export` |
| `warp-drive/graphics/entity/warp-field/` (shockwave, lightning cloud, anomalies, streaks) | `tools/sprites/models/warp-field.js` | `node render.mjs warp-field --export` |
| `warp-drive/graphics/icons/warp-drive.png`, `warp-drive/graphics/technology/warp-drive.png` | `tools/sprites/models/warp-drive-icon.js`, `warp-drive-technology.js` | `node render.mjs warp-drive-icon warp-drive-technology --export` |
| `warp-drive/resources/audio/*.ogg` | `warp-drive/resources/audio/generate.py` (see `warp-drive/AUDIO.md`) | `python3 warp-drive/resources/audio/generate.py [--only NAME...]` |
| `<mod>/docs/*.gif` | `tools/sprites/gif.mjs`, from the model's preview | `node render.mjs <model> && node gif.mjs <model> --out=../../<mod>/docs` |
| `<mod>/docs/icons/` | `tools/readme-icons.py`, from the game and the mods | `python3 tools/readme-icons.py` |

`node` commands run from `tools/sprites/` after `npm install`; `node render.mjs --export` alone re-exports every model. Sprite rendering needs Chrome, GIFs need `ffmpeg` and `gifsicle`, audio needs `ffmpeg`, and README icons need Factorio.

## Runtime Architecture

- Keep `control.lua` as the composition root. Organize runtime modules by feature ownership, not one file per helper.
- Keep direct, filtered `script.on_event` registrations unless multiple independent listeners create a concrete need for dispatch infrastructure. Do not add a custom event bus or framework for the current feature count.
- Keep persistent state under Factorio `storage`. Runtime modules must not retain mutable game state in module locals or store non-serializable closures.
- Register handlers at module load. Initialize stored state from lifecycle or event paths, and invalidate prototype-derived caches on configuration changes.
- Keep broad surface scans out of frequent updates such as Warp Drive's 10-tick drive loop. Companion adoption and orphan cleanup belong to initialization, configuration changes, registration, or explicit repair paths.
- Prefer small feature-owned APIs over generic utilities, classes, repositories, dependency injection, or a global-module framework.
- Keep Warp Drive companion creation explicit while animation, wiring, detector, charge, and support behavior differ. Share only lifecycle operations with identical invariants.

## Code Comments

- Add concise comments to opaque helpers and non-obvious code paths that explain why they exist and what invariant they preserve, not merely what each statement does.
- Document Factorio-specific API workarounds at the point of use, including relevant units, tick timing, and why the straightforward implementation is incorrect.
- Prefer a short function-level comment when understanding a helper would otherwise require tracing its callers and related state fields.

## Refactoring

- Add focused regression coverage before moving behavior across modules.
- Preserve Factorio-specific integration tests for API units, event order, electrical networks, migration, and serialization; do not replace them solely with mocked tests.
- Optimize measured scans and prototype walks. Profile before adding indexes, caches, or changing update cadences.
- Keep migration paths until supported saves cannot contain their legacy prototypes or stored fields.

## Build

The user mod directory is `~/Library/Application Support/factorio/mods`. Set `FACTORIO_MODS_DIR` to override the destination.

```sh
./make.sh                 # build and install every mod
./make.sh spacelab        # build and install one mod, by directory name
./make.sh warp-drive spacelab
```

For each mod, `make.sh` reads the name and version from that mod's `info.json`, creates the required `<name>_<version>` top-level zip directory, excludes `tests/`, `docs/`, `.git`, `.claude`, `.DS_Store`, and ZIPs, and installs the archive.

## Validation

### Prototype Tests

After every prototype change, run:

```sh
./tests/run-prototype-tests.sh
```

It dumps resolved prototypes (`--dump-data`) and their displayed names and descriptions (`--dump-prototype-locale`) for vanilla Space Age, each mod alone, and all mods together, using temporary mod and write-data directories so installed mods and `script-output` are untouched. Each mod's `tests/prototypes.py` asserts the README's player-facing values: recipes, results and probabilities, recipe categories, technology costs, prerequisites and unlocks, building stats, weights, surface conditions, and vanilla overrides compared against the unmodded baseline. Every `bte-` prototype must also have a name that resolves, so no "Unknown key" reaches the game. Loading each mod alone also verifies that no mod depends on another.

`README.md` remains the source of truth. When gameplay changes, update the mod's README and its `tests/prototypes.py` in the same change; a failing prototype test means one of them is out of date. Add expectations for every new player-facing prototype. Use `FACTORIO_BIN` to override the Factorio executable and `KEEP_TEST_ARTIFACTS=1` to keep dumps and logs.

### Manual Dump Inspection

For fields the prototype tests do not cover, or to check interaction with the user's other installed mods, dump with the standalone Factorio installation:

```sh
"/Applications/factorio.app/Contents/MacOS/factorio" \
  --mod-directory "$HOME/Library/Application Support/factorio/mods" \
  --dump-data
```

Fall back to the Steam binary when necessary:

```sh
"$HOME/Library/Application Support/Steam/steamapps/common/Factorio/factorio.app/Contents/MacOS/factorio" \
  --mod-directory "$HOME/Library/Application Support/factorio/mods" \
  --dump-data
```

The dump is written to `~/Library/Application Support/factorio/script-output/data-raw-dump.json`. When inspecting manually:

1. Build the changed mods with `./make.sh`.
2. Confirm the log loads each changed mod's `data.lua` (and `data-final-fixes.lua` when applicable) at its current version and exits successfully.
3. Assert the exact resolved fields changed by the task that the prototype tests do not cover, such as icons, module effects, productivity, fluid box details, sounds, and graphics.
4. Mention unrelated user mods loaded from the shared mod directory because they can alter resolved prototypes.

Run `git diff --check` before finishing documentation or code changes.

### Warp Drive Runtime Tests

`--dump-data` does not load `control.lua`. After Warp Drive prototype or runtime changes, also run the runtime suite (prototype tests above cover only data-stage facts):

```sh
./warp-drive/tests/run-runtime-tests.sh
```

The suite builds a temporary mod set and verifies:

- Published ZIP contents and basic `control.lua` initialization
- Platform placement, companion lifecycle, power, movement, cooldown, and relocation
- Runtime API assumptions used by `control.lua`
- Local and relay research branches with absolute multiplier checks

Use `FACTORIO_BIN` to override `/Applications/factorio.app/Contents/MacOS/factorio`. Set `KEEP_TEST_ARTIFACTS=1` to retain temporary saves, mods, and logs.

Test helpers live under `warp-drive/tests/mods/` and must never enter the published ZIP. Do not commit generated saves, logs, mod directories, or ZIPs.

Runtime assertions use `error("WARP_TEST_FAIL: ...")`; emit `log("WARP_TEST_PASS: ...")` only after all checks pass. Recreate saves after helper changes because mod scripts are stored in saves; the runner does this automatically.

Headless runs (`--benchmark`) have no player, so GUI code and anything that depends on what a player sees, such as smoke culling, are only exercised in the visible game. To probe runtime state headlessly, add a throwaway helper mod named `bte-warp-drive-runtime-test` so the drive registers its test remote interface, and log from its `on_tick`. Standalone Lua 5.5 `luac -p` is a quick syntax check, but it rejects assigning to `_`, which Factorio's Lua accepts.

Scripted tests do not replace interactive checks for GUI behavior, visuals, natural travel direction and speed, real brownouts, robots and ghosts, asteroid removal, or wire geometry.
