# Development Log

This document tracks project state, implementation decisions, and validation runs.

## 2026-03-20

### Auxiliary Modality Visualization And Integration Memo
- Ran a quick cross-modality visualization pass outside the main MATLAB pipeline to inspect:
  - eye tracking from Unity logs,
  - ECG / HR from Movesense,
  - EDA from Shimmer.
- Main purpose of this pass:
  - document workable alignment assumptions and next MATLAB integration steps before folding these modalities into motion-analysis trial structures.
- Added integration memo:
  - `docs/AUX_MODALITY_INTEGRATION_2026-03-20.md`

### Worked Example Alignment Decisions Recorded
- Example stimulus used for the quick pass:
  - `x_0302`
  - Unity window: `2025-08-15 14:34:55` to `14:35:25`
- Eye data interpretation:
  - Unity logs remain the canonical trial clock and can carry eye variables stimulus-wise without extra cross-device sync.
- EDA alignment interpretation:
  - Shimmer timestamps can be aligned directly to the local session clock in the worked example.
- ECG alignment interpretation:
  - example-session alignment was inferred from the Movesense UTC header timestamp converted to local session time,
  - therefore ECG timing should currently carry explicit provenance / confidence metadata in future MATLAB integration.

### Recommended Next MATLAB Work
- Add auxiliary modality windows into the same trial-level structures already used for mocap segmentation.
- Preserve:
  - source file provenance,
  - sample rate,
  - alignment method,
  - timing-confidence flags.
- Build simple multimodal QC figures in MATLAB before any inferential multimodal analysis.

### EDA Summary Features Clarified During Figure Iteration
- The most useful compact EDA descriptors from the quick collaborator-facing
  figure iteration were:
  - tonic slope over the Unity-defined `0–30 s` stimulus window,
  - phasic spike count over the same `0–30 s` stimulus window.
- Current working interpretation:
  - tonic slope is a plausible descriptive proxy for gradual conductance rise
    or fall during a trial,
  - phasic spike count is a plausible descriptive proxy for the frequency of
    short phasic responses during a trial.
- Current limitation:
  - both summaries are still exploratory and should be re-implemented and
    validated in the MATLAB pipeline before they are treated as analysis
    variables.

### EDA QC Figure Design Direction
- The most stable presentation-oriented EDA layout from the iteration ended up
  using:
  - full-session tonic conductance with Unity stimulus markers,
  - full-session phasic trace with the same marker scheme,
  - a compact stimulus-aligned EDA comparison panel,
  - and a per-stimulus summary panel showing tonic slope plus phasic spike
    count.
- A non-y-aligned tonic trace view was tested and rejected as not useful for
  interpretation.

## 2026-03-14

### Regime-Distinctness Analysis Passes
- Added pooled regime-distinctness script:
  - `scripts/analyze_regime_distinctness_all_bodyparts.m`
- Added subject-level follow-up script:
  - `scripts/analyze_regime_distinctness_subject_level.m`
- Added focused reversal/export script:
  - `scripts/make_disgust_joy_head_regime_panels.m`
- Added presentation-style regime slide builder:
  - `scripts/make_regime_story_slide.m`
- Added box-and-jitter regime-order figure builder:
  - `scripts/make_regime_order_boxscatter_panels.m`

### Regime Analysis Outputs (latest)
- Head pooled reversal panel (`DISGUST` vs `JOY`):
  - `/Users/yoe/Documents/REPOS/eMove-playground/outputs/figures/disgust_joy_head_regime_20260314_194230`
- Pooled regime-distinctness diagnostics, FEAR included:
  - `/Users/yoe/Documents/REPOS/eMove-playground/outputs/figures/regime_distinctness_20260314_195024`
- Subject-level regime summary:
  - `/Users/yoe/Documents/REPOS/eMove-playground/outputs/figures/regime_subject_level_20260314_195909`
- Story-slide draft, corrected FEAR-excluded version:
  - `/Users/yoe/Documents/REPOS/eMove-playground/outputs/figures/regime_story_20260314_203008`
- Pooled regime-distinctness diagnostics, FEAR excluded, upper-body focus:
  - `/Users/yoe/Documents/REPOS/eMove-playground/outputs/figures/regime_distinctness_20260314_203938`
- Subject-median box/jitter regime-order figure set:
  - `/Users/yoe/Documents/REPOS/eMove-playground/outputs/figures/regime_order_boxscatter_20260314_204428`

