#!/usr/bin/env python3
from __future__ import annotations

import argparse
import math
import statistics
from pathlib import Path
from typing import List, Sequence, Tuple

from generate_eye_movement_svg import (
    clamp,
    color_ramp,
    contiguous_segments,
    draw_rect,
    draw_text,
    map_x,
    map_y,
    moving_average,
    percentile,
    summarize,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate a presentation-slide SVG figure from one Unity eye log."
    )
    parser.add_argument("csv_path", help="Path to the Unity eye log CSV.")
    parser.add_argument(
        "--output",
        default="outputs/eye_movement_slide.svg",
        help="Output SVG path.",
    )
    return parser.parse_args()


def draw_panel(parts: List[str], x: float, y: float, w: float, h: float, title: str, subtitle: str) -> None:
    parts.append(
        f'<rect x="{x:.2f}" y="{y:.2f}" width="{w:.2f}" height="{h:.2f}" rx="26" ry="26" '
        f'fill="#fffaf3" stroke="#d6c9b7" stroke-width="1.2" />'
    )
    draw_text(parts, x + 24, y + 34, title, "panel-title")
    if subtitle:
        draw_text(parts, x + 24, y + 56, subtitle, "panel-subtitle")


def draw_time_panel(
    parts: List[str],
    *,
    x: float,
    y: float,
    w: float,
    h: float,
    title: str,
    color: str,
    times: Sequence[float],
    values: Sequence[float],
    invalid_segments: Sequence[Tuple[float, float]],
    duration: float,
    ylim: Tuple[float, float],
    y_ticks: Sequence[float],
    y_label: str,
    fill_to_zero: bool = False,
    raw_values: Sequence[float] | None = None,
    stride: int = 6,
    raw_stride: int = 8,
) -> None:
    draw_panel(parts, x, y, w, h, title, "")
    cx = x + 54
    cy = y + 52
    cw = w - 76
    ch = h - 82
    x_ticks = [0, 10, 20, 30]

    for start, end in invalid_segments:
        sx = map_x(start, 0, duration, cx, cw)
        ex = map_x(end, 0, duration, cx, cw)
        draw_rect(parts, sx, cy, max(1.0, ex - sx), ch, "invalid")

    for xt in x_ticks:
        gx = map_x(xt, 0, duration, cx, cw)
        parts.append(f'<line class="grid-x" x1="{gx:.2f}" y1="{cy:.2f}" x2="{gx:.2f}" y2="{cy + ch:.2f}" />')
    for yt in y_ticks:
        gy = map_y(yt, ylim[0], ylim[1], cy, ch)
        parts.append(f'<line class="grid-y" x1="{cx:.2f}" y1="{gy:.2f}" x2="{cx + cw:.2f}" y2="{gy:.2f}" />')
        draw_text(parts, cx - 10, gy + 4, f"{yt:g}", "tick", anchor="end")

    zero_inside = ylim[0] < 0 < ylim[1]
    if zero_inside:
        zy = map_y(0, ylim[0], ylim[1], cy, ch)
        parts.append(f'<line class="zero" x1="{cx:.2f}" y1="{zy:.2f}" x2="{cx + cw:.2f}" y2="{zy:.2f}" />')

    def draw_series_lines(points: List[Tuple[float, float]], stroke: str, stroke_width: float, opacity: float) -> None:
        for (x0, y0), (x1, y1) in zip(points, points[1:]):
            parts.append(
                f'<line x1="{x0:.2f}" y1="{y0:.2f}" x2="{x1:.2f}" y2="{y1:.2f}" '
                f'stroke="{stroke}" stroke-width="{stroke_width:.2f}" stroke-linecap="round" opacity="{opacity:.3f}" />'
            )

    if raw_values is not None:
        raw_points = []
        for idx, (t, v) in enumerate(zip(times, raw_values)):
            if idx % raw_stride != 0:
                continue
            if math.isfinite(v):
                raw_points.append((map_x(t, 0, duration, cx, cw), map_y(v, ylim[0], ylim[1], cy, ch)))
        draw_series_lines(raw_points, "#b6c2cf", 1.1, 0.55)

    if fill_to_zero:
        fill_points = []
        baseline_y = map_y(0 if zero_inside else ylim[0], ylim[0], ylim[1], cy, ch)
        for idx, (t, v) in enumerate(zip(times, values)):
            if idx % stride != 0:
                continue
            if math.isfinite(v):
                fill_points.append((map_x(t, 0, duration, cx, cw), map_y(v, ylim[0], ylim[1], cy, ch)))
        if len(fill_points) > 1:
            poly = [(fill_points[0][0], baseline_y)] + fill_points + [(fill_points[-1][0], baseline_y)]
            pts = " ".join(f"{px:.2f},{py:.2f}" for px, py in poly)
            parts.append(f'<polygon points="{pts}" fill="{color}" opacity="0.15" />')

    points = []
    for idx, (t, v) in enumerate(zip(times, values)):
        if idx % stride != 0:
            continue
        if math.isfinite(v):
            points.append((map_x(t, 0, duration, cx, cw), map_y(v, ylim[0], ylim[1], cy, ch)))
    draw_series_lines(points, color, 2.3, 0.98)

    draw_text(parts, cx - 18, cy + ch / 2.0 + 4, y_label, "axis-label", anchor="end")
    for xt in x_ticks:
        gx = map_x(xt, 0, duration, cx, cw)
        draw_text(parts, gx, cy + ch + 18, f"{xt:g}", "tick", anchor="middle")
    draw_text(parts, cx + cw / 2.0, cy + ch + 42, "Time (s)", "axis-label", anchor="middle")


