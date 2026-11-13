"""Resolved-prototype expectations for Stargate. Values mirror stargate/README.md."""

import math
import re

from prototype_checks import KG

# The bulk materials delivered to the construction site, each a whole number of stacks.
REQUIREMENTS = [
    ("tungsten-plate", 1000), ("superconductor", 200), ("low-density-structure", 200),
    ("refined-concrete", 200), ("steel-plate", 200), ("tungsten-carbide", 100), ("advanced-circuit", 200),
]
# The scarce high-end parts, which go into the construction kit instead of the site.
SCARCE_KIT_PARTS = [
    ("quantum-processor", 20), ("speed-module-3", 10), ("productivity-module-3", 10),
    ("efficiency-module-3", 10), ("quality-module-3", 10), ("supercapacitor", 50), ("fusion-power-cell", 20),
]
# A little structural material as well, so the kit looks like a kit; the site takes the bulk of the same items.
KIT_INGREDIENTS = SCARCE_KIT_PARTS + [("steel-plate", 100), ("refined-concrete", 100), ("low-density-structure", 50)]
ITEM_TYPES = ["item", "module", "capsule", "tool", "ammo", "armor", "gun", "repair-tool",
              "item-with-entity-data", "rail-planner", "spidertron-remote", "space-platform-starter-pack"]
STARGATE_PACKS = [
    "automation-science-pack", "logistic-science-pack", "chemical-science-pack",
    "production-science-pack", "utility-science-pack", "space-science-pack",
    "metallurgic-science-pack", "agricultural-science-pack", "electromagnetic-science-pack",
    "cryogenic-science-pack",
]
BUILDINGS = ["bte-stargate-construction-site", "bte-stargate-assembling", "bte-stargate"]


def check(t):
    check_kit(t)
    check_construction_plan(t)
    check_buildings(t)
    check_graphics(t)
    check_technology(t)
    t.locale("bte-")


def stack_size(t, name):
    for type_name in ITEM_TYPES:
        prototype = t.raw.get(type_name, {}).get(name)
        if prototype:
            return prototype["stack_size"]
    raise KeyError(name)


