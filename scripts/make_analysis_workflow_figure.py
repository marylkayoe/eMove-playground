#!/usr/bin/env python3
"""
make_analysis_workflow_figure.py

Build a step-by-step explainer figure for the motion-analysis workflow.

This figure is intentionally pedagogical rather than exhaustive:
1. continuous recording is segmented into baseline + emotion windows
2. one trial/bodypart example is converted into speed traces
3. low-speed samples are retained as the micromovement regime
4. samples are pooled into emotion-conditioned distributions
5. pairwise differences are mapped back onto the body
"""

from __future__ import annotations

from pathlib import Path
import numpy as np
from PIL import Image
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, Rectangle, FancyArrowPatch, Circle


REPO = Path("/Users/yoe/Documents/REPOS/eMove-playground")
OUTDIR = REPO / "outputs" / "figures" / "analysis_workflow_20260322"
TRACE_IMG = OUTDIR / "workflow_trace_panel.png"
POOLED_DENSITY = REPO / "outputs" / "figures" / "pooled_disgust_density_20260315_131050" / "pooled_disgust_density_baseline_normalized.png"
STICKFIG = REPO / "outputs" / "figures" / "disgust_fear_ks_stickfigures_20260315_133403" / "disgust_ks_stickfigures.png"

EMOTION_COLORS = {
    "NEUTRAL": "#4CAF50",
    "DISGUST": "#E64A19",
    "JOY": "#7B1FA2",
    "SAD": "#4FC3F7",
}


def ensure_inputs():
    missing = [p for p in [TRACE_IMG, POOLED_DENSITY, STICKFIG] if not p.exists()]
    if missing:
        raise FileNotFoundError(f"Missing inputs: {missing}")
    OUTDIR.mkdir(parents=True, exist_ok=True)


def load_and_crop(path: Path, crop_fracs=None):
    img = Image.open(path).convert("RGB")
    if crop_fracs is not None:
        w, h = img.size
        l, t, r, b = crop_fracs
        img = img.crop((int(l * w), int(t * h), int(r * w), int(b * h)))
    return np.asarray(img)


def add_panel_title(ax, step, title, subtitle=""):
    ax.text(
        0.0, 1.08, f"{step}. {title}",
        transform=ax.transAxes,
        ha="left", va="bottom",
        fontsize=15, fontweight="bold",
    )
    if subtitle:
        ax.text(
            0.0, 1.01, subtitle,
            transform=ax.transAxes,
            ha="left", va="bottom",
            fontsize=10.5, color="#444444"
        )


def add_panel_box(ax):
    patch = FancyBboxPatch(
        (-0.03, -0.04), 1.06, 1.12,
        transform=ax.transAxes,
        boxstyle="round,pad=0.018,rounding_size=0.03",
        linewidth=1.3, edgecolor="#D0D0D0", facecolor="#FAFAFA",
        zorder=-20,
    )
    ax.add_patch(patch)


def draw_timeline_panel(ax):
    ax.set_axis_off()
    add_panel_box(ax)
    add_panel_title(ax, "1", "Record a continuous session", "One long mocap recording is later segmented into baseline and stimulus windows.")

    x0, y0, width, height = 0.08, 0.48, 0.82, 0.12
    segments = [
        ("BASELINE", "#DDDDDD", 0.14),
        ("0302", EMOTION_COLORS["NEUTRAL"], 0.14),
        ("0602", EMOTION_COLORS["DISGUST"], 0.14),
        ("4903", EMOTION_COLORS["JOY"], 0.14),
        ("5102", EMOTION_COLORS["SAD"], 0.14),
        ("…", "#EAEAEA", 0.16),
        ("more videos", "#EAEAEA", 0.14),
    ]
    cursor = x0
    for label, color, frac in segments:
        w = width * frac
        ax.add_patch(Rectangle((cursor, y0), w, height, transform=ax.transAxes,
                               facecolor=color, edgecolor="white", linewidth=2))
        ax.text(cursor + w/2, y0 + height/2, label, transform=ax.transAxes,
                ha="center", va="center", fontsize=11, fontweight="bold",
                color="#222222")
        cursor += w

    ax.text(0.08, 0.73, "Continuous Vicon trajectory data", transform=ax.transAxes,
            fontsize=12, fontweight="bold")
    ax.text(0.08, 0.30, "Each block becomes one trial window aligned to the Unity log schedule.",
            transform=ax.transAxes, fontsize=11, color="#333333")
    ax.text(0.08, 0.18, "Inter-report intervals are ignored in the current emotion analysis.",
            transform=ax.transAxes, fontsize=10, color="#666666")


