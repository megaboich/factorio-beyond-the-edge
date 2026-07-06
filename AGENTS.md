For mode design best practices use space exploration mod as a reference. Sources can be found in the following directory: ~/work/other/factorio-space-exploration.

## Space Exploration reference map

Use `~/work/other/factorio-space-exploration` as the local reference root.

### Growth Facility / Zero-G growth facility

The Space Exploration building players know is `Growth Facility`, prototype name `se-space-growth-facility`.

- **Entity prototype:** `space-exploration_0.7.57/prototypes/phase-1/entity/growth-facility.lua`
  - `type = "assembling-machine"`
  - `name = data_util.mod_prefix .. "space-growth-facility"`
  - `crafting_categories = {"space-growth"}`
  - `crafting_speed = 4`
  - `energy_usage = "4000kW"`
  - `module_slots = 4`
  - `allowed_effects = data_util.all_effects_except("productivity")`
  - size: `collision_box = {{-4.3, -4.3}, {4.3, 4.3}}`, `selection_box = {{-4.5, -4.5}, {4.5, 4.5}}`
  - fluids: original SE reference uses 6 input boxes and 6 output boxes around the 9x9 footprint; local `spacelab-growth-facility` uses 3 west/east `input-output` pass-through input lanes at y offsets `-2`, `0`, and `2` so Growth Facilities can be chained in rows with shared liquid buses.
- **Main entity graphics:** `space-exploration-graphics-3_0.7.3/graphics/entity/growth-facility/growth-facility.png`
  - referenced as `__space-exploration-graphics-3__/graphics/entity/growth-facility/growth-facility.png`
  - sheet settings: `width = 4032/7`, `height = 3360/5`, `frame_count = 32`, `line_length = 7`, `shift = util.by_pixel(0, -24)`, `scale = 0.5`
- **Shadow graphics:** `space-exploration-graphics-3_0.7.3/graphics/entity/growth-facility/growth-facility-shadow.png`
  - referenced as `__space-exploration-graphics-3__/graphics/entity/growth-facility/growth-facility-shadow.png`
  - sheet settings: `width = 618`, `height = 570`, `frame_count = 1`, `repeat_count = 32`, `shift = util.by_pixel(8, 2)`, `scale = 0.5`
- **Icon:** `space-exploration-graphics_0.7.6/graphics/icons/growth-facility.png`
- **Technology icon:** `space-exploration-graphics_0.7.6/graphics/technology/growth-facility.png`
- **Item prototype:** `space-exploration_0.7.57/prototypes/phase-1/item/structures.lua`, item `se-space-growth-facility`
- **Building recipe:** `space-exploration_0.7.57/prototypes/phase-1/recipe/structures.lua`, recipe `se-space-growth-facility`
- **Growth recipes:** `space-exploration_0.7.57/prototypes/phase-1/recipe/growth-facility.lua`, category `space-growth`
- **Technology unlock:** `space-exploration_0.7.57/prototypes/phase-1/technology/technology.lua`, technology `se-space-growth-facility`
- **Recipe category:** `space-exploration_0.7.57/prototypes/phase-1/categories.lua`, category `space-growth`
- **English locale:** `space-exploration_0.7.57/locale/en/strings.cfg`
  - entity/item label: `se-space-growth-facility=Growth Facility`
  - description mentions controlled biological growth conditions, including micro-gravity vats and high-G centrifuges.

### Custom ore/resource pattern

Space Exploration custom ores are useful references for dependency-free local resource definitions.

- **Resource prototypes:** `space-exploration_0.7.57/prototypes/phase-1/entity/resources.lua`
  - examples: `se-beryllium-ore`, `se-holmium-ore`, `se-iridium-ore`, `se-naquium-ore`
  - pattern: `type = "resource"`, matching mineable item result, 8-stage sprite sheet, `stage_counts`, `map_color`, and an `autoplace` control
- **Item prototypes:** `space-exploration_0.7.57/prototypes/phase-1/item/resources.lua`
  - ore items use a primary icon plus optional `pictures` variants
- **Autoplace:** `space-exploration_0.7.57/prototypes/phase-1/entity/resource-autoplace.lua`
  - SE has custom noise helpers, but this mod should use base `resource-autoplace` instead of depending on SE
- **Current local Flurolite placeholder graphics:** copied from SE beryllium ore graphics and renamed under `__spacelab__`
  - entity sheet: `graphics/entity/flurolite/flurolite.png`
  - icons: `graphics/icons/flurolite.png`, `graphics/icons/flurolite-01.png`, `graphics/icons/flurolite-02.png`, `graphics/icons/flurolite-03.png`

## Local build and install

This machine has Factorio installed in these locations:

