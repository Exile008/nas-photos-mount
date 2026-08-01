# Contributing

## Before opening an issue

- Search existing issues and read `README.md` plus `CONFIG.md`.
- Remove SMB passwords, panel tokens, public IP addresses, personal paths, and complete media listings.
- Include the device model, Android version, Magisk version, module version, and the smallest relevant log excerpt.

## Development workflow

1. Fork the repository and create a focused branch.
2. Keep runtime code compatible with `/system/bin/sh` on Android 10 unless the compatibility target changes explicitly.
3. Run the migration and syntax checks:

   ```bash
   bash -n build.sh tests/*.sh
   for script in customize.sh action.sh cgi-lib.sh compile-ignore.sh lib.sh mount-once.sh \
     refresh-capacity.sh remount.sh scan-new.sh service.sh start-web.sh uninstall.sh \
     unmount.sh watchdog.sh web/cgi-bin/*; do sh -n "$script"; done
   ./tests/test-clean-install.sh
   ./tests/test-legacy-migration.sh
   ```

4. Build and inspect the Magisk archive with `./build.sh` and `unzip -t dist/*.zip`.
5. Open a Pull Request describing the behavior change, compatibility impact, and checks run.

## Releases

Use semantic versions. Before tagging, update `module.prop`, `update.json`, and `CHANGELOG.md`. A `v*` tag triggers GitHub Actions to build the module and attach the ZIP plus SHA-256 file to a GitHub Release.
