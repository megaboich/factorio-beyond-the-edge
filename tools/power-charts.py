"""Draws the charts in docs/power/ from the power bank's rules (warp-drive/scripts/power_bank.lua).

Run: python3 tools/power-charts.py

Each chart is a small tick-by-tick simulation of the same rules the mods run: the store leaks
0.5 % of its charge a second, takes in all that arrives, activation spends 80 % of a full store, the draw is capped at the
load, the leak, and a refill allowance, and the adaptive request climbs in 10-50 MW steps and backs
off on shortfalls. Output is deterministic, so rerunning over unchanged sources leaves git clean.
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs", "power")
TPS = 60
LEAK = 0.005
ACTIVATION = 0.8
MIN_STEP, MAX_STEP, GROWTH, FACTOR, HOLD, MET = 10e6, 50e6, 1.1, 2, 120, 0.999

INK = "#1f2328"
MUTED = "#656d76"
GRID = "#d0d7de"
COLORS = ["#0969da", "#cf222e", "#1a7f37", "#8250df", "#bf8700"]


class Bank:
    """PowerBank.tick, condensed: one tick, given what the network delivers for a request."""

    def __init__(self):
        self.charge, self.request, self.step, self.hold, self.applied = 0.0, MAX_STEP, MAX_STEP, 0, 0.0

    def ask(self, capacity, load, max_draw, sink=False):
        room = float("inf") if sink else ((capacity - self.charge) * TPS + load + self.charge * LEAK)
        self.applied = max(0.0, min(self.request, max_draw, room))
        return self.applied

    def receive(self, capacity, load, got, tick, sink=False):
        if not sink:
            self.charge = max(0.0, min(capacity, self.charge - (load + self.charge * LEAK) / TPS
                                       + got / TPS))
        asked = self.applied
        if asked > 1:
            if got < asked * MET:
                self.request = max(got / 2, min(got, self.request - max(self.step, FACTOR * (asked - got))))
                self.step = MIN_STEP
                self.hold = tick + HOLD if got > 0 else 0
            elif tick >= self.hold and self.applied >= self.request:
                self.request += self.step
                self.step = min(MAX_STEP, self.step * GROWTH)
        elif self.request < MIN_STEP:
            self.request = MIN_STEP


def share(supply, factory, asks):
    """Factorio's rule for machine-priority consumers: everyone gets the same fraction."""
    demand = factory + sum(asks)
    ratio = 1.0 if demand <= supply else supply / demand
    return ratio, [a * ratio for a in asks]


# --- simulations -------------------------------------------------------------------------------

def stargate_cycle():
    """A gate on a network with 1.5 GW to spare: charges closed, opens when full at 15 s, stays open."""
    capacity, upkeep, charge_rate, refill = 10e9, 1e9, 1e9, 200e6
    bank, opened = Bank(), False
    rows = []
    for tick in range(int(75 * TPS)):
        if not opened and bank.charge >= capacity * 0.999 and tick >= 15 * TPS:
            bank.charge = capacity * (1 - ACTIVATION)
            bank.step, bank.hold = MAX_STEP, 0
            opened = True
        load = upkeep if opened else 0
        allowance = refill if opened else charge_rate
        ask = bank.ask(capacity, load, (load + capacity * LEAK + allowance))
        _, (got,) = share(1.5e9 + 300e6, 300e6, [ask])
        bank.receive(capacity, load, got, tick)
        rows.append((tick / TPS, got / 1e6, bank.charge / capacity * 100, opened))
    return rows


