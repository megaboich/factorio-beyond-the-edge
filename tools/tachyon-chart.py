#!/usr/bin/env python3
"""Generates warp-drive/docs/tachyon-density-chart.svg for the Warp Drive README.

Draws the final-stretch tachyon density curve (Solar System Edge to Shattered Planet,
4,000,000 km) using the same non-linear horizontal axis (u = t^3) and density formula
as the in-game Tachyon Detector tab.
"""
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "warp-drive" / "docs" / "tachyon-density-chart.svg"

FINAL_LENGTH_KM = 4_000_000
DENSITY_EDGE = 100.0
DENSITY_MAX = 10_000.0
CURVE_EXPONENT = 1.4
CURVE_K = 1.0 / 16.0
X_AXIS_EXPONENT = 3.0


def final_stretch_density(u: float) -> float:
    u = max(0.0, min(1.0, u))
    if u <= 0.0:
        return DENSITY_EDGE
    if u >= 1.0:
        return DENSITY_MAX
    up = u ** CURVE_EXPONENT
    shaped = ((1.0 + CURVE_K) * up) / (up + CURVE_K)
    return DENSITY_EDGE + (DENSITY_MAX - DENSITY_EDGE) * shaped


def generate_svg() -> str:
    width, height = 720, 250
    pad_l, pad_r, pad_t, pad_b = 76, 36, 36, 58
    plot_w = width - pad_l - pad_r
    plot_h = height - pad_t - pad_b
    inner_top = pad_t + 14
    inner_bottom = pad_t + plot_h - 6
    inner_h = inner_bottom - inner_top

    def x_for_t(t: float) -> float:
        return pad_l + t * plot_w

    def y_for_d(d: float) -> float:
        return inner_bottom - inner_h * (d / DENSITY_MAX)

    # Sample the smooth curve across t in [0, 1].
    steps = 160
    pts = []
    for i in range(steps + 1):
        t = i / steps
        u = t ** X_AXIS_EXPONENT
        d = final_stretch_density(u)
        pts.append((x_for_t(t), y_for_d(d)))

    polyline = " ".join(f"{x:.1f},{y:.1f}" for x, y in pts)
    area = (
        f"M {pts[0][0]:.1f},{inner_bottom:.1f} "
        + " ".join(f"L {x:.1f},{y:.1f}" for x, y in pts)
        + f" L {pts[-1][0]:.1f},{inner_bottom:.1f} Z"
    )

    milestones = [
        (0, "0 km", "Solar System Edge", "100", "start", 6, -8),
        (100_000, "100k km", None, "~1,000", "middle", 0, -10),
        (500_000, "500k km", None, "~5,000", "middle", 0, -10),
        (2_000_000, "2M km", None, "~9,100", "middle", 0, 16),
        (4_000_000, "4M km", "Shattered Planet", "10,000", "end", -6, 16),
    ]

    y_ticks = [
        (0, "0"),
        (1_000, "1,000"),
        (5_000, "5,000"),
        (10_000, "10,000"),
    ]

    lines = [
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" width="{width}" height="{height}" font-family="-apple-system, BlinkMacSystemFont, \'Segoe UI\', Helvetica, Arial, sans-serif" font-size="12">',
        '  <defs>',
        '    <linearGradient id="curveFill" x1="0" y1="0" x2="0" y2="1">',
        '      <stop offset="0%" stop-color="#40bfff" stop-opacity="0.28"/>',
        '      <stop offset="100%" stop-color="#40bfff" stop-opacity="0.02"/>',
        '    </linearGradient>',
        '  </defs>',
        f'  <rect width="{width}" height="{height}" rx="6" fill="#232528" stroke="#3a3d42" stroke-width="1.5"/>',
        f'  <text x="{pad_l}" y="23" fill="#dcdcdc" font-weight="600" font-size="13">Final route tachyon density curve (particles/s vs. non-linear distance past Solar System Edge)</text>',
        f'  <rect x="{pad_l}" y="{pad_t}" width="{plot_w}" height="{plot_h}" rx="3" fill="#14171a" stroke="#0c0e10" stroke-width="1.5"/>',
    ]

    for d_val, label in y_ticks:
        y = y_for_d(d_val)
        lines.append(
            f'  <line x1="{pad_l}" y1="{y:.1f}" x2="{pad_l + plot_w}" y2="{y:.1f}" stroke="#272c33" stroke-width="1" stroke-dasharray="3,3"/>'
        )
        lines.append(
            f'  <text x="{pad_l - 8}" y="{y + 4:.1f}" fill="#9aa0a6" text-anchor="end" font-size="11">{label}</text>'
        )

    for km, dist_label, dest_label, _, anchor, _, _ in milestones:
        u = km / FINAL_LENGTH_KM
        t = u ** (1.0 / X_AXIS_EXPONENT) if u > 0 else 0.0
        x = x_for_t(t)
        lines.append(
            f'  <line x1="{x:.1f}" y1="{pad_t}" x2="{x:.1f}" y2="{pad_t + plot_h}" stroke="#272c33" stroke-width="1" stroke-dasharray="3,3"/>'
        )
        lines.append(
            f'  <text x="{x:.1f}" y="{pad_t + plot_h + 18}" fill="#c8cdd3" text-anchor="{anchor}" font-size="11">{dist_label}</text>'
        )
        if dest_label:
            lines.append(
                f'  <text x="{x:.1f}" y="{pad_t + plot_h + 34}" fill="#8a9099" text-anchor="{anchor}" font-size="11">{dest_label}</text>'
            )

    lines.append(f'  <path d="{area}" fill="url(#curveFill)"/>')
    lines.append(
        f'  <polyline fill="none" stroke="#40bfff" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" points="{polyline}"/>'
    )

    for km, _, _, density_label, anchor, dx, dy in milestones:
        u = km / FINAL_LENGTH_KM
        t = u ** (1.0 / X_AXIS_EXPONENT) if u > 0 else 0.0
        d = final_stretch_density(u)
        x, y = x_for_t(t), y_for_d(d)
        dot_color = "#ffe040" if km == 500_000 else "#40bfff"
        lines.append(
            f'  <circle cx="{x:.1f}" cy="{y:.1f}" r="4.2" fill="{dot_color}" stroke="#14171a" stroke-width="1.5"/>'
        )
        lines.append(
            f'  <text x="{x + dx:.1f}" y="{y + dy:.1f}" fill="{dot_color}" text-anchor="{anchor}" font-weight="600" font-size="11">{density_label} p/s</text>'
        )

    lines.append("</svg>\n")
    return "\n".join(lines)


def main() -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(generate_svg())
    print(f"wrote {OUT.relative_to(REPO)}")


if __name__ == "__main__":
    main()
