import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:litetodo/app/bootstrap.dart';
import 'package:litetodo/application/settings_controller.dart';
import 'package:litetodo/application/workspace_controller.dart';
import 'package:litetodo/domain/models/app_settings.dart';
import 'package:litetodo/infrastructure/logging/app_log_service.dart';
import 'package:litetodo/infrastructure/persistence/backup_service.dart';
import 'package:litetodo/presentation/settings/settings_scope.dart';

void main() {
  test('exit flush closes the app logger after existing flush order', () async {
    final directory = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}litetodo-bootstrap-log-${DateTime.now().microsecondsSinceEpoch}',
    );
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    final logger = AppLogService(dataDirectory: directory);
    await logger.initialize();
    final settings = SettingsController(
      repository: InMemorySettingsRepository(
        initial: AppSettings(autoBackup: false),
      ),
    );
    await settings.initialize();
    await flushLiteTodoOnExit(
      workspace: WorkspaceController(),
      settings: settings,
      backupService: BackupService(directory: directory),
      appLog: logger,
    );

    final logFile = File(
      '${directory.path}${Platform.pathSeparator}logs${Platform.pathSeparator}app.log',
    );
    expect(await logFile.exists(), isTrue);
    expect(await logFile.readAsString(), contains('app.shutdown'));
    expect(logger.isInitialized, isTrue);
    await logger.close();
    settings.dispose();
  });

  test('automatic backup failure uses sanitized app logging', () async {
    final directory = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}litetodo-bootstrap-backup-failure-${DateTime.now().microsecondsSinceEpoch}',
    );
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    final logger = AppLogService(dataDirectory: directory);
    await logger.initialize();
    final settings = SettingsController(
      repository: InMemorySettingsRepository(
        initial: AppSettings(autoBackup: true),
      ),
    );
    await settings.initialize();
    await flushLiteTodoOnExit(
      workspace: WorkspaceController(),
      settings: settings,
      backupService: BackupService(directory: directory),
      appLog: logger,
    );

    final content = await logger.logFile.readAsString(encoding: utf8);
    expect(content, contains('backup.auto_failed'));
    expect(content, contains('errorType=FileSystemException'));
    expect(content, isNot(contains('data.json does not exist')));
    settings.dispose();
  });
}
