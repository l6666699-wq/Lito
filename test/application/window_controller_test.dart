import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:litetodo/application/quick_add_controller.dart';
import 'package:litetodo/application/window_controller.dart';
import 'package:litetodo/infrastructure/platform/desktop_window_service.dart';
import 'package:litetodo/infrastructure/platform/global_hotkey_service.dart';
import 'package:litetodo/infrastructure/platform/system_tray_service.dart';

void main() {
  test(
    'Full and Compact transitions remain stable after 100 round trips',
    () async {
      final desktop = FakeDesktopWindowService();
      final controller = WindowController(desktopService: desktop);
      await controller.initialize();

      for (var i = 0; i < 100; i++) {
        await controller.switchMode(WindowMode.compact);
        await controller.switchMode(WindowMode.full);
      }

      expect(controller.mode, WindowMode.full);
      expect(controller.state, WindowLifecycleState.fullVisible);
      expect(controller.isHidden, isFalse);
      expect(desktop.geometry.size, WindowLayout.full.size);
    },
  );

  test(
    'QuickAdd restores previous mode after 100 submissions/cancels',
    () async {
      final controller = WindowController(
        desktopService: FakeDesktopWindowService(),
      );
      await controller.initialize();
      await controller.switchMode(WindowMode.compact);

      for (var i = 0; i < 100; i++) {
        await controller.openQuickAdd();
        expect(controller.previousMode, WindowMode.compact);
        if (i.isEven) {
          await controller.completeQuickAdd();
        } else {
          await controller.cancelQuickAdd();
        }
        expect(controller.mode, WindowMode.compact);
        expect(controller.state, WindowLifecycleState.compactVisible);
        expect(controller.previousMode, isNull);
      }
    },
  );

  test('QuickAdd centers on the primary display visible bounds', () async {
    final desktop = FakeDesktopWindowService()
      ..visibleBounds = const Rect.fromLTWH(100, 200, 1920, 1080);
    final controller = WindowController(desktopService: desktop);
    await controller.initialize();

    await controller.openQuickAdd();

    expect(
      desktop.geometry,
      const WindowGeometry(position: Offset(750, 638), size: Size(620, 204)),
    );
  });

  test('hidden Compact -> QuickAdd -> Esc restores the hidden state', () async {
    final desktop = FakeDesktopWindowService();
    final controller = WindowController(desktopService: desktop);
    await controller.initialize();
    await controller.switchMode(WindowMode.compact);
    await controller.hideToTray();

    await controller.openQuickAdd();
    expect(controller.mode, WindowMode.quickAdd);
    expect(controller.isHidden, isFalse);
    expect(controller.previousMode, WindowMode.compact);

    desktop.calls.clear();
    await controller.cancelQuickAdd();
    expect(controller.mode, WindowMode.compact);
    expect(controller.state, WindowLifecycleState.hiddenToTray);
    expect(controller.isHidden, isTrue);
    expect(desktop.visible, isFalse);
    final hideIndex = desktop.calls.indexOf('hide');
    final restoreIndex = desktop.calls.indexWhere(
      (call) => call == 'configure:340.0x520.0',
    );
    expect(hideIndex, isNonNegative);
    expect(restoreIndex, isNonNegative);
    expect(hideIndex, lessThan(restoreIndex));
  });

  test(
    'QuickAddController submits through the existing window and restores it',
    () async {
      final controller = WindowController(
        desktopService: FakeDesktopWindowService(),
      );
      await controller.initialize();
      await controller.openQuickAdd();
      final submitted = <String>[];
      final quickAdd = QuickAddController(
        windowController: controller,
        onSubmit: (title) async => submitted.add(title),
      );

      quickAdd.setDraft('  first thought  ');
      expect(await quickAdd.submit(), isTrue);
      expect(submitted, <String>['first thought']);
      expect(controller.mode, WindowMode.full);
      expect(controller.state, WindowLifecycleState.fullVisible);
    },
  );

  test(
    'lock captures an anchor, restores it on move, and unlocks rules',
    () async {
      final desktop = FakeDesktopWindowService();
      desktop.geometry = const WindowGeometry(
        position: Offset(10, 20),
        size: Size(340, 520),
      );
      final controller = WindowController(desktopService: desktop);
      await controller.initialize();

      await controller.setLocked(true);
      expect(controller.isLocked, isTrue);
      expect(desktop.resizable, isFalse);
      desktop.geometry = const WindowGeometry(
        position: Offset(900, 900),
        size: Size(340, 520),
      );
      await desktop.emitWindowMoved();
      expect(desktop.geometry.position, const Offset(10, 20));

      await controller.setLocked(false);
      expect(controller.isLocked, isFalse);
      expect(desktop.resizable, isTrue);
    },
  );

  test(
    'locked Full -> Compact refreshes the anchor to Compact bounds',
    () async {
      final desktop = FakeDesktopWindowService();
      desktop.geometry = const WindowGeometry(
        position: Offset(10, 20),
        size: Size(860, 620),
      );
      final controller = WindowController(desktopService: desktop);
      await controller.initialize();
      await controller.setLocked(true);

      await controller.switchMode(WindowMode.compact);
      expect(desktop.geometry.size, WindowLayout.compact.size);

      desktop.geometry = const WindowGeometry(
        position: Offset(900, 900),
        size: Size(340, 520),
      );
      await desktop.emitWindowMoved();

      expect(desktop.geometry.position, const Offset(10, 20));
      expect(desktop.geometry.size, WindowLayout.compact.size);
    },
  );

  test('rapid concurrent mode requests are serialized', () async {
    final controller = WindowController(
      desktopService: FakeDesktopWindowService(),
    );
    await controller.initialize();
    await Future.wait(<Future<void>>[
      for (var i = 0; i < 50; i++) controller.switchMode(WindowMode.compact),
      for (var i = 0; i < 50; i++) controller.switchMode(WindowMode.full),
    ]);
    expect(controller.state, WindowLifecycleState.fullVisible);
    expect(controller.previousMode, isNull);
  });

  test(
    'exit flushes, unregisters hotkey/tray, then destroys the window',
    () async {
      final events = <String>[];
      final desktop = FakeDesktopWindowService();
      final tray = FakeSystemTrayService();
      final hotkey = FakeGlobalHotkeyService();
      final controller = WindowController(
        desktopService: desktop,
        trayService: tray,
        hotkeyService: hotkey,
        flushHook: () async => events.add('flush'),
      );
      await controller.initialize();
      await controller.exit();

      expect(events, <String>['flush']);
      expect(hotkey.unregisterCount, 1);
      expect(tray.disposed, isTrue);
      expect(desktop.calls.last, 'destroy');
      expect(controller.state, WindowLifecycleState.exiting);
    },
  );

  test('exit cleans up native resources when the flush hook fails', () async {
    final desktop = FakeDesktopWindowService();
    final tray = FakeSystemTrayService();
    final hotkey = FakeGlobalHotkeyService();
    final controller = WindowController(
      desktopService: desktop,
      trayService: tray,
      hotkeyService: hotkey,
      flushHook: () async => throw StateError('flush failed'),
    );
    await controller.initialize();

    await expectLater(controller.exit(), throwsStateError);

    expect(hotkey.unregisterCount, 1);
    expect(tray.disposed, isTrue);
    expect(desktop.calls.last, 'destroy');
    expect(controller.state, WindowLifecycleState.exiting);
  });

  test('exit cleanup survives controller disposal while flushing', () async {
    final gate = Completer<void>();
    final desktop = FakeDesktopWindowService();
    final tray = FakeSystemTrayService();
    final hotkey = FakeGlobalHotkeyService();
    final controller = WindowController(
      desktopService: desktop,
      trayService: tray,
      hotkeyService: hotkey,
      flushHook: () => gate.future,
    );
    await controller.initialize();

    final exiting = controller.exit();
    controller.dispose();
    gate.complete();

    await expectLater(exiting, completes);
    expect(hotkey.unregisterCount, 1);
    expect(tray.disposed, isTrue);
    expect(desktop.calls.last, 'destroy');
  });

  test(
    'hotkey registration failures are observable without blocking startup',
    () async {
      final hotkey = FakeGlobalHotkeyService(failRegistration: true);
      final controller = WindowController(
        desktopService: FakeDesktopWindowService(),
        hotkeyService: hotkey,
      );
      await controller.initialize();
      expect(controller.isInitialized, isTrue);
      expect(controller.hotkeyError, contains('registration failed'));
    },
  );

  test('tray actions route to the same WindowController', () async {
    final tray = FakeSystemTrayService();
    final controller = WindowController(
      desktopService: FakeDesktopWindowService(),
      trayService: tray,
    );
    await controller.initialize();

    await tray.tap(TrayAction.toggleCompact);
    expect(controller.mode, WindowMode.compact);
    await tray.tap(TrayAction.quickAdd);
    expect(controller.mode, WindowMode.quickAdd);
    await tray.tap(TrayAction.open);
    expect(controller.mode, WindowMode.quickAdd);
    await controller.cancelQuickAdd();
    await tray.tap(TrayAction.exit);
    expect(controller.state, WindowLifecycleState.exiting);
  });
}
