# LiteTodo Flutter Desktop 项目定稿开发文档

> 文档状态：V2 定稿  
> 技术路线：Flutter Desktop + shadcn_ui + Dart + 本地 JSON  
> 首发平台：Windows 10 / 11  
> 后续平台：macOS / Linux（业务层保持可复用）  
> 核心目标：轻量、快速、长期常驻、桌面悬浮、树形待办、无账号、本地优先  
> 明确不使用：Tauri、Electron、WebView、Rust、Rinf、SQLite、Riverpod、Bloc、GetX

---

# 1. 产品定义

LiteTodo 是一个 **Windows 优先的本地轻量树形待办桌面工具**。

它不是项目管理平台，不做 Jira、Notion、Todoist 那套越来越重的系统。核心场景只有：

1. 想到一件事，可以在 1～2 秒内记下来。
2. 待办可以属于某个项目，也可以不属于任何项目。
3. 不属于项目的待办统一进入“收集箱”。
4. 待办支持父子树形结构。
5. 完成待办后仍然保留，可折叠、查看和恢复。
6. 每个项目可配置自己的颜色和 IconPark 图标。
7. 软件可以长期悬浮在桌面角落，并锁定位置。
8. 支持全局快捷键快速呼出并添加任务。
9. 数据只保存在本地，无账号、无云端、无网络依赖。
10. 启动快、运行稳定、依赖少、内存占用可控。

产品原则：

> “快速记录”和“持续可见”优先于“功能数量”。

任何新增功能都必须先回答：

> 它是否能明显改善快速记录、任务拆分或桌面使用体验？

如果不能，不进入 V1。

---

# 2. 为什么采用 Flutter，而不是继续 Tauri

旧方案 Tauri + Vue 在实际运行中出现：

- WebView2 常驻内存明显高于预期；
- 真实运行达到 100MB+；
- 桌面窗口、焦点、悬浮、托盘等场景存在较多边缘问题；
- Vue UI 开发舒服，但 Windows 桌面行为并不够直接；
- “安装包小”并不代表“运行时轻量”。

新版选择 Flutter 的理由：

- Flutter Desktop 正式支持 Windows / macOS / Linux；
- 不依赖 WebView2；
- UI 渲染、动画、窗口内容全部由 Flutter 自己控制；
- Desktop 插件生态已覆盖窗口、托盘、快捷键、开机启动；
- 使用 shadcn_ui 可以得到接近 FluxDown 的视觉语言；
- Dart 足以承担 LiteTodo 的全部业务逻辑，不需要额外 Rust 引擎；
- 后续迁移 macOS / Linux 时，Domain / Application / Presentation 可大比例复用。

需要明确：

> Flutter 不是“极限 20MB 内存框架”。

所以本项目必须先做 Phase 0 性能 PoC，通过真实 Release 数据验收，再进入完整开发。禁止根据 Debug 模式或 README 宣传数字判断性能。

---

# 3. FluxDown 参考原则

本项目可以学习 FluxDown 的：

- Flutter Desktop 组织方式；
- shadcn_ui 视觉体系；
- Theme Token 思路；
- 组件拆分方式；
- ChangeNotifier + ListenableBuilder 的轻状态管理；
- window_manager 的桌面窗口控制思路；
- tray_manager 的系统托盘生命周期；
- Desktop 生命周期设计；
- UI / Application / Platform 分层思想；
- 本地优先、无账号的产品方向。

但必须遵守以下规则：

## 3.1 禁止复制 FluxDown 实现代码

FluxDown 使用 AGPL-3.0。

LiteTodo 只能：

- 阅读；
- 学习；
- 理解结构；
- 参考交互；
- 独立重新实现。

禁止：

- 直接复制其 Dart 文件；
- 直接复制其 Widget 实现；
- 大段改名后复用；
- 直接 Fork 后删减成 LiteTodo。

## 3.2 不复制 FluxDown 的 Rust 架构

FluxDown 使用 Rust 是因为它包含：

- HTTP / FTP；
- BitTorrent；
- HLS / DASH；
- 并发下载；
- SQLite；
- 下载调度；
- 多协议解析。

LiteTodo 不存在这些重任务。

因此本项目：

```text
Flutter UI
    ↓
Dart Application
    ↓
Dart Domain
    ↓
Local JSON / Desktop Plugins
```

禁止引入：

```text
Rust
Rinf
FFI
Tokio
native engine
```

除非未来出现 Dart 明确无法合理完成的核心需求，并单独重新评审。

---

# 4. 技术栈定稿

## 4.1 SDK

