# Primitive Event Analysis Handoff (2026-05-06)

This note documents the current MATLAB workflow for extracting and summarizing
putative primitive envelope events from the Waseda chest accelerometer
magnitude files.

The intent is not to claim that the present detector is final or validated.
The intent is to make the current logic explicit enough that another agent can:

- understand the scientific question,
- reproduce the same analysis on the current dataset,
- and adapt the workflow to another dataset without guessing which choices
  were in force.

## 1. Question

The current question is:

- can a primitive event-like fluctuation be identified in the chest
  accelerometer envelope across subjects and across task contexts?

The working hope is:

- event amplitude and inter-event timing may vary by subject and condition,
- but a more stable event shape may exist across contexts and subjects.

Current contexts in this dataset:

- `desk_work_stand`
- `watching_videos_stand`

Current data scope:

- 8 chest magnitude files
- subjects `sub1` to `sub4`
- one desk-work and one video file per subject, except that the two `sub1`
  files are from a different session date than `sub2-sub4`

## 2. Input Data

The current analysis consumes the magnitude MAT files in:

- `/Users/yoe/Dropbox/WORK/Data/Waseda-ACC/MAGNITUDES`

Each MAT file contains `motionData` with:

- `timeSec`
- `motionEnvelope`
- `gravityCorrectedAcc`
- `meta`

The event analysis currently uses:

- `motionData.motionEnvelope`
- `motionData.timeSec`
- `motionData.meta.sampleRateHz`

Important conceptual point:

- the event-shape summaries are now extracted from `noiseEstimate.eventSignal`,
  not directly from the raw `motionEnvelope`
- `eventSignal` is the baseline-relative residual after noise-estimation
  preprocessing, rectified so negative residual values are set to zero

That means the shape plots are currently baseline-relative event shapes, not
raw-envelope trajectories.

## 3. Core Functions

The present workflow uses these functions:

- [estimateLocalSignalNoise.m](/Users/yoe/Documents/REPOS/eMove-playground/CODE/ANALYSIS/estimateLocalSignalNoise.m)
- [detectEnvelopeEvents.m](/Users/yoe/Documents/REPOS/eMove-playground/CODE/ACCELEROMETER/detectEnvelopeEvents.m)
- [extractEnvelopeEventWaveforms.m](/Users/yoe/Documents/REPOS/eMove-playground/CODE/ACCELEROMETER/extractEnvelopeEventWaveforms.m)
- [extractEnvelopeEvents.m](/Users/yoe/Documents/REPOS/eMove-playground/CODE/ACCELEROMETER/extractEnvelopeEvents.m)
- [analyzePrimitiveEvents.m](/Users/yoe/Documents/REPOS/eMove-playground/CODE/ACCELEROMETER/analyzePrimitiveEvents.m)

### 3.1 `estimateLocalSignalNoise`

Purpose:

- estimate a slow local baseline
- estimate residual signal relative to that baseline
- estimate a local robust noise scale

Outputs used downstream:

- `baseline`
- `residual`
- `eventSignal`
- `noiseSigma`

Current meaning of `eventSignal`:

- `eventSignal = residual`
- then values below zero are clipped to zero when `RectifyResidual = true`

### 3.2 `detectEnvelopeEvents`

Purpose:

- detect candidate event peaks in `eventSignal`

Key current behavior:

- thresholding uses a typical noise level from `median(noiseSignal, 'omitnan')`
- detection uses MATLAB `findpeaks`
- a valley-based merging rule is then applied so close peaks can be kept
  separate or merged depending on the depth of the valley between them

Current important local parameter in the code:

- `valleyFraction = 0.2`

This value lives inside `detectEnvelopeEvents.m` and is not currently exposed
as a wrapper parameter.

Outputs used downstream:

- `peakLocations`
- `peakValues`
- `peakWidths`

Important warning:

- `detectEnvelopeEvents` still returns peak widths from `findpeaks`
- those widths are detector widths, not waveform-extractor widths

### 3.3 `extractEnvelopeEventWaveforms`

Purpose:

- take detected peak locations and extract waveforms around them

Current event definition:

- start:
  - minimum before the peak
  - but only searched within the last `2.0 s` before the peak
- end:
  - minimum after the peak
  - but only searched within the next `2.0 s` after the peak
- alignment:
  - waveforms are currently aligned by peak

Current waveform source:

- the function is now called on `noiseEstimate.eventSignal`
- so extracted shapes are baseline-relative and rectified

Current width metric from the extractor:

- `halfHeightWidthSamples`
- `halfHeightWidthSec`

These are computed from the extracted waveform on the `eventSignal` scale.

### 3.4 `extractEnvelopeEvents`

Purpose:

