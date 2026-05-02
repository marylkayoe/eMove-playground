# Grant Handoff Note (2026-04-15)

This note is intended as a compact handoff for a separate grant-writing thread.
It summarizes the current motion-analysis results, what appears robust enough to
mention, what remains exploratory, and which figures/assets are most useful.

## 1) Project Question

Core question:
- can emotional state be characterized from human motion, especially in a
  low-animation / micromovement regime?

Practical framing that emerged from the figure work:
- overt movement is informative but potentially confounded by voluntary,
  strategic, or task-shaped expression
- low-animation motion may provide a complementary signal, potentially less
  dominated by obvious gross behavior

Important caution:
- current evidence does **not** justify the simple claim that micromovement is
  globally "better" than full movement
- the strongest defensible claim is more selective and anatomy-dependent

## 2) Most Important Empirical Takeaways

### A) FEAR is a strong special case

Across subjects, `FEAR` appears much more clearly separable than the other
emotion conditions.

Implication:
- it makes sense to treat `FEAR` separately in poster/grant figures rather than
  letting it dominate non-fear comparisons

Current descriptive body-map figure:
- [fear_summary_bodymap_red_displayrange_graylegs_20260329_211025](/Users/yoe/Documents/REPOS/eMove-playground/outputs/figures/fear_summary_bodymap_red_displayrange_graylegs_20260329_211025)

Interpretation:
- `FEAR` is globally distinctive enough that it risks overwhelming subtler
  non-fear differences if included naively in pooled summaries

### B) Non-fear structure is subtler and should be analyzed separately

Poster development converged on a cleaner non-fear approach:
- `DISGUST` vs other non-fear emotions
- `JOY` vs other non-fear emotions
- `SAD` vs other non-fear emotions

Current descriptive body-map figures:
- [disgust_summary_bodymap_green_displayrange_graylegs_20260329_211049](/Users/yoe/Documents/REPOS/eMove-playground/outputs/figures/disgust_summary_bodymap_green_displayrange_graylegs_20260329_211049)
- [joy_summary_bodymap_magenta_displayrange_graylegs_20260329_211107](/Users/yoe/Documents/REPOS/eMove-playground/outputs/figures/joy_summary_bodymap_magenta_displayrange_graylegs_20260329_211107)
- [sad_summary_bodymap_blue_displayrange_graylegs_20260329_211125](/Users/yoe/Documents/REPOS/eMove-playground/outputs/figures/sad_summary_bodymap_blue_displayrange_graylegs_20260329_211125)

Interpretation:
- `DISGUST`, `JOY`, and `SAD` each show some bodypart-specific distinguishability
- these non-fear effects are meaningfully weaker and more selective than FEAR

### C) Upper body matters more than legs

A recurring pattern across exploratory and descriptive passes:
- head / upper torso / lower torso / upper limbs carry most of the emotion-related signal
- legs contribute relatively little in the current motion-speed analyses

Poster convention adopted:
- legs are rendered in neutral gray in the body-map figures
- they are excluded from the color-scale calculation

This is a presentation decision, but it matches the current empirical pattern.

### D) There is evidence for regime-dependent reorganization, but it is selective

Exploratory work on full-motion vs micromovement suggested:
- the low-animation regime is **not** simply a lower-amplitude copy of overt movement
- some emotion relationships change across regimes
- the clearest such pattern looked disgust-centered and torso-weighted

Important caveat:
- the dramatic pooled reversal picture weakened under subject-aware checks
- the broad claim "many reversals everywhere" is too strong

The most defensible version is:
- some upper-body affective structure changes between full and low-animation regimes
- but the effect is selective, not universal

Relevant exploratory outputs:
- [regime_story_20260314_203008](/Users/yoe/Documents/REPOS/eMove-playground/outputs/figures/regime_story_20260314_203008)
- [reversal_stability_qc_20260315_083300](/Users/yoe/Documents/REPOS/eMove-playground/outputs/figures/reversal_stability_qc_20260315_083300)
- [stable_reversal_summary_20260315_083816](/Users/yoe/Documents/REPOS/eMove-playground/outputs/figures/stable_reversal_summary_20260315_083816)

For grant language, this should be framed as:
- preliminary evidence for regime-specific reorganization of emotion-related
  motion structure
- strongest in upper-body channels
- requiring confirmatory follow-up rather than treated as final proof

## 3) Best Current Figure Assets

### A) Analysis workflow explainer

Use when a grant needs a simple "how the analysis works" panel:
- [analysis_workflow_20260322/analysis_workflow_figure.png](/Users/yoe/Documents/REPOS/eMove-playground/outputs/figures/analysis_workflow_20260322/analysis_workflow_figure.png)

Purpose:
- explain continuous motion recording
- low-animation sample selection
- pooling by emotion
- distribution comparison
- mapping differences onto the body

### B) Single-subject example figure family

Best example subject from the current poster-development pass:
- `SC3001`

Useful folder:
- [disgust_subject_pack_20260315_124849_SC3001](/Users/yoe/Documents/REPOS/eMove-playground/outputs/figures/disgust_subject_pack_20260315_124849_SC3001)

Why this subject:
- cleanest conceptual example of a regime-dependent reversal pattern
- especially useful for showing the intuition before moving to pooled summaries

Caveat:
- this subject was chosen for clarity, not representativeness

### C) Pooled descriptive body maps

