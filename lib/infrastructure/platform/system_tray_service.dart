import 'dart:async';
import 'dart:io';

import 'package:tray_manager/tray_manager.dart';

enum TrayAction {
  open,
  quickAdd,
  toggleAlwaysOnTop,
  toggleCompact,
  toggleLaunchAtStartup,
  exit,
}

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

/// Optional state-aware tray surface.  Keeping this separate from
/// [SystemTrayService] means existing platform doubles that only implement the
/// original two-checkmark update contract remain source-compatible.
abstract interface class SystemTrayStateService {
  Future<void> updateLaunchAtStartup({required bool launchAtStartup});

  Future<void> updateState({
    required bool alwaysOnTop,
    required bool compact,
    required bool launchAtStartup,
  });
}

/// Projects all available checkmarks while retaining compatibility with old
/// services that do not know about the startup item yet.
extension SystemTrayStateProjection on SystemTrayService {
  Future<void> updateState({
    required bool alwaysOnTop,
    required bool compact,
    required bool launchAtStartup,
  }) async {
    if (this is SystemTrayStateService) {
      final stateService = this as SystemTrayStateService;
      await stateService.updateState(
        alwaysOnTop: alwaysOnTop,
        compact: compact,
        launchAtStartup: launchAtStartup,
      );
      return;
    }
    await update(alwaysOnTop: alwaysOnTop, compact: compact);
  }
}

/// Creates the complete V1 menu in one place so the native implementation and
/// platform fakes cannot drift in labels, ordering, or checkmark semantics.
Menu buildLiteTodoTrayMenu({
  required bool alwaysOnTop,
  required bool compact,
  required bool launchAtStartup,
}) {
  return Menu(
    items: <MenuItem>[
      MenuItem(key: 'open', label: '打开 LiteTodo'),
      MenuItem(key: 'quick-add', label: '快速添加'),
      MenuItem.separator(),
      MenuItem.checkbox(
        key: 'always-on-top',
        label: '窗口置顶',
        checked: alwaysOnTop,
      ),
      MenuItem.checkbox(key: 'compact', label: '紧凑模式', checked: compact),
      MenuItem.separator(),
      MenuItem.checkbox(
        key: 'launch-at-startup',
        label: '开机启动',
        checked: launchAtStartup,
      ),
      MenuItem.separator(),
      MenuItem(key: 'exit', label: '退出'),
    ],
  );
}

/// Windows implementation of the minimal LiteTodo tray menu.
class WindowsSystemTrayService
    implements SystemTrayService, SystemTrayStateService, TrayListener {
  TrayActionHandler? _handler;
  bool _initialized = false;
  String? _initializationError;
  bool _alwaysOnTop = false;
  bool _compact = false;
  bool _launchAtStartup = false;

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
    await _setMenu(
      alwaysOnTop: _alwaysOnTop,
      compact: _compact,
      launchAtStartup: _launchAtStartup,
    );
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
    _alwaysOnTop = alwaysOnTop;
    _compact = compact;
    await _setMenu(
      alwaysOnTop: _alwaysOnTop,
      compact: _compact,
      launchAtStartup: _launchAtStartup,
    );
  }

  @override
  Future<void> updateLaunchAtStartup({required bool launchAtStartup}) async {
    if (!_initialized || !Platform.isWindows) return;
    _launchAtStartup = launchAtStartup;
    await _setMenu(
      alwaysOnTop: _alwaysOnTop,
      compact: _compact,
      launchAtStartup: _launchAtStartup,
    );
  }

  @override
  Future<void> updateState({
    required bool alwaysOnTop,
    required bool compact,
    required bool launchAtStartup,
  }) async {
    if (!_initialized || !Platform.isWindows) return;
    _alwaysOnTop = alwaysOnTop;
    _compact = compact;
    _launchAtStartup = launchAtStartup;
    await _setMenu(
      alwaysOnTop: _alwaysOnTop,
      compact: _compact,
      launchAtStartup: _launchAtStartup,
    );
  }

  Future<void> _setMenu({
    required bool alwaysOnTop,
    required bool compact,
    required bool launchAtStartup,
  }) async {
    final menu = buildLiteTodoTrayMenu(
      alwaysOnTop: alwaysOnTop,
      compact: compact,
      launchAtStartup: launchAtStartup,
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
      'launch-at-startup' => TrayAction.toggleLaunchAtStartup,
      'exit' => TrayAction.exit,
      _ => null,
    };
    if (action != null) handler(action);
  }

  @override
  void onTrayIconMouseDown() {
    final handler = _handler;
    if (handler != null) unawaited(handler(TrayAction.open));
  }

  @override
  void onTrayIconMouseUp() {}

  @override
  void onTrayIconRightMouseDown() {
    unawaited(trayManager.popUpContextMenu());
  }

  @override
  void onTrayIconRightMouseUp() {}
}

class FakeSystemTrayService
    implements SystemTrayService, SystemTrayStateService {
  TrayActionHandler? _handler;
  bool initialized = false;
  bool disposed = false;
  bool alwaysOnTop = false;
  bool compact = false;
  bool launchAtStartup = false;
  int updateCount = 0;
  int startupUpdateCount = 0;
  final List<TrayAction> actions = <TrayAction>[];

  @override
  Future<void> initialize(TrayActionHandler handler) async {
    _handler = handler;
    initialized = true;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    initialized = false;
  }

  @override
  Future<void> update({
    required bool alwaysOnTop,
    required bool compact,
  }) async {
    updateCount += 1;
    this.alwaysOnTop = alwaysOnTop;
    this.compact = compact;
  }

  @override
  Future<void> updateLaunchAtStartup({required bool launchAtStartup}) async {
    startupUpdateCount += 1;
    this.launchAtStartup = launchAtStartup;
  }

  @override
  Future<void> updateState({
    required bool alwaysOnTop,
    required bool compact,
    required bool launchAtStartup,
  }) async {
    updateCount += 1;
    startupUpdateCount += 1;
    this.alwaysOnTop = alwaysOnTop;
    this.compact = compact;
    this.launchAtStartup = launchAtStartup;
  }

  Future<void> tap(TrayAction action) async {
    actions.add(action);
    await _handler?.call(action);
  }

  Future<void> tapIcon() => tap(TrayAction.open);
}
