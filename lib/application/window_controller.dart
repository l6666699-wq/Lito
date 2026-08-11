import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../infrastructure/platform/desktop_window_service.dart';
import '../infrastructure/platform/global_hotkey_service.dart';
import '../infrastructure/platform/system_tray_service.dart';

export '../infrastructure/platform/desktop_window_service.dart'
    show WindowMode, WindowGeometry, WindowLayout;

typedef WindowState = WindowLifecycleState;
typedef WindowGeometryChangedHandler =
    FutureOr<void> Function(WindowMode mode, WindowGeometry? geometry);
typedef VisibleBoundsProvider = FutureOr<Rect?> Function();
typedef LaunchAtStartupChangedHandler = Future<bool> Function(bool value);

enum WindowLifecycleState {
  fullVisible,
  compactVisible,
  quickAddVisible,
  hiddenToTray,
  exiting,
}

enum _PendingWindowAction { show, quickAdd }

/// Coordinates all desktop operations against the one Flutter window.
///
/// Every public transition is placed on [_operationTail].  A rapid sequence of
/// hotkey, tray and UI actions consequently cannot interleave native calls or
/// leave the window in a half-applied layout.
class WindowController extends ChangeNotifier {
  WindowController({
    DesktopWindowService? desktopWindowService,
    DesktopWindowService? desktopService,
    SystemTrayService? systemTrayService,
    SystemTrayService? trayService,
    GlobalHotkeyService? globalHotkeyService,
    GlobalHotkeyService? hotkeyService,
    Future<void> Function()? flushHook,
    this.onLaunchAtStartupChanged,
    WindowGeometry? initialFullGeometry,
    WindowGeometry? initialCompactGeometry,
    this.onGeometryChanged,
    this.visibleBoundsProvider,
    bool startHidden = false,
    bool compactAlwaysOnTop = true,
    bool compactSkipTaskbar = false,
    bool lockCompactPosition = false,
    bool launchAtStartup = false,
    this.registerHotkeyOnInitialize = true,
  }) : _desktop =
           desktopWindowService ?? desktopService ?? FakeDesktopWindowService(),
       _tray = systemTrayService ?? trayService ?? FakeSystemTrayService(),
       _hotkey =
           globalHotkeyService ?? hotkeyService ?? FakeGlobalHotkeyService(),
       _flushHook = flushHook ?? _noopFlush {
    _startHidden = startHidden;
    _compactAlwaysOnTop = compactAlwaysOnTop;
    _compactSkipTaskbar = compactSkipTaskbar;
    _lockCompactPosition = lockCompactPosition;
    _launchAtStartup = launchAtStartup;
    if (initialFullGeometry != null) {
      _geometries[WindowMode.full] = initialFullGeometry;
    }
    if (initialCompactGeometry != null) {
      _geometries[WindowMode.compact] = initialCompactGeometry;
    }
  }

  final DesktopWindowService _desktop;
  final SystemTrayService _tray;
  final GlobalHotkeyService _hotkey;
  final Future<void> Function() _flushHook;
  final LaunchAtStartupChangedHandler? onLaunchAtStartupChanged;
  final WindowGeometryChangedHandler? onGeometryChanged;
  final VisibleBoundsProvider? visibleBoundsProvider;
  final bool registerHotkeyOnInitialize;

  Future<void> _operationTail = Future<void>.value();
  final Map<WindowMode, WindowGeometry> _geometries =
      <WindowMode, WindowGeometry>{};
  WindowMode _mode = WindowMode.full;
  WindowMode? _previousMode;
  bool _hidden = false;
  bool _hiddenBeforeQuickAdd = false;
  bool _deferShow = false;
  bool _locked = false;
  bool _restoringAnchor = false;
  bool _applyingMode = false;
  bool _exiting = false;
  bool _initialized = false;
  bool _alwaysOnTop = false;
  bool _launchAtStartup = false;
  bool _skipTaskbar = false;
  bool _maximized = false;
  bool _closeToTray = true;
  bool _rememberWindowPosition = true;
  bool _startHidden = false;
  bool _compactAlwaysOnTop = true;
  bool _compactSkipTaskbar = false;
  bool _lockCompactPosition = false;
  bool? _alwaysOnTopPreference;
  bool? _skipTaskbarPreference;
  WindowGeometry? _lockAnchor;
  final Map<WindowMode, Timer> _geometrySaveTimers = <WindowMode, Timer>{};
  bool _disposed = false;
  _PendingWindowAction? _pendingAction;
  bool _explicitActivation = false;
  WindowMode? _explicitActivationMode;

