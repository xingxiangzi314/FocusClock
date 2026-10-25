# 拾光 · Flutter 版

离线安卓学习计时 App，版本 **2.0.7+16**，包名 `com.shiguang.focus`，支持 Android 8.0 及以上。页面使用较小、较轻的标题，时钟卡片约占手机屏幕四分之一，统计依次为累计、分布与热力图。保留浅灰背景、大圆角卡片、亮蓝色操作按钮和悬浮导航。

所有版本说明持续维护在 [更新说明](../更新说明.md)。默认仅交付最新 APK 与签名附属文件，不生成新的源码 ZIP。本目录为最新源码；保留的 1.0.3 源码 ZIP 是历史归档。

2.0.4 以 2.0.2 的布局为基准，仅缩小设置分组文字、将统计日期移到分布标题右侧并删除卡片内日历，以及将原尺寸饼图在周期文字与卡片底边之间垂直居中。三张卡片的高度、间距及热力图保持 2.0.2 的样式。

2.0.6 增加 8 瓣背景反向旋转及浅灰到极淡蓝色渐变，背景恢复首次横向中心后向上移动。累计专注三组数据居中，两侧再分别向外微移 8 个逻辑像素；今日专注到学习待办标题的间距缩小为 12。其余界面沿用原布局。

2.0.7 将触感改为短促轻触，新增 1–100% 强度调节（默认 35%）、立即体验和恢复默认，强度可持久保存并随备份导入导出。

## 安装与升级

打开「拾光-2.0.7.apk」安装。已有拾光时直接覆盖安装，**不要先卸载或清除数据**。沿用原包名、原开发签名和原数据格式，任务、记录、设置与进行中的计时仍由原数据仓库读取。首次开始专注时允许通知。

## 整体架构

界面已完整改为 **Dart + Flutter Widgets**，安装包不再包含网页界面或使用 WebView。安卓后台部分继续使用 Java，避免依赖 Flutter 页面存活来维持计时。

```text
Flutter 界面：待办 / 沉浸时钟 / 统计图表 / 设置
                    ↓
FocusController：状态、操作、前台轻量刷新、触感请求
                    ↓ MethodChannel
Android MainActivity：本机接口、权限、系统文件选择器
                    ↓
Repository：原有数据格式、持久化、单调时钟、有效区间
FocusService：后台专注、通知控制、完成提醒、唤醒锁
Haptics：应用内独立触感控制及安卓版本适配
```

| 源码 | 职责 |
| --- | --- |
| `lib/main.dart`、`ui.dart` | 应用入口、主题、导航动效、通用组件与安全区域 |
| `lib/tasks.dart` | 任务增删改、完成恢复、正倒计时、沉浸模式与结束确认 |
| `lib/stats_page.dart`、`statistics.dart` | 日周月年统计、任务占比、全年热力图与记录 |
| `lib/controller.dart`、`models.dart` | 状态模型、本机通信、刷新与失败处理 |
| `android/app/src/main/java/com/shiguang/focus/` | 安卓存储、可靠计时、通知、文件读写与触感 |
| `test/` | Flutter 控制逻辑、统计与界面操作测试 |
| `tool/preview_test.dart` | 使用演示数据渲染界面预览，数据不会打入 APK |

应用运行只使用 Flutter SDK 及系统能力，没有第三方运行时插件、账号、远程页面、广告或网络权限。中文文字使用设备字体，图标随 APK 离线打包。开发时下载工具与依赖需要联网。

## 功能与统计口径

