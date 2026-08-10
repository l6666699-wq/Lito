import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:litetodo/app/bootstrap.dart';
import 'package:litetodo/domain/models/app_data.dart';
import 'package:litetodo/domain/models/app_settings.dart';
import 'package:litetodo/application/settings_controller.dart';
import 'package:litetodo/application/workspace_controller.dart';
import 'package:litetodo/infrastructure/persistence/backup_service.dart';
import 'package:litetodo/presentation/settings/settings_scope.dart';

void main() {
  test('exit flush creates a daily backup only when enabled', () async {
    final directory = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}LiteTodo-exit-test',
    );
    await directory.create(recursive: true);
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    await File(
      '${directory.path}${Platform.pathSeparator}data.json',
    ).writeAsString(jsonEncode(AppData.empty().toJson()), flush: true);

    final enabled = SettingsController(
      repository: InMemorySettingsRepository(
        initial: AppSettings(autoBackup: true),
      ),
    );
    await enabled.initialize();
    await flushLiteTodoOnExit(
      workspace: WorkspaceController(),
      settings: enabled,
      backupService: BackupService(directory: directory),
    );
    expect(await BackupService(directory: directory).listBackups(), isNotEmpty);
    enabled.dispose();

    final disabledDirectory = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}LiteTodo-exit-disabled-test',
    );
    await disabledDirectory.create(recursive: true);
    addTearDown(() async {
      if (await disabledDirectory.exists()) {
        await disabledDirectory.delete(recursive: true);
      }
    });
    await File(
      '${disabledDirectory.path}${Platform.pathSeparator}data.json',
    ).writeAsString(jsonEncode(AppData.empty().toJson()), flush: true);
    final disabled = SettingsController(
      repository: InMemorySettingsRepository(
        initial: AppSettings(autoBackup: false),
      ),
    );
    await disabled.initialize();
    await flushLiteTodoOnExit(
      workspace: WorkspaceController(),
      settings: disabled,
      backupService: BackupService(directory: disabledDirectory),
    );
    expect(
      await BackupService(directory: disabledDirectory).listBackups(),
      isEmpty,
    );
    disabled.dispose();
  });
}
