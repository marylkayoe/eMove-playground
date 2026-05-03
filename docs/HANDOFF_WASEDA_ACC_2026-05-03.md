# Waseda ACC Handoff (Imported Context, 2026-05-03)

This note captures the current state of the Waseda accelerometer work from the
separate collaboration thread so that this repository carries the same working
context even though the exploratory scripts and figure outputs live elsewhere.

Source handoff read on 2026-05-03:

- `/Users/yoe/Documents/REPOS/eMove-Collaboration/private/yoe_codex/analysis_thread_handoff_waseda_2026-05-03.md`

## Scope

This is a context-import note, not a claim that the full Waseda analysis code
or generated outputs have been migrated into this repository.

Current repository status:

- the Waseda exploratory scripts referenced in the source handoff live in the
  separate collaboration repository
- the promoted Waseda figures referenced in the source handoff also live in
  the separate collaboration repository
- this repository now carries the scientific state and interpretation boundary
  as documentation so that future work here does not lose that progress
- this repository also now carries a MATLAB-first continuation layer for the
  same work

## Current Local MATLAB Entry Points

Tracked local files:

- manifest:
  - `resources/waseda_acc/dataset_manifest.json`
- signal feature helper:
  - `CODE/ANALYSIS/computeWasedaDynamicMagnitude.m`
- quiet-dynamics probe:
  - `scripts/run_waseda_quiet_dynamics_probe.m`
- candidate-pattern summary figure:
  - `scripts/make_waseda_candidate_pattern_summary.m`
- focused departure figure set:
  - `scripts/make_waseda_departure_figure_set.m`

Current scratch outputs from the MATLAB port:

- `scratch/waseda_acc_matlab/quiet_dynamics_probe/`
- `scratch/waseda_acc_matlab/summary/`
- `scratch/waseda_acc_matlab/figure_set/`

These outputs are reproducible and should remain scratch/local unless the user
explicitly asks to promote a figure or derived table.

## Current Scientific Read

The current Waseda read should remain in candidate-pattern /
protocol-development space only.

Do not describe the present Waseda results as validated evidence for:

- attention
- boredom
- frustration
- sparse accelerometer low-animation regime detection

Current best working pattern:

- subject-specific quiet operating band
- transient departures from that band
- departure amplitude above local baseline
- recovery / return-to-baseline
- inter-event interval and short-gap clustering
- minute-scale drift across the block

Current best actual example from the separate thread:

- `sub1` video is the clearest drift candidate

Interpretation boundary:

- departures may reflect posture correction, discomfort, task drift, or other
  regulation-related adjustments
- that ambiguity is acceptable at this stage
- the useful output is a proposed phasic sparse-ACC pattern to test in
  better-controlled experiments

## Current Quantitative Hints

These values are exploratory orientation only, not claim-grade results:

- pooled strict-departure median inter-event interval:
  - desk: roughly `8.0 s`
  - video: roughly `4.7 s`
- strict-screened departure-shape medians:
  - duration: `0.367 s`
  - amplitude above baseline: `0.010`
  - return-to-baseline: `0.734 s`

## Important Methodological Lessons

The separate thread already clarified several dead ends and framing changes:

- the Waseda data are preliminary and likely not block-identical across
  participants
- raw dense event detection produced too many tiny events to be useful by
  itself
- the productive shift was from "detect low-animation regime" to
  "characterize quiet-state departures and drift"
- histogram/distribution displays became interpretable only after stricter
  screening and tighter plotting ranges

Two implementation fixes recorded in the source handoff should not be
forgotten if equivalent code is recreated here later:

- gross-motion vetoing in the Waseda instability probe became window-local
  rather than leaking outside-window motion into the current window
- quiet-signal example plotting was updated to key windows by full identity
  rather than `(subject_id, condition)` alone

## External Pointers

Promoted figures currently live in the separate collaboration repository:

- `/Users/yoe/Documents/REPOS/eMove-Collaboration/shared/analysis/waseda_acc_actual_candidate_patterns_2026-05-02.png`
- `/Users/yoe/Documents/REPOS/eMove-Collaboration/shared/analysis/waseda_acc_departure_shape_distributions_strict_2026-05-02.png`

Associated note:

- `/Users/yoe/Documents/REPOS/eMove-Collaboration/shared/analysis/waseda_acc_candidate_phasic_pattern_2026-05-02.md`

Representative source outputs worth mining there if needed:

- `/Users/yoe/Documents/REPOS/eMove-Collaboration/analyses/waseda_acc/outputs/quiet_signal_examples/actual_signal_sub1_video_drift_candidate.png`
- `/Users/yoe/Documents/REPOS/eMove-Collaboration/analyses/waseda_acc/outputs/quiet_signal_examples/actual_signal_candidate_event_gallery_artifact_screened.png`
- `/Users/yoe/Documents/REPOS/eMove-Collaboration/analyses/waseda_acc/outputs/quiet_signal_examples/interdeparture_intervals_desk_vs_video.png`
- `/Users/yoe/Documents/REPOS/eMove-Collaboration/analyses/waseda_acc/outputs/quiet_dynamics_probe/quiet_chest_burst_shape.png`
- `/Users/yoe/Documents/REPOS/eMove-Collaboration/analyses/waseda_acc/outputs/quiet_dynamics_probe/quiet_chest_epoch_trajectories.png`
- `/Users/yoe/Documents/REPOS/eMove-Collaboration/analyses/waseda_acc/outputs/quiet_dynamics_probe/quiet_chest_window_summary.png`
- `/Users/yoe/Documents/REPOS/eMove-Collaboration/analyses/waseda_acc/outputs/lar_instability_probe/regime_summary.csv`

Referenced external scripts:

- `/Users/yoe/Documents/REPOS/eMove-Collaboration/analyses/waseda_acc/scripts/run_lar_instability_probe.py`
- `/Users/yoe/Documents/REPOS/eMove-Collaboration/analyses/waseda_acc/scripts/run_quiet_dynamics_probe.py`
- `/Users/yoe/Documents/REPOS/eMove-Collaboration/analyses/waseda_acc/scripts/plot_quiet_signal_examples.py`
- `/Users/yoe/Documents/REPOS/eMove-Collaboration/analyses/waseda_acc/scripts/plot_lar_instability_summary.py`
- `/Users/yoe/Documents/REPOS/eMove-Collaboration/analyses/waseda_acc/scripts/plot_lar_instability_summary_svg.py`

## Practical Use In This Repo

If Waseda work continues from this repository, the safest continuation is:

1. treat this note as the current imported state
2. recreate only the specific logic that is actually needed here
3. keep exploratory outputs in `scratch/` or external local storage first
4. promote only compact curated notes, scripts, or figures after review

The main durable memory to preserve is:

- the best current Waseda story is quiet-state departures plus drift
- not validated boredom / attention / frustration inference
- and not simple dense event counting
