# Auxiliary Modality Integration Notes

Date: 2026-03-20

## Purpose

This note records the practical decisions from the quick auxiliary-modality
visualization pass so the next MATLAB-focused work can resume from a concrete
starting point.

Scope covered here:
- eye tracking from Unity stimulus logs,
- ECG / HR from Movesense,
- EDA from Shimmer,
- time alignment assumptions used for a worked example session.

This is an integration memo, not a finalized analysis specification.

## Worked Example Session

Example files used during the visualization pass:
- Unity eye/stimulus log:
  - `RAWDATA/UNITYLOGS/PNr_xb0202_2025-08-15-14-34 x_0302.csv`
- ECG:
  - `RAWDATA/HR/MovesenseECG-2025-08-15T10_36_37.485695Z.csv`
- EDA:
  - `RAWDATA/EDA/DefaultTrial_Session22_Shimmer_40C9_Calibrated_PC.csv`

Selected stimulus window used for examples:
- video ID: `x_0302`
- Unity start: `2025-08-15 14:34:55`
- Unity end: `2025-08-15 14:35:25`
- duration: `30 s`

## Session Structure Reminder

Canonical session schedule in current Unity logs:
- one `BASELINE` segment,
- followed by `15` post-baseline stimulus videos,
- each post-baseline stimulus lasts `30 s`.

For the inspected session:
- `BASELINE`: `2025-08-15 13:47:27` to `13:50:27`
- last post-baseline example used here:
  - `x_0302`: `2025-08-15 14:34:55` to `14:35:25`

## Modality-Specific Notes

### 1) Eye Tracking

Current practical interpretation:
- the Unity stimulus logs are already the canonical trial timing source,
- eye variables can therefore be attached directly per stimulus log,
- no extra cross-device synchronization step is required if the data are used
  stimulus-wise from the Unity CSVs themselves.

Useful quick-look fields from the raw Unity logs:
- gaze position / viewing angles,
- gaze speed,
- pupil diameter.

Immediate MATLAB implication:
- eye data should be stored stimulus-wise inside the same per-trial structure
  that already uses Unity timing for mocap segmentation.

### 2) EDA

Current practical interpretation:
- the Shimmer CSV timestamps are local timestamps,
- for the worked example they can be aligned directly to the Unity clock,
- this modality is therefore the simpler physiology source for first-pass
  multimodal integration.

Worked-example alignment anchor:
- EDA file first timestamp:
  - `2025/08/15 13:36:30.109`
- selected `x_0302` onset relative to EDA file start:
  - about `3504.891 s`

Immediate MATLAB implication:
- support extracting:
  - full-session raw conductance,
  - tonic component,
  - phasic component,
  - stimulus-centered windows with configurable pre/post padding.

Current exploratory summary features that looked useful in the quick pass:
- tonic EDA slope over the Unity-defined `0–30 s` stimulus interval,
- phasic spike count within the same `0–30 s` stimulus interval.

Practical interpretation at this stage:
- tonic slope can serve as a compact per-trial descriptor of slow conductance
  increase or decrease during a stimulus,
- phasic spike count can serve as a compact per-trial descriptor of short-lived
  phasic response frequency during a stimulus,
- both should currently be treated as descriptive QC / exploratory features,
  not finalized physiological endpoints.

### 3) ECG / HR

Current practical interpretation:
- Movesense file timing is less direct than EDA in the current raw format,
- the file name/header provides a UTC timestamp,
- for the worked example the ECG file was aligned by converting that UTC start
  time to local session time.
- the raw CSV later proved timing-ambiguous because it contains:
  - an ambiguous `# created ...` timestamp,
  - elapsed time from `0.000 s`,
  - but no absolute timestamp per sample,
  - no trigger/event markers,
  - and no explicit field proving that `created` equals true acquisition onset.
- therefore, even when Unity and ECG were recorded on the same PC, the CSV
  alone does not prove zero-offset synchronization to the Unity clock.

Worked-example alignment anchor:
- ECG file header timestamp:
  - `2025-08-15T10:36:37.485695Z`
- local session-time assumption used in the quick-look:
  - UTC + `3 h`
