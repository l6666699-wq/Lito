import 'dart:io';

import 'package:tray_manager/tray_manager.dart';

enum TrayAction { open, quickAdd, toggleAlwaysOnTop, toggleCompact, exit }

typedef TrayActionHandler = Future<void> Function(TrayAction action);

/// Resolves the bundled tray icon relative to the running Windows executable.
///
/// Flutter desktop release assets live under `data/flutter_assets` beside the
/// runner executable.  Keeping this helper pure (apart from `dart:io` path
/// resolution) makes the release layout independently testable without
/// loading the tray plugin.
String resolveBundledTrayIconPath([String? executablePath]) {
  final executable = executablePath ?? Platform.resolvedExecutable;
  final executableDirectory = File(executable).parent;
  return executableDirectory.uri
      .resolve('data/flutter_assets/assets/icons/app/litetodo.ico')
      .toFilePath();
}

abstract interface class SystemTrayService {
  Future<void> initialize(TrayActionHandler handler);
  Future<void> dispose();
  Future<void> update({required bool alwaysOnTop, required bool compact});
}

/// Windows implementation of the minimal LiteTodo tray menu.
class WindowsSystemTrayService implements SystemTrayService, TrayListener {
  TrayActionHandler? _handler;
  bool _initialized = false;
  String? _initializationError;

  String? get initializationError => _initializationError;

  @override
  Future<void> initialize(TrayActionHandler handler) async {
    if (_initialized || !Platform.isWindows) return;
    _initializationError = null;
    final iconPath = resolveBundledTrayIconPath();
    if (!File(iconPath).existsSync()) {
      _initializationError = 'LiteTodo tray icon asset not found: $iconPath';
      throw StateError(_initializationError!);
    }
    _handler = handler;
    trayManager.addListener(this);
    await trayManager.setIcon(iconPath);
    await trayManager.setToolTip('LiteTodo');
    await _setMenu(alwaysOnTop: false, compact: false);
    _initialized = true;
  }

  @override
  Future<void> dispose() async {
    if (!_initialized || !Platform.isWindows) return;
    trayManager.removeListener(this);
    await trayManager.destroy();
    _initialized = false;
  }

  @override
  Future<void> update({
    required bool alwaysOnTop,
    required bool compact,
  }) async {
    if (!_initialized || !Platform.isWindows) return;
    await _setMenu(alwaysOnTop: alwaysOnTop, compact: compact);
  }

  Future<void> _setMenu({
    required bool alwaysOnTop,
    required bool compact,
  }) async {
    final menu = Menu(
      items: <MenuItem>[
        MenuItem(key: 'open', label: '打开 LiteTodo'),
        MenuItem(key: 'quick-add', label: '快速添加'),
        MenuItem.separator(),
        MenuItem.checkbox(
          key: 'always-on-top',
          label: '置顶窗口',
          checked: alwaysOnTop,
        ),
        MenuItem.checkbox(key: 'compact', label: '桌面悬浮模式', checked: compact),
        MenuItem.separator(),
        MenuItem(key: 'exit', label: '退出'),
      ],
    );
    await trayManager.setContextMenu(menu);
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    final key = menuItem.key;
    final handler = _handler;
    if (handler == null) return;
    final action = switch (key) {
      'open' => TrayAction.open,
      'quick-add' => TrayAction.quickAdd,
      'always-on-top' => TrayAction.toggleAlwaysOnTop,
      'compact' => TrayAction.toggleCompact,
      'exit' => TrayAction.exit,
      _ => null,
    };
    if (action != null) handler(action);
  }

  @override
  void onTrayIconMouseDown() {}

  @override
  void onTrayIconMouseUp() {}

  @override
  void onTrayIconRightMouseDown() {}

  @override
  void onTrayIconRightMouseUp() {}
}

class FakeSystemTrayService implements SystemTrayService {
  TrayActionHandler? _handler;
  bool initialized = false;
  bool disposed = false;
  bool alwaysOnTop = false;
  bool compact = false;
  final List<TrayAction> actions = <TrayAction>[];

  @override
  Future<void> initialize(TrayActionHandler handler) async {
    _handler = handler;
    initialized = true;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }

  @override
  Future<void> update({
    required bool alwaysOnTop,
    required bool compact,
  }) async {
    this.alwaysOnTop = alwaysOnTop;
    this.compact = compact;
  }

  Future<void> tap(TrayAction action) async {
    actions.add(action);
    await _handler?.call(action);
  }
}