- wrap the three core steps:
  1. noise estimation
  2. peak detection
  3. waveform extraction

It also:

- converts detector widths to seconds for reporting
- adds compound-event flags to the event table

Current compound-event logic:

- event flags are computed strictly in sample-index space, not seconds
- an event is marked as compound if another detected peak falls within:
  - `1.0 s` before the peak
  - `4.0 s` after the peak

Current event-table flags:

- `hasNeighborBefore`
- `hasNeighborAfter`
- `isCompoundEvent`
- `isIsolatedEvent`

### 3.5 `analyzePrimitiveEvents`

Purpose:

- run `extractEnvelopeEvents` across all magnitude files in a folder
- compile the outputs into one MATLAB structure
- generate summary figures

Current default behavior:

- uses isolated events only for summary analysis:
  - `UseIsolatedEventsOnly = true`
- uses detector amplitudes and detector widths for scalar summaries
- uses baseline-relative `eventSignal` waveforms for shape summaries

## 4. Current Effective Parameter Set

This section captures the current settings that matter most.

### 4.1 Noise estimation

From `estimateLocalSignalNoise` through the wrapper:

- `BaselineWindowSeconds = 15`
- `NoiseWindowSeconds = 30`
- `RectifyResidual = true`

### 4.2 Peak detection

From `extractEnvelopeEvents` plus the current detector file:

- `ThresholdSigma = 4`
- `MinPeakDistanceSeconds = 0.5` inside `detectEnvelopeEvents`
- `valleyFraction = 0.2` inside `detectEnvelopeEvents`

### 4.3 Waveform extraction

From `extractEnvelopeEventWaveforms`:

- `MaxStartLookbackSeconds = 2.0`
- `MaxEndLookaheadSeconds = 2.0`
- alignment by peak
- waveform source signal = `noiseEstimate.eventSignal`

### 4.4 Compound-event exclusion for summaries

From `extractEnvelopeEvents` and `analyzePrimitiveEvents`:

- compound-pre window = `1.0 s`
- compound-post window = `4.0 s`
- summaries use `isIsolatedEvent == true`

## 5. Why The Workflow Ended Up Here

Several earlier variants were tried and rejected or demoted:

- onset-aligned mean waveforms often looked misleading because the late
  portion of the mean was supported by fewer events and could fail to turn
  down
- event-end rules based only on local minima were too vulnerable to
  compound events and noise
- event-end rules based on fixed fraction of peak did not solve the core
  issue when events were not actually isolated
- raw-envelope waveform plots were harder to interpret because baseline
  level and slow drift contaminated shape inspection

The current compromise is:

- detect events on `eventSignal`
- exclude events likely to be compound using neighbor-based flags
- summarize only isolated events
- inspect shape on the baseline-relative event signal rather than the raw
  envelope

This is still provisional.

## 6. Current Outputs

### 6.1 Folder-level analysis function

Current entry point:

- [analyzePrimitiveEvents.m](/Users/yoe/Documents/REPOS/eMove-playground/CODE/ACCELEROMETER/analyzePrimitiveEvents.m)

Typical call:

```matlab
analysisOutput = analyzePrimitiveEvents( ...
    '/Users/yoe/Dropbox/WORK/Data/Waseda-ACC/MAGNITUDES', ...
    'OutputFolder', '/Users/yoe/Documents/REPOS/eMove-playground/scratch/waseda_event_summary_20260506/function_outputs');
```

Returned structure includes:

- `perFile`
- `allEventTable`
- `fileSummaryTable`
- `conditionSummaryTable`
- `subjectSummaryTable`
- `meanWaveformTable`
- `figureHandles`

### 6.2 Latest saved outputs

Current scratch output folder:

- `/Users/yoe/Documents/REPOS/eMove-playground/scratch/waseda_event_summary_20260506/function_outputs`

Key figures:

- [primitive_event_summary_cdfs_by_condition.png](/Users/yoe/Documents/REPOS/eMove-playground/scratch/waseda_event_summary_20260506/function_outputs/primitive_event_summary_cdfs_by_condition.png)
- [primitive_event_summary_cdfs_by_subject.png](/Users/yoe/Documents/REPOS/eMove-playground/scratch/waseda_event_summary_20260506/function_outputs/primitive_event_summary_cdfs_by_subject.png)
- [primitive_event_summary_file_mean_waveforms.png](/Users/yoe/Documents/REPOS/eMove-playground/scratch/waseda_event_summary_20260506/function_outputs/primitive_event_summary_file_mean_waveforms.png)
- [primitive_event_summary_grouped_mean_waveforms.png](/Users/yoe/Documents/REPOS/eMove-playground/scratch/waseda_event_summary_20260506/function_outputs/primitive_event_summary_grouped_mean_waveforms.png)
- [primitive_event_summary_amplitude_width_scatter.png](/Users/yoe/Documents/REPOS/eMove-playground/scratch/waseda_event_summary_20260506/function_outputs/primitive_event_summary_amplitude_width_scatter.png)

