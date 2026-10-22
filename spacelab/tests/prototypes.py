"""Resolved-prototype expectations for SPACELAB. Values mirror spacelab/README.md."""

from prototype_checks import KG, watts

STONE_FOCUSED = {
    "bte-metallic-asteroid-crushing-stone-focused": ("metallic-asteroid-chunk", [("iron-ore", 1), ("copper-ore", 1)]),
    "bte-carbonic-asteroid-crushing-stone-focused": ("carbonic-asteroid-chunk", [("carbon", 2)]),
    "bte-oxide-asteroid-crushing-stone-focused": ("oxide-asteroid-chunk", [("ice", 2)]),
}
FLUROLITE_FOCUSED = {
    "bte-metallic-asteroid-crushing-flurolite-focused": ("metallic-asteroid-chunk", [("iron-ore", 1), ("copper-ore", 1)]),
    "bte-carbonic-asteroid-crushing-flurolite-focused": ("carbonic-asteroid-chunk", [("carbon", 2)]),
    "bte-oxide-asteroid-crushing-flurolite-focused": ("oxide-asteroid-chunk", [("ice", 2)]),
}
GROWTH_RECIPES = [
    "bte-yumako-cultivation", "bte-jellynut-cultivation",
    "bte-biter-egg-incubation", "bte-pentapod-egg-incubation",
]
SPACE_SCIENCE_OVERRIDES = [
    "agricultural-science-pack", "cryogenic-science-pack",
    "electromagnetic-science-pack", "metallurgic-science-pack",
]


def check(t):
    check_recipes(t)
    check_growth_facility(t)
    check_flurolite(t)
    check_technologies(t)
    check_vanilla_overrides(t)
    t.locale("bte-")


def check_recipes(t):
    t.recipe("bte-growth-facility", time=10, category="crafting",
             ingredients=[("cryogenic-plant", 1), ("low-density-structure", 40), ("pump", 4),
                          ("heat-exchanger", 1), ("small-lamp", 100), ("refined-concrete", 100),
                          ("overgrowth-yumako-soil", 50), ("overgrowth-jellynut-soil", 50)],
             results=[("bte-growth-facility", 1)])

    for name, (chunk, base) in STONE_FOCUSED.items():
        t.recipe(name, time=2, category="crushing", ingredients=[(chunk, 1)], results=base + [("stone", 4)])
    trace = [("bte-flurolite", 1, 0.05), ("uranium-ore", 1, 0.01)]
    for name, (chunk, base) in FLUROLITE_FOCUSED.items():
        t.recipe(name, time=3, category="crushing", ingredients=[(chunk, 1)], results=base + [("stone", 2)] + trace)
    t.recipe("bte-shattered-synthesis", time=4, category="crushing",
             ingredients=[("promethium-asteroid-chunk", 1)],
             results=[("holmium-ore", 1, 0.2), ("tungsten-ore", 1), ("stone", 2),
                      ("bte-flurolite", 1, 0.05), ("uranium-ore", 1, 0.03)])

    t.recipe("bte-ammonia-extraction", time=5, category="cryogenics",
             ingredients=[("stone", 5), ("water", 100), ("steam", 50)], results=[("ammonia", 10)])
    t.recipe("bte-lithium-focused-condensation", time=10, category="cryogenics",
             ingredients=[("bte-flurolite", 1), ("steam", 100)],
             results=[("lithium-brine", 40), ("fluorine", 10)])
    t.recipe("bte-fluorine-focused-condensation", time=10, category="cryogenics",
             ingredients=[("bte-flurolite", 1), ("steam", 100)],
             results=[("fluorine", 40), ("lithium-brine", 10)])

    crop = [("nutrients", 25), ("water", 500), ("steam", 250), ("calcite", 5), ("carbon", 10), ("ammonia", 125)]
    t.recipe("bte-yumako-cultivation", time=60, category="bte-spacelab-growth",
             ingredients=crop + [("yumako-seed", 1)], results=[("yumako", 57)])
    t.recipe("bte-jellynut-cultivation", time=60, category="bte-spacelab-growth",
             ingredients=crop + [("jellynut-seed", 1)], results=[("jellynut", 57)])
    egg = [("nutrients", 50), ("bioflux", 5), ("water", 500), ("steam", 250), ("calcite", 5), ("carbon", 10),
           ("ammonia", 125)]
    t.recipe("bte-biter-egg-incubation", time=120, category="bte-spacelab-growth",
             ingredients=egg + [("biter-egg", 1)], results=[("biter-egg", 19)])
    t.recipe("bte-pentapod-egg-incubation", time=120, category="bte-spacelab-growth",
             ingredients=egg + [("pentapod-egg", 1)], results=[("pentapod-egg", 19)])
    for name in GROWTH_RECIPES:
        recipe = t.raw["recipe"].get(name, {})
        t.check(f"recipe {name} preserves products in machine output",
                recipe.get("preserve_products_in_machine_output"), True)


