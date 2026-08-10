# Codex 启动任务

你现在负责开发 LiteTodo。

开始前必须先阅读：

1. `AGENTS.md`
2. `docs/LiteTodo_Flutter_项目定稿开发文档.md`

不要直接开始完整功能开发。

## 当前任务：只执行 Phase 0

先完成 Flutter Desktop 技术 PoC，用于验证方案能否继续。

Phase 0 必须包含：

- Flutter stable 3.44.x
- shadcn_ui
- Windows x64
- 单 Flutter Window / 单 Engine
- Full / Compact / QuickAdd 三种模式切换
- 50 条 Mock Todo
- 1000 条 Mock Todo
- parentId 树形扁平化渲染
- ListView.builder
- 项目颜色
- IconPark 本地 SVG
- window_manager
- always-on-top
- lock position
- tray_manager
- global hotkey
- quick add
- JSON load/save
- Windows single instance

## 禁止

不要加入 Rust、Rinf、Tauri、Electron、WebView、SQLite、Riverpod、Bloc、Provider、GetX、Freezed、多窗口、多 Flutter Engine。

## Phase 0 完成后

执行：

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test
flutter build windows --release
```

然后更新：

```text
docs/progress.md
docs/benchmark.md
```

`benchmark.md` 记录：Flutter/Dart/Windows 版本、Release 体积、50/1000 Todo Working Set 和 Private Working Set、冷启动大致耗时、Full/Compact/QuickAdd/Tray/单实例稳定性及已知窗口焦点问题。

如果 50 Todo Release Working Set > 140MB，不要继续 Phase 1，优先分析 Flutter Engine、插件和资源占用。

如果出现严重 window/tray/focus 问题，也不要用业务代码掩盖，先修 Phase 0。

Phase 0 通过之后，再严格按照开发文档进入 Phase 1。
