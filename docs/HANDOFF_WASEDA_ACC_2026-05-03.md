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
- condition-split CDF figures:
  - `scripts/make_waseda_departure_metric_cdfs.m`
- metric-vs-time scatter figures:
  - `scripts/make_waseda_event_metric_scatter_vs_time.m`

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

Current best detector framing in this repository:

- clean the dynamic envelope first
- blank clear artifact peaks (`env >= 0.5`) in the displayed envelope
- interpolate through those peaks for stable-band estimation and event finding
- treat accepted events as compound quiet-state departures rather than local
  derivative bursts
- inspect durations directly in the zoomable figures using event-span overlays

Interpretation boundary:

- departures may reflect posture correction, discomfort, task drift, or other
  regulation-related adjustments
- that ambiguity is acceptable at this stage
- the useful output is a proposed phasic sparse-ACC pattern to test in
  better-controlled experiments

## Frequency-Space Follow-Up

The user later noticed a clear oscillatory baseline in the envelope plots and
asked for frequency-space inspection before further detector changes. That
shifted the continuation from pure event-threshold tuning to carrier analysis.

Current read from the raw ACC spectra:

- the periodic structure is already present in the raw signal
- `sub4` is materially different from the other subjects
- `sub2` is comparatively broadband / less carrier-dominated
- longer rolling-SD windows suppress the peaky behavior in several windows,
  but not uniformly

The working interpretation should stay cautious:

- the oscillation is nuisance for event calling regardless of its origin
- but it remains a signal worth returning to later
- any suppression should be tested as a preprocessing choice, not treated as
  an implicit truth about the physiology

The likely next experiment is a comparison between:

- the current envelope
- a slower envelope
- a raw-signal band-stop or notch candidate around the carrier

The raw carrier summary suggests the same caveat:

- `sub1` often sits around `0.5-0.7 Hz`
- `sub3` often sits around `~1.0-1.1 Hz`
- `sub4` shifts between `~0.6 Hz` and `~1.2 Hz`
- `sub2` is less obviously dominated by a single carrier

So the best working stop-band is probably not a single universal notch.
The more realistic candidate is a window-specific or subject-specific
suppression centered somewhere in the broader `0.5-1.2 Hz` neighborhood,
tested only as preprocessing and not promoted as a final signal claim.

The user then paused the filtering branch and asked to focus on short
primitive-event shape instead.

That next branch should be preserved here as:

- use the current event table as provisional
- focus on the short-duration mode around `~0.5 s`
- compare normalized short-event shapes across subjects
- compare those shapes between work and video conditions

## Current Quantitative Hints

These values are exploratory orientation only, not claim-grade results:

- pooled strict-departure median inter-event interval:
  - desk: roughly `6.5 s`
  - video: roughly `4.2 s`
- strict-screened departure-shape medians:
  - pooled duration median: `1.706 s`
  - pooled amplitude above baseline median: `0.005`
  - pooled return-to-baseline median: `0.174 s`
- current condition-split strict medians:
  - desk duration median: `2.285 s`
  - video duration median: `1.501 s`
  - desk amplitude median: `0.0073`
  - video amplitude median: `0.0029`
  - desk return median: `0.270 s`
  - video return median: `0.127 s`
- current visual working hint:
  - a dense short-duration mode appears to sit roughly around `0.3-0.6 s`
  - longer accepted events may often be compound events built from such
    shorter subelements

## Important Methodological Lessons

The separate thread already clarified several dead ends and framing changes:

- the Waseda data are preliminary and likely not block-identical across
  participants
- raw dense event detection produced too many tiny events to be useful by
  itself
- the productive shift was from "detect low-animation regime" to
  "characterize quiet-state departures and drift"
- histogram/distribution displays became interpretable only after:
  - artifact screening,
  - compound-event treatment,
  - clipped comparison views,
  - and left-end zoom insets

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

Current branch after the oscillation discussion:

- stop trying to filter the oscillation out for now
- keep the carrier as a later signal to track, not something to forget
- focus next on short primitive-event waveform shape
- compare fixed-time raw shapes and amplitude-normalized shapes across
  subjects and work/video conditions

Current correction after the event-overlay pass:

- use detector event times directly
- stack event waveforms by subject and condition
- compare recording-level averages for desk and video
- exclude saturated events with `peak_env >= 0.45`
- extend the recovery window to `10 s` so return-to-baseline is visible
