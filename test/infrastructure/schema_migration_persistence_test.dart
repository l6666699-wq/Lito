import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:litetodo/application/workspace_controller.dart';
import 'package:litetodo/infrastructure/persistence/json_app_data_repository.dart';

void main() {
  test(
    'v1 file remains readable until next business save then becomes v2',
    () async {
      final directory = await Directory.systemTemp.createTemp('litetodo-v1-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}${Platform.pathSeparator}data.json');
      await file.writeAsString(
        jsonEncode(<String, dynamic>{
          'schemaVersion': 1,
          'revision': 4,
          'projects': <dynamic>[],
          'todos': <dynamic>[],
          'trash': <dynamic>[],
        }),
      );
      final repository = JsonAppDataRepository(directory: directory);
      final workspace = WorkspaceController(
        repository: repository,
        nowProvider: () => DateTime(2026, 8, 10),
      );
      await workspace.initialize();
      expect(workspace.appData.schemaVersion, 2);
      expect(
        (jsonDecode(await file.readAsString()) as Map)['schemaVersion'],
        1,
      );
      await workspace.addTodoAndFlush('migrated write');
      expect(
        (jsonDecode(await file.readAsString()) as Map)['schemaVersion'],
        2,
      );
    },
  );
}
