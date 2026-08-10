# LiteTodo

LiteTodo 是一款面向 Windows 10/11 x64 的本地优先树形待办应用。数据保存在本机 JSON 文件中，不依赖账号、服务器或网络服务；Full、Compact、QuickAdd 三种模式复用同一个 Flutter 窗口。

## 主要能力

- 项目、分组和 Todo 树（最大深度 6），支持完成状态、拖拽移动和键盘操作。
- 撤销/重做、QuickAdd、回收站、导入导出、备份恢复以及异常启动恢复。
- 窗口置顶、紧凑模式、系统托盘、全局快捷键、开机启动和单实例。
- 响应式首页、设置页和统计页；页面还原以 `LiteTodo_Flutter_开发资料包/真实UI` 图片为参考。

## 图标规范

功能、系统和操作图标统一由 `lib/icons/app_icons.dart` 的 `AppIcons` 提供，底层使用 `lucide_icons_flutter`。项目图标统一使用 `lib/icons/project_icons.dart` 中登记的本地 IconPark Outline SVG。业务页面不得直接选择其他图标库，也不得使用 Emoji 或 Unicode 图标字符。

## 开发

在已安装 Flutter stable 的终端执行：

```bash
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test --concurrency=1
```

Windows 调试运行：

```bash
flutter run -d windows
```

构建便携版 Release：

```bash
flutter build windows --release
```

输出目录为 `build/windows/x64/runner/Release`。发布时可将该目录压缩为 ZIP；项目当前提供的便携包为 `build/artifacts/LiteTodo-1.0.0-windows-x64.zip`。LiteTodo 不提供安装器，解压后直接运行 `litetodo.exe` 即可。

## 数据目录

默认使用平台应用数据目录。可通过 `LITETODO_DATA_DIR` 指定数据根目录，便于便携运行、备份和测试：

```powershell
$env:LITETODO_DATA_DIR = "D:\LiteTodoData"
flutter run -d windows
```

目录中包含 `data.json`、`settings.json`、`data.prev.json`、`backups/` 和 `logs/`。首次干净启动会创建 schema v2 的空数据，不会注入示例 Todo。

## 依赖

核心运行依赖及用途：

| 依赖 | 版本 | 用途 |
| --- | --- | --- |
| `shadcn_ui` | `^0.56.1` | 桌面 UI 组件和视觉系统 |
| `lucide_icons_flutter` | `^3.1.15` | 统一功能/系统图标 |
| `flutter_svg` | `^2.3.0` | 渲染本地 IconPark 项目图标 |
| `window_manager` | `^0.5.2` | 单窗口尺寸、位置和模式切换 |
| `tray_manager` | `^0.5.3` | Windows 系统托盘 |
| `launch_at_startup` | `^0.5.1` | 开机启动设置 |
| `hotkey_manager` | `^0.2.3` | 全局 QuickAdd 快捷键 |
| `path_provider` | `^2.1.6` | 平台数据目录解析 |
| `file_selector` | `^1.1.0` | 官方本地导入/导出文件选择器 |
| `screen_retriever` | `^0.2.2` | 屏幕可见区域和窗口边界计算 |
| `windows_single_instance` | `^1.1.0` | Windows 单实例和参数转发 |

完整版本约束以 [`pubspec.yaml`](pubspec.yaml) 为准。

## 资料与进度

- [开发进度](docs/progress.md)
- [项目定稿开发文档](docs/LiteTodo_Flutter_项目定稿开发文档.md)
- [第三方许可说明](THIRD_PARTY_NOTICES.md)
