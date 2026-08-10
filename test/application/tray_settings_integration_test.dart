import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:litetodo/application/settings_controller.dart';
import 'package:litetodo/application/window_controller.dart';
import 'package:litetodo/domain/models/app_settings.dart';
import 'package:litetodo/infrastructure/platform/desktop_window_service.dart';
import 'package:litetodo/infrastructure/platform/global_hotkey_service.dart';
import 'package:litetodo/infrastructure/platform/startup_service.dart';
import 'package:litetodo/infrastructure/platform/system_tray_service.dart';
import 'package:litetodo/infrastructure/persistence/settings_repository.dart';

class _MemorySettingsRepository implements SettingsRepository {
  _MemorySettingsRepository([AppSettings? initial])
    : snapshot = initial ?? AppSettings();

  AppSettings snapshot;
  bool failSave = false;

  @override
  Future<AppSettingsLoadResult> load() async => AppSettingsLoadResult(
    settings: snapshot,
    source: SettingsLoadSource.primary,
  );

  @override
  Future<void> save(AppSettings next) async {
    if (failSave) throw StateError('controlled settings save failure');
    snapshot = next;
  }

  @override
  Future<void> flushNow() async {}
}

class _RecordingHotkeyService extends FakeGlobalHotkeyService {
  _RecordingHotkeyService(this.events);

  final List<String> events;

  @override
  Future<void> unregister() async {
    events.add('hotkey.unregister');
    await super.unregister();
  }
}

class _RecordingTrayService extends FakeSystemTrayService {
  _RecordingTrayService(this.events);

  final List<String> events;

  @override
  Future<void> dispose() async {
    events.add('tray.dispose');
    await super.dispose();
  }
}

class _RecordingDesktopService extends FakeDesktopWindowService {
  _RecordingDesktopService(this.events);

  final List<String> events;

  @override
  Future<void> destroy() async {
    events.add('desktop.destroy');
    await super.destroy();
  }
}

class _LegacyTrayService implements SystemTrayService {
  TrayActionHandler? handler;
  int updateCount = 0;
  bool alwaysOnTop = false;
  bool compact = false;

  @override
  Future<void> initialize(TrayActionHandler handler) async {
    this.handler = handler;
  }

  @override
  Future<void> dispose() async {}

  @override
  Future<void> update({
    required bool alwaysOnTop,
    required bool compact,
  }) async {
    updateCount += 1;
    this.alwaysOnTop = alwaysOnTop;
    this.compact = compact;
  }
}

