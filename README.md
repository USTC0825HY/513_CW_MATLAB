# MATLAB Code

This directory is the consolidated MATLAB/Python analysis repository. It also
contains shared utilities under `tools/` and migration/validation records
under `catalog/`.

## Main contents

- `laser_analysis`: main analysis entry point.
- `project_analysis/gs_delay_20260730`: GS/delay-driver analysis scripts and retained source history.
- `513DIANXING_analysis`: 513 test-dianxing analysis workspace.
- `tools/`: shared utilities and validation scripts.
- `catalog/`: migration records and source inventories.

Raw measurements and generated analysis outputs remain outside Git according
to `.gitignore`; stable source manifests and artifact hashes are retained.

The repository was consolidated from existing MATLAB repositories while
preserving their histories under `refs/archive/`.