Current exported compiled MATLAB output:

- [analysisOutput_current.mat](/Users/yoe/Documents/REPOS/eMove-playground/scratch/waseda_event_summary_20260506/function_outputs/analysisOutput_current.mat)

Current exported tables:

- [all_event_metrics_current.csv](/Users/yoe/Documents/REPOS/eMove-playground/scratch/waseda_event_summary_20260506/function_outputs/all_event_metrics_current.csv)
- [file_summary_current.csv](/Users/yoe/Documents/REPOS/eMove-playground/scratch/waseda_event_summary_20260506/function_outputs/file_summary_current.csv)
- [condition_summary_current.csv](/Users/yoe/Documents/REPOS/eMove-playground/scratch/waseda_event_summary_20260506/function_outputs/condition_summary_current.csv)
- [subject_summary_current.csv](/Users/yoe/Documents/REPOS/eMove-playground/scratch/waseda_event_summary_20260506/function_outputs/subject_summary_current.csv)

Note:

- `analysisOutput_current.mat` is large, about `57 MB`, because it contains
  the compiled MATLAB output structure with waveform data and figure handles

## 7. Current Quantitative Results

These results are from the current isolated-event configuration, not the
earlier all-event runs.

### 7.1 Condition-level summary

From [condition_summary_current.csv](/Users/yoe/Documents/REPOS/eMove-playground/scratch/waseda_event_summary_20260506/function_outputs/condition_summary_current.csv):

- `desk_work_stand`
  - `nEvents = 356`
  - `medianAmplitude = 0.0168`
  - `medianDetectorWidthSec = 1.2907`
  - `medianInterEventIntervalSec = 12.48`
- `watching_videos_stand`
  - `nEvents = 230`
  - `medianAmplitude = 0.0215`
  - `medianDetectorWidthSec = 1.3606`
  - `medianInterEventIntervalSec = 19.136`

Current descriptive read:

- video events are fewer
- video events are larger in amplitude
- video events are slightly wider by the detector width metric
- video events are more widely spaced

### 7.2 Subject-level summary

From [subject_summary_current.csv](/Users/yoe/Documents/REPOS/eMove-playground/scratch/waseda_event_summary_20260506/function_outputs/subject_summary_current.csv):

- `sub1`
  - `nEvents = 246`
  - `medianAmplitude = 0.0233`
  - `medianDetectorWidthSec = 1.3462`
  - `medianInterEventIntervalSec = 13.04`
- `sub2`
  - `nEvents = 208`
  - `medianAmplitude = 0.0177`
  - `medianDetectorWidthSec = 1.3151`
  - `medianInterEventIntervalSec = 12.528`
- `sub3`
  - `nEvents = 51`
  - `medianAmplitude = 0.0106`
  - `medianDetectorWidthSec = 1.2710`
  - `medianInterEventIntervalSec = 44.48`
- `sub4`
  - `nEvents = 81`
  - `medianAmplitude = 0.0120`
  - `medianDetectorWidthSec = 1.4606`
  - `medianInterEventIntervalSec = 22.016`

Current descriptive read:

- subject differences remain strong
- `sub1` and `sub2` still contribute most events
- `sub3` remains especially sparse and slow
- `sub4` remains intermediate but with relatively broad detector widths

### 7.3 File-level summary

From [file_summary_current.csv](/Users/yoe/Documents/REPOS/eMove-playground/scratch/waseda_event_summary_20260506/function_outputs/file_summary_current.csv):

- `sub1 desk`
  - `128` isolated events
  - median amplitude `0.0207`
  - median detector width `1.3369 s`
  - median inter-event interval `10.208 s`
- `sub1 video`
  - `118` isolated events
  - median amplitude `0.0260`
  - median detector width `1.3466 s`
  - median inter-event interval `15.04 s`
- `sub2 desk`
  - `107` isolated events
  - median amplitude `0.0196`
  - median detector width `1.2163 s`
  - median inter-event interval `9.296 s`
- `sub2 video`
  - `101` isolated events
  - median amplitude `0.0171`
  - median detector width `1.4746 s`
  - median inter-event interval `23.28 s`
- `sub3 desk`
  - `50` isolated events
  - median amplitude `0.0106`
  - median detector width `1.2733 s`
  - median inter-event interval `44.48 s`
- `sub3 video`
  - `1` isolated event
  - no meaningful interval summary
