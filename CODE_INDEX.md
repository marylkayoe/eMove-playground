# eMove Code Index

This document maps the current MATLAB codebase so new contributors can quickly find the right file.

## 1) Pipeline At A Glance

1. Organize raw recordings into per-subject folders.
2. Convert per-subject MoCap CSV into `trialData` MAT files.
3. Run motion metrics across subjects/stimuli.
4. Aggregate, normalize, and visualize results.

## 2) Folder Map

- `CODE/HELPERS/`
  - Dataset organization and metadata helpers.
  - Main files:
    - `buildDatasetAssignments.m`
    - `buildSubjectTrialData.m`
    - `buildSubjectTrialDataBatch.m`
    - `buildSubjectTrialDataFromManifest.m`
    - `buildSubjectTrialDataBatchFromManifest.m`
    - `parseViconCSV.m`
    - `getSubjectModalityFileInventory.m`
    - `loadUnityEyeLogCSV.m`
    - `loadShimmerEDACSV.m`
    - `loadMovesenseECGCSV.m`
    - `loadModalitySignalsFromInventory.m`
    - `createStimEncodingTemplateFromManifest.m`
    - `createBodypartGroupingTemplateFromTrialData.m`
    - `launchBodypartGroupingHelper.m`
    - `loadBodypartGroupingCSV.m`
    - `buildMarkerGroupsFromAssignmentTable.m`
    - `buildSubjectSessionTimeline.m`
    - `parseSelfReportBodyCSV.m`
    - `buildSelfReportTrialToUnityMap.m`
    - `normalizeSubjectID.m`
    - `isHardwiredExcludedSubjectID.m`

- `CODE/ANALYSIS/`
  - Metric computation, aggregation, and statistical summaries.
  - Main files:
    - `runMotionMetricsBatch.m`
    - `runMotionMetricsBatchFromManifest.m`
    - `getMotionMetricsAcrossStims.m`
    - `getMotionMetricsForMarkers.m`
    - `getMotionMetricsFromTrajectory.m`

- `CODE/PLOTTING/`
  - Static plotting utilities and poster figures.
  - Includes self-report body-map visualization:
    - `plotSelfReportBodyMapsByVideo.m`
  - Includes subject session-structure visualization:
    - `plotSubjectSessionTimeline.m`
  - Includes poster KS body-part stick figure tools:
    - `poster/ks/plotKsBodyPartStickFigure.m`
    - `poster/ks/plotKsBodyPartStickFigurePanel.m`
    - `poster/ks/plotKsBodyPartStickFigureAllPairs.m`

- `CODE/PLOTTING/poster/gui/`
  - Interactive exploration tools.
  - Main files:
    - `launchMicromovementExampleBrowser.m`
  - Current notes:
    - supports EPS export (`painters` + `print -depsc`) for Illustrator workflows.

- `CODE/PLOTTING/gui/`
  - Interactive non-poster plotting browsers.
  - Main files:
    - `launchCdfComparisonBrowser.m`
    - `launchSubjectDensityBrowser.m`
    - `plotPooledSpeedDensityByEmotion.m`
    - `plotPooledPairwiseStatsHeatmap.m`
    - `plotSubjectPairwiseStatsHeatmap.m`
  - Current notes:
    - left/right limb groups are collapsed into combined browser options:
      - `Arms`
      - `Wrists`
      - `Legs`
    - supports EPS export (`painters` + `print -depsc`) for Illustrator workflows.
    - subject density browser plots per-subject or pooled KDE speed distributions for one or more selected emotions and bodyparts.
    - subject density browser supports:
      - baseline-normalized or absolute display,
      - full-motion or micromovement-only selection,
      - probability-density or CDF mode,
      - optional panel-level significance annotations,
      - optional two-emotion KS readout in density/CDF panels,
      - compact pairwise KS heatmaps from the same selections,
      - quantile-based x-range clipping for long-tailed distributions.
    - current caveat:
      - subject density browser micromovement mode uses the precomputed `speedArrayImmobile` field;
      - live threshold changes are intentionally not exposed until browser-side recomputation is implemented.
    - current heatmap convention:
      - every off-diagonal cell uses the same semantics,
      - cell color = KS distance `D`,
      - cell text = significance stars only,
      - color scale is shared across bodypart panels within one figure.

