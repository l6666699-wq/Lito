import 'package:flutter_test/flutter_test.dart';
import 'package:litetodo/application/window_controller.dart';
import 'package:litetodo/infrastructure/platform/desktop_window_service.dart';
import 'package:litetodo/infrastructure/platform/global_hotkey_service.dart';

void main() {
  test('close preference hides to tray or exits the same window', () async {
    final trayDesktop = FakeDesktopWindowService();
    final trayController = WindowController(desktopService: trayDesktop);
    await trayController.initialize();
    await trayDesktop.emitCloseRequest();

    expect(trayController.state, WindowLifecycleState.hiddenToTray);
    expect(trayDesktop.calls, contains('hide'));

    final exitDesktop = FakeDesktopWindowService();
    final exitController = WindowController(desktopService: exitDesktop);
    await exitController.initialize();
    await exitController.setCloseToTray(false);
    await exitDesktop.emitCloseRequest();

    expect(exitController.state, WindowLifecycleState.exiting);
    expect(exitDesktop.calls, contains('destroy'));
  });

  test(
    'persisted hotkey registration can be delegated to settings startup',
    () async {
      final hotkey = FakeGlobalHotkeyService();
      final controller = WindowController(
        desktopService: FakeDesktopWindowService(),
        hotkeyService: hotkey,
        registerHotkeyOnInitialize: false,
      );

      await controller.initialize();

      expect(hotkey.registerCount, 0);
      expect(controller.isInitialized, isTrue);
    },
  );

  test(
    'remember position preference skips session geometry snapshots',
    () async {
      final desktop = FakeDesktopWindowService();
      final controller = WindowController(desktopService: desktop);
      await controller.initialize();
      await controller.setRememberWindowPosition(false);
      await controller.switchMode(WindowMode.compact);
      await controller.switchMode(WindowMode.full);

      expect(desktop.calls.where((call) => call == 'writeGeometry'), isEmpty);
    },
  );
}
