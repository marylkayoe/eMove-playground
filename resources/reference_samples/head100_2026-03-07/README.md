# Reference Samples (First 100 Rows)

This folder stores small, fixed-size reference extracts from raw acquisition files for architecture and parser design.

## Purpose

- Preserve reproducible format examples without checking full raw datasets into the repo.
- Support schema, parsing, and synchronization design.
- Provide stable test fixtures for ingestion/QC utilities.

## Source And Copy Date

Copied on 2026-03-07 from:
- `/Users/yoe/Documents/DATA/HUMANMOCAP/emove_samples/mocap_head100.csv`
- `/Users/yoe/Documents/DATA/HUMANMOCAP/emove_samples/shimmer_head100.csv`
- `/Users/yoe/Documents/DATA/HUMANMOCAP/emove_samples/unitylog_head100.csv`
- `/Users/yoe/Documents/DATA/HUMANMOCAP/emove_samples/movesense_head100.csv`

## Files

1. `mocap_head100.csv`
- Vicon export sample (very wide CSV).
- Row 1 contains key-value metadata (capture frame rate, start time, units).
- Multi-row header follows; data rows begin after header block.
- Observed export/capture frame rate in sample metadata: `120 Hz`.

2. `shimmer_head100.csv`
- EDA/GSR sample.
- Starts with `"sep=,"` line, then column names, then units row.
- Data rows include formatted timestamps and conductance/resistance channels.
- Observed sample interval in first rows: about `20 ms` (`~50 Hz`).

3. `unitylog_head100.csv`
- Unity/Varjo log for one stimulus segment.
- Delimiter is semicolon (`;`).
- Contains eye-tracking and HMD fields (`GazeStatus`, pupil metrics, vectors, `SystemTime`).
- Numeric decimals in some fields use comma (for example `70,725`), and vector fields are string tuples.
- `CaptureTime` appears nanosecond-scale; first-row differences suggest about `5 ms` (`~200 Hz`).

4. `movesense_head100.csv`
- ECG sample with comment-style metadata lines starting with `#`.
- Header row appears after metadata block (`"Elapsed time","ECG"`).
- Data rows are elapsed-time seconds and ECG mV.
- First-row elapsed-time increments suggest about `5 ms` (`~200 Hz`).

## Usage Notes

- These files are format references, not complete recordings.
- Do not infer full-session quality from these extracts alone.
- Keep this folder immutable once architecture decisions are tied to it; add new dated folders for new fixtures.

