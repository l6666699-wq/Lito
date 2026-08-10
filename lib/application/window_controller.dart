import 'dart:async';

import 'package:flutter/foundation.dart';

import '../infrastructure/platform/desktop_window_service.dart';
import '../infrastructure/platform/global_hotkey_service.dart';
import '../infrastructure/platform/system_tray_service.dart';

export '../infrastructure/platform/desktop_window_service.dart'
    show WindowMode, WindowGeometry, WindowLayout;

typedef WindowState = WindowLifecycleState;

enum WindowLifecycleState {
  fullVisible,
  compactVisible,
  quickAddVisible,
  hiddenToTray,
  exiting,
}

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
  }) : _desktop =
           desktopWindowService ?? desktopService ?? FakeDesktopWindowService(),
       _tray = systemTrayService ?? trayService ?? FakeSystemTrayService(),
       _hotkey =
           globalHotkeyService ?? hotkeyService ?? FakeGlobalHotkeyService(),
       _flushHook = flushHook ?? _noopFlush;

  final DesktopWindowService _desktop;
  final SystemTrayService _tray;
  final GlobalHotkeyService _hotkey;
  final Future<void> Function() _flushHook;

  Future<void> _operationTail = Future<void>.value();
  final Map<WindowMode, WindowGeometry> _geometries =
      <WindowMode, WindowGeometry>{};
  WindowMode _mode = WindowMode.full;
  WindowMode? _previousMode;
  bool _hidden = false;
  bool _hiddenBeforeQuickAdd = false;
  bool _locked = false;
  bool _restoringAnchor = false;
  bool _exiting = false;
  bool _initialized = false;
  bool _alwaysOnTop = false;
  bool _skipTaskbar = false;
  bool? _alwaysOnTopPreference;
  bool? _skipTaskbarPreference;
  WindowGeometry? _lockAnchor;

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
  bool get isSkipTaskbar => _skipTaskbar;
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

  Future<void> initialize() {
    return _enqueue<void>(() async {
      if (_initialized) return;
      _desktop.setCloseRequestHandler(hideToTray);
      _desktop.setWindowMovedHandler(_onWindowMoved);
      await _desktop.initialize();
      await _applyMode(WindowMode.full, restoreGeometry: false);
      await _desktop.show(focus: false);
      await _tray.initialize(_handleTrayAction);
      await _hotkey.register(onPressed: openQuickAdd);
      _initialized = true;
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
    await _desktop.show();
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
    } else {
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

  Future<void> showFromTray() {
    return _enqueue<void>(() async {
      if (_exiting) return;
      _hidden = false;
      await _desktop.show();
      notifyListeners();
    });
  }

  Future<void> show() => showFromTray();

  Future<void> setAlwaysOnTop(bool value) {
    return _enqueue<void>(() async {
      if (_exiting) return;
      if (_mode != WindowMode.quickAdd) _alwaysOnTopPreference = value;
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
      if (_mode != WindowMode.quickAdd) _skipTaskbarPreference = value;
      _skipTaskbar = value;
      await _desktop.setSkipTaskbar(value);
      notifyListeners();
    });
  }

  Future<void> setLocked(bool value) {
    return _enqueue<void>(() async {
      if (_exiting || _locked == value) return;
      if (value) {
        _lockAnchor = await _desktop.readGeometry();
      }
      _locked = value;
      if (!value) _lockAnchor = null;
      await _desktop.setResizable(!value);
      await _desktop.setMovable(!value);
      notifyListeners();
    });
  }

  Future<void> toggleLocked() => setLocked(!_locked);

  Future<void> exit() {
    return _enqueue<void>(() async {
      if (_exiting) return;
      _exiting = true;
      notifyListeners();
      await _flushHook();
      await _hotkey.unregister();
      await _tray.dispose();
      await _desktop.destroy();
      notifyListeners();
    });
  }

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
      case TrayAction.exit:
        return exit();
    }
  }

  Future<void> _captureGeometry(WindowMode mode) async {
    if (mode == WindowMode.quickAdd) return;
    final geometry = await _desktop.readGeometry();
    if (geometry != null) _geometries[mode] = geometry;
  }

  Future<void> _applyMode(
    WindowMode mode, {
    bool restoreGeometry = true,
  }) async {
    final layout = WindowLayout.forMode(mode);
    await _desktop.configure(layout);
    _alwaysOnTop = mode == WindowMode.quickAdd
        ? true
        : (_alwaysOnTopPreference ?? layout.alwaysOnTop);
    _skipTaskbar = mode == WindowMode.quickAdd
        ? true
        : (_skipTaskbarPreference ?? layout.skipTaskbar);
    await _desktop.setAlwaysOnTop(_alwaysOnTop);
    await _desktop.setSkipTaskbar(_skipTaskbar);
    final geometry = restoreGeometry ? _geometries[mode] : null;
    if (geometry != null && mode != WindowMode.quickAdd) {
      await _desktop.writeGeometry(geometry);
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
    await _tray.update(
      alwaysOnTop: _alwaysOnTop,
      compact: _mode == WindowMode.compact,
    );
  }

  Future<void> _onWindowMoved() {
    return _enqueue<void>(() async {
      if (!_locked || _lockAnchor == null || _restoringAnchor || _exiting) {
        return;
      }
      _restoringAnchor = true;
      try {
        await _desktop.writeGeometry(_lockAnchor!);
      } finally {
        _restoringAnchor = false;
      }
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

  static Future<void> _noopFlush() async {}
}
