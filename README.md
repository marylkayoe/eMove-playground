# eMove Analysis Project

## Project Overview
This repository is dedicated to analyzing movement signatures in motion capture (MoCap) data that correlate with the emotional content of videos displayed through a VR headset. The project is a collaborative effort between Yoe and Simo.

## Repository Structure
- `RAWDATA/`: Directory for raw data files (excluded from version control).
- Under `RAWDATA/` there are subfolders for different types of data:
  - `MOCAP/`: motion capture data files.
  - `EDA/`: electrodermal activity data files.
  - `HR/`: heart rate data files.
  - `STIMVIDEOS/`: stimulus videos shown during data collection.
  - `UNITYLOGS/`: Unity logs (including timing and possible eye-tracking related data).
- `CODE/`: MATLAB code for ingestion, analysis, and plotting.

## Quick Pipeline
1. Organize/assign raw files by subject and modality.
2. Build per-subject `trialData` MAT files from mocap + Unity timing.
3. Run batch motion metrics.
4. Produce aggregate summaries and plots.

Current analysis run scripts:
- Full manifest run (metrics + CDF + distance + KS + stick figures):  
  `scripts/run_full_analysis_manifest_once.m`
- CDF-only export from latest manifest run:  
  `scripts/run_cdf_only_manifest.m`
- KS immobility-only export (heatmaps + stick figures):  
  `scripts/run_ks_immobility_only.m`
- Presentation-oriented DISGUST vs NEUTRAL panel export:
  `scripts/make_disgust_neutral_panels.m`

## Waseda ACC (Protocol-Development Track)

This repository now also carries a MATLAB-first continuation of the Waseda
standing accelerometer pilot as a separate protocol-development track.

Current scope:
- chest ACC quiet-state departure detection and summary
- inter-event interval and departure-shape summaries
- scratch-first figure rendering for candidate-pattern inspection

Current tracked entry points:
- repo-local manifest:
  - `resources/waseda_acc/dataset_manifest.json`
- envelope preprocessing helper:
  - `CODE/ANALYSIS/preprocessWasedaDynamicEnvelope.m`
- quiet-dynamics probe:
  - `scripts/run_waseda_quiet_dynamics_probe.m`
- candidate-pattern summary figure:
  - `scripts/make_waseda_candidate_pattern_summary.m`
- focused departure figure set:
  - `scripts/make_waseda_departure_figure_set.m`
- zoomable envelope/event figures:
  - `scripts/make_waseda_envelope_event_figures.m`
- condition-split metric CDFs:
  - `scripts/make_waseda_departure_metric_cdfs.m`
- metric-vs-time scatter summaries:
  - `scripts/make_waseda_event_metric_scatter_vs_time.m`

Current output policy:
- generated Waseda outputs should go to `scratch/waseda_acc_matlab/...`
- do not commit probe CSVs or rendered figures unless explicitly promoted

Current descriptive status:
- the most useful current Waseda event object is a compound quiet-state
  departure, not a dense derivative spike
- artifact blanking at the envelope level is now part of the workflow
- raw ACC frequency-space inspection is now being used to check whether the
  rhythmic carrier is already present before envelope construction and to
  decide whether any band-stop suppression should be tested as a
  preprocessing step
- the current raw spectra suggest a subject-specific low-frequency carrier
  corridor rather than one universal tone, so any suppression test will need
  to be checked window by window
- current desk vs video comparison figures suggest:
  - longer departures in desk work,
  - larger departure amplitudes in desk work,
  - slower return-to-baseline in desk work,
  - and a plausible short-duration event mode around roughly `0.5 s`
- the current shape branch compares short events in fixed real time first and
  then amplitude-normalized, without duration normalization
- the current overlay branch uses the detector event times directly, stacks
  event waveforms by subject and condition, and compares pooled desk/video
  averages after excluding saturated peaks (`peak_env >= 0.45`) and extending
  the recovery window to `10 s`
- this remains a protocol-development / candidate-pattern track, not a
  validated psychological inference

## Interactive Exploration Tools
- Micromovement example browser:
  - launcher: `scripts/launch_micromovement_example_browser.m`
  - app-style entrypoint: `CODE/APPS/launchMicromovementExplorerApp.m`
  - current capabilities:
    - subject/video/bodypart browsing from manifest-built MAT files,
    - preserved browsing context across subject switches,
    - configurable pre/post stimulus context,
    - integrated speed panel and immobility shading,
    - right-side stick-figure overview,
    - EPS export via `painters` rendering for Illustrator-friendly vector output.
- Group-level CDF comparison browser:
  - launcher: `scripts/launch_cdf_comparison_browser.m`
  - main file: `CODE/PLOTTING/gui/launchCdfComparisonBrowser.m`
  - current capabilities:
    - multi-bodypart selection,
    - left/right collapsing into combined display groups:
      - `Arms`
      - `Wrists`
      - `Legs`
    - multi-emotion overlay in one plot,
    - `perVideoMedian`, `pooledRaw`, or `perSubjectRaw` modes,
    - full-speed vs micromovement comparison,
    - baseline-normalized vs absolute display,
    - EPS export via `painters` rendering for Illustrator-friendly vector output.