def check_kit(t):
    t.recipe("bte-stargate-construction-kit", time=60, category="crafting",
             ingredients=KIT_INGREDIENTS, results=[("bte-stargate-construction-kit", 1)])
    item = t.prototype("item", "bte-stargate-construction-kit")
    if item:
        t.check("kit places the construction site", item.get("place_result"), "bte-stargate-construction-site")
        t.check("kit stack size", item.get("stack_size"), 1)
        t.check("kit weight", item["weight"], 1000 * KG)
        lift = t.raw["utility-constants"]["default"]["default_rocket_lift_weight"]
        t.check("kits per cargo rocket", lift // item["weight"], 1)


def check_construction_plan(t):
    """The site's slots hold one stack of filtered space per stack of each material."""
    site = t.prototype("container", "bte-stargate-construction-site")
    plan = t.prototype("mod-data", "bte-stargate-construction")
    if site is None or plan is None:
        return
    data = plan["data"]
    t.check("construction plan materials", [(r["name"], r["amount"]) for r in data["requirements"]], REQUIREMENTS)
    first_slot = 1
    for requirement in data["requirements"]:
        slots = math.ceil(requirement["amount"] / stack_size(t, requirement["name"]))
        t.check(f"{requirement['name']} slot layout", (requirement["first_slot"], requirement["slots"]), (first_slot, slots))
        first_slot += slots
    t.check("construction site slots hold the whole bill", site["inventory_size"], first_slot - 1)
    t.check("construction site slot count", site["inventory_size"], 32)
    t.check("construction plan build time (ticks)", data["build_ticks"], 3600)
    t.check("construction plan stages", data["stages"], 3)
    # Whole stacks, so a delivery can never exceed the bill.
    t.check("every bulk amount is a whole number of stacks",
            [(r["name"], r["amount"] % stack_size(t, r["name"])) for r in data["requirements"]],
            [(name, 0) for name, _ in REQUIREMENTS])
    t.check("no scarce kit part is also delivered to the site",
            sorted({n for n, _ in SCARCE_KIT_PARTS} & {r["name"] for r in data["requirements"]}), [])
    t.check("construction site inventory has filters", site.get("inventory_type"), "with_filters_and_bar")
    t.check("construction site ignores quality slot bonus", site.get("quality_affects_inventory_size"), False)
    for name, _ in REQUIREMENTS:
        t.check(f"{name} is a valid item", any(name in t.raw.get(type_name, {}) for type_name in ITEM_TYPES), True)


def check_buildings(t):
    site = t.prototype("container", "bte-stargate-construction-site")
    assembling = t.prototype("simple-entity-with-owner", "bte-stargate-assembling")
    gate = t.prototype("simple-entity-with-owner", "bte-stargate")
    for name, entity in zip(BUILDINGS, (site, assembling, gate)):
        if entity is None:
            continue
        t.check(f"{name} footprint", t.footprint(entity), (14, 14))
        # The 2x2 grid snaps the origin to even coordinates; the building's centre is one tile south-east of it,
        # so the rails (odd coordinates) and the 4 | rail | gap | rail | 4 layout fall on whole rail cells.
        t.check(f"{name} collision box", entity["collision_box"], [[-5.9, -5.9], [7.9, 7.9]])
        t.check(f"{name} selection box", entity["selection_box"], [[-6, -6], [8, 8]])
        t.check(f"{name} builds on the rails' 2x2 grid", entity.get("build_grid_size"), 2)
    if site:
        t.check("construction site returns the kit when mined", site.get("minable", {}).get("result"),
                "bte-stargate-construction-kit")
    for name, entity in (("assembling gate", assembling), ("gate", gate)):
        if entity is None:
            continue
        t.check(f"{name} cannot be mined", "minable" in entity, False)
        t.check(f"{name} cannot be deconstructed", "not-deconstructable" in entity.get("flags", []), True)
        t.check(f"{name} is not blueprintable", "not-blueprintable" in entity.get("flags", []), True)
    if assembling:
        t.check("assembling gate starts on its first picture", assembling.get("random_variation_on_create"), False)
    t.check("gate is sturdier than the site", (gate or {}).get("max_health", 0) > (site or {}).get("max_health", 0), True)


def exported_shift(t, filename):
    """The shift a generated sheet's .lua file records, which util.sprite_load adds to the prototype's own."""
    match = re.fullmatch(r"__([^/]+)__/(.+)\.png", filename)
    text = (t.mods[match[1]] / f"{match[2]}.lua").read_text()
    found = re.search(r"shift = \{(-?[\d.]+), (-?[\d.]+)\}", text)
    return [float(found[1]), float(found[2])]


def check_graphics(t):
    """Original tools/sprites art: platform and ring in main and shadow, with an additive light layer on the gate.

    The assembling gate has one picture per build stage, which the runtime switches between.
    """
    suffixes = ("glow-lights.png", "main.png", "shadow.png")

    def layers(sprites):
        return [(next(x for x in suffixes if s["filename"].endswith(x)), bool(s.get("draw_as_shadow"))) for s in sprites]

    plain = [("main.png", False), ("shadow.png", True)]
    lit = plain + [("glow-lights.png", False)]
    site = t.prototype("container", "bte-stargate-construction-site")
    assembling = t.prototype("simple-entity-with-owner", "bte-stargate-assembling")
    gate = t.prototype("simple-entity-with-owner", "bte-stargate")
    pictures = {}
    if site:
        pictures["construction site"] = [site["picture"]]
    if assembling:
        pictures.update({f"assembling stage {n}": [p] for n, p in enumerate(assembling["pictures"], 1)})
        t.check("assembling gate stage pictures", len(assembling["pictures"]), 3)
        if site:
            t.check("the first build stage reuses the construction site's picture",
                    [s["filename"] for s in assembling["pictures"][0]["layers"]],
                    [s["filename"] for s in site["picture"]["layers"]])
    if gate:
        pictures["gate"] = [gate["picture"]]
    for label, [picture] in pictures.items():
        sprites = picture["layers"]
        t.check(f"{label} layers", layers(sprites), lit if label == "gate" else plain)
        t.check(f"{label} glow layer is additive",
                [s.get("blend_mode") for s in sprites if s["filename"].endswith("glow-lights.png")],
                ["additive"] if label == "gate" else [])
        for sprite in sprites:
            t.sprite_sheet(f"{label} {sprite['filename'].rsplit('/', 1)[-1]}", sprite)
            # Every sprite is shifted with the boxes, one tile south-east of the origin.
            expected = [round(v + 1, 4) for v in exported_shift(t, sprite["filename"])]
            t.check(f"{label} {sprite['filename'].rsplit('/', 1)[-1]} shift follows the box",
                    [round(v, 4) for v in sprite["shift"]], expected)
    for name, icon in (("bte-stargate-construction-kit", "construction-kit"), ("bte-stargate", "stargate")):
        prototype = t.raw["item" if "kit" in name else "simple-entity-with-owner"].get(name)
        if prototype:
            t.check(f"{name} icon", prototype.get("icon"), f"__bte-stargate__/graphics/icons/{icon}.png")


def check_technology(t):
    t.technology("bte-stargate-experimental-gates", count=1000, time=60, packs=STARGATE_PACKS,
                 prerequisites=["quantum-processor", "fusion-reactor", "speed-module-3", "productivity-module-3",
                                "efficiency-module-3", "quality-module-3"],
                 unlocks=["bte-stargate-construction-kit"])
