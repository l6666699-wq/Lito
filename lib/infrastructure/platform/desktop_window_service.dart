import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

/// The three desktop presentations all use this one native Flutter window.
enum WindowMode { full, compact, quickAdd }

/// A small, platform-neutral description of a native window layout.
class WindowLayout {
  const WindowLayout({
    required this.size,
    required this.minimumSize,
    required this.maximumSize,
    required this.alwaysOnTop,
    required this.skipTaskbar,
    required this.resizable,
    required this.movable,
  });

  final Size size;
  final Size minimumSize;
  final Size maximumSize;
  final bool alwaysOnTop;
  final bool skipTaskbar;
  final bool resizable;
  final bool movable;

  static const full = WindowLayout(
    size: Size(860, 620),
    minimumSize: Size(680, 460),
    // window_manager has no resetMaximumSize API.  This is intentionally a
    // large finite value rather than infinity, which the Windows plugin cannot
    // marshal to a LONG.
    maximumSize: Size(10000, 10000),
    alwaysOnTop: false,
    skipTaskbar: false,
    resizable: true,
    movable: true,
  );

  static const compact = WindowLayout(
    size: Size(340, 520),
    minimumSize: Size(300, 360),
    maximumSize: Size(440, 760),
    alwaysOnTop: true,
    skipTaskbar: false,
    resizable: true,
    movable: true,
  );

  static const quickAdd = WindowLayout(
    size: Size(620, 204),
    minimumSize: Size(460, 196),
    maximumSize: Size(760, 240),
    alwaysOnTop: true,
    skipTaskbar: true,
    resizable: false,
    movable: true,
  );

  static WindowLayout forMode(WindowMode mode) {
    switch (mode) {
      case WindowMode.full:
        return full;
      case WindowMode.compact:
        return compact;
      case WindowMode.quickAdd:
        return quickAdd;
    }
  }
}

class WindowGeometry {
  const WindowGeometry({required this.position, required this.size});

  final Offset position;
  final Size size;

  @override
  bool operator ==(Object other) {
    return other is WindowGeometry &&
        other.position == position &&
        other.size == size;
  }

  @override
  int get hashCode => Object.hash(position, size);
}

typedef WindowEventHandler = FutureOr<void> Function();

/// Application-facing boundary for window_manager.  Application and
/// presentation code only depend on this interface, never on the plugin.
abstract interface class DesktopWindowService {
  String? get capabilityWarning;

  Future<void> initialize();
  Future<void> configure(WindowLayout layout, {WindowGeometry? geometry});
  Future<void> show({bool focus = true});
  Future<void> hide();
  Future<void> focus();
  Future<void> startDragging();
  Future<void> minimize();
  Future<bool> isMaximized();
  Future<void> maximize();
  Future<void> restore();
  Future<void> destroy();
  Future<WindowGeometry?> readGeometry();
  Future<Rect?> readVisibleBounds() async => null;
  Future<void> writeGeometry(WindowGeometry geometry);
  Future<void> setResizable(bool value);
  Future<void> setMovable(bool value);
  Future<void> setAlwaysOnTop(bool value);
  Future<void> setSkipTaskbar(bool value);
  Future<void> setTitle(String title);
  void setCloseRequestHandler(WindowEventHandler? handler);
  void setWindowMovedHandler(WindowEventHandler? handler);

  /// Optional for older test doubles and non-resizable platforms.
  void setWindowResizedHandler(WindowEventHandler? handler) {}
}

