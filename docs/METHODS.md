# Methods (Draft)

Version: 0.3 (working draft)  
Date: 2026-03-20

## 1) Study Aim

Primary aim:
determine whether emotional state can be characterized from human motion in a low-animation (micromotion) regime.

Current extension aim:
integrate auxiliary modalities (eye tracking from Unity logs, EDA from Shimmer, HR/ECG from Movesense) to support motion-based findings.

## 2) Experimental Design

Each participant completes one recording session.

Session structure:
- one continuous Vicon mocap recording,
- one explicit `BASELINE` segment,
- followed by 15 post-baseline stimulus presentations (30 s each),
- with randomized stimulus order across participants.

Notes:
- demo/practice segments may exist before baseline and are excluded from main trial mapping.
- current analysis scope focuses on `BASELINE` and post-baseline stimulus segments (not inter-report intervals).

## 3) Participant And Dataset Snapshot

As of 2026-03-08 (current prescreen snapshot):
- master manifest rows: `549`
- manifest modality counts:
  - `mocap`: `32`
  - `unity`: `449`
  - `hr`: `30`
  - `eda`: `38`
- unique mocap-assigned subjects: `28`
- subject exclusions are now loaded from:
  `resources/project/subject_exclusions.csv`
- current default exclusions in that file: `AB1502`, `JANNE`, `AS2302`, `XC1301`
- `runMotionMetricsBatch(...)` and `runMotionMetricsBatchFromManifest(...)`
  apply this exclusion list by default (can be overridden by parameters).
- default marker grouping is now legacy-style 9 groups:
  `UTORSO`, `HEAD`, `UPPER_LIMB_L`, `UPPER_LIMB_R`,
  `LOWER_LIMB_L`, `LOWER_LIMB_R`, `WRIST_L`, `WRIST_R`, `LTORSO`
  (with `OTHER`, `HAND_L`, `HAND_R` excluded in default grouping CSV).

Built MAT outputs:
- subject folders under `matlab_from_manifest`: `28`
- MAT files currently present: `31`
- three subjects have historical duplicate MATs from earlier runs:
  - `AU1001`, `SC3001`, `XY1700`
- smoke test policy now uses latest MAT per subject by default.

## 4) Data Sources And Modalities

Raw sources:
- Vicon CSV (mocap trajectories),
- Unity log CSV (stimulus-wise eye and headset data),
- Shimmer CSV (EDA),
- Movesense CSV (ECG/HR-related waveform source),
- self-report body map CSV (separate integration track).

Storage policy:
- Keep raw files immutable in raw-data storage (for example `.../HUMANMOCAP/Self-report-body.csv`).
- Write parsed/derived artifacts (for example `selfReportCompact.mat`) to processed-data storage outside this repository (for example `.../HUMANMOCAP_by_subject/derived/selfreport/`).

Parsed modality support in current pipeline:
- `loadUnityEyeLogCSV`
- `loadShimmerEDACSV`
- `loadMovesenseECGCSV`
- aggregated by `loadModalitySignalsFromInventory`

## 5) Trial Definition And Time Alignment

Trial segmentation anchor:
- Unity log schedule is the canonical source for stimulus window timing.

Current rules:
- if multiple baseline/demo logs exist, use the **last** `BASELINE` as anchor,
- ignore Unity logs before that anchor,
- if post-baseline video IDs repeat, keep first chronological occurrence for mapping,
- map segmented windows onto continuous mocap using metadata timing.

### 5.1 Auxiliary Modality Alignment Note (2026-03-20 working state)

Current practical alignment rule set:
- eye tracking should be attached directly from the Unity stimulus logs,
- EDA can currently be aligned most directly because the Shimmer CSV carries local timestamps,
- ECG / HR currently requires an explicit alignment-provenance note because example-session alignment was inferred from the Movesense UTC header timestamp.

Worked-example memo and concrete file/timing details:
- `docs/AUX_MODALITY_INTEGRATION_2026-03-20.md`

