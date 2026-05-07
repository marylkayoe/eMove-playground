# Portable Primitive Event Agent Brief (2026-05-07)

This document is meant to be copied into another repository where we will
work on related accelerometer-envelope analyses with Simo.

The goal is not to preserve MATLAB syntax. The goal is to preserve:

- the scientific question
- the current hypotheses
- the important implementation choices
- the minimal analysis functions that need to exist
- the main failure modes and cautions

Use this as an agent-facing brief.

## 1. Core Question

We are looking for a possible primitive event-like fluctuation in a
movement-envelope signal derived from accelerometer data.

The working question is:

- does the envelope contain a recurring event morphology that is relatively
  stable across subjects and contexts, even if amplitude and timing vary?

This means we care about three partially separate things:

1. event amplitude
2. event timing / inter-event intervals
3. event shape

The current hypothesis is:

- amplitude may be subject- and context-dependent
- inter-event interval may be subject- and context-dependent
- normalized event shape may be more conserved

So the shape question should not be collapsed into amplitude or rate.

## 2. Signal Assumptions

The analysis assumes one 1D envelope-like signal per trial or recording.

That signal may come from:

- gravity-corrected accelerometer magnitude
- band-limited movement energy
- RMS envelope of acceleration magnitude
- or another comparable movement-envelope representation

The upstream preprocessing can vary by project, but the downstream event
analysis assumes:

- one numeric signal vector
- one known sampling frequency
- enough duration to estimate local baseline and local noise

## 3. Main Conceptual Insight

The useful signal for event detection is usually not the raw envelope
itself.

A better working signal is:

- local-baseline-relative
- upward-only
- noise-aware

So the current event workflow uses a derived signal:

- `residual = signal - baseline`
- `eventSignal = max(residual, 0)`

This does two things:

1. it removes slow local drift
2. it makes the event-shape question easier to interpret as "fluctuation
   above local baseline"

Important:

- shape plots based on `eventSignal` are not raw-envelope shapes
- they are baseline-relative, rectified event shapes

That distinction should remain explicit in any future repository.

## 4. Current Working Hypotheses

### 4.1 Event existence hypothesis

The envelope may contain repeatable local burst-like events rather than
only diffuse fluctuation.

### 4.2 Subject/context hypothesis

Subjects and contexts may differ strongly in:

- how often events happen
- how large they are
- how widely spaced they are

These differences do not rule out a shared event morphology.

### 4.3 Morphology hypothesis

After normalization, event waveforms or event-centered time-frequency maps
may look more similar across conditions than raw amplitudes do.

### 4.4 Negative possibility

It may turn out there is no single primitive event class, only a mixture of:

- isolated simple events
- compound events
- weak local fluctuations
- detector-dependent fragments

So all downstream claims should be framed as exploratory until that is
tested carefully.

## 5. Practical Analysis Logic

The current logic can be implemented in any language.

### Step 1. Estimate local baseline and local noise

Input:

- `signal`
- `samplingFrequency`

Output:

- `baseline`
- `residual`
- `eventSignal`
- `noiseSigma`

Recommended current defaults:

- baseline window: `15 s`
- noise window: `30 s`
- rectify residual: `true`

### Step 2. Detect candidate peaks

Detect peaks on `eventSignal`, not on the raw signal.

Current practical defaults:

- threshold: about `4 * noise`
- minimum peak spacing: about `0.5 s`

There is also a valley rule to avoid over-splitting or under-splitting close
peaks.

Current working detector parameter:

- `valleyFraction = 0.2`

Exact implementation can differ by language, but conceptually it should:

- find local maxima
- reject noise-level maxima
- avoid creating duplicate peaks from one broad event
- still allow close peaks if a real valley separates them

### Step 3. Flag compound events

This is important because many suspicious mean-waveform results come from
averaging multi-peak or overlapping events as if they were primitive events.

Current compound-event rule:

- flag as compound if another detected peak occurs:
  - within `1.0 s` before the peak
  - or within `4.0 s` after the peak

This produces:

- `isCompoundEvent`
- `isIsolatedEvent`

