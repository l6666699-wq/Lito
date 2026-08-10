# LiteTodo Windows Release Benchmark

## Environment

```text
Date: 2026-08-10 Asia/Shanghai
Flutter: stable 3.44.9
Dart: 3.12.2
Windows: Windows 11 Pro 23H2, build 22631, x64
CPU: Intel Core i5-13400 (10C/16T)
RAM: 33,914,216,448 bytes (approximately 31.58 GiB)
Build: build/windows/x64/runner/Release
Measurement: Release, no debugger attached, 15 seconds after startup
```

## Binary Size

```text
Release folder: 32,509,840 bytes (31.004 MiB)
Executable: 92,672 bytes
Portable ZIP: N/A
Installer: N/A
```

## Memory

Measure Release build with no debugger attached, 15 seconds after startup. Each formal run used a unique temporary `LITETODO_DATA_DIR`.

| Scenario | Formal samples | Working Set | Private Working Set | Result |
|---|---:|---:|---:|---|
| 50 Todo idle | 3 cold runs (median) | 127.016 MiB | 86.320 MiB | FAIL: Working Set is above the 120 MiB gate, below the 140 MiB stop threshold; Private Working Set meets the soft 90 MiB target. |
| 1000 Todo default-collapsed | 1 formal real-UI sample | 126.738 MiB | 85.980 MiB | Under the 130 MiB target and 150 MiB gate; repeatability is incomplete. |
| 1000 Todo expanded/scroll | Not executed | N/A | N/A | No formal sample. |

`Working Set - Private` is the Windows performance-counter value; it is not `PrivateMemorySize64`.

### Formal run details

```text
50 Todo Run 1: interactive 341.6 ms; Working Set 126.906 MiB; Private Working Set 86.227 MiB
50 Todo Run 2: interactive 368.2 ms; Working Set 127.211 MiB; Private Working Set 86.512 MiB
50 Todo Run 3: interactive 296.1 ms; Working Set 127.016 MiB; Private Working Set 86.320 MiB
50 Todo median: interactive 341.6 ms; Working Set 127.016 MiB; Private Working Set 86.320 MiB

1000 Todo: real UI confirmed `1000 条 Todo · 可见 100 行`, collapsed roots, 15s+, one process,
non-zero HWND, Responding=true; Working Set 126.738 MiB; Private Working Set 85.980 MiB; cleanup=0.
```

The default real-data SHA-256 remained `0AC434A177FE77ADBF9241A01965DC8890254FD35433F414618A64D72265D79D`.
The isolated data had schema 1, revision 1, 4 projects, 50 todos and 0 trash items.

## Startup

```text
50 Todo formal cold startup to interactive: 341.6 ms, 368.2 ms, 296.1 ms; median 341.6 ms.
```

## Desktop Stability

| Test | Runs | Result | Notes |
|---|---:|---|---|
| Show/Hide | 100 | Not executed | No formal run. |
| Full/Compact | 100 | Fake controller test passed (100); real Release smoke once | One accepted `Full -> Compact` smoke at 340x520; this is not 100 Release runs. |
| QuickAdd | 100 | Fake controller test passed (100); real Release smoke once | One accepted `Ctrl+Alt+Space` smoke at 420x128; this is not 100 Release runs. |
| Tray show/hide | 100 | Not executed | Do not infer tray-click coverage. |
| Lock/unlock | 50 | Real Release smoke once | One lock drag re-anchor smoke; see the known jitter issue. |
| Second instance | 20 | Implementation test plus one real Release smoke | Primary + secondary instance verified once; 20-run matrix not executed. |
| Sleep/wake | 5 | Not executed | No formal run. |
| Explorer restart | 5 | Not executed | No formal run. |
| Monitor disconnect/reconnect | 5 | Not executed | No formal run. |

Real tray-click and Escape-key automation were not executed. The fake-controller results are not Release UI stability runs.

## Gate

```text
50 Todo:
soft target <= 90MB
gate <= 120MB
> 140MB => STOP and investigate
Measured median: Working Set 127.016 MiB; Private Working Set 86.320 MiB.

1000 Todo:
target <= 130MB
gate <= 150MB
Measured formal sample: Working Set 126.738 MiB; Private Working Set 85.980 MiB.
```

### Memory interpretation

Stable reproduction is approximately 127.1 MiB Working Set / 86.35 MiB Private Working Set. Approximately 40.7 MiB is shared resident memory, primarily Flutter/Win32/D3D/Intel GPU/IME. Product plugin DLLs total about 0.55 MiB. No runtime plugin registration/DLL was observed for `launch_at_startup`, so removal is expected to provide approximately zero Working Set benefit; it was not changed because the intended startup baseline must be preserved. Lucide fonts are 3.369 MiB on disk, with uncertain resident impact (estimated below 1–3 MiB), so they were not changed. No forced Working Set trimming was used.

## Conclusion

```text
FAIL
Reason: the 50-Todo three-run median Working Set (127.016 MiB) exceeds the 120 MiB gate. The 1000-Todo formal sample is under its 130 MiB target and 150 MiB gate, but repeatability is incomplete and no expanded/scroll sample exists. Phase 1 is blocked pending investigation/retest or an explicit approved gate exception.
```
