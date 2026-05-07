# Derivative Boundary Exploration (2026-05-08)

This note documents the exploratory attempt to define event limits from
visible waveform notches rather than from local minima alone.

The work is provisional. It does not replace the current detector or the main
primitive-event analysis.

## Question

The averaged event waveforms show notches or elbows on both sides of the
peak. The working question was whether those notches mark the real event
entry and exit points better than the current minimum-within-window rule.

The analogy was action-potential analysis, where first- or second-derivative
features are often used as landmarks for onset, offset, or phase transitions.

## Current Main-Pipeline Boundary Rule

The current main extractor still uses existing detected peaks and defines:

- start = minimum before the peak, searched no further than `2.0 s`
- end = minimum after the peak, searched no further than `2.0 s`

This remains the main operational definition in `extractEnvelopeEvents` and
`analyzePrimitiveEvents`.

## Exploratory Derivative Boundary Rule

The exploratory function is:

- [estimateEnvelopeEventDerivativeBoundaries.m](/Users/yoe/Documents/REPOS/eMove-playground/CODE/ACCELEROMETER/estimateEnvelopeEventDerivativeBoundaries.m)

It:

- reuses existing peak indices
- does not redetect events
- works on the baseline-relative event signal
- smooths the signal
- computes first and second derivatives
- searches pre- and post-peak flanks for positive second-derivative notches
- returns a boundary table for inspection

The exploratory scratch runner is:

- `scratch/primitive_event_boundary_notches_20260507/run_derivative_boundary_exploration.m`

## Current Exploratory Settings

The settings used in the scratch exploration were:

- pre-peak search window: `2.0 s`
- post-peak search window: `2.0 s`
- smoothing window: `0.20 s`
- start search allowed up to `70%` of the peak amplitude
- end search allowed up to `85%` of the peak amplitude
- same isolated peaks as the main primitive-event analysis

All boundary decisions were made in sample-index space. Seconds were used for
reporting and plotting.

## Results

The derivative rule was applied to `586` isolated events from the current
Waseda chest-envelope analysis.

Median offsets relative to the detected peak:

- current start: `-2.016 s`
- derivative start: `-0.928 s`
- current end: `1.376 s`
- derivative end: `0.896 s`
- current duration: `3.136 s`
- derivative duration: `1.728 s`

The derivative rule moved both boundaries inward toward the visible notches.
This supports the idea that the notches may represent a useful central-event
boundary hypothesis.

## Figures

Scratch outputs are under:

- `scratch/primitive_event_boundary_notches_20260507/outputs`

Most relevant figures:

- `derivative_boundary_offsets.png`
- `derivative_boundary_grouped_waveforms.png`
- `derivative_boundary_start_aligned_waveforms.png`
- `derivative_boundary_duration_comparison.png`

The peak-aligned derivative-boundary figure still shows pre- and post-peak
shoulder structure. The start-aligned version makes the rise more coherent,
but a post-start shoulder or plateau remains.

## Interpretation

The derivative/notch method is promising as a diagnostic boundary layer, but
it is not ready to replace the current event definition.

The main unresolved issue is contamination by nearby event-like structure:

- some neighboring bumps are too small to be detected as separate peaks
- therefore they are not caught by the current compound-event flag
- those subthreshold neighbors can still contaminate mean waveforms

This means that "isolated event" is still detector-dependent. It currently
means isolated from other detected peaks, not necessarily isolated from all
nearby movement structure.

## Recommended Next Step

Do not immediately raise the detector threshold as the main fix. That would
reduce contamination but also bias the sample toward larger events.

A better next analysis layer would keep the existing detector and add an
event-level contamination score, for example:

- largest secondary local maximum within the pre/post window
- valley depth between main peak and secondary bump
- extra area outside the derivative-defined core
- strongest derivative notch outside the candidate event core

Then regenerate grouped means after excluding events with high contamination
scores.

This would test whether the primitive-event shape becomes cleaner without
changing which peaks the detector originally found.

## References Used

No external literature was consulted during this exploratory pass.

The references were:

- the current local MATLAB functions
- the user's action-potential analogy
- standard signal-processing logic that smoothed derivatives can identify
  slope and curvature transitions
