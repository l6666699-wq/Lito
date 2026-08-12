import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../application/data_transfer_controller.dart';
import '../application/settings_controller.dart';
import '../application/sticky_notes_controller.dart';
import '../application/window_controller.dart';
import '../application/workspace_controller.dart';
import '../domain/models/app_settings.dart';
import '../domain/services/todo_move_service.dart';
import '../infrastructure/logging/app_log_service.dart';
import '../infrastructure/platform/desktop_window_service.dart';
import '../infrastructure/platform/data_directory_service.dart';
import '../infrastructure/platform/file_selector_picker.dart';
import '../infrastructure/platform/global_hotkey_service.dart';
import '../infrastructure/platform/single_instance_service.dart';
import '../infrastructure/platform/system_tray_service.dart';
import '../infrastructure/platform/startup_service.dart';
import '../infrastructure/platform/sticky_notes_window_service.dart';
import '../infrastructure/persistence/json_app_data_repository.dart';
import '../infrastructure/persistence/backup_service.dart';
import '../infrastructure/persistence/data_transfer_service.dart';
import '../infrastructure/persistence/json_settings_repository.dart';
import 'litetodo_app.dart';
import 'sticky_notes_app.dart';

/// Windows-only startup boundary. A second process forwards its arguments
/// through the named-pipe gate and exits before `runApp`.
Future<void> bootstrap(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();

  // The Windows runner launches each sticky note in its own Flutter engine.
  // Branch before the primary single-instance/persistence graph so a note is
  // a read-only projection and never registers a second tray or hotkey.
  if (Platform.isWindows) {
    final stickyArguments = StickyWindowLaunchArguments.parse(arguments);
    if (stickyArguments != null) {
      await bootstrapStickyNotesWindow(stickyArguments);
      return;
    }
  }

  if (!Platform.isWindows) {
    runApp(const LiteTodoApp());
    return;
  }

  final desktop = WindowsDesktopWindowService();
  final stickyWindowService = SafeStickyNotesWindowService(
    WindowsStickyNotesWindowService(),
  );
  final tray = WindowsSystemTrayService();
  final hotkey = WindowsGlobalHotkeyService();
  final repository = await createDefaultAppDataRepository();
  final workspace = WorkspaceController(repository: repository);
  installStickyMutationHandler(workspace);
  final settingsRepository = await createDefaultSettingsRepository();
  final settingsDirectory = await settingsRepository.dataDirectory;
  final appLog = AppLogService(dataDirectory: settingsDirectory);
  await appLog.initialize();
  appLog.installGlobalErrorHandlers();
  unawaited(
    appLog.logEvent(
      'app.bootstrap',
      metadata: const <String, Object?>{
        'phase': 'startup',
        'platform': 'windows',
      },
    ),
  );
  final backupService = BackupService(directory: settingsDirectory);
  final dataTransferController = DataTransferController(
    workspace: workspace,
    service: DataTransferService(backupService: backupService),
    filePicker: const FileSelectorPicker(),
  );
  final startup = WindowsStartupService();
  late final WindowController windowController;
  final settingsController = SettingsController(
    repository: settingsRepository,
    startupService: startup,
    globalHotkeyService: hotkey,
    onGlobalHotkeyPressed: () => windowController.openQuickAdd(),
  );
  windowController = WindowController(
    desktopWindowService: desktop,
    systemTrayService: tray,
    globalHotkeyService: hotkey,
    registerHotkeyOnInitialize: false,
    onLaunchAtStartupChanged: (value) =>
        settingsController.setLaunchAtStartup(value),
    visibleBoundsProvider: desktop.readVisibleBounds,
    onGeometryChanged: (mode, geometry) async {
      if (!settingsController.isInitialized) return;
      final settingsMode = mode == WindowMode.compact
          ? AppWindowMode.compact
          : AppWindowMode.full;
      await settingsController.setWindowGeometry(
        settingsMode,
        _toAppWindowGeometry(geometry),
      );
    },
    flushHook: () => flushLiteTodoOnExit(
      workspace: workspace,
      settings: settingsController,
      backupService: backupService,
      appLog: appLog,
    ),
  );
  final dataDirectoryService = WindowsDataDirectoryService(
    directory: settingsDirectory,
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
  if (!isPrimary) {
    await appLog.close();
    return;
  }

  await workspace.initialize();
  if (workspace.recoveryWarning != null) {
    unawaited(
      appLog.logEvent(
        'workspace.recovery',
        metadata: const <String, Object?>{
          'source': 'workspace',
          'reason': 'recovery',
        },
      ),
    );
  }
  // Initialize the native window hidden before registering the global hotkey.
  // A hotkey or second-instance request can then safely queue against a ready
  // window_manager handle without flashing the default Full layout.
  await windowController.initialize(showWindow: false);
  try {
    await settingsController.initialize();
  } catch (error, stackTrace) {
    await appLog.logError(
      code: 'settings.initialize_failed',
      error: error,
      stackTrace: stackTrace,
      metadata: const <String, Object?>{
        'source': 'settings',
        'action': 'initialize',
      },
    );
    // Keep the shell available so the settings page can surface a localized
    // platform error instead of failing the whole process during startup.
  }
  final settings = settingsController.settings;
  await windowController.applyPreferences(
    startHidden: settings.startHidden,
    compactAlwaysOnTop: settings.compactAlwaysOnTop,
    compactSkipTaskbar: settings.compactSkipTaskbar,
    lockCompactPosition: settings.lockCompactPosition,
    rememberWindowPosition: settings.rememberWindowPosition,
    launchAtStartup: settings.launchAtStartup,
    fullGeometry: _toDesktopWindowGeometry(settings.fullGeometry),
    compactGeometry: _toDesktopWindowGeometry(settings.compactGeometry),
  );
  // SettingsController remains the single authority for persisted values;
  // this listener only projects its startup flag onto the tray checkmark.
  settingsController.addListener(() {
    unawaited(
      _syncTrayStartupPreference(
        windowController,
        settingsController.launchAtStartup,
      ),
    );
  });
  await windowController.setCloseToTray(settings.closeToTray);
  final explicitActivation = windowController.hasExplicitActivation;
  final explicitQuickAdd =
      windowController.explicitActivationMode == WindowMode.quickAdd;
  if (!explicitQuickAdd && settings.defaultWindowMode != AppWindowMode.full) {
    await windowController.switchMode(
      settings.defaultWindowMode == AppWindowMode.compact
          ? WindowMode.compact
          : WindowMode.quickAdd,
    );
  }
  if (explicitQuickAdd && windowController.mode != WindowMode.quickAdd) {
    await windowController.openQuickAdd();
  }
  if (explicitActivation) {
    await windowController.showFromTray();
  } else if (settings.startHidden) {
    await windowController.hideToTray();
  } else {
    await windowController.showFromTray();
  }
  windowController.consumeExplicitActivation();
  runApp(
    LiteTodoApp(
      controller: workspace,
      windowController: windowController,
      settingsController: settingsController,
      backupService: backupService,
      dataTransferController: dataTransferController,
      dataDirectoryService: dataDirectoryService,
      stickyNotesWindowService: stickyWindowService,
    ),
  );
}

/// Starts a secondary engine's read-only sticky projection.
Future<void> bootstrapStickyNotesWindow(
  StickyWindowLaunchArguments arguments,
) async {
  final workspace = WorkspaceController();
  final channel = StickyNotesSecondaryChannel();
  final stickySettings = ValueNotifier<AppSettings>(AppSettings());
  var receivedSnapshotSettings = false;

  void applySnapshot(String snapshot) {
    applyStickySnapshot(workspace, snapshot);
    final settings = readStickySnapshotSettings(snapshot);
    if (settings != null) {
      receivedSnapshotSettings = true;
      stickySettings.value = settings;
    }
  }

  try {
    final snapshot = await channel.readSnapshot(arguments.key);
    if (snapshot != null) applySnapshot(snapshot);
  } catch (_) {
    // The channel listener below fills the startup gap once primary syncs.
  }
  channel.listen(
    onSnapshot: (snapshot) {
      try {
        applySnapshot(snapshot);
      } catch (_) {
        // Ignore malformed/stale snapshots; the next primary revision will
        // retry and the existing projection remains visible.
      }
    },
  );
  runApp(
    StickyNotesSecondaryApp(
      workspace: workspace,
      windowService: channel,
      projectId: arguments.projectId,
      groupId: arguments.groupId,
      windowKey: arguments.key,
      settingsListenable: stickySettings,
    ),
  );
  unawaited(
    _hydrateStickyNotesWindow(
      channel: channel,
      settings: stickySettings,
      key: arguments.key,
      hasSnapshotSettings: () => receivedSnapshotSettings,
      applySnapshot: applySnapshot,
    ),
  );
}

Future<void> _hydrateStickyNotesWindow({
  required StickyNotesSecondaryChannel channel,
  required ValueNotifier<AppSettings> settings,
  required String key,
  required bool Function() hasSnapshotSettings,
  required void Function(String snapshot) applySnapshot,
}) async {
  // The primary may sync while this engine is wiring its first frame; read the
  // retained snapshot once more without blocking the initial window paint.
  try {
    final retrySnapshot = await channel.readSnapshot(key);
    if (retrySnapshot != null) applySnapshot(retrySnapshot);
  } catch (_) {}
  if (hasSnapshotSettings()) return;
  try {
    final repository = await createDefaultSettingsRepository();
    settings.value = (await repository.load()).settings;
  } catch (_) {
    // The primary engine still sends its live settings snapshot after startup.
  }
}

/// Installs the primary-engine endpoint for mutations originating in a
/// secondary sticky-note engine.  The native runner forwards the request over
/// the primary engine's channel; only this handler may mutate and flush the
/// authoritative workspace.
void installStickyMutationHandler(WorkspaceController workspace) {
  const channel = MethodChannel('litetodo/sticky_windows');
  channel.setMethodCallHandler((call) async {
    if (call.method != 'mutation') return null;
    final rawArguments = call.arguments;
    if (rawArguments is! Map) {
      throw PlatformException(
        code: 'invalid_mutation',
        message: 'The sticky mutation payload is invalid.',
      );
    }
    final arguments = Map<String, Object?>.from(rawArguments);
    final operation = arguments['operation'];
    final todoId = arguments['todoId'] as String?;
    final groupId = arguments['groupId'] as String?;
    switch (operation) {
      case 'toggleCompleted':
        if (todoId == null || todoId.isEmpty) {
          throw PlatformException(
            code: 'invalid_mutation',
            message: 'A todo ID is required for completion changes.',
          );
        }
        workspace.toggleTodoCompleted(todoId);
        await workspace.flushNow();
      case 'editTitle':
        final title = arguments['title'] as String?;
        if (todoId == null || todoId.isEmpty || title == null) {
          throw PlatformException(
            code: 'invalid_mutation',
            message: 'A todo ID and title are required for edits.',
          );
        }
        workspace.editTodoTitle(todoId, title);
        await workspace.flushNow();
      case 'addTodo':
        final title = arguments['title'] as String?;
        if (title == null || title.trim().isEmpty) {
          throw PlatformException(
            code: 'invalid_mutation',
            message: 'A title is required for a new todo.',
          );
        }
        await workspace.addTodoAndFlush(
          title,
          projectId: arguments['projectId'] as String?,
          groupId: groupId,
        );
      case 'reorderTodo':
        final targetId = arguments['targetId'] as String?;
        final rawPosition = arguments['position'] as String?;
        TodoMovePosition? position;
        for (final candidate in TodoMovePosition.values) {
          if (candidate.name == rawPosition) {
            position = candidate;
            break;
          }
        }
        if (todoId == null || targetId == null || position == null) {
          throw PlatformException(
            code: 'invalid_mutation',
            message: 'A moving todo, target todo and position are required.',
          );
        }
        workspace.moveTodo(todoId, targetId, position);
        await workspace.flushNow();
      default:
        throw PlatformException(
          code: 'unknown_mutation',
          message: 'Unsupported sticky mutation: $operation',
        );
    }
    return null;
  });
}

Future<void> _syncTrayStartupPreference(
  WindowController windowController,
  bool launchAtStartup,
) async {
  try {
    await windowController.setLaunchAtStartupPreference(launchAtStartup);
  } catch (_) {
    // A tray refresh is best-effort; the settings snapshot and its stable
    // persistence error remain authoritative when the native menu is busy.
  }
}

WindowGeometry? _toDesktopWindowGeometry(AppWindowGeometry? geometry) {
  if (geometry == null || !geometry.isValid) return null;
  return WindowGeometry(
    position: Offset(geometry.x, geometry.y),
    size: Size(geometry.width, geometry.height),
  );
}

AppWindowGeometry? _toAppWindowGeometry(WindowGeometry? geometry) {
  if (geometry == null) return null;
  return AppWindowGeometry(
    x: geometry.position.dx,
    y: geometry.position.dy,
    width: geometry.size.width,
    height: geometry.size.height,
  );
}

/// Flushes the local snapshot and settings during native shutdown.  Daily
/// backup is best-effort: a corrupt or locked backup target is logged, but it
/// cannot prevent the settings flush or normal window destruction.
Future<void> flushLiteTodoOnExit({
  required WorkspaceController workspace,
  required SettingsController settings,
  required BackupService backupService,
  AppLogService? appLog,
}) async {
  Object? firstError;
  StackTrace? firstStack;
  try {
    await workspace.flushNow();
  } catch (error, stackTrace) {
    firstError = error;
    firstStack = stackTrace;
    if (appLog != null) {
      await appLog.logError(
        code: 'workspace.flush_failed',
        error: error,
        stackTrace: stackTrace,
        metadata: const <String, Object?>{
          'source': 'workspace',
          'action': 'flush',
        },
      );
    }
  }

  if (firstError == null && settings.autoBackup) {
    try {
      await backupService.createDailyBackup();
    } catch (error, stackTrace) {
      if (appLog != null) {
        await appLog.logError(
          code: 'backup.auto_failed',
          error: error,
          stackTrace: stackTrace,
          metadata: const <String, Object?>{
            'source': 'repository',
            'action': 'backup',
          },
        );
      } else {
        stderr.writeln('LiteTodo automatic backup failed.');
      }
    }
  }

  try {
    await settings.flushNow();
  } catch (error, stackTrace) {
    firstError ??= error;
    firstStack ??= stackTrace;
    if (appLog != null) {
      await appLog.logError(
        code: 'settings.flush_failed',
        error: error,
        stackTrace: stackTrace,
        metadata: const <String, Object?>{
          'source': 'settings',
          'action': 'flush',
        },
      );
    }
  }
  if (appLog != null) {
    await appLog.logEvent(
      'app.shutdown',
      metadata: const <String, Object?>{'phase': 'shutdown'},
    );
    await appLog.close();
  }
  final error = firstError;
  if (error != null) {
    Error.throwWithStackTrace(error, firstStack!);
  }
}