### Current Scientific Read From Today
- Pooled upper-body motion and micromovement do not behave like a trivial
  scaled-down copy of one another.
- The strongest regime reorganization is in:
  - `UTORSO`
  - `HEAD`
  - `UPPER_LIMB_L`
  - `UPPER_LIMB_R`
  - `WRIST_L`
  - `WRIST_R`
  - `LTORSO`
- Lower limbs remain comparatively stable and are now omitted from the
  presentation-focused figure variants.
- Subject-level analysis is more conservative than the pooled analysis:
  - pooled geometry shifts strongly,
  - within-subject geometry shifts more modestly,
  - therefore the working interpretation is "partially distinct regime",
    not "completely separate motor regime".

### Presentation-Figure Design Iteration
- The original "full vs micro connected line" panel proved visually weak for
  presentation purposes because:
  - micro values sit on a much smaller scale,
  - emotion ordering is hard to compare,
  - the figure emphasizes regime compression more than regime reordering.
- Replacement direction explored:
  - separate-axis regime panels,
  - FEAR-excluded summaries,
  - upper-body-only focus,
  - subject-level box-plus-jitter plots for readable order comparison.
- Current conclusion:
  - the new box/jitter panels are better than the connected-line plots,
  - but the central presentation figure is still not fully solved and
    requires another design pass.

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

## 2026-03-15

### Regime-Reversal QC And Presentation Work

#### 1) Combined pooled reversal scatter
- Script:
  - `scripts/make_combined_regime_pair_scatter.m`
- Current figure characteristics:
  - upper-body only
  - `FEAR` excluded
  - point color = emotion pair
  - point number = bodypart
  - right-side legend includes pair colors and stick-figure bodypart numbering
  - shaded reversal quadrants with explanatory labels
- Latest discussed export:
  - `/Users/yoe/Documents/REPOS/eMove-playground/outputs/figures/combined_regime_pair_scatter_20260315_124138/combined_regime_pair_scatter.png`

#### 2) Subject-level reversal cloud
- Scripts:
  - `scripts/make_subject_regime_pair_scatter.m`
  - `scripts/make_subject_regime_pair_scatter_combined.m`
- Outputs:
  - per-bodypart subject clouds:
    `/Users/yoe/Documents/REPOS/eMove-playground/outputs/figures/subject_regime_pair_scatter_20260315_081704`
  - combined subject cloud:
    `/Users/yoe/Documents/REPOS/eMove-playground/outputs/figures/subject_regime_pair_scatter_combined_20260315_082032`
- Interpretation:
  - subject-level geometry is broader and less clustered than pooled-raw
  - this is expected because the pooling/weighting is different

#### 3) Reversal stability QC
- Script:
  - `scripts/run_reversal_stability_qc.m`
- Outputs:
  - `/Users/yoe/Documents/REPOS/eMove-playground/outputs/figures/reversal_stability_qc_20260315_083300`
  - `/Users/yoe/Documents/REPOS/eMove-playground/docs/REVERSAL_STABILITY_REPORT_2026-03-15.md`
- Main conclusion:
  - pooled reversals are selective rather than universal
  - the most stable cells are disgust-centered, especially torso-weighted

#### 4) Stable reversal summary figures
- Scripts:
  - `scripts/make_stable_reversal_summary_figure.m`
  - `scripts/make_stable_reversal_summary_allbody.m`
  - `scripts/make_reversal_probability_summary_05.m`
- Outputs:
  - stable upper-body summary:
    `/Users/yoe/Documents/REPOS/eMove-playground/outputs/figures/stable_reversal_summary_20260315_083816`
  - all-body context summary:
    `/Users/yoe/Documents/REPOS/eMove-playground/outputs/figures/stable_reversal_summary_allbody_20260315_084958`
  - softer `>=0.50` probability view:
    `/Users/yoe/Documents/REPOS/eMove-playground/outputs/figures/reversal_probability_summary_05_20260315_085521`
- Main conclusion:
  - surviving cells are concentrated in `UTORSO`, `LTORSO`, some `HEAD`, and
    little/no lower-limb signal

#### 5) Subject-contrast inclusion sensitivity
- Script:
  - `scripts/run_subject_contrast_filter_qc.m`
