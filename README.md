# MATLAB Code

This directory is the consolidated MATLAB/Python analysis repository. It also
contains shared utilities under `tools/` and migration/validation records
under `catalog/`.

- `laser_analysis`: main Git repository and standard entry point.
- `project_analysis/gs_delay_20260730`: GS/delay-driver analysis scripts and retained results.
- `legacy/gs_delay_data_and_examples`: historical ADC/DAC/noise/SFDR examples and data.

Start the main environment with:

```matlab
cd('F:\01_Laser\code\matlab\laser_analysis')
paths = setup_laser_analysis();
```

`laser_test_paths` derives the code root from its own location, so the main
repository no longer depends on its former root-level location.

Raw measurements and generated analysis outputs remain outside Git according
to `.gitignore`; stable source manifests and artifact hashes are retained.
