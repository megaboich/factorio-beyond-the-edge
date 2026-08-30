# Warp Drive Development Guide

## Documentation Roles

- `README.md`: authoritative player-facing mechanics, recipes, costs, balance, dependencies, and attribution.
- `BUILDING.md`: technical reference only for composite-entity composition, ownership, electrical lifecycle, wiring, and rendering.
- `AUDIO.md`: technical reference for sound assets, synthesis, runtime playback, scheduling state, and regeneration.
- `PLAN.md`: unresolved decisions, validation, and deferred work only.

## Dependencies

- Required: `base >= 2.1.0` and `space-age >= 2.1.0`.
- Optional: `spacelab >= 0.1.0`; integration must not make it a runtime dependency.
- Local Factorio data and API docs: `/Applications/factorio.app/Contents/data` and `/Applications/factorio.app/Contents/doc-html`.

## Code Comments

- Add concise comments to opaque helpers and non-obvious code paths that explain why they exist and what invariant they preserve, not merely what each statement does.
- Document Factorio-specific API workarounds at the point of use, including relevant units, tick timing, and why the straightforward implementation is incorrect.
- Prefer a short function-level comment when understanding a helper would otherwise require tracing its callers and related state fields.

## Runtime Architecture

- Keep `control.lua` as the composition root as runtime modules are extracted. Organize modules by feature ownership, not one file per helper.
- Keep direct, filtered `script.on_event` registrations unless multiple independent listeners create a concrete need for dispatch infrastructure. Do not add a custom event bus or framework for the current feature count.
- Keep persistent state under Factorio `storage`. Runtime modules must not retain mutable game state in module locals or store non-serializable closures.
- Register handlers at module load. Initialize stored state from lifecycle or event paths, and invalidate prototype-derived caches on configuration changes.
- Keep broad surface scans out of the 10-tick drive update. Companion adoption and orphan cleanup belong to initialization, configuration changes, registration, or explicit repair paths.
- Prefer small feature-owned APIs over generic utilities, classes, repositories, dependency injection, or a global-module framework.
- Keep companion creation explicit while animation, wiring, detector, charge, and support behavior differ. Share only lifecycle operations with identical invariants.
- Keep prototype code in the existing feature-sized files. Duplicate constants across data and runtime stages when sharing them would couple incompatible Factorio load phases.
- Use mature mods as design evidence, not templates. Krastorio 2 supports a small composition root and paired feature/GUI modules; Space Exploration's custom dispatcher, globals, and migration framework are not justified at this mod's scale.

## Refactoring

- Add focused regression coverage before moving behavior across modules.
- Preserve Factorio-specific integration tests for API units, event order, electrical networks, migration, and serialization; do not replace them solely with mocked tests.
- Optimize measured scans and prototype walks. Profile before adding indexes, caches, or changing the 10-tick update cadence.
- Keep migration paths until supported saves cannot contain their legacy prototypes or stored fields.

## Validation

After prototype changes, run `./make.sh`, dump and inspect resolved Factorio prototypes, run `./tests/run-runtime-tests.sh`, and run `git diff --check`.

`--dump-data` does not load `control.lua`. The runtime suite builds a temporary mod set and verifies:

- Published ZIP contents and basic `control.lua` initialization
- Platform placement, companion lifecycle, power, movement, cooldown, and relocation
- Runtime API assumptions used by `control.lua`
- Local and relay research branches with absolute multiplier checks

Use `FACTORIO_BIN` to override `/Applications/factorio.app/Contents/MacOS/factorio`. Set `KEEP_TEST_ARTIFACTS=1` to retain temporary saves, mods, and logs.

Test helpers live under `tests/mods/` and must never enter the published ZIP. Do not commit generated saves, logs, mod directories, or ZIPs.

Runtime assertions use `error("WARP_TEST_FAIL: ...")`; emit `log("WARP_TEST_PASS: ...")` only after all checks pass. Recreate saves after helper changes because mod scripts are stored in saves; the runner does this automatically.

Scripted tests do not replace interactive checks for GUI behavior, visuals, natural travel direction and speed, real brownouts, robots and ghosts, asteroid removal, or wire geometry.