- 任务支持正计时或 1–720 分钟倒计时，六种图标与颜色，编辑、删除、完成与恢复；计时方式在任务编辑中设置。删除任务保留历史记录。
- 开始、暂停、继续、结束确认、沉浸时钟、通知栏操作；倒计时完成自动保存，正计时单次上限 24 小时。
- 新计时有效专注 **超过 10 秒**才生成记录，等于或少于 10 秒不计入次数与时长；旧记录与旧 JSON 备份继续保留。
- 暂停时间不累计，跨天按有效片段分配。跨日记录可能在多天的列表出现，累计次数只计一次。
- 日均从首次记录日至今按自然日计算，包含未专注日；时钟倒计时秒数向上取整，统计分钟向下取整。
- 日、周、月、年切换，日期选择、历史周期、饼图、热力图与记录详情／删除。周从周一开始。
- 热力图按所选年份展示，可左右滑动；默认定位到所选日期附近，点击日期进入当日统计。分级为 0、少于 30、30–59、60–119、120 分钟及以上。
- 每日目标、明亮／深色／跟随系统、触感、完成提醒、前台计时保持亮屏、JSON 备份恢复、CSV 导出。
- 普通文字不可选择，无双指缩放；任务名称等输入框保留编辑功能。导航支持轻移和淡入，尊重系统减少动画设置。

## 后台、通知与触感

后台由原生前台服务管理，界面切页或进入后台不会重置计时。通知运行时只显示系统动态时钟，暂停时改为固定时长，避免出现两个不同步的时间。倒计时运行期间使用 CPU 唤醒锁。

触感开关由应用独立控制，不读取或修改系统触感开关。设置中可调节 1–100% 强度，默认 35%，松手保存并体验。硬件支持时使用轻触原语，否则使用短包络／短脉冲兼容，避免长时间重振。Android 13 及以上通过媒体用途的自定义短振调用，旧版本采用系统允许的兼容方式。开启应用开关立即轻振，关闭停止后续操作反馈；完成提醒单独控制。全部禁振、媒体振动关闭、勿扰、省电或厂商限制仍可能阻止振动。

小米等系统可能需要允许拾光后台活动。强行停止可能中断完成提醒；设备重启后按最近约 30 秒检查点暂停恢复，关机时间不计入专注。卸载或清除数据会删除记录，请先导出备份。备份不包含进行中的专注，恢复前完整校验并二次确认，恢复会替换当前数据。系统云备份已关闭。

## Git 版本记录

本目录已建立本地 Git 仓库，主分支为 `main`，包含修改前的源代码基线和本次功能提交，版本标签为 `v2.0.7`。VS Code 左侧“源代码管理”可查看改动和提交，也可运行 `git log --oneline`。签名密钥保留在本机 signing 目录并由 .gitignore 排除，缓存、安装包和本机绝对路径配置同样不纳入版本记录。未配置远程仓库。

## 在 VS Code 快速预览 UI

使用 Flutter 插件的 **Widget Preview**。入口为 `lib/ui_previews.dart`，其中已配置待办、统计数据、设置三张 412×915 的手机尺寸预览。它们直接复用实际页面和底部导航，通过内存演示数据展示 UI，不依赖安卓设备、后台计时或用户学习记录。

打开 `lib/ui_previews.dart`，在命令面板执行 **Flutter: Show Widget Preview**。修改 `tasks.dart`、`stats_page.dart`、`settings_page.dart`、`ui.dart` 或 `focus_toggle.dart` 后保存，预览会更新。已取消“只显示当前文件”的过滤，可在修改其他布局文件时持续查看三页。工作区配置为打开项目时预热预览服务、在编辑器旁显示；UI 预览使用此面板，无需按 F5。

`ui_previews.dart` 未被正式 `main.dart` 入口导入，演示数据不进入正式应用入口。官方说明：https://docs.flutter.dev/tools/widget-previewer 。本次仅进行了静态检查与预览入口注册确认，没有运行功能测试或打包 APK。

## 安卓设备功能调试（可选）

2026-10-25 已完成 SDK 许可确认，启动 Pixel_7（Android 17／API 37）并实际运行拾光。WHPX、首页、统计、设置与热重载已验证。VS Code 已通过 `.vscode/launch.json` 的“拾光：安卓界面预览”接入调试，设备为 `emulator-5554`。

