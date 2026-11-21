# Stargate: The Finished Gate

Maintainer reference for the finished gate: its entity, power, collision, and the companions that draw it. Player-facing figures are in the [README](../README.md); the power bank itself is in [docs/power.md](../../docs/power.md). Code: `scripts/gate.lua`, `prototypes/entities.lua`, `data-final-fixes.lua`.

## Entity and state

- The finished gate is an `assembling-machine` with the hidden no-op `bte-stargate-portal` recipe (no ingredients or results) as `fixed_recipe`, on a `void` energy source, which gives it the engine's circuit enable condition.
- `scripts/gate.lua` keeps `record.open` (opens on a full charge when on and `LuaGenericOnOffControlBehavior.disabled` is false, paired or unpaired; closes on either failing or the buffer running dry) and sets `disabled_by_script = not open`.
- The gate has no `minable` and is `not-deconstructable`, so it can only be destroyed.

## Power

- Its power is a hidden companion `electric-energy-interface`, `bte-stargate-capacitor`, spanning the footprint (empty collision mask) so any pole reaching the gate powers it. Active banks (`storage.active_gates`) are driven every tick by the shared power bank (`scripts/power_bank.lua`, see Mod Independence in `AGENTS.md` and `docs/power.md`). Once full and fed for five seconds, a gate enters steady-draw direct mode and leaves `storage.active_gates` (checked each second from the network statistics, `Gate.check_power`); switched-off gates zero their capacitor once, leak their stored charge in pure Lua, and leave `storage.active_gates` too once empty. The bank switches the interface to `secondary-input` so no accumulator storage shows for it, and keeps the charge in `record.bank`.
- The gate's figures are in its `bte-stargate-power` mod-data: `capacity` 10 GJ, `upkeep` 1 GW, `charge_rate` 1 GW, `refill` 200 MW. The runtime test shrinks the capacity to 0.3 GJ and the upkeep to 30 MW so the reserve lasts as long as the real gate's.
- The store leaks 0.5 % of its charge a second and takes in all that is drawn. A closed gate charges with no load at up to `charge_rate` plus a full store's leak (1.05 GW). Opening needs a full store and spends 80 % (`PowerBank.activate`, `ACTIVATION_SHARE`, the same for Warp Drive). An open gate's load is the upkeep, and it draws up to upkeep, leak, and `refill` (1.25 GW).
- A gate switched off or closed by its circuit stops charging unless `record.keep_charged` (the window's "Keep charged when deactivated").
- Its lights are red while it charges or while an open gate gets less than its upkeep (`Gate.short_of_power`).
- The bank's step rule was tuned with `stargate/tests/power-model.py`. The runtime test's `SHARE` case runs three gates beside a 300 MW load with 100 MW spare in the game (headless: load 99.97 % fed, gates about 80 % of the spare).

## Collision and the portal zone

- The gate's collision mask drops `player` and `is_object` (characters collide on both) so characters walk into the portal; rails still collide on `object`.
- `scripts/gate.lua` places hidden barrier entities over the machinery only (`BARRIERS`): `bte-stargate-side-block` over the west and east strips from 3 tiles out (capacitor banks, towers, housings, the ring's sides), `bte-stargate-cabinet-block` and `bte-stargate-rack-block` over the front corners. Everything else, the lanes through the ring and the floor in front and behind, is open.
- The barriers sit on their own `bte-stargate-barrier` collision layer, which `data-final-fixes.lua` adds to every `character`, `spider-leg`, `car` (cars and tanks), and `unit` whose collision mask includes `player` (leaving modded flying vehicles or characters free), so all ground travellers hit the machinery and pass through the lanes; a layer of their own keeps them off everything else. `tests/prototypes.py` checks the masks, the runtime test where characters, a car, a tank, and a biter can stand. The barriers have no `minable` and are `not-deconstructable` either.
- The portal zone triggers from either side: 3 tiles either side of the centre line (the whole gap between the side blocks, so nobody passes the ring's edge untriggered) and from 0.5 behind to 1.5 in front of the ring's plane, deeper than a fast runner covers between checks (`TRANSFER_TICKS`). Arrivals land 1.9 in front, clear of it.

## Drawing: companions and layers

Because people walk behind the ring, the finished gate's picture is split (`models/stargate.js`, `setVariant`):

- The `floor` layer (meshes flagged `userData.floor` in `floor()`) is the gate's `integration_patch` on the `floor` render layer, and the gate itself draws only its shadow.
- `main` (the floor cut out as an occluder) with `glow-lights` or `glow-lights-red` (the `alarm` variant) is `bte-stargate-body`, a hidden `simple-entity-with-owner` companion that `show_body` places on the ring's line, two tiles south of the centre, with graphics variation 1 (cyan) or 2 (red); station mode adds the `main-<mode>` and `glow-lights[-red]-<mode>` variations ([railway.md](railway.md)). Factorio sorts objects by position, so a character behind the ring is drawn under the whole ring, lights included, and one in front over it; on the gate itself, sorted a tile north-west of the centre, characters between that and the ring were drawn over it.
- Spidertron bodies are drawn on `under-elevated`, after every `object`, so the ring's upper arc (its upper half, above `TOP`, the ring's centre height `RING.cy`) is drawn again by a second companion, `bte-stargate-top`, on `elevated-object`, the way Space Age draws elevated rails (`elevated-rail-*` layers) and the trains on them: over spidertrons wherever they stand. Characters in front close enough to reach that height on screen are already in the portal zone.
- The `top` picture carries the arc's lights (`glow-lights-high`, `-red-high`), and the body's `glow-lights`/`-red` leave them out, so no light is drawn twice (`render.js` copies a source's clipping planes into its glow material for this). The lamps are baked dark and matte into `main` and `top`, so their colour comes only from the glow layers: red light added over a lamp baked cyan read white.
- The open portal's veil is split the same way (`glow-veil`, `glow-veil-high`) into two animated companions on the same spot, `bte-stargate-veil` (`object`) and `bte-stargate-veil-top` (`elevated-object`), which `show_veil` creates while the gate is open and removes when it closes, so legs and characters behind the ring are drawn under the veil and spidertron bodies under its upper part. While open, a steady `rendering.draw_light` lights the surroundings (`record.veil_light`).
- Opening first plays the portal forming (`glow-opening`, `-high`, 30 frames at 4 ticks, the last held 8 ticks to cover `Gate.update`'s 3-tick wait) as `bte-stargate-opening`/`-high` render animations on `object` and `elevated-object`, and closing plays `bte-stargate-closing`/`-high` (18 frames).
- `tools/sprites/stargate-showcase.html` (the interactive demo: phases, gate states, transfer, red lights, and the mod's sounds) draws the same layers and plays the same sheets.
- Earlier attempts (script-drawn render objects, lights through holes in the picture) gave mismatched light brightness and are gone.
