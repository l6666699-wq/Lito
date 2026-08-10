import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:litetodo/domain/models/app_settings.dart';
import 'package:litetodo/infrastructure/persistence/json_settings_repository.dart';
import 'package:litetodo/infrastructure/persistence/settings_repository.dart';

Future<Directory> _temporaryDirectory() =>
    Directory.systemTemp.createTemp('litetodo-settings-');

void main() {
  test('settings save/load serializes concurrent revisions', () async {
    final directory = await _temporaryDirectory();
    final repository = JsonSettingsRepository(directory: directory);
    expect((await repository.load()).source, SettingsLoadSource.defaults);

    await Future.wait(<Future<void>>[
      for (var revision = 1; revision <= 5; revision++)
        repository.save(AppSettings(revision: revision)),
    ]);
    final loaded = await repository.load();
    expect(loaded.settings.revision, 5);
    expect(
      jsonDecode(await File('${directory.path}\\settings.json').readAsString()),
      containsPair('revision', 5),
    );
    repository.dispose();
  });

  test(
    'invalid primary falls back to a valid previous settings file',
    () async {
      final directory = await _temporaryDirectory();
      final repository = JsonSettingsRepository(directory: directory);
      await repository.save(AppSettings(revision: 1));
      await repository.save(AppSettings(revision: 2));
      await File('${directory.path}\\settings.json').writeAsString('{broken');

      final loaded = await repository.load();
      expect(loaded.source, SettingsLoadSource.previous);
      expect(loaded.settings.revision, 1);
      expect(loaded.warning, contains('settings.prev.json'));
      repository.dispose();
    },
  );
}
