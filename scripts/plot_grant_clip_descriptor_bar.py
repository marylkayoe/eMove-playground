#!/usr/bin/env python3
"""
Build a cleaner grant-style modality informativeness chart from the CSV
summaries generated in MATLAB.

Bars show mean absolute within-subject beta across clip descriptors.
Colored dots show descriptor-specific absolute betas.
"""

from __future__ import annotations

import csv
from collections import defaultdict
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D
from matplotlib.patches import Patch


REPO_ROOT = Path("/Users/yoe/Documents/REPOS/eMove-playground")
SUMMARY_CSV = REPO_ROOT / "outputs/figures/emowear_grant_clip_descriptor_rose_20260413_133835/clip_descriptor_mixed_model_summary.csv"
OUT_DIR = REPO_ROOT / "outputs/figures/emowear_grant_clip_descriptor_bar_python_20260413"
OUT_DIR.mkdir(parents=True, exist_ok=True)


def load_rows(path: Path):
    with path.open(newline="") as f:
        rows = list(csv.DictReader(f))
    for row in rows:
        row["within_beta"] = float(row["within_beta"])
    return rows


def main():
    rows = load_rows(SUMMARY_CSV)

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

    by_label = defaultdict(dict)
    for row in rows:
        by_label[row["label"]][row["rating"]] = abs(row["within_beta"])

    labels = []
    means = []
    for label, vals in by_label.items():
        ordered = [vals[r] for r in rating_order]
        labels.append(label)
        means.append(sum(ordered) / len(ordered))

    order = sorted(range(len(labels)), key=lambda i: means[i], reverse=True)
    labels = [labels[i] for i in order]
    means = [means[i] for i in order]

    dot_values = {r: [by_label[label][r] for label in labels] for r in rating_order}

    fig, ax = plt.subplots(figsize=(13.2, 8.6), facecolor="#fcfaf5")
    ax.set_facecolor("#fcfaf5")

    y = list(range(len(labels)))
    bar_color = "#c8d0d4"
    ax.barh(y, means, height=0.72, color=bar_color, edgecolor="none", zorder=1)

    offsets = {
        "valence": -0.24,
        "arousal": -0.08,
        "liking": 0.08,
        "familiarity": 0.24,
    }
    for rating in rating_order:
        yy = [yi + offsets[rating] for yi in y]
        ax.scatter(
            dot_values[rating],
            yy,
            s=78,
            color=rating_colors[rating],
            edgecolors="white",
            linewidths=1.0,
            zorder=3,
            label=rating_labels[rating],
        )

    for yi, mean_val in zip(y, means):
        ax.text(
            mean_val + 0.012,
            yi,
            f"{mean_val:.3f}",
            va="center",
            ha="left",
            fontsize=13,
            color="#2d2d2d",
            bbox=dict(boxstyle="round,pad=0.16", facecolor="#fcfaf5", edgecolor="none", alpha=0.9),
        )

    ax.set_yticks(y)
    ax.set_yticklabels(labels, fontsize=14, color="#2d2d2d")
    ax.invert_yaxis()
    ax.set_xlabel(
        "Mean absolute within-subject beta across clip descriptors",
        fontsize=18,
        fontweight="bold",
        color="#222222",
        labelpad=12,
    )
    xmax = max(means) + 0.05
    ax.set_xlim(0, xmax)
    ax.tick_params(axis="x", labelsize=15, colors="#2d2d2d")
    ax.grid(axis="x", color="#8f8f8f", alpha=0.18, linewidth=1.0)
    ax.set_axisbelow(True)

    for spine in ax.spines.values():
        spine.set_visible(False)

    legend_handles = [Patch(facecolor=bar_color, edgecolor="none", label="Mean across descriptors")]
    legend_handles.extend(
        [
            Line2D(
                [0],
                [0],
                marker="o",
                color="none",
                markerfacecolor=rating_colors[r],
                markeredgecolor="white",
                markeredgewidth=0.8,
                markersize=7,
                label=rating_labels[r],
            )
            for r in rating_order
        ]
    )
    fig.legend(
        handles=legend_handles,
        loc="upper center",
        bbox_to_anchor=(0.53, 0.885),
        ncol=5,
        frameon=False,
        fontsize=14,
        handletextpad=0.4,
        columnspacing=1.0,
    )

    fig.suptitle(
        "Informativeness of motion and physiological signals",
        fontsize=21,
        fontweight="bold",
        color="#202020",
        y=0.965,
    )

    fig.text(
        0.5,
        0.05,
        "Bars show mean absolute beta across valence, arousal, liking, and familiarity. Dots show descriptor-specific values.",
        ha="center",
        va="center",
        fontsize=12,
        color="#4a4a4a",
    )

    fig.subplots_adjust(left=0.29, right=0.98, top=0.78, bottom=0.22)
    out_path = OUT_DIR / "grant_clip_descriptor_bar_python.png"
    fig.savefig(out_path, dpi=240, facecolor=fig.get_facecolor())
    print(out_path)


if __name__ == "__main__":
    main()
