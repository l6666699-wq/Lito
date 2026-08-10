import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:litetodo/application/settings_controller.dart';
import 'package:litetodo/application/window_controller.dart';
import 'package:litetodo/domain/models/app_settings.dart';
import 'package:litetodo/infrastructure/platform/desktop_window_service.dart';
import 'package:litetodo/infrastructure/persistence/settings_repository.dart';

void main() {
  test('desktop settings have safe defaults and preserve geometry JSON', () {
    final settings = AppSettings(
      startHidden: false,
      compactAlwaysOnTop: false,
      compactSkipTaskbar: true,
      lockCompactPosition: true,
      fullGeometry: const AppWindowGeometry(
        x: 12,
        y: 24,
        width: 680,
        height: 460,
      ),
      compactGeometry: const AppWindowGeometry(
        x: 40,
        y: 50,
        width: 340,
        height: 520,
      ),
    );

    expect(AppSettings().startHidden, isTrue);
    expect(AppSettings().compactAlwaysOnTop, isTrue);
    expect(AppSettings().compactSkipTaskbar, isFalse);
    expect(AppSettings().lockCompactPosition, isFalse);
    expect(AppSettings.fromJson(settings.toJson()), settings);

    final legacy = AppSettings.fromJson(<String, dynamic>{
      'schemaVersion': 1,
      'revision': 1,
      'themeMode': 'system',
      'globalHotkey': 'Ctrl+Alt+Space',
      'alwaysOnTop': false,
      'skipTaskbarInCompact': true,
      'lockPosition': true,
    });
    expect(legacy.compactAlwaysOnTop, isFalse);
    expect(legacy.compactSkipTaskbar, isTrue);
    expect(legacy.lockCompactPosition, isTrue);
  });

  test(
    'hidden initialization defers every show until explicitly requested',
    () async {
      final desktop = FakeDesktopWindowService();
      final controller = WindowController(desktopService: desktop);

      // A second-instance/global-hotkey request can arrive before bootstrap has
      // reached window_manager.  It must be retained, not executed early.
      await controller.openQuickAdd();
      expect(desktop.calls, isEmpty);
      await controller.initialize(showWindow: false);
      expect(desktop.calls.where((call) => call.startsWith('show')), isEmpty);
      expect(controller.mode, WindowMode.quickAdd);
      expect(controller.hasExplicitActivation, isTrue);

      await controller.showFromTray();
      expect(desktop.calls, contains('show+focus'));
      expect(controller.consumeExplicitActivation(), isTrue);

      final ordinaryDesktop = FakeDesktopWindowService();
      final ordinary = WindowController(desktopService: ordinaryDesktop);
      await ordinary.initialize(showWindow: false);
      await ordinary.applyPreferences(
        startHidden: true,
        compactAlwaysOnTop: true,
        compactSkipTaskbar: false,
        lockCompactPosition: false,
        rememberWindowPosition: true,
      );
      expect(ordinary.hasExplicitActivation, isFalse);
      await ordinary.hideToTray();
      expect(
        ordinaryDesktop.calls.where((call) => call.startsWith('show')),
        isEmpty,
      );

      final pendingShowDesktop = FakeDesktopWindowService();
      final pendingShow = WindowController(desktopService: pendingShowDesktop);
      await pendingShow.showFromTray();
      expect(pendingShowDesktop.calls, isEmpty);
      await pendingShow.initialize(showWindow: false);
      expect(
        pendingShowDesktop.calls.where((call) => call.startsWith('show')),
        isEmpty,
      );
      await pendingShow.showFromTray();
      expect(
        pendingShowDesktop.calls
            .where((call) => call.startsWith('show'))
            .length,
        1,
      );
    },
  );

  test('compact preferences synchronize native flags and lock state', () async {
    final desktop = FakeDesktopWindowService();
    final controller = WindowController(desktopService: desktop);
    await controller.initialize(showWindow: false);
    await controller.applyPreferences(
      startHidden: true,
      compactAlwaysOnTop: false,
      compactSkipTaskbar: true,
      lockCompactPosition: false,
      rememberWindowPosition: true,
    );

    await controller.switchMode(WindowMode.compact);
    expect(desktop.alwaysOnTop, isFalse);
    expect(desktop.skipTaskbar, isTrue);
    expect(desktop.resizable, isTrue);
    expect(desktop.movable, isTrue);

    await controller.setLockCompactPosition(true);
    expect(desktop.resizable, isFalse);
    expect(desktop.movable, isFalse);
    final dragCount = desktop.calls
        .where((call) => call == 'startDragging')
        .length;
    await controller.startDragging();
    expect(
      desktop.calls.where((call) => call == 'startDragging').length,
      dragCount,
    );

    await controller.setLockCompactPosition(false);
    await controller.startDragging();
    expect(
      desktop.calls.where((call) => call == 'startDragging').length,
      dragCount + 1,
    );

    await controller.switchMode(WindowMode.full);
    expect(desktop.alwaysOnTop, isFalse);
    expect(desktop.skipTaskbar, isFalse);
  });

  test(
    'native compact preference failures roll controller state back',
    () async {
      final desktop = _FailingDesktopWindowService();
      final controller = WindowController(desktopService: desktop);
      await controller.initialize(showWindow: false);
      await controller.switchMode(WindowMode.compact);

      desktop.failAlwaysOnTop = true;
      await expectLater(
        controller.setCompactAlwaysOnTop(false),
        throwsStateError,
      );
      expect(controller.compactAlwaysOnTopPreference, isTrue);
      expect(desktop.alwaysOnTop, isTrue);

      desktop.failAlwaysOnTop = false;
      desktop.failSkipTaskbar = true;
      await expectLater(
        controller.setCompactSkipTaskbar(true),
        throwsStateError,
      );
      expect(controller.compactSkipTaskbarPreference, isFalse);
      expect(desktop.skipTaskbar, isFalse);

      desktop.failSkipTaskbar = false;
      desktop.failMovable = true;
      await expectLater(
        controller.setLockCompactPosition(true),
        throwsStateError,
      );
      expect(controller.lockCompactPositionPreference, isFalse);
      expect(controller.isLocked, isFalse);
      expect(desktop.resizable, isTrue);
    },
  );

  test('saved geometry is clamped, debounced, and resettable', () async {
    final desktop = FakeDesktopWindowService();
    final saved = <(WindowMode, WindowGeometry?)>[];
    final controller = WindowController(
      desktopService: desktop,
      initialFullGeometry: const WindowGeometry(
        position: Offset(2000, 2000),
        size: Size(1000, 700),
      ),
      visibleBoundsProvider: () => const Rect.fromLTWH(0, 0, 680, 460),
      onGeometryChanged: (mode, geometry) => saved.add((mode, geometry)),
    );
    await controller.initialize(showWindow: false);
    await controller.applyPreferences(
      startHidden: true,
      compactAlwaysOnTop: true,
      compactSkipTaskbar: false,
      lockCompactPosition: false,
      rememberWindowPosition: true,
      fullGeometry: const WindowGeometry(
        position: Offset(2000, 2000),
        size: Size(1000, 700),
      ),
      compactGeometry: null,
    );

    expect(desktop.geometry.position, const Offset(0, 0));
    expect(desktop.geometry.size, const Size(680, 460));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(saved, isNotEmpty);
    expect(saved.last.$1, WindowMode.full);

    desktop.geometry = const WindowGeometry(
      position: Offset(30, 40),
      size: Size(680, 460),
    );
    await desktop.emitWindowMoved();
    await desktop.emitWindowResized();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(saved.last.$2?.position, const Offset(30, 40));

    await controller.resetDefaultWindowPosition();
    expect(controller.geometryFor(WindowMode.full), isNull);
    expect(saved.where((entry) => entry.$2 == null), isNotEmpty);
  });

  test('geometry persistence failure rolls settings back', () async {
    final initial = AppSettings(
      fullGeometry: const AppWindowGeometry(
        x: 1,
        y: 2,
        width: 680,
        height: 460,
      ),
      compactGeometry: const AppWindowGeometry(
        x: 3,
        y: 4,
        width: 340,
        height: 520,
      ),
    );
    final repository = _MemorySettingsRepository(
      initial: initial,
      failSave: true,
    );
    final controller = SettingsController(repository: repository);
    await controller.initialize();
    final geometry = const AppWindowGeometry(
      x: 10,
      y: 20,
      width: 680,
      height: 460,
    );

    expect(await controller.setFullGeometry(geometry), isFalse);
    expect(controller.fullGeometry, initial.fullGeometry);
    expect(controller.compactGeometry, initial.compactGeometry);
    expect(repository.snapshot, initial);
    expect(await controller.resetWindowGeometries(), isFalse);
    expect(controller.fullGeometry, initial.fullGeometry);
    expect(controller.compactGeometry, initial.compactGeometry);
    expect(repository.snapshot, initial);
  });
}

