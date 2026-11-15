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
    t.check("construction plan stages", data["stages"], 6)
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
    gate = t.prototype("assembling-machine", "bte-stargate")
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
    if gate:
        # The gate is an assembling machine on a hidden no-op recipe, for its power, circuit condition, and veil.
        t.check("gate is powered through its capacitor", gate.get("energy_source", {}).get("type"), "void")
        t.check("gate runs the portal recipe", gate.get("fixed_recipe"), "bte-stargate-portal")
        t.check("gate takes no modules", gate.get("module_slots", 0), 0)
        t.check("gate has a circuit connection", "circuit_connector" in gate and gate.get("circuit_wire_max_distance", 0) > 0, True)
        t.check("characters can walk into the gate",
                sorted(set(gate.get("collision_mask", {}).get("layers", {"player": True})) & {"player", "is_object"}), [])
    # The barriers over the machinery stop characters, spidertron legs, and vehicles.
    for name in ("bte-stargate-side-block", "bte-stargate-cabinet-block", "bte-stargate-rack-block"):
        barrier = t.prototype("simple-entity-with-owner", name)
        if barrier:
            t.check(f"{name} is on the barrier layer only", barrier.get("collision_mask", {}).get("layers"), {"bte-stargate-barrier": True})
    for kind, name, expected in (("character", "character", True), ("spider-leg", "spidertron-leg-1", True),
                                 ("car", "car", True), ("car", "tank", True)):
        entity = t.prototype(kind, name)
        if entity:
            t.check(f"{name} collides with the gate's barriers: {expected}",
                    "bte-stargate-barrier" in entity.get("collision_mask", {}).get("layers", {}), expected)
    capacitor = t.prototype("electric-energy-interface", "bte-stargate-capacitor")
    if capacitor:
        source = capacitor.get("energy_source", {})
        t.check("capacitor draws as an ordinary consumer, not accumulator storage", source.get("usage_priority"), "secondary-input")
        t.check("capacitor charges at up to 1.25 GW (upkeep, leak, and 200 MW) and gives nothing back",
                (source.get("input_flow_limit"), source.get("output_flow_limit")), ("1250MW", "0W"))
        t.check("capacitor covers the gate", capacitor.get("collision_box"), [[-6.9, -6.9], [6.9, 6.9]])
        t.check("capacitor collides with nothing", capacitor.get("collision_mask", {}).get("layers"), {})
    power = t.prototype("mod-data", "bte-stargate-power")
    t.check("a gate stores 10 GJ, upkeep 1 GW, charges at 1 GW, refills at 200 MW",
            power and [power.get("data", {}).get(k) for k in ("capacity", "upkeep", "charge_rate", "refill")], [10e9, 1e9, 1e9, 200e6])
    for name in ("bte-stargate-open", "bte-stargate-close", "bte-stargate-depart", "bte-stargate-arrive",
                 "bte-stargate-car-in", "bte-stargate-car-out"):
        sound = t.raw.get("sound", {}).get(name)
        t.check(f"{name} sound exists", sound is not None, True)
        if sound:
            file = re.fullmatch(r"__bte-stargate__/(.+)", sound.get("filename", ""))
            t.check(f"{name} file exists", bool(file) and (t.mods["bte-stargate"] / file[1]).is_file(), True)
    # The building and its lights stand on the ring's line, two tiles south of the gate's centre, so
    # characters sort against the ring; the upper arc is drawn again over spidertrons, like elevated
    # rails. Variation 1 has cyan lights, 2 red.
    for label, layer, picture, lights in (("body", "object", "main", "glow-lights"),
                                          ("top", "elevated-object", "top", "glow-lights-high")):
        companion = t.prototype("simple-entity-with-owner", f"bte-stargate-{label}")
        if not companion:
            continue
        t.check(f"{label} collides with nothing", companion.get("collision_mask", {}).get("layers"), {})
        t.check(f"{label} render layer", companion.get("render_layer", "object"), layer)
        t.check(f"{label} keeps its variation", companion.get("random_variation_on_create"), False)
        red = lights.replace("glow-lights", "glow-lights-red")
        # The body also has pictures for a station gate's one and two tracks (scripts/gate.lua, show_body).
        suffixes = ("", "-single", "-double") if label == "body" else ("",)
        expected = [(picture + x, glow + x) for x in suffixes for glow in (lights, red)]
        t.check(f"{label} has {len(expected)} variations", len(companion.get("pictures", [])), len(expected))
        for n, (variation, (pic, glow)) in enumerate(zip(companion.get("pictures", []), expected), 1):
            sprites = variation["layers"]
            t.check(f"{label} variation {n} layers", [x["filename"].rsplit("stargate-", 1)[-1] for x in sprites], [f"{pic}.png", f"{glow}.png"])
            t.check(f"{label} variation {n} lights are an additive glow", (sprites[1].get("blend_mode"), sprites[1].get("draw_as_glow")), ("additive", True))
            for sprite in sprites:
                name = sprite["filename"].rsplit("/", 1)[-1]
                t.sprite_sheet(f"{label} {name}", sprite)
                shift = exported_shift(t, sprite["filename"])
                t.check(f"{label} {name} shift puts the picture on the gate", [round(v, 4) for v in sprite["shift"]],
                        [round(shift[0], 4), round(shift[1] - 2, 4)])
    # Station mode (scripts/railway.lua): vanilla rails only the script places, on the rail layer alone so
    # they fit inside the gate yet still block and join player rails, and an invisible station.
    rail = t.prototype("straight-rail", "bte-stargate-rail")
    if rail:
        t.check("station rail is on the rail layer only", rail.get("collision_mask", {}).get("layers"), {"rail": True})
        t.check("station rail cannot be mined", "minable" in rail, False)
        vanilla = dict(t.prototype("straight-rail", "straight-rail").get("pictures", {}))
        pictures = dict(rail.get("pictures", {}))
        layers = pictures.pop("render_layers", {})
        vanilla.pop("render_layers", None)
        t.check("station rail keeps the vanilla look", pictures == vanilla, True)
        # Never drawn: the gate draws its own track on a ramp (bte-stargate-tracks).
        t.check("station rail is drawn under the ground", set(layers.values()), {"zero"})
    splash = t.raw.get("animation", {}).get("bte-stargate-splash")
    t.check("each train carriage's splash exists, 32 frames", splash and splash.get("frame_count"), 32)
    tracks = t.prototype("simple-entity-with-owner", "bte-stargate-tracks")
    t.check("station track companion exists", tracks is not None, True)
    if tracks:
        t.check("station track is drawn above the floor, under trains", tracks.get("render_layer"), "floor-mechanics")
        t.check("station track collides with nothing", tracks.get("collision_mask", {}).get("layers"), {})
        t.check("station track has one track, and two with chevrons for either layout",
                [[layer["filename"].rsplit("stargate-", 1)[-1] for layer in v["layers"]] for v in tracks.get("pictures", [])],
                [["rails-single.png"], ["rails-double.png", "chevrons-right.png"], ["rails-double.png", "chevrons-left.png"]])
        for v in tracks.get("pictures", []):
            for layer in v["layers"]:
                t.sprite_sheet("station track", layer)
    hidden = t.prototype("straight-rail", "bte-stargate-rail-hidden")
    if hidden:
        t.check("hidden rail is drawn under the ground", set(hidden.get("pictures", {}).get("render_layers", {}).values()), {"zero"})
        t.check("hidden rail is on the rail layer only", hidden.get("collision_mask", {}).get("layers"), {"rail": True})
    station = t.prototype("train-stop", "bte-stargate-station")
    if station:
        t.check("station collides with nothing", station.get("collision_mask", {}).get("layers"), {})
        t.check("station cannot be mined", "minable" in station, False)
        t.check("station is not blueprintable", "not-blueprintable" in station.get("flags", []), True)
    portal = t.raw.get("recipe", {}).get("bte-stargate-portal")
    t.check("portal recipe exists", portal is not None, True)
    if portal:
        t.check("portal recipe is hidden", portal.get("hidden"), True)
        t.check("portal recipe has no ingredients or results",
                (portal.get("ingredients") or [], portal.get("results") or []), ([], []))
        t.check("portal recipe category", portal.get("categories"), ["bte-stargate-portal"])
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
    site = t.prototype("container", "bte-stargate-construction-site")
    assembling = t.prototype("simple-entity-with-owner", "bte-stargate-assembling")
    gate = t.prototype("assembling-machine", "bte-stargate")
    pictures = {}
    if site:
        pictures["construction site"] = [site["picture"]]
    if assembling:
        pictures.update({f"assembling stage {n}": [p] for n, p in enumerate(assembling["pictures"], 1)})
        t.check("assembling gate stage pictures", len(assembling["pictures"]), 6)
        if site:
            t.check("the first build stage reuses the construction site's picture",
                    [s["filename"] for s in assembling["pictures"][0]["layers"]],
                    [s["filename"] for s in site["picture"]["layers"]])
    if gate:
        pictures["gate"] = [gate["graphics_set"]["animation"]]
        patch = gate["graphics_set"].get("integration_patch")
        t.check("gate floor is its integration patch, under rails", (bool(patch), gate["graphics_set"].get("integration_patch_render_layer")), (True, "floor"))
        if patch:
            t.check("gate floor patch draws the floor", patch["filename"].endswith("stargate-floor.png"), True)
            t.check("gate floor patch shift follows the box", [round(v, 4) for v in patch["shift"]],
                    [round(v + 1, 4) for v in exported_shift(t, patch["filename"])])
        t.check("gate leaves the veil to its companions", gate["graphics_set"].get("working_visualisations"), None)
    # The veil, split like the ring: the lower part sorts with characters, the upper over spidertrons.
    for name, layer, sheet in (("bte-stargate-veil", "object", "glow-veil"), ("bte-stargate-veil-top", "elevated-object", "glow-veil-high")):
        companion = t.prototype("simple-entity-with-owner", name)
        if not companion:
            continue
        t.check(f"{name} render layer", companion.get("render_layer", "object"), layer)
        t.check(f"{name} collides with nothing", companion.get("collision_mask", {}).get("layers"), {})
        veil = companion.get("animations", [{}])[0]
        t.check(f"{name} draws {sheet}", veil.get("filename", "").endswith(f"stargate-{sheet}.png"), True)
        t.check(f"{name} is an additive glow", (veil.get("blend_mode"), veil.get("draw_as_glow")), ("additive", True))
        t.check(f"{name} frames", veil.get("frame_count"), 16)
        t.sprite_sheet(f"{name} {sheet}.png", veil)
        t.check(f"{name} shift puts the veil on the gate", [round(v, 4) for v in veil["shift"]],
                (lambda shift: [round(shift[0], 4), round(shift[1] - 2, 4)])(exported_shift(t, veil["filename"])))
    for label, [picture] in pictures.items():
        sprites = picture["layers"]
        # The gate's building is its body (above); the gate itself draws only the shadow.
        t.check(f"{label} layers", layers(sprites), [("shadow.png", True)] if label == "gate" else plain)
        t.check(f"{label} glow layer is additive",
                [s.get("blend_mode") for s in sprites if s["filename"].endswith("glow-lights.png")],
                [])
        for sprite in sprites:
            t.sprite_sheet(f"{label} {sprite['filename'].rsplit('/', 1)[-1]}", sprite)
            # Every sprite is shifted with the boxes, one tile south-east of the origin.
            expected = [round(v + 1, 4) for v in exported_shift(t, sprite["filename"])]
            t.check(f"{label} {sprite['filename'].rsplit('/', 1)[-1]} shift follows the box",
                    [round(v, 4) for v in sprite["shift"]], expected)
    passage = t.raw.get("animation", {}).get("bte-stargate-passage")
    t.check("passage animation exists", passage is not None, True)
    if passage:
        t.check("passage is an additive glow of 32 frames",
                (passage.get("blend_mode"), passage.get("draw_as_glow"), passage.get("frame_count")), ("additive", True, 32))
        t.sprite_sheet("passage glow-passage.png", passage)
    for name, icon in (("bte-stargate-construction-kit", "construction-kit"), ("bte-stargate", "stargate")):
        prototype = t.raw["item" if "kit" in name else "assembling-machine"].get(name)
        if prototype:
            t.check(f"{name} icon", prototype.get("icon"), f"__bte-stargate__/graphics/icons/{icon}.png")


def check_technology(t):
    t.technology("bte-stargate-experimental-gates", count=1000, time=60, packs=STARGATE_PACKS,
                 prerequisites=["quantum-processor", "fusion-reactor", "speed-module-3", "productivity-module-3",
                                "efficiency-module-3", "quality-module-3"],
                 unlocks=["bte-stargate-construction-kit"])
