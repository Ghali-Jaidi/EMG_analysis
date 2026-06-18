# Archived Documentation

This folder contains historical project documentation and deprecated analysis approaches. 

## Files

**Purpose:** Preserve project history and rationale for design decisions without cluttering the main codebase.

## References

See parent folder (`Code/`) for current documentation:
- `README.md` – Project overview
- `INDEX.md` – Project index and navigation

See module-specific README files for technical details:
- `config/README.md` – Central parameters (`default_emg_parameters`) + GUI
- `preprocessing/README.md` – Preprocessing pipeline (`preprocess_and_label`, `snr_emg`)
- `utilities/README.md` – Filtering, masking and artifact-removal helpers
- `detection/README.md` – Spasm classification and stim ON/OFF analysis
- `analysis/README.md` – Frequency / spectral workflows
- `visualization/README.md` – Plotting functions

## Accessing Archived Information

If you need historical context about deprecated approaches:
1. Check the module README that would have used the deprecated code
2. Review git history: `git log --oneline -- <filename>`
3. Read archived markdown files in this directory (if available)

---

**Last updated:** 2026-05-11
