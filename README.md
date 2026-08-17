# Atri Bot Launcher

[`atri-bot-launcher`](https://github.com/chhongzh/atri-bot-launcher) 是给普通用户用的 atri-bot 图形启动器。它负责下载和切换 atri-bot 内核，编辑 `config.yaml`，启动和停止进程，还会把内核日志整理到界面里。你可以把它理解成 atri-bot 的桌面和 Android 管理入口。

聊天能力由 [atri-bot](https://github.com/chhongzh/atri-bot) 提供。启动器不包含 Telegram 机器人内核，第一次使用时会从 GitHub Releases 下载对应平台的版本。

## 适合谁

如果你熟悉命令行，直接运行 atri-bot 二进制文件会更简单。启动器更适合希望用界面完成下面这些事情的人。

- 查看可用版本，并下载当前平台和架构对应的构建产物。
- 在界面里填写和修改 `config.yaml`，不用手动处理 YAML 缩进。
- 启动、停止和观察 atri-bot 进程，查看结构化日志。
- 在内核异常退出时收到应用内提示，系统支持时还会收到通知。

## 当前功能

- 从 GitHub Releases 获取版本，最低支持 `v2.0.0-0`，包括 v2 稳定版和预发布版。
- 按平台和架构选择 Android 可执行文件，或桌面端的 `zip`、`tar.gz` 压缩包。
- 下载显示全局进度。桌面端解包时只启动 `atri-bot` 本体，不会误执行压缩包里的 LICENSE 或 README。
- 内核文件保存到应用数据目录，桌面端会尝试补充执行权限。
- `config.yaml` 支持递归读取和保存，配置项按 atri-bot 的实际结构分组，支持文本、布尔值、列表、对象和条件字段。
- GitHub API 和文件下载统一使用 Dio，并跟随平台的网络与代理配置。
- 关于页提供 atri-bot 项目地址、许可证、Star 入口和作者信息。

## 快速开始

### 直接运行

从 Releases 下载与你的平台匹配的启动器，安装后打开应用，再到版本页下载内核。启动器固定从 `chhongzh/atri-bot` 获取 v2.0.0-0 及以上版本，并自动管理内核和配置文件的位置。

首次启动 atri-bot 前，至少需要在配置页填写 Telegram Bot Token。完整的内核配置字段请看 [atri-bot 配置说明](https://github.com/chhongzh/atri-bot/blob/main/docs/configuration.md)。

启动器会把 `config.yaml` 放在 atri-bot 可执行文件同级目录，并以这个目录作为内核的工作目录。这样升级内核时，配置和运行数据仍然留在同一个位置。

### 从源码运行

需要 Flutter SDK 和对应平台的构建工具。项目使用 Dart SDK `^3.11.4`。

```bash
flutter pub get
flutter run
```

常用检查和构建命令如下。

```bash
flutter analyze
flutter build apk --debug
```

桌面端可以把 `apk` 换成 `macos`、`windows` 或 `linux`。具体构建产物和 Flutter 环境有关，提交代码前建议至少运行一次 `flutter analyze`。

## 使用顺序

打开应用后，进入“版本”页，选择一个适合当前平台和架构的版本并开始下载。下载完成后，打开“配置”页填写 Bot Token 及其他选项。回到首页即可启动内核，运行中的输出会出现在日志页。

启动器会持续观察内核进程。进程主动停止时不会自动重启，异常退出时会显示原因；系统通知能力可用时，后台退出也会提醒你。

## 平台说明

### Android

Android 构建固定使用 `targetSdkVersion 28`。内核下载到应用私有的 `data` 目录，启动器会先尝试通过 Dart `Process.start` 直接运行它。

部分 ROM 可能因为 `noexec`、SELinux 或后台限制拒绝执行应用目录中的二进制文件。遇到这种情况，界面会保留真实异常信息。后续需要把 atri-bot 改成可加载的 JNI 或其他原生产物，再在 `KernelService` 中接入对应启动通道。

这个分发方式不适合通过 Google Play 更新。发布 Android 版本时，请使用 APK、GitHub Releases 或其他可信渠道。后台保活取决于目标 ROM，当前实现至少会在进程异常退出时召回用户。

### macOS

应用启用了出站网络 entitlement。启动下载的内核前，启动器会尝试移除 macOS 的下载隔离属性。若请求仍然失败，版本页会显示 DNS、TLS、超时或 GitHub HTTP 状态等具体原因。

### Windows 和 Linux

桌面端使用对应平台的压缩包，解包后以 `atri-bot` 为入口文件。启动器会把工作目录设为内核所在目录，配置文件和内核日志按 atri-bot 的行为保存。

## 与 atri-bot 的关系

atri-bot 负责 Telegram 对话、角色、工具和 MCP 能力。启动器负责版本下载、配置编辑和进程管理，两者可以分开使用。

- 内核项目主页 [chhongzh/atri-bot](https://github.com/chhongzh/atri-bot)
- 内核部署教程 [docs/deployment.md](https://github.com/chhongzh/atri-bot/blob/main/docs/deployment.md)
- 启动器项目主页 [chhongzh/atri-bot-launcher](https://github.com/chhongzh/atri-bot-launcher)

## 参与贡献

欢迎提交代码、文档、测试和问题反馈。报告问题时，请附上启动器版本、操作系统和架构，并尽量贴出日志页中的完整错误信息。

代码修改前运行 `flutter analyze`。涉及平台能力的改动，还应在对应平台完成一次实际构建和启动测试。

## 开源协议

启动器以 MIT 协议开源，详见 [LICENSE](LICENSE)。atri-bot 使用同样的许可证，项目详情见 [atri-bot 的 LICENSE](https://github.com/chhongzh/atri-bot/blob/main/LICENSE)。