- `/Applications/factorio.app`
- `~/Library/Application Support/Steam/steamapps/common/Factorio/factorio.app`

Factorio's user mod directory on this machine is:

- `~/Library/Application Support/factorio/mods`

The game expects a zipped mod to contain a top-level directory named `<mod-name>_<version>`, where both values come from `info.json`. For this mod that currently means `spacelab_0.1.0`.

From the repository root, build and install the mod zip with:

```sh
./make.sh
```

`make.sh` reads `info.json`, stages the required top-level `<mod-name>_<version>` directory in a temporary folder, zips it, and writes the zip to `~/Library/Application Support/factorio/mods`. Override the install destination by setting `FACTORIO_MODS_DIR` before running the script.

After installing, launch Factorio and enable `SPACELAB` in the in-game Mods menu. Restart the game when Factorio asks for it.

## Factorio 2.1 implementation notes

- **Recipe categories:** Factorio 2.1 merged `category` and `additional_categories` into `categories`; recipe prototypes must use `categories = {"..."}` instead of `category = "..."`.
- **Recipe guards:** Local recipe helper code should validate `recipe.categories` against `data.raw["recipe-category"]`, while still allowing built-in `crafting` and `advanced-crafting`. Ingredient/result guards for `type = "item"` must check item-like prototype types, not only `data.raw.item`; Space Age uses `capsule` prototypes for `yumako`, `jellynut`, and `bioflux`.
- **Science packs:** Factorio 2.1 science packs are `item` prototypes on this install; technology helper code should check `data.raw.item` before falling back to `data.raw.tool`.
- **Recipe icons:** Multi-output recipes need an explicit `icon`, `icons`, or `main_product`; otherwise Factorio 2.1 can fail with `Key "icon" not found`. For this small mod, prefer explicit per-recipe `icons = {...}` lists over generic composition. Keep only a small helper such as `recipe_icon_layer(product, scale, shift)` for prototype icon lookup and layer positioning. Assign `main_product` for ordinary single-output recipes. Low-probability side products such as Uranium Ore can remain in `results` but be omitted from the explicit icon list to prevent icon overbloat.
- **Product probabilities:** Factorio 2.1 renamed product prototype `probability` to `independent_probability`; probabilistic recipe results should use `independent_probability = ...`.
- **Productivity:** New SPACELAB production recipes that should accept productivity modules must set `allow_productivity = true` explicitly. This includes asteroid processing, Growth Facility growth/incubation, ammonia extraction, and Flurolite condensation recipes.
- **Spoilage preservation:** Recipes that output spoilable biological products can use `preserve_products_in_machine_output = true` to match captive biter spawner behavior: products do not spoil while still inside the machine output inventory.
- **Recipe tints:** Recipe-specific machine coloring uses recipe `crafting_machine_tint = {primary = ..., secondary = ...}` plus entity `working_visualisations` entries with `apply_recipe_tint = "primary"` / `"secondary"`. Plain light-only visualisations may be too subtle; visible additive glow overlays work better.
- **Biotech glow overlay:** A good Space Age-compatible organic glow source is `__space-age__/graphics/entity/biolab/biolab-lights.png` with `draw_as_glow = true` and `blend_mode = "additive"`. The current Growth Facility uses it as recipe-tinted center overlays, with `scale = 1.08` for primary and `scale = 0.57` for secondary.
- **Circuit connectors:** Because `space-age` is a required dependency, Growth Facility can copy `circuit_connector` and `circuit_wire_max_distance` directly from `data.raw["assembling-machine"]["cryogenic-plant"]`; no base assembler fallback is needed.
- **Fluid pass-through layouts:** For large buildings that should chain in rows, use `production_type = "input-output"` fluid boxes on opposite sides at matching offsets. The local Growth Facility uses west/east pass-through lanes at y offsets `-2`, `0`, and `2`.
- **Module slots/effects:** Local Growth Facility intentionally differs from the SE reference by using 8 module slots and `allowed_effects = {"consumption", "speed", "pollution", "quality"}`.
- **Sound globals:** Do not use `sounds.machine_open` or `sounds.machine_close` as globals in this mod's data stage. Use explicit base sound definitions such as `{filename = "__base__/sound/machine-open.ogg", volume = 0.5}` and `{filename = "__base__/sound/machine-close.ogg", volume = 0.5}`.
- **Validation workflow:** After prototype changes, build/install with `./make.sh`, run Factorio `--dump-data` using the local mods directory, and inspect `~/Library/Application Support/factorio/script-output/data-raw-dump.json` to verify final prototype fields such as ingredients, results, `icons`, `module_slots`, circuit connectors, recipe tints, and productivity flags.