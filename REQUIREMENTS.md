# eMove Requirements

Version: 1.1  
Created: 2026-03-05  
Updated: 2026-03-07

## 1) Project Aim

Primary research question:
Can signatures of emotional state be extracted from human motion data, especially in the low-animation (micromotion) regime?

Current evidence baseline:
Micromotion structure differs across emotion-inducing videos.

Strategic extension:
Use auxiliary modalities (EDA, HR, pupil size, saccades/eye movement signals) to strengthen or contextualize motion-based claims.

## 2) Scientific Context And Working Hypotheses

1. Fear is associated with a marked decrease in micromotion structure.
2. Other emotions (joy, disgust, sadness, neutral) appear distinguishable in motion features.
3. Emotion effects differ by body part.
4. Non-trivial relations may exist between eye behavior and motion properties (for example smoothness), but this is exploratory.

## 3) Experiment Structure

1. One subject is recorded once (single session per subject).
2. Session contains one continuous mocap recording.
3. Session includes 16 total segments:
one explicit `BASELINE` period and 15 post-baseline immersive stimulus videos.
4. Each stimulus video duration is 30 seconds.
5. Stimulus order is randomized.
6. No break structure is assumed for analysis purposes at this stage.
7. In-between self-report intervals exist, but are out-of-scope for current motion-centric analysis.

## 4) Canonical Subject And Folder Conventions

1. Subject ID is the session identifier and follows pattern: two uppercase letters + four digits (example: `AB1502`).
2. Each subject has one folder named by subject ID.
3. Supported per-subject subfolders:
`mocap`, `hr`, `eda`, `unitylogs`.
4. `mocap` contains Vicon CSV.
5. `unitylogs` contains one file per stimulus presentation and includes eye-tracking data for that stimulus window.
6. `hr` and `eda` contain modality CSV recordings when available.
7. Example Unity log filename:
`AB1502_unitylog_PNr_AB1502_2025-08-14-12-29 x_3502.csv`.
8. Subject ID matching must be case-insensitive and canonical storage should use uppercase IDs.

## 5) Segmentation And Time Reference

1. Unity logs are the canonical segmentation source.
2. Mocap is treated as continuous and cut into stimulus windows using Unity timing.
3. Current analysis scope includes only:
stimulus segments and `BASELINE`.
4. Default segmentation behavior:
use full Unity window for each stimulus.
5. Optional trimming parameters must exist:
`clipStartSec`, `clipEndSec`.
6. Default trajectory clipping should be explicit and neutral:
`clipStartSec = 0` unless a specific analysis overrides it.
7. If multiple baseline/demo Unity blocks exist for a subject, segmentation anchor is the **last** `BASELINE` block.
8. Unity logs before the last `BASELINE` are ignored for stimulus mapping.
9. If post-baseline Unity video IDs repeat, keep only the first chronological occurrence by default and flag the repeats.

## 6) Data Model Strategy (v2)

1. Keep backward compatibility with existing v1 `trialData`.
2. Introduce `trialData` schema v2 with unified per-subject structure centered on mocap.
3. Include modality containers for:
`mocap`, `eye`, `hr`, `eda`.
4. Include synchronization metadata and modality availability/quality flags.
5. Existing v1 MAT files should be upgradable by loader/upgrader logic.
6. New ingestion should produce v2 directly.

## 7) Missing Data And Inclusion Policy

1. Mocap is the central modality and default inclusion anchor.
2. Missing HR/EDA must not automatically exclude a subject from mocap analysis.
3. Analysis tiers must be supported:
Tier A (MoCap-only), Tier B (MoCap+Eye), Tier C (MoCap+Eye+HR/EDA subset).
4. Subject/video inclusion should be user-controlled.
5. Default selection is all subjects and all stimulus videos.
6. HR and EDA modalities may be split into multiple files per subject; ingestion must support multi-file modality inventories.
7. For the current raw dataset snapshot (2026-03-07), default exclude list is:
`JANNE`, `AS2302`, `XC1301`.

## 8) QC Requirements

1. QC granularity:
subject x stimulus x modality.
2. QC should run as a pre-screening step before analysis.
3. Pre-screening output should be persisted as table(s) for review.
4. Initial QC policy:
flag-only by default (no hard auto-exclusion).
5. User decides exclusions through include/exclude lists.
6. Sync mismatch warning tolerance is currently TBD and must remain configurable.
7. HR/EDA/Eye missingness thresholds are currently TBD and must remain configurable.
8. QC should explicitly report split modality file counts and ordering assumptions (for example HR/EDA in multiple pieces).

