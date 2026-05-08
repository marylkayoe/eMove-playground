# Acceleration Primitive Events During LAR: Brief For Simo

Updated: 2026-05-08

This note summarizes the current state of the "acceleration primitive events"
work in language intended for a human collaborator. It is written so it can be
read without access to the MATLAB code.

## Main Claim We Can Defend Now

The current Waseda chest-accelerometer analysis supports a cautious claim:

> Low-amplitude residual motion during LAR contains repeatable,
> acceleration-supported event-like motifs, and larger movement bouts often
> contain several such motifs arranged with non-random subsecond timing.

The stronger claim is not yet proven:

> LAR motion consists of true physiological motor primitives.

The present evidence is best treated as a foundation for an event-based
analysis pipeline. It is already more specific than broad summaries such as
median magnitude, variance, or jerkiness, but it still needs validation on
larger controlled datasets and on motion-capture trajectories.

## Data Used So Far

The current analysis used eight Waseda chest accelerometer recordings:

- four subjects,
- desk-work and watching-video contexts,
- chest accelerometer data with orientation/quaternion information,
- MATLAB-converted motion-envelope files.

The important point is that all results so far are exploratory. The Waseda
data are useful for developing the event definitions, but not sufficient for a
final physiological or neuroscientific claim.

## What The Signal Terms Mean

The raw sensor records three-axis acceleration. That raw acceleration includes
body movement, gravity, orientation effects, and possible contact artifacts.
Quaternion orientation data are used to estimate and remove gravity, yielding
a gravity-corrected acceleration estimate. This gravity-corrected signal is
the key reality check: if a detected event does not show support there, it may
be only a processing artifact.

The motion envelope is a one-dimensional motion-intensity trace derived from
the accelerometer data. It is positive, smoother than raw acceleration, and
easier to threshold, but it is not raw motion.

The event detector does not threshold the raw envelope directly. It first
estimates a slow local background level, subtracts that baseline, and keeps
only positive deviations above it:

```text
residual = motion envelope - local baseline
eventSignal = max(residual, 0)
```

In plain language, `eventSignal` asks: "when is movement briefly higher than
the local background?" Candidate events are peaks in this signal.

The local baseline is estimated with a 15 s moving median. Noise is estimated
from the local median absolute deviation of the baseline-subtracted residual
over 30 s. The main event detector then uses a 4-sigma threshold based on the
typical noise level in the recording.

When the example trace figures show a shaded background/noise region, the top
of that region is the same threshold expressed back in original motion-envelope
units:

```text
envelope threshold = local baseline + 4 * median(noiseSigma)
```

Some orange subpeak markers can appear below this main threshold because
compound-bout decomposition uses a lower 2-sigma threshold inside already
detected bouts.

## Event And Compound-Bout Definitions

An event is a threshold-crossing local peak in `eventSignal`. At this stage it
means "candidate primitive-like motion event", not "confirmed motor primitive".

A key issue was how to define compound events. An early proximity definition
flagged an event as compound if another detected peak occurred within a broad
time window. Visual inspection showed this was too crude: peaks can be close
in time but separated by a deep recovery valley, making them more naturally
separate movement episodes.

The current working definition is therefore valley-delimited:

> A compound bout is a movement episode containing two or more subpeaks, where
> adjacent subpeaks remain in the same bout only if the signal does not recover
> through a deep valley between them.

Operationally, adjacent subpeaks are split into separate bouts if the valley
between them falls below:

```text
0.50 * min(left peak height, right peak height)
```

Subpeaks inside the same bout are detected with:

- lower threshold: 2 sigma,
- minimum subpeak separation: 0.35 s,
- search neighborhood around the anchor event: -1.5 to +4.5 s.

The 0.35 s minimum separation was tested against alternatives. Lowering it
does add shorter-lag subpeaks, but the broader temporal-coherence result does
not disappear. We therefore kept 0.35 s as the current detector-resolved
definition.

## Main Findings

The detector found 739 primary peaks across the eight Waseda files. In the
current valley-delimited bout analysis, 735 usable bouts remained after
boundary exclusions:

- unitary bouts: 203,
- compound bouts: 532,
- fraction compound: 0.724,
- median compound subpeaks: 3,
- median compound active span: 1.184 s.

Detected event windows had more gravity-corrected acceleration energy than
matched random windows:

- median gravity-corrected event/random RMS ratio: 1.326,
- median filtered-magnitude event/random RMS ratio: 1.423,
- median eventSignal event/random RMS ratio: 2.340,
- 77.0% of detected events had gravity-corrected event/random RMS ratio above
  1.

This argues against the most pessimistic interpretation that the detector is
finding empty mathematical peaks with no physical acceleration support.

Event waveforms were also more self-similar than random windows:

- eventSignal event-event median similarity: 0.633,
- event-random median similarity: -0.072,
- random-random median similarity: -0.033,
- filtered-magnitude event-event median similarity: 0.301.

The similarity is strongest in the detector's native `eventSignal`, so it
should not be overinterpreted. The important positive result is that similarity
is not restricted entirely to a meaningless scalar artifact; there is also
weaker but measurable support in acceleration-derived signals.

## Temporal Coherence

Temporal coherence asks whether subpeaks inside compound bouts are arranged in
time in a structured way, rather than appearing at arbitrary positions.

The corrected analysis treats each physical bout once, aligns the bout to its
first or dominant subpeak depending on the panel, and then examines the timing
of the other detected subpeaks. The large spike at zero in early plots was
partly a consequence of aligning each bout to a peak and then counting that
same peak. Later summaries separate the anchor peak from secondary subpeaks.

For compound bouts:

- median adjacent within-compound interval: 0.608 s,
- 67.3% of within-compound intervals were below 700 ms,
- 88.4% were below 1 s.

Compared with a null model that preserves each bout's duration and number of
subpeaks but places secondary subpeaks uniformly within the bout, the observed
timing distribution showed clear departure from random timing. This matters
because a compound event hypothesis predicts organized subpeak timing; random
clusters of peaks do not.

## How To Read The Current Grant Figure

The current grant-oriented summary figure is:

`scratch/unitary_event_validation_20260508/outputs/grant_onset_aligned_unitary_vs_compound_event_shapes.png`

The most important panels are:

- onset-aligned unitary and compound average shapes,
- compound-bout rasters sorted by first-peak timing and by bout duration,
- peak-latency distributions,
- within-compound subpeak interval histogram,
- inter-compound interval histogram.

The compound rasters use color to show normalized event-signal amplitude
within each bout. Cyan dots mark detected subpeaks. Rows are individual
compound bouts. In the first-peak-sorted raster, the leading cyan-dot boundary
shows when the first detected subpeak occurs relative to estimated bout onset.
In the duration-sorted raster, shorter compound bouts are placed at the top and
longer ones at the bottom.

The current example trace figure is:

`scratch/unitary_event_validation_20260508/outputs/grant_lar_trace_1500_2500s_unitary_compound_peaks.png`

It shows the original motion envelope over a 1000 s LAR-like region. Blue dots
mark unitary primary peaks. Orange dots mark subpeaks belonging to
valley-delimited compound bouts. The gray shaded region indicates the primary
event detector's background/noise region.

## Physiological Interpretation

The data are consistent with the idea that low-amplitude LAR motion is not just
diffuse noise or a single bulk activity level. It appears to contain brief
motion events, some occurring alone and many occurring as subelements of larger
movement bouts.

If this holds in better-controlled datasets, it would support a useful
neuroscientific framing: LAR micromotion may be describable as a sequence of
discrete motor-output fragments or postural micro-adjustments, with event rate,
event timing, and compound-bout organization varying across subjects and
internal states.

This could be cleaner than broad movement features because it separates:

- how often events occur,
- how large events are,
- how events combine into bouts,
- how subpeaks are timed,
- whether event morphology is conserved across contexts.

## What Simo's Controlled Dataset Should Test

Simo's larger experiments, especially if interoceptive state was controlled,
are the right next place to test whether this becomes a real analytical
pipeline. Key questions:

- Do event rates differ between subjects, contexts, or interoceptive states?
- Do compound-bout fractions differ between contexts?
- Does compound-bout duration differ by subject or state?
- Do within-compound subpeak intervals shift between contexts?
- Is there a stable timing mode around the same subsecond range?
- Are unitary-event shapes conserved across subjects after amplitude
  normalization?
- Do accelerometer-defined events have corresponding structure in
  motion-capture marker trajectories?
- If marker trajectories show events, are their dynamics delayed, smoothed, or
  spatially redistributed compared with accelerometer events?
- Does event organization predict experimental variables better than median
  magnitude, variance, jerkiness, or total motion?

## Current Caveats

The detector can still impose some shape because it detects peaks in a
processed event signal. Surrogate controls showed that detector-compatible
waveforms can appear in altered data, so raw/gravity-corrected support and
held-out validation are essential.

The compound definition is still provisional. The 0.50 valley fraction matches
current visual intuition better than the earlier broad-window rule, but it
should be calibrated against hand-labeled examples.

The Waseda sample is small. Subject imbalance and context differences can
easily dominate pooled figures. Future reports should show subject-level and
context-level results, not only pooled summaries.

The best current wording is therefore:

> The current evidence supports acceleration-supported primitive-like events
> and structured compound bouts during LAR. It does not yet prove a universal
> physiological motor primitive.
