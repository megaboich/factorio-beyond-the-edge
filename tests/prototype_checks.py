"""Shared assertions for resolved-prototype tests.

Each mod declares its expectations in `<mod>/tests/prototypes.py` as `check(t)`, where `t`
is a `Checker` bound to one `--dump-data` result and a vanilla Space Age baseline dump.
Expected values mirror each mod's README, which remains the source of truth.
"""

import argparse
import importlib.util
import json
import math
import sys
from pathlib import Path

FULL_SCIENCE_SET = [
    "automation-science-pack", "logistic-science-pack", "military-science-pack",
    "chemical-science-pack", "production-science-pack", "utility-science-pack",
    "space-science-pack", "metallurgic-science-pack", "electromagnetic-science-pack",
    "agricultural-science-pack", "cryogenic-science-pack", "promethium-science-pack",
]

# Prototype weights use base units where `kg = 1000`, matching the data-stage `kg` constant.
KG = 1000

_POWER_UNITS = {"W": 1, "kW": 1e3, "MW": 1e6, "GW": 1e9, "TW": 1e12}


def watts(value):
    for unit in sorted(_POWER_UNITS, key=len, reverse=True):
        if value.endswith(unit):
            return float(value[:-len(unit)]) * _POWER_UNITS[unit]
    raise ValueError(f"unrecognized power value {value!r}")


def _products(entries):
    return sorted((e["name"], e.get("amount"), e.get("independent_probability", 1)) for e in entries or [])


def _expected_products(entries):
    return sorted((e[0], e[1], e[2] if len(e) > 2 else 1) for e in entries)


class Checker:
    def __init__(self, raw, vanilla):
        self.raw = raw
        self.vanilla = vanilla
        self.checks = 0
        self.failures = []

    def check(self, label, actual, expected):
        self.checks += 1
        if actual != expected:
            self.failures.append(f"{label}: expected {expected!r}, got {actual!r}")

    def prototype(self, type_name, name):
        self.checks += 1
        prototype = self.raw.get(type_name, {}).get(name)
        if prototype is None:
            self.failures.append(f"missing {type_name} {name}")
        return prototype

    def absent(self, type_name, name):
        self.check(f"{type_name} {name} absent", name in self.raw.get(type_name, {}), False)

    def names(self, type_name, prefix):
        return sorted(name for name in self.raw.get(type_name, {}) if name.startswith(prefix))

    def recipe(self, name, *, time, category, ingredients, results):
        recipe = self.prototype("recipe", name)
        if recipe is None:
            return None
        self.check(f"recipe {name} time", recipe.get("energy_required", 0.5), time)
        self.check(f"recipe {name} categories", recipe.get("categories", ["crafting"]), [category])
        self.check(f"recipe {name} ingredients", _products(recipe.get("ingredients")), _expected_products(ingredients))
        self.check(f"recipe {name} results", _products(recipe.get("results")), _expected_products(results))
        return recipe

    def technology(self, name, *, count, time, prerequisites, unlocks=(), packs=FULL_SCIENCE_SET):
        tech = self.prototype("technology", name)
        if tech is None:
            return None
        unit = tech.get("unit", {})
        self.check(f"technology {name} count", unit.get("count"), count)
        self.check(f"technology {name} time", unit.get("time"), time)
        self.check(f"technology {name} packs",
                   sorted(i[0] if isinstance(i, list) else i["name"] for i in unit.get("ingredients", [])),
                   sorted(packs))
        self.check(f"technology {name} prerequisites", sorted(tech.get("prerequisites", [])), sorted(prerequisites))
        self.check(f"technology {name} unlocks",
                   sorted(e["recipe"] for e in tech.get("effects", []) if e["type"] == "unlock-recipe"),
                   sorted(unlocks))
        return tech

    def footprint(self, entity):
        (x1, y1), (x2, y2) = (tuple(p) if isinstance(p, list) else (p["x"], p["y"]) for p in entity["collision_box"])
        return math.ceil(x2 - x1), math.ceil(y2 - y1)

    def same_as_vanilla(self, type_name, name, ignore=()):
        """Asserts a prototype matches the unmodded Space Age baseline except for `ignore` keys."""
        actual = self.prototype(type_name, name)
        base = self.vanilla.get(type_name, {}).get(name)
        if actual is None or base is None:
            self.check(f"{type_name} {name} exists in vanilla baseline", base is not None, True)
            return
        changed = sorted(key for key in set(actual) | set(base)
                         if key not in ignore and actual.get(key) != base.get(key))
        self.check(f"{type_name} {name} fields changed from vanilla", changed, [])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dump", required=True, help="data-raw-dump.json to test")
    parser.add_argument("--vanilla", required=True, help="data-raw-dump.json from unmodded Space Age")
    parser.add_argument("--label", default="", help="mod set name used in output")
    parser.add_argument("mods", nargs="+", help="mod directories whose tests/prototypes.py to run")
    args = parser.parse_args()

    repo = Path(__file__).resolve().parent.parent
    raw = json.loads(Path(args.dump).read_text())
    vanilla = json.loads(Path(args.vanilla).read_text())
    failed = False
    for mod in args.mods:
        spec = importlib.util.spec_from_file_location(f"{mod}_prototypes", repo / mod / "tests" / "prototypes.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        checker = Checker(raw, vanilla)
        module.check(checker)
        status = "PASS" if not checker.failures else "FAIL"
        print(f"PROTOTYPE_TEST_{status}: {args.label} {mod}: {checker.checks} checks, {len(checker.failures)} failures")
        for failure in checker.failures:
            print(f"  FAIL {failure}")
        failed = failed or bool(checker.failures)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
