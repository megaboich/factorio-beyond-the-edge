# Warp Drive Plan

This file tracks unresolved decisions and validation only. Implemented behavior belongs in `README.md`; composite-entity details belong in `BUILDING.md`.

## Performance Validation

- Profile `force_lab_metrics` across a large multi-surface save before deciding whether `scripts/research.lua` needs a lab index.
- Benchmark the 10-tick drive loop with many forces/platforms before and after module extraction; reject a split that introduces broad per-tick scans.

## Balance Decisions

- Recalibrate the `1,000,000,000`-unit Practical research cost after measuring completion times.
- Confirm the `20` to `10,000 particles/s` density curve makes deep travel rewarding without making the final route mandatory.
- Decide whether `20 particles/s` near the inner planets is useful enough.
- Validate the `1 GW` detector ceiling and exact script-owned reserve scaling on very heavy platforms.
- Decide whether relay research needs a transmission penalty.

## Release Validation

- Test natural travel through departure, reversal, arrival, and endpoint margins.
- Measure native route movement and confirm Warp-1, Warp-10, above-Warp-10, and two-second level transitions.
- Test support-power fallback, brownouts, disconnection, exit, and the 10-second lockout.
- Compare detector progress with labs using quality, modules, beacons, force bonuses, productivity, and optional SPACELAB facilities.
- Test player, robot, platform, and ghost placement plus duplicate refunds.
- Verify GUI layout, values, controls, scrolling, and close behavior.
- Verify asteroid removal during warp.
- Inspect animation, emission, shadow, footprint, and selection box.
- Inspect both circuit-wire colors for attachment, sag, shadows, and crossing.

## Deferred Features

- Validated SPACELAB Growth Facility amplification
- Remote interfaces for third-party integrations
