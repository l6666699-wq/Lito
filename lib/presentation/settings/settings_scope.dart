import 'dart:io';

import 'package:flutter/widgets.dart';

import '../../application/data_transfer_controller.dart';
import '../../application/settings_controller.dart';
import '../../application/window_controller.dart';
import '../../application/workspace_controller.dart';
import '../../domain/models/app_settings.dart';
import '../../infrastructure/platform/data_directory_service.dart';
import '../../infrastructure/persistence/backup_service.dart';
import '../../infrastructure/persistence/settings_repository.dart';

/// The app-level bridge used by the settings route.  FullAppShell stays
/// unaware of settings dependencies; SettingsPage resolves them from here.
class SettingsScope extends InheritedNotifier<SettingsController> {
  const SettingsScope({
    super.key,
    required SettingsController settingsController,
    required this.backupService,
    this.dataTransferController,
    required this.workspaceController,
    required this.windowController,
    required this.dataDirectoryService,
    required super.child,
  }) : settingsController = settingsController,
       super(notifier: settingsController);

  final SettingsController settingsController;
  final BackupService backupService;
  final DataTransferController? dataTransferController;
  final WorkspaceController workspaceController;
  final WindowController windowController;
  final DataDirectoryService dataDirectoryService;

  static SettingsScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    if (scope == null) {
      throw FlutterError('SettingsScope is missing above SettingsPage.');
    }
    return scope;
  }

  static SettingsScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsScope>();
}

/// Non-Windows and widget-test default.  It deliberately never resolves an
/// Application Support path or writes to a real user profile.
class InMemorySettingsRepository implements SettingsRepository {
  InMemorySettingsRepository({AppSettings? initial})
    : _settings = initial ?? AppSettings();

  AppSettings _settings;

  @override
  Future<AppSettingsLoadResult> load() async => AppSettingsLoadResult(
    settings: _settings,
    source: SettingsLoadSource.primary,
  );

  @override
  Future<void> save(AppSettings snapshot) async {
    _settings = snapshot;
  }

  @override
  Future<void> flushNow() async {}
}

BackupService createTestBackupService() {
  return BackupService(
    directory: Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}LiteTodo',
    ),
  );
}
