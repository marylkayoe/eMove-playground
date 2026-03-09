# Development Log

This document tracks project state, implementation decisions, and validation runs.

## 2026-03-10

### Current State Summary
- Repository focus remains MoCap-first ingestion and analysis, with optional modality loading for `unity`, `eda`, and `hr`.
- Canonical session structure is now documented as:
  - `16` total segments per session
  - `1` `BASELINE`
  - `15` post-baseline stimulus segments
- Self-report storage policy is documented:
  - raw `Self-report-body.csv` stays in raw-data storage
  - parsed/derived self-report artifacts stay outside this repository

### Documentation Updates (latest pass)
- Updated canonical session wording in:
  - `README.md`
  - `REQUIREMENTS.md`
  - `docs/METHODS.md`
  - `ARCHITECTURE_BODYPART_SELFREPORT.md`
- Added explicit raw-vs-derived self-report storage policy in core docs.

### Data/Config Status
- `resources/stim_video_encoding_SINGLES.csv` now has:
  - 1 header row
  - 16 data rows (baseline + 15 stimuli)

### Build And Test Runs

#### 1) Manifest-based rebuild with modalities enabled
- Command type: MATLAB batch run of `buildSubjectTrialDataBatchFromManifest(...)`
- Settings:
  - `loadModalitySignals=true`
  - `modalitiesToLoad={'unity','eda','hr'}`
  - `continueOnError=true`
- Result:
  - `28/28` subjects built with status `ok`
  - Output CSV:  
    `/Users/yoe/Documents/DATA/HUMANMOCAP_by_subject/trialdata_build_results_manifest_with_modalities.csv`
- Notable warnings:
  - `AU1001`, `SC3001`, `XY1700` had multiple mocap rows in manifest; latest timestamp row was selected (expected behavior).

#### 2) Spot-check of rebuilt MAT content
- Verified `trialData.metaData.modalitySignalsLoaded == 1` on rebuilt subject MAT.
- Verified `trialData.modalityData` contains:
  - `unity`
  - `eda`
  - `hr`

#### 3) Smoke test run
- Script: `scripts/run_testing_smoke.m`
- Result summary:
  - Stim encoding: `Rows total=16 | included=16`
  - Missing coding IDs: `0` subjects
  - Missing grouped markers: `0` subjects
  - Modality load errors: `0` subjects
  - Smoke test completed successfully

### Known Caveats (still open)
- `parseViconCSV.m` currently assumes an `Unlabeled` column exists in Vicon headers.
- `getMarkerTrajectory.m` currently:
  - defaults to clipping first 5 seconds (`CLIPSEC=5`)
  - overwrites passed `mocapMetaData` with `trialData.metaData`
- These are known behavior risks and should be addressed deliberately before broad automation.

### Update Procedure (after each build/test cycle)
1. Add a new dated section at top (`## YYYY-MM-DD`).
2. Record data/config changes:
   - canonical assumptions changed (yes/no)
   - modified config tables (file names + row/count changes)
3. Record build command and scope:
   - script/function used
   - key parameters (for example modalities loaded, include/exclude sets)
4. Record outcomes with counts:
   - subjects attempted / succeeded / failed
   - warnings that changed behavior (for example fallback row selection)
5. Record validation runs:
   - smoke/QC scripts executed
   - key result counts and any failing IDs
6. Record open caveats and whether each is:
   - unchanged
   - mitigated
   - resolved (with file reference)
