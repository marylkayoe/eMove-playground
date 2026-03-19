#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import math
import os
import statistics
from pathlib import Path
from typing import Iterable, List, Sequence, Tuple


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate an SVG figure summarizing eye movements from one Unity eye log."
    )
    parser.add_argument("csv_path", help="Path to the Unity eye log CSV.")
    parser.add_argument(
        "--output",
        default="outputs/eye_movement_summary.svg",
        help="Output SVG path.",
    )
    return parser.parse_args()


def parse_float(value: str) -> float:
    value = (value or "").strip()
    if not value:
        return float("nan")
    return float(value.replace(",", "."))


def parse_vec3(value: str) -> Tuple[float, float, float]:
    value = (value or "").strip()
    if not value:
        return (float("nan"), float("nan"), float("nan"))
    value = value.strip("()")
    parts = [part.strip() for part in value.split(",")]
    if len(parts) != 3:
        return (float("nan"), float("nan"), float("nan"))
    return tuple(parse_float(part) for part in parts)  # type: ignore[return-value]


def is_finite(*values: float) -> bool:
    return all(math.isfinite(v) for v in values)


def percentile(values: Sequence[float], q: float) -> float:
    clean = sorted(v for v in values if math.isfinite(v))
    if not clean:
        return float("nan")
    if len(clean) == 1:
        return clean[0]
    pos = (len(clean) - 1) * q
    lo = int(math.floor(pos))
    hi = int(math.ceil(pos))
    if lo == hi:
        return clean[lo]
    frac = pos - lo
    return clean[lo] * (1.0 - frac) + clean[hi] * frac


def clamp(value: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, value))


