# Warp Drive: Runtime Tests

`--dump-data` does not load `control.lua`, so after Warp Drive prototype or runtime changes also run the runtime suite (the prototype tests cover only data-stage facts):

```sh
./warp-drive/tests/run-runtime-tests.sh
```

Use `FACTORIO_BIN` to override `/Applications/factorio.app/Contents/MacOS/factorio`. Factorio runs through `tests/factorio.sh` (see `AGENTS.md`), so each case is the package and its helper mods added to the same base save. Set `KEEP_TEST_ARTIFACTS=1` to keep the temporary mods and logs.

## What it verifies

The suite builds a temporary mod set and checks:

- published ZIP contents and basic `control.lua` initialization;
- platform placement, companion lifecycle, power, movement, cooldown, and relocation;
- runtime API assumptions used by `control.lua`;
- local and relay research branches with absolute multiplier checks.

## Writing tests

- Test helpers live under `tests/mods/` and must never enter the published ZIP. Do not commit generated saves, logs, mod directories, or ZIPs.
- Runtime assertions use `error("WARP_TEST_FAIL: ...")`; emit `log("WARP_TEST_PASS: ...")` only after all checks pass.
- Recreate saves after helper changes, because mod scripts are stored in saves; the runner does this automatically.
- To probe runtime state headlessly, add a throwaway helper mod named `bte-warp-drive-runtime-test` so the drive registers its test remote interface, and log from its `on_tick`.
- Standalone Lua 5.5 `luac -p` is a quick syntax check, but it rejects assigning to `_`, which Factorio's Lua accepts.

## Not covered

Headless runs (`--benchmark`) have no player, so GUI code and anything that depends on what a player sees, such as smoke culling, are only exercised in the visible game. Scripted tests do not replace interactive checks for GUI behaviour, visuals, natural travel direction and speed, real brownouts, robots and ghosts, asteroid removal, or wire geometry.