  WindowMode get mode => _mode;
  WindowMode? get previousMode => _previousMode;
  WindowLifecycleState get state {
    if (_exiting) return WindowLifecycleState.exiting;
    if (_hidden) return WindowLifecycleState.hiddenToTray;
    return switch (_mode) {
      WindowMode.full => WindowLifecycleState.fullVisible,
      WindowMode.compact => WindowLifecycleState.compactVisible,
      WindowMode.quickAdd => WindowLifecycleState.quickAddVisible,
    };
  }

  bool get isHidden => _hidden;
  bool get isLocked => _locked;
  bool get isExiting => _exiting;
  bool get isAlwaysOnTop => _alwaysOnTop;
  bool get launchAtStartup => _launchAtStartup;
  bool get isSkipTaskbar => _skipTaskbar;
  bool get isMaximized => _maximized;
  bool get closeToTray => _closeToTray;
  bool get rememberWindowPosition => _rememberWindowPosition;
  bool get startHidden => _startHidden;
  bool get isStartHidden => _startHidden;
  bool get compactAlwaysOnTopPreference => _compactAlwaysOnTop;
  bool get compactSkipTaskbarPreference => _compactSkipTaskbar;
  bool get lockCompactPositionPreference => _lockCompactPosition;
  bool get hasExplicitActivation => _explicitActivation;
  WindowMode? get explicitActivationMode => _explicitActivationMode;
  bool get isInitialized => _initialized;
  String? get hotkeyError => _hotkey.error;
  String? get capabilityWarning =>
      _desktop.capabilityWarning ??
      (_locked
          ? 'Windows lock uses a position re-anchor fallback; dragging may briefly move the window.'
          : null);

  DesktopWindowService get desktopService => _desktop;
  SystemTrayService get trayService => _tray;
  GlobalHotkeyService get hotkeyService => _hotkey;

  WindowGeometry? geometryFor(WindowMode mode) => _geometries[mode];

  Future<void> initialize({bool? showWindow}) {
    return _enqueue<void>(() async {
      if (_initialized) return;
      _desktop.setCloseRequestHandler(_handleCloseRequest);
      _desktop.setWindowMovedHandler(_onWindowMoved);
      _desktop.setWindowResizedHandler(_onWindowResized);
      await _desktop.initialize();
      await _applyMode(_mode, restoreGeometry: false);
      final shouldShow = showWindow ?? !_startHidden;
      _deferShow = !shouldShow;
      if (shouldShow) await _desktop.show(focus: false);
      await _tray.initialize(_handleTrayAction);
      // Tray initialization creates its first native menu before settings are
      // loaded.  Project the controller's current snapshot immediately so a
      // non-default launchAtStartup or mode cannot flash an incorrect check.
      await _updateTray();
      if (registerHotkeyOnInitialize) {
        await _hotkey.register(onPressed: openQuickAdd);
      }
      _initialized = true;
      final pendingAction = _pendingAction;
      _pendingAction = null;
      if (pendingAction == _PendingWindowAction.quickAdd &&
          _mode != WindowMode.quickAdd) {
        await _openQuickAdd();
      } else if (pendingAction == _PendingWindowAction.show) {
        if (_deferShow) {
          _hidden = false;
        } else {
          await _showFromTrayInternal();
        }
      }
      notifyListeners();
    });
  }

