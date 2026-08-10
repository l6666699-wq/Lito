# LiteTodo Development Progress

## Current Phase

Phase 0 — performance gate not passed; Phase 1 must not start.

## Completed

- [x] Windows desktop PoC uses one Flutter window/engine with Full, Compact and QuickAdd modes.
- [x] Flat `parentId` Todo tree rendered with `ListView.builder`; formal 50-Todo and 1000-Todo fixtures are available.
- [x] Project palette (12 colors), 57 local IconPark SVG icons and the Apache-2.0 notice are present.
- [x] Window manager/AOT, lock-position fallback, tray, global hotkey, single-instance and lock-drag re-anchor paths are implemented.
- [x] JSON safe writer, previous-file recovery, serialized writes, QuickAdd rollback and restart coverage are implemented.
- [x] Release build and Phase 0 checks completed: format (44 files, 0 changed), analyze (no issues), 46 tests passed.
- [x] Three formal cold 50-Todo Release runs and one formal 1000-Todo default-collapsed real-UI sample were recorded; see `benchmark.md`.

## Incomplete

- [ ] 50-Todo memory gate: the three-run median Working Set is 127.016 MiB, above the 120 MiB gate (while below the 140 MiB stop threshold).
- [ ] 1000-Todo repeatability: only one formal default-collapsed real-UI sample exists; the expanded/scroll sample was not executed.
- [ ] Launch-at-startup behavior is not implemented or verified; only the dependency is installed. This is outside the Phase 0 start prompt and remains future work.
- [ ] Phase 0 acceptance decision: investigate and retest, or obtain an explicit approved gate exception. Phase 1 remains blocked.

## Architecture Changes

- One Flutter window/engine is reused for Full, Compact and QuickAdd modes; QuickAdd restores the previous mode.
- The persisted Todo model stays flat (`id`, `projectId`, `parentId`, `sortOrder`) and the UI flattens visible rows for `ListView.builder`.
- Desktop integrations are routed through the window/tray/hotkey/single-instance services; lock-position uses the available window-manager fallback.
- Persistence uses schema/revision JSON, safe replacement, `data.prev.json`, recovery and serialized writes.

## Dependencies Added

| Dependency | Version | Reason |
|---|---|---|
| shadcn_ui | 0.56.1 | Required visual system for the desktop UI. |
| window_manager | 0.5.2 | Single-window sizing, positioning and mode changes. |
| tray_manager | 0.5.3 | Windows tray integration. |
| launch_at_startup | 0.5.1 | Optional Windows startup integration. |
| hotkey_manager | 0.2.3 | Global QuickAdd hotkey. |
| path_provider | 2.1.6 | Platform data-directory resolution. |
| flutter_svg | 2.3.0 | Local IconPark SVG rendering. |
| windows_single_instance | 1.1.0 | Nearest compatible stable version; 1.2.0 requires `win32 >=6`, which conflicts with the `launch_at_startup` dependency chain. |
| flutter_lints | 6.0.0 | Dart/Flutter lint baseline. |

## Tests

```text
dart format --set-exit-if-changed .: 44 files, 0 changed
flutter analyze: No issues
flutter test: 46 passed
flutter build windows --release: Success
```

## Benchmark

See `benchmark.md`.

## Known Issues

- Stable reproduced 50-Todo memory is about 127.1 MiB Working Set / 86.35 MiB Private Working Set; the shared resident portion is about 40.7 MiB, primarily Flutter/Win32/D3D/Intel GPU/IME.
- Product plugin DLLs are about 0.55 MiB total. No runtime plugin registration/DLL was observed for `launch_at_startup`, so removal is expected to provide approximately zero Working Set benefit; it was not changed because the intended startup baseline must be preserved.
- Lucide font files occupy 3.369 MiB on disk; resident impact is uncertain (estimated below 1–3 MiB) and the risky change was not made.
- `window_manager` 0.5.2 lacks a native Windows movable-control API; lock uses resize disable plus move re-anchor and may briefly jitter.
- No forced Windows working-set trimming was used.

## Next

Investigate the 50-Todo Working Set result, retest the incomplete 1000-Todo and stability samples, and make an explicit Phase 0 gate decision (or document an approved exception). Do not start Phase 1 until that decision is recorded.