- Subject-level density browser:
  - launcher: `scripts/launch_subject_density_browser.m`
  - main file: `CODE/PLOTTING/gui/launchSubjectDensityBrowser.m`
  - current capabilities:
    - one-subject exploration of speed distributions by selected emotion set,
    - pooled-across-subjects mode via `POOLED (all subjects)`,
    - one or more combined display groups:
      - `Head`
      - `Upper torso`
      - `Lower torso`
      - `Arms`
      - `Wrists`
      - `Legs`
    - `Probability density` or `CDF` display mode,
    - full-motion or micromovement-only display,
    - baseline-normalized or absolute display,
    - optional panel-level significance annotations:
      - `ranksum` for two selected emotions,
      - `Kruskal-Wallis` for three or more,
    - optional per-panel `KS D` annotation for exactly two selected emotions in the density/CDF view,
    - compact pairwise KS heatmap view from the same browser,
    - quantile-based x-range clipping for long-tailed distributions,
    - EPS export via `painters` rendering for Illustrator-friendly vector output.
  - current caveats:
    - the browser uses KDE (`ksdensity`) rather than histogram bins,
    - the selected x-limit quantile defines both the displayed range and the support of the plotted KDE after trimming values to that range,
    - the browser currently uses the precomputed `speedArrayImmobile` field for micromovement mode,
    - therefore the browser no longer exposes a live-editable micromovement threshold; analysis-side threshold recomputation remains future work,
    - collapsed browser labels are display aliases only; the underlying saved result-cell group names remain canonical left/right labels,
    - pooled browser plots are exploratory pooled-sample views and should not be confused with the subject-aggregated batch KS summaries used in the main reporting pipeline.

## Poster Figure Utilities
- Current poster-oriented bodypart summary maps are generated by:
  - `scripts/make_fear_summary_bodymap.m`
- Despite the name, this script currently supports target-emotion summary maps for:
  - `FEAR`
  - `DISGUST`
  - `JOY`
  - `SAD`
- Current poster-facing convention:
  - `FEAR` is summarized against all other emotions
  - non-fear target maps are summarized against other non-fear emotions
  - bodypart summaries are baseline-normalized
  - legs are shown in neutral gray and excluded from the color scale
  - figure color scales are shared within a figure (full vs micromovement) and
    based on the displayed non-gray aggregated bodypart values
  - EPS export uses `painters` for Illustrator workflows

## Session Structure (Canonical)
- One continuous mocap recording per subject session.
- `16` total segments per session:
  - `1` explicit `BASELINE` segment.
  - `15` post-baseline stimulus video segments (30 s each).

See [CODE_INDEX.md](CODE_INDEX.md) for a file-by-file map.

## Auxiliary Modality Integration Status
- Current raw-data modalities already available around the mocap pipeline:
  - eye tracking from Unity logs,
  - EDA from Shimmer,
  - ECG / HR from Movesense.
- Current parser entry points already in the MATLAB codebase:
  - `loadUnityEyeLogCSV`
  - `loadShimmerEDACSV`
  - `loadMovesenseECGCSV`
  - `loadModalitySignalsFromInventory`
- A concrete integration memo from the 2026-03-20 visualization/alignment pass is here:
  - [docs/AUX_MODALITY_INTEGRATION_2026-03-20.md](docs/AUX_MODALITY_INTEGRATION_2026-03-20.md)
- Operational recommendation for the next MATLAB step:
  - keep Unity timing as the canonical trial clock,
  - attach auxiliary modality windows to the same per-trial structures used for mocap segmentation,
  - preserve modality-specific alignment provenance, especially for ECG.

See [CODE_INDEX.md](CODE_INDEX.md) for a file-by-file map.

## Readability And Editing Policy
- Code should be student-readable: clear names, explicit assumptions, and comments for non-obvious logic.
- Any change that affects computed values (speed, spectral features, thresholds, statistics) requires explicit owner approval before implementation.

Detailed conventions are in [CONTRIBUTING_READABILITY.md](CONTRIBUTING_READABILITY.md).

## Notes
- Ensure all raw data files are placed in `RAWDATA/`.
- `RAWDATA/` is excluded from version control to avoid issues with large files.
- Keep raw self-report CSV immutable (example: `.../HUMANMOCAP/Self-report-body.csv`).
- Save parsed self-report outputs (for example `selfReportCompact.mat`) in a derived data location outside this repo (example: `.../HUMANMOCAP_by_subject/derived/selfreport/`).
- Subject exclusion policy is CSV-driven via `resources/project/subject_exclusions.csv`.
- Important reproducibility note:
  - `runMotionMetricsBatch*` currently applies subject exclusions by default.
  - For legacy parity checks, explicitly pass `'applySubjectExclusions', false`.

---

*Last updated: March 29, 2026*
