import 'package:flutter_test/flutter_test.dart';
import 'package:litetodo/app/theme/project_palette.dart';
import 'package:litetodo/application/workspace_controller.dart';
import 'package:litetodo/domain/models/app_data.dart';
import 'package:litetodo/infrastructure/persistence/app_data_repository.dart';

class _RecordingRepository implements AppDataRepository {
  _RecordingRepository(this.result);

  AppDataLoadResult result;
  AppData? saved;
  int saveCalls = 0;

  @override
  Future<AppDataLoadResult> load() async => result;

  @override
  Future<void> save(AppData snapshot) async {
    saveCalls += 1;
    saved = snapshot;
  }
}

void main() {
  test('project palette contains all twelve documented color keys', () {
    expect(ProjectPalette.values.map((entry) => entry.key).toList(), <String>[
      'red',
      'orange',
      'amber',
      'green',
      'teal',
      'cyan',
      'blue',
      'indigo',
      'violet',
      'purple',
      'pink',
      'gray',
    ]);
  });

  test('controller switches between deterministic 50 and 1000 datasets', () {
    final controller = WorkspaceController();
    expect(controller.todos, hasLength(50));
    expect(controller.visibleRows, hasLength(50));

    controller.switchDataset(TodoDataset.thousand);
    expect(controller.todos, hasLength(1000));
    expect(controller.visibleRows, hasLength(100));
    expect(controller.visibleRows.every((row) => row.depth == 0), isTrue);

    controller.toggleCollapsed(controller.visibleRows.first.todo.id);
    expect(controller.visibleRows.length, greaterThan(100));
  });

  test('no-repository controller retains the 50-row benchmark fixture', () {
    final controller = WorkspaceController();

    expect(controller.isBenchmarkMode, isTrue);
    expect(controller.groups, hasLength(3));
    expect(controller.projects, hasLength(4));
    expect(controller.todos, hasLength(50));
    expect(controller.trash, isEmpty);
  });

  test(
    'fresh repository initializes and persists one empty snapshot',
    () async {
      final repository = _RecordingRepository(
        AppDataLoadResult(
          data: AppData.empty(),
          source: AppDataLoadSource.empty,
        ),
      );
      final controller = WorkspaceController(repository: repository);

      await controller.initialize();

      expect(controller.groups, isEmpty);
      expect(controller.projects, isEmpty);
      expect(controller.todos, isEmpty);
      expect(controller.trash, isEmpty);
      expect(controller.appData, AppData.empty());
      expect(controller.hasUnsavedChanges, isFalse);
      expect(repository.saveCalls, 1);
      expect(repository.saved, AppData.empty());
    },
  );

  test(
    'existing repository snapshot loads exactly without a synthetic save',
    () async {
      final snapshot = AppData(
        schemaVersion: AppData.currentSchemaVersion,
        revision: 7,
        projects: const [],
        todos: const [],
        trash: <TrashItem>[
          TrashItem(
            id: 'trash-existing',
            kind: 'todo',
            payload: <String, dynamic>{'title': 'existing'},
          ),
        ],
      );
      final repository = _RecordingRepository(
        AppDataLoadResult(data: snapshot, source: AppDataLoadSource.primary),
      );
      final controller = WorkspaceController(repository: repository);

      await controller.initialize();

      expect(controller.appData, snapshot);
      expect(repository.saveCalls, 0);
    },
  );

  test('collapse state is held by the controller as the only source', () {
    final controller = WorkspaceController();
    final root = controller.visibleRows.first.todo;
    expect(root.collapsed, isFalse);
    controller.setCollapsed(root.id, false);
    expect(
      controller.todos.firstWhere((todo) => todo.id == root.id).collapsed,
      isFalse,
    );
    expect(controller.visibleRows, hasLength(50));

    controller.switchDataset(TodoDataset.thousand);
    final collapsedRoot = controller.visibleRows.first.todo;
    expect(collapsedRoot.collapsed, isTrue);
    controller.setCollapsed(collapsedRoot.id, false);
    expect(controller.visibleRows.length, greaterThan(100));
  });
}
