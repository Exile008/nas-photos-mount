# NAS Photos Mount

[简体中文](README.md) | [English](README_EN.md)

[![Build Magisk module](https://github.com/Exile008/nas-photos-mount/actions/workflows/release.yml/badge.svg)](https://github.com/Exile008/nas-photos-mount/actions/workflows/release.yml)
[![Release](https://img.shields.io/github/v/release/Exile008/nas-photos-mount)](https://github.com/Exile008/nas-photos-mount/releases)
[![License](https://img.shields.io/github/license/Exile008/nas-photos-mount)](LICENSE)

Mount multiple SMB folders from Synology or another NAS read-only into Android `DCIM` on a rooted first-generation Pixel or Pixel XL. Android MediaStore and Google Photos can read the mounted media on demand, without copying the entire library to the phone's internal storage first.

> [!WARNING]
> This experimental project creates FUSE and bind mounts with root privileges. Incorrect settings, device-specific behavior, or forced power loss can leave mounts in an inconsistent state. Keep the original NAS data and an independent backup, and test the complete workflow before unattended use.

## Features

- Multiple SMB sources with independent remote folders, local album names, scan intervals, and batch sizes.
- SMB authentication, remote folder browsing, connection tests, and a local management panel.
- Per-source Syncthing `.stignore`-style ignore rules for gradually scanning multi-terabyte libraries.
- Per-source pause/resume controls and an optional Live Photo filter that hides a paired `.MOV` while keeping the still image visible.
- A separate `seen.tsv` for each source, so unchanged files are not resubmitted to Android MediaScanner after an app or phone restart.
- Read-only rclone FUSE mounts that do not cache the complete NAS library on the phone.
- Monitoring for NAS capacity, indexed item counts and sizes, mount processes, and logs.
- Instant Chinese/English switching in the top-right corner of the management panel, with the preference stored locally.
- A management service bound only to `127.0.0.1:8686`, with a random token required by every API request.

## How It Works

```text
SMB / NAS
   -> rclone read-only FUSE (/mnt/nas-photos/<source-id>)
   -> Android global mount namespace
   -> /storage/emulated/0/DCIM/<album-name>
   -> MediaScanner
   -> Google Photos
```

The overall idea was inspired by [master-hax/pixel-backup-gang](https://github.com/master-hax/pixel-backup-gang), but this project uses SMB, rclone, multi-source configuration, and a Magisk WebUI to provide a different workflow.

## Compatibility

The current release includes an `arm64` binary only.

- Tested: Pixel (sailfish), Android 10, Magisk, and SELinux Enforcing.
- Expected to work: similar environments on Pixel XL (marlin).
- Other devices and Android versions are not guaranteed. Android mount namespaces and storage paths may differ.
- SMB must be enabled on the NAS, and the phone must be able to reach it over the local network.

Google controls the Google Photos storage policy. This module does not modify Google Photos or bypass account or server-side restrictions.

## Installation

1. Download the latest `nas-photos-mount-v*.zip` from [Releases](https://github.com/Exile008/nas-photos-mount/releases).
2. Open Magisk, go to Modules, choose Install from storage, and select the ZIP.
3. Restart the phone after installation.
4. Tap the action button for `NAS Photos Mount` in the Magisk module list to open the management panel.
5. Expand SMB connection, enter the address, port, username, password, and optional domain, then tap Test and save.
6. Tap Add folder, browse to a NAS folder, and configure the phone album name, scan interval, Live Photo filtering, and ignore rules.
7. Enable backup for the corresponding local album folder in Google Photos.

See [CONFIG_EN.md](CONFIG_EN.md) for detailed fields and ignore-rule syntax. The Chinese version is available in [CONFIG.md](CONFIG.md).

## Upgrade and Uninstall

Install a newer ZIP in Magisk and restart to upgrade. Runtime configuration, credentials, and dedupe indexes are stored in `/data/adb/nas_photos_mount/` and are not overwritten by the module.

Removing the Magisk module stops the service and unmounts its folders, but preserves that data directory for recovery. To remove it completely, first verify that no scan is pending and no mounted file is being read, then delete the data directory manually.

## Recommendations for Large Libraries

Mounting a 2 TB folder does not write 2 TB to the phone. File contents travel over SMB only when an application reads them. The initial scan still has to traverse metadata and can take a long time when a folder contains many files.

- Start by allowing only a small year or month range.
- Use a registration batch size between `100` and `500` initially.
- Watch Google Photos, network usage, device temperature, and logs before gradually expanding the range.
- Put recycle bins, system folders, and sidecar files that are not needed into the ignore rules.
- The first time Live Photo filtering is enabled, the module must traverse visible file names to identify HEIC/MOV pairs. This can take a long time for a 2 TB folder. The pair list is cached and is refreshed only when later scans find changes.

## Deduplication Boundary

For each submitted item, the module records the remote folder, local album name, relative path, file size, and modification time. A file with the same record is not resubmitted after the program or phone restarts. A content or metadata change causes the file to be registered again.

This prevents duplicate MediaScanner submissions. It does not prove that Google Photos uploaded the file successfully, and it does not replace Google Photos cloud-side deduplication or status tracking.

## Security

- SMB passwords are stored with `rclone obscure` in `/data/adb/nas_photos_mount/rclone.conf`, with file mode `0600`.
- `rclone obscure` is reversible obfuscation, not an encrypted vault. Other root applications may still read the credentials.
- The management page token is stored in `web.token` with mode `0600`, and the HTTP service binds only to the phone's loopback address.
- NAS mounts use `--read-only`, but the module itself runs with root privileges.
- Create a dedicated NAS account with the smallest practical read-only permission set.

Do not post passwords, access tokens, real public addresses, or a complete private folder inventory in issues, screenshots, or logs.

## Build from Source

The build requires `bash`, `curl`, `unzip`, and `zip`:

```bash
git clone https://github.com/Exile008/nas-photos-mount.git
cd nas-photos-mount
./build.sh
```

Output is written to `dist/`. The build script downloads a pinned official rclone arm64 archive and verifies its SHA-256 before extraction. Pushing a `v*` tag makes GitHub Actions build the ZIP and create a Release automatically.

When a verified rclone binary is already available on the development machine, avoid downloading it again with:

```bash
RCLONE_BIN=/absolute/path/to/rclone ./build.sh
```

## Development

Keep these files in sync when publishing a version:

- `version` and `versionCode` in `module.prop`
- Version and Release URL in `update.json`
- `CHANGELOG.md`
- The pinned rclone version and archive SHA-256 in `tools/rclone.conf`, when needed

Use a feature branch and pull request where practical. After merging into `main`, create a version tag such as:

```bash
git tag -a v3.3.1 -m "NAS Photos Mount v3.3.1"
git push origin v3.3.1
```

## License

Project code is distributed under the [MIT License](LICENSE). Third-party components included in release archives and their licenses are listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
