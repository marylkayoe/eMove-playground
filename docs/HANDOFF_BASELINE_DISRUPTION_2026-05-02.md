# Baseline Disruption Handoff (2026-05-02)

## Question

Assess whether the explicit `BASELINE` stimulus period contains rare, discrete
motion/posture events rather than only ordinary sway fluctuations during a
long low-animation regime.

## Branch status

- The original `baselineStim` first pass succeeded but was too liberal.
- It overcalled ordinary sway-like threshold crossings.
- A stricter detector was implemented and threshold-swept.
- The current working branch is no longer in the "what counts as an event?"
  stage. It has a concrete retained detector with known limitations.

## Current working detector

- Interval:
  - `intervalMode='baselineStim'`
- Signal:
  - `signalMarkerMode='uTorso'`
- Preprocessing:
  - marker-speed signal with `speedWindowSec=0.1`
  - `1.0 s` moving-median smoothing
  - stable reference estimated from the lower `60%` of the smoothed signal
  - robust center = median
  - robust scale = MAD-derived scale
- Current retained thresholds:
  - `eventZThreshold=4.5`
  - `peakZThreshold=6.0`
  - `minPeakProminenceZ=2.5`
  - `grossZThreshold=8.0`
  - `mergeGapSec=0.35`
  - `minEventDurSec=0.40`

## Why This Replaced The First Pass

The first detector mainly used suprathreshold run logic and was too willing to
count ordinary fluctuations as candidate events.

The stricter branch added:

- explicit signal-mode selection:
  - `upperBody`
  - `head`
  - `uTorso`
  - `lTorso`
- separate span and peak criteria
- within-run peak-prominence filtering
- event timing fields:
  - `peakSec`
  - `peakTimeNorm`
- event-morphology QC:
  - aligned trace summary
  - normalized event-shape summary
  - timing histogram
  - subject-level timing raster

## Threshold Sweep Summary

The retained summary from the `baselineStim` threshold sweep was:

| Label | Span z | Peak z | Prominence z | Median candidate rate (/min) | Median candidate count | Zero-event subjects | Subjects with >=3 candidates | Max candidate count |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| sweepA | 4.0 | 5.5 | 2.0 | 1.29 | 3 | 3 | 16 | 7 |
| sweepB | 4.0 | 6.0 | 2.0 | 1.29 | 3 | 3 | 16 | 7 |
| sweepC | 4.0 | 6.0 | 2.5 | 0.43 | 1 | 4 | 13 | 7 |
| sweepD | 4.5 | 6.0 | 2.5 | 0.43 | 1 | 8 | 7 | 4 |

Operational conclusions:

- Raising peak threshold alone from `5.5` to `6.0` had negligible cohort-level
  effect.
- Raising prominence from `2.0` to `2.5` produced the first substantial
  sparsification.
- Tightening span threshold from `4.0 z` to `4.5 z` further reduced the
  heavier-count tail.
- `sweepD` became the retained working detector.

## Marker Comparison Outcome

- `HEAD` alone looked less sparse and likely noisier.
- Pooled upper-body was usable but still somewhat heavier-tailed.
- `UTORSO` preserved the sparse regime while slightly reducing heavy-count
  subjects.

Current default:

- keep `signalMarkerMode='uTorso'`

## Current Findings

- Tightening the detector made event counts plausibly sparse.
- The current `uTorso` run supports a cautious claim that some `BASELINE`
  intervals contain intermittent transient excursions.
- Event timing does not show a clear cohort-level increase toward the end of
  `BASELINE`.
- Event-aligned morphology shows moderate shared bump-like structure around
  the peak, but not a highly stereotyped waveform across subjects.

## Interpretation Boundary

- The detector now isolates sparse candidate events.
- That is enough to motivate further QC and structural refinement.
- It is not yet enough to claim that the retained events are definitively
  unitary disruption episodes.
- It is also not enough to assign them a settled psychological interpretation
  such as frustration, boredom, or attentional disengagement.

## Canonical Outputs To Revisit

- Original liberal first pass:
  - `outputs/figures/long_baseline_disruption_baselineStim_20260502_135035`
- Threshold-sweep note:
  - external copy previously saved as
    `outputs/figures/long_baseline_disruption_baselineStim_threshold_sweep_20260502.md`
- Current working result:
  - `outputs/figures/long_baseline_disruption_baselineStim_uTorso_sweepD_20260502`

Key files in the current working result:

- `subject_summary.csv`
- `event_table.csv`
- `first_pass_report.md`
- `representative_trace.png`
- `cohort_summary.png`
- `event_morphology_summary.png`

## Recommended Next Step

Do not keep tightening only by raising amplitude thresholds.

If more selectivity is needed, add one structural criterion instead:

- refractory period between accepted events
- pre/post quiet-window requirement
- onset-slope or impulse-shape filter
- optional cross-channel confirmation after the single-channel detector is
  stable

## Memory Anchor

The stable memory for future sessions should be:

- first pass overcalled sway
- prominence mattered more than peak height alone
- `UTORSO` beat `HEAD` as the working signal
- `sweepD` is the retained detector
- the next methodological move should be structural filtering, not just
  harsher z-thresholds
