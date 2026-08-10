# AGENTS.md — LiteTodo

## 1. Project Goal

Build LiteTodo as a lightweight, local-first Windows desktop tree Todo application.

Primary requirements:

- Flutter Desktop
- Windows 10/11 x64 first
- shadcn_ui visual system
- single Flutter Window / Engine
- Full / Compact / QuickAdd modes reuse the same window
- project + inbox Todos
- configurable project color + IconPark SVG icon
- flat parentId tree model
- tree depth <= 6
- tri-state completion
- completed Todos remain visible and restorable
- desktop always-on-top / lock position
- tray / global hotkey / startup
- local JSON with safe-write, backup and recovery
- no account, no server, no network dependency

Read `docs/LiteTodo_Flutter_项目定稿开发文档.md` before changing architecture.

## 2. Non-Negotiable Technology Constraints

DO NOT introduce without explicit approval:

- Rust
- Rinf
- Tauri
- Electron
- WebView
- SQLite / Drift / Isar / Hive / ObjectBox
- Riverpod
- Bloc
- GetX
- Provider
- Freezed
- json_serializable
- build_runner
- a second UI framework
- multiple Flutter windows / multiple Flutter engines

The application is intentionally small. Do not solve small problems with infrastructure.

## 3. FluxDown Reference Rule

FluxDown may be inspected for Flutter Desktop architecture, shadcn_ui usage patterns, theme organization, component boundaries, desktop lifecycle concepts and window/tray usage concepts.

Do not copy implementation code. FluxDown is AGPL-3.0. LiteTodo must be independently implemented.

## 4. UI Rules

Product-visible UI should use shadcn_ui and Flutter base widgets where appropriate.

Do not visually mix Material or Cupertino components.

Use centralized AppTheme, AppColors, AppMetrics and ProjectPalette. No random padding, radius, color or animation duration inside feature widgets.

## 5. State Management

Use only:

- ChangeNotifier
- ValueNotifier
- ListenableBuilder
- ValueListenableBuilder

`WorkspaceController` is the single source of truth for projects, Todos and trash.

Models are immutable and use hand-written constructor, copyWith, fromJson and toJson.

## 6. Layer Boundaries

`domain/`: pure Dart, no Flutter, plugin or Windows imports.

`application/`: orchestration/controllers/commands, no direct plugin or filesystem calls where an interface exists.

`infrastructure/`: JSON, backup, migration, window, tray, hotkey, startup, single-instance.

`presentation/`: UI only; calls controllers; does not directly write files or call windowManager/trayManager.

## 7. Desktop Architecture

ONE Flutter window only.

```dart
enum WindowMode {
  full,
  compact,
  quickAdd,
}
```

QuickAdd temporarily changes the existing window and restores the previous mode.

All plugin window operations go through `DesktopWindowService` + `WindowController`.

## 8. Todo Tree

Persistent model is flat: id, projectId, parentId, sortOrder.

Never persist nested `children`.

Render flattened `VisibleTodoRow` with `ListView.builder`.

Prevent cycles, moves into descendants and depth > 6.

Drag drop supports Before / Inside / After.

Cross-project movement is explicit in V1, not sidebar drag.

## 9. Completion Rules

- Parent toggle completes/uncompletes entire subtree.
- Some children complete => parent indeterminate.
- All children complete => parent auto-completes.
- Any child becomes incomplete => ancestors recompute.
- Adding incomplete child under completed parent => parent becomes partial.
- Completed Todos are never auto-deleted.

## 10. Persistence

Required files:

```text
data.json
settings.json
data.prev.json
backups/
logs/
```

Required fields: schemaVersion, revision.

Never directly overwrite `data.json`.

SafeFileWriter: snapshot -> encode -> temp write + flush -> re-read validate -> preserve previous -> safe replace -> delete temp.

Writes must be serialized. Normal mutations use about 250ms debounce. Exit/import/migration/manual backup must `flushNow()`.

## 11. Dependencies

Baseline as of 2026-08-10:

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

If resolver compatibility requires another stable version, use the nearest compatible stable version and document why. Do not use git dependencies to dodge compatibility.

Before adding a dependency, document problem, why existing tools cannot solve it, runtime/size impact, maintenance and license.

## 12. Performance Rules

Phase 0 must be completed before full development.

Windows x64 Release gates:

50 Todo idle:

```text
soft target <= 90MB Working Set
gate <= 120MB
> 140MB => stop feature development and investigate
```

1000 Todo default-collapsed:

```text
target <= 130MB
gate <= 150MB
```

Do not evaluate memory from Debug builds.

Never use WebView, multiple engines, SingleChildScrollView containing every Todo, Column containing every Todo, permanent backdrop blur, huge shadows per row, timers per Todo, or disk writes per Todo widget.

## 13. Testing Gate

Before considering a phase complete:

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

No analyzer errors. Tree algorithms require unit tests before UI integration. Persistence failure paths require tests.

## 14. Development Order

1. Phase 0 — desktop/performance PoC
2. Phase 1 — domain + persistence
3. Phase 2 — full workspace UI
4. Phase 3 — tree interactions
5. Phase 4 — desktop integration
6. Phase 5 — polish/release

Do not build all UI before validating desktop behavior.

## 15. Progress Log

Maintain `docs/progress.md` after each phase with completed, incomplete, architecture changes, dependencies added, tests, benchmark results and known issues.

## 16. V1 Scope Guard

Do NOT add login, accounts, cloud sync, server, WebDAV, team features, AI, calendar, pomodoro, attachments, rich text, tags, priorities, recurring Todo, complex reminders or mobile app.