- Compared methods:
  - reference: all comparable subject cells
  - dead-zone filter: exclude near-zero contrast cells
  - bootstrap-CI filter: include only if full or micro contrast CI excludes zero
- Outputs:
  - `/Users/yoe/Documents/REPOS/eMove-playground/outputs/figures/subject_contrast_filter_qc_20260315_092041`
  - `/Users/yoe/Documents/REPOS/eMove-playground/docs/SUBJECT_CONTRAST_FILTER_REPORT_2026-03-15.md`
- Practical settings used:
  - upper-body only
  - `FEAR` excluded
  - dead-zone quantile `0.20`
  - bootstrap count `30` for pragmatic turnaround
- Result summary:
  - mean reversal fractions changed only slightly across methods
  - the broad reversal picture is not solely created by trivial near-zero cells
  - fragile cells remain concentrated in weaker non-disgust comparisons

### Current Working Read
- The scientifically safest current message is:
  - regime dependence exists
  - it is selective rather than universal
  - the clearest stable part of the picture is disgust-centered and
    torso-weighted
- Lower limbs remain useful as a negative-control region.

### 6) Subject Example Screening And Final Selection
- Script:
  - `scripts/screen_disgust_example_subjects.m`
- Candidate subjects screened:
  - `KN9309`
  - `MB0502`
  - `XC3002`
  - `XJ1505`
  - `XJ1802`
  - `XM3001`
- Practical outcome:
  - `KN9309` gave the strongest reversal count,
  - `XJ1802` was the cleanest "hygienic" compromise,
  - `SC3001` was ultimately retained as the main narrative subject because the
    reversal pattern is visually clearest across `HEAD`, `UTORSO`, and
    `LTORSO`, even though its immobility bouts are less tidy.

### 7) Subject And Pooled Density Panels
- Scripts:
  - `scripts/make_single_subject_disgust_density_figure.m`
  - `scripts/make_disgust_subject_example_pack.m`
  - `scripts/make_pooled_disgust_density_figure.m`
- Current preferred outputs:
  - subject example (`SC3001`):
    `/Users/yoe/Documents/REPOS/eMove-playground/outputs/figures/disgust_subject_pack_20260315_124849_SC3001`
  - pooled density:
    `/Users/yoe/Documents/REPOS/eMove-playground/outputs/figures/pooled_disgust_density_20260315_131050`
- Figure-design decision:
  - density plots with separate full/micro x-axes were preferred over CDFs for
    the subject narrative because the regime-specific scales differ too much for
    a shared axis to read cleanly.

### 8) KS Stick-Figure Iteration
- Scripts:
  - `scripts/make_allpairs_signed_ks_stickfigures.m`
  - `scripts/make_disgust_fear_ks_stickfigures.m`
- Result:
  - a signed/directional color version was generated and rejected as too
    visually confusing and too easy to misread.
  - the unsigned KS style remains the trusted presentation style.
- Current preferred outputs:
  - disgust-focused:
    `/Users/yoe/Documents/REPOS/eMove-playground/outputs/figures/disgust_fear_ks_stickfigures_20260315_133403/disgust_ks_stickfigures.png`
  - fear-focused:
    `/Users/yoe/Documents/REPOS/eMove-playground/outputs/figures/disgust_fear_ks_stickfigures_20260315_133403/fear_ks_stickfigures.png`

### 9) Semantics / Trust Caveats That Must Stay Attached To The Figures
- Pair order and subtraction sign materially alter scatter quadrants.
  - This was not a cosmetic issue; it changed the apparent story.
  - Future scatter figures must state subtraction direction explicitly and keep
    one convention throughout the whole figure family.
- Pooled raw and subject-level plots answer different questions.
  - pooled raw:
    - sample-weighted group summary
  - subject-level:
    - person-level spread before pooling
- The "many reversals everywhere" reading was too strong and is no longer the
  project interpretation.
- Current approved wording should stay close to:
  - disgust-centered,
  - torso-weighted,
  - group-level regime dependence,
  - with head as a secondary contributor,
  - and lower limbs as mostly negative-control-like.

### 10) Figure Cleanup Intent
- By end of day, the figure folders should stop reflecting every intermediate
  run and instead keep the latest run in each figure family.
- The goal of the cleanup is not to erase analysis history from the docs, but to
  reduce directory clutter and keep only the latest representative outputs for
  each panel type.
