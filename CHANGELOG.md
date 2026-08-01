# Changelog

## 3.3.0 - 2026-08-02

- Replace the temporary unmount action with a persistent per-source pause/resume mount control.
- Add an optional per-source Live Photo filter that hides a MOV only when a same-folder, same-name HEIC exists.
- Show indexed item counts and sizes without exposing the internal MediaStore registration queue in the management panel.

## 3.2.0 - 2026-08-01

- Add an in-panel Chinese/English switch with persistent language selection.
- Add English README and configuration documentation with language links on the project home page.
- Allow per-source automatic scan intervals as short as one minute.

## 3.1.0 - 2026-08-01

- Add a responsive management panel with collapsible SMB and per-source settings.
- Add multiple independently configured SMB source folders.
- Add per-source Syncthing-style ignore rules, scan intervals, and batch sizes.
- Preserve per-source media scan history across restarts to avoid resubmitting unchanged files.
- Add NAS capacity and per-source indexed-size charts with offline ECharts assets.
- Add reproducible Magisk ZIP builds and GitHub tag-based releases.
- Keep clean installations empty instead of creating a sample NAS source.
