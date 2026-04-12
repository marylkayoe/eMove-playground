# Accelerometer Development Log (2026-04-12)

This document tracks the planned workflow for the EmoWear accelerometer analysis.

## 1) Working Question

Primary target:
- quantify motion magnitude from accelerometer data during non-locomotory periods

Planned questions:
1. Does non-locomotory motion magnitude predict locomotion vigor?
2. Does non-locomotory motion magnitude correlate with emotional descriptors of displayed content?

## 2) Dataset Understanding So Far

- EmoWear is a synchronized wearable dataset with:
  - chest IMU signals,
  - additional physiological channels,
  - emotion-eliciting video viewing,
  - walking,
  - talking,
  - drinking,
  - and self-assessed valence / arousal / dominance.
- For the current analysis, the `mat` package is the right first data target because it is the cleaned and synchronized package intended for analysis.
- `meta.csv` should be used for QC and exclusion handling because it records missingness, imperfections, and anomalies.
- The raw package is not needed for the first-pass analysis, but it would be needed if full preprocessing provenance or signal re-extraction becomes necessary.

## 3) Reliability Principles For This Project

The existing project notes make several habits worth preserving here:

- state inclusion and exclusion decisions explicitly,
- make all gating assumptions visible,
- separate exploratory figures from inferential summaries,
- prefer trace-first inspection before committing to summary metrics,
- keep repeated-measures structure visible rather than flattening everything into one pooled sample.

For the accelerometer work, this means:

1. we should not define "non-locomotory" only from intuition,
2. we should inspect labeled traces before computing final features,
3. we should preserve subject-level repeated structure in the statistical design,
4. we should keep a QC table that records every dropped subject, task, or window and why.

## 4) Assumptions That Must Be Verified With The User

These are not implementation details; they affect the scientific meaning of the result.

### A) Emotion Target
- Are we relating accelerometer magnitude to:
  - content-level labels of the displayed clips,
  - subject-level self-reports,
  - or both?

Current recommendation:
- do both, but keep them separate.
- Content labels answer:
  - "what kind of material was shown?"
- Self-reports answer:
  - "what did the participant report feeling?"

### B) Definition Of Non-Locomotory
- Candidate definitions considered:
  - all clip-viewing periods,
  - clip-viewing periods minus detected locomotion bouts,
  - only conservative stationary segments within clip-viewing periods,
  - standing-still frames immediately before walking starts.

Current user preference:
- the primary non-locomotory analysis should use standing-in-place frames just before locomotion onset.
- This is preferred because it is the simplest analogue to the earlier eMove framing.

Operational implication:
- the first-pass primary window should be:
  - `prewalk_standing`
- and not seated clip-viewing windows.

Current secondary plan:
- seated clip-viewing periods can be analyzed later as a separate question rather than folded into the first locomotion-vigor analysis.

### C) Definition Of Locomotion Vigor
- Candidate definitions:
  - acceleration magnitude during walking-task windows,
  - step/cadence-derived vigor,
  - spectral periodicity measures during walking,
  - or a composite index.

Current recommendation:
- start with simple, transparent walking-window summaries.
- Add step-like or periodicity-based measures only after trace inspection shows they are stable.

### D) Trace Display Requirements
- The user wants traces with relevant domains labeled.

Current requirement for trace figures:
- label at least:
  - `BASELINE`
  - `EMOTION_CLIP`
  - `WALK`
  - `TALK`
  - `DRINK`
- and where possible:
  - clip ID
  - emotion label
  - self-report values

### E) Task Exclusion Preference
- The user currently wants to ignore:
  - talking
  - drinking
- for the first pass.

Operational implication:
- first-pass task domains of interest should be restricted to:
  - pre-walk standing
  - walking
- Clip-viewing may be revisited later, but it is not the primary analogue analysis.

## 5) Analysis Strategy

### Phase 1: Data Inventory

Goal:
- learn the exact MAT schema before choosing feature code.

Tasks:
1. inspect MAT folder structure and file naming
2. identify:
   - accelerometer channels
   - sampling rate
   - task/event markers
   - walking windows
   - clip-viewing windows
   - self-report fields
3. map subject/session IDs
4. join `meta.csv` QC information to the subject/session manifest

Deliverable:
- a compact schema note and one manifest table

### Phase 2: Trace-First QC

Goal:
- verify timing, task boundaries, and plausible accelerometer behavior before summary analysis

Tasks:
1. generate a few subject-level timeline plots
2. show accelerometer magnitude over time
3. overlay labeled task domains
4. mark candidate locomotion periods
5. inspect whether walking, talking, drinking, and clip-viewing are cleanly separable

