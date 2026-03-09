# Architecture Brief: Body-Part Grouping And Self-Report Body Maps

Date: 2026-03-07

Related diagrams:
See [ARCHITECTURE_CALL_GRAPHS.md](/Users/yoe/Documents/REPOS/eMove-playground/ARCHITECTURE_CALL_GRAPHS.md) for function-level call graphs.

## 1) What We Observed

### 1.1 Current eMove codebase

1. Marker grouping is currently passed as manual `markerLists` plus optional `markerGroupNames`.
2. There is only a minimal helper (`getGroupedMarkerNames`) that does substring matching.
3. Analysis and plotting functions already support marker-group subsets well once groups are provided.
4. Main gap is not downstream analysis, but upstream group-definition ergonomics and validation.

### 1.2 Self-report CSV (`Self-report-body.csv`)

1. Semicolon-separated file with 415 columns.
2. Rows are participant-level wide records.
3. Structure is repeated blocks:
`20x GEW items + Q00002 + Q00003 + text`.
4. In this export, `Q00002`/`Q00003` carry activation/deactivation body-map traces as JSON-like coordinate arrays.
5. Subject IDs are not cleanly standardized (mixed case and clear test rows exist), so ID normalization and QC are required.
6. File includes baseline and demo blocks plus `G1..G15` blocks; mapping to your full stimulus set must be explicit.

### 1.3 Enrico Glerean `embody` repository

Repository: <https://github.com/eglerean/embody>

1. MATLAB scripts (`matlab/embody_demo.m`, `matlab/load_subj.m`) show the original data concept:
paint traces are reconstructed into pixel maps and optionally smoothed.
2. Raw trial format in `embody` demo data is sectioned by `-1,-1,-1` delimiters:
mouse trajectory, paint trajectory, mouse-down times, mouse-up times.
3. Their workflow confirms that preserving raw paint traces and converting later is a practical approach.

## 2) Recommended Architecture

### 2.1 Body-part grouping layer (new)

Add a dedicated grouping module that is independent of metric code:

1. Canonical definition file:
`bodypart_groups.csv` (or `.mat`) with columns:
`groupName, markerName, side, level, includeByDefault, notes`.
2. Resolver utility:
input = marker names from Vicon + user selection options;
output = validated `markerLists` and `markerGroupNames`.
3. Validator utility:
flags unknown markers, empty groups, duplicates, unassigned markers.
4. Selection utility:
supports `includeGroups`, `excludeGroups`, and `customGroups` overrides.

This replaces ad-hoc manual cell arrays as the default user path.

### 2.2 Self-report ingestion layer (new)

Build a self-report parser that outputs tidy trial-level records:

1. Input:
wide `Self-report-body.csv`.
2. Output:
table with one row per subject x trial block containing:
`subjectID, trialKey, gewScores(1..20), bodyActRaw, bodyDeactRaw, textRaw`.
3. Keep raw JSON payloads in output for traceability.
4. Parse JSON coordinates into optional structured arrays only when needed by downstream functions.
5. Add QC columns:
`idNormalized`, `isTestLikeID`, `hasActMap`, `hasDeactMap`, `isMalformed`.

### 2.3 Mapping layer between self-report and stimuli (new)

Introduce explicit mapping table instead of hardcoded assumptions:

1. `selfReportTrialMap.csv` with columns:
`trialKey, expectedOrder, videoID, blockType`.
2. Required because current file has `G1..G15` blocks and separate baseline/demo blocks.
3. Join key for analysis:
`subjectID + videoID` after mapping.

### 2.4 Comparison layer (future, approval-gated)

Once mapping and ingestion are stable:

1. Aggregate motion metrics by canonical body-part groups.
2. Aggregate self-report body maps into the same canonical groups.
3. Compare directionality and rank patterns across groups.

Any new computed comparison metric should be implemented only after your explicit approval.

## 3) Suggested Implementation Order

1. Implement body-part group definition + resolver + validator (no metric changes).
2. Implement self-report wide-to-tidy parser + QC report (no comparisons yet).
3. Create and validate `trialKey -> videoID` mapping table with your collaborator.
4. Add non-computational join utility producing aligned tables ready for later analysis.
5. Only then design and approve actual comparison metrics.

## 4) Quirks Found

1. `Self-report-body.csv` includes likely pilot/test IDs (`Janne`, `asdfasd`, mixed-case IDs).
2. Body-map fields vary between empty, `[]`, and long coordinate arrays.
3. Trial blocks appear to be 15 (`G1..G15`) in this export, which aligns with the canonical design of 15 post-baseline stimuli plus 1 baseline segment (16 total segments).
4. Current grouping in eMove is flexible but brittle because definitions are not centralized.

## 5) Open Questions To Resolve Before Coding Comparison Metrics

1. What is the authoritative mapping from `G1..G15` (and baseline/demo blocks) to stimulus video IDs?
2. Should subject IDs be matched case-insensitively (`ij1701` vs `IJ1701`) and then normalized to uppercase?
3. Do `Q00002` and `Q00003` always mean activation/deactivation in your export version?
4. For missing deactivation maps, should we treat as true zero or unknown/missing?

## 6) Decisions Confirmed (2026-03-07)

1. Subject IDs are matched case-insensitively and stored in uppercase canonical form.
2. Self-report parser should follow current dataset conventions as-is.
3. Working mapping assumption:
`G1..G15` correspond to per-subject Unity presentation order after `BASELINE`.
4. HR/EDA ingestion must explicitly handle split recordings (multiple files per modality).
5. If multiple baseline/demo blocks exist for a subject, use the **last** `BASELINE` as anchor and ignore earlier logs.
6. If post-baseline Unity video IDs repeat, keep first chronological occurrence for mapping and flag repeats in QC.
7. Current dataset-specific default exclusions: `JANNE`, `AS2302`, `XC1301`.
