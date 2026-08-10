import 'package:flutter_test/flutter_test.dart';

import 'package:litetodo/application/window_controller.dart';
import 'package:litetodo/infrastructure/platform/desktop_window_service.dart';

void main() {
  test('custom caption operations stay behind WindowController', () async {
    final desktop = FakeDesktopWindowService();
    final controller = WindowController(desktopService: desktop);

    await controller.startDragging();
    await controller.minimize();
    await controller.toggleMaximize();
    expect(controller.isMaximized, isTrue);
    await controller.toggleMaximize();
    expect(controller.isMaximized, isFalse);
    await controller.close();

    expect(
      desktop.calls,
      containsAllInOrder(<String>[
        'startDragging',
        'minimize',
        'isMaximized',
        'maximize',
        'isMaximized',
        'restore',
        'hide',
      ]),
    );
    expect(desktop.visible, isFalse);
  });
}
