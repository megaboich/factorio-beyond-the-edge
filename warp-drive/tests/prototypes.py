"""Resolved-prototype expectations for Warp Drive. Values mirror warp-drive/README.md.

Runtime behavior is covered by run-runtime-tests.sh; this file checks only data-stage facts.
"""


def check(t):
    t.recipe("bte-warp-drive", time=120, category="crafting",
             ingredients=[("quantum-processor", 200), ("superconductor", 500), ("tungsten-plate", 1000),
                          ("carbon-fiber", 500), ("supercapacitor", 500)],
             results=[("bte-warp-drive", 1)])

    controller = t.prototype("constant-combinator", "bte-warp-drive-controller")
    if controller is not None:
        t.check("Warp Drive footprint", t.footprint(controller), (8, 8))
        t.check("Warp Drive is platform-only", controller.get("surface_conditions"),
                [{"property": "pressure", "min": 0, "max": 0}])
        t.check("Warp Drive mines into its item", controller.get("minable", {}).get("result"), "bte-warp-drive")
        t.check("Warp Drive name and description locale keys",
                [controller.get("localised_name"), controller.get("localised_description")],
                [["entity-name.bte-warp-drive"], ["entity-description.bte-warp-drive"]])
        check_graphics(t, controller)

    t.locale("bte-")

    t.technology("bte-theoretical-warp-drive", count=10000, time=120,
                 prerequisites=["promethium-science-pack"], unlocks=["bte-warp-drive"])
    t.technology("bte-practical-warp-drive", count=1000000000, time=120,
                 prerequisites=["bte-theoretical-warp-drive"])

    # The mod adds one building and no laboratories, science packs, or particle items.
    t.check("Warp Drive items", t.names("item", "bte-warp-drive"), ["bte-warp-drive"])
    t.check("Warp Drive laboratories", t.names("lab", "bte-"), [])
    t.check("Warp Drive science packs", t.names("tool", "bte-"), [])

    # Drive audio plays ship-wide on the game-effects slider, never the music ("ambient") slider.
    sounds = t.raw.get("sound", {})
    drive_sounds = t.names("sound", "bte-warp-drive-")
    t.check("Warp Drive sound count", len(drive_sounds), 44)
    t.check("Warp Drive sounds use the game-effects mixer",
            sorted({sounds[name].get("category") for name in drive_sounds}), ["game-effect"])

    # Warp lightning bolts strike 25 tiles south of their cloud, near the drive too.
    lightning = t.prototype("lightning", "bte-warp-drive-lightning")
    if lightning is not None:
        t.check("Warp lightning bolt height", lightning.get("source_offset"), [0, -25])
        t.check("Warp lightning is harmless", [lightning.get("damage"), lightning.get("energy")], [None, "0J"])
        t.check("Warp lightning cloud is the warp-field nebula",
                lightning["graphics_set"]["cloud_background"].get("filename"),
                "__bte-warp-drive__/graphics/entity/warp-field/warp-field-nebula.png")
    t.absent("lightning", "bte-warp-drive-local-lightning")

    # Subspace streaks are particles gliding at deck level: four shapes, five tints, three lengths,
    # each fading in over its first frames and playing its row once over a 120-tick life.
    streak = t.prototype("optimized-particle", "bte-warp-drive-streak")
    if streak is not None:
        pictures = streak.get("pictures", [])
        t.check("Warp streak variations", len(pictures), 60)
        height = pictures[0].get("height", 0) if pictures else 0
        t.check("Warp streak rows", sorted({p.get("y") for p in pictures}), [0, height, 2 * height, 3 * height])
        t.check("Warp streak flight", [streak.get("life_time"), streak.get("vertical_acceleration")], [120, 0])

    # Background anomalies pick one of six shapes per layer.
    anomaly = t.prototype("animation", "bte-warp-drive-anomaly")
    if anomaly is not None:
        t.check("Warp anomaly shapes", anomaly["layers"][0].get("frame_count"), 6)

    # Activation shockwaves are one ring sheet that scripts/shockwaves.lua scales and tints; the
    # trivial smoke it replaced is gone.
    t.prototype("animation", "bte-warp-drive-shockwave")
    for tint in ("azure", "violet"):
        for reach in (32, 64, 128, 256):
            t.absent("trivial-smoke", f"bte-warp-drive-shockwave-{tint}-{reach}")

    # While warp holds, a hidden companion makes the building itself hum.
    hum = t.prototype("simple-entity-with-owner", "bte-warp-drive-field-hum")
    if hum is not None:
        sound = hum.get("working_sound", {}).get("sound", {})
        t.check("Warp field hum sound", [sound.get("filename"), sound.get("category")],
                ["__bte-warp-drive__/resources/audio/warp-field-hum.ogg", "game-effect"])
        t.check("Warp field hum is hidden and unselectable",
                [hum.get("hidden"), hum.get("selectable_in_game"), hum.get("collision_mask")],
                [True, False, {"layers": {}}])


# Core overlays scripts/visuals.lua draws for each drive state.
OVERLAY_STATES = ["standby", "detecting", "charging", "activation", "warp"]


def check_graphics(t, controller):
    """The hull, lamps, and every state overlay use the drive's own generated sheets."""
    sprites = list(controller["sprites"]["north"]["layers"])
    t.check("Warp Drive hull casts a shadow", [bool(s.get("draw_as_shadow")) for s in sprites], [False, True])
    animation = t.prototype("electric-energy-interface", "bte-warp-drive-animation")
    if animation is not None:
        sprites.append(animation["animation"])
    for state in OVERLAY_STATES:
        for part in ("interior", "glow"):
            overlay = t.prototype("animation", f"bte-warp-drive-{state}-{part}")
            if overlay is not None:
                sprites.extend(overlay["layers"])
                t.check(f"Warp Drive {state} {part} overlay blending",
                        overlay["layers"][0].get("blend_mode"), "additive" if part == "glow" else None)
    for sprite in sprites:
        t.sprite_sheet(f"Warp Drive {sprite.get('filename', '?').rsplit('/', 1)[-1]}", sprite)
    t.check("Warp Drive graphics come only from its own warp-drive art",
            sorted({s.get("filename", "").rsplit("/", 1)[0] for s in sprites}),
            ["__bte-warp-drive__/graphics/entity/warp-drive"])
