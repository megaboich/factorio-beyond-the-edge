"""Models gates charging from a Factorio electric network shared with a factory, to tune the adaptive
request in scripts/gate.lua (collect). Run: python3 stargate/tests/power-model.py

The engine's rule for machine-priority (secondary-input) consumers: if the total demand fits the
supply everyone gets what it asks for, otherwise everyone gets the same fraction supply / demand.
Values are MW per tick; gates start 20 ticks apart. The runtime test's SHARE case checks the same
figures in the real game (factory fed, gates' share of the spare power).
"""
import statistics

TICKS = 60 * 30
CASES = [
    ("300 MW factory, 100 spare, 1 gate", 400, 300, 1),
    ("300 MW factory, 200 spare, 1 gate", 500, 300, 1),
    ("300 MW factory, 300 spare, 1 gate", 600, 300, 1),
    ("300 MW factory, 100 spare, 3 gates", 400, 300, 3),
    ("300 MW factory, 200 spare, 3 gates", 500, 300, 3),
    ("300 MW factory, 300 spare, 3 gates", 600, 300, 3),
    ("3 GW factory, 1 GW spare, 3 gates", 4000, 3000, 3),
]


class Policy:
    """Rise by the step on a fully met tick (growing it by `grow` up to `max_step`); on a shortfall cut to
    at most what arrived, less the step or `factor` times the shortfall, but not below `floor` times
    what arrived; reset the step to `min_step`, and hold for `hold` ticks."""

    def __init__(self, name, min_step, max_step, grow, factor, hold, met, floor):
        self.name, self.min_step, self.max_step, self.floor = name, min_step, max_step, floor
        self.grow, self.factor, self.hold, self.met = grow, factor, hold, met

    def init(self):
        return {"request": self.max_step, "step": self.max_step, "hold": 0}

    def update(self, gate, asked, got):
        gate["hold"] = max(0, gate["hold"] - 1)
        if asked > 0 and got < asked * self.met:
            gate["request"] = max(got * self.floor, min(got, gate["request"] - max(gate["step"], self.factor * (asked - got))))
            gate["step"] = self.min_step
            gate["hold"] = self.hold
        elif gate["hold"] == 0:
            gate["request"] = min(1000, gate["request"] + gate["step"])
            gate["step"] = min(self.max_step, gate["step"] * self.grow)


POLICIES = [
    Policy("fixed 50 MW (before)", 50, 50, 1, 4, 60, 0.98, 0),
    Policy("adaptive 10-50 MW (current)", 10, 50, 1.1, 2, 120, 0.999, 0.5),
]


def simulate(policy, supply, factory, gates):
    state = [policy.init() for _ in range(gates)]
    lost, used, wobble, previous = 0.0, [], 0.0, None
    for tick in range(TICKS):
        active = [i for i in range(gates) if tick >= 20 * i]
        asks = [state[i]["request"] if i in active else 0 for i in range(gates)]
        demand = factory + sum(asks)
        ratio = 1.0 if demand <= supply else supply / demand
        lost += factory * (1 - ratio) / 60
        for i in active:
            policy.update(state[i], asks[i], asks[i] * ratio)
        if tick >= TICKS // 2:
            used.append(sum(asks) * ratio)
            if previous is not None:
                wobble += abs(asks[0] - previous)
            previous = asks[0]
    return lost, statistics.mean(used) / (supply - factory), wobble / (TICKS // 2) * 60


if __name__ == "__main__":
    for label, supply, factory, gates in CASES:
        print(f"\n{label}")
        print(f"  {'policy':30} {'factory lost MJ':>15} {'gates use of spare':>19} {'wobble MW/s':>12}")
        for policy in POLICIES:
            lost, use, wobble = simulate(policy, supply, factory, gates)
            print(f"  {policy.name:30} {lost:15.1f} {use:19.2f} {wobble:12.1f}")