开发基线：

```text
Flutter stable 3.44.x
Windows 10 / 11 x64
Visual Studio Windows Desktop Toolchain
```

Codex 开始开发时先执行：

```bash
flutter --version
flutter doctor -v
```

必须使用 stable channel。

禁止使用 beta / master 修复普通业务问题。

## 4.2 UI

```text
Flutter
shadcn_ui
Flutter base widgets
```

UI 规范：

- 根应用使用 `ShadApp`；
- 产品级可见组件优先使用 shadcn_ui；
- 允许使用 Flutter Base Widgets：ListView、CustomScrollView、Focus、Shortcuts、Actions、MouseRegion、GestureDetector、Overlay、AnimatedSize、AnimatedSwitcher、RepaintBoundary；
- 禁止在产品 UI 中混用 Material / Cupertino 风格控件；
- 不使用 Scaffold / AppBar / Material Button 等作为视觉组件；
- 不为了一个控件再引入第二套 UI 框架。

## 4.3 状态管理

只使用：

```text
ChangeNotifier
ValueNotifier
ListenableBuilder
ValueListenableBuilder
```

禁止：

```text
Provider
Riverpod
Bloc
GetX
MobX
Redux
```

主要状态对象：

```text
WorkspaceController
WindowController
QuickAddController
SettingsController
UndoManager
```

其中 `WorkspaceController` 是业务数据唯一事实来源。

## 4.4 数据

V1：

```text
dart:io
JSON
path_provider
```

禁止：

```text
SQLite
Drift
Isar
Hive
ObjectBox
Realm
```

原因：数据量小、JSON 易备份和迁移、依赖更少、当前查询不复杂。

## 4.5 Desktop 插件

开发基线：

```yaml
shadcn_ui: ^0.56.1
window_manager: ^0.5.2
tray_manager: ^0.5.3
launch_at_startup: ^0.5.1
hotkey_manager: ^0.2.3
path_provider: ^2.1.6
flutter_svg: ^2.3.0
windows_single_instance: ^1.2.0
flutter_lints: ^6.0.0
```

说明：

- 以上是 2026-08-10 的开发基线；
- Codex 创建项目时先确认 Flutter 3.44.x 兼容性；
- 如果 pub resolver 给出冲突，优先使用“最新稳定兼容版本”，不得改成 git main；
- `pubspec.lock` 必须提交；
- 项目稳定后不要无理由升级依赖；
- 新增 dependency 前必须说明“为什么标准库和现有依赖无法完成”。

Windows V1 使用 `windows_single_instance` 保证单实例。

未来 macOS / Linux 的单实例能力必须放在 Platform 层，不得让 Windows-only 包污染 Domain 层。

---

# 5. 极简依赖原则

目标不是“依赖越新越好”，而是：

> 能少一个依赖就少一个依赖。

禁止为以下事情安装新包：

- JSON Model：手写 `fromJson / toJson / copyWith`；
- 日志：自己实现轻量 `AppLogger`；
- 防抖：自己实现 Timer；
- Theme：自己定义 Token；
- 排序：标准库。

尤其禁止：

```text
freezed
json_serializable
build_runner
injectable
get_it
auto_route
go_router
```

LiteTodo V1 不需要路由系统，更不需要代码生成工业园区。

---

# 6. 项目目录结构