Deliverable:
- example traces with relevant domains labeled

### Phase 3: Define Operational Windows

Goal:
- formalize analysis windows in a way that is inspectable and reproducible

Planned primary window families:
- `prewalk_standing`
- `walk_task`

Planned deferred window families:
- `clip_full`
- `clip_nonlocomotory`
- `clip_stationary_strict`

Deliverable:
- one window-definition table per subject/session

### Phase 4: Feature Extraction

Goal:
- compute transparent accelerometer summaries before attempting more model-heavy analyses

Candidate primary non-locomotory features from `prewalk_standing`:
- magnitude mean
- magnitude median
- RMS magnitude
- variance
- low-percentile and high-percentile envelope
- immobility fraction

Candidate locomotion-vigor features:
- walking-window mean magnitude
- walking-window RMS magnitude
- cadence or dominant frequency
- step-event rate, if stable enough

Important note:
- derived features should be named so that the exact signal treatment is obvious.
- For example:
  - `accMag_rms_clip_nonlocomotory`
  - not a vague label like `motionScore1`

### Phase 5: Statistical Design

Goal:
- answer the scientific questions without collapsing repeated-measures structure incorrectly

Planned analysis split:

1. Pre-locomotion standing motion -> locomotion vigor
- likely unit:
  - subject/session
- basic question:
  - do participants with larger pre-walk standing accelerometer magnitude also show more vigorous walking?

2. Pre-locomotion standing motion -> emotional descriptors
- likely unit:
  - subject x walking episode or subject/session, depending on available labels
- basic question:
  - within and across subjects, does pre-walk standing accelerometer magnitude differ systematically with emotional descriptors available around the walking context?

Important caution:
- this second question is only valid if the dataset provides emotion labels that can be linked meaningfully to the pre-walk standing periods.
- This linkage must be verified from the MAT schema before committing to the analysis.

Preferred model family:
- repeated-measures or mixed-effects models with subject as a grouping factor

Why:
- pooled correlations alone would be too fragile and too easy to misread

### Phase 6: Sensitivity Analyses

Goal:
- test whether conclusions depend heavily on one arbitrary threshold or one narrow definition

Planned sensitivity checks:
- shorter vs longer pre-walk standing windows
- looser vs stricter standing-only thresholds
- per-subject aggregation vs repeated-episode mixed model
- alternative accelerometer magnitude summaries
- later comparison against seated clip-viewing windows, if needed

## 6) Planned Outputs

The first useful outputs should be:

1. a subject/session manifest with QC annotations
2. labeled accelerometer traces for a few example sessions
3. a table of candidate analysis windows
4. a first feature table with transparent column names
5. compact plots for:
   - non-locomotory motion vs locomotion vigor
   - non-locomotory motion vs emotional descriptors

Important distinction:
- some figures will be explanatory and QC-oriented
- others will be inferential summaries
- these should not be mixed casually

## 7) Immediate Next Step After Download Completes

Do not start with modeling.

Start with:
1. inspect MAT schema
2. inspect `meta.csv`
3. build one manifest
4. create 2-3 labeled traces
5. review the operational definitions with the user before feature extraction

## 8) Open Questions

1. Which emotional target is primary:
   - content labels
   - self-reports
   - or both equally?
2. How exactly should the pre-walk standing window be defined:
   - fixed number of seconds before walk onset,
   - all standing frames since the instruction to walk,
   - or another rule tied to event markers?
3. Should talking and drinking always remain excluded, even in later exploratory analyses?
4. Should locomotion vigor be summarized per walking task only, or also from spontaneous locomotion elsewhere in the session?
5. Which trace layout will be easiest for joint review with the user?

## 9) Current Working Decision

Until the MAT schema is inspected, the safest stance is:

- treat the dataset as synchronized but not yet operationally mapped,
- avoid premature feature engineering,
- and make trace-based validation the gate before any statistical claim.

## 10) EmoWear MAT Package Inventory (Observed On Disk)

Downloaded location:
- `/Users/yoe/Documents/DATA/EmoWear_zenodo_10407279`

Extracted MAT location:
- `/Users/yoe/Documents/DATA/EmoWear_zenodo_10407279/mat_extracted`

Observed downloaded files:
- `mat.zip` (`~9.3G`)
- `meta.csv` (`~80K`)
- `questionnaire.csv` (`~7.7K`)

Observed extracted size:
- `~9.9G`

### Top-Level Structure

The extracted archive contains:
- one top-level `mat/` folder
- participant folders named like:
  - `01-9TZK`
  - `20-9V52`
  - `38-9W6A`

Observed participant count:
- `49` participant folders

Observed MAT file count:
- `192` `.mat` files total

Observed folder pattern:
- each participant folder contains exactly `4` MAT files

### Per-Participant File Pattern

For sampled participants, the file pattern is:
- `signals.mat`
- `markers.mat`
- `surveys.mat`
- `params.mat`

### Top-Level Variable Names Inside The MAT Files

Sampled participant:
- `01-9TZK`

Observed top-level variable names:
- `signals.mat` contains:
  - `signals` (`struct`)
- `markers.mat` contains:
  - `markers` (`struct`)
- `surveys.mat` contains:
  - `surveys` (`table`)
- `params.mat` contains:
  - `params`

### Observed Field Names

For sampled participant `01-9TZK`:

Observed `signals` fields:
- `e4`
- `bh3`

Observed `markers` fields:
- `unique`
- `phase1`
- `phase2`

Observed `params` fields:
- `device`
- `shift`
- `cf`

Observed `surveys` columns:
- `seq`
- `exp`
- `valence`
- `arousal`
- `dominance`
- `liking`
- `familiarity`

### Device Coverage Varies Across Participants

Additional sampled participants show that `signals` can include more than the
two devices seen in `01-9TZK`.

Observed examples:

- participant `20-9V52`:
  - `e4`
  - `bh3`
  - `front`
  - `back`

- participant `38-9W6A`:
  - `e4`
  - `bh3`
  - `front`
  - `back`
  - `water`

Current interpretation:
- the `signals` struct likely contains one field per available recording device
- chest / body-worn accelerometer content relevant to the current project may
  live in:
  - `bh3`
  - `front`
  - `back`
  - and possibly `water` depending on task/setup
- exact channel names still need to be inspected inside those device-level structs

### External CSV Files Already Confirm Useful Metadata

Observed `meta.csv` columns:
- `Code`
- `ID`
- `Sequence`
- `Experiment`
- `Empatica E4`
- `Zephyr BioHarness 3`
- `Front STb`
- `Back STb`
- `Water STb`
- `Notes`

Observed `meta.csv` utility:
- session-level missingness by device
- task/sequence annotations
- free-text notes such as incomplete walking

Observed `questionnaire.csv` columns include:
- demographic fields
- handedness
- vision
- education
- stimulant / substance use
- sleep
- alertness
- physical / psychiatric syndrome notes

### Immediate Consequences For The Accelerometer Plan

1. The dataset does contain usable self-report dimensions directly in the MAT package:
   - `valence`
   - `arousal`
   - `dominance`
   - plus `liking` and `familiarity`

2. Task/event segmentation is likely encoded through:
   - `markers`
   - and the `surveys.seq` / `surveys.exp` information

3. Device availability varies by participant, so the first manifest must include:
   - which device fields exist in `signals`
   - which devices are missing according to `meta.csv`

4. Before any feature extraction, the next schema-inspection step must answer:
   - what channel names exist inside `signals.bh3`, `signals.front`, `signals.back`, `signals.water`, and `signals.e4`
   - what the time bases look like
   - how `markers.unique`, `markers.phase1`, and `markers.phase2` define task timing
   - whether walking onset can be localized precisely enough to define `prewalk_standing`

## 11) Nested Schema Inspection (Observed)

Additional MATLAB inspection was run on sampled participants:
- `01-9TZK`
- `20-9V52`
- `38-9W6A`

### Signals: Device-Level Structure

Observed `signals.e4` fields:
- `acc`
- `bvp`
- `eda`
- `skt`
- `hr`
- `ibi`

Observed `signals.bh3` fields:
- `acc`
- `ecg`
- `rr`
- `bb`
- `rsp`
- `br`
- `hr`
- `hr_confidence`

Observed `signals.front` fields:
- `gyro`
- `acc`

Observed `signals.back` fields:
- `gyro`
- `acc`

Observed `signals.water` fields:
- `gyro`
- `acc`

### Accelerometer Table Layout

Observed `e4.acc` columns:
- `timestamp`
- `x`
- `y`
- `z`

Observed `bh3.acc` columns:
- `timestamp`
- `x`
- `y`
- `z`

Observed `front.acc`, `back.acc`, and `water.acc` columns:
- `timestamp`
- `x1_lis2dw12`
- `y1_lis2dw12`
- `z1_lis2dw12`
- `x2_lis3dhh`
- `y2_lis3dhh`
- `z2_lis3dhh`
- `x3_lsm6dsox`
- `y3_lsm6dsox`
- `z3_lsm6dsox`

Observed `front.gyro`, `back.gyro`, and `water.gyro` columns:
- `timestamp`
- `x`
- `y`
- `z`

Current interpretation:
- `e4` and `bh3` provide a straightforward single-triad accelerometer format.
- `front`, `back`, and `water` appear to contain multiple onboard accelerometer chips or processed sensor channels in parallel.
- For the first-pass analysis, `bh3.acc` is currently the cleanest candidate because:
  - it is present in all sampled participants,
  - it has a simple `timestamp, x, y, z` structure,
  - it is paired with other body-signal channels in the same device package.

This is still a provisional decision.
- It must be checked across all participants before we commit to `bh3` as the primary source.

### Time Base Observations

Observed accelerometer timestamps are relative numeric values rather than obvious wall-clock datetimes.

Sample values:
- `e4.acc.timestamp` starts near `-523.86`
- `bh3.acc.timestamp` starts near `-568.63`
- `front.acc.timestamp` starts near `-554.44`

Current interpretation:
- timestamps are likely session-relative seconds aligned to a common synchronized reference
- negative values suggest the task/event reference point occurs after recording start

This is useful:
- it implies the package may already be aligned enough to compare device streams directly against marker times

### Markers: Event-Timing Structure

Observed `markers.unique` columns:
- `eoj`
- `baselineB`
- `baselineE`
- `pauseB`
- `pauseE`
- `vadB`
- `vadE`

Observed `markers.phase2` columns:
- `seq`
- `exp`
- `newExp`
- `preB`
- `vidB`
- `postB`
- `surveyB`
- `walkB`
- `walkE`
- `walkDetect`
- `walkFinish`

Observed `markers.phase1` behavior:
- for one participant it was a numeric value
- for another participant it was a table with:
  - `sentence`
  - `onset`
  - `offset`

Current interpretation:
- `phase1` appears related to another task block and is not currently the primary target
- `phase2` is the main task table for the current planned analysis

### Why `prewalk_standing` Looks Feasible

The presence of these `phase2` fields is especially important:
- `preB`
- `walkB`
- `walkE`
- `walkDetect`
- `walkFinish`

This strongly suggests that we can define candidate standing windows such as:
- from `preB` to `walkB`
- from `preB` to `walkDetect`
- from `walkDetect - k` seconds to `walkDetect`
- from `walkB - k` seconds to `walkB`

Current recommendation:
- treat the exact pre-walk standing definition as a decision to be validated on traces
- but the data package appears to support that decision directly

### Survey Table Implication

Observed `surveys` table size for sampled participant `38-9W6A`:
- `38 x 7`

Observed columns:
- `seq`
- `exp`
- `valence`
- `arousal`
- `dominance`
- `liking`
- `familiarity`

Current interpretation:
- the self-report rows can likely be joined directly to `markers.phase2` through:
  - `seq`
  - and probably `exp`

This is promising for the later question about emotional descriptors.

### Immediate Analysis Consequences

The current schema pass supports the following next-step plan:

1. Build a participant-level inventory of available accelerometer devices.
2. Check whether `bh3.acc` exists broadly enough to serve as the primary first-pass source.
3. Plot one or more traces with:
   - `bh3` accelerometer magnitude,
   - `walkB`,
   - `walkDetect`,
   - `walkE`,
   - and candidate `prewalk_standing` windows.
4. Compare:
   - `preB -> walkB`
   - `preB -> walkDetect`
   - short fixed windows before walking onset
5. Only after that choose the operational window for the main analysis.

## 8) 2026-04-12 Evening Session Summary

### Browser And Schema Work Completed

- Built an interactive EmoWear accelerometer browser in MATLAB:
  - `scripts/launch_emowear_accel_browser.m`
  - `CODE/PLOTTING/gui/launchEmoWearAccelBrowser.m`
  - `CODE/APPS/launchEmoWearAccelBrowserApp.m`
- Browser now supports:
  - participant / device / signal / sequence selection,
  - standard MATLAB toolbar tools,
  - persistent control selections when switching subjects,
  - pre-walk and walking zoom buttons,
  - marker overlays,
  - regime shading overlays.
- Device interpretation used in the browser:
  - `bh3` = chest Zephyr BioHarness 3,
  - `e4` = Empatica E4,
  - `front`, `back`, `water` = ST SensorTile streams.

### Important Signal-Treatment Revision

- The original browser-side "dynamic magnitude" was first implemented as:
  - full-session axis median centering,
  - then Euclidean norm.
- This was rejected after trace inspection because posture/orientation changes produced artificial sustained jumps.
- Current browser-side and analysis-side dynamic-motion proxy:
  - `0.5 s` rolling per-axis standard deviation,
  - combined as `sqrt(sd_x^2 + sd_y^2 + sd_z^2)`.