class _MemorySettingsRepository implements SettingsRepository {
  _MemorySettingsRepository({AppSettings? initial, this.failSave = false})
    : snapshot = initial ?? AppSettings();

  final bool failSave;
  AppSettings snapshot;

  @override
  Future<AppSettingsLoadResult> load() async => AppSettingsLoadResult(
    settings: snapshot,
    source: SettingsLoadSource.primary,
  );

  @override
  Future<void> save(AppSettings value) async {
    if (failSave) throw StateError('save failed');
    snapshot = value;
  }

  @override
  Future<void> flushNow() async {}
}

class _FailingDesktopWindowService extends FakeDesktopWindowService {
  bool failAlwaysOnTop = false;
  bool failSkipTaskbar = false;
  bool failMovable = false;

  @override
  Future<void> setAlwaysOnTop(bool value) async {
    if (failAlwaysOnTop) throw StateError('always-on-top failed');
    await super.setAlwaysOnTop(value);
  }

  @override
  Future<void> setSkipTaskbar(bool value) async {
    if (failSkipTaskbar) throw StateError('skip-taskbar failed');
    await super.setSkipTaskbar(value);
  }

  @override
  Future<void> setMovable(bool value) async {
    if (failMovable) throw StateError('movable failed');
    await super.setMovable(value);
  }
}