  /// Applies persisted desktop preferences after the native window has been
  /// initialized.  Geometry values are kept in the controller so a mode
  /// switch never has to read the settings file or call a platform plugin
  /// from the settings layer.
  Future<void> applyPreferences({
    required bool startHidden,
    required bool compactAlwaysOnTop,
    required bool compactSkipTaskbar,
    required bool lockCompactPosition,
    required bool rememberWindowPosition,
    bool? launchAtStartup,
    WindowGeometry? fullGeometry,
    WindowGeometry? compactGeometry,
  }) {
    return _enqueue<void>(() async {
      _startHidden = startHidden;
      _compactAlwaysOnTop = compactAlwaysOnTop;
      _compactSkipTaskbar = compactSkipTaskbar;
      _lockCompactPosition = lockCompactPosition;
      _rememberWindowPosition = rememberWindowPosition;
      if (launchAtStartup != null) _launchAtStartup = launchAtStartup;
      if (fullGeometry == null) {
        _geometries.remove(WindowMode.full);
      } else {
        _geometries[WindowMode.full] = fullGeometry;
      }
      if (compactGeometry == null) {
        _geometries.remove(WindowMode.compact);
      } else {
        _geometries[WindowMode.compact] = compactGeometry;
      }
      await _applyMode(_mode, restoreGeometry: true);
      notifyListeners();
    });
  }

  Future<void> setStartHidden(bool value) {
    return _enqueue<void>(() async {
      if (_exiting || _startHidden == value) return;
      _startHidden = value;
      notifyListeners();
    });
  }

  /// Synchronizes the tray checkmark with the settings authority.  This is a
  /// one-way projection: it never writes back to [SettingsController], which
  /// keeps settings listeners from forming a feedback loop.
  Future<void> setLaunchAtStartupPreference(bool value) {
    return _enqueue<void>(() async {
      if (_exiting || _launchAtStartup == value) return;
      final previous = _launchAtStartup;
      _launchAtStartup = value;
      try {
        await _updateTray();
      } catch (error) {
        _launchAtStartup = previous;
        try {
          await _updateTray();
        } catch (_) {}
        rethrow;
      }
      notifyListeners();
    });
  }

  Future<void> syncLaunchAtStartup(bool value) =>
      setLaunchAtStartupPreference(value);

  Future<void> setLaunchAtStartup(bool value) =>
      setLaunchAtStartupPreference(value);

  Future<void> setCompactAlwaysOnTop(bool value) {
    return _enqueue<void>(() async {
      if (_exiting || _compactAlwaysOnTop == value) return;
      final previousPreference = _compactAlwaysOnTop;
      final previousNative = _alwaysOnTop;
      _compactAlwaysOnTop = value;
      try {
        if (_mode == WindowMode.compact) {
          await _applyMode(WindowMode.compact, restoreGeometry: false);
        }
      } catch (error) {
        _compactAlwaysOnTop = previousPreference;
        _alwaysOnTop = previousNative;
        try {
          await _desktop.setAlwaysOnTop(previousNative);
          await _updateTray();
        } catch (_) {}
        rethrow;
      }
      notifyListeners();
    });
  }

  Future<void> setCompactSkipTaskbar(bool value) {
    return _enqueue<void>(() async {
      if (_exiting || _compactSkipTaskbar == value) return;
      final previousPreference = _compactSkipTaskbar;
      final previousNative = _skipTaskbar;
      _compactSkipTaskbar = value;
      try {
        if (_mode == WindowMode.compact) {
          await _applyMode(WindowMode.compact, restoreGeometry: false);
        }
      } catch (error) {
        _compactSkipTaskbar = previousPreference;
        _skipTaskbar = previousNative;
        try {
          await _desktop.setSkipTaskbar(previousNative);
        } catch (_) {}
        rethrow;
      }
      notifyListeners();
    });
  }

  Future<void> setLockCompactPosition(bool value) {
    return _enqueue<void>(() async {
      if (_exiting || _lockCompactPosition == value) return;
      final previousPreference = _lockCompactPosition;
      final previousLocked = _locked;
      final previousAnchor = _lockAnchor;
      _lockCompactPosition = value;
      try {
        if (_mode == WindowMode.compact) {
          await _setLockedInternal(value);
        }
      } catch (error) {
        _lockCompactPosition = previousPreference;
        try {
          if (_locked != previousLocked) {
            await _setLockedInternal(previousLocked);
          }
        } catch (_) {}
        _locked = previousLocked;
        _lockAnchor = previousAnchor;
        rethrow;
      }
      notifyListeners();
    });
  }