- inferred local ECG start:
  - `2025-08-15 13:36:37.485695`
- selected `x_0302` onset relative to ECG file start:
  - about `3497.514 s`

Important caution:
- this ECG alignment should currently be treated as an explicit inference,
  not a proven hardware-level synchronization result.
- later diagnostic checking suggested that a fixed second-scale offset remains
  plausible even when the hour-level `UTC + 3 h` conversion is correct.
- current best explanation is that the CSV `created` field may correspond to
  file/session creation time rather than guaranteed first-sample acquisition
  time.

Immediate MATLAB implication:
- ECG integration should preserve the alignment provenance flag
  (`direct timestamp` vs `inferred from UTC header`) so downstream analyses
  can separate higher-confidence vs inferred timing cases if needed.
- the MATLAB pipeline should also preserve any future evidence about ECG start
  semantics separately from the derived trial timing, so re-alignment remains
  possible if better metadata become available.

## Existing MATLAB Entry Points Already Relevant

Current parser / aggregation functions already noted in the repo:
- `loadUnityEyeLogCSV`
- `loadShimmerEDACSV`
- `loadMovesenseECGCSV`
- `loadModalitySignalsFromInventory`

Current design implication:
- the next step is not to invent a new modality system,
- it is to carry these parsed signals consistently into the subject-level
  MATLAB outputs used by motion analysis.

## Recommended Next MATLAB Integration Steps

### 1) Add stimulus-centered auxiliary windows into subject MAT outputs

Target outcome:
- each trial should be able to carry:
  - mocap segment,
  - Unity / eye segment,
  - EDA segment,
  - ECG / HR segment,
  with shared trial metadata.

Suggested fields:
- `trialData.trials(i).videoID`
- `trialData.trials(i).tStart`
- `trialData.trials(i).tEnd`
- `trialData.trials(i).eye`
- `trialData.trials(i).eda`
- `trialData.trials(i).ecg`

### 2) Standardize configurable padding

Recommended default for future QC plots:
- pre-stimulus padding: `10 s`
- post-stimulus padding:
  - `10 s` for compact modality QC,
  - optionally `60 s` for slower EDA recovery views.

Recommended summary window conventions:
- tonic slope summary:
  - compute on the Unity-defined stimulus interval only (`0–30 s`),
- phasic spike count summary:
  - count detected phasic peaks on the same Unity-defined stimulus interval
    (`0–30 s`),
- use padding for visualization / context, but keep the summary metrics tied to
  the canonical stimulus window unless a different analysis window is
  explicitly justified.

### 3) Keep one canonical trial clock

Recommended rule:
- continue to treat Unity schedule as the canonical trial-definition clock,
- then express auxiliary modalities relative to Unity onset/offset.

### 4) Store provenance and alignment confidence

Recommended per-modality metadata:
- raw source file,
- parser version / date,
- alignment method,
- timing confidence flag,
- sample rate,
- any load/parsing warnings.

### 5) Add simple multimodal QC figures in MATLAB

Before inferential analysis, add collaborator-facing QC that can show:
- mocap speed,
- gaze speed / pupil,
- EDA tonic + phasic,
- ECG waveform + HR trend,
- all centered on the same Unity-defined trial window.

Recommended EDA QC additions:
- full-session tonic conductance with colored Unity stimulus markers,
- full-session phasic trace with the same marker scheme,
- stimulus-aligned EDA trend panel for quick across-stimulus comparison,
- per-stimulus side summary reporting:
  - tonic slope (`µS/s`) over `0–30 s`,
  - phasic spike count over `0–30 s`.

## Interpretation Boundary

The quick figures built on 2026-03-20 were for communication and integration
planning only.

They should not be treated as:
- finalized physiological preprocessing,
- clinical ECG analysis,
- finalized EDA decomposition,
- validated cross-device synchronization,
- or validated SCR event detection / scoring.

## Operational Summary

Most defensible next move:
- keep Unity timing as the session/trial anchor,
- integrate eye directly from stimulus logs,
- integrate EDA next because timestamp alignment is most direct,
- integrate ECG with explicit timing provenance because current alignment is
  more inferential.
