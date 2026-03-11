# Analysis Run Report (2026-03-11)

Run script:
- `scripts/run_full_analysis_manifest_once.m`

Canonical completed run:
- output folder: `/Users/yoe/Documents/DATA/HUMANMOCAP_by_subject/derived/analysis_runs/20260311_110642`

## 1) Scope Executed

The following stages were executed end-to-end:
- manifest-ordered batch motion metrics over `matlab_from_manifest`,
- normalized metric bucket build,
- grouped metric plots and CDF plots,
- stimulus distance matrix (Wasserstein) and clustering plots,
- KS distance table, KS heatmap, and KS stick-figure panel plots.

## 2) Outcome Summary

- Subject processing: `28/28` succeeded.
- Core artifacts were produced:
  - `resultsCell.mat`
  - `run_summary.csv`
  - `normalized_buckets.mat`
  - `stim_distance_wasserstein.mat/.csv`
  - `stim_distance_cluster.mat`
  - `ks_distances_by_subject.csv`
- Figures (PNG + vector PDF) were produced for:
  - grouped speed/MAD/SAL plots,
  - CDF summary,
  - distance matrix summary,
  - clustering outputs,
  - KS heatmap,
  - KS stick-figure panel.

## 3) Warnings / Quirks Observed

1. `plotSpeedCDFByStimGroupFromResultsCell` warning:
   - `Ignoring extra legend entries.`
   - Impact: cosmetic only; figures still generated.

2. MATLAB Java warnings during graphics:
   - reflective-access warnings from `hg.jar`/AWT.
   - Impact: no functional failure observed in this run.

3. Runtime bottleneck in distance stage without capping:
   - first attempt (run folder `.../analysis_runs/20260311_104717`) stalled in `computeStimDistanceWasserstein`.
   - mitigation used in final run: `maxSamplesPerDist=5000`.

## 4) Practical Recommendations

- Keep `maxSamplesPerDist` exposed as a documented analysis parameter and log it on every run.
- Consider adding a wrapper option preset (for example `runtimeProfile='full'|'fast'`) to avoid manual edits.
- Consider fixing legend handle creation in `plotSpeedCDFByStimGroupFromResultsCell` to remove noisy warnings.

