# Readability And Review Conventions

This project prioritizes transparent, student-friendly MATLAB code.

## Required style

- Every public function should include:
  - Purpose (one sentence)
  - Inputs (shape/type assumptions)
  - Outputs
  - Side effects (file I/O, warnings, plots)
- Use clear names (`videoIDs`, `frameRange`, `markerGroupNames`) over abbreviations.
- Add comments only where they explain intent or non-obvious decisions.

## Review checklist

- Can a first-time reader follow the function top-to-bottom?
- Are assumptions explicit (time units, frame units, naming conventions)?
- Are failure modes explained via warnings/errors?
- Is plotting code separated from metric computation where possible?

## Approval boundary

Any change that alters computed values requires explicit project-owner approval.
Examples:
- speed calculations
- smoothing windows
- immobility thresholds
- PSD band definitions
- statistical distance formulas