void main() {
  test('tray menu has the exact V1 order, labels, and checkmarks', () {
    final menu = buildLiteTodoTrayMenu(
      alwaysOnTop: true,
      compact: false,
      launchAtStartup: true,
    );
    final items = menu.items!;

    expect(items.length, 9);
    expect(items.map((item) => item.type).toList(), <String>[
      'normal',
      'normal',
      'separator',
      'checkbox',
      'checkbox',
      'separator',
      'checkbox',
      'separator',
      'normal',
    ]);
    expect(items.map((item) => item.label).toList(), <String?>[
      '打开 LiteTodo',
      '快速添加',
      null,
      '窗口置顶',
      '紧凑模式',
      null,
      '开机启动',
      null,
      '退出',
    ]);
    expect(items[3].checked, isTrue);
    expect(items[4].checked, isFalse);
    expect(items[6].checked, isTrue);
  });

  test(
    'legacy tray services use the two-state fallback without recursion',
    () async {
      final tray = _LegacyTrayService();
      final window = WindowController(
        desktopService: FakeDesktopWindowService(),
        trayService: tray,
        launchAtStartup: true,
      );

      await window.initialize();
      await window.switchMode(WindowMode.compact);

      expect(tray.updateCount, greaterThanOrEqualTo(2));
      expect(tray.compact, isTrue);
      expect(tray.alwaysOnTop, isTrue);
      window.dispose();
    },
  );

  test(
    'startup tray action uses SettingsController and rolls back on failure',
    () async {
      final repository = _MemorySettingsRepository();
      final startup = FakeStartupService(failEnable: true);
      final settings = SettingsController(
        repository: repository,
        startupService: startup,
      );
      await settings.initialize();
      final tray = FakeSystemTrayService();
      final window = WindowController(
        desktopService: FakeDesktopWindowService(),
        trayService: tray,
        onLaunchAtStartupChanged: settings.setLaunchAtStartup,
      );
      await window.initialize();

      await tray.tap(TrayAction.toggleLaunchAtStartup);

      expect(settings.launchAtStartup, isFalse);
      expect(repository.snapshot.launchAtStartup, isFalse);
      expect(startup.enabled, isFalse);
      expect(tray.launchAtStartup, isFalse);
      expect(
        settings.lastPersistenceError,
        contains(SettingsController.startupPreferenceFailureMessage),
      );
      expect(tray.startupUpdateCount, greaterThanOrEqualTo(1));
      settings.dispose();
      window.dispose();
    },
  );

  test(
    'settings changes project one authoritative startup state to the tray',
    () async {
      final repository = _MemorySettingsRepository();
      final startup = FakeStartupService();
      final settings = SettingsController(
        repository: repository,
        startupService: startup,
      );
      await settings.initialize();
      final tray = FakeSystemTrayService();
      final window = WindowController(
        desktopService: FakeDesktopWindowService(),
        trayService: tray,
      );
      await window.initialize();
      settings.addListener(() {
        // Mirrors the one-way bootstrap projection without writing settings.
        unawaited(
          window.setLaunchAtStartupPreference(settings.launchAtStartup),
        );
      });

      expect(await settings.setLaunchAtStartup(true), isTrue);
      await window.setLaunchAtStartupPreference(settings.launchAtStartup);

      expect(startup.enabled, isTrue);
      expect(settings.launchAtStartup, isTrue);
      expect(window.launchAtStartup, isTrue);
      expect(tray.launchAtStartup, isTrue);
      settings.dispose();
      window.dispose();
    },
  );

  test(
    'successful startup tray action calls the platform once and syncs state',
    () async {
      final repository = _MemorySettingsRepository();
      final startup = FakeStartupService();
      final settings = SettingsController(
        repository: repository,
        startupService: startup,
      );
      await settings.initialize();
      final tray = FakeSystemTrayService();
      final window = WindowController(
        desktopService: FakeDesktopWindowService(),
        trayService: tray,
        onLaunchAtStartupChanged: settings.setLaunchAtStartup,
      );
      await window.initialize();
      final enableCountBefore = startup.enableCount;

      await tray.tap(TrayAction.toggleLaunchAtStartup);

      expect(startup.enableCount, enableCountBefore + 1);
      expect(settings.launchAtStartup, isTrue);
      expect(window.launchAtStartup, isTrue);
      expect(tray.launchAtStartup, isTrue);
      settings.dispose();
      window.dispose();
    },
  );

  test('exit tray action flushes before native cleanup', () async {
    final events = <String>[];
    final tray = _RecordingTrayService(events);
    final hotkey = _RecordingHotkeyService(events);
    final desktop = _RecordingDesktopService(events);
    final window = WindowController(
      desktopService: desktop,
      trayService: tray,
      hotkeyService: hotkey,
      flushHook: () async => events.add('flush'),
    );
    await window.initialize();
    events.clear();

    await tray.tap(TrayAction.exit);

    expect(events, <String>[
      'flush',
      'hotkey.unregister',
      'tray.dispose',
      'desktop.destroy',
    ]);
    expect(window.state, WindowLifecycleState.exiting);
    window.dispose();
  });

  test(
    'startup success is rolled back when settings persistence fails',
    () async {
      final repository = _MemorySettingsRepository()..failSave = true;
      final startup = FakeStartupService();
      final settings = SettingsController(
        repository: repository,
        startupService: startup,
      );
      await settings.initialize();

      expect(await settings.setLaunchAtStartup(true), isFalse);
      expect(startup.enabled, isFalse);
      expect(startup.enableCount, 1);
      expect(startup.disableCount, 1);
      expect(settings.launchAtStartup, isFalse);
      expect(
        settings.lastPersistenceError,
        contains('controlled settings save failure'),
      );
      settings.dispose();
    },
  );
}
