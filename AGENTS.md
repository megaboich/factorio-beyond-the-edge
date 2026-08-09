# SPACELAB Development Guide

## Documentation Rule

Do not duplicate player-facing mechanics, recipes, yields, technology costs, balance values, or feature descriptions here. `README.md` is the single source of truth for gameplay information. Keep this file limited to development context not surfaced in `README.md`, and update the README whenever gameplay changes.

## Dependencies And References

- Required dependencies are `base >= 2.1.0` and `space-age >= 2.1.0`; read the current mod version from `info.json` rather than hard-coding it.
- Factorio data is available at `/Applications/factorio.app/Contents/data` and in the Steam app under `~/Library/Application Support/Steam/steamapps/common/Factorio/factorio.app/Contents/data`.
- Use Space Exploration as a design reference only. It is not a runtime dependency. Local source root: `~/work/other/factorio-space-exploration`.
- The relevant SE Growth Facility prototype is `space-exploration_0.7.57/prototypes/phase-1/entity/growth-facility.lua`.
- The relevant SE graphics are under `space-exploration-graphics-3_0.7.3/graphics/entity/growth-facility/` and `space-exploration-graphics_0.7.6/graphics/icons/` / `graphics/technology/`.

## Repository Map

- `data.lua`: loads categories, items, entities, recipes, and technologies.
- `data-final-fixes.lua`: applies intentional vanilla overrides after other data-stage changes.
- `prototypes/helpers.lua`: prototype guards, icon lookup, recipe registration, and technology helpers.
- `prototypes/categories.lua`: item group, subgroups, and custom recipe category.
- `prototypes/items.lua`: item prototypes.
- `prototypes/entities.lua`: Growth Facility assembling-machine prototype.
- `prototypes/recipes.lua`: recipe prototypes.
- `prototypes/technologies.lua`: technology prototypes.
- `prototypes/overrides.lua`: vanilla prototype overrides.
- `locale/en/strings.cfg`: English prototype names and descriptions.
- `README.md`: player-facing mechanics, exact recipes, technologies, balance, and asset attribution.
- `make.sh`: packages and installs the mod zip.

## Implementation Constraints

- Load science-pack surface overrides through `data-final-fixes.lua` so they run after other data-stage changes.
- Overrides must mutate existing vanilla recipes rather than add duplicate recipes or crafting machines.
- Growth Facility circuit connector data and wire distance are copied from the Space Age Cryogenic Plant.
- Recipe-specific Growth Facility lighting uses `crafting_machine_tint` with additive Biolab glow overlays.

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

## Build And Validation

The user mod directory is `~/Library/Application Support/factorio/mods`.

Build and install from the repository root:

```sh
./make.sh
```

`make.sh` reads the name and version from `info.json`, creates the required `<name>_<version>` top-level zip directory, and installs the archive. Set `FACTORIO_MODS_DIR` to override the destination.

Validate with the standalone Factorio installation:

```sh
"/Applications/factorio.app/Contents/MacOS/factorio" \
  --mod-directory "$HOME/Library/Application Support/factorio/mods" \
  --dump-data
```

Fallback to the Steam binary when necessary:

```sh
"$HOME/Library/Application Support/Steam/steamapps/common/Factorio/factorio.app/Contents/MacOS/factorio" \
  --mod-directory "$HOME/Library/Application Support/factorio/mods" \
  --dump-data
```

The dump is written to `~/Library/Application Support/factorio/script-output/data-raw-dump.json`. After every prototype change:

1. Confirm the log loads both `spacelab <version> (data.lua)` and, when applicable, `spacelab <version> (data-final-fixes.lua)` and exits successfully.
2. Assert the exact resolved fields changed by the task, including ingredients, results, icons, weights, module effects, surface conditions, probabilities, productivity, fluid boxes, and spoilage preservation as relevant.
3. Mention unrelated user mods loaded from the shared mod directory because they can alter resolved prototypes.
4. Run `git diff --check` before finishing documentation or code changes.
