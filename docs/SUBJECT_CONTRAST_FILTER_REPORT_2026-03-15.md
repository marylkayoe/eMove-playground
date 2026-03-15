# Subject Contrast Filter Report (2026-03-15)

This report compares three subject-cell inclusion rules for reversal counting.

Figure:
- ![Subject contrast filter QC](/Users/yoe/Documents/REPOS/eMove-playground/outputs/figures/subject_contrast_filter_qc_20260315_092041/subject_contrast_filter_qc.png)

Dead-zone thresholds:
- `absolute`: |Δfull| threshold `10.687`, |Δmicro| threshold `1.464`
- `baseline-normalized`: |Δfull| threshold `1.472`, |Δmicro| threshold `0.227`

Interpretation guidance:
- Reference row: all comparable subject cells are counted.
- Dead-zone row: weak near-zero contrasts are excluded before counting reversals.
- Bootstrap-CI row: a subject-cell is counted only if full or micro contrast CI excludes zero.

This is a reversal-specific filter analysis. It is not based on KS significance, because KS addresses a different question (distributional difference rather than directional reversal).
