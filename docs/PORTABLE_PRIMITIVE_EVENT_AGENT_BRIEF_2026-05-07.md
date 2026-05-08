# Portable Primitive Event Agent Brief

Updated: 2026-05-08

This document is for another agent, including Simo's Claude, continuing the
acceleration primitive-event analysis outside this thread. It is self-contained
and intentionally avoids assuming access to the current MATLAB workspace.

## Goal

The scientific goal is to test whether low-amplitude residual motion during
LAR can be described as discrete primitive-like acceleration events, and
whether larger motion episodes are structured compounds of those events.

Use cautious language:

- preferred: "acceleration-supported primitive-like events",
- preferred: "valley-delimited compound bouts",
- avoid: "proven motor primitives" unless held-out physiological validation is
  completed.

The current working claim:

> LAR micromotion includes repeatable acceleration-supported event-like motifs,
> and many larger bouts contain multiple such motifs arranged with non-random
> subsecond timing.

## Input Data Expected

The downstream analysis assumes one envelope-like movement signal per trial or
recording, plus a sampling rate.

Possible inputs:

- gravity-corrected accelerometer magnitude,
- accelerometer-derived motion envelope,
- marker-derived speed or acceleration envelope,
- another one-dimensional movement-intensity trace.

If raw accelerometer and orientation/quaternion data are available, keep them.
They are needed to check whether event times have support in
gravity-corrected acceleration rather than only in the processed envelope.

## Signal Definitions

`raw acceleration`: three-axis sensor acceleration, including body motion,
gravity, orientation effects, and possible contact artifacts.

`gravity-corrected acceleration`: acceleration after using orientation to
subtract gravity. This is the main physical-support check.

`motion envelope`: positive one-dimensional motion-intensity signal derived
from acceleration or motion capture.

`baseline`: slow local background of the motion envelope.

`residual`: motion envelope minus local baseline.

`eventSignal`: positive baseline-relative event signal:

```text
eventSignal = max(motionEnvelope - baseline, 0)
```

Peaks are detected in `eventSignal`, not directly in the raw envelope.

`noiseSigma`: robust local variability estimate from the residual.

`event`: a primary peak in `eventSignal` above threshold.

`subpeak`: a lower-threshold peak inside a broader event neighborhood.

`bout`: a valley-delimited group of subpeaks treated as one movement episode.

`unitary bout`: a bout with one detected subpeak.

`compound bout`: a bout with two or more detected subpeaks.

`temporal coherence`: non-random timing of secondary subpeaks within compound
bouts.

## Current Algorithm Specification

### 1. Baseline And Noise

For each signal vector:

```text
baseline = moving median(signal, 15 s)
residual = signal - baseline
eventSignal = max(residual, 0)
absoluteDeviation = abs(residual - moving median(residual, 30 s))
localMad = moving median(absoluteDeviation, 30 s)
noiseSigma = 1.4826 * localMad
```

Replace zero or invalid `noiseSigma` values with a global robust residual MAD.

The detector threshold in event-signal units is:

```text
primaryThreshold = 4 * median(noiseSigma)
```

The same threshold in original envelope units is:

```text
envelopeThreshold = baseline + 4 * median(noiseSigma)
```

This is the shaded/noise threshold shown in the current example trace figure.

### 2. Primary Event Detection

Detect local maxima in `eventSignal` with:

- minimum peak height: `4 * median(noiseSigma)`,
- minimum peak distance: `0.5 s`.

Then apply a peak-merging valley rule:

- if two candidate primary peaks are not separated by a valley below
  `0.20 * min(leftPeak, rightPeak)`, treat them as the same primary event and
  keep the larger peak.

This 0.20 rule belongs to primary peak de-duplication. Do not confuse it with
the compound-bout valley rule below.

### 3. Compound-Bout Decomposition

For each primary event anchor, search nearby for lower-threshold subpeaks:

- search window around anchor: `[-1.5, +4.5] s`,
- subpeak threshold: `2 * median(noiseSigma)`,
- subpeak minimum distance: `0.35 s`.

Group adjacent subpeaks into the same bout unless there is a deep recovery
valley between them.

Current compound-bout split rule:

```text
split if valleyBetweenPeaks < 0.50 * min(leftPeak, rightPeak)
```

The bout containing the anchor peak is the anchor's same-bout decomposition.

Fields used in the MATLAB pipeline:

- `nSameBoutSubpeaks`,
- `sameBoutSubpeakIndicesText`,
- `sameBoutSubpeakTimesRelativeSecText`,
- `activeSubpeakSpanSec`,
- `isCompoundEvent = nSameBoutSubpeaks >= 2`,
- `isIsolatedEvent = nSameBoutSubpeaks == 1`.

Older proximity-only fields may also exist:

- `hasNearbyPeak`,
- `isNearbyPeakEvent`.

Use the valley-delimited fields for physiological compound-bout analysis. Use
the proximity-only fields only as contamination/context flags.

### 4. Event Shape Summaries

For grant-style shape plots, align snippets at the estimated onset of the
first subpeak in the bout, not at the dominant peak. This prevents compound
events from looking artificially short due to peak alignment.

For secondary subpeak timing, calculate delays from the first subpeak peak,
not from onset.

Recommended summary panels:

- onset-aligned mean `eventSignal` waveform for unitary vs compound bouts,
- compound-bout raster sorted by first-peak timing,
- compound-bout raster sorted by duration,
- peak latency after onset,
- secondary subpeak timing from first peak,
- within-compound inter-subpeak interval histogram clipped to 0-1.5 s,
- inter-compound interval histogram clipped to 0-20 s.