- `sub4 desk`
  - `71` isolated events
  - median amplitude `0.0120`
  - median detector width `1.4606 s`
  - median inter-event interval `17.088 s`
- `sub4 video`
  - `10` isolated events
  - median amplitude `0.0106`
  - median detector width `1.3535 s`
  - median inter-event interval `109.856 s`

Current descriptive read:

- the largest condition contrast is not a uniform amplitude effect
- the clearer consistent effect is that video tends to become sparser,
  especially for `sub3` and `sub4`
- `sub1` is the clearest case where video events are more numerous enough to
  remain analyzable and also larger in amplitude
- `sub2` shows a different pattern, with video events becoming wider and much
  more separated rather than larger

## 8. Important Assumptions And Caveats

These are essential for any replication attempt.

### 8.1 This is not a validated primitive-event detector

The workflow is still exploratory.

It is best thought of as:

- one operational definition of isolated event-like perturbations in the
  envelope
- with one particular thresholding, merging, and boundary logic

### 8.2 Detection and shape analysis are coupled

Changing any of these can substantially change the event sample:

- `ThresholdSigma`
- `valleyFraction`
- compound-event exclusion windows
- pre-peak lookback window
- post-peak lookahead window

### 8.3 Isolated-event filtering is detector-dependent

Compound-event exclusion depends on the detected peaks.

If a small neighboring fluctuation is not detected as a peak, a compound event
can still survive the isolation filter.

### 8.4 Scalar summaries and shape summaries are not identical objects

Scalar summaries use:

- detector amplitudes
- detector widths
- inter-event intervals between detected peaks

Shape summaries use:

- extracted baseline-relative `eventSignal` waveforms
- aligned by peak

So the scalar metrics and the shape plots are related but not identical views
of the same object.

### 8.5 Processing should stay index-based

The current code has been checked so that event-decision logic operates in
sample-index space.

Seconds are used only to:

- convert user-facing windows into sample counts
- report widths and times
- label plots

Another agent should preserve that principle.

## 9. Recommended Replication Plan For Another Dataset

If another agent is asked to reproduce this on a new dataset, the safe order is:

1. Build or verify the equivalent magnitude/envelope input.
2. Confirm the sample rate used for the new dataset.
3. Run `analyzePrimitiveEvents` with the same current defaults.
4. Inspect:
   - event counts per file
   - isolated vs compound counts
   - grouped mean waveform panels
   - amplitude vs width scatter
5. Only after that, consider changing:
   - `ThresholdSigma`
   - `valleyFraction`
   - isolation windows
   - boundary windows

Recommended first comparison questions on a new dataset:

- does one subject or condition dominate the event count?
- do grouped peak-normalized means show a shared rise/decay motif?
- are detector widths and amplitudes positively related?
- does video-like context make events sparser, larger, or both?

## 10. What Another Agent Should Not Assume

Another agent should not assume that:

- the current isolated events are necessarily the true primitive class
- the detector width is the best width metric
- amplitude and width effects generalize beyond this dataset
- subject-level differences are nuisance only

Those are open questions.

## 11. Minimal Practical Commands

To rerun the current analysis in MATLAB:

```matlab
analysisOutput = analyzePrimitiveEvents( ...
    '/Users/yoe/Dropbox/WORK/Data/Waseda-ACC/MAGNITUDES', ...
    'OutputFolder', '/Users/yoe/Documents/REPOS/eMove-playground/scratch/waseda_event_summary_20260506/function_outputs');
```

To inspect all event metrics in MATLAB afterward:

```matlab
T = analysisOutput.allEventTable;
Tisolated = T(T.isIsolatedEvent, :);
```

To compare conditions quickly:

```matlab
desk = Tisolated(Tisolated.condition == "desk_work_stand", :);
video = Tisolated(Tisolated.condition == "watching_videos_stand", :);
```

To compare subjects quickly:

```matlab
sub1 = Tisolated(Tisolated.subjectID == "sub1", :);
sub2 = Tisolated(Tisolated.subjectID == "sub2", :);
sub3 = Tisolated(Tisolated.subjectID == "sub3", :);
sub4 = Tisolated(Tisolated.subjectID == "sub4", :);
```

## 12. Bottom Line

Current best working interpretation:

- there are event-like perturbations in the chest-envelope signal that can be
  detected across files
- after isolated-event filtering, the event sample becomes sparser and more
  plausible as a primitive-class candidate
- amplitude, spacing, and width still differ by subject and condition
- the current workflow is now suitable for replication-style transfer to
  another dataset, provided the same caveats are carried forward

This is the right stage for another agent to try the same logic elsewhere and
test whether the apparent primitive event structure survives transfer.