def draw_pooling_panel(ax):
    ax.set_axis_off()
    add_panel_box(ax)
    add_panel_title(ax, "3", "Pool retained samples by emotion", "All low-speed samples from the selected bodypart are accumulated across trials and subjects.")

    cols = ["NEUTRAL", "DISGUST", "JOY", "SAD"]
    xs = np.linspace(0.14, 0.86, len(cols))
    rng = np.random.default_rng(3)
    for x, emo in zip(xs, cols):
        ax.text(x, 0.84, emo, transform=ax.transAxes, ha="center", va="center",
                fontsize=12, fontweight="bold", color=EMOTION_COLORS[emo])
        ax.add_patch(Rectangle((x - 0.09, 0.12), 0.18, 0.62, transform=ax.transAxes,
                               facecolor="white", edgecolor="#DDDDDD", linewidth=1.2))
        for i in range(70):
            px = x + rng.normal(0, 0.028)
            py = 0.16 + rng.random() * 0.52
            ax.add_patch(Circle((px, py), 0.0075, transform=ax.transAxes,
                                facecolor=EMOTION_COLORS[emo], edgecolor="none", alpha=0.55))
    ax.text(0.06, 0.05, "Example shown schematically: the actual pipeline stores thousands of speed samples per emotion/bodypart.",
            transform=ax.transAxes, fontsize=10, color="#555555")


def draw_distribution_panel(ax):
    add_panel_box(ax)
    add_panel_title(ax, "4", "Compare the resulting distributions", "Here shown as pooled density curves; the same samples can also be summarized as CDFs.")
    ax.axis("off")
    # Crop to the top half to keep the explainer readable.
    img = load_and_crop(POOLED_DENSITY, crop_fracs=(0.03, 0.03, 0.98, 0.69))
    ax.imshow(img)


def draw_bodymap_panel(ax):
    add_panel_box(ax)
    add_panel_title(ax, "5", "Map pairwise emotion differences back onto the body", "Unsigned KS intensity asks where a given emotion pair differs most strongly.")
    ax.axis("off")
    img = load_and_crop(STICKFIG, crop_fracs=(0.03, 0.06, 0.97, 0.97))
    ax.imshow(img)


def draw_trace_panel(ax):
    add_panel_box(ax)
    add_panel_title(ax, "2", "Isolate the micromovement regime", "Example: SC3001, disgust video 0602, HEAD + upper torso + lower torso.")
    ax.axis("off")
    img = load_and_crop(TRACE_IMG, crop_fracs=(0.03, 0.03, 0.98, 0.97))
    ax.imshow(img)


def draw_arrows(fig, axes_pairs):
    for ax_from, ax_to in axes_pairs:
        b1 = ax_from.get_position()
        b2 = ax_to.get_position()
        start = (b1.x1 + 0.008, (b1.y0 + b1.y1) / 2)
        end = (b2.x0 - 0.008, (b2.y0 + b2.y1) / 2)
        arr = FancyArrowPatch(
            start, end,
            transform=fig.transFigure,
            arrowstyle="-|>", mutation_scale=18,
            linewidth=1.5, color="#888888"
        )
        fig.add_artist(arr)


def main():
    ensure_inputs()

    fig = plt.figure(figsize=(18, 11), facecolor="white")
    gs = fig.add_gridspec(
        2, 3,
        width_ratios=[1.05, 1.15, 1.2],
        height_ratios=[0.95, 1.15],
        left=0.04, right=0.98, top=0.93, bottom=0.05,
        wspace=0.16, hspace=0.24
    )

    ax1 = fig.add_subplot(gs[0, 0])
    ax2 = fig.add_subplot(gs[0, 1])
    ax3 = fig.add_subplot(gs[0, 2])
    ax4 = fig.add_subplot(gs[1, 0:2])
    ax5 = fig.add_subplot(gs[1, 2])

    draw_timeline_panel(ax1)
    draw_trace_panel(ax2)
    draw_pooling_panel(ax3)
    draw_distribution_panel(ax4)
    draw_bodymap_panel(ax5)

    draw_arrows(fig, [(ax1, ax2), (ax2, ax3)])

    fig.suptitle(
        "From continuous movement to emotion-specific micromovement signatures",
        fontsize=23, fontweight="bold", y=0.975
    )
    fig.text(
        0.5, 0.945,
        "Workflow summary: segment trials, threshold low-speed motion, pool samples by emotion, compare distributions, then localize the strongest pairwise differences on the body.",
        ha="center", va="center", fontsize=12.5, color="#333333"
    )

    out_png = OUTDIR / "analysis_workflow_figure.png"
    out_pdf = OUTDIR / "analysis_workflow_figure.pdf"
    fig.savefig(out_png, dpi=220, bbox_inches="tight")
    fig.savefig(out_pdf, dpi=220, bbox_inches="tight")
    plt.close(fig)
    print(f"Saved:\n{out_png}\n{out_pdf}")


if __name__ == "__main__":
    main()
