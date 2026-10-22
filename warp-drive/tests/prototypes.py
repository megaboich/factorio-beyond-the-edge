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
        t.check("Warp Drive footprint", t.footprint(controller), (6, 6))
        t.check("Warp Drive is platform-only", controller.get("surface_conditions"),
                [{"property": "pressure", "min": 0, "max": 0}])
        t.check("Warp Drive mines into its item", controller.get("minable", {}).get("result"), "bte-warp-drive")

    t.technology("bte-theoretical-warp-drive", count=10000, time=120,
                 prerequisites=["promethium-science-pack"], unlocks=["bte-warp-drive"])
    t.technology("bte-practical-warp-drive", count=1000000000, time=120,
                 prerequisites=["bte-theoretical-warp-drive"])

    # The mod adds one building and no laboratories, science packs, or particle items.
    t.check("Warp Drive items", t.names("item", "bte-warp-drive"), ["bte-warp-drive"])
    t.check("Warp Drive laboratories", t.names("lab", "bte-"), [])
    t.check("Warp Drive science packs", t.names("tool", "bte-"), [])
