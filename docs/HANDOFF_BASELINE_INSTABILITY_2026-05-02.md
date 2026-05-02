# Baseline Instability Handoff (2026-05-02)

## Question

After the sparse-event framing weakened, the question became:

Can the `BASELINE` chest-motion traces be described more convincingly as a
gradual loss of local stability / stationarity rather than as a buildup of
rare phasic event counts?

## Why The Framing Changed

- The original liberal event detector overcalled ordinary sway.
- A stricter `uTorso` detector with peak/prominence constraints became sparse,
  but did not yield a strong cohort-level timing effect.
- A brief-exit-from-LAR assay was more interpretable, but still only mildly
  late-skewed.
- Visual inspection of the traces suggested a different phenomenon:
  - not necessarily more large excursions,
  - but more waviness, drift, and local irregularity later in baseline.

## What Was Added In This Session

### 1) Structural event follow-up

- `scripts/explore_long_baseline_disruption_events.m`

Additions:
- explicit signal-mode selection inside the script
- peak timing fields
- peak prominence filtering
- refractory filtering
- optional quiet-window gating
- timing and morphology figure export

Outcome:
- useful as a cleanup / negative result
- did not produce a convincingly stronger event story

### 2) Brief exits from LAR

- `scripts/explore_baseline_lar_exits.m`
- `scripts/plot_lar_exit_probability_over_time.m`

Working definition:
- signal: `uTorso` speed
- LAR threshold: `< 35 mm/s`
- immobile bout minimum: `1.0 s`
- retained exit:
  - mobile run bracketed by immobile bouts
  - duration `0.15-4.0 s`
  - peak speed `>= 40 mm/s`

Main output folder:
- `outputs/figures/baseline_lar_exit_baselineStim_20260502_202522425_uTorso_working`

Key descriptive result:
- exits existed and were sparse
- timing was only mildly late-skewed
- not strong enough to support a clean "hazard rises with time" claim

### 3) Rolling instability analysis

- `scripts/explore_baseline_instability.m`

Working definition:
- signal: `uTorso`
- analysis interval:
  - `BASELINE`
  - trim first `10 s`
  - trim last `5 s`
- speed window: `0.1 s`
- rolling window:
  - width `10 s`
  - step `2 s`
- early reference for drift:
  - first `20 s` of analyzed interval

Rolling metrics:
- `speedStdMmps`
- `speedMadMmps`
- `speedDiffMadMmps`
- `posLocalMadMm`
- `posDriftMm`

Main output folder:
- `outputs/figures/baseline_instability_baselineStim_20260502_204538015_uTorso_working`

Key figure assets:
- `cohort_instability_curves.png`
- `early_late_summary.png`
- `representative_instability.png`
- `subject_summary.csv`
- `window_table.csv`

## Current Best Read

This branch now supports a more coherent, but still modest, claim:

- `BASELINE` does not show a strong rise in discrete exit events.
- It does show a mild tendency toward greater local instability later in the
  trial.
- The effect is clearest as:
  - increased position drift
  - mild increases in speed roughness / variability

This is a better fit to the visual gut feeling than the event-count framing.

## Concrete Results To Remember

### LAR exits

- total retained exits: `45`
- overall early vs late split:
  - early `21`
  - late `24`
- subjectwise:
  - more late-heavy: `12`
  - more early-heavy: `3`
  - tied: `13`

Interpretation:
- suggestive but weak
- not enough for a strong monotonic time-to-exit story

### Instability late-minus-early medians

- speed SD: `+0.42`
- speed MAD: `+0.10`
- speed-diff MAD: `+0.006`
- local position MAD: `+0.10`
- position drift: `+3.93 mm`

Direction counts:
- speed SD: `16` positive, `12` negative
- speed MAD: `17` positive, `11` negative
- speed-diff MAD: `19` positive, `9` negative
- local position MAD: `19` positive, `9` negative
- position drift: `23` positive, `5` negative

Interpretation:
- modest, not dramatic
- but systematically more aligned with the visual impression

## What Another Thread Should Not Do

- Do not assume the sparse-event detector is already a validated phasic
  assay.
- Do not claim a strong monotonic increase in exit probability over time from
  the current figures.
- Do not keep spending effort only on harsher threshold tuning.

## What Another Thread Should Probably Do Next

1. compare instability curves across:
   - `HEAD`
   - `uTorso`
   - `lTorso`
   - pooled upper body
2. decide whether the best downstream summary is:
   - one composite instability score
   - or separate position-drift and speed-roughness stories
3. if inferential work is wanted, fit explicit time-trend models to the
   rolling metrics rather than only using early-vs-late summaries

## Memory Anchor

The most durable memory from this session should be:

- the user's visual intuition was better captured by a nonstationarity /
  instability framing than by a phasic-event framing
- brief exits from LAR were useful descriptively but weak inferentially
- rolling instability metrics gave the first coherent positive signal
- position drift was the clearest single metric
