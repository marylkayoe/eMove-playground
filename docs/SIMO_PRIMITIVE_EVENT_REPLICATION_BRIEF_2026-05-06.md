# Primitive Event Replication Brief For Simo (2026-05-06)

This note is for Simo and for an agent that will need to rebuild the
analysis without MATLAB.

Short answer:

- yes, Claude should be able to reproduce the same kind of analysis on a
  different accelerometer dataset
- but the previous handoff note is MATLAB- and repository-oriented
- for a from-scratch implementation, the agent also needs a plain-language
  statement of the scientific goal, the exact event logic, and the expected
  outputs

This document is meant to provide that.

## 1. What We Are Looking For

We are not trying to classify large body movements in a generic way.

We are looking for a small, repeatable, event-like fluctuation in an
accelerometer-derived movement envelope.

The working hypothesis is:

- event amplitude may vary across people and conditions
- event rate / inter-event interval may vary across people and conditions
- but the event *shape* may be more stable

So the target is a possible "primitive envelope event":

- a local burst-like fluctuation in the envelope
- that can be detected repeatedly in a recording
- and whose normalized waveform or normalized time-frequency structure may
  look similar across subjects and contexts

The important idea is:

- this is a morphology question, not only a count or amplitude question

## 2. Input Signal Assumptions

The current pipeline starts from a 1D movement envelope time series.

In our case this envelope came from chest accelerometer data after:

1. gravity correction
2. bandpass filtering
3. vector magnitude
4. 1-second RMS envelope

But Simo does not need to match the upstream preprocessing exactly if their
dataset already has a comparable 1D movement-magnitude or movement-envelope
signal.

What matters for the current stage is:

- one signal vector per recording
- a known sampling frequency
- enough recording length to estimate local baseline and noise

## 3. Conceptual Pipeline

The current event-analysis logic is:

1. Estimate slow baseline and local noise from the envelope.
2. Build a baseline-relative signal.
3. Rectify it so only upward event-like fluctuations remain.
4. Detect peaks above a noise-scaled threshold.
5. Exclude compound events using nearby-peak logic.
6. Extract peak-centered event snippets.
7. Compare:
   - amplitudes
   - widths
   - inter-event intervals
   - mean aligned waveforms
   - normalized wavelet maps

Important:

- event detection is done on the baseline-relative rectified signal
- waveform-shape summaries are also currently based on that same
  baseline-relative signal, not on the raw envelope

## 4. Plain Implementation Spec

This section is the most important if the analysis is being rewritten from
scratch in Python or another language.

### 4.1 Baseline and noise estimation

Given:

- `signal`: 1D envelope
- `fs`: sampling frequency in Hz

Use:

- baseline window: 15 s
- noise window: 30 s

Compute:

- `baseline`: slow local trend of the envelope
- `residual = signal - baseline`
- `eventSignal = max(residual, 0)`

Then estimate local noise scale:

- robustly within a moving 30 s window
- something like local MAD or another robust sigma estimate is acceptable

The downstream detector expects:

- one `eventSignal`
- one local `noiseSigma`

### 4.2 Peak detection

Detect peaks on `eventSignal`.

Current working thresholds:

- threshold = `4 * typicalNoise`
- minimum peak separation around `0.5 s`

In the MATLAB version the detector:

- uses `findpeaks`
- then applies a valley rule to decide whether nearby peaks remain separate

Current detector parameter:

- `valleyFraction = 0.2`

Interpretation:

- if two nearby peaks have a sufficiently deep valley between them, keep
  them separate
- otherwise merge or suppress one of them

For a rewrite, the exact detector implementation does not need to be
 MATLAB-specific, but it should behave similarly:

- local maxima on `eventSignal`
- thresholded by noise level
- not too close together
- not split aggressively unless the valley is real

### 4.3 Compound-event exclusion

This is important.

After peak detection, define an event as "compound" if another detected peak
 falls near it.

Current rule:

- another peak within 1.0 s before
- or within 4.0 s after

If either is true:

- `isCompoundEvent = true`
- `isIsolatedEvent = false`

The main summaries currently use isolated events only.

This is not a perfect compound-event detector, because it depends on which
subpeaks were actually detected. But it is the current practical filter.

### 4.4 Event waveform extraction

For each detected isolated peak:

- define event start as the minimum before peak within the last 2.0 s
- define event end as the minimum after peak within the next 2.0 s

Then align waveforms by peak.

Important implementation detail:

- do this in sample-index space, not in floating-point time space

Use a shared relative sample vector:

```text
relativeSampleIndex = -preSamples : postSamples
relativeTimeSec = relativeSampleIndex / fs
```

Store snippets as:

- rows = relative samples
- columns = events

Then compute:

- mean waveform across events using column selection and row-wise mean

Do not build waveform x-axes from original exported time vectors per event.
That previously caused small zigzag artifacts in averaged traces.

### 4.5 Scalar event measures

For each event, compute at least:

- peak amplitude on the detector signal
- detector-given width
- inter-event interval from successive peak times

We also computed an extractor half-height width, but for current summaries
the main width measure is the detector width.

### 4.6 Wavelet similarity analysis

This is the new layer.

For each detected isolated event:

1. take a fixed peak-centered window, currently `[-5 5] s`
2. extract snippet from the same baseline-relative event signal
3. subtract snippet median
4. normalize snippet by its max absolute value
5. compute CWT
6. take `abs(CWT)`
7. normalize each wavelet map by its own maximum

Current wavelet settings:

- wavelet: `amor`
- frequency range: `0.2 to 10 Hz`
- voices per octave: `12`

Then compute:

- mean normalized wavelet map by condition
- mean normalized wavelet map by subject
- event-by-event similarity matrix
- similarity distributions:
  - within condition
  - between condition
  - within subject
  - between subject

Similarity metric:

- correlation between flattened normalized wavelet maps

### 4.7 Random control

This is needed so that event similarity is not interpreted without context.

For each file:

- sample random peak-centered windows from non-event parts of the same file
- avoid the existing event windows
- compute the same normalized wavelet maps for those random windows

Then compare:

- event-event similarity
- event-random similarity

The question is:

- are detected events more mutually similar than random non-event windows?

## 5. What Outputs Are Expected

At minimum the rewrite should produce:

### Event-level table

For each event:

- file ID
- subject ID
- condition
- peak sample
- peak time
- amplitude
- width
- inter-event interval
- compound / isolated flag

### Waveform summaries

- mean aligned waveform by file
- mean aligned waveform by subject
- mean aligned waveform by condition

### Scalar distribution summaries

Use CDFs rather than histograms for the main reporting figures.

At minimum:

- amplitude CDF by condition
- amplitude CDF by subject
- width CDF by condition
- width CDF by subject
- inter-event interval CDF by condition
- inter-event interval CDF by subject

### Wavelet summaries

- mean normalized wavelet maps by condition
- mean normalized wavelet maps by subject
- event-by-event similarity matrix
- similarity CDFs:
  - within condition
  - between condition
  - within subject
  - between subject
- random-control comparison:
  - event-event vs event-random similarity

## 6. What Has Been Observed So Far In Our Data

Current findings in the Waseda data:

- subject effects are strong
- condition effects exist but are smaller and less clean
- event amplitudes and inter-event intervals vary substantially by subject
- the event-shape question remains open
- the wavelet analysis was added specifically to test whether normalized
  event structure is more stable than amplitude

So the sought outcome is not:

- "all subjects have the same event rate"

The sought outcome is more like:

- "there may exist a normalized envelope-event morphology that recurs across
  contexts, even though amplitude and timing differ"

## 7. Known Failure Modes

These matter for replication.

### 7.1 Detector dependence

Everything downstream depends on peak detection.

If the detector:

- misses subpeaks
- over-splits noisy peaks
- merges genuine compound events

then the waveform and wavelet summaries will change.

### 7.2 Compound events are hard

Many seemingly single events actually have extra bumps or tails.

A major reason for the isolated-event filter is to avoid averaging compound
shapes and calling the result a primitive event.

### 7.3 Baseline-relative signal is not the raw envelope

Current event-shape plots are based on:

- `eventSignal = max(signal - baseline, 0)`

This makes event morphology easier to compare, but it also changes what is
meant by "shape". It is a shape above baseline, not the raw envelope trace.

### 7.4 Exact upstream preprocessing may matter

If Simo's dataset uses:

- a different envelope definition
- different smoothing
- different bandpass logic

then the event detector may need retuning.

That is acceptable. The key is to preserve the logic of:

- baseline-relative event detection
- isolated-event filtering
- aligned waveform comparison
- normalized wavelet similarity

## 8. Recommendation To Simo

If you or your agent are implementing this from scratch:

1. Do not start by optimizing the detector.
2. First recreate the exact logic above as simply as possible.
3. Work in sample indices internally.
4. Only convert to seconds for reporting and plotting.
5. Keep event detection and wavelet similarity as separate steps.
6. Use isolated events only for the morphology summaries.
7. Inspect intermediate figures often.

The fastest useful port would be:

- Python
- NumPy / SciPy
- pandas
- matplotlib
- PyWavelets or SciPy wavelet tools

But the language does not matter as long as the logic is preserved.

## 9. Message To The Agent

The task is not to build a general activity-recognition system.

The task is to test a narrow scientific idea:

- does the movement envelope contain a recurring primitive event-like shape
  that is conserved more in morphology than in amplitude or timing?

Please keep the implementation transparent.

Prefer:

- small functions
- explicit parameters
- tables or dict-like event outputs
- fixed, inspectable intermediate products

Avoid:

- large frameworks
- hidden preprocessing assumptions
- aggressive auto-cleaning that removes legitimate small events

If your first pass reproduces:

- event CDF summaries
- mean aligned waveforms
- normalized wavelet similarity summaries

then you are already doing the right analysis.

## 10. Relevant Files In This Repository

Main documentation:

- [PRIMITIVE_EVENT_ANALYSIS_HANDOFF_2026-05-06.md](/Users/yoe/Documents/REPOS/eMove-playground/docs/PRIMITIVE_EVENT_ANALYSIS_HANDOFF_2026-05-06.md)

Current tracked figures:

- [WASEDA_ACC_PRIMITIVE_EVENTS_20260506](/Users/yoe/Documents/REPOS/eMove-playground/figures/WASEDA_ACC_PRIMITIVE_EVENTS_20260506)

Main current outputs:

- [analysisOutput_current.mat](/Users/yoe/Documents/REPOS/eMove-playground/scratch/waseda_event_summary_20260506/function_outputs/analysisOutput_current.mat)
- [waveletOutput_current.mat](/Users/yoe/Documents/REPOS/eMove-playground/scratch/waseda_event_summary_20260506/function_outputs/waveletOutput_current.mat)

If needed, another agent can use those outputs as a reference target while
re-implementing the logic elsewhere.
