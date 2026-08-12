import 'package:flutter_test/flutter_test.dart';
import 'package:litetodo/infrastructure/platform/global_hotkey_service.dart';
import 'package:litetodo/infrastructure/platform/single_instance_service.dart';
import 'package:litetodo/infrastructure/platform/system_tray_service.dart';

void main() {
  test(
    'tray icon helper resolves the bundled release asset beside the exe',
    () {
      final path = resolveBundledTrayIconPath(
        r'C:\build\windows\x64\runner\Release\litetodo.exe',
      ).replaceAll('\\', '/');
      expect(
        path,
        endsWith(
          '/build/windows/x64/runner/Release/data/flutter_assets/'
          'assets/icons/app/litetodo.ico',
        ),
      );
    },
  );

  test(
    'fake single-instance service forwards arguments to the primary process',
    () async {
      final service = FakeSingleInstanceService();
      List<String>? received;
      final primary = await service.ensureSingleInstance(
        arguments: const <String>['--quick-add'],
        onSecondInstance: (args) async => received = args,
      );
      expect(primary, isTrue);
      await service.emitSecondInstance(const <String>['--quick-add']);
      expect(received, <String>['--quick-add']);
    },
  );

  test('fake secondary instance never claims a writable primary', () async {
    final service = FakeSingleInstanceService(primary: false);
    final primary = await service.ensureSingleInstance(
      arguments: const <String>[],
      onSecondInstance: (_) async {},
    );
    expect(primary, isFalse);
  });

  test(
    'hotkey fake exposes registration failure and can trigger success',
    () async {
      final failed = FakeGlobalHotkeyService(failRegistration: true);
      await failed.register(onPressed: () async {});
      expect(failed.isRegistered, isFalse);
      expect(failed.error, contains('registration failed'));

      var triggered = false;
      final success = FakeGlobalHotkeyService();
      await success.register(onPressed: () async => triggered = true);
      await success.trigger();
      expect(success.isRegistered, isTrue);
      expect(triggered, isTrue);
    },
  );

  test('tray fake dispatches actions without native plugin calls', () async {
    final tray = FakeSystemTrayService();
    final received = <TrayAction>[];
    await tray.initialize((action) async => received.add(action));
    await tray.tapIcon();
    await tray.tap(TrayAction.open);
    await tray.tap(TrayAction.quickAdd);
    expect(received, <TrayAction>[
      TrayAction.open,
      TrayAction.open,
      TrayAction.quickAdd,
    ]);
    await tray.dispose();
    expect(tray.disposed, isTrue);
  });
}