工作区使用 `D:/code/flutter`、`work/android-sdk`、Java 17 及现有 Pub／Gradle 缓存。Flutter 用户配置单独放在 `work/flutter-user`，调试会话显式使用同一配置，避免编辑器继续选用 Android Studio 的 Java 25。以后执行 `Flutter: Launch Emulator` 并选择 Pixel_7，待安卓桌面出现后按 F5，修改 Dart 界面后保存即可热重载。Flutter 尚未加入系统 PATH，终端可使用完整路径 `& 'D:/code/flutter/bin/flutter.bat'`。

`android/app/src/debug/AndroidManifest.xml` 为 Flutter 本地 VM 调试服务声明 INTERNET 权限，解决调试版无法建立热重载连接的问题。该配置仅用于 debug 构建；已核对现有 2.0.6 正式 APK 仍无网络权限且哈希不变。模拟器实际画面见 `../预览/模拟器-待办.png`、`模拟器-统计数据.png` 和 `模拟器-设置.png`。

## 构建

本次使用 Flutter **3.47.8**（Dart 3.13.7）、JDK 17、Android SDK Platform 36、Build Tools 35.0.0，目标 Android API 35。工程使用 Gradle 8.14.3、Android Gradle Plugin 8.11.1、Kotlin 构建依赖 2.3.20，Wrapper 已附带。

```powershell
.\build.ps1 -FlutterRoot 'C:\dev\flutter' -SdkRoot 'C:\Android\Sdk' -JavaHome 'C:\Program Files\Java\jdk-17'
```

脚本获取 Flutter 依赖、构建 ARM32 + ARM64 通用 release APK，使用现有证书签名并验证，输出到上一级发布目录。验证成功后才清理发布目录中的旧版本 APK／idsig，不删除源码 ZIP。

也可以用 Flutter 插件在 Android Studio 或 VS Code 打开本目录，执行 `flutter pub get`、`flutter test`、`flutter build apk --release --target-platform android-arm,android-arm64`。首次构建需下载 Gradle、安卓依赖及可能缺少的 SDK 工具。`android/local.properties` 为本机路径，不应复制到其他电脑直接使用。

保持 `signing/debug.keystore` 不变才能覆盖现有安装；别名 `androiddebugkey`，开发口令 `android`。这是个人开发签名包，未上架商店。

## 验证与范围

- Dart 静态检查无问题。
- 28 项 Flutter 测试覆盖统计分摊、日期边界、触感开关、过期刷新、自动保存刷新、任务表单、计时操作、导航动效、深色与减少动画，以及时钟高度、统计卡片顺序与 320／412／768 宽度布局。新增启停动效、连续反向、状态确认、操作失败和沉浸时钟检查。
- 45 项原生计时与数据检查、26 项原生触感检查、11 项通知时间检查使用 JVM 平台替身或纯 Java 逻辑，真实业务源码参与测试。
- 使用中文字体及实际图标渲染 Flutter 五种页面状态，检查带记录的图表、浅色与深色布局；演示数据只用于预览。
- Flutter release 构建、v2／v3／v4 签名、16 KB 对齐、包名／版本／权限与 Flutter AOT 产物校验通过，证书与 2.0.6 一致。最终页面及 51 帧时钟动效与已确认预览逐像素一致；实际动效见 ../预览/启停动效-8瓣背景上移.gif。
- 2.0.6 的界面曾在 Pixel_7 模拟器验证三页显示、导航与热重载；本版本原生触感经平台替身验证，未连接安卓真机，实际轻重和小米系统限制需在手机上确认。

Flutter 与安卓通信采用 [官方 Platform Channels](https://docs.flutter.dev/platform-integration/platform-channels)。

原生触感检查可运行 `python tool/test_haptics_native.py`；数据检查可运行 `python tool/test_repository_native.py`（需要 org.json 测试 JAR，可通过 JSON_JAR 指定；本机复用工作区 work/json.jar）。两者编译实际业务源码，不连接手机。