def moving_average(values: Sequence[float], window: int) -> List[float]:
    radius = max(0, window // 2)
    out: List[float] = []
    for idx in range(len(values)):
        lo = max(0, idx - radius)
        hi = min(len(values), idx + radius + 1)
        local = [v for v in values[lo:hi] if math.isfinite(v)]
        out.append(sum(local) / len(local) if local else float("nan"))
    return out


def contiguous_segments(mask: Sequence[bool], times: Sequence[float]) -> List[Tuple[float, float]]:
    segments: List[Tuple[float, float]] = []
    start = None
    prev_time = None
    for flag, t in zip(mask, times):
        if flag and start is None:
            start = t
        if flag:
            prev_time = t
        elif start is not None and prev_time is not None:
            segments.append((start, prev_time))
            start = None
            prev_time = None
    if start is not None and prev_time is not None:
        segments.append((start, prev_time))
    return segments


def angle_from_forward(vec: Tuple[float, float, float]) -> Tuple[float, float]:
    x, y, z = vec
    if not is_finite(x, y, z) or z <= 0:
        return (float("nan"), float("nan"))
    horiz = math.degrees(math.atan2(x, z))
    vert = math.degrees(math.atan2(y, z))
    return horiz, vert


def angular_speed_deg_per_s(
    prev_vec: Tuple[float, float, float],
    curr_vec: Tuple[float, float, float],
    dt_sec: float,
) -> float:
    if dt_sec <= 0 or not is_finite(*prev_vec, *curr_vec):
        return float("nan")
    ax, ay, az = prev_vec
    bx, by, bz = curr_vec
    amag = math.sqrt(ax * ax + ay * ay + az * az)
    bmag = math.sqrt(bx * bx + by * by + bz * bz)
    if amag == 0 or bmag == 0:
        return float("nan")
    dot = (ax * bx + ay * by + az * bz) / (amag * bmag)
    dot = clamp(dot, -1.0, 1.0)
    return math.degrees(math.acos(dot)) / dt_sec


def fmt(value: float, digits: int = 2) -> str:
    return f"{value:.{digits}f}" if math.isfinite(value) else "NA"


def svg_escape(text: str) -> str:
    return (
        str(text)
        .replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    )


def color_ramp(t: float) -> str:
    t = clamp(t, 0.0, 1.0)
    anchors = [
        (20, 34, 77),
        (33, 97, 140),
        (73, 169, 169),
        (255, 195, 113),
        (214, 93, 14),
    ]
    span = t * (len(anchors) - 1)
    idx = min(len(anchors) - 2, int(span))
    frac = span - idx
    c0 = anchors[idx]
    c1 = anchors[idx + 1]
    rgb = tuple(int(round(a * (1.0 - frac) + b * frac)) for a, b in zip(c0, c1))
    return "#%02x%02x%02x" % rgb


def map_x(value: float, lo: float, hi: float, x: float, width: float) -> float:
    if not math.isfinite(value):
        return x
    if hi <= lo:
        return x + width / 2.0
    return x + (value - lo) * width / (hi - lo)


def map_y(value: float, lo: float, hi: float, y: float, height: float) -> float:
    if not math.isfinite(value):
        return y + height / 2.0
    if hi <= lo:
        return y + height / 2.0
    return y + height - (value - lo) * height / (hi - lo)


def draw_rect(parts: List[str], x: float, y: float, width: float, height: float, klass: str) -> None:
    parts.append(
        f'<rect class="{klass}" x="{x:.2f}" y="{y:.2f}" width="{width:.2f}" height="{height:.2f}" />'
    )


def draw_text(parts: List[str], x: float, y: float, text: str, klass: str, anchor: str = "start") -> None:
    parts.append(
        f'<text class="{klass}" x="{x:.2f}" y="{y:.2f}" text-anchor="{anchor}">{svg_escape(text)}</text>'
    )


def draw_polyline(
    parts: List[str],
    points: Iterable[Tuple[float, float]],
    stroke: str,
    stroke_width: float,
    opacity: float = 1.0,
) -> None:
    pts = " ".join(f"{x:.2f},{y:.2f}" for x, y in points)
    if not pts:
        return
    parts.append(
        f'<polyline fill="none" stroke="{stroke}" stroke-width="{stroke_width:.2f}" '
        f'stroke-linejoin="round" stroke-linecap="round" opacity="{opacity:.3f}" points="{pts}" />'
    )


def draw_panel_background(parts: List[str], x: float, y: float, width: float, height: float, title: str, subtitle: str) -> None:
    draw_rect(parts, x, y, width, height, "panel")
    draw_text(parts, x + 18, y + 28, title, "panel-title")
    draw_text(parts, x + 18, y + 48, subtitle, "panel-subtitle")


def draw_grid(
    parts: List[str],
    x: float,
    y: float,
    width: float,
    height: float,
    xticks: Sequence[float],
    yticks: Sequence[float],
    xlim: Tuple[float, float],
    ylim: Tuple[float, float],
) -> None:
    for xt in xticks:
        gx = map_x(xt, xlim[0], xlim[1], x, width)
        parts.append(f'<line class="grid" x1="{gx:.2f}" y1="{y:.2f}" x2="{gx:.2f}" y2="{y + height:.2f}" />')
    for yt in yticks:
        gy = map_y(yt, ylim[0], ylim[1], y, height)
        parts.append(f'<line class="grid" x1="{x:.2f}" y1="{gy:.2f}" x2="{x + width:.2f}" y2="{gy:.2f}" />')


def build_svg(data: dict, source_path: str) -> str:
    width = 1600
    height = 1200
    left = 70
    top = 160
    gutter = 28
    panel_w = (width - 2 * left - gutter) / 2.0
    panel_h = 420
    bottom_panel_y = top + panel_h + gutter

    duration = data["duration_sec"]
    valid_ratio = data["valid_ratio"]
    sample_rate = data["sample_rate_hz"]
    horiz = data["horiz_deg"]
    vert = data["vert_deg"]
    speed = data["speed_deg_s"]
    speed_smoothed = data["speed_smooth"]
    pupil_l = data["left_pupil"]
    pupil_r = data["right_pupil"]
    pupil_mean = data["mean_pupil"]
    times = data["time_sec"]
    invalid_mask = data["invalid_mask"]
    invalid_segments = contiguous_segments(invalid_mask, times)

    h_valid = [v for v in horiz if math.isfinite(v)]
    v_valid = [v for v in vert if math.isfinite(v)]
    speed_valid = [v for v in speed if math.isfinite(v)]
    pupil_valid = [v for v in pupil_mean if math.isfinite(v)]

    xy_extent = max(
        6.0,
        abs(percentile(h_valid, 0.01)),
        abs(percentile(h_valid, 0.99)),
        abs(percentile(v_valid, 0.01)),
        abs(percentile(v_valid, 0.99)),
    )
    xy_lim = (-xy_extent, xy_extent)
    speed_hi = max(40.0, percentile(speed_valid, 0.99) * 1.05)
    pupil_lo = min(percentile(pupil_valid, 0.01) - 0.2, statistics.fmean(pupil_valid) - 1.8)
    pupil_hi = max(percentile(pupil_valid, 0.99) + 0.2, statistics.fmean(pupil_valid) + 1.8)
    time_ticks = [0, 5, 10, 15, 20, 25, 30]

    parts: List[str] = []
    parts.append(
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
        f'viewBox="0 0 {width} {height}" role="img" aria-label="Eye movement summary figure">'
    )
    parts.append(
        """
<style>
  .bg { fill: #f4efe7; }
  .panel { fill: #fffaf2; stroke: #d9cdbb; stroke-width: 1.4; rx: 18; ry: 18; }
  .header-rule { stroke: #d9cdbb; stroke-width: 1.2; }
  .grid { stroke: #eadfce; stroke-width: 1.0; }
  .axis { stroke: #8a7d6c; stroke-width: 1.2; }
  .invalid { fill: #c7ced6; opacity: 0.18; }
  .title { font-family: 'SF Pro Display', 'Segoe UI', sans-serif; font-size: 28px; font-weight: 700; fill: #1d2733; }
  .subtitle { font-family: 'SF Pro Text', 'Segoe UI', sans-serif; font-size: 15px; font-weight: 500; fill: #52606d; }
  .panel-title { font-family: 'SF Pro Display', 'Segoe UI', sans-serif; font-size: 18px; font-weight: 700; fill: #1f2a37; }
  .panel-subtitle { font-family: 'SF Pro Text', 'Segoe UI', sans-serif; font-size: 13px; font-weight: 500; fill: #64748b; }
  .label { font-family: 'SF Pro Text', 'Segoe UI', sans-serif; font-size: 12px; font-weight: 500; fill: #5b6470; }
  .small { font-family: 'SF Pro Text', 'Segoe UI', sans-serif; font-size: 11px; font-weight: 500; fill: #64748b; }
  .stat-k { font-family: 'SF Pro Text', 'Segoe UI', sans-serif; font-size: 12px; font-weight: 500; fill: #5b6470; }
  .stat-v { font-family: 'SF Pro Display', 'Segoe UI', sans-serif; font-size: 18px; font-weight: 700; fill: #1f2a37; }
</style>
        """.strip()
    )
    draw_rect(parts, 0, 0, width, height, "bg")
    draw_text(parts, left, 52, "Unity Eye Movement Summary", "title")
    draw_text(
        parts,
        left,
        78,
        f"{Path(source_path).name}  |  video token 0302 (NEUTRAL)  |  combined gaze projected into viewing-angle space",
        "subtitle",
    )
    parts.append(f'<line class="header-rule" x1="{left:.2f}" y1="95" x2="{width - left:.2f}" y2="95" />')

    stats = [
        ("Duration", f"{duration:.2f}s"),
        ("Samples", str(len(times))),
        ("Rate", f"{sample_rate:.1f} Hz"),
        ("Valid gaze", f"{valid_ratio * 100.0:.1f}%"),
        ("Speed p95", f"{percentile(speed_valid, 0.95):.1f} deg/s"),
        ("Mean pupil", f"{statistics.fmean(pupil_valid):.2f} mm"),
    ]
    for idx, (label, value) in enumerate(stats):
        x = left + idx * 170
        draw_text(parts, x, 110, label, "stat-k")
        draw_text(parts, x, 132, value, "stat-v")

    # Panel 1: gaze trajectory in angular space.
    p1x, p1y = left, top
    draw_panel_background(
        parts,
        p1x,
        p1y,
        panel_w,
        panel_h,
        "Gaze Position Cloud",
        "Combined gaze direction mapped to horizontal and vertical viewing angles",
    )
    chart_x = p1x + 58
    chart_y = p1y + 72
    chart_w = panel_w - 92
    chart_h = panel_h - 110
    xy_ticks = [-20, -10, 0, 10, 20]
    draw_grid(parts, chart_x, chart_y, chart_w, chart_h, xy_ticks, xy_ticks, xy_lim, xy_lim)
    parts.append(
        f'<line class="axis" x1="{chart_x:.2f}" y1="{map_y(0, xy_lim[0], xy_lim[1], chart_y, chart_h):.2f}" '
        f'x2="{chart_x + chart_w:.2f}" y2="{map_y(0, xy_lim[0], xy_lim[1], chart_y, chart_h):.2f}" />'
    )
    parts.append(
        f'<line class="axis" x1="{map_x(0, xy_lim[0], xy_lim[1], chart_x, chart_w):.2f}" y1="{chart_y:.2f}" '
        f'x2="{map_x(0, xy_lim[0], xy_lim[1], chart_x, chart_w):.2f}" y2="{chart_y + chart_h:.2f}" />'
    )
    draw_text(parts, chart_x + chart_w / 2.0, p1y + panel_h - 18, "Horizontal angle (deg)", "label", anchor="middle")
    draw_text(parts, p1x + 18, chart_y + chart_h / 2.0, "Vertical angle (deg)", "label")
    for tick in xy_ticks:
        tx = map_x(tick, xy_lim[0], xy_lim[1], chart_x, chart_w)
        ty = map_y(tick, xy_lim[0], xy_lim[1], chart_y, chart_h)
        draw_text(parts, tx, chart_y + chart_h + 18, str(tick), "small", anchor="middle")
        draw_text(parts, chart_x - 12, ty + 4, str(tick), "small", anchor="end")

    valid_points = [
        (idx, hx, vy)
        for idx, (hx, vy, inv) in enumerate(zip(horiz, vert, invalid_mask))
        if math.isfinite(hx) and math.isfinite(vy) and not inv
    ]
    for idx, hx, vy in valid_points[::3]:
        frac = idx / max(1, len(times) - 1)
        cx = map_x(hx, xy_lim[0], xy_lim[1], chart_x, chart_w)
        cy = map_y(vy, xy_lim[0], xy_lim[1], chart_y, chart_h)
        radius = 1.8 + 1.6 * frac
        color = color_ramp(frac)
        parts.append(
            f'<circle cx="{cx:.2f}" cy="{cy:.2f}" r="{radius:.2f}" fill="{color}" opacity="0.27" />'
        )
    draw_text(parts, chart_x, p1y + panel_h - 18, "Early", "small")
    draw_text(parts, chart_x + 52, p1y + panel_h - 18, "to", "small")
    draw_text(parts, chart_x + 78, p1y + panel_h - 18, "late", "small")
    for i in range(60):
        xx = chart_x + 120 + i * 4.6
        parts.append(
            f'<line x1="{xx:.2f}" y1="{p1y + panel_h - 22:.2f}" x2="{xx:.2f}" y2="{p1y + panel_h - 10:.2f}" '
            f'stroke="{color_ramp(i / 59.0)}" stroke-width="4" />'
        )

    # Panel 2: position over time.
    p2x, p2y = left + panel_w + gutter, top
    draw_panel_background(
        parts,
        p2x,
        p2y,
        panel_w,
        panel_h,
        "Position Over Time",
        "Horizontal and vertical gaze angles with invalid samples shaded",
    )
    chart2_x = p2x + 58
    chart2_y = p2y + 72
    chart2_w = panel_w - 92
    chart2_h = panel_h - 110
    draw_grid(parts, chart2_x, chart2_y, chart2_w, chart2_h, time_ticks, xy_ticks, (0, duration), xy_lim)
    for start, end in invalid_segments:
        sx = map_x(start, 0, duration, chart2_x, chart2_w)
        ex = map_x(end, 0, duration, chart2_x, chart2_w)
        draw_rect(parts, sx, chart2_y, max(1.0, ex - sx), chart2_h, "invalid")
    parts.append(
        f'<line class="axis" x1="{chart2_x:.2f}" y1="{map_y(0, xy_lim[0], xy_lim[1], chart2_y, chart2_h):.2f}" '
        f'x2="{chart2_x + chart2_w:.2f}" y2="{map_y(0, xy_lim[0], xy_lim[1], chart2_y, chart2_h):.2f}" />'
    )
    h_points = []
    v_points = []
    for t, hx, vy in zip(times, horiz, vert):
        if math.isfinite(hx):
            h_points.append((map_x(t, 0, duration, chart2_x, chart2_w), map_y(hx, xy_lim[0], xy_lim[1], chart2_y, chart2_h)))
        if math.isfinite(vy):
            v_points.append((map_x(t, 0, duration, chart2_x, chart2_w), map_y(vy, xy_lim[0], xy_lim[1], chart2_y, chart2_h)))
    draw_polyline(parts, h_points, "#1768ac", 1.4, opacity=0.9)
    draw_polyline(parts, v_points, "#d95d39", 1.4, opacity=0.9)
    draw_text(parts, chart2_x + chart2_w / 2.0, p2y + panel_h - 18, "Time (s)", "label", anchor="middle")
    draw_text(parts, p2x + 18, chart2_y + chart2_h / 2.0, "Angle (deg)", "label")
    for tick in time_ticks:
        tx = map_x(tick, 0, duration, chart2_x, chart2_w)
        draw_text(parts, tx, chart2_y + chart2_h + 18, str(tick), "small", anchor="middle")
    for tick in xy_ticks:
        ty = map_y(tick, xy_lim[0], xy_lim[1], chart2_y, chart2_h)
        draw_text(parts, chart2_x - 12, ty + 4, str(tick), "small", anchor="end")
    draw_text(parts, chart2_x + 10, chart2_y + 18, "Horizontal", "small")
    parts.append(f'<line x1="{chart2_x + 82:.2f}" y1="{chart2_y + 14:.2f}" x2="{chart2_x + 116:.2f}" y2="{chart2_y + 14:.2f}" stroke="#1768ac" stroke-width="3" />')
    draw_text(parts, chart2_x + 136, chart2_y + 18, "Vertical", "small")
    parts.append(f'<line x1="{chart2_x + 192:.2f}" y1="{chart2_y + 14:.2f}" x2="{chart2_x + 226:.2f}" y2="{chart2_y + 14:.2f}" stroke="#d95d39" stroke-width="3" />')

    # Panel 3: speed over time.
    p3x, p3y = left, bottom_panel_y
    draw_panel_background(
        parts,
        p3x,
        p3y,
        panel_w,
        panel_h,
        "Angular Gaze Speed",
        "Instantaneous speed from successive combined gaze vectors",
    )
    chart3_x = p3x + 58
    chart3_y = p3y + 72
    chart3_w = panel_w - 92
    chart3_h = panel_h - 110
    speed_ticks = [0, 50, 100, 150, 200]
    draw_grid(parts, chart3_x, chart3_y, chart3_w, chart3_h, time_ticks, speed_ticks, (0, duration), (0, speed_hi))
    for start, end in invalid_segments:
        sx = map_x(start, 0, duration, chart3_x, chart3_w)
        ex = map_x(end, 0, duration, chart3_x, chart3_w)
        draw_rect(parts, sx, chart3_y, max(1.0, ex - sx), chart3_h, "invalid")
    raw_points = []
    smooth_points = []
    for t, raw, sm in zip(times, speed, speed_smoothed):
        if math.isfinite(raw):
            raw_points.append((map_x(t, 0, duration, chart3_x, chart3_w), map_y(min(raw, speed_hi), 0, speed_hi, chart3_y, chart3_h)))
        if math.isfinite(sm):
            smooth_points.append((map_x(t, 0, duration, chart3_x, chart3_w), map_y(min(sm, speed_hi), 0, speed_hi, chart3_y, chart3_h)))
    draw_polyline(parts, raw_points, "#94a3b8", 1.0, opacity=0.55)
    draw_polyline(parts, smooth_points, "#0f766e", 2.3, opacity=0.95)
    draw_text(parts, chart3_x + chart3_w / 2.0, p3y + panel_h - 18, "Time (s)", "label", anchor="middle")
    draw_text(parts, p3x + 18, chart3_y + chart3_h / 2.0, "deg/s", "label")
    for tick in time_ticks:
        tx = map_x(tick, 0, duration, chart3_x, chart3_w)
        draw_text(parts, tx, chart3_y + chart3_h + 18, str(tick), "small", anchor="middle")
    for tick in speed_ticks:
        ty = map_y(tick, 0, speed_hi, chart3_y, chart3_h)
        draw_text(parts, chart3_x - 12, ty + 4, str(tick), "small", anchor="end")
    draw_text(parts, chart3_x + 10, chart3_y + 18, "raw", "small")
    parts.append(f'<line x1="{chart3_x + 34:.2f}" y1="{chart3_y + 14:.2f}" x2="{chart3_x + 70:.2f}" y2="{chart3_y + 14:.2f}" stroke="#94a3b8" stroke-width="3" />')
    draw_text(parts, chart3_x + 92, chart3_y + 18, "smoothed", "small")
    parts.append(f'<line x1="{chart3_x + 156:.2f}" y1="{chart3_y + 14:.2f}" x2="{chart3_x + 192:.2f}" y2="{chart3_y + 14:.2f}" stroke="#0f766e" stroke-width="3" />')

    # Panel 4: pupil size over time.
    p4x, p4y = left + panel_w + gutter, bottom_panel_y
    draw_panel_background(
        parts,
        p4x,
        p4y,
        panel_w,
        panel_h,
        "Pupil Diameter",
        "Left, right, and binocular mean pupil diameter from the Unity log",
    )
    chart4_x = p4x + 58
    chart4_y = p4y + 72
    chart4_w = panel_w - 92
    chart4_h = panel_h - 110
    pupil_ticks = [round(pupil_lo + step * (pupil_hi - pupil_lo) / 4.0, 1) for step in range(5)]
    draw_grid(parts, chart4_x, chart4_y, chart4_w, chart4_h, time_ticks, pupil_ticks, (0, duration), (pupil_lo, pupil_hi))
    for start, end in invalid_segments:
        sx = map_x(start, 0, duration, chart4_x, chart4_w)
        ex = map_x(end, 0, duration, chart4_x, chart4_w)
        draw_rect(parts, sx, chart4_y, max(1.0, ex - sx), chart4_h, "invalid")
    left_points = []
    right_points = []
    mean_points = []
    for t, lp, rp, mp in zip(times, pupil_l, pupil_r, pupil_mean):
        if math.isfinite(lp):
            left_points.append((map_x(t, 0, duration, chart4_x, chart4_w), map_y(lp, pupil_lo, pupil_hi, chart4_y, chart4_h)))
        if math.isfinite(rp):
            right_points.append((map_x(t, 0, duration, chart4_x, chart4_w), map_y(rp, pupil_lo, pupil_hi, chart4_y, chart4_h)))
        if math.isfinite(mp):
            mean_points.append((map_x(t, 0, duration, chart4_x, chart4_w), map_y(mp, pupil_lo, pupil_hi, chart4_y, chart4_h)))
    draw_polyline(parts, left_points, "#1d4ed8", 1.0, opacity=0.75)
    draw_polyline(parts, right_points, "#e11d48", 1.0, opacity=0.75)
    draw_polyline(parts, mean_points, "#111827", 2.0, opacity=0.95)
    draw_text(parts, chart4_x + chart4_w / 2.0, p4y + panel_h - 18, "Time (s)", "label", anchor="middle")
    draw_text(parts, p4x + 18, chart4_y + chart4_h / 2.0, "mm", "label")
    for tick in time_ticks:
        tx = map_x(tick, 0, duration, chart4_x, chart4_w)
        draw_text(parts, tx, chart4_y + chart4_h + 18, str(tick), "small", anchor="middle")
    for tick in pupil_ticks:
        ty = map_y(tick, pupil_lo, pupil_hi, chart4_y, chart4_h)
        draw_text(parts, chart4_x - 12, ty + 4, str(tick), "small", anchor="end")
    draw_text(parts, chart4_x + 10, chart4_y + 18, "Left", "small")
    parts.append(f'<line x1="{chart4_x + 38:.2f}" y1="{chart4_y + 14:.2f}" x2="{chart4_x + 72:.2f}" y2="{chart4_y + 14:.2f}" stroke="#1d4ed8" stroke-width="3" />')
    draw_text(parts, chart4_x + 92, chart4_y + 18, "Right", "small")
    parts.append(f'<line x1="{chart4_x + 128:.2f}" y1="{chart4_y + 14:.2f}" x2="{chart4_x + 162:.2f}" y2="{chart4_y + 14:.2f}" stroke="#e11d48" stroke-width="3" />')
    draw_text(parts, chart4_x + 184, chart4_y + 18, "Mean", "small")
    parts.append(f'<line x1="{chart4_x + 222:.2f}" y1="{chart4_y + 14:.2f}" x2="{chart4_x + 256:.2f}" y2="{chart4_y + 14:.2f}" stroke="#111827" stroke-width="3" />')

    draw_text(
        parts,
        left,
        height - 24,
        "Shaded regions mark invalid combined-gaze samples. Speed is clipped to the 99th percentile for readability.",
        "subtitle",
    )
    parts.append("</svg>")
    return "\n".join(parts)


def summarize(csv_path: str) -> dict:
    time_sec: List[float] = []
    horiz_deg: List[float] = []
    vert_deg: List[float] = []
    left_pupil: List[float] = []
    right_pupil: List[float] = []
    mean_pupil: List[float] = []
    speed_deg_s: List[float] = []
    invalid_mask: List[bool] = []
    valid_count = 0
    total = 0

    prev_vec = None
    prev_capture = None
    prev_valid = False
    first_capture = None
    capture_deltas: List[float] = []

    with open(csv_path, newline="") as handle:
        reader = csv.DictReader(handle, delimiter=";")
        for row in reader:
            total += 1
            capture_ns = int((row.get("CaptureTime") or "0").strip())
            if first_capture is None:
                first_capture = capture_ns
            t = (capture_ns - first_capture) / 1e9
            gaze_status = (row.get("GazeStatus") or "").strip().upper()
            vec = parse_vec3(row.get("CombinedGazeForward", ""))
            horiz, vert = angle_from_forward(vec)
            valid = gaze_status == "VALID" and is_finite(horiz, vert)
            invalid_mask.append(not valid)
            if valid:
                valid_count += 1
            else:
                horiz = float("nan")
                vert = float("nan")

            lp = parse_float(row.get("LeftPupilDiameterInMM", ""))
            rp = parse_float(row.get("RightPupilDiameterInMM", ""))
            mp = statistics.fmean([v for v in (lp, rp) if math.isfinite(v)]) if any(
                math.isfinite(v) for v in (lp, rp)
            ) else float("nan")

            if prev_capture is not None:
                capture_deltas.append((capture_ns - prev_capture) / 1e9)

            if prev_capture is None or prev_vec is None or not valid or not prev_valid:
                speed = float("nan")
            else:
                dt_sec = (capture_ns - prev_capture) / 1e9
                speed = angular_speed_deg_per_s(prev_vec, vec, dt_sec)

            time_sec.append(t)
            horiz_deg.append(horiz)
            vert_deg.append(vert)
            left_pupil.append(lp)
            right_pupil.append(rp)
            mean_pupil.append(mp)
            speed_deg_s.append(speed)

            prev_vec = vec
            prev_capture = capture_ns
            prev_valid = valid

    duration_sec = time_sec[-1] if time_sec else 0.0
    sample_rate_hz = 1.0 / statistics.median(capture_deltas) if capture_deltas else float("nan")
    speed_smooth = moving_average(speed_deg_s, 15)
    return {
        "time_sec": time_sec,
        "horiz_deg": horiz_deg,
        "vert_deg": vert_deg,
        "left_pupil": left_pupil,
        "right_pupil": right_pupil,
        "mean_pupil": mean_pupil,
        "speed_deg_s": speed_deg_s,
        "speed_smooth": speed_smooth,
        "invalid_mask": invalid_mask,
        "valid_ratio": valid_count / total if total else 0.0,
        "duration_sec": duration_sec,
        "sample_rate_hz": sample_rate_hz,
    }


def main() -> None:
    args = parse_args()
    data = summarize(args.csv_path)
    svg = build_svg(data, args.csv_path)

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(svg, encoding="utf-8")

    print(f"Wrote {output_path}")
    print(f"Duration: {data['duration_sec']:.2f}s")
    print(f"Samples: {len(data['time_sec'])}")
    print(f"Valid combined gaze: {data['valid_ratio'] * 100.0:.1f}%")
    print(f"Estimated sample rate: {fmt(data['sample_rate_hz'], 1)} Hz")


if __name__ == "__main__":
    main()