  /// Restores the mode defaults and clears both persisted rectangles.  The
  /// geometry callback receives null values so the settings snapshot follows
  /// the native reset and remains consistent across the next restart.
  Future<void> resetDefaultWindowPosition({bool persist = true}) {
    return _enqueue<void>(() async {
      if (_exiting) return;
      final previousFull = _geometries[WindowMode.full];
      final previousCompact = _geometries[WindowMode.compact];
      for (final timer in _geometrySaveTimers.values) {
        timer.cancel();
      }
      _geometrySaveTimers.clear();
      _geometries.remove(WindowMode.full);
      _geometries.remove(WindowMode.compact);
      try {
        await _applyMode(_mode, restoreGeometry: false);
      } catch (error) {
        if (previousFull != null) _geometries[WindowMode.full] = previousFull;
        if (previousCompact != null) {
          _geometries[WindowMode.compact] = previousCompact;
        }
        try {
          await _applyMode(_mode, restoreGeometry: true);
        } catch (_) {}
        rethrow;
      }
      if (persist) {
        _notifyGeometryChanged(WindowMode.full, null);
        _notifyGeometryChanged(WindowMode.compact, null);
      }
      notifyListeners();
    });
  }

  Future<void> restoreGeometrySnapshot({
    WindowGeometry? fullGeometry,
    WindowGeometry? compactGeometry,
  }) {
    return _enqueue<void>(() async {
      if (_exiting) return;
      if (fullGeometry == null) {
        _geometries.remove(WindowMode.full);
      } else {
        _geometries[WindowMode.full] = fullGeometry;
      }
      if (compactGeometry == null) {
        _geometries.remove(WindowMode.compact);
      } else {
        _geometries[WindowMode.compact] = compactGeometry;
      }
      await _applyMode(_mode, restoreGeometry: true);
      notifyListeners();
    });
  }

  Future<void> switchMode(WindowMode nextMode) {
    return _enqueue<void>(() async {
      if (_exiting || nextMode == _mode && !_hidden) return;
      if (nextMode == WindowMode.quickAdd) {
        await _openQuickAdd();
        return;
      }
      if (_mode == WindowMode.quickAdd) {
        await _restoreQuickAdd(targetMode: nextMode);
        return;
      }
      await _captureGeometry(_mode);
      _mode = nextMode;
      _hidden = false;
      await _applyMode(nextMode);
      notifyListeners();
    });
  }

  Future<void> setMode(WindowMode nextMode) => switchMode(nextMode);

  Future<void> openQuickAdd() {
    if (!_initialized) {
      _pendingAction = _PendingWindowAction.quickAdd;
      _explicitActivation = true;
      _explicitActivationMode = WindowMode.quickAdd;
      if (_mode != WindowMode.quickAdd) {
        _previousMode = _mode;
        _hiddenBeforeQuickAdd = _hidden;
        _hidden = false;
        _mode = WindowMode.quickAdd;
        notifyListeners();
      }
      return Future<void>.value();
    }
    if (_deferShow) {
      _explicitActivation = true;
      _explicitActivationMode = WindowMode.quickAdd;
    }
    return _enqueue<void>(() => _openQuickAdd());
  }

  Future<void> enterQuickAdd() => openQuickAdd();

  Future<void> _openQuickAdd() async {
    if (_exiting || _mode == WindowMode.quickAdd) {
      if (!_hidden) await _desktop.focus();
      return;
    }
    await _captureGeometry(_mode);
    _previousMode = _mode;
    _hiddenBeforeQuickAdd = _hidden;
    _hidden = false;
    _mode = WindowMode.quickAdd;
    await _applyMode(WindowMode.quickAdd, restoreGeometry: false);
    if (!_deferShow) await _desktop.show();
    notifyListeners();
  }

  Future<void> completeQuickAdd() {
    return _enqueue<void>(() => _restoreQuickAdd());
  }

