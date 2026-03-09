# Methods (Draft)

Version: 0.1 (working draft)  
Date: 2026-03-08

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
- hardwired excluded IDs for this dataset: `JANNE`, `AS2302`, `XC1301`

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

## 6) Configuration Tables

### 6.1 Stimulus Coding Table

Current working file:
- `resources/stim_video_encoding_SINGLES.csv`

Snapshot:
- canonical rows: `16` (1 baseline + 15 post-baseline stimulus IDs)
- currently included rows in checked-in table: `17` (requires reconciliation to canonical 16)
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

---

This document is intentionally incomplete and should be expanded into manuscript-ready Methods text after:
- unresolved stimulus labels are finalized,
- self-report trial-to-video mapping is finalized,
- final participant inclusion list is frozen.
