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
        t.check("Warp Drive footprint", t.footprint(controller), (9, 9))
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


# Core overlays scripts/visuals.lua draws for each drive state.
OVERLAY_STATES = ["standby", "charging", "activation", "warp"]


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
