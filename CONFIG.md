# NAS Photos Mount v3 配置说明

[简体中文](CONFIG.md) | [English](CONFIG_EN.md)

## 打开管理面板

在 Magisk 模块列表中点击 `NAS Photos Mount` 的“操作”按钮。面板只监听手机本机的 `127.0.0.1:8686`，所有接口都需要模块生成的随机令牌。

可使用右上角语言控件切换中文和英文，选择会保存在管理面板的本地浏览器存储中。

## SMB 登录

在“SMB 登录”中填写 NAS 地址、端口、账号、密码和可选域，然后点击“测试并保存连接”。模块只有在能够列出 SMB 根目录时才会保存新配置。

- 地址填写主机名或 IP，例如 `192.168.1.10`，不要包含 `smb://`。
- SMB 默认端口为 `445`。
- 已保存密码时，密码框留空表示继续使用原密码。
- 密码经 `rclone obscure` 混淆后保存在 `/data/adb/nas_photos_mount/rclone.conf`，文件权限为 `0600`；管理接口不会回显密码或混淆值。
- 修改连接后，所有已启用来源会自动重新挂载。

## 添加多个待扫描目录

点击“添加目录”创建来源，然后用“浏览”从远程 SMB 目录中选择路径。每个来源独立保存以下配置：

- `NAS 目录`：使用 `共享名/子目录`，例如 `photo/example`。
- `手机相册目录名`：映射到 `/storage/emulated/0/DCIM/<名称>`；不同来源不能使用相同名称。
- `启用来源`：关闭后保留配置和去重记录，但卸载该来源。
- `自动扫描`：按该来源自己的周期查找新增或变化文件。
- `扫描间隔`：15 到 10080 分钟。
- `每批登记数`：1 到 5000。大目录建议先设为 100 到 500，观察 Google Photos 后再提高。
- `忽略规则`：只作用于当前来源。

最多可保存 32 个来源。每个来源分别挂载到 `/mnt/nas-photos/<source-id>`，再只读绑定到对应的 `DCIM` 相册目录。移除来源会先卸载，再将配置和去重状态归档到 `/data/adb/nas_photos_mount/deleted-sources/`。

## 大目录与 2 TB 内容

挂载不会把整个 NAS 目录下载到手机，文件在 Google Photos 或媒体服务读取时才通过 SMB 按需传输。首次扫描仍需遍历目录元数据；文件非常多时可能耗时较长。

建议先配置忽略规则，将扫描范围缩小，再逐步放开目录。状态面板会显示每个来源的文件数、已索引大小、待登记数、扫描状态和上次扫描时间，也会显示 NAS 总容量和挂载进程状态。

## 忽略规则

规则兼容本模块支持的 Syncthing `.stignore` 子集：

- 每行一个模式。
- `#` 开头的行是注释；需要匹配以 `#` 开头的目录时使用 `(?d)#目录名`。
- 支持 `*`、`?` 和字符范围，例如 `[0-9]`。
- `(?d)` 被接受；只读挂载不涉及删除，因此在本模块中表示忽略目录或文件。
- `(?i)` 让该来源的所有忽略匹配不区分大小写。

被忽略的内容不会出现在手机挂载视图，也不会提交给 Android 媒体库。默认规则为：

```text
2022*
2023*
2024*
2025*
2026-0[1-2]*
#2025-0[1-9]*
#2025-10-0[1-5]*
#2024-05-0[1-9]*
#2024-05-1[1-9]*
# OS generated files #
(?d)$RECYCLE.BIN
(?d)$Recycle.Bin
(?d)#recycle
(?d)System Volume Information
(?d)*Zone.Identifier:$DATA
(?i)(?d)lost+found
```

## 增量扫描与重复上传

每个来源在 `/data/adb/nas_photos_mount/sources/<source-id>/state/seen.tsv` 独立记录已经提交给 Android 媒体库的远程目录、手机相册名、相对路径、大小和修改时间。

- 程序、模块或手机重启后，记录完全相同的文件不会再次提交媒体扫描。
- 路径相同但大小或修改时间改变时，会作为变化文件重新登记。
- 从 v2 升级时，旧配置自动迁移为 `source-1`，旧 `seen.tsv` 会一并迁移，因此已有照片不会因升级被整批重新登记。
- “已登记”只表示 Android 媒体库已经收到扫描请求，不代表 Google Photos 云端上传完成；云端状态和服务端去重仍由 Google Photos 管理。

## 数据位置

- SMB 配置：`/data/adb/nas_photos_mount/rclone.conf`
- 多来源配置：`/data/adb/nas_photos_mount/sources/`
- 已移除来源归档：`/data/adb/nas_photos_mount/deleted-sources/`
- 运行日志：`/data/adb/nas_photos_mount/nas-photos.log`
- 管理面板令牌：`/data/adb/nas_photos_mount/web.token`
