# Development Log

This document tracks project state, implementation decisions, and validation runs.

## 2026-03-14

### Presentation-Oriented Interactive Tooling
- Refined the micromovement example browser for collaborator-facing exploration:
  - `CODE/PLOTTING/poster/gui/launchMicromovementExampleBrowser.m`
  - `CODE/PLOTTING/poster/plotPosterMarkerTimeSeries.m`
  - `CODE/PLOTTING/poster/extractMarkerTrajectoryForVideo.m`
  - `CODE/APPS/launchMicromovementExplorerApp.m`
- Current browser capabilities:
  - subject/video/bodypart browsing from manifest-built MAT files,
  - multi-bodypart selection via checkboxes,
  - preserved video/bodypart/dimension/numeric settings when switching subjects,
  - pre/post context around the selected stimulus segment,
  - integrated right-side stick-figure overview,
  - legend moved outside the main axes to keep traces readable.

### Micromovement Browser UI Fixes
- Control-panel layout was reorganized to remove overlapping controls and improve scanning.
- Numeric edit controls (`pre`, `post`, threshold, smoothing) now keep their typed values until `Plot / Refresh`.
- Refresh path was hardened by caching numeric fields and reusing them at plot time.
- Subject switching now preserves:
  - selected video ID (when available),
  - selected bodyparts,
  - dimension,
  - pre/post values,
  - threshold and smoothing,
  - display-mode checkboxes.

### New Group-Level CDF Comparison Browser
- Added:
  - `CODE/PLOTTING/gui/launchCdfComparisonBrowser.m`
  - `scripts/launch_cdf_comparison_browser.m`
- Current capabilities:
  - one or more bodypart groups selected by checkboxes,
  - two or more emotions overlaid in one CDF figure,
  - plotting modes:
    - `perVideoMedian`
    - `pooledRaw`
    - `perSubjectRaw`
  - full-speed vs micromovement regime,
  - baseline-normalized vs absolute display,
  - optional stats overlay.
- Behavior note:
  - pairwise stats annotation is only forwarded when exactly two emotions are selected;
    for larger emotion sets, the overall KW annotation remains the main summary.

### Presentation Figure Export Helper
- Added:
  - `scripts/make_disgust_neutral_panels.m`
- Purpose:
  - generate focused Panel C / Panel D candidate figures for `DISGUST` vs `NEUTRAL`
    from the latest manifest-derived `resultsCell.mat`.
- First run output:
  - `/Users/yoe/Documents/REPOS/eMove-playground/outputs/figures/disgust_neutral_panels_20260314_164839`

### Validation Runs
- Micromovement browser smoke tests:
  - browser launches successfully on latest manifest MAT corpus,
  - control values persist through refresh after numeric-field fix,
  - subject switching preserves browsing context.
- CDF comparison browser smoke tests:
  - loaded `5` emotions and `9` bodypart groups from current data/config,
  - initial plot opens successfully,
  - plot also opens successfully when `3` emotions are selected together.

## 2026-03-11

### Cross-Repository Reproducibility QC (external CODE vs playground CODE)
- Added controlled A/B scripts:
  - `scripts/run_external_vs_playground_ab_qc.m`
  - `scripts/compare_external_playground_same_subjects.m`
- Key outcome:
  - with identical subject sets and matched exclusion policy, KS results are identical across code trees (`maxAbsDeltaD=0`).
  - prior observed differences were explained by subject inclusion mismatch (playground default exclusions enabled vs legacy flow).

### Subject Inclusion Governance
- Confirmed active exclusion source:
  - `resources/project/subject_exclusions.csv`
- Current default analysis runs therefore use 27 subjects (28 mocap-assigned minus excluded IDs) unless explicitly overridden.
- Added explicit parity guidance in docs/scripts:
  - use `'applySubjectExclusions', false` for strict legacy reproduction checks.

### KS And Stick-Figure Usability Fixes
- Fixed marker-group name compatibility in:
  - `CODE/PLOTTING/poster/ks/plotKsBodyPartStickFigure.m`
  - added normalization from legacy/current label variants to canonical groups.
- Fixed wrapper behavior in:
  - `CODE/PLOTTING/poster/ks/plotKsBodyPartStickFigureAllPairs.m`
  - `maxPairs` now works as intended.
- Extended panel forwarding in:
  - `CODE/PLOTTING/poster/ks/plotKsBodyPartStickFigurePanel.m`
  - now supports `showGroupLabels` pass-through.
- Current visualization defaults in `scripts/run_ks_immobility_only.m`:
  - `minSamplesPerCond=200`,
  - immobility threshold `<=35 mm/s`,
  - optional `FEAR` exclusion from displayed pairs,
  - style tuned for cleaner body-part-only labels.

### Manifest Run Outputs (today)
- Full manifest pipeline run:
  - `/Users/yoe/Documents/DATA/HUMANMOCAP_by_subject/derived/analysis_runs/20260311_200947`
  - mirrored figures:
    `/Users/yoe/Documents/REPOS/eMove-playground/outputs/figures/20260311_200947`