Current shape summaries are built from isolated events only.

### Step 4. Extract aligned event snippets

Current event-boundary rule:

- start = minimum before peak within the last `2.0 s`
- end = minimum after peak within the next `2.0 s`

Alignment:

- align by peak

Important implementation rule:

- do event extraction and alignment in sample-index space
- do not use per-event original time vectors to define aligned x-axes

Instead use one shared relative sample vector:

```text
relativeSampleIndex = -preSamples : postSamples
relativeTimeSec = relativeSampleIndex / samplingFrequency
```

Then store snippets as:

- rows = relative samples
- columns = events

This matters because averaging event-specific time axes caused small
backward/zigzag horizontal artifacts in mean plots.

### Step 5. Compute scalar event summaries

At minimum keep:

- detector amplitude
- detector width
- inter-event interval

The detector width and extractor width are not the same quantity. Keep that
explicit.

For current summary plots, detector width is the main width metric.

### Step 6. Compare waveform morphology

Build mean aligned waveforms by:

- file
- subject
- condition

Useful normalized view:

- shift each event so its first value is 0
- optionally normalize peak to 1

This gives:

- raw aligned mean shape
- peak-normalized aligned mean shape

### Step 7. Compare wavelet morphology

Add a separate event-aligned wavelet layer without changing the detector.

Current logic:

1. use existing detected peaks
2. extract a fixed peak-centered window, currently `[-5 5] s`
3. work from baseline-relative `eventSignal`
4. subtract snippet median
5. normalize snippet by max absolute amplitude
6. compute CWT
7. use `abs(CWT)`
8. normalize each wavelet map by its own maximum

Then compute:

- mean normalized wavelet map by condition
- mean normalized wavelet map by subject
- event-event wavelet similarity matrix
- within/between condition similarity distributions
- within/between subject similarity distributions

Similarity metric:

- correlation of flattened normalized wavelet maps

### Step 8. Random control

The wavelet analysis should include a random-window control.

For each file:

- sample random non-event windows
- avoid the event windows
- compute the same normalized wavelet maps

Then compare:

- event-event similarity
- event-random similarity

This tests whether detected event structure is more self-similar than random
background fluctuation.

## 6. Key Implementation Principles

These are more important than the exact language.

### 6.1 Work in indices internally

Do detection, alignment, neighbor checks, and snippet extraction in sample
indices.

Convert to seconds only for:

- reporting
- plotting
- exported summary tables

### 6.2 Keep the detector and downstream summaries separate

Do not let downstream waveform logic silently change which peaks exist.

The clean split is:

1. baseline/noise estimation
2. peak detection
3. compound-event flagging
4. waveform extraction
5. wavelet similarity

### 6.3 Keep normalized-shape analyses distinct from amplitude analyses

Do not mix these interpretations.

If waveforms or wavelet maps are normalized, state clearly:

- this is testing morphology, not amplitude

### 6.4 Preserve inspectable intermediate products

At minimum keep access to:

- baseline
- residual
- eventSignal
- peak locations
- compound flags
- aligned waveform matrix
- event table
- event-centered wavelet maps

If these are hidden, it becomes too hard to debug why summary plots look odd.

## 7. Minimal Function Set To Recreate

The names do not need to match exactly, but the roles should.

### Function 1. Baseline/noise estimation

Suggested role:

- `estimateLocalSignalNoise(signal, samplingFrequency, ...)`

Should return:

- `baseline`
- `residual`
- `eventSignal`
- `noiseSigma`

### Function 2. Peak detection

Suggested role:

- `detectEnvelopeEvents(eventSignal, noiseSigma, ...)`

Should return at least:

- peak indices
- peak amplitudes
- detector widths

### Function 3. Waveform extraction

Suggested role:

- `extractEnvelopeEventWaveforms(signal, peakIndices, ...)`

Should return at least:

- aligned waveform matrix
- shared relative sample/time vector
- event table with boundaries and width metrics

### Function 4. Trial-level wrapper

Suggested role:

- `extractEnvelopeEvents(signal, samplingFrequency, ...)`