def check_growth_facility(t):
    machine = t.prototype("assembling-machine", "bte-growth-facility")
    if machine is None:
        return
    t.check("Growth Facility footprint", t.footprint(machine), (9, 9))
    t.check("Growth Facility power", watts(machine["energy_usage"]), 100e6)
    t.check("Growth Facility crafting speed", machine.get("crafting_speed"), 4)
    t.check("Growth Facility module slots", machine.get("module_slots"), 8)
    t.check("Growth Facility allowed effects", machine.get("allowed_effects"), ["consumption"])
    t.check("Growth Facility crafting categories", machine.get("crafting_categories"), ["bte-spacelab-growth"])
    lanes = [sorted(c["position"][0] for c in box.get("pipe_connections", []))
             for box in machine.get("fluid_boxes", [])]
    t.check("Growth Facility west/east pass-through fluid lanes", lanes, [[-4, 4]] * 3)
    check_growth_facility_graphics(t, machine)

    item = t.prototype("item", "bte-growth-facility")
    if item is None:
        return
    t.check("Growth Facility weight", item.get("weight"), 1000 * KG)
    lift = t.raw["utility-constants"]["default"]["default_rocket_lift_weight"]
    t.check("Growth Facilities per cargo rocket", lift // item["weight"], 1)


# Each growth recipe owns one recipe tint channel and the specimens layer drawn with it.
GROWTH_CHANNELS = {
    "bte-yumako-cultivation": ("primary", "specimens-yumako"),
    "bte-jellynut-cultivation": ("secondary", "specimens-jellynut"),
    "bte-biter-egg-incubation": ("tertiary", "specimens-biter-egg"),
    "bte-pentapod-egg-incubation": ("quaternary", "specimens-pentapod-egg"),
}
CHANNELS = ["primary", "secondary", "tertiary", "quaternary"]


def tint_alpha(color):
    if isinstance(color, dict):
        return color.get("a", 1)
    return color[3] if len(color) > 3 else 1


def check_growth_facility_graphics(t, machine):
    """Original tools/sprites art: a 32-frame building and shadow, lights, and per-recipe specimens and fluid.

    Specimens grow over 8 building loops: 64 frames at a quarter of the building's frame rate.
    """
    graphics = machine.get("graphics_set", {})
    layers = graphics.get("animation", {}).get("layers", [])
    t.check("Growth Facility animation layers (frames, shadow)",
            [(layer.get("frame_count"), bool(layer.get("draw_as_shadow"))) for layer in layers],
            [(32, False), (1, True)])
    overlays = [v for v in graphics.get("working_visualisations", []) if "animation" in v]
    building_speed = layers[0].get("animation_speed") if layers else None
    t.check("Growth Facility overlays (sprite, tint channel, always drawn, blend, frames, speed vs building)",
            [(v["animation"].get("filename", "").rsplit("growth-facility-", 1)[-1], v.get("apply_recipe_tint"),
              bool(v.get("always_draw")), v["animation"].get("blend_mode", "normal"), v["animation"].get("frame_count"),
              v["animation"].get("animation_speed") / building_speed if building_speed else None) for v in overlays],
            [(f"{sprite}.png", channel, True, "normal", 64, 0.25) for channel, sprite in GROWTH_CHANNELS.values()]
            + [("fluid.png", channel, True, "normal", 32, 1.0) for channel, _ in GROWTH_CHANNELS.values()]
            + [("glow-lights.png", None, False, "additive", 32, 1.0)])
    t.check("Growth Facility recipe lights use one channel each",
            sorted(v.get("apply_recipe_tint") for v in graphics.get("working_visualisations", [])
                   if "light" in v and v.get("apply_recipe_tint")), sorted(CHANNELS))
    for field in ("default_recipe_tint", "recipe_not_set_tint"):
        t.check(f"Growth Facility {field} hides every contents layer",
                [tint_alpha(graphics.get(field, {}).get(c, [1, 1, 1, 1])) for c in CHANNELS], [0] * 4)
    for name, (channel, _) in GROWTH_CHANNELS.items():
        tints = t.raw["recipe"].get(name, {}).get("crafting_machine_tint", {})
        t.check(f"recipe {name} switches on only its {channel} contents",
                {c: tint_alpha(tints.get(c, [1, 1, 1, 1])) for c in CHANNELS},
                {c: 1 if c == channel else 0 for c in CHANNELS})
    sprites = layers + [v["animation"] for v in overlays]
    for sprite in sprites:
        t.sprite_sheet(f"Growth Facility {sprite.get('filename', '?').rsplit('/', 1)[-1]}", sprite)
    t.check("Growth Facility graphics come only from SPACELAB's own growth-facility art",
            sorted({s.get("filename", "").rsplit("/", 1)[0] for s in sprites}),
            ["__bte-spacelab__/graphics/entity/growth-facility"])


def check_flurolite(t):
    t.prototype("item", "bte-flurolite")
    t.absent("resource", "bte-flurolite")
    t.absent("autoplace-control", "bte-flurolite")


def check_technologies(t):
    prerequisites = ["promethium-science-pack"]
    t.technology("bte-asteroid-stone-processing", count=1200, time=120, prerequisites=prerequisites,
                 unlocks=list(STONE_FOCUSED) + ["bte-ammonia-extraction"])
    t.technology("bte-flurolite-processing", count=1200, time=120, prerequisites=prerequisites,
                 unlocks=list(FLUROLITE_FOCUSED) + ["bte-shattered-synthesis", "bte-lithium-focused-condensation",
                                                    "bte-fluorine-focused-condensation"])
    t.technology("bte-growth-facility", count=1200, time=120, prerequisites=prerequisites,
                 unlocks=["bte-growth-facility"] + GROWTH_RECIPES)


def check_vanilla_overrides(t):
    for name in SPACE_SCIENCE_OVERRIDES:
        vanilla = t.vanilla["recipe"].get(name, {})
        t.check(f"recipe {name} has a vanilla surface condition", bool(vanilla.get("surface_conditions")), True)
        t.check(f"recipe {name} surface conditions removed",
                t.raw["recipe"].get(name, {}).get("surface_conditions"), None)
        t.same_as_vanilla("recipe", name, ignore=("surface_conditions",))
