# eMove Analysis Project

## Project Overview
This repository is dedicated to analyzing movement signatures in motion capture (MoCap) data that correlate with the emotional content of videos displayed through a VR headset. The project is a collaborative effort between Yoe and Simo.

## Repository Structure
- `RAWDATA/`: Directory for raw data files (excluded from version control).
- Under `RAWDATA/` there are subfolders for different types of data:
  - `MOCAP/`: motion capture data files.
  - `EDA/`: electrodermal activity data files.
  - `HR/`: heart rate data files.
  - `STIMVIDEOS/`: stimulus videos shown during data collection.
  - `UNITYLOGS/`: Unity logs (including timing and possible eye-tracking related data).
- `CODE/`: MATLAB code for ingestion, analysis, and plotting.

## Quick Pipeline
1. Organize/assign raw files by subject and modality.
2. Build per-subject `trialData` MAT files from mocap + Unity timing.
3. Run batch motion metrics.
4. Produce aggregate summaries and plots.

See [CODE_INDEX.md](CODE_INDEX.md) for a file-by-file map.

## Readability And Editing Policy
- Code should be student-readable: clear names, explicit assumptions, and comments for non-obvious logic.
- Any change that affects computed values (speed, spectral features, thresholds, statistics) requires explicit owner approval before implementation.

Detailed conventions are in [CONTRIBUTING_READABILITY.md](CONTRIBUTING_READABILITY.md).

## Notes
- Ensure all raw data files are placed in `RAWDATA/`.
- `RAWDATA/` is excluded from version control to avoid issues with large files.

---

*Last updated: March 5, 2026*
