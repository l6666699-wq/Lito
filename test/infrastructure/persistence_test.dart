import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:litetodo/application/quick_add_controller.dart';
import 'package:litetodo/application/window_controller.dart';
import 'package:litetodo/application/workspace_controller.dart';
import 'package:litetodo/domain/models/app_data.dart';
import 'package:litetodo/infrastructure/persistence/app_data_repository.dart';
import 'package:litetodo/infrastructure/persistence/json_app_data_repository.dart';
import 'package:litetodo/infrastructure/persistence/safe_file_writer.dart';
import 'package:litetodo/infrastructure/platform/desktop_window_service.dart';

Future<Directory> _temporaryDirectory() =>
    Directory.systemTemp.createTemp('litetodo-persistence-');

AppData _snapshot(int revision, {String title = 'saved'}) {
  return AppData(
    schemaVersion: AppData.currentSchemaVersion,
    revision: revision,
    projects: const [],
    todos: const [],
    trash: <TrashItem>[
      TrashItem(
        id: 'trash-$revision',
        kind: 'todo',
        payload: <String, dynamic>{'title': title},
      ),
    ],
  );
}

class _FailOnceRepository implements AppDataRepository {
  _FailOnceRepository(this.snapshot);

  AppData snapshot;
  bool failNextSave = true;
  int saveCalls = 0;

  @override
  Future<AppDataLoadResult> load() async {
    return AppDataLoadResult(data: snapshot, source: AppDataLoadSource.primary);
  }

  @override
  Future<void> save(AppData next) async {
    saveCalls += 1;
    if (failNextSave) {
      failNextSave = false;
      throw StateError('controlled first-save failure');
    }
    snapshot = next;
  }
}