```text
lib/
├─ main.dart
├─ app/
│  ├─ bootstrap.dart
│  ├─ litetodo_app.dart
│  ├─ app_constants.dart
│  ├─ app_text.dart
│  └─ theme/
│     ├─ app_theme.dart
│     ├─ app_colors.dart
│     ├─ app_metrics.dart
│     └─ project_palette.dart
├─ domain/
│  ├─ models/
│  │  ├─ todo_item.dart
│  │  ├─ project.dart
│  │  ├─ app_data.dart
│  │  ├─ app_settings.dart
│  │  ├─ window_geometry.dart
│  │  └─ trash_item.dart
│  └─ services/
│     ├─ todo_tree_service.dart
│     ├─ todo_completion_service.dart
│     ├─ todo_move_service.dart
│     └─ search_service.dart
├─ application/
│  ├─ workspace_controller.dart
│  ├─ settings_controller.dart
│  ├─ window_controller.dart
│  ├─ quick_add_controller.dart
│  ├─ undo_manager.dart
│  └─ commands/
│     ├─ todo_commands.dart
│     └─ project_commands.dart
├─ infrastructure/
│  ├─ persistence/
│  │  ├─ app_data_repository.dart
│  │  ├─ json_app_data_repository.dart
│  │  ├─ safe_file_writer.dart
│  │  ├─ backup_service.dart
│  │  └─ migration_service.dart
│  ├─ platform/
│  │  ├─ desktop_window_service.dart
│  │  ├─ system_tray_service.dart
│  │  ├─ global_hotkey_service.dart
│  │  ├─ startup_service.dart
│  │  ├─ single_instance_service.dart
│  │  └─ display_service.dart
│  └─ logging/
│     └─ app_logger.dart
├─ presentation/
│  ├─ shell/
│  │  ├─ app_shell.dart
│  │  └─ window_drag_region.dart
│  ├─ full/
│  │  ├─ full_workspace.dart
│  │  ├─ project_sidebar.dart
│  │  └─ full_toolbar.dart
│  ├─ compact/
│  │  ├─ compact_workspace.dart
│  │  └─ compact_header.dart
│  ├─ quick_add/
│  │  └─ quick_add_view.dart
│  ├─ todo/
│  │  ├─ todo_list.dart
│  │  ├─ todo_row.dart
│  │  ├─ todo_checkbox.dart
│  │  ├─ todo_inline_editor.dart
│  │  ├─ todo_context_menu.dart
│  │  └─ todo_drop_indicator.dart
│  ├─ project/
│  │  ├─ project_item.dart
│  │  ├─ project_editor_dialog.dart
│  │  ├─ project_icon_picker.dart
│  │  └─ project_color_picker.dart
│  ├─ common/
│  │  ├─ icon_button.dart
│  │  ├─ empty_state.dart
│  │  ├─ search_box.dart
│  │  └─ confirm_dialog.dart
│  └─ settings/
│     └─ settings_view.dart
└─ icons/
   ├─ icon_catalog.dart
   └─ icon_entry.dart

assets/
├─ icons/
│  ├─ app/
│  └─ iconpark/
└─ images/

test/
├─ domain/
├─ application/
├─ infrastructure/
└─ widget/
```

规则：

- Presentation 不允许直接读写 JSON；
- Widget 不允许直接调用 `windowManager` / `trayManager`；
- Platform 插件调用只能出现在 `infrastructure/platform`；
- Domain 不允许 import Flutter；
- Domain 不允许 import Windows-only package；
- Infrastructure 实现外部能力；
- Presentation 只与 Controller 交互。

---

# 7. 单窗口架构

这是 V2 的重要约束。

## 7.1 禁止多 Flutter Window / 多 Engine

V1 全程只存在一个 Flutter Window。

禁止：主窗口一个 Engine、悬浮窗口一个 Engine、Quick Add 再开一个 Engine。

原因：减少内存、窗口生命周期、tray/focus/hotkey 和状态同步问题。

## 7.2 WindowMode

```dart
enum WindowMode {
  full,
  compact,
  quickAdd,
}
```

三种 UI 只是同一个窗口的不同状态。

### Full

```text
默认：860 × 620
最小：680 × 460
显示任务栏
普通窗口
可选置顶
```

### Compact

```text
默认：340 × 520
最小：300 × 360
最大：440 × 760
默认 alwaysOnTop = true
可配置 skipTaskbar
支持锁定位置
```

### Quick Add

```text
420 × 128 左右
alwaysOnTop = true
聚焦输入框
无任务栏项
不保存本次几何位置
完成 / Esc 后恢复 previousMode
```

---

# 8. 窗口状态机

```text
Boot
  ↓
RestoreState
  ↓
Visible(full | compact)
  ↕
QuickAdd
  ↕
HiddenToTray
  ↓
Exiting
```

`WindowController` 负责：show、hide、switchMode、restorePreviousMode、alwaysOnTop、lockPosition、geometry、skipTaskbar、focus、Quick Add 位置、Full/Compact 各自的位置尺寸、显示器变化后的可见区域修正。

关闭按钮：

```text
点击 × → 默认隐藏到托盘 → 不退出进程
```

真正退出：

```text
托盘 → 退出
```

退出流程：flush 数据 → 保存设置 → 注销 hotkey → dispose tray → destroy window → exit。

---

# 9. 单实例

Windows V1 必须保证单实例，防止两个进程同时写 JSON、重复托盘、Hotkey 冲突。

第二次启动：

```text
如果 LiteTodo 已运行
→ 不创建第二实例
→ 唤醒已有窗口
→ 启动参数交给主实例
```

封装为 `SingleInstanceService`，Windows 实现内部可使用 `windows_single_instance`。

---

# 10. 核心数据模型

## 10.1 Project