- CDF-only export from latest manifest run:
  - `/Users/yoe/Documents/REPOS/eMove-playground/outputs/figures/cdf_only_20260311_201604`
- KS immobility (minSamples=200, FEAR-excluded display) latest:
  - `/Users/yoe/Documents/REPOS/eMove-playground/outputs/figures/ks_immobile_20260311_203819`

### Analysis Pipeline Run (Manifest-Ordered)
- Added `CODE/ANALYSIS/runMotionMetricsBatchFromManifest.m`:
  - same computation path as `runMotionMetricsBatch`,
  - subject traversal follows manifest order,
  - selects latest MAT per subject when duplicates exist.
- Added orchestration script `scripts/run_full_analysis_manifest_once.m` to run:
  - motion metrics batch,
  - normalized-bucket/group plots,
  - stimulus-distance matrices + clustering,
  - KS tables + heatmap + body-part stick figures,
  - and save all outputs to a timestamped run folder.

### Run Results
- Successful run output folder:
  - `/Users/yoe/Documents/DATA/HUMANMOCAP_by_subject/derived/analysis_runs/20260311_110642`
- Subject batch stage:
  - `28/28` subjects OK
  - runtime: `133.8 s`
- Distance + clustering stage:
  - runtime: `155.8 s`
  - selected `k=2` in current silhouette sweep
- KS + stick-figure stage:
  - runtime: `7.6 s`

### Runtime Observation And Mitigation
- A prior attempt without sample capping in `computeStimDistanceWasserstein` became impractically slow.
- Mitigation applied:
  - `maxSamplesPerDist=5000` in the run script for reproducible full-batch completion.
- This setting is now documented in `docs/METHODS.md` as an explicit runtime/reproducibility parameter.

### CDF Plotting Adjustments
- Added `scripts/run_cdf_only_manifest.m` for CDF-only exports (no KS/distance stages).
- CDF export now includes both absolute and baseline-normalized variants for:
  - `perVideoMedian` (median speed per row),
  - `pooledRaw` (all speed samples).
- Plot title labels now render marker-group names without underscores in
  `CODE/PLOTTING/plotSpeedCDFByStimGroupFromResultsCell.m`.
- Figure layout updates:
  - figure-level title (suptitle) carries mode/context metadata,
  - panel titles show marker-group labels only,
  - legend is placed outside the last panel (`eastoutside`).
- CDF exporter now saves MATLAB figure files (`.fig`) in addition to `.png` and `.pdf`.

### CDF Stats/Color Consistency And Immobility-35 Run
- `plotSpeedCDFByStimGroupFromResultsCell` now supports:
  - figure-level titles with run context,
  - compact panel titles (marker label only),
  - external legend placement (`eastoutside`) on last panel,
  - consistent emotion colors via `resolveStimVideoColors`,
  - per-panel nonparametric stats text:
    - Kruskal-Wallis p-value,
    - configurable pairwise KS p-value (default `NEUTRAL` vs `FEAR`).
- `run_cdf_only_manifest.m` now supports mode flags and current default run mode:
  - immobility-only export (`doImmobile=true`, `doFullSpeed=false`),
  - immobility threshold metadata in suptitle (`<=35 mm/s`),
  - `.png/.pdf/.fig` outputs.
- Latest immobility-only run output:
  - `/Users/yoe/Documents/REPOS/eMove-playground/outputs/figures/cdf_only_20260311_123836`

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
- Added subject-level session timeline visualization utilities to inspect
  stimulus ordering and waiting/gap durations from mocap/unity timestamps.

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

#### 4) Session timeline visualization run
- New helper/plot/script added:
  - `CODE/HELPERS/buildSubjectSessionTimeline.m`
  - `CODE/PLOTTING/plotSubjectSessionTimeline.m`
  - `scripts/plot_session_timeline_batch.m`
- Batch timeline generation result:
  - subjects processed: `28`
  - subjects with errors: `0`
  - summary CSV:  
    `/Users/yoe/Documents/DATA/HUMANMOCAP_by_subject/derived/session_timeline/session_timeline_summary.csv`
  - per-subject outputs:
    - `*_session_timeline.png`
    - `*_session_timeline.csv`

### Known Caveats (still open)
- `parseViconCSV.m` currently assumes an `Unlabeled` column exists in Vicon headers.
- `getMarkerTrajectory.m` currently:
  - defaults to clipping first 5 seconds (`CLIPSEC=5`)
  - overwrites passed `mocapMetaData` with `trialData.metaData`
- These are known behavior risks and should be addressed deliberately before broad automation.

### Subject Exclusion Registry (2026-03-11)
- Added CSV-backed exclusion source:
  - `resources/project/subject_exclusions.csv`
- Added helper functions:
  - `CODE/HELPERS/loadSubjectExclusionList.m`
  - `CODE/HELPERS/filterResultsCellBySubjectExclusion.m`
- Compatibility update:
  - `CODE/HELPERS/isHardwiredExcludedSubjectID.m` now reads the CSV list while
    preserving the legacy function name used by existing pipeline code.

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