  Future<void> cancelQuickAdd() {
    return _enqueue<void>(() => _restoreQuickAdd());
  }

  Future<void> exitQuickAdd() => cancelQuickAdd();

  Future<void> _restoreQuickAdd({WindowMode? targetMode}) async {
    if (_mode != WindowMode.quickAdd) return;
    final restoreMode = targetMode ?? _previousMode ?? WindowMode.full;
    final wasHidden = _hiddenBeforeQuickAdd;
    _previousMode = null;
    _hiddenBeforeQuickAdd = false;
    _mode = restoreMode;
    _hidden = false;
    await _applyMode(restoreMode);
    if (wasHidden) {
      _hidden = true;
      await _desktop.hide();
    } else if (!_deferShow) {
      await _desktop.show();
    }
    notifyListeners();
  }

  Future<void> hideToTray() {
    return _enqueue<void>(() async {
      if (_exiting) return;
      _hidden = true;
      await _desktop.hide();
      notifyListeners();
    });
  }

  Future<void> hide() => hideToTray();

  /// Starts a native drag from the custom Flutter titlebar.
  Future<void> startDragging() {
    return _enqueue<void>(() async {
      if (_exiting || _locked) return;
      if (_mode != WindowMode.full && _mode != WindowMode.compact) return;
      await _desktop.startDragging();
    });
  }

  Future<void> drag() => startDragging();

  Future<void> minimize() {
    return _enqueue<void>(() async {
      if (_exiting) return;
      await _desktop.minimize();
    });
  }

  Future<void> toggleMaximize() {
    return _enqueue<void>(() async {
      if (_exiting || _mode != WindowMode.full) return;
      final maximized = await _desktop.isMaximized();
      if (maximized) {
        await _desktop.restore();
        _maximized = false;
      } else {
        await _desktop.maximize();
        _maximized = true;
      }
      notifyListeners();
    });
  }

  Future<void> maximizeOrRestore() => toggleMaximize();

  /// Applies the close preference to the app's close affordance and native
  /// close request.  The default keeps the process alive in the tray.
  Future<void> close() {
    return _enqueue<void>(() async {
      if (_exiting) return;
      if (_closeToTray) {
        _hidden = true;
        await _desktop.hide();
        notifyListeners();
      } else {
        await _exitNow();
      }
    });
  }

  Future<void> setCloseToTray(bool value) {
    return _enqueue<void>(() async {
      if (_exiting || _closeToTray == value) return;
      _closeToTray = value;
      notifyListeners();
    });
  }

  Future<void> setRememberWindowPosition(bool value) {
    return _enqueue<void>(() async {
      if (_exiting || _rememberWindowPosition == value) return;
      _rememberWindowPosition = value;
      notifyListeners();
    });
  }

  Future<void> showFromTray() {
    if (!_initialized) {
      _pendingAction = _PendingWindowAction.show;
      _explicitActivation = true;
      _explicitActivationMode = null;
      return Future<void>.value();
    }
    if (_deferShow) {
      _explicitActivation = true;
      _explicitActivationMode = null;
    }
    return _enqueue<void>(() async {
      await _showFromTrayInternal();
      notifyListeners();
    });
  }

  Future<void> show() => showFromTray();

  Future<void> _showFromTrayInternal() async {
    if (_exiting) return;
    _deferShow = false;
    _hidden = false;
    await _desktop.show();
  }

  /// Returns whether startup received an explicit activation (for example a
  /// second-instance `--quick-add`) and clears it after bootstrap consumes it.
  bool consumeExplicitActivation() {
    final hadActivation = _explicitActivation;
    _explicitActivation = false;
    _explicitActivationMode = null;
    return hadActivation;
  }

  Future<void> setAlwaysOnTop(bool value) {
    return _enqueue<void>(() async {
      if (_exiting) return;
      if (_mode == WindowMode.compact) {
        _compactAlwaysOnTop = value;
      } else if (_mode != WindowMode.quickAdd) {
        _alwaysOnTopPreference = value;
      }
      _alwaysOnTop = _mode == WindowMode.quickAdd ? true : value;
      await _desktop.setAlwaysOnTop(_alwaysOnTop);
      await _updateTray();
      notifyListeners();
    });
  }

