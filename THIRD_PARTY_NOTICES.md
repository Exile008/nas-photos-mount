# Third-party notices

The Magisk release ZIP contains or downloads the following third-party components:

| Component | Version | License | Source |
| --- | --- | --- | --- |
| rclone | 1.75.0 | MIT | https://github.com/rclone/rclone |
| Apache ECharts | 5.6.0 | Apache-2.0 | https://github.com/apache/echarts |
| Lucide | 0.468.0 | ISC | https://github.com/lucide-icons/lucide |
| fusermount | 2.9.9 | GPL-2.0 | https://github.com/libfuse/libfuse |
| libandroid-support | 29 | Apache-2.0 and MIT | https://github.com/termux/libandroid-support |

`rclone` is not committed to this repository. `build.sh` downloads the pinned official
Linux arm64 archive and verifies its SHA-256 before packaging it. The small Android
compatibility binaries are kept under `vendor/arm64-v8a/` with their checksums in
`vendor/arm64-v8a/SHA256SUMS`.
