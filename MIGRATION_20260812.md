# MATLAB repository consolidation

The former `laser_analysis`, nested `PDH_data_process`, and
`project_analysis/gs_delay_20260730/00_matlab` repositories were protected
with Git bundles before consolidation. Original `.git` metadata is stored in
`F:\\01_Laser\\git_migration_backup_20260812\\original_git_metadata`.

The shared `tools` and `catalog` directories are now part of this repository.
Raw measurements and generated analysis outputs remain on disk and are not
silently deleted by this migration.

The dBm converter source was retained, while its nested `.git` metadata was
moved to the migration backup to keep this repository as the only active Git
root under `code/matlab`.

Because `git-filter-repo` was unavailable in the managed runtime, the original
history is preserved in verified bundles and this consolidated repository uses
the current complete source tree as its baseline.