  Future<void> toggleAlwaysOnTop() => setAlwaysOnTop(!_alwaysOnTop);

  Future<void> setSkipTaskbar(bool value) {
    return _enqueue<void>(() async {
      if (_exiting) return;
      if (_mode == WindowMode.compact) {
        _compactSkipTaskbar = value;
      } else if (_mode != WindowMode.quickAdd) {
        _skipTaskbarPreference = value;
      }
      _skipTaskbar = _mode == WindowMode.quickAdd ? true : value;
      await _desktop.setSkipTaskbar(_skipTaskbar);
      notifyListeners();
    });
  }

  Future<void> setLocked(bool value) {
    return _enqueue<void>(() async {
      if (_exiting || _locked == value) return;
      await _setLockedInternal(value);
      notifyListeners();
    });
  }

  Future<void> toggleLocked() => setLocked(!_locked);

  Future<void> exit() {
    return _enqueue<void>(_exitNow);
  }

  Future<void> _exitNow() async {
    if (_exiting) return;
    _exiting = true;
    if (!_disposed) notifyListeners();

    // Shutdown is a best-effort sequence.  A persistence or plugin failure
    // must not strand the tray icon (or the native window) in the process.
    // Keep the first error so callers still get an actionable failure after
    // every cleanup boundary has had a chance to run.
    Object? firstError;
    StackTrace? firstStack;
    void captureError(Object error, StackTrace stackTrace) {
      firstError ??= error;
      firstStack ??= stackTrace;
    }

    try {
      await _flushGeometryPersistence();
    } catch (error, stackTrace) {
      captureError(error, stackTrace);
    }
    try {
      await _flushHook();
    } catch (error, stackTrace) {
      captureError(error, stackTrace);
    }
    try {
      await _hotkey.unregister();
    } catch (error, stackTrace) {
      captureError(error, stackTrace);
    }
    try {
      await _tray.dispose();
    } catch (error, stackTrace) {
      captureError(error, stackTrace);
    }
    try {
      await _desktop.destroy();
    } catch (error, stackTrace) {
      captureError(error, stackTrace);
    }
    if (!_disposed) notifyListeners();
    if (firstError != null) {
      Error.throwWithStackTrace(firstError!, firstStack!);
    }
  }

  Future<void> _handleCloseRequest() => close();

  Future<void> _handleTrayAction(TrayAction action) {
    switch (action) {
      case TrayAction.open:
        return showFromTray();
      case TrayAction.quickAdd:
        return openQuickAdd();
      case TrayAction.toggleAlwaysOnTop:
        return toggleAlwaysOnTop();
      case TrayAction.toggleCompact:
        return switchMode(
          _mode == WindowMode.compact ? WindowMode.full : WindowMode.compact,
        );
      case TrayAction.toggleLaunchAtStartup:
        return _toggleLaunchAtStartupFromTray();
      case TrayAction.exit:
        return exit();
    }
  }

  Future<void> _toggleLaunchAtStartupFromTray() {
    return _enqueue<void>(() async {
      if (_exiting) return;
      final handler = onLaunchAtStartupChanged;
      if (handler == null) {
        // Keep the native checkmark authoritative even when a non-Windows or
        // test host does not provide a startup capability.
        await _updateTray();
        return;
      }
      final next = !_launchAtStartup;
      bool applied;
      try {
        applied = await handler(next);
      } catch (_) {
        // Startup errors are normalized by SettingsController.  If an older
        // callback still throws, keep the previous checkmark and do not let a
        // tray callback leave a stale optimistic state behind.
        try {
          await _updateTray();
        } catch (_) {}
        return;
      }
      if (!applied) {
        try {
          await _updateTray();
        } catch (_) {}
        return;
      }
      final previous = _launchAtStartup;
      _launchAtStartup = next;
      try {
        await _updateTray();
      } catch (_) {
        _launchAtStartup = previous;
        try {
          await _updateTray();
        } catch (_) {}
        return;
      }
      notifyListeners();
    });
  }

