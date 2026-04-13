#!/usr/bin/env python3
"""
Build a cleaner Python radar / rose summary from the MATLAB mixed-model CSV.

Radius = absolute within-subject beta on a common scale.
"""

from __future__ import annotations

import csv
import math
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
from matplotlib.patches import Polygon


REPO_ROOT = Path("/Users/yoe/Documents/REPOS/eMove-playground")
SUMMARY_CSV = REPO_ROOT / "outputs/figures/emowear_grant_clip_descriptor_rose_20260413_133835/clip_descriptor_mixed_model_summary.csv"
OUT_DIR = REPO_ROOT / "outputs/figures/emowear_grant_clip_descriptor_rose_python_20260413"
OUT_DIR.mkdir(parents=True, exist_ok=True)


def load_rows(path: Path):
    with path.open(newline="") as f:
        rows = list(csv.DictReader(f))
    for row in rows:
        row["within_beta"] = float(row["within_beta"])
    return rows


def pol2cart(theta, radius):
    return radius * math.cos(theta), radius * math.sin(theta)


def main():
    rows = load_rows(SUMMARY_CSV)

    feature_order = [
        "Front STb motion",
        "BH3 HR mean",
        "BH3 HRV (RMSSD)",
        "E4 EDA mean amplitude",
        "E4 SCR rate",
        "BH3 breathing rate",
    ]
    feature_short = {
        "Front STb motion": "Front STb",
        "BH3 HR mean": "BH3 HR",
        "BH3 HRV (RMSSD)": "BH3 HRV",
        "E4 EDA mean amplitude": "E4 EDA tonic",
        "E4 SCR rate": "E4 SCR",
        "BH3 breathing rate": "BH3 breathing",
    }
    rating_order = ["valence", "arousal", "liking", "familiarity"]
    rating_labels = {
        "valence": "Valence",
        "arousal": "Arousal",
        "liking": "Liking",
        "familiarity": "Familiarity",
    }
    rating_colors = {
        "valence": "#b2412d",
        "arousal": "#356fb3",
        "liking": "#2e8b57",
        "familiarity": "#7b5aa6",
    }

    data = {(row["rating"], row["label"]): abs(row["within_beta"]) for row in rows}

    fig, ax = plt.subplots(figsize=(10.2, 9.8), facecolor="#fcfaf5")
    ax.set_facecolor("#fcfaf5")
    ax.set_aspect("equal")
    ax.axis("off")

    n = len(feature_order)
    thetas = [math.pi / 2 - i * 2 * math.pi / n for i in range(n)]
    rmax = 0.16
    ticks = [0.04, 0.08, 0.12, 0.16]

    grid_color = "#d6d0c8"
    spoke_color = "#e4dfd7"
    text_color = "#222222"

    # Grid polygons
    for tv in ticks:
        rr = tv / rmax
        pts = [pol2cart(theta, rr) for theta in thetas]
        poly = Polygon(pts, closed=True, fill=False, edgecolor=grid_color, linewidth=1.0, zorder=0)
        ax.add_patch(poly)

    # Spokes
    for theta in thetas:
        x0, y0 = 0, 0
        x1, y1 = pol2cart(theta, 1.02)
        ax.plot([x0, x1], [y0, y1], color=spoke_color, linewidth=1.0, zorder=0)

    # Radial labels on BH3 HR spoke
    hr_theta = thetas[1]
    for tv in ticks:
        rr = tv / rmax
        xt, yt = pol2cart(hr_theta, rr)
        ax.text(
            xt + 0.025,
            yt,
            f"{tv:.2f}",
            ha="left",
            va="center",
            fontsize=12,
            color="#555555",
            bbox=dict(boxstyle="round,pad=0.15", facecolor="#fcfaf5", edgecolor="none", alpha=0.95),
        )

    # Spoke labels
    label_radius = 1.18
    for theta, label in zip(thetas, feature_order):
        x, y = pol2cart(theta, label_radius)
        ha = "center"
        if math.cos(theta) > 0.2:
            ha = "left"
        elif math.cos(theta) < -0.2:
            ha = "right"
        ax.text(
            x,
            y,
            feature_short[label],
            ha=ha,
            va="center",
            fontsize=15,
            fontweight="bold",
            color=text_color,
        )

    # Rating shapes
    handles = []
    for rating in rating_order:
        vals = [data[(rating, feat)] for feat in feature_order]
        pts = [pol2cart(theta, val / rmax) for theta, val in zip(thetas, vals)]
        pts_closed = pts + [pts[0]]
        xs = [p[0] for p in pts_closed]
        ys = [p[1] for p in pts_closed]
        ax.fill(xs, ys, color=rating_colors[rating], alpha=0.10, zorder=1)
        ax.plot(xs, ys, color=rating_colors[rating], linewidth=2.4, zorder=2)
        ax.scatter(
            [p[0] for p in pts],
            [p[1] for p in pts],
            s=42,
            color=rating_colors[rating],
            edgecolors="white",
            linewidths=0.8,
            zorder=3,
        )
        handles.append(
            Line2D(
                [0],
                [0],
                color=rating_colors[rating],
                marker="o",
                markersize=7,
                linewidth=2.4,
                markerfacecolor=rating_colors[rating],
                markeredgecolor="white",
                markeredgewidth=0.8,
                label=rating_labels[rating],
            )
        )

    ax.set_title(
        "Clip descriptor informativeness by modality",
        fontsize=22,
        fontweight="bold",
        pad=34,
        color=text_color,
    )
    ax.legend(
        handles=handles,
        loc="upper center",
        bbox_to_anchor=(0.5, 1.03),
        ncol=4,
        frameon=False,
        fontsize=14,
        handletextpad=0.5,
        columnspacing=1.1,
    )
    fig.text(
        0.5,
        0.05,
        "Radius = absolute within-subject beta on a common scale",
        ha="center",
        va="center",
        fontsize=12,
        color="#4a4a4a",
    )

    fig.subplots_adjust(left=0.10, right=0.90, top=0.82, bottom=0.10)
    out_path = OUT_DIR / "grant_clip_descriptor_rose_python.png"
    fig.savefig(out_path, dpi=240, facecolor=fig.get_facecolor())
    print(out_path)


if __name__ == "__main__":
    main()