Use enough bins to show structure. Avoid very coarse histograms.

### 5. Physical-Support Checks

For each detected event or subpeak, compare event-centered windows with
matched random windows from the same recording.

Useful metrics:

- gravity-corrected event/random RMS ratio,
- filtered-magnitude event/random RMS ratio,
- eventSignal event/random RMS ratio,
- waveform similarity between events and between random windows.

The Waseda result so far:

- median gravity-corrected event/random RMS ratio: `1.326`,
- median filtered-magnitude event/random RMS ratio: `1.423`,
- median eventSignal event/random RMS ratio: `2.340`,
- 77.0% of events had gravity-corrected event/random ratio above 1.

Interpretation: events usually carry real acceleration support, but this does
not prove physiology by itself.

### 6. Temporal-Coherence Tests

Temporal coherence asks whether subpeaks inside compound bouts occur at
structured delays.

Avoid counting the anchor peak as evidence for timing structure. Deduplicate
physical bouts, remove the alignment peak from secondary timing histograms,
and compare against a null model.

Recommended null:

- preserve each compound bout's active duration,
- preserve each bout's number of secondary subpeaks,
- randomly place those secondary subpeaks uniformly inside the active span.

Current Waseda result:

- median adjacent within-compound interval: `0.608 s`,
- fraction below 700 ms: `0.673`,
- fraction below 1 s: `0.884`,
- observed timing distribution departs from the uniform-within-bout null.

Do not interpret the 0.35 s minimum subpeak distance as a biological
refractory period. It is detector resolution.

## Current Waseda Summary

After boundary exclusions in the grant-oriented onset-aligned pass:

- usable bouts: `735`,
- unitary bouts: `203`,
- compound bouts: `532`,
- fraction compound: `0.724`,
- median compound subpeaks: `3`,
- median compound active span: `1.184 s`.

These numbers are useful for reproducing the current analysis but should not
be treated as final population estimates.

## Key MATLAB Files In This Repository

Core tracked functions:

- `CODE/ANALYSIS/estimateLocalSignalNoise.m`,
- `CODE/ACCELEROMETER/detectEnvelopeEvents.m`,
- `CODE/ACCELEROMETER/extractEnvelopeEvents.m`,
- `CODE/ACCELEROMETER/extractEnvelopeEventWaveforms.m`,
- `CODE/ACCELEROMETER/analyzePrimitiveEvents.m`,
- `CODE/ACCELEROMETER/plotEnvelopeEventsWithNoiseBand.m`.

Current scratch analysis scripts:

- `scratch/unitary_event_validation_20260508/run_unitary_event_validation_study.m`,
- `scratch/unitary_event_validation_20260508/run_compound_event_decomposition_study.m`,
- `scratch/unitary_event_validation_20260508/run_valley_lobe_compound_decomposition_study.m`,
- `scratch/unitary_event_validation_20260508/run_temporal_coherence_analysis.m`,
- `scratch/unitary_event_validation_20260508/run_min_peak_distance_temporal_sensitivity.m`,
- `scratch/unitary_event_validation_20260508/make_onset_aligned_grant_figures.m`.

Important current output figures:

- `scratch/unitary_event_validation_20260508/outputs/grant_onset_aligned_unitary_vs_compound_event_shapes.png`,
- `scratch/unitary_event_validation_20260508/outputs/grant_lar_trace_1500_2500s_unitary_compound_peaks.png`,
- `scratch/unitary_event_validation_20260508/outputs/temporal_coherence_subpeak_timing.png`,
- `scratch/unitary_event_validation_20260508/outputs/event_vs_random_motion_support.png`,
- `scratch/unitary_event_validation_20260508/outputs/normalized_similarity_controls.png`.

## Figure-Saving Rule For MATLAB

When generating and saving MATLAB figures, always make the figure visible and
portable before `savefig`.

Use explicit figure handles. Do not rely on `gcf` unless unavoidable.

Before `savefig`, set:

```matlab
fig.Visible = 'on';
fig.WindowStyle = 'normal';
fig.WindowState = 'normal';
fig.Units = 'pixels';
fig.Position = [100 100 1200 600];
drawnow;
savefig(fig, filePath);
```

When reopening saved `.fig` files:

```matlab
fig = openfig(filePath, 'reuse', 'visible');
```

## Questions For Simo's Controlled Dataset

Simo's Claude reportedly has accelerometer and motion-capture data from larger
experiments where interoceptive state was appropriately controlled. Prioritize:

- Are event rates different by subject, context, or interoceptive state?
- Are compound-bout fractions different by context/state?
- Do compound-bout durations differ by subject or state?
- Does secondary subpeak timing shift by context/state?
- Are within-compound intervals clustered around similar subsecond delays?
- Do event-shape templates trained on one subject generalize to held-out
  subjects?
- Do accelerometer-defined event times align with marker trajectory events?
- Are marker-trajectory event shapes broader, delayed, or spatially localized
  compared with accelerometer events?
- Do event features explain condition differences better than median motion,
  variance, jerkiness, or total acceleration?

## Validation Work Still Needed

Before making a strong physiological claim:

- calibrate the 0.50 valley rule against hand-labeled examples,
- fit one-, two-, and three-element template models to compound bouts,
- compare fitted-template residuals against random and surrogate windows,
- validate templates on held-out subjects and datasets,
- test accelerometer events against motion-capture marker trajectories,
- report subject-level and context-level results before pooling.