  Future<void> _captureGeometry(WindowMode mode) async {
    if (mode == WindowMode.quickAdd || !_rememberWindowPosition) return;
    final geometry = await _desktop.readGeometry();
    if (geometry != null) {
      _geometries[mode] = geometry;
      _scheduleGeometryPersist(mode, geometry);
    }
  }

  Future<void> _applyMode(
    WindowMode mode, {
    bool restoreGeometry = true,
  }) async {
    _applyingMode = true;
    try {
      await _applyModeInternal(mode, restoreGeometry: restoreGeometry);
    } finally {
      _applyingMode = false;
    }
  }

  Future<void> _applyModeInternal(
    WindowMode mode, {
    bool restoreGeometry = true,
  }) async {
    final layout = WindowLayout.forMode(mode);
    await _desktop.configure(layout);
    _alwaysOnTop = switch (mode) {
      WindowMode.quickAdd => true,
      WindowMode.compact => _compactAlwaysOnTop,
      WindowMode.full => _alwaysOnTopPreference ?? layout.alwaysOnTop,
    };
    _skipTaskbar = switch (mode) {
      WindowMode.quickAdd => true,
      WindowMode.compact => _compactSkipTaskbar,
      WindowMode.full => _skipTaskbarPreference ?? layout.skipTaskbar,
    };
    await _desktop.setAlwaysOnTop(_alwaysOnTop);
    await _desktop.setSkipTaskbar(_skipTaskbar);
    if (mode == WindowMode.quickAdd) {
      final bounds = await _readVisibleBounds();
      if (bounds != null && !bounds.isEmpty) {
        final size = layout.size;
        final position = Offset(
          bounds.left + (bounds.width - size.width) / 2,
          bounds.top + (bounds.height - size.height) / 2,
        );
        await _desktop.writeGeometry(
          WindowGeometry(position: position, size: size),
        );
      }
    }
    final geometry = restoreGeometry && _rememberWindowPosition
        ? _geometries[mode]
        : null;
    if (geometry != null && mode != WindowMode.quickAdd) {
      final clamped = await _clampToVisibleBounds(geometry);
      _geometries[mode] = clamped;
      await _desktop.writeGeometry(clamped);
      if (clamped != geometry) _scheduleGeometryPersist(mode, clamped);
    }
    if (mode == WindowMode.compact && _lockCompactPosition) {
      if (!_locked) await _setLockedInternal(true);
    } else if (mode != WindowMode.compact && _lockCompactPosition) {
      if (_locked) await _setLockedInternal(false);
    }
    if (_locked) {
      await _desktop.setResizable(false);
      await _desktop.setMovable(false);
    }
    // A mode change can alter the native size.  Refresh the lock anchor after
    // the new layout (and any saved geometry) has actually been applied so a
    // later move restores the current mode's bounds rather than the prior
    // mode's dimensions.
    if (_locked && mode != WindowMode.quickAdd) {
      final actualGeometry = await _desktop.readGeometry();
      if (actualGeometry != null) _lockAnchor = actualGeometry;
    }
    await _updateTray();
  }

  Future<void> _updateTray() async {
    await _tray.updateState(
      alwaysOnTop: _alwaysOnTop,
      compact: _mode == WindowMode.compact,
      launchAtStartup: _launchAtStartup,
    );
  }

  Future<WindowGeometry> _clampToVisibleBounds(WindowGeometry geometry) async {
    final provider = visibleBoundsProvider;
    if (provider == null) return geometry;
    Rect? bounds;
    try {
      bounds = await provider();
    } catch (_) {
      // A display query is an enhancement to restore, not a reason to block
      // the shell from opening.  Keep the persisted rectangle if it fails.
      return geometry;
    }
    if (bounds == null || bounds.isEmpty) return geometry;
    final width = math.min(geometry.size.width, bounds.width);
    final height = math.min(geometry.size.height, bounds.height);
    final minX = bounds.left;
    final maxX = math.max(minX, bounds.right - width);
    final minY = bounds.top;
    final maxY = math.max(minY, bounds.bottom - height);
    final x = geometry.position.dx.clamp(minX, maxX).toDouble();
    final y = geometry.position.dy.clamp(minY, maxY).toDouble();
    if (x == geometry.position.dx &&
        y == geometry.position.dy &&
        width == geometry.size.width &&
        height == geometry.size.height) {
      return geometry;
    }
    return WindowGeometry(position: Offset(x, y), size: Size(width, height));
  }