- `CODE/APPS/`
  - Deployment-aware app entrypoints for packaged or user-facing tools.
  - Main files:
    - `launchMicromovementExplorerApp.m`

## 3) Core Data Object (`trialData`)

`trialData` is the shared object passed through analysis functions.

Current expected fields:
- `markerNames`: marker labels from Vicon CSV.
- `trajectoryData`: `nFrames x 3 x nMarkers` position matrix.
- `metaData`: recording metadata, including stimulus schedule (`videoIDs`, `stimScheduling`) when Unity logs are available.
- `subjectID`: added by subject-level build scripts.
  - `metaData.modalityFileInventory`: per-modality source file inventory (helps with split HR/EDA files).
  - `metaData.modalitySignalsLoaded`: true only when modality CSVs are parsed into memory.
- `modalityData` (optional): parsed Unity/EDA/HR tables when `loadModalitySignals=true`.

## 4) Main Entry Points

- Raw file assignment:
  - `CODE/HELPERS/buildDatasetAssignments.m`
- Subject MAT build:
  - `CODE/HELPERS/buildSubjectTrialData.m`
  - `CODE/HELPERS/buildSubjectTrialDataBatch.m`
  - `CODE/HELPERS/buildSubjectTrialDataFromManifest.m`
  - `CODE/HELPERS/buildSubjectTrialDataBatchFromManifest.m`
- Modality parsing (no metrics):
  - `CODE/HELPERS/loadUnityEyeLogCSV.m`
  - `CODE/HELPERS/loadShimmerEDACSV.m`
  - `CODE/HELPERS/loadMovesenseECGCSV.m`
  - `CODE/HELPERS/loadModalitySignalsFromInventory.m`
- Template generation for testing:
  - `CODE/HELPERS/createStimEncodingTemplateFromManifest.m`
  - `CODE/HELPERS/createBodypartGroupingTemplateFromTrialData.m`
  - `CODE/HELPERS/launchBodypartGroupingHelper.m`
  - `CODE/HELPERS/loadBodypartGroupingCSV.m`
  - `CODE/HELPERS/buildMarkerGroupsFromAssignmentTable.m`
  - `scripts/generate_testing_templates.m`
  - `scripts/launch_bodypart_grouping_helper.m`
  - `scripts/launch_micromovement_example_browser.m`
  - `scripts/launch_cdf_comparison_browser.m`
  - `scripts/launch_subject_density_browser.m`
  - `scripts/make_fear_summary_bodymap.m`
  - `scripts/make_analysis_workflow_figure.m`
  - `scripts/export_analysis_workflow_trace_panel.m`
  - `scripts/make_disgust_neutral_panels.m`
  - `scripts/run_testing_smoke.m`
  - `scripts/plot_session_timeline_batch.m`
  - `scripts/run_full_analysis_manifest_once.m`
  - `scripts/run_cdf_only_manifest.m`
  - `scripts/run_ks_immobility_only.m`
  - `scripts/run_external_vs_playground_ab_qc.m`
  - `scripts/compare_external_playground_same_subjects.m`
- Self-report compact conversion:
  - `CODE/HELPERS/parseSelfReportBodyCSV.m`
- Self-report to Unity order mapping:
  - `CODE/HELPERS/buildSelfReportTrialToUnityMap.m`
- Batch motion metrics:
  - `CODE/ANALYSIS/runMotionMetricsBatch.m`
- Higher-level summaries:
  - `CODE/ANALYSIS/buildNormalizedMetricsBuckets.m`
  - `CODE/ANALYSIS/collectSpeedByStimVideo.m`
  - `CODE/ANALYSIS/computeKsDistancesFromResultsCell.m`

## 5) Editing Rules For This Project

- Keep code student-readable:
  - Use clear variable names.
  - Add short comments where logic is not obvious.
  - Prefer explicit steps over compact one-liners when readability improves.