/// Real Windows implementation.  It is only constructed by bootstrap on
/// Windows, keeping plugin imports out of application and presentation.
class WindowsDesktopWindowService
    with WindowListener
    implements DesktopWindowService {
  WindowsDesktopWindowService();

  WindowEventHandler? _closeHandler;
  WindowEventHandler? _movedHandler;
  WindowEventHandler? _resizedHandler;
  String? _capabilityWarning;
  bool _initialized = false;

  @override
  String? get capabilityWarning => _capabilityWarning;

  @override
  Future<void> initialize() async {
    if (_initialized || !Platform.isWindows) return;
    await windowManager.ensureInitialized();
    // Native window handles are not guaranteed to exist immediately after
    // ensureInitialized.  Wait for the runner's window before issuing any
    // bounds/style calls (otherwise window_manager can dereference a null
    // HWND on Windows).
    await windowManager.waitUntilReadyToShow();
    // The Flutter topbar is the only titlebar rendered by the application.
    // Keep native caption buttons hidden while retaining the native resize and
    // maximize behavior exposed by window_manager.
    await windowManager.setTitleBarStyle(
      TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
    await windowManager.setTitle('LiteTodo');
    windowManager.addListener(this);
    _initialized = true;
  }

  @override
  Future<void> configure(
    WindowLayout layout, {
    WindowGeometry? geometry,
  }) async {
    if (!Platform.isWindows) return;
    // Lower/raise constraints before changing size. Windows clamps SetWindowPos
    // against the previous minimum, which would otherwise leave Compact at
    // Full's 680px minimum or QuickAdd at Compact's 360px minimum.
    await windowManager.setMinimumSize(layout.minimumSize);
    await windowManager.setMaximumSize(layout.maximumSize);
    if (geometry == null) {
      await windowManager.setSize(layout.size);
    } else {
      await windowManager.setBounds(
        null,
        position: geometry.position,
        size: geometry.size,
      );
    }
    await windowManager.setResizable(layout.resizable);
    await windowManager.setAlwaysOnTop(layout.alwaysOnTop);
    await windowManager.setSkipTaskbar(layout.skipTaskbar);
    await windowManager.setPreventClose(true);
  }

  @override
  Future<void> show({bool focus = true}) async {
    if (!Platform.isWindows) return;
    await windowManager.show();
    if (focus) await windowManager.focus();
  }

  @override
  Future<void> hide() async {
    if (!Platform.isWindows) return;
    await windowManager.hide();
  }

  @override
  Future<void> focus() async {
    if (!Platform.isWindows) return;
    await windowManager.focus();
  }

  @override
  Future<void> startDragging() async {
    if (!Platform.isWindows) return;
    await windowManager.startDragging();
  }

  @override
  Future<void> minimize() async {
    if (!Platform.isWindows) return;
    await windowManager.minimize();
  }

  @override
  Future<bool> isMaximized() async {
    if (!Platform.isWindows) return false;
    return windowManager.isMaximized();
  }

  @override
  Future<void> maximize() async {
    if (!Platform.isWindows) return;
    await windowManager.maximize();
  }

  @override
  Future<void> restore() async {
    if (!Platform.isWindows) return;
    await windowManager.restore();
  }

  @override
  Future<void> destroy() async {
    if (!Platform.isWindows) return;
    windowManager.removeListener(this);
    await windowManager.destroy();
  }

  @override
  Future<WindowGeometry?> readGeometry() async {
    if (!Platform.isWindows) return null;
    final bounds = await windowManager.getBounds();
    return WindowGeometry(position: bounds.topLeft, size: bounds.size);
  }

  @override
  Future<Rect?> readVisibleBounds() async {
    if (!Platform.isWindows) return null;
    try {
      final display = await screenRetriever.getPrimaryDisplay();
      final position = display.visiblePosition ?? Offset.zero;
      final size = display.visibleSize ?? display.size;
      if (size.width <= 0 || size.height <= 0) return null;
      return Rect.fromLTWH(position.dx, position.dy, size.width, size.height);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeGeometry(WindowGeometry geometry) async {
    if (!Platform.isWindows) return;
    await windowManager.setBounds(
      null,
      position: geometry.position,
      size: geometry.size,
    );
  }

  @override
  Future<void> setResizable(bool value) async {
    if (!Platform.isWindows) return;
    await windowManager.setResizable(value);
  }

  @override
  Future<void> setMovable(bool value) async {
    if (!Platform.isWindows) return;
    // window_manager 0.5.2 exposes setMovable in Dart, but its Windows
    // implementation has no corresponding method (only macOS supports it).
    // Keep the call guarded so a missing method never breaks mode switching.
    try {
      await windowManager.setMovable(value);
    } on MissingPluginException catch (_) {
      _capabilityWarning =
          'Windows lock uses a position re-anchor fallback; dragging may briefly move the window.';
    } on PlatformException catch (error) {
      _capabilityWarning =
          'Windows lock uses a position re-anchor fallback (${error.code}).';
    }
  }

  @override
  Future<void> setAlwaysOnTop(bool value) async {
    if (!Platform.isWindows) return;
    await windowManager.setAlwaysOnTop(value);
  }

  @override
  Future<void> setSkipTaskbar(bool value) async {
    if (!Platform.isWindows) return;
    await windowManager.setSkipTaskbar(value);
  }

  @override
  Future<void> setTitle(String title) async {
    if (!Platform.isWindows) return;
    await windowManager.setTitle(title);
  }

  @override
  void setCloseRequestHandler(WindowEventHandler? handler) {
    _closeHandler = handler;
  }

  @override
  void setWindowMovedHandler(WindowEventHandler? handler) {
    _movedHandler = handler;
  }

  @override
  void setWindowResizedHandler(WindowEventHandler? handler) {
    _resizedHandler = handler;
  }

  @override
  void onWindowClose() {
    final handler = _closeHandler;
    if (handler != null) _runHandler(handler);
  }

  @override
  void onWindowMoved() {
    final handler = _movedHandler;
    if (handler != null) _runHandler(handler);
  }

  @override
  void onWindowResized() {
    final handler = _resizedHandler;
    if (handler != null) _runHandler(handler);
  }

  void _runHandler(WindowEventHandler handler) {
    final result = handler();
    if (result is Future<void>) unawaited(result);
  }
}

/// Deterministic fake used by unit and widget tests.  It records operations
/// while never touching a native plugin.
class FakeDesktopWindowService implements DesktopWindowService {
  FakeDesktopWindowService({this.movableSupported = true});

  final bool movableSupported;
  final List<String> calls = <String>[];
  WindowGeometry geometry = const WindowGeometry(
    position: Offset(80, 80),
    size: Size(860, 620),
  );
  Rect? visibleBounds;
  WindowEventHandler? _closeHandler;
  WindowEventHandler? _movedHandler;
  WindowEventHandler? _resizedHandler;
  String? _capabilityWarning;
  bool visible = true;
  bool initialized = false;
  bool resizable = true;
  bool movable = true;
  bool alwaysOnTop = false;
  bool skipTaskbar = false;
  bool maximized = false;

  @override
  String? get capabilityWarning => _capabilityWarning;

  @override
  Future<void> initialize() async {
    initialized = true;
    calls.add('initialize');
  }

  @override
  Future<void> configure(
    WindowLayout layout, {
    WindowGeometry? geometry,
  }) async {
    calls.add('configure:${layout.size.width}x${layout.size.height}');
    this.geometry =
        geometry ??
        WindowGeometry(position: this.geometry.position, size: layout.size);
    await setResizable(layout.resizable);
    await setAlwaysOnTop(layout.alwaysOnTop);
    await setSkipTaskbar(layout.skipTaskbar);
  }

  @override
  Future<void> show({bool focus = true}) async {
    visible = true;
    calls.add(focus ? 'show+focus' : 'show');
  }

  @override
  Future<void> hide() async {
    visible = false;
    calls.add('hide');
  }

  @override
  Future<void> focus() async => calls.add('focus');

  @override
  Future<void> startDragging() async => calls.add('startDragging');

  Future<void> drag() => startDragging();

  @override
  Future<void> minimize() async => calls.add('minimize');

  @override
  Future<bool> isMaximized() async {
    calls.add('isMaximized');
    return maximized;
  }

  @override
  Future<void> maximize() async {
    maximized = true;
    calls.add('maximize');
  }

  @override
  Future<void> restore() async {
    maximized = false;
    calls.add('restore');
  }

  @override
  Future<void> destroy() async {
    visible = false;
    calls.add('destroy');
  }

  @override
  Future<WindowGeometry?> readGeometry() async {
    calls.add('readGeometry');
    return geometry;
  }

  @override
  Future<Rect?> readVisibleBounds() async => visibleBounds;

  @override
  Future<void> writeGeometry(WindowGeometry value) async {
    geometry = value;
    calls.add('writeGeometry');
  }

  @override
  Future<void> setResizable(bool value) async {
    resizable = value;
    calls.add('resizable:$value');
  }

  @override
  Future<void> setMovable(bool value) async {
    if (!movableSupported) {
      _capabilityWarning =
          'Windows lock uses a position re-anchor fallback; dragging may briefly move the window.';
      calls.add('movable:unsupported');
      return;
    }
    movable = value;
    calls.add('movable:$value');
  }

  @override
  Future<void> setAlwaysOnTop(bool value) async {
    alwaysOnTop = value;
    calls.add('alwaysOnTop:$value');
  }

  @override
  Future<void> setSkipTaskbar(bool value) async {
    skipTaskbar = value;
    calls.add('skipTaskbar:$value');
  }

  @override
  Future<void> setTitle(String title) async => calls.add('title:$title');

  @override
  void setCloseRequestHandler(WindowEventHandler? handler) {
    _closeHandler = handler;
  }

  @override
  void setWindowMovedHandler(WindowEventHandler? handler) {
    _movedHandler = handler;
  }

  @override
  void setWindowResizedHandler(WindowEventHandler? handler) {
    _resizedHandler = handler;
  }

  Future<void> emitCloseRequest() async {
    final result = _closeHandler?.call();
    if (result is Future<void>) await result;
  }

  Future<void> emitWindowMoved() async {
    final result = _movedHandler?.call();
    if (result is Future<void>) await result;
  }

  Future<void> emitWindowResized() async {
    final result = _resizedHandler?.call();
    if (result is Future<void>) await result;
  }
}
