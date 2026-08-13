# Warp Drive Development Guide

## Documentation Rule

`README.md` is the source of truth for implemented player-facing mechanics, recipes, technology costs, balance values, and asset attribution. `BUILDING.md` documents the Warp Drive's composite entity architecture, runtime lifecycle, and implementation invariants. `PLAN.md` tracks remaining validation and deferred work.

## Dependencies

- Required dependencies are `base >= 2.1.0` and `space-age >= 2.1.0`.
- `spacelab >= 0.1.0` is optional. Integration must not make SPACELAB a runtime requirement.
- Factorio data and API documentation are under `/Applications/factorio.app/Contents/data` and `/Applications/factorio.app/Contents/doc-html`.

## Validation

After prototype changes, run `./make.sh`, run Factorio with `--dump-data`, inspect the resolved prototypes, and run `git diff --check`.

### Scripted Runtime Testing

`--dump-data` does not load `control.lua`. The reproducible headless runtime suite is checked into `tests/` and runs with:

```sh
./tests/run-runtime-tests.sh
```

Set `FACTORIO_BIN` to override the default `/Applications/factorio.app/Contents/MacOS/factorio`. Set `KEEP_TEST_ARTIFACTS=1` to retain and print the temporary directory for debugging failed runs.

The runner performs these checks:

- Builds Warp Drive into a temporary mod directory.
- Verifies the distributable ZIP does not contain `tests/`.
- Creates a save with only Warp Drive and its required dependencies, then benchmarks 120 ticks to exercise `control.lua`, `on_init`, event registration, and periodic callbacks.
- Creates another save with the platform test helpers and benchmarks 700 ticks.
- Requires explicit `WARP_TEST_PASS` output from the scripted platform test.
- Creates a legacy-drive save, reloads it after adding the migration verifier, and checks entity replacement, preserved health, direction, circuit wiring, and companion creation.
- Removes all generated mod directories, saves, and logs unless `KEEP_TEST_ARTIFACTS=1` is set.

Test helper layout:

- `tests/mods/aaa-warp-drive-speed-test`: loads before Warp Drive and forces platform speed and pause state before Warp Drive's tick handler runs. Factorio's platform physics otherwise overwrites scripted speed each tick.
- `tests/mods/warp-drive-runtime-test`: loads after Warp Drive, creates the platform and entities, and performs assertions after Warp Drive handles raised build events and periodic updates.
- `tests/mods/warp-drive-migration-fixture`: creates a saved legacy drive with a circuit connection before the upgrade test.
- `tests/mods/warp-drive-migration-test`: triggers the configuration change and verifies the saved legacy drive migrated correctly.

The platform test creates a platform with `LuaForce.create_space_platform`, applies `space-platform-starter-pack`, lays foundation tiles, and places drives with `raise_built = true`. It verifies delayed hidden charge-buffer creation, duplicate-drive destruction, experimental detector cleanup and restoration, charge consumption, support-load creation and removal, distance advancement, power-loss exit, Practical research revocation, post-warp lockout, and relocation cleanup.

Use `error("WARP_TEST_FAIL: ...")` for assertions and emit `log("WARP_TEST_PASS: ...")` only after all assertions pass. Recreate the save after every helper-mod change because mod scripts are stored in the save; the checked-in runner does this automatically.

Keep helper source under `tests/`, but never add generated saves, logs, mod directories, or ZIPs to the repository. `make.sh` excludes the entire `tests/` directory from the published mod package.

Scripted tests complement, but do not replace, interactive checks for GUI behavior, visuals, naturally sampled travel direction and speed, powered brownouts, robots and ghosts, and actual asteroid removal.