- Do not change computation behavior without explicit approval:
  - Speed, spectral, immobility, or other metric algorithms must not be modified unless approved.

## 6) Guarded (Approval-Required) Algorithm Files

These files contain computation logic and should be treated as approval-required for behavior changes:

- `CODE/ANALYSIS/getTrajectorySpeed.m`
- `CODE/ANALYSIS/getMotionMetricsFromTrajectory.m`
- `CODE/ANALYSIS/getMotionMetricsForMarkers.m`
- `CODE/ANALYSIS/getMotionMetricsAcrossStims.m`
- `CODE/ANALYSIS/getTrajectoryFrequencyMetrics.m`
- `CODE/ANALYSIS/computeStimDistanceWasserstein.m`
- `CODE/ANALYSIS/computeKsDistancesFromResultsCell.m`

## 7) Known Quirks (Current Behavior)

- `CODE/getMarkerTrajectory.m`
  - The optional input `'mocapMetaData'` is currently parsed but then overwritten by `trialData.metaData` internally.
  - Default `'CLIPSEC'` is `5`, so extracted trajectories drop the first 5 seconds unless overridden.

- `CODE/HELPERS/parseViconCSV.m`
  - Assumes at least one column contains the label `Unlabeled`; if not present, column-range logic can fail.

- `CODE/getStimVideoScheduling.m`
  - Logs are now ordered by parsed Unity start datetime (fallback: filename timestamp, then file modified time), not plain alphabetical file name order.

- `CODE/HELPERS/buildSelfReportTrialToUnityMap.m`
  - Mapping now anchors on the **last** `BASELINE` by default and deduplicates repeated post-baseline video IDs by keeping first occurrence.

- `CODE/HELPERS/buildDatasetAssignments.m`
  - Adds optional cleanup to reassign short same-day `UNKNOWN` pre-session rows to the next known mocap subject.

- `CODE/PLOTTING/poster/ks/plotKsBodyPartStickFigureAllPairs.m`
  - Pair filtering and `maxPairs` selection are now passed through panel auto-resolution (wrapper no longer forces all pairs).

## 8) Current Presentation Tooling

- Subject-level example mining:
  - `CODE/PLOTTING/poster/gui/launchMicromovementExampleBrowser.m`
  - use this to search for illustrative trial windows with pre/post context and immobility shading.
- Group-level emotion comparison:
  - `CODE/PLOTTING/gui/launchCdfComparisonBrowser.m`
  - use this to compare one or more emotions across selected bodyparts and plot modes.
  - note: browser labels can be combined aliases, while the underlying plotter aggregates the matching canonical result-cell groups.
- Subject-level emotion distribution exploration:
  - `CODE/PLOTTING/gui/launchSubjectDensityBrowser.m`
  - use this to inspect one subject at a time, or pooled across all subjects, across selected emotions and bodyparts using KDE density plots or CDFs.
  - note: x-limit quantile clipping is a display-and-support setting for the plotted KDE, intended to make long-tailed distributions readable without changing the saved analysis results.
  - note: micromovement mode currently reflects the precomputed immobile arrays already stored in `resultsCell`, not a live threshold recomputation inside the browser.
  - note: the paired heatmap view inside this browser is exploratory and is not identical to the subject-aggregated batch `computeKsDistancesFromResultsCell` / `plotKsHeatmap` reporting path.
- Poster-oriented bodypart summary maps:
  - `scripts/make_fear_summary_bodymap.m`
  - despite the historical name, this script is currently the shared generator
    for target-emotion body maps (`FEAR`, `DISGUST`, `JOY`, `SAD`).
  - current convention:
    - baseline-normalized target-vs-other KS summaries,
    - full vs micromovement side-by-side,
    - legs shown in neutral gray and excluded from color-scale computation,
    - EPS export via `painters`,
    - figure color scales are shared within each figure but tuned to the
      displayed non-gray aggregated range.
- Presentation-ready focused export:
  - `scripts/make_disgust_neutral_panels.m`
  - currently oriented toward producing Panel C / Panel D style CDF figures for collaborator or funder slides.