Operational recommendation for the next MATLAB integration phase:
- continue to treat Unity timing as the canonical trial-definition clock,
- express EDA / ECG / eye windows relative to Unity onset and offset,
- carry a per-modality timing-confidence / alignment-method field into subject MAT outputs.

## 6) Configuration Tables

### 6.1 Stimulus Coding Table

Current working file:
- `resources/stim_video_encoding_SINGLES.csv`

Snapshot:
- canonical rows: `16` (1 baseline + 15 post-baseline stimulus IDs)
- currently included rows in checked-in table: `16`
- unresolved tags (`X` or empty): `11` (to be finalized)

Minimum columns used in current workflows:
- `videoID`
- `emotionTag`
- `include`

### 6.2 Bodypart Grouping Table

Current working file:
- `resources/bodypart_marker_grouping.csv`

Snapshot:
- marker rows: `101`
- included markers: `62`
- included groups: `12`
- grouped marker coverage against current subject MATs: no missing grouped markers in smoke test.

## 7) Quality Control And Smoke Testing

Non-computational smoke test script:
- `scripts/run_testing_smoke.m`

Checks:
- input file presence,
- coding-table integrity (duplicates, baseline presence),
- bodypart-grouping integrity,
- per-subject MAT consistency (video IDs and markers),
- modality parser error flags in stored `trialData`.

Latest smoke test outcome (reported 2026-03-08):
- missing coding IDs: `0` subjects
- missing grouped markers: `0` subjects
- modality load errors: `0` subjects

## 8) Current Analysis Scope (Operational)

This code state supports:
- manifest-based ingestion without copying raw files,
- subject-level MAT assembly with optional modality parsing,
- baseline/stimulus trial scheduling from Unity timing,
- configurable stimulus coding and bodypart grouping,
- readiness checks prior to metric/statistical analysis.

## 9) Planned Analysis (Next Phases)

Planned, configurable analysis layers:
- motion-only analyses by stimulus and bodypart,
- motion + eye modality analyses,
- subset analyses including EDA and HR where available,
- optional integration with self-report body maps after mapping/QC is finalized.

Important governance rule:
changes to core computed metrics/statistical algorithms require explicit owner approval before implementation.

## 10) Reproducibility Notes

Recommended provenance with each analysis run:
- git commit hash,
- branch,
- run timestamp,
- data snapshot path(s),
- config table versions (`stim_video_encoding_*.csv`, `bodypart_marker_grouping.csv`).

Runtime note for distance analyses:
- `computeStimDistanceWasserstein` can become impractically slow on full pooled sample arrays.
- For reproducible full-batch runs, apply a fixed cap with
  `maxSamplesPerDist` (current operational setting: `5000` in `scripts/run_full_analysis_manifest_once.m`).
- Record the cap value in run metadata/report, because it changes runtime and can slightly affect distance estimates.

CDF reporting convention (current plotting scripts):
- Export both absolute-value and baseline-normalized variants for the same metric.
- Current CDF script (`scripts/run_cdf_only_manifest.m`) exports:
  - `perVideoMedian` (row-level medians),
  - `pooledRaw` (all pooled speed samples),
  each in both:
  - absolute units (no baseline normalization),
  - fold-baseline units (per-subject baseline normalization).

KS immobility reporting convention:
- KS values are computed from raw per-sample arrays (`speedArrayImmobile`), not from medians.
- Displayed heatmap values are aggregated across subjects (default aggregation in `plotKsHeatmap`: median).
- `minSamplesPerCond` in `computeKsDistancesFromResultsCell` is a per-subject gate:
  - for each subject + markerGroup + emotion pair, both conditions must meet the sample minimum.
  - default in code is `200`.
- Project operational decision (2026-03-11):
  - use `minSamplesPerCond=200` consistently for KS reporting unless explicitly noted otherwise.
- Increasing `minSamplesPerCond` (for example to `5000`) can remove markerGroups/pairs that were present at `200` (notably wrist groups in this dataset).

Cross-code reproducibility note (legacy folder vs playground):
- Controlled A/B comparison showed metric parity when:
  - identical subject set is enforced, and
  - exclusion policy is matched (`applySubjectExclusions` setting aligned).