def warp_cycle():
    """A 10,000 t ship (1 GJ reserve, 100 MW a level) with ample power: charge, jump, climb to Warp-5."""
    mass = 10_000_000
    capacity, per_level, refill = 100 * mass, 10 * mass, 10 * mass
    bank, state, level, jump = Bank(), "charging", 0.0, None
    rows = []
    for tick in range(int(45 * TPS)):
        if tick % 10 == 0 and state == "charging" and bank.charge + 1 >= capacity:
            bank.charge = capacity * (1 - ACTIVATION)
            bank.step, bank.hold = MAX_STEP, 0
            state, level, jump = "warp", 1.0, tick
        # The drive holds Warp-1 for its two stabilizing updates, then climbs half a level a second.
        elif tick % 10 == 0 and state == "warp" and tick >= jump + 20:
            level = min(5.0, level + 10 / TPS / 2)
        load = per_level * level if state == "warp" else 0
        top = per_level * min(5.0, level + 10 / TPS / 2) if state == "warp" else 0
        ask = bank.ask(capacity, load, (top + capacity * LEAK + refill))
        _, (got,) = share(2e9, 0, [ask])
        bank.receive(capacity, load, got, tick)
        rows.append((tick / TPS, got / 1e6, bank.charge / capacity * 100, level))
    return rows


def shared_gates():
    """Three gates, starting a third of a second apart, beside a 300 MW factory with 200 MW spare."""
    capacity = 10e9
    banks = [Bank() for _ in range(3)]
    rows = []
    for tick in range(int(12 * TPS)):
        asks = []
        for i, bank in enumerate(banks):
            asks.append(bank.ask(capacity, 0, 1.05e9) if tick >= 20 * i else 0.0)
        ratio, gots = share(500e6, 300e6, asks)
        for i, bank in enumerate(banks):
            if tick >= 20 * i:
                bank.receive(capacity, 0, gots[i], tick)
        rows.append((tick / TPS, [g / 1e6 for g in gots], ratio * 100))
    return rows


# --- SVG ---------------------------------------------------------------------------------------

class Chart:
    def __init__(self, title, width=760):
        self.title, self.width, self.parts, self.height = title, width, [], 40

    def panel(self, x_max, y_max, y_label, series, height=200, x_label=None, bands=(), y_ticks=None,
              x_step=5, legend=True, y_min=0):
        left, right, top = 64, self.width - 20, self.height + 14
        bottom = top + height
        sx = lambda x: left + (right - left) * x / x_max
        sy = lambda y: bottom - height * (y - y_min) / (y_max - y_min)
        out = []
        for x0, x1, label in bands:
            out.append(f'<rect x="{sx(x0):.1f}" y="{top}" width="{sx(x1) - sx(x0):.1f}" height="{height}" '
                       f'fill="#f6f8fa"/>')
            out.append(f'<text x="{(sx(x0) + sx(x1)) / 2:.1f}" y="{top + 14}" text-anchor="middle" '
                       f'fill="{MUTED}" font-size="11">{label}</text>')
        for y in (y_ticks or [y_min + (y_max - y_min) * i / 4 for i in range(5)]):
            out.append(f'<line x1="{left}" x2="{right}" y1="{sy(y):.1f}" y2="{sy(y):.1f}" stroke="{GRID}"/>')
            out.append(f'<text x="{left - 6}" y="{sy(y) + 4:.1f}" text-anchor="end" fill="{MUTED}" '
                       f'font-size="11">{y:g}</text>')
        x = 0
        while x <= x_max + 1e-9:
            out.append(f'<text x="{sx(x):.1f}" y="{bottom + 16}" text-anchor="middle" fill="{MUTED}" '
                       f'font-size="11">{x:g}</text>')
            x += x_step
        out.append(f'<line x1="{left}" x2="{right}" y1="{bottom}" y2="{bottom}" stroke="{INK}"/>')
        out.append(f'<text transform="translate(16 {(top + bottom) / 2:.1f}) rotate(-90)" text-anchor="middle" '
                   f'fill="{INK}" font-size="12">{y_label}</text>')
        if x_label:
            out.append(f'<text x="{(left + right) / 2:.1f}" y="{bottom + 34}" text-anchor="middle" '
                       f'fill="{INK}" font-size="12">{x_label}</text>')
        lx = left + 8
        for i, (name, points, dash) in enumerate(series):
            color = COLORS[i % len(COLORS)]
            # Keep every point where the line turns; drop the rest of each straight run.
            kept = []
            for p in points:
                if len(kept) >= 2:
                    (x0, y0), (x1, y1) = kept[-2], kept[-1]
                    if abs((y1 - y0) * (p[0] - x1) - (p[1] - y1) * (x1 - x0)) < 1e-6 * y_max:
                        kept[-1] = p
                        continue
                kept.append(p)
            path = " ".join(f"{sx(px):.1f},{sy(max(y_min, min(py, y_max))):.1f}" for px, py in kept)
            extra = ' stroke-dasharray="5 4"' if dash else ""
            out.append(f'<polyline points="{path}" fill="none" stroke="{color}" stroke-width="2"{extra}/>')
            if legend:
                out.append(f'<line x1="{lx}" x2="{lx + 18}" y1="{top + 30}" y2="{top + 30}" stroke="{color}" '
                           f'stroke-width="2"{extra}/>')
                out.append(f'<text x="{lx + 22}" y="{top + 34}" fill="{INK}" font-size="11">{name}</text>')
                lx += 30 + 6.2 * len(name)
        self.parts.extend(out)
        self.height = bottom + (44 if x_label else 26)

    def write(self, name):
        body = "\n".join(self.parts)
        svg = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {self.width} {self.height}" '
               f'width="{self.width}" height="{self.height}" font-family="-apple-system, Segoe UI, Helvetica, Arial, sans-serif">\n'
               f'<rect width="100%" height="100%" fill="#ffffff"/>\n'
               f'<text x="20" y="26" fill="{INK}" font-size="15" font-weight="600">{self.title}</text>\n'
               f'{body}\n</svg>\n')
        with open(os.path.join(OUT, name), "w") as f:
            f.write(svg)


