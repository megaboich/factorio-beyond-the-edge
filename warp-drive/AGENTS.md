# Warp Drive Development Guide

## Documentation Roles

- `README.md`: authoritative player-facing mechanics, recipes, costs, balance, dependencies, and attribution.
- `BUILDING.md`: technical reference only for composite-entity composition, ownership, electrical lifecycle, wiring, rendering, and migration.
- `PLAN.md`: unresolved decisions, validation, and deferred work only.

## Dependencies

- Required: `base >= 2.1.0` and `space-age >= 2.1.0`.
- Optional: `spacelab >= 0.1.0`; integration must not make it a runtime dependency.
- Local Factorio data and API docs: `/Applications/factorio.app/Contents/data` and `/Applications/factorio.app/Contents/doc-html`.

## Validation

After prototype changes, run `./make.sh`, dump and inspect resolved Factorio prototypes, run `./tests/run-runtime-tests.sh`, and run `git diff --check`.

`--dump-data` does not load `control.lua`. The runtime suite builds a temporary mod set and verifies:

- Published ZIP contents and basic `control.lua` initialization
- Platform placement, companion lifecycle, power, movement, cooldown, and relocation
- Legacy replacement with health, direction, wiring, and companions preserved
- Runtime API assumptions used by `control.lua`
- Local and relay research branches with absolute multiplier checks

Use `FACTORIO_BIN` to override `/Applications/factorio.app/Contents/MacOS/factorio`. Set `KEEP_TEST_ARTIFACTS=1` to retain temporary saves, mods, and logs.

Test helpers live under `tests/mods/` and must never enter the published ZIP. Do not commit generated saves, logs, mod directories, or ZIPs.

Runtime assertions use `error("WARP_TEST_FAIL: ...")`; emit `log("WARP_TEST_PASS: ...")` only after all checks pass. Recreate saves after helper changes because mod scripts are stored in saves; the runner does this automatically.

Scripted tests do not replace interactive checks for GUI behavior, visuals, natural travel direction and speed, real brownouts, robots and ghosts, asteroid removal, or wire geometry.
