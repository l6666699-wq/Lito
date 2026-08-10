import 'package:flutter_test/flutter_test.dart';
import 'package:litetodo/domain/models/app_settings.dart';
import 'package:litetodo/infrastructure/platform/global_hotkey_service.dart';
import 'package:litetodo/infrastructure/platform/startup_service.dart';

void main() {
  test(
    'fake startup service exposes real enable/disable state transitions',
    () async {
      final service = FakeStartupService();
      expect(await service.isEnabled(), isFalse);
      expect(await service.enable(), isTrue);
      expect(await service.isEnabled(), isTrue);
      expect(await service.disable(), isTrue);
      expect(await service.isEnabled(), isFalse);
    },
  );

  test('fake hotkey records configured re-registration and failure', () async {
    final service = FakeGlobalHotkeyService();
    await service.register(
      onPressed: () async {},
      config: AppHotkeyConfig.parse('Ctrl+Shift+K'),
    );
    expect(service.activeConfig?.displayString, 'Ctrl+Shift+K');
    await service.register(
      onPressed: () async {},
      config: const AppHotkeyConfig.defaultValue(),
    );
    expect(service.registeredConfigs, hasLength(2));

    final failed = FakeGlobalHotkeyService(failRegistration: true);
    await failed.register(onPressed: () async {});
    expect(failed.isRegistered, isFalse);
    expect(failed.error, contains('registration failed'));
  });
}
