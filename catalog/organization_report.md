# Code Organization Report

Date: 2026-08-07

## Result

- Central code root: `F:\01_Laser\code`
- Baseline assets: 30,953 files, 21,847,900,164 bytes
- Move verification: 30,953 SHA-256 matches
- Missing, overwritten, size-mismatched, or hash-mismatched files: 0
- Original root-level `MATLAB`, `.Xil`, and `202607_上海_电2\logic` locations are no longer used.
- A final workspace-wide scan found three residual code packages. They were moved intact to:
  - `fpga/legacy/unclassified_drive_pang`
  - `fpga/releases/unclassified_error_detection_laser_drive_20260801`
  - `matlab/legacy/gs_delay_data_and_examples`
- The three residual packages contain 92 files and 1,086,651,938 bytes. Their
  SHA-256 values are recorded in `residual_package_hash_manifest.csv`; hash errors: 0.

## Path repairs

- Updated the embedded `Path` attribute in all 12 Vivado `.xpr` files.
- Updated the MATLAB entry path and made `laser_test_paths` derive the code root from its own location.
- Updated the persistent `LASER_TEST_CODE_ROOT` and `LASER_TEST_REQUIREMENT_ROOT` user environment variables.
- Active MATLAB, Tcl, XPR, Markdown, Python, and PowerShell sources contain no references to the former code roots.
- Historical Vivado logs and generated hardware/session files are retained unchanged and may contain old paths.

## Validation

- MATLAB R2025b: 9 tests passed, 0 failed, 0 incomplete.
- Vivado 2018.3: 6 representative projects opened successfully in read-only mode, 0 failures.
- After the final CWJG internal-directory renames, both CWJG projects were opened again successfully, 0 failures.
- Git: all 4 detected repositories resolve correctly from their new locations.
- Firmware `top0726.bit` and `top0726.ltx` remain paired under `fpga/releases/20260714_top0726`.
- The unclassified 2026-08-01 firmware package also retains its paired
  `top.bit` and `top.ltx`, together with its XDC and original usage document.
- Workspace-wide code-extension audit: 0 logic/MATLAB files remain outside `code`.

## Directory naming

All directories under `code` use English or ASCII-safe tool naming. The two
unreferenced CWJG snapshot directories formerly named `20260331PDH修改` were
renamed to `pdh_update_20260331`. The final historical MATLAB example directory
was renamed to `data_and_examples`; no active script referenced its former name.

## Preservation notes

The MATLAB, qualification FPGA, and PDH repositories already contained uncommitted
changes before the move. They were moved as complete repositories and were not reset
or committed. Current status is recorded in `git_status_after_move.txt`.