void main() {
  test('LITETODO_DATA_DIR accepts only an explicit absolute directory', () {
    expect(
      resolveLiteTodoDataDirectoryOverride(r'C:\temp\litetodo')!.path,
      r'C:\temp\litetodo',
    );
    expect(resolveLiteTodoDataDirectoryOverride(null), isNull);
    expect(
      () => resolveLiteTodoDataDirectoryOverride(r'relative\LiteTodo'),
      throwsStateError,
    );
  });

  test('empty directory loads empty data and save/load round trips', () async {
    final directory = await _temporaryDirectory();
    final repository = JsonAppDataRepository(directory: directory);

    final first = await repository.load();
    expect(first.isInitial, isTrue);
    expect(first.recoveryWarning, isNull);

    final source = _snapshot(42);
    await repository.save(source);
    final loaded = await repository.load();
    expect(loaded.source, AppDataLoadSource.primary);
    expect(loaded.data, source);
    expect(
      jsonDecode(await File('${directory.path}\\data.json').readAsString()),
      containsPair('revision', 42),
    );
  });

  test('invalid primary recovers the valid previous snapshot', () async {
    final directory = await _temporaryDirectory();
    final repository = JsonAppDataRepository(directory: directory);
    await repository.save(_snapshot(1, title: 'first'));
    await repository.save(_snapshot(2, title: 'second'));
    await File('${directory.path}\\data.json').writeAsString('{broken');

    final loaded = await repository.load();
    expect(loaded.recovered, isTrue);
    expect(loaded.data.revision, 1);
    expect(loaded.warning, contains('data.prev.json'));
  });

  test('failed temp validation leaves the primary file untouched', () async {
    final directory = await _temporaryDirectory();
    final target = File('${directory.path}\\data.json');
    await target.parent.create(recursive: true);
    await target.writeAsString('{"revision":1}', flush: true);
    final writer = const SafeFileWriter();

    await expectLater(
      writer.writeJson(
        target,
        '{invalid',
        validator: (contents) {
          jsonDecode(contents);
        },
      ),
      throwsFormatException,
    );
    expect(await target.readAsString(), '{"revision":1}');
  });

  test('concurrent saves are serialized and latest revision wins', () async {
    final directory = await _temporaryDirectory();
    final repository = JsonAppDataRepository(directory: directory);
    await Future.wait(<Future<void>>[
      for (var revision = 1; revision <= 20; revision++)
        repository.save(_snapshot(revision)),
    ]);
    final loaded = await repository.load();
    expect(loaded.data.revision, 20);
    final contents = await File('${directory.path}\\data.json').readAsString();
    expect(() => jsonDecode(contents), returnsNormally);
  });

  test('QuickAdd writes a real Todo and reloads after restart', () async {
    final directory = await _temporaryDirectory();
    final repository = JsonAppDataRepository(directory: directory);
    final workspace = WorkspaceController(repository: repository);
    await workspace.initialize();
    final initialRevision = workspace.revision;
    final window = WindowController(desktopService: FakeDesktopWindowService());
    await window.initialize();
    await window.openQuickAdd();
    final quickAdd = QuickAddController(
      windowController: window,
      onSubmit: workspace.addTodoAndFlush,
    );
    quickAdd.setDraft('persisted quick add');

    expect(await quickAdd.submit(), isTrue);
    expect(window.mode, WindowMode.full);
    expect(workspace.revision, initialRevision + 1);
    final restarted = WorkspaceController(repository: repository);
    await restarted.initialize();
    expect(
      restarted.todos.map((todo) => todo.title),
      contains('persisted quick add'),
    );
  });

  test(
    'QuickAdd failed save rolls back so the same draft retry adds once',
    () async {
      final seed = AppData(
        schemaVersion: AppData.currentSchemaVersion,
        revision: 12,
        projects: const [],
        todos: const [],
        trash: const [],
      );
      final repository = _FailOnceRepository(seed);
      final workspace = WorkspaceController(repository: repository);
      await workspace.initialize();
      final window = WindowController(
        desktopService: FakeDesktopWindowService(),
      );
      await window.initialize();
      await window.openQuickAdd();
      final quickAdd = QuickAddController(
        windowController: window,
        onSubmit: workspace.addTodoAndFlush,
      );
      quickAdd.setDraft('retry once');

      expect(await quickAdd.submit(), isFalse);
      expect(quickAdd.error, contains('添加失败'));
      expect(window.mode, WindowMode.quickAdd);
      expect(
        workspace.todos.where((todo) => todo.title == 'retry once'),
        isEmpty,
      );
      expect(workspace.revision, seed.revision);
      expect(workspace.hasUnsavedChanges, isFalse);
      expect(repository.snapshot, seed);

      expect(await quickAdd.submit(), isTrue);
      expect(window.mode, WindowMode.full);
      expect(repository.saveCalls, 2);
      expect(
        workspace.todos.where((todo) => todo.title == 'retry once'),
        hasLength(1),
      );
      expect(workspace.revision, seed.revision + 1);

      final restarted = WorkspaceController(repository: repository);
      await restarted.initialize();
      expect(
        restarted.todos.where((todo) => todo.title == 'retry once'),
        hasLength(1),
      );
      expect(restarted.revision, seed.revision + 1);
    },
  );

  test(
    'benchmark dataset switching never overwrites persistent AppData',
    () async {
      final directory = await _temporaryDirectory();
      final repository = JsonAppDataRepository(directory: directory);
      final workspace = WorkspaceController(repository: repository);
      await workspace.initialize();
      final before = (await repository.load()).data;
      expect(before, AppData.empty());
      expect(await File('${directory.path}\\data.json').exists(), isTrue);

      workspace.switchDataset(TodoDataset.thousand);
      expect(workspace.isBenchmarkMode, isTrue);
      await workspace.flushNow();
      final after = (await repository.load()).data;
      expect(after, before);
      expect(after.groups, isEmpty);
      expect(after.projects, isEmpty);
      expect(after.todos, isEmpty);
      expect(after.trash, isEmpty);
    },
  );
}
