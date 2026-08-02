# NAS Photos Mount

[简体中文](README.md) | [English](README_EN.md)

[![Build Magisk module](https://github.com/Exile008/nas-photos-mount/actions/workflows/release.yml/badge.svg)](https://github.com/Exile008/nas-photos-mount/actions/workflows/release.yml)
[![Release](https://img.shields.io/github/v/release/Exile008/nas-photos-mount)](https://github.com/Exile008/nas-photos-mount/releases)
[![License](https://img.shields.io/github/license/Exile008/nas-photos-mount)](LICENSE)

在已 Root 的第一代 Pixel / Pixel XL 上，将群晖或其他 NAS 的多个 SMB 目录以只读方式挂载到 Android `DCIM`，交给系统媒体库和 Google Photos 读取。媒体按需从 NAS 传输，不需要先完整复制到手机闪存。

> [!WARNING]
> 本项目会以 Root 权限创建 FUSE 和 bind mount，属于实验性工具。错误配置、系统差异或强制断电都可能造成挂载异常。请保留 NAS 原始数据与独立备份，并在无人值守使用前充分测试。

## 功能

- 多个 SMB 来源，每个来源独立设置远程目录、本地相册名、扫描周期和批量大小。
- SMB 远程登录、目录浏览、连接测试与本地管理面板。
- Syncthing `.stignore` 风格的逐来源忽略规则，适合数 TB 大目录逐步放开扫描范围。
- 每个来源可独立暂停/恢复挂载，并可忽略 Live Photo 配对中的 `.MOV`，只向相册呈现静态图。
- 每个来源独立保存 `seen.tsv`，重启后不会重复向 Android 媒体库提交未变化文件。
- rclone 只读 FUSE 挂载，不把整个 NAS 目录缓存到手机。
- NAS 容量、来源索引数量与大小、挂载进程和日志监控。
- 管理面板右上角可即时切换简体中文和英文，并记住本机选择。
- 管理服务只监听 `127.0.0.1:8686`，接口使用随机令牌。

## 工作原理

```text
SMB / NAS
   -> rclone 只读 FUSE (/mnt/nas-photos/<source-id>)
   -> Android 全局挂载命名空间
   -> /storage/emulated/0/DCIM/<相册名>
   -> MediaScanner
   -> Google Photos
```

本项目的整体思路受到 [master-hax/pixel-backup-gang](https://github.com/master-hax/pixel-backup-gang) 启发，但使用 SMB、rclone、多来源配置和 Magisk WebUI 实现了不同的工作流。

## 兼容性

当前发布包仅包含 `arm64` 二进制。

- 已测试：Pixel（sailfish）、Android 10、Magisk、SELinux Enforcing。
- 预期可用：Pixel XL（marlin）上的相近系统环境。
- 其他设备或 Android 版本没有保证；Android 挂载命名空间和存储路径可能不同。
- 需要 NAS 开启 SMB，并允许手机通过局域网访问。

Google Photos 的免费存储政策由 Google 决定，本模块不修改 Google Photos，也不绕过账号或服务端限制。

## 安装

1. 从 [Releases](https://github.com/Exile008/nas-photos-mount/releases) 下载最新的 `nas-photos-mount-v*.zip`。
2. 在 Magisk 中进入“模块”，选择“从本地安装”，选中 ZIP。
3. 安装完成后重启手机。
4. 在 Magisk 模块列表中点击 `NAS Photos Mount` 的操作按钮，打开管理面板。
5. 展开“SMB 连接”，填写地址、端口、账号、密码和可选域，点击“测试并保存”。
6. 点击“添加目录”，浏览并选择 NAS 目录，设置手机相册名、扫描周期、Live Photo 过滤和忽略规则。
7. 在 Google Photos 中为对应的本地相册目录启用备份。

详细字段和忽略语法见 [CONFIG.md](CONFIG.md)，英文版见 [CONFIG_EN.md](CONFIG_EN.md)。

## 升级与卸载

直接在 Magisk 中安装新版 ZIP 并重启即可升级。运行配置、凭据和去重索引保存在 `/data/adb/nas_photos_mount/`，不会被模块覆盖。

移除 Magisk 模块会停止服务并卸载目录，但会保留上述数据目录，便于恢复。需要彻底清除时，请先确认没有待扫描或正在读取的文件，再手动删除该数据目录。

## 大目录建议

挂载 2 TB 不等于向手机写入 2 TB；文件内容只在应用读取时通过 SMB 传输。但首次扫描仍需要遍历元数据，目录中文件很多时会持续较长时间。

- 首次只放开较小的年份或月份目录。
- 每批登记数先使用 `100` 到 `500`。
- 观察 Google Photos、网络、温度与日志后再逐步扩大范围。
- 不需要的回收站、系统目录、旁车文件应放入忽略规则。
- 首次开启 Live Photo 过滤需要遍历当前可见文件名来识别 HEIC/MOV 配对；2 TB 目录可能需要较长时间。配对清单会被缓存，后续正常扫描发现变化时才更新并重新挂载。

## 去重边界

模块以“远程目录 + 本地相册名 + 相对路径 + 文件大小 + 修改时间”记录已经提交给 Android MediaScanner 的项目。记录相同的文件在程序或手机重启后不会重新提交；内容或元数据变化会重新登记。

这只避免重复提交媒体扫描，不代表 Google Photos 已成功上传，也不能替代 Google Photos 自身的云端去重和状态判断。

## 安全说明

- SMB 密码通过 `rclone obscure` 保存到 `/data/adb/nas_photos_mount/rclone.conf`，权限为 `0600`。
- `rclone obscure` 是可逆混淆，不是加密保险库；Root 应用仍可能读取凭据。
- 管理页面令牌保存在 `web.token`，同样使用 `0600`，HTTP 服务仅绑定手机回环地址。
- NAS 挂载使用 `--read-only`，但本模块本身拥有 Root 权限。
- 请为模块创建权限尽可能小的 NAS 只读账号。

不要在 Issue、日志截图或配置示例中提交密码、访问令牌、真实公网地址或完整目录清单。

## 从源码构建

需要 `bash`、`curl`、`unzip` 和 `zip`：

```bash
git clone https://github.com/Exile008/nas-photos-mount.git
cd nas-photos-mount
./build.sh
```

输出位于 `dist/`。构建脚本下载固定版本的官方 rclone arm64 归档，并在解压前校验 SHA-256。推送 `v*` 标签时，GitHub Actions 会自动构建 ZIP 并创建 Release。

开发机已有经过验证的 rclone 二进制时，也可以避免重复下载：

```bash
RCLONE_BIN=/absolute/path/to/rclone ./build.sh
```

## 开发

提交版本时需要同步更新：

- `module.prop` 中的 `version` 和 `versionCode`
- `update.json` 中的版本与 Release URL
- `CHANGELOG.md`
- 必要时更新 `tools/rclone.conf` 中锁定的 rclone 版本和归档 SHA-256

建议使用功能分支和 Pull Request；合并到 `main` 后创建版本标签，例如：

```bash
git tag -a v3.3.1 -m "NAS Photos Mount v3.3.1"
git push origin v3.3.1
```

## 许可证

项目代码使用 [MIT License](LICENSE)。发布包中的第三方组件及许可证见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
