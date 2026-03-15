# Reversal Stability Report (2026-03-15)

This report tests whether the pooled reversal picture is stable once subjects are treated as subjects.

Outputs used here:
- `/Users/yoe/Documents/REPOS/eMove-playground/outputs/figures/reversal_stability_qc_20260315_083300/reversal_stability_metrics.csv`
- ![Absolute QC](/Users/yoe/Documents/REPOS/eMove-playground/outputs/figures/reversal_stability_qc_20260315_083300/reversal_stability_qc_absolute.png)
- ![Normalized QC](/Users/yoe/Documents/REPOS/eMove-playground/outputs/figures/reversal_stability_qc_20260315_083300/reversal_stability_qc_baseline_normalized.png)

## absolute

### Read
- `pooledFlip=1` means the pooled raw summary lands in a reversal quadrant.
- `subjectFlipFraction` asks how many individual subjects show a reversal for that same bodypart/pair.
- `bootstrapFlipProbability` asks how often the aggregate subject-median reversal survives subject resampling.
- `pooledVsSubjectAgree` asks whether pooled raw and subject-median aggregation tell the same sign-flip story.

### Most Stable Pooled-Reversal Cells
- `LTORSO | SAD-DISGUST`: subject flip fraction `0.30`, bootstrap `0.87`, pooled-vs-subject agreement `1`
- `UTORSO | SAD-DISGUST`: subject flip fraction `0.33`, bootstrap `0.83`, pooled-vs-subject agreement `1`
- `LTORSO | DISGUST-NEUTRAL`: subject flip fraction `0.26`, bootstrap `0.80`, pooled-vs-subject agreement `1`
- `UPPER_LIMB_L | SAD-DISGUST`: subject flip fraction `0.33`, bootstrap `0.66`, pooled-vs-subject agreement `1`
- `HEAD | JOY-DISGUST`: subject flip fraction `0.19`, bootstrap `0.64`, pooled-vs-subject agreement `1`
- `UPPER_LIMB_R | SAD-DISGUST`: subject flip fraction `0.30`, bootstrap `0.59`, pooled-vs-subject agreement `1`

### Most Fragile Pooled-Reversal Cells
- `UPPER_LIMB_L | SAD-NEUTRAL`: subject flip fraction `0.26`, bootstrap `0.04`, pooled-vs-subject agreement `0`
- `WRIST_R | SAD-NEUTRAL`: subject flip fraction `0.30`, bootstrap `0.04`, pooled-vs-subject agreement `0`
- `LTORSO | SAD-NEUTRAL`: subject flip fraction `0.30`, bootstrap `0.09`, pooled-vs-subject agreement `0`
- `UTORSO | SAD-NEUTRAL`: subject flip fraction `0.30`, bootstrap `0.16`, pooled-vs-subject agreement `0`
- `HEAD | SAD-NEUTRAL`: subject flip fraction `0.22`, bootstrap `0.16`, pooled-vs-subject agreement `0`
- `UTORSO | JOY-NEUTRAL`: subject flip fraction `0.26`, bootstrap `0.18`, pooled-vs-subject agreement `0`

### Bodypart-Level Median Stability
- `HEAD`: median subject flip fraction `0.22`, median bootstrap `0.44`, median agreement `1.00`
- `LTORSO`: median subject flip fraction `0.28`, median bootstrap `0.36`, median agreement `1.00`
- `UPPER_LIMB_L`: median subject flip fraction `0.26`, median bootstrap `0.36`, median agreement `1.00`
- `UPPER_LIMB_R`: median subject flip fraction `0.26`, median bootstrap `0.36`, median agreement `1.00`
- `UTORSO`: median subject flip fraction `0.30`, median bootstrap `0.32`, median agreement `1.00`
- `WRIST_L`: median subject flip fraction `0.30`, median bootstrap `0.29`, median agreement `1.00`
- `WRIST_R`: median subject flip fraction `0.26`, median bootstrap `0.28`, median agreement `1.00`

## baseline-normalized

### Read
- `pooledFlip=1` means the pooled raw summary lands in a reversal quadrant.
- `subjectFlipFraction` asks how many individual subjects show a reversal for that same bodypart/pair.
- `bootstrapFlipProbability` asks how often the aggregate subject-median reversal survives subject resampling.
- `pooledVsSubjectAgree` asks whether pooled raw and subject-median aggregation tell the same sign-flip story.

### Most Stable Pooled-Reversal Cells
- `LTORSO | SAD-DISGUST`: subject flip fraction `0.30`, bootstrap `0.89`, pooled-vs-subject agreement `1`
- `UTORSO | SAD-DISGUST`: subject flip fraction `0.33`, bootstrap `0.83`, pooled-vs-subject agreement `1`
- `LTORSO | DISGUST-NEUTRAL`: subject flip fraction `0.26`, bootstrap `0.79`, pooled-vs-subject agreement `1`
- `UPPER_LIMB_L | SAD-DISGUST`: subject flip fraction `0.33`, bootstrap `0.67`, pooled-vs-subject agreement `1`
- `HEAD | JOY-DISGUST`: subject flip fraction `0.19`, bootstrap `0.63`, pooled-vs-subject agreement `1`
- `UPPER_LIMB_R | JOY-DISGUST`: subject flip fraction `0.22`, bootstrap `0.58`, pooled-vs-subject agreement `1`

### Most Fragile Pooled-Reversal Cells
- `WRIST_R | SAD-NEUTRAL`: subject flip fraction `0.30`, bootstrap `0.04`, pooled-vs-subject agreement `0`
- `UPPER_LIMB_L | SAD-NEUTRAL`: subject flip fraction `0.26`, bootstrap `0.04`, pooled-vs-subject agreement `0`
- `WRIST_L | SAD-NEUTRAL`: subject flip fraction `0.30`, bootstrap `0.09`, pooled-vs-subject agreement `0`
- `LTORSO | SAD-NEUTRAL`: subject flip fraction `0.30`, bootstrap `0.10`, pooled-vs-subject agreement `0`
- `HEAD | SAD-NEUTRAL`: subject flip fraction `0.22`, bootstrap `0.16`, pooled-vs-subject agreement `0`
- `UTORSO | SAD-NEUTRAL`: subject flip fraction `0.30`, bootstrap `0.16`, pooled-vs-subject agreement `0`

### Bodypart-Level Median Stability
- `HEAD`: median subject flip fraction `0.22`, median bootstrap `0.43`, median agreement `1.00`
- `LTORSO`: median subject flip fraction `0.28`, median bootstrap `0.36`, median agreement `1.00`
- `UPPER_LIMB_L`: median subject flip fraction `0.26`, median bootstrap `0.36`, median agreement `1.00`
- `UPPER_LIMB_R`: median subject flip fraction `0.26`, median bootstrap `0.36`, median agreement `1.00`
- `UTORSO`: median subject flip fraction `0.30`, median bootstrap `0.32`, median agreement `1.00`
- `WRIST_L`: median subject flip fraction `0.30`, median bootstrap `0.30`, median agreement `0.00`
- `WRIST_R`: median subject flip fraction `0.26`, median bootstrap `0.28`, median agreement `1.00`

## Working Interpretation

If many pooled-reversal cells have only modest subject flip fractions and modest bootstrap persistence, then the pooled reversal map should be treated as suggestive rather than definitive. The most defensible claims will then focus on the subset of pair/bodypart combinations that remain stable under subject-aware resampling.