```dart
class Project {
  final String id;
  final String name;
  final String iconKey;
  final String colorKey;
  final int sortOrder;
  final bool archived;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

规则：项目可创建、编辑、排序、归档；颜色与图标可独立选择；不强制颜色绝对唯一。

## 10.2 收集箱

收集箱不是一个真实 Project：

```dart
projectId == null
```

UI 永远提供 `📥 收集箱`。

Quick Add 默认使用上次项目；不存在或已归档则回退收集箱。

## 10.3 TodoItem

```dart
class TodoItem {
  final String id;
  final String? projectId;
  final String? parentId;
  final String title;
  final bool completed;
  final DateTime? completedAt;
  final int sortOrder;
  final bool collapsed;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

V1 不加入 dueDate、reminder、tag、attachment、priority、assignee、richText。

---

# 11. 树形结构

数据必须扁平存储，通过 `parentId` 建树。禁止持久化嵌套 `children` 数组。

最大层级：

```text
maxTreeDepth = 6
```

超过 6 层禁止继续缩进，并提供轻提示。

---

# 12. 树形渲染必须扁平化可见节点

禁止递归构建完整 Widget Tree。

必须实现：

```dart
class VisibleTodoRow {
  final TodoItem todo;
  final int depth;
  final TodoVisualState completionState;
}
```

流程：

```text
TodoItem Flat List
        ↓
TodoTreeService
        ↓
TreeIndex(parent -> children)
        ↓
根据 collapsed 生成 VisibleTodoRow[]
        ↓
ListView.builder
```

只有屏幕附近的 Row 实际构建。

---

# 13. 父子任务完成规则

UI 支持：

```text
□ 未完成
◩ 部分完成
☑ 已完成
```

规则：

- 点击父节点完成 → 当前节点和所有后代递归完成；
- 取消父节点 → 当前节点和所有后代递归未完成；
- 完成部分子节点 → 父节点显示部分完成；
- 全部直接子节点完成 → 父节点自动完成并写 `completedAt`；
- 任意子节点恢复未完成 → 祖先重新计算；
- 已完成父节点下新增未完成子节点 → 父节点变为部分完成，不自动完成新任务。

---

# 14. 完成任务展示

完成 != 删除。

默认：

- 未完成优先；
- 完成节点字体变淡；
- 标题轻删除线；
- 同层级完成项排在未完成之后；
- 保持父子关系；
- 根级完整已完成子树可进入折叠区域。

过滤：

```text
全部
未完成
已完成
```

Compact 默认展开未完成，已完成区域折叠。

动画 120～180ms。

---

# 15. 排序与拖拽

拖拽只使用明确 Drag Handle。

支持：

```text
Before
Inside
After
```

约束：

- 禁止拖入自己的子孙节点；
- 禁止形成环；
- 禁止超过 6 层；
- 拖父节点时整个子树移动；
- 子节点 `projectId` 必须与父节点一致；
- V1 只支持当前项目内部拖动。

跨项目移动使用：`右键 → 移动到项目`。

移动父节点到其他项目时，整个 subtree 的 `projectId` 一并更新。

---

# 16. 键盘效率

默认快捷键：

```text
Ctrl + Alt + Space    全局 Quick Add
Ctrl + F              搜索
Ctrl + Z              撤销
Ctrl + Shift + Z      重做
Enter                 确认输入 / 新建同级任务
Ctrl + Enter          新建子任务
Tab                   缩进
Shift + Tab           减少缩进
F2                    编辑标题
Esc                   退出编辑 / 关闭 Quick Add
Delete                移入回收站
```

全局快捷键可关闭、可修改，注册失败必须明确提示。

---

# 17. 快速添加

这是产品核心能力。

主窗口列表顶部长期存在：`＋ 添加待办`。

全局 Quick Add：

1. 记录 previousMode；
2. 同一个窗口切 quickAdd；
3. 调整尺寸；
4. alwaysOnTop；
5. 聚焦输入框；
6. 提交并保存；
7. 恢复 previousMode 或隐藏。

V1 不做自然语言日期解析。

---

# 18. 项目颜色

固定 Palette，不做无限调色盘。

建议 12 色：

```text
red orange amber green teal cyan blue indigo violet purple pink gray
```

每色定义 accent、softBackground、border、foreground。

项目色只用于：左侧色条、图标、Accent、小 Badge、Focus ring。禁止整个页面大面积染色。

---

# 19. IconPark

从 IconPark 精选 48～64 个项目图标 SVG，保存到：

```text
assets/icons/iconpark/
```

业务数据只存：

```text
iconKey = "code"
```

通过 `IconCatalog.resolve("code")` 映射本地 SVG。

使用 `flutter_svg` 本地渲染，可按项目色 tint。禁止运行时网络请求图标。

仓库加入 `THIRD_PARTY_NOTICES.md`，记录 IconPark Apache-2.0 来源。

---

# 20. Theme / FluxDown 风格

V1 使用系统字体：Windows 优先 Segoe UI Variable / Segoe UI，不额外打包 MiSans。

建议 Token：

```text
base spacing   4
row height     36 / 40
input height   36
small radius   6
normal radius  8
dialog radius  12
sidebar width  190～220
tree indent    16
icon size      16 / 18
```

动画：hover 80～120ms、expand 120～180ms、mode switch 150～200ms。

禁止大面积 blur、BackdropFilter 常驻、Shader、粒子、长时间 spring、每行重 Shadow。

---

# 21. 数据目录

使用 `path_provider` 获取 Application Support 路径：

```text
LiteTodo/
├─ data.json
├─ settings.json
├─ data.prev.json
├─ backups/
└─ logs/
```

禁止硬编码 Windows AppData 路径。

---

# 22. data.json

```json
{
  "schemaVersion": 1,
  "revision": 42,
  "projects": [],
  "todos": [],
  "trash": []
}
```

必须带 `schemaVersion` 和 `revision`。

`revision` 每次业务修改 +1。

---

# 23. settings.json

建议：

```json
{
  "themeMode": "system",
  "windowMode": "compact",
  "alwaysOnTop": true,
  "lockPosition": false,
  "skipTaskbarInCompact": false,
  "launchAtStartup": false,
  "startHidden": true,
  "globalHotkeyEnabled": true,
  "globalHotkey": "Ctrl+Alt+Space",
  "lastProjectId": null,
  "fullGeometry": {},
  "compactGeometry": {}
}
```

不使用 shared_preferences 存 Todo 数据；设置也统一 JSON，减少依赖。

---

# 24. JSON 安全写入

严禁直接覆盖主文件。

必须实现 `SafeFileWriter`：

```text
1. 内存生成 immutable snapshot
2. jsonEncode
3. 写 data.tmp
4. flush: true
5. 从 data.tmp 重新读取并 decode 校验
6. 当前 data.json 有效时保留为 data.prev.json
7. 安全替换 data.json
8. 成功后删除 tmp
```

纯 Dart 在 Windows 上不假设 POSIX 绝对原子替换，目标是“安全替换 + 前一版本备份 + 启动恢复”。

---

# 25. 保存调度

普通 mutation：

```text
revision +1
→ notifyListeners()
→ 250ms debounce save
```

必须支持 `flushNow()`。

退出、导出、schema migration、手动备份前立即 flush。

所有写任务必须串行，禁止两个 Future 同时写 data.json。

---

# 26. 启动恢复

```text
data.json
   ↓ 失败
data.prev.json
   ↓ 失败
backups 最新有效文件
   ↓ 失败
创建空 AppData
```

从备份恢复后，应用仍正常启动，并显示非阻塞提示。

---

# 27. Backup

- `data.prev.json`：最近有效版本；
- `backups/`：每天最多一份；
- schema migration 前强制备份；
- 手动“备份数据”可立即生成；
- 默认保留最近 14 个日备份。

不要每次勾选 Todo 都制造历史文件。

---

# 28. 回收站

删除 Todo：subtree 一起进入 Trash。

恢复规则：原项目存在则恢复原项目；原项目不存在则恢复收集箱；原 parent 不存在则恢复根节点。

V1 不自动清空回收站。

项目默认优先“归档”；真正删除项目时，项目 + 全部任务进入 Trash，并二次确认。

---

# 29. Undo / Redo

内存 Command Stack，最多 50 个操作。

至少覆盖：新建、编辑、完成/恢复、移动、缩进、删除、项目修改。

完成父节点即使修改 50 个子节点，也必须一次 Undo 全部恢复。

Undo 不跨重启。

---

# 30. Search

V1 搜索 Todo title 和 Project name。

不做正则、标签筛选、高级 Query DSL、NLP。

搜索结果显示完整路径，例如：`租房系统 / 合同模块 / PDF`。

搜索期间不改变原 tree collapsed 状态。

---

# 31. 系统托盘

Tray Menu：

```text
打开 LiteTodo
快速添加
────────
置顶窗口        ✓
桌面悬浮模式
────────
开机启动        ✓
────────
退出
```

托盘操作统一经过 `SystemTrayService`。

---

# 32. 开机启动

使用 `launch_at_startup`。

“开机启动”和“启动后隐藏”是两个独立设置。

默认：

```text
launchAtStartup = false
startHidden = true
```

首次安装不强迫自启动。

---

# 33. 悬浮与锁定

Compact 支持：

```text
📌 Always On Top
🔒 Lock Position
```

Lock 后禁止窗口拖动和 resize，但 Todo 仍可操作。

保存 compactGeometry；多显示器断开后，如果窗口完全在可视区域外，自动移动回主屏可见区域。

---

# 34. “桌面挂件”边界

V1 不使用 Windows WorkerW / Progman hack 嵌入桌面层。

LiteTodo V1 的“固定桌面”定义：

```text
Compact
+
Always On Top
+
锁定位置
+
可隐藏任务栏项
```

未来真的需要壁纸层 Widget 再单独实验。

---

# 35. 性能设计

硬约束：

```text
1 Flutter Engine
1 Window
```

Todo 必须 `ListView.builder`。

禁止 `Column(children: allTodos)`、`SingleChildScrollView + 全部 Todo`。

资源全部本地，禁止 WebView、Lottie、视频/GIF、大型字体、网络图标。

---

# 36. Phase 0：性能与桌面能力 PoC（必须先做）

Codex 不得一上来实现全部业务。

技术验证版只做：

```text
ShadApp
单 Window
50 条 Todo
1000 条 Mock Todo
树形扁平化列表
IconPark SVG
项目颜色
Compact
Always On Top
Lock
Tray
Global Hotkey
Quick Add
JSON Save / Load
Single Instance
```

Release：

```bash
flutter build windows --release
```

## 36.1 性能门槛

Windows 11 x64，Release，启动后等待 15 秒：

50 Todo：

```text
Soft Target: <= 90 MB Working Set
Gate:        <= 120 MB
> 140 MB:    停止完整开发，先定位
```

1000 Todo 默认折叠：

```text
Target: <= 130 MB
Gate:   <= 150 MB
```

必须测 3 次，记录 Working Set / Private Working Set，不使用 Debug 模式做结论。

## 36.2 启动

Release 冷启动至可操作目标 `< 1.2s`，明显 2～3 秒则分析。

## 36.3 Desktop 验收

连续测试：

```text
显示 / 隐藏 100 次
Full / Compact 100 次
Quick Add 100 次
托盘显示 / 隐藏
锁定 / 解锁
睡眠 / 唤醒
Explorer 重启
双屏拔插
重复启动应用
```

出现焦点丢失、幽灵窗口、托盘失效必须在 Phase 1 前解决。

---

# 37. Phase 1：数据与核心业务

实现 Project、Inbox、Todo、TreeIndex、三态完成、Search、JSON、SafeFileWriter、Backup、Migration、Trash、Unit Tests。

UI 只需基本可操作，不做精细视觉。

# 38. Phase 2：完整工作区

实现 Full Mode、Project Sidebar、项目创建/编辑、Icon Picker、Color Picker、Todo Row、Inline Editor、完成区域、Search、Context Menu。

# 39. Phase 3：树形交互

实现 Before/Inside/After 拖拽、防环、Max Depth、Tab/Shift+Tab、Ctrl+Enter、Move to Project、Undo/Redo。

所有树算法先写 Unit Test，再接 UI。

# 40. Phase 4：Desktop 能力

实现 Compact、Quick Add、Tray、Global Hotkey、Startup、Single Instance、AlwaysOnTop、Lock、Geometry、Multi-display recovery。

# 41. Phase 5：打磨与发布

完成深浅主题、hover/focus/disabled、空状态、错误提示、日志、数据恢复 UI、Release benchmark、Portable ZIP、Windows Setup。

---

# 42. UI 细节

Todo Row 高度 36～40px。

结构：

```text
drag handle
checkbox
indent
title
hover actions
```

默认不显示一排按钮。Hover 才显示“添加子任务 / 更多”。

Inline Edit：双击标题或 F2；Enter 保存；Esc 取消；失焦有修改则保存，空字符串则恢复原值。

---

# 43. Project Sidebar

Project Item：icon + name + unfinishedCount。

选中：soft 项目色背景 + 左侧 2px accent + 项目色 icon。

底部 `＋ 新建项目`。归档项目独立折叠，不占主列表。

---

# 44. Project Editor

字段只有：

```text
项目名称
项目颜色
项目图标
```

不要加项目描述、负责人、预算、权限之类企业后台字段。

---

# 45. 设置页

## 通用

- 开机启动；
- 启动时隐藏；
- 关闭按钮隐藏到托盘；
- 主题：系统 / 浅色 / 深色。

## 桌面

- Compact 默认置顶；
- Compact 隐藏任务栏项；
- 锁定位置；
- Global Hotkey；
- 恢复默认窗口位置。

## 数据

- 打开数据目录；
- 导出；
- 导入；
- 立即备份；
- 查看备份；
- 回收站；
- 清空回收站。

## 关于

- 版本；
- Flutter；
- Third-party licenses。

---

# 46. 数据导入导出

导出完整 data.json。

导入：校验 JSON → 校验 schemaVersion → 备份当前数据 → 导入 → rebuild index → 保存 → 刷新 UI。

导入失败不得破坏现有数据。

---

# 47. Schema Migration

从第一天保留 `schemaVersion`。

接口：

```dart
abstract interface class DataMigration {
  int get fromVersion;
  int get toVersion;
  Map<String, dynamic> migrate(Map<String, dynamic> source);
}
```

逐级迁移 v1 → v2 → v3。

---

# 48. 日志

不用第三方 logger。

```text
logs/app.log
logs/app.prev.log
```

单文件最大 2MB，最多 2 个。不记录 Todo 正文。记录启动、恢复、文件错误、插件错误、Hotkey 错误。

---

# 49. 异常边界

使用 `FlutterError.onError` 和 `PlatformDispatcher.instance.onError`。

错误写日志；持久化失败显示非阻塞提示；数据损坏优先恢复 backup。

禁止空 catch。

---

# 50. 测试

Domain 必测：父子完成、部分完成、新增子节点、Before/Inside/After、防环、Max Depth、subtree project move、sort normalize、search。

Persistence 必测：save/load、invalid json、tmp、prev、backup rotation、migration、revision、并行写串行化。

Application 必测：undo/redo、delete/restore、project archive、quick add target project。

Widget 核心测：Todo Row、Inline Edit、Project Item、Completed section、Quick Add。

---

# 51. 编码规范

- 文件 snake_case；
- 类型 PascalCase；
- 变量 camelCase；
- `const` 能用必须用；
- model immutable；
- mutation 通过 Controller；
- model 手写 `copyWith`；
- 不在 build() 做 IO；
- 不在 build() 修改 Controller；
- 不用 magic number；
- spacing 来自 AppMetrics；
- Color 来自 Theme / ProjectPalette；
- 单文件 > 500～600 行应拆分；
- 单函数 > 60～80 行检查职责。

---

# 52. 性能禁止项

不得：

- 每次 build 全量 JSON decode；
- checkbox 改动时多次全量遍历；
- 每个 Todo 一个 Controller；
- 递归构建所有树节点；
- SingleChildScrollView 包全部 Todo；
- 多 Flutter Engine；
- WebView；
- 常驻 backdrop blur；
- 每行复杂 Shadow；
- 每 Todo Timer；
- 每 Todo 独立写盘；
- 每 Todo 监听 WorkspaceController 全量变化。

---

# 53. TreeIndex

```dart
class TodoTreeIndex {
  final Map<String, TodoItem> byId;
  final Map<String?, List<String>> childrenByParent;
}
```

先保证正确，再做增量优化。

---

# 54. SortOrder

V1 建议同级间隔：

```text
1000
2000
3000
```

中间插入 1500；间隔不足时 normalize siblings。

---

# 55. 项目计数

Sidebar 未完成数量只统计当前项目有效未完成 Todo，不包括 Trash、Archived、Completed。计数派生，不持久化。

---

# 56. 跨平台边界

Domain 100% platform agnostic；Application 尽量平台无关；Infrastructure Platform Windows first。

未来实现：WindowsDesktopWindowService / MacDesktopWindowService / LinuxDesktopWindowService。

UI 不允许散落大量 `Platform.isWindows`。

---

# 57. Windows 首发范围

V1 只承诺 Windows 10 / 11 x64。

ARM64、macOS、Linux 后续，不作为 V1 阻塞项。

---

# 58. 打包

输出：

```text
LiteTodo-x.y.z-windows-x64-portable.zip
LiteTodo-x.y.z-windows-x64-setup.exe
```

基础：

```bash
flutter build windows --release
```

Installer 可用 Inno Setup 独立脚本。

安装器：不强制开机启动、不创建服务、卸载默认保留用户 data、可选删除用户数据、桌面快捷方式可选。

---

# 59. V1 明确不做

```text
账号
登录
云同步
WebDAV
服务端
多人协作
日历
番茄钟
AI
自然语言识别
附件
Markdown 编辑器
富文本
标签系统
优先级体系
复杂提醒
重复任务
插件市场
移动端
统计 Dashboard
时间追踪
```

不允许因为“顺手”加入。

---

# 60. Definition of Done

## Core

- [ ] 收集箱；
- [ ] 项目 CRUD / 归档；
- [ ] 项目独立颜色；
- [ ] 项目独立 IconPark 图标；
- [ ] Todo 新建/编辑；
- [ ] 树形父子；
- [ ] 最大 6 层；
- [ ] 三态完成；
- [ ] 完成后保留；
- [ ] 完成可恢复；
- [ ] Drag Before/Inside/After；
- [ ] Tab / Shift+Tab；
- [ ] Trash；
- [ ] Undo / Redo；
- [ ] Search。

## Desktop

- [ ] 单实例；
- [ ] Full；
- [ ] Compact；
- [ ] Quick Add；
- [ ] 单 Flutter Engine；
- [ ] Always On Top；
- [ ] Lock Position；
- [ ] Window Geometry；
- [ ] Multi-display recovery；
- [ ] Tray；
- [ ] Global Hotkey；
- [ ] Startup；
- [ ] Close to Tray；
- [ ] 正常 Exit。

## Data

- [ ] data.json；
- [ ] settings.json；
- [ ] schemaVersion；
- [ ] revision；
- [ ] Safe Write；
- [ ] serialized writes；
- [ ] data.prev；
- [ ] daily backup；
- [ ] restore；
- [ ] import/export；
- [ ] migration。

## UI

- [ ] shadcn_ui；
- [ ] Light；
- [ ] Dark；
- [ ] project accent；
- [ ] IconPark；
- [ ] hover；
- [ ] keyboard focus；
- [ ] 空状态；
- [ ] 不混用 Material 风格视觉组件。

## Quality

- [ ] `flutter analyze` 0 error；
- [ ] `flutter test` 通过；
- [ ] Release benchmark；
- [ ] 1000 Todo 流畅滚动；
- [ ] 无明显全量 rebuild；
- [ ] 关闭/托盘/Quick Add 连续测试通过；
- [ ] 数据损坏恢复测试通过。

---

# 61. Codex 开发顺序

严格：

```text
Phase 0 性能 PoC
↓
Phase 1 Domain + Persistence
↓
Phase 2 Full UI
↓
Phase 3 Tree Interaction
↓
Phase 4 Desktop Integration
↓
Phase 5 Polish + Release
```

禁止先写完所有页面，最后才验证 window_manager。

Phase 0 失败时停止堆业务代码。

---

# 62. Codex 每阶段输出

每阶段更新 `docs/progress.md`：

```text
完成
未完成
设计变更
新增依赖
已知问题
测试结果
性能结果
下一阶段
```

如文档与现实冲突：记录冲突，优先保持产品目标；改变核心技术栈、数据结构、状态管理必须停止并说明。

---

# 63. Codex 禁令

除非重新批准，不得：

```text
引入 Rust
引入 Tauri
引入 Electron
引入 WebView
引入 SQLite
引入 Riverpod
引入 Bloc
引入 GetX
引入 Freezed
引入 build_runner
引入第二个 Flutter UI 框架
引入多 Window / 多 Engine
抄 FluxDown 源码
```

---

# 64. 最终架构图

```text
┌──────────────────────────────────────┐
│             Presentation             │
│ shadcn_ui / Full / Compact / Quick  │
└──────────────────┬───────────────────┘
                   │
┌──────────────────▼───────────────────┐
│             Application              │
│ Workspace / Window / Undo / Quick   │
└──────────────────┬───────────────────┘
                   │
┌──────────────────▼───────────────────┐
│                Domain                │
│ Project / Todo / Tree / Completion  │
└───────────────┬───────────────┬──────┘
                │               │
┌───────────────▼──────┐ ┌──────▼────────────┐
│     Persistence      │ │ Desktop Platform   │
│ JSON / Backup / Mig. │ │ Window/Tray/Hotkey │
└──────────────────────┘ └────────────────────┘
```

全项目只有 Flutter + Dart。没有 Browser Runtime、WebView、Node、Rust、Database Server、Cloud Service。

---

# 65. 产品最终定位

> 一个长期趴在 Windows 桌面角落、能在两秒内记下一件事、支持项目和树形拆分、完成后仍保留记录的轻量本地待办工具。

只要持续围绕这句话开发，LiteTodo 就不会在第三个月莫名其妙拥有 CRM、AI 助手和团队 OKR。