## 9) Coding Tables And Labels

1. Video IDs are standardized across subjects.
2. System must support both:
global coding tables and subject-specific coding tables.
3. Default current workflow:
single global coding table.
4. Personalized coding from self-reports is a planned extension.

## 10) Self-Report Integration Status

1. Self-report data exists (emotion ratings and body-location information) but schema/availability is currently messy.
2. Current available export (`Self-report-body.csv`) uses semicolon delimiters and repeated trial blocks with:
`20x GEW ratings + activation body-map + deactivation body-map + free-text`.
3. Body-map fields are serialized JSON-like coordinate traces and require parsing, validation, and normalization before use.
4. Codebase must include interface hooks for future self-report based coding personalization.
5. Raw self-report input (`Self-report-body.csv`) is treated as immutable raw data and must stay in raw-data storage, not inside this repository.
6. Parsed self-report artifacts (for example compact MAT/CSV outputs) are treated as derived data and must be written to external processed-data folders, not committed to this repository.

## 11) Output Requirements

1. Typical workflow output starts with saved MAT structs.
2. Downstream analysis and plotting functions consume saved structs.
3. Default output organization:
per-subject processed MATs in subject folders and centralized run outputs in dated folders.
4. Each analysis output must include metadata:
parameters used, subject counts per condition, modality availability summary.
5. Each analysis output must include provenance:
`gitCommitHash`, `gitBranch`, `analysisTimestamp`, `schemaVersion`.
6. Outputs should support trace-back to exact code/data assumptions used.
7. Generated outputs from raw data ingestion (including parsed self-report compact files) must be stored outside the repository in versioned processed-data paths.

## 12) Readability And Governance Requirements

1. Code must be student-readable.
2. Functions should be understandable as “one thing at a time.”
3. Non-obvious logic must be commented.
4. Core computed-algorithm changes require explicit owner approval before implementation.
5. This approval rule applies to metrics such as speed, spectral, immobility, and statistical distance logic.

## 13) Configuration Requirements

1. A user-controlled defaults/config file must exist.
2. Configurable items must include:
included subjects/videos, coding table selection, clip settings, QC thresholds.
3. Defaults should be conservative and transparent.

## 14) Open/TBD Items

1. Sync mismatch tolerance threshold.
2. Baseline handling beyond explicit `BASELINE` segment (for the random initial no-video period).
3. Practical missing-data thresholds per modality for hard exclusion rules (if ever enabled).
4. Formal self-report schema and ingestion mapping.
5. Mapping from self-report trial labels (`G1..G15`, baseline/demo blocks) to actual stimulus video IDs and order.
Current working assumption: map `G1..G15` to per-subject Unity presentation order after `BASELINE`, ordered by stimulus timestamps.
6. For sessions with repeated post-baseline video IDs, only first chronological occurrence is used for `G1..G15` mapping.

## 15) Body-Part Grouping Requirements

1. The system must support marker analysis by selected body parts without requiring users to manually build ad-hoc cell arrays in each script.
2. Body-part grouping must be driven by a readable, versioned definition source (for example a table/config file) that maps marker names to canonical body-part groups.
3. Users must be able to:
choose predefined group sets, include/exclude groups, and define custom groups for a run.
4. Validation must detect:
unknown marker names, duplicate marker assignment (if disallowed), empty groups, and unassigned markers.
5. Group definitions must remain decoupled from metric computation code so grouping can evolve without rewriting analysis algorithms.
6. Defaults should include a coarse canonical set aligned with existing analysis labels (for example head, torso, waist, left/right arms, left/right wrists, left/right legs).

## 16) Body-Map Self-Report Integration Requirements

1. Ingestion must parse both activation and deactivation body-map fields per trial and preserve raw payloads for traceability.
2. Ingestion output must be per-subject and per-trial tidy records containing:
subject ID, trial key, GEW vector, activation map payload, deactivation map payload, and free text.
3. Subject IDs from self-report files must be normalized and QC-checked against mocap subject IDs.
4. Missing or malformed self-report entries must be flagged (not silently dropped).
5. The pipeline must support linking self-report trial records with motion-analysis stimulus segments via explicit mapping tables.
6. Comparison analyses between reported body activation and micromotion changes are a planned extension and must remain optional.
7. Any new computed comparison metric between self-report maps and motion features requires explicit owner approval before implementation.