Best current poster-ready descriptive summaries:
- FEAR: [fear_summary_bodymap_red_displayrange_graylegs_20260329_211025/fear_summary_bodymap_red_displayrange_graylegs.png](/Users/yoe/Documents/REPOS/eMove-playground/outputs/figures/fear_summary_bodymap_red_displayrange_graylegs_20260329_211025/fear_summary_bodymap_red_displayrange_graylegs.png)
- DISGUST: [disgust_summary_bodymap_green_displayrange_graylegs_20260329_211049/disgust_summary_bodymap_green_displayrange_graylegs.png](/Users/yoe/Documents/REPOS/eMove-playground/outputs/figures/disgust_summary_bodymap_green_displayrange_graylegs_20260329_211049/disgust_summary_bodymap_green_displayrange_graylegs.png)
- JOY: [joy_summary_bodymap_magenta_displayrange_graylegs_20260329_211107/joy_summary_bodymap_magenta_displayrange_graylegs.png](/Users/yoe/Documents/REPOS/eMove-playground/outputs/figures/joy_summary_bodymap_magenta_displayrange_graylegs_20260329_211107/joy_summary_bodymap_magenta_displayrange_graylegs.png)
- SAD: [sad_summary_bodymap_blue_displayrange_graylegs_20260329_211125/sad_summary_bodymap_blue_displayrange_graylegs.png](/Users/yoe/Documents/REPOS/eMove-playground/outputs/figures/sad_summary_bodymap_blue_displayrange_graylegs_20260329_211125/sad_summary_bodymap_blue_displayrange_graylegs.png)

EPS versions exist in the same folders for Illustrator workflows.

## 4) Current Method Conventions That Matter

### A) Baseline normalization

Most current poster-facing summaries use baseline-normalized speed.

Operational rule:
- within each subject and bodypart, speed values are divided by that
  subject/bodypart baseline median

This matters for grant language because some current figures are intentionally
framed as baseline-relative rather than absolute-speed results.

### B) Micromovement regime

Important implementation caveat:
- the browser and some figure tools currently use the precomputed
  `speedArrayImmobile` arrays in `resultsCell`
- they do **not** recompute the low-animation regime live from a user-specified
  threshold

Therefore:
- micromovement figures should be described as using the **precomputed
  low-animation regime**
- not as arbitrary threshold sweeps unless the analysis was explicitly rerun

### C) Pooled browser views vs subject-aggregated reporting

The interactive browser can show pooled-across-subject distributions and KS
heatmaps.

But:
- those browser pooled views are exploratory sample-pooling views
- they are not identical to the main subject-aware reporting pipeline that:
  1. computes per-subject pairwise values
  2. then aggregates across subjects

That distinction matters when drafting precise claims.

## 5) Major Caveats To Carry Into The Grant

### A) No direct residual-vs-signal reassurance yet

An attempt was made to inspect Vicon triangulation residuals in the raw CSVs.

Current finding:
- the available Vicon CSV exports do not contain usable residual / reconstruction
  quality columns

Consequence:
- we cannot currently quantify micromovement magnitude relative to
  triangulation residual from the present exports alone

This is a real limitation if the grant wants to emphasize very low-amplitude
signals.

### B) Some figures are descriptive, not inferential

The body-map figures are best treated as:
- descriptive anatomical summaries
- useful for communication and hypothesis framing

They are not the same thing as:
- a full inferential model
- or a fully standardized effect-size atlas

### C) Color scales are optimized within figure, not across figure families

Current body-map convention:
- scale each figure to the displayed non-gray range of that target emotion
- keep the scale shared across the full and micromovement panels **within that figure**

Good for readability, but it means:
- FEAR, DISGUST, JOY, and SAD body maps should not be read as directly
  comparable in absolute magnitude from color alone

## 6) Suggested Grant Framing

The safest current narrative is something like:

"Preliminary analyses of full-body motion capture suggest that emotional state
is reflected not only in overt movement but also in a low-animation regime of
subtle motion. In current exploratory analyses, fear shows a globally strong
body-wide signature, whereas non-fear emotions show more selective
distinguishability concentrated in upper-body channels. These observations
motivate a larger confirmatory study aimed at quantifying where in the body and
under which motion regime affective information is most robustly expressed."

That framing is:
- ambitious enough for a grant
- but still honest about the current status of the evidence

## 7) What Another Project / Grant Thread Should Probably Do Next

If this note is handed to another Codex instance working on a grant, the next
useful tasks would be:

1. translate these results into grant-ready claims with explicit caveat language
2. decide which of the current figures are:
   - explanatory
   - descriptive
   - inferential
3. build one coherent "figure story" from:
   - analysis workflow explainer
   - one single-subject example
   - one FEAR summary body map
   - one non-fear summary body map
4. avoid overclaiming the reversal/regime-reorganization results unless the
   grant text clearly labels them as preliminary/exploratory

## 8) Short Version

If only one paragraph can be passed on:

- FEAR is the clearest and most globally distinctive emotion in the current motion data.
- Non-fear emotions (`DISGUST`, `JOY`, `SAD`) are weaker and more selective, with most useful signal in head/torso/upper-body channels rather than legs.
- There is preliminary evidence that the low-animation regime is not simply a weaker copy of overt motion, but the strongest version of that claim remains exploratory.
- Current poster-ready figures are descriptive and useful for communication, especially the body maps and the single-subject example, but residual-vs-signal QC and fully confirmatory subject-aware analyses remain important future steps.
