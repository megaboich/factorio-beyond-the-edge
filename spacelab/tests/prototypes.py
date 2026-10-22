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

    crop = [("nutrients", 5), ("water", 100), ("steam", 50), ("calcite", 1), ("carbon", 2), ("ammonia", 25)]
    t.recipe("bte-yumako-cultivation", time=60, category="bte-spacelab-growth",
             ingredients=crop + [("yumako-seed", 1)], results=[("yumako", 50)])
    t.recipe("bte-jellynut-cultivation", time=60, category="bte-spacelab-growth",
             ingredients=crop + [("jellynut-seed", 1)], results=[("jellynut", 50)])
    egg = [("nutrients", 10), ("bioflux", 1), ("water", 100), ("steam", 50), ("calcite", 1), ("carbon", 2),
           ("ammonia", 25)]
    t.recipe("bte-biter-egg-incubation", time=120, category="bte-spacelab-growth",
             ingredients=egg + [("biter-egg", 1)], results=[("biter-egg", 20)])
    t.recipe("bte-pentapod-egg-incubation", time=120, category="bte-spacelab-growth",
             ingredients=egg + [("pentapod-egg", 1)], results=[("pentapod-egg", 20)])
    for name in GROWTH_RECIPES:
        recipe = t.raw["recipe"].get(name, {})
        t.check(f"recipe {name} preserves products in machine output",
                recipe.get("preserve_products_in_machine_output"), True)


def check_growth_facility(t):
    machine = t.prototype("assembling-machine", "bte-growth-facility")
    if machine is None:
        return
    t.check("Growth Facility footprint", t.footprint(machine), (9, 9))
    t.check("Growth Facility power", watts(machine["energy_usage"]), 40e6)
    t.check("Growth Facility crafting speed", machine.get("crafting_speed"), 4)
    t.check("Growth Facility module slots", machine.get("module_slots"), 8)
    t.check("Growth Facility allowed effects", machine.get("allowed_effects"), ["consumption"])
    t.check("Growth Facility crafting categories", machine.get("crafting_categories"), ["bte-spacelab-growth"])
    lanes = [sorted(c["position"][0] for c in box.get("pipe_connections", []))
             for box in machine.get("fluid_boxes", [])]
    t.check("Growth Facility west/east pass-through fluid lanes", lanes, [[-4, 4]] * 3)

    item = t.prototype("item", "bte-growth-facility")
    if item is None:
        return
    t.check("Growth Facility weight", item.get("weight"), 1000 * KG)
    lift = t.raw["utility-constants"]["default"]["default_rocket_lift_weight"]
    t.check("Growth Facilities per cargo rocket", lift // item["weight"], 1)


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
