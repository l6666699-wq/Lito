import 'package:flutter_test/flutter_test.dart';
import 'package:litetodo/application/settings_controller.dart';
import 'package:litetodo/domain/models/app_settings.dart';
import 'package:litetodo/infrastructure/platform/global_hotkey_service.dart';
import 'package:litetodo/infrastructure/platform/startup_service.dart';
import 'package:litetodo/presentation/settings/settings_scope.dart';

void main() {
  test(
    'startup capability failure remains visible without blocking settings',
    () async {
      final controller = SettingsController(
        repository: InMemorySettingsRepository(
          initial: AppSettings(launchAtStartup: true),
        ),
        startupService: FakeStartupService(failEnable: true),
      );

      await controller.initialize();

      expect(controller.isInitialized, isTrue);
      expect(controller.lastPersistenceError, contains('Startup preference'));
      expect(await controller.setAccentColorKey('purple'), isTrue);
      controller.dispose();
    },
  );

  test(
    'hotkey registration failure remains visible without blocking settings',
    () async {
      final controller = SettingsController(
        repository: InMemorySettingsRepository(),
        globalHotkeyService: FakeGlobalHotkeyService(failRegistration: true),
      );

      await controller.initialize();

      expect(controller.isInitialized, isTrue);
      expect(controller.lastPersistenceError, contains('registration failed'));
      expect(await controller.setFontScale(1.1), isTrue);
      controller.dispose();
    },
  );
}