  Future<Rect?> _readVisibleBounds() async {
    final provider = visibleBoundsProvider;
    try {
      return provider == null
          ? await _desktop.readVisibleBounds()
          : await provider();
    } catch (_) {
      return null;
    }
  }

  void _scheduleGeometryPersist(WindowMode mode, WindowGeometry geometry) {
    if (onGeometryChanged == null ||
        mode == WindowMode.quickAdd ||
        !_rememberWindowPosition ||
        _disposed) {
      return;
    }
    _geometrySaveTimers[mode]?.cancel();
    _geometrySaveTimers[mode] = Timer(const Duration(milliseconds: 250), () {
      _geometrySaveTimers.remove(mode);
      if (_disposed) return;
      _notifyGeometryChanged(mode, geometry);
    });
  }

  void _notifyGeometryChanged(WindowMode mode, WindowGeometry? geometry) {
    final handler = onGeometryChanged;
    if (handler == null || _disposed) return;
    try {
      final result = handler(mode, geometry);
      if (result is Future<void>) unawaited(result);
    } catch (_) {
      // Persistence failures are surfaced by SettingsController; a native
      // move event must never throw into window_manager's listener callback.
    }
  }

  Future<void> _flushGeometryPersistence() async {
    final handler = onGeometryChanged;
    if (handler == null || !_rememberWindowPosition) return;
    for (final timer in _geometrySaveTimers.values) {
      timer.cancel();
    }
    _geometrySaveTimers.clear();
    for (final entry in _geometries.entries) {
      if (entry.key == WindowMode.quickAdd) continue;
      try {
        final result = handler(entry.key, entry.value);
        if (result is Future<void>) await result;
      } catch (_) {
        // The settings flush still runs; its repository surfaces any final
        // persistence error to the shutdown boundary.
      }
    }
  }

  Future<void> _setLockedInternal(bool value) async {
    if (_locked == value) return;
    final previousLocked = _locked;
    final previousAnchor = _lockAnchor;
    final nextAnchor = value ? await _desktop.readGeometry() : null;
    try {
      await _desktop.setResizable(!value);
      await _desktop.setMovable(!value);
    } catch (error) {
      try {
        await _desktop.setResizable(!previousLocked);
        await _desktop.setMovable(!previousLocked);
      } catch (_) {}
      _locked = previousLocked;
      _lockAnchor = previousAnchor;
      rethrow;
    }
    _locked = value;
    _lockAnchor = nextAnchor;
  }

  Future<void> _onWindowMoved() {
    return _enqueue<void>(() async {
      if (_exiting || _applyingMode) return;
      if (_locked && _lockAnchor != null && !_restoringAnchor) {
        _restoringAnchor = true;
        try {
          await _desktop.writeGeometry(_lockAnchor!);
        } finally {
          _restoringAnchor = false;
        }
        return;
      }
      await _captureGeometry(_mode);
    });
  }

  Future<void> _onWindowResized() {
    return _enqueue<void>(() async {
      if (_exiting || _restoringAnchor || _applyingMode) return;
      if (_locked && _lockAnchor != null) {
        _restoringAnchor = true;
        try {
          await _desktop.writeGeometry(_lockAnchor!);
        } finally {
          _restoringAnchor = false;
        }
        return;
      }
      await _captureGeometry(_mode);
    });
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final result = _operationTail.then<T>((_) => operation());
    _operationTail = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return result;
  }

  @override
  void dispose() {
    _disposed = true;
    for (final timer in _geometrySaveTimers.values) {
      timer.cancel();
    }
    _geometrySaveTimers.clear();
    super.dispose();
  }

  static Future<void> _noopFlush() async {}
}