- Observed KS discrepancies during debugging were attributable to subject inclusion mismatch, not a mathematical drift in KS computation.

Stick-figure plotting notes (2026-03-11):
- Poster KS stick-figure code now normalizes marker-group names so current schema
  (`UTORSO`, `UPPER_LIMB_L`, `WRIST_L`, etc.) maps correctly to the body diagram.
- `maxPairs` is now honored in all-pairs wrapper flow.
- Current KS immobility script defaults:
  - threshold: `<=35 mm/s`,
  - `minSamplesPerCond=200`,
  - optional exclusion of `FEAR` from pair display for contrast-focused visualization.

SAL/MAD immobility availability (current gap):
- Speed has explicit immobility-window arrays (`speedArrayImmobile`), and KS/CDF pathways can target that field.
- SAL and MAD are currently exposed as full-window summary metrics in the main results tables; there is no equivalent immobility-window SAL/MAD field path in current reporting scripts.
- Planned extension should add read-paths/fields for SAL/MAD restricted to immobility windows before new inferential use.

## 11) Regime-Comparison And Reversal QC Notes

During 2026-03-14 to 2026-03-15, an exploratory figure/analysis pass was run to
test whether the low-animation regime behaves as a simple lower-amplitude
version of overt motion or shows selective reorganization.

This work should currently be treated as **exploratory QC / figure development**,
not as a finalized inferential pipeline.

### 11.1 Pooled Contrast Plots

Exploratory pooled plots were generated by comparing pairwise emotion contrasts
between:
- full-motion samples
- micromovement samples (thresholded speed regime)

Important caveat:
- pooled raw contrasts weight subjects by the number of usable samples they
  contribute.
- Therefore pooled raw plots answer a group-level sample-weighted question and
  should not be interpreted as equivalent to subject-median or subject-level
  analyses.

### 11.2 Subject-Level Reversal Interpretation

For a given emotion pair and bodypart, a "reversal" means:
- the pairwise contrast changes sign between full-motion and micromovement
  regimes.

Crucial implementation note:
- pair order and subtraction direction must be held fixed.
- Reversing the label order (for example `DISGUST-JOY` vs `JOY-DISGUST`) while
  also plotting signed contrasts changes the apparent quadrant/location of the
  same biological relationship.

Operational rule adopted after debugging:
- all contrast-based figures should state or imply one fixed subtraction
  convention per figure family,
- and comparisons from different conventions should not be mixed in the same
  visual summary.

### 11.3 Subject-Aware Stability Checks

Three subject-aware QC strategies were used to evaluate whether pooled reversal
patterns were likely to be meaningful:

1. subject-level reversal fractions
   - count the proportion of subjects showing a sign flip for a given
     bodypart/pair cell

2. subject-bootstrap stability of pooled reversals
   - resample subjects with replacement
   - recompute aggregate bodypart/pair reversals
   - estimate the probability that the pooled reversal remains in the same
     reversal quadrant

3. subject-cell inclusion sensitivity
   - reference: include all comparable cells
   - dead-zone filter: exclude near-zero subject contrasts
   - bootstrap-CI filter: include cells only if a regime contrast CI excludes
     zero

Current read from these checks:
- the pooled reversal picture is not pure noise,
- but the broad "many reversals everywhere" reading is too strong,
- the clearest surviving pattern is disgust-centered, especially torso-weighted.

### 11.4 What Was Rejected For Presentation Use

The following visualization idea was explored and then set aside:

- signed KS stick figures where color attempted to encode both:
  - discriminability magnitude
  - and direction of the median contrast

Reason for rejection:
- the figure became too easy to misread,
- especially when per-tile scaling and sign both varied,
- and it was less trustworthy at a glance than the older unsigned KS style.

Current presentation preference:
- use unsigned KS/bodypart magnitude figures for "where in the body" questions,
- and use separate scatter/density figures for directional contrast examples.

---

This document is intentionally incomplete and should be expanded into manuscript-ready Methods text after:
- unresolved stimulus labels are finalized,
- self-report trial-to-video mapping is finalized,
- final participant inclusion list is frozen.