Interpretation:
- this is not physical gravity subtraction,
- it is a local motion-energy envelope,
- but it behaves far better than global recentering for the current purpose.

### Pre-Walk Low-Animation Regime

Implemented helper:
- `CODE/ANALYSIS/getLowAnimationFramesFromMotionMagnitude.m`

Current low-animation definition:
- start from `motion < 40`
- fill high-motion interruptions of `<= 0.1 s`
- keep only low-motion runs lasting `>= 0.5 s`

Browser support:
- low-animation bouts are shaded green
- threshold line at `40`

Distribution work:
- pooled histogram of all pre-walk frame values:
  - `n = 888000`
  - median `22.19`
  - `p95 = 29.58`
  - `p98 = 35.80`
  - `p99 = 48.17`
- interpretation:
  - main bulk roughly `18-28`
  - upper tail emerges around `30-35`
  - `48+` is clearly extreme

### Walking / Sustained-Locomotion Regime

Implemented helper:
- `CODE/ANALYSIS/getContinuousWalkingFramesFromMotionMagnitude.m`

Current continuous-walking definition:
- start from `motion > 100`
- fill low-motion interruptions of `<= 0.25 s`
- keep only high-motion runs lasting `>= 1.0 s`

Browser support:
- sustained-walking bouts are shaded amber
- threshold line at `100`
- `Walk` button shows `walkB -> walkFinish`

Marker interpretation update:
- `walkFinish - walkE` over all trials:
  - `n = 1776`
  - median `6.014 s`
  - `p25 = 3.727 s`
  - `p75 = 8.593 s`
- current interpretation:
  - `walkE` marks the end of the main walking segment
  - `walkFinish` extends into the settling / post-walk tail

Walk-frame distribution:
- pooled histogram of all walk-frame dynamic values:
  - `n = 3383432`
  - `p10 = 70.14`
  - `p25 = 148.72`
  - median `209.42`
- interpretation:
  - clear low-valued component at roughly `15-40`
  - valley / transition region around `50-80`
  - main walking bulk rises well above that

### Correlation / Scatter Results After Regime Definition

Current comparison script:
- `scripts/run_emowear_regime_scatter_comparison.m`

Regime selections used in that comparison:
- pre-walk:
  - low-animation frames in `[walkB - 5 s, walkB)`
- walking:
  - sustained-walking frames in `[walkB, walkFinish]`

Mean retained fractions:
- pre-walk selected fraction: `0.987`
- walk selected fraction: `0.856`

Results:

1. `dynamic -> dynamic`
- pooled Pearson: `r = -0.171`, `p = 3.76e-13`
- pooled Spearman: `rho = -0.156`, `p = 4.31e-11`
- subject-level Pearson: `r = -0.254`, `p = 0.0818`

2. `raw -> raw`
- pooled Pearson: `r = 0.003`, `p = 0.896`
- subject-level Pearson: `r = -0.059`, `p = 0.693`

3. `dynamic -> raw`
- pooled Pearson: `r = -0.018`, `p = 0.443`
- subject-level Pearson: `r = -0.017`, `p = 0.911`

Current interpretation:
- the modest negative association survives only when locomotion vigor is defined in the dynamic domain
- once locomotion is summarized in the raw domain, the relation essentially disappears
- raw magnitude may preserve gait waveform shape visually, but it appears to compress vigor contrast numerically for this use

### Subject-Aware Visualization

Added:
- `scripts/plot_emowear_dynamic_to_dynamic_by_subject.m`

Output:
- subject-colored pooled episode scatter with subject centroids overlaid

Current reading:
- pooled negative relation is not obviously driven by a single subject
- there is visible within-subject spread plus subject-level cloud structure
- a subject-aware model is still needed before making strong predictive claims

### Current Best Working Formulation Of Question 1

Current operational version:
- "Does pre-walk low-animation dynamic motion magnitude predict subsequent locomotion vigor, where locomotion vigor is defined from sustained-walking dynamic motion?"

Current answer:
- there is a modest negative pooled association under the current regime definitions
- the sign persists at subject level but remains weaker / not conventionally significant

### Immediate Next Step

Defer more work on question 1 for now.

Next target:
- examine properties of the video clips / content,
- and ask whether clip qualities relate to:
  - low-animation pre-walk motion,
  - locomotion vigor,
  - or both.

Before that clip-quality analysis starts, we should preserve:
- exact regime definitions,
- exact dynamic-motion proxy,
- and the distinction between:
  - dynamic-envelope summaries,
  - raw waveform summaries.