Should:

- call the three steps above
- attach compound-event flags
- return one structured output per recording

### Function 5. Folder- or dataset-level summary

Suggested role:

- `analyzePrimitiveEvents(recordings, ...)`

Should:

- run the trial-level extraction across all recordings
- build one combined event table
- build subject/condition summaries
- generate core figures

### Function 6. Event-aligned wavelet similarity

Suggested role:

- `analyzeEventAlignedWaveletSimilarity(analysisOutput, ...)`

Should:

- reuse existing event peaks
- not redetect events
- compute normalized event-centered CWT maps
- return similarity outputs and control summaries

## 8. Expected Outputs

At minimum, the future repository should be able to produce:

### Event table

Fields should include:

- recording ID
- subject ID
- condition
- peak index
- peak time
- amplitude
- width
- inter-event interval
- compound flag
- isolated flag

### Figures

Recommended core figures:

1. grouped mean event waveforms
2. amplitude CDFs by condition
3. amplitude CDFs by subject
4. inter-event interval CDFs by condition
5. inter-event interval CDFs by subject
6. width-amplitude scatter
7. mean normalized wavelet maps by condition
8. wavelet similarity matrix
9. wavelet similarity CDFs
10. random-control wavelet comparison

### Stored analysis outputs

One combined analysis object should retain:

- per-recording outputs
- full event table
- grouped summary tables
- waveform summaries
- wavelet outputs

## 9. Main Failure Modes To Watch

### 9.1 Detector defines reality too strongly

If the detector misses subpeaks or merges nearby peaks, downstream shape
averages can become misleading.

### 9.2 Compound events contaminate "primitive" means

This is the main reason to keep isolated-event filtering explicit.

The current isolated-event flag is still detector-dependent. It catches
nearby detected peaks, but it does not catch smaller nearby bumps that fail
to cross the detector threshold. Those subthreshold neighbors can still
contaminate mean event shapes.

Recommended next extension:

- keep the detector unchanged
- add an event-level contamination score
- base it on secondary local maxima, valley depth, or extra signal outside
  the candidate event core
- use that score to filter or stratify morphology summaries

### 9.3 Raw-envelope and eventSignal interpretations get mixed

That causes confusion when discussing amplitude, baseline, and shape.

### 9.4 Time-base handling becomes sloppy

Aligned means should use a shared relative axis, not per-event original time
vectors.

### 9.5 Over-cleaning

Do not erase legitimate small events by making preprocessing too aggressive.

### 9.6 Boundary definition is still provisional

A derivative/notch-based boundary layer was tested after visible notches
appeared in peak-aligned mean waveforms.

The exploratory logic:

- reuse existing peaks
- smooth the baseline-relative event signal
- compute first and second derivatives
- use positive second-derivative flank notches as candidate starts and ends

Current read:

- the method moves boundaries inward toward the visible notches
- start-aligned means become cleaner on the rising side
- shoulder or plateau structure remains in some groups
- therefore the method is diagnostic, not yet a replacement for the main
  event definition

Details are documented in:

- [DERIVATIVE_BOUNDARY_EXPLORATION_2026-05-08.md](/Users/yoe/Documents/REPOS/eMove-playground/docs/DERIVATIVE_BOUNDARY_EXPLORATION_2026-05-08.md)

## 10. Current Strategic Insight

The most important scientific idea to preserve is this:

- there may not be one universally fixed event amplitude or rate
- but there may still be a recurring normalized event morphology

So the analysis should explicitly separate:

- "how big or frequent are events?"
from
- "do the events look like variations of the same primitive shape?"

## 11. Direct Message To A Future Agent

If you are reading this in another repository:

- do not start by inventing a broad framework
- first recreate the logic above in small inspectable functions
- keep all event decisions transparent
- work in sample indices internally
- treat waveform and wavelet normalization as morphology analysis, not
  amplitude analysis

If you can reproduce:

- event tables
- aligned mean waveforms
- condition/subject CDF summaries
- event-aligned normalized wavelet similarity

then you have captured the core of the current approach.