def build_density(valid_xy: Sequence[Tuple[float, float]], xlim: Tuple[float, float], ylim: Tuple[float, float], nx: int, ny: int) -> List[List[int]]:
    counts = [[0 for _ in range(nx)] for _ in range(ny)]
    for hx, vy in valid_xy:
        if not (xlim[0] <= hx <= xlim[1] and ylim[0] <= vy <= ylim[1]):
            continue
        fx = (hx - xlim[0]) / (xlim[1] - xlim[0] + 1e-12)
        fy = (vy - ylim[0]) / (ylim[1] - ylim[0] + 1e-12)
        ix = min(nx - 1, max(0, int(fx * nx)))
        iy = min(ny - 1, max(0, int(fy * ny)))
        counts[ny - 1 - iy][ix] += 1
    return counts


def build_svg(data: dict, source_path: str) -> str:
    width = 1920
    height = 1080
    margin = 70
    header_y = 70
    stats_y = 120
    body_y = 170
    body_h = 840
    left_w = 1080
    gap = 28
    right_x = margin + left_w + gap
    right_w = width - right_x - margin

    times = data["time_sec"]
    horiz = data["horiz_deg"]
    vert = data["vert_deg"]
    speed_raw = data["speed_deg_s"]
    pupil_mean = data["mean_pupil"]
    invalid_segments = contiguous_segments(data["invalid_mask"], times)
    duration = data["duration_sec"]

    horiz_smooth = moving_average(horiz, 25)
    vert_smooth = moving_average(vert, 25)
    speed_smooth = moving_average(speed_raw, 21)
    pupil_smooth = moving_average(pupil_mean, 41)

    h_valid = [v for v in horiz if math.isfinite(v)]
    v_valid = [v for v in vert if math.isfinite(v)]
    speed_valid = [v for v in speed_raw if math.isfinite(v)]
    pupil_valid = [v for v in pupil_mean if math.isfinite(v)]
    valid_xy = [(hx, vy) for hx, vy in zip(horiz, vert) if math.isfinite(hx) and math.isfinite(vy)]

    extent = max(
        7.0,
        abs(percentile(h_valid, 0.01)),
        abs(percentile(h_valid, 0.99)),
        abs(percentile(v_valid, 0.01)),
        abs(percentile(v_valid, 0.99)),
    )
    xlim = (-extent, extent)
    ylim = (-extent, extent)
    speed_hi = max(60.0, percentile(speed_valid, 0.98) * 1.08)
    pupil_lo = percentile(pupil_valid, 0.01) - 0.15
    pupil_hi = percentile(pupil_valid, 0.99) + 0.15

    counts = build_density(valid_xy, xlim, ylim, 34, 26)
    nonzero = [c for row in counts for c in row if c > 0]
    density_hi = max(1, int(percentile(nonzero, 0.95))) if nonzero else 1

    parts: List[str] = []
    parts.append(
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}" role="img" aria-label="Eye movement slide figure">'
    )
    parts.append(
        """
<style>
  .title { font-family: 'Avenir Next', 'Segoe UI', sans-serif; font-size: 34px; font-weight: 700; fill: #1f2937; }
  .subtitle { font-family: 'Avenir Next', 'Segoe UI', sans-serif; font-size: 16px; font-weight: 500; fill: #64748b; }
  .panel-title { font-family: 'Avenir Next', 'Segoe UI', sans-serif; font-size: 22px; font-weight: 700; fill: #1f2937; }
  .panel-subtitle { font-family: 'Avenir Next', 'Segoe UI', sans-serif; font-size: 13px; font-weight: 500; fill: #64748b; }
  .stat-k { font-family: 'Avenir Next', 'Segoe UI', sans-serif; font-size: 12px; font-weight: 600; fill: #64748b; text-transform: uppercase; letter-spacing: 1.2px; }
  .stat-v { font-family: 'Avenir Next', 'Segoe UI', sans-serif; font-size: 24px; font-weight: 700; fill: #1f2937; }
  .tick { font-family: 'Avenir Next', 'Segoe UI', sans-serif; font-size: 12px; font-weight: 500; fill: #64748b; }
  .axis-label { font-family: 'Avenir Next', 'Segoe UI', sans-serif; font-size: 13px; font-weight: 600; fill: #52606d; }
  .grid-x { stroke: #ece3d5; stroke-width: 1; }
  .grid-y { stroke: #e5dac8; stroke-width: 1; }
  .zero { stroke: #8f8a81; stroke-width: 1.4; }
  .crosshair { stroke: #8f8a81; stroke-width: 1.4; }
  .invalid { fill: #9aa8b7; opacity: 0.18; }
  .note { font-family: 'Avenir Next', 'Segoe UI', sans-serif; font-size: 14px; font-weight: 500; fill: #5f6c7b; }
</style>
        """.strip()
    )
    parts.append(f'<rect x="0" y="0" width="{width}" height="{height}" fill="#f5efe6" />')

    draw_text(parts, margin, header_y, "Eye Movements During Stimulus", "title")
    draw_text(
        parts,
        margin,
        header_y + 28,
        f"{Path(source_path).name}  |  binocular combined gaze from Unity eye log  |  video token 0302",
        "subtitle",
    )

    stats = [
        ("Duration", f"{duration:.2f}s"),
        ("Samples", str(len(times))),
        ("Valid Gaze", f"{data['valid_ratio'] * 100:.1f}%"),
        ("Sample Rate", f"{data['sample_rate_hz']:.1f} Hz"),
    ]
    for idx, (label, value) in enumerate(stats):
        sx = margin + idx * 200
        draw_text(parts, sx, stats_y, label, "stat-k")
        draw_text(parts, sx, stats_y + 28, value, "stat-v")

    # Main gaze field panel.
    draw_panel(
        parts,
        margin,
        body_y,
        left_w,
        body_h,
        "Gaze Field",
        "Darker cells show where gaze dwelled longer; colored trajectory moves from early to late in the clip",
    )
    gx = margin + 70
    gy = body_y + 90
    gw = left_w - 120
    gh = body_h - 150
    xticks = [-20, -10, 0, 10, 20]
    yticks = [-20, -10, 0, 10, 20]

    cell_w = gw / 34.0
    cell_h = gh / 26.0
    for row_idx, row in enumerate(counts):
        for col_idx, count in enumerate(row):
            if count <= 0:
                continue
            alpha = clamp(math.sqrt(count / density_hi) * 0.55, 0.05, 0.48)
            fill = "#2b8fad"
            x = gx + col_idx * cell_w
            y = gy + row_idx * cell_h
            parts.append(
                f'<rect x="{x:.2f}" y="{y:.2f}" width="{cell_w + 0.4:.2f}" height="{cell_h + 0.4:.2f}" fill="{fill}" opacity="{alpha:.3f}" />'
            )

    for xt in xticks:
        xx = map_x(xt, xlim[0], xlim[1], gx, gw)
        parts.append(f'<line class="grid-x" x1="{xx:.2f}" y1="{gy:.2f}" x2="{xx:.2f}" y2="{gy + gh:.2f}" />')
        draw_text(parts, xx, gy + gh + 24, f"{xt:g}", "tick", anchor="middle")
    for yt in yticks:
        yy = map_y(yt, ylim[0], ylim[1], gy, gh)
        parts.append(f'<line class="grid-y" x1="{gx:.2f}" y1="{yy:.2f}" x2="{gx + gw:.2f}" y2="{yy:.2f}" />')
        draw_text(parts, gx - 12, yy + 4, f"{yt:g}", "tick", anchor="end")
    parts.append(
        f'<line class="crosshair" x1="{map_x(0, xlim[0], xlim[1], gx, gw):.2f}" y1="{gy:.2f}" x2="{map_x(0, xlim[0], xlim[1], gx, gw):.2f}" y2="{gy + gh:.2f}" />'
    )
    parts.append(
        f'<line class="crosshair" x1="{gx:.2f}" y1="{map_y(0, ylim[0], ylim[1], gy, gh):.2f}" x2="{gx + gw:.2f}" y2="{map_y(0, ylim[0], ylim[1], gy, gh):.2f}" />'
    )
    draw_text(parts, gx + gw / 2.0, gy + gh + 52, "Horizontal gaze angle (deg)", "axis-label", anchor="middle")
    draw_text(parts, gx - 22, gy + gh / 2.0, "Vertical", "axis-label", anchor="end")

    trajectory = [(i, hx, vy) for i, (hx, vy) in enumerate(zip(horiz_smooth, vert_smooth)) if math.isfinite(hx) and math.isfinite(vy)]
    step = 18
    for idx in range(step, len(trajectory), step):
        i0, x0, y0 = trajectory[idx - step]
        i1, x1, y1 = trajectory[idx]
        px0 = map_x(x0, xlim[0], xlim[1], gx, gw)
        py0 = map_y(y0, ylim[0], ylim[1], gy, gh)
        px1 = map_x(x1, xlim[0], xlim[1], gx, gw)
        py1 = map_y(y1, ylim[0], ylim[1], gy, gh)
        frac = i1 / max(1, len(times) - 1)
        parts.append(
            f'<line x1="{px0:.2f}" y1="{py0:.2f}" x2="{px1:.2f}" y2="{py1:.2f}" stroke="{color_ramp(frac)}" stroke-width="1.9" stroke-linecap="round" opacity="0.45" />'
        )

    for mark_sec in [0, 10, 20, 30]:
        best_idx = min(range(len(times)), key=lambda i: abs(times[i] - mark_sec))
        hx = horiz_smooth[best_idx]
        vy = vert_smooth[best_idx]
        if not (math.isfinite(hx) and math.isfinite(vy)):
            continue
        px = map_x(hx, xlim[0], xlim[1], gx, gw)
        py = map_y(vy, ylim[0], ylim[1], gy, gh)
        parts.append(f'<circle cx="{px:.2f}" cy="{py:.2f}" r="7.5" fill="#fffaf2" stroke="#111827" stroke-width="2.2" />')
        draw_text(parts, px, py + 4, str(mark_sec), "tick", anchor="middle")

    legend_x = gx + 12
    legend_y = gy + gh + 74
    draw_text(parts, legend_x, legend_y, "Early", "tick")
    for i in range(70):
        xx = legend_x + 48 + i * 3.5
        parts.append(
            f'<line x1="{xx:.2f}" y1="{legend_y - 6:.2f}" x2="{xx:.2f}" y2="{legend_y + 8:.2f}" stroke="{color_ramp(i / 69.0)}" stroke-width="3" />'
        )
    draw_text(parts, legend_x + 310, legend_y, "Late", "tick")

    # Right-side single-signal panels.
    small_h = (body_h - 3 * 18) / 4.0
    blue = "#1768ac"
    orange = "#d95d39"
    teal = "#0f766e"
    charcoal = "#30363d"

    draw_time_panel(
        parts,
        x=right_x,
        y=body_y,
        w=right_w,
        h=small_h,
        title="Horizontal Gaze",
        color=blue,
        times=times,
        values=horiz_smooth,
        invalid_segments=invalid_segments,
        duration=duration,
        ylim=xlim,
        y_ticks=[-20, -10, 0, 10, 20],
        y_label="deg",
        fill_to_zero=False,
        raw_values=None,
        stride=8,
    )
    draw_time_panel(
        parts,
        x=right_x,
        y=body_y + small_h + 18,
        w=right_w,
        h=small_h,
        title="Vertical Gaze",
        color=orange,
        times=times,
        values=vert_smooth,
        invalid_segments=invalid_segments,
        duration=duration,
        ylim=ylim,
        y_ticks=[-20, -10, 0, 10, 20],
        y_label="deg",
        fill_to_zero=False,
        raw_values=None,
        stride=8,
    )
    draw_time_panel(
        parts,
        x=right_x,
        y=body_y + 2 * (small_h + 18),
        w=right_w,
        h=small_h,
        title="Angular Speed",
        color=teal,
        times=times,
        values=speed_smooth,
        invalid_segments=invalid_segments,
        duration=duration,
        ylim=(0, speed_hi),
        y_ticks=[0, 100, 200, 300],
        y_label="deg/s",
        fill_to_zero=True,
        raw_values=speed_raw,
        stride=5,
        raw_stride=10,
    )
    draw_time_panel(
        parts,
        x=right_x,
        y=body_y + 3 * (small_h + 18),
        w=right_w,
        h=small_h,
        title="Mean Pupil Diameter",
        color=charcoal,
        times=times,
        values=pupil_smooth,
        invalid_segments=invalid_segments,
        duration=duration,
        ylim=(pupil_lo, pupil_hi),
        y_ticks=[round(pupil_lo, 1), round((pupil_lo + pupil_hi) / 2.0, 1), round(pupil_hi, 1)],
        y_label="mm",
        fill_to_zero=False,
        raw_values=None,
        stride=10,
    )

    draw_text(
        parts,
        margin,
        height - 28,
        "Shaded bands mark invalid combined-gaze samples. Horizontal and vertical traces are separated to keep the slide legible.",
        "note",
    )
    parts.append("</svg>")
    return "\n".join(parts)


def main() -> None:
    args = parse_args()
    data = summarize(args.csv_path)
    svg = build_svg(data, args.csv_path)
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(svg, encoding="utf-8")
    print(f"Wrote {output_path}")


if __name__ == "__main__":
    main()