def main():
    os.makedirs(OUT, exist_ok=True)

    rows = stargate_cycle()
    opened = next(t for t, _, _, o in rows if o)
    chart = Chart("Stargate: charge closed, open, refill while open (1.5 GW to spare)")
    bands = [(0, opened, "closed: charging"), (opened, 75, "open: 1 GW upkeep from the store")]
    chart.panel(75, 1400, "Draw (MW)", [("draw from the network", [(t, d) for t, d, _, _ in rows], False)],
                bands=bands, y_ticks=[0, 250, 500, 750, 1050, 1250], x_step=5)
    chart.panel(75, 100, "Store (%)", [("store charge", [(t, c) for t, _, c, _ in rows], False)],
                bands=bands, x_label="Seconds", x_step=5)
    chart.write("stargate-cycle.svg")

    rows = warp_cycle()
    jumped = next(t for t, _, _, lvl in rows if lvl >= 1)
    chart = Chart("Warp Drive, 10,000 t ship: charge, jump, climb to Warp-5 (ample power)")
    bands = [(0, jumped, "charging"), (jumped, 45, "warp: level support from the store")]
    chart.panel(45, 700, "Draw (MW)", [
        ("draw from the network", [(t, d) for t, d, _, _ in rows], False),
        ("level support (load)", [(t, lvl * 100) for t, _, _, lvl in rows], True)],
        bands=bands, y_ticks=[0, 105, 200, 300, 400, 505, 700], x_step=5)
    chart.panel(45, 100, "Reserve (%)", [("reserve charge", [(t, c) for t, _, c, _ in rows], False)],
                bands=bands, x_label="Seconds", x_step=5)
    chart.write("warp-drive-cycle.svg")

    rows = shared_gates()
    chart = Chart("Three gates charging beside a 300 MW factory with 200 MW to spare")
    chart.panel(12, 250, "Gate draw (MW)", [
        (f"gate {i + 1}", [(t, g[i]) for t, g, _ in rows], False) for i in range(3)],
        y_ticks=[0, 50, 100, 150, 200, 250], x_step=1)
    chart.panel(12, 100, "Factory power (%)", [("factory satisfaction", [(t, r) for t, _, r in rows], False)],
                y_ticks=[85, 90, 95, 100], x_label="Seconds", x_step=1, y_min=85, height=140)
    chart.write("shared-gates.svg")


if __name__ == "__main__":
    main()
