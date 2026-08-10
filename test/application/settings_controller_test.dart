import 'package:flutter_test/flutter_test.dart';
import 'package:litetodo/application/settings_controller.dart';
import 'package:litetodo/domain/models/app_settings.dart';
import 'package:litetodo/infrastructure/platform/global_hotkey_service.dart';
import 'package:litetodo/infrastructure/platform/startup_service.dart';
import 'package:litetodo/infrastructure/persistence/settings_repository.dart';

class _MemorySettingsRepository implements SettingsRepository {
  _MemorySettingsRepository([AppSettings? initial])
    : snapshot = initial ?? AppSettings();

  AppSettings snapshot;
  bool failSave = false;
  int saveCount = 0;

  @override
  Future<AppSettingsLoadResult> load() async => AppSettingsLoadResult(
    settings: snapshot,
    source: SettingsLoadSource.primary,
  );

  @override
  Future<void> save(AppSettings next) async {
    saveCount += 1;
    if (failSave) throw StateError('controlled settings save failure');
    snapshot = next;
  }

  @override
  Future<void> flushNow() async {}
}

class _FailOnSecondHotkeyService implements GlobalHotkeyService {
  int registerCount = 0;
  bool _isRegistered = false;
  String? _error;
  AppHotkeyConfig? activeConfig;

  @override
  bool get isRegistered => _isRegistered;

  @override
  String? get error => _error;

  @override
  Future<void> register({
    required HotkeyPressedHandler onPressed,
    AppHotkeyConfig? config,
  }) async {
    registerCount += 1;
    if (config?.key == 'K') {
      _isRegistered = false;
      _error = 'Global hotkey registration failed (configured key).';
      return;
    }
    _isRegistered = true;
    activeConfig = config;
    _error = null;
  }

  @override
  Future<void> unregister() async {
    _isRegistered = false;
    activeConfig = null;
  }
}

void main() {
  test(
    'typed update persists revision and re-registers configured hotkey',
    () async {
      final repository = _MemorySettingsRepository();
      final startup = FakeStartupService();
      final hotkey = FakeGlobalHotkeyService();
      final controller = SettingsController(
        repository: repository,
        startupService: startup,
        globalHotkeyService: hotkey,
      );
      await controller.initialize();

      expect(await controller.setAccentColorKey('teal'), isTrue);
      expect(controller.settings.revision, 1);
      expect(repository.snapshot.accentColorKey, 'teal');
      expect(await controller.setGlobalHotkey('Ctrl+Shift+K'), isTrue);
      expect(controller.settings.globalHotkey.displayString, 'Ctrl+Shift+K');
      expect(hotkey.registeredConfigs.last.displayString, 'Ctrl+Shift+K');
      expect(await controller.setLaunchAtStartup(true), isTrue);
      expect(startup.enabled, isTrue);
      expect(controller.lastPersistenceError, isNull);
      controller.dispose();
    },
  );

  test('invalid and failed mutations retain the previous snapshot', () async {
    final repository = _MemorySettingsRepository();
    final controller = SettingsController(repository: repository);
    await controller.initialize();
    final initial = controller.settings;

    expect(await controller.setFontScale(2), isFalse);
    expect(controller.settings, initial);
    expect(controller.lastPersistenceError, isNotNull);

    repository.failSave = true;
    expect(await controller.setThemeMode(AppThemeMode.dark), isFalse);
    expect(controller.settings, initial);
    expect(repository.snapshot, initial);
    expect(
      controller.lastPersistenceError,
      contains('controlled settings save failure'),
    );
    controller.dispose();
  });

  test('last project setter supports an explicit null clear', () async {
    final repository = _MemorySettingsRepository(
      AppSettings(lastProjectId: 'project-focus'),
    );
    final controller = SettingsController(repository: repository);
    await controller.initialize();

    expect(await controller.setLastProjectId('project-home'), isTrue);
    expect(controller.lastProjectId, 'project-home');
    expect(await controller.setLastProjectId(null), isTrue);
    expect(controller.lastProjectId, isNull);
    expect(repository.snapshot.lastProjectId, isNull);
    controller.dispose();
  });

  test(
    'composite platform update rolls startup back when hotkey fails',
    () async {
      final repository = _MemorySettingsRepository();
      final startup = FakeStartupService();
      final hotkey = _FailOnSecondHotkeyService();
      final controller = SettingsController(
        repository: repository,
        startupService: startup,
        globalHotkeyService: hotkey,
      );
      await controller.initialize();
      final before = controller.settings;

      expect(
        await controller.updateSettings(
          launchAtStartup: true,
          globalHotkey: AppHotkeyConfig.parse('Ctrl+Shift+K'),
        ),
        isFalse,
      );
      expect(startup.enabled, isFalse);
      expect(controller.settings, before);
      expect(repository.snapshot, before);
      expect(hotkey.activeConfig, before.globalHotkey);
      expect(controller.lastPersistenceError, contains('configured key'));
      controller.dispose();
    },
  );

  test(
    'hotkey rollback continues when startup rollback reports failure',
    () async {
      final repository = _MemorySettingsRepository();
      final startup = FakeStartupService(failDisable: true);
      final hotkey = _FailOnSecondHotkeyService();
      final controller = SettingsController(
        repository: repository,
        startupService: startup,
        globalHotkeyService: hotkey,
      );
      await controller.initialize();
      final before = controller.settings;

      expect(
        await controller.updateSettings(
          launchAtStartup: true,
          globalHotkey: AppHotkeyConfig.parse('Ctrl+Shift+K'),
        ),
        isFalse,
      );
      // The fake startup plugin intentionally refuses rollback, but the
      // independent hotkey rollback still restores the previous registration.
      expect(startup.enabled, isTrue);
      expect(hotkey.activeConfig, before.globalHotkey);
      controller.dispose();
    },
  );
}
