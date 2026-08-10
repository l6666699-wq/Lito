import 'dart:io';

import 'package:flutter/widgets.dart';

import '../application/window_controller.dart';
import '../application/workspace_controller.dart';
import '../infrastructure/platform/desktop_window_service.dart';
import '../infrastructure/platform/global_hotkey_service.dart';
import '../infrastructure/platform/single_instance_service.dart';
import '../infrastructure/platform/system_tray_service.dart';
import '../infrastructure/persistence/json_app_data_repository.dart';
import 'litetodo_app.dart';

/// Windows-only startup boundary. A second process forwards its arguments
/// through the named-pipe gate and exits before `runApp`.
Future<void> bootstrap(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!Platform.isWindows) {
    runApp(const LiteTodoApp());
    return;
  }

  final desktop = WindowsDesktopWindowService();
  final tray = WindowsSystemTrayService();
  final hotkey = WindowsGlobalHotkeyService();
  final repository = await createDefaultAppDataRepository();
  final workspace = WorkspaceController(repository: repository);
  final windowController = WindowController(
    desktopWindowService: desktop,
    systemTrayService: tray,
    globalHotkeyService: hotkey,
    flushHook: workspace.flushNow,
  );
  final singleInstance = WindowsSingleInstanceService();

  final isPrimary = await singleInstance.ensureSingleInstance(
    arguments: arguments,
    onSecondInstance: (args) async {
      if (args.any((arg) => arg == '--quick-add' || arg == 'quick-add')) {
        await windowController.openQuickAdd();
      } else {
        await windowController.showFromTray();
      }
    },
  );
  if (!isPrimary) return;

  await workspace.initialize();
  await windowController.initialize();
  runApp(
    LiteTodoApp(controller: workspace, windowController: windowController),
  );
}
