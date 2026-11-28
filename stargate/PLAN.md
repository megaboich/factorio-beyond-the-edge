# Beyond the Edge: Stargate — Remaining Plan & Future Scope

Single consolidated planning document for `bte-stargate` (replaces the former `VISION.md`, `PLAN.md`, and `docs/review-plan.md`).

All standalone mechanics — the three-technology progression (**Experimental Gates** → first random jump → **Controllable Stargate Jumps** → **Stargate Rail Transit**), solid-ground random landings, construction, adaptive power bank, reciprocal pairing, character/vehicle/enemy travel, and carriage-by-carriage train station transit — are implemented, tested, and documented in [README.md](README.md) and [`docs/`](docs/).

Only future sibling-mod integration and optional post-release evaluations remain below.

---

## 1. Homecoming Journey Integration Boundary (`S4`)

Owned jointly with [Homecoming Journey](../homecoming-journey/PLAN.md) when the campaign mod is implemented (`bte-stargate` stays standalone with zero hard dependencies on [Mechanoids](../mechanoids/PLAN.md), Warp Drive, Space Lab, or Homecoming Journey):

- **Versioned `remote` interface & custom events:**
  - Register campaign-owned ancient gate anchors and unrestored receivers by caller-owned stable ID (idempotent across reloads).
  - Configure campaign gate power profiles and locked links without reading or mutating `bte-stargate`'s private `storage`, locking out manual re-pairing on campaign-managed gates while still enforcing energy, collision, and train-transfer safety checks.
  - Support explicit one-shot prepaid return entitlements for unrestored campaign receivers.
  - Emit events / query hooks for completed construction, player transfer, and train transfer.
- **Ancient Fulgoran gate art (`tools/sprites/`):**
  - Separate 3D model and generated sprite sheets on the same `14x14` rail-aligned footprint for Homecoming Journey's ancient gate network.

---

## 2. Optional Standalone Evaluations (Uncommitted)

These are candidate future enhancements rather than settled promises:

- **Train dispatcher mods:** evaluate optional compatibility hooks for LTN and Project Cybersyn if needed beyond vanilla Factorio 2.0/2.1 train groups, `trains_limit`, and interrupts.
- **Multi-gate routing:** evaluate whether a station gate should ever address multiple destination gates via circuit signals (standalone gates currently keep one reciprocal partner by design).
- **Per-train energy cost:** evaluate whether sending a train should draw additional energy per carriage beyond keeping the sending gate open (`1 GW` upkeep); accepted trains currently always finish their trip once past the entry signal.
- **Interactive client spot checks:** multi-rider cutscene skipping, spidertron leg settling on crowded pads, and blueprint/cursor grid snapping in a live client window (automated screenshot probes are documented in [`docs/testing.md`](docs/testing.md#seeing-what-is-drawn)).
