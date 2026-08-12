import 'package:flutter_test/flutter_test.dart';
import 'package:litetodo/application/workspace_controller.dart';
import 'package:litetodo/domain/models/app_data.dart';
import 'package:litetodo/domain/models/project.dart';
import 'package:litetodo/domain/models/todo_item.dart';
import 'package:litetodo/domain/services/todo_move_service.dart';
import 'package:litetodo/domain/services/todo_tree_service.dart';
import 'package:litetodo/infrastructure/persistence/app_data_repository.dart';

class _MemoryRepository implements AppDataRepository {
  _MemoryRepository(this.data);

  AppData data;

  @override
  Future<AppDataLoadResult> load() async =>
      AppDataLoadResult(data: data, source: AppDataLoadSource.primary);

  @override
  Future<void> save(AppData snapshot) async {
    data = snapshot;
  }
}

void main() {
  final fixedNow = DateTime(2026, 8, 10, 12);

  WorkspaceController controller() =>
      WorkspaceController(nowProvider: () => fixedNow);

  test('today and recent use local dueAt date boundaries', () {
    final workspace = controller();
    final today = workspace.createRootTodo(
      'today',
      dueAt: DateTime(2026, 8, 10, 23),
    );
    final recent = workspace.createRootTodo(
      'recent',
      dueAt: DateTime(2026, 8, 16, 23),
    );
    workspace.createRootTodo('later', dueAt: DateTime(2026, 8, 17));

    workspace.selectToday();
    expect(workspace.visibleRows.map((row) => row.todo.id), contains(today.id));
    expect(
      workspace.visibleRows.map((row) => row.todo.id),
      isNot(contains(recent.id)),
    );
    workspace.selectRecent();
    expect(workspace.visibleRows.map((row) => row.todo.id), contains(today.id));
    expect(
      workspace.visibleRows.map((row) => row.todo.id),
      contains(recent.id),
    );
  });

  test('new inbox Todos use creation time for today and recent scopes', () {
    final workspace = controller();
    final created = workspace.createRootTodo('created in inbox');

    expect(created.projectId, isNull);
    workspace.selectInbox();
    expect(
      workspace.visibleRows.map((row) => row.todo.id),
      contains(created.id),
    );
    workspace.selectToday();
    expect(
      workspace.visibleRows.map((row) => row.todo.id),
      contains(created.id),
    );
    workspace.selectRecent();
    expect(
      workspace.visibleRows.map((row) => row.todo.id),
      contains(created.id),
    );
  });

  test('completion toggles subtree and recomputes ancestors', () {
    final workspace = controller();
    final root = workspace.createRootTodo('root');
    final child = workspace.createChildTodo('child', parentId: root.id);
    final grandchild = workspace.createChildTodo(
      'grandchild',
      parentId: child.id,
    );

    workspace.setTodoCompleted(root.id, true);
    expect(
      workspace.todos
          .where(
            (todo) =>
                <String>{root.id, child.id, grandchild.id}.contains(todo.id),
          )
          .where((todo) => todo.completed),
      hasLength(3),
    );
    workspace.setTodoCompleted(grandchild.id, false);
    expect(
      workspace.todos.firstWhere((todo) => todo.id == root.id).completed,
      isFalse,
    );
    expect(
      workspace.todos.firstWhere((todo) => todo.id == child.id).completed,
      isFalse,
    );
  });

  test('delete and restore subtree preserve valid relationships', () {
    final workspace = controller();
    final root = workspace.createRootTodo('root');
    final child = workspace.createChildTodo('child', parentId: root.id);
    final trash = workspace.deleteTodo(root.id)!;
    expect(workspace.todos.where((todo) => todo.id == root.id), isEmpty);
    expect(workspace.restoreTrash(trash.id), isTrue);
    expect(
      workspace.todos.map((todo) => todo.id),
      containsAll(<String>[root.id, child.id]),
    );
    expect(
      workspace.todos.firstWhere((todo) => todo.id == child.id).parentId,
      root.id,
    );
  });

  test('project trash restores project and remaps conflicting ids', () async {
    final now = DateTime(2026, 8, 10);
    final project = controller().projects.first;
    final existing = controller().todos.first;
    final restoredTodo = existing.copyWith(
      id: 'same-todo',
      projectId: project.id,
    );
    final trash = TrashItem(
      id: 'project-trash',
      kind: 'project_subtree',
      payload: <String, dynamic>{
        'project': project.toJson(),
        'todos': <dynamic>[
          restoredTodo.toJson(),
          restoredTodo
              .copyWith(id: 'same-child', parentId: 'same-todo')
              .toJson(),
        ],
      },
    );
    final repository = _MemoryRepository(
      AppData(
        schemaVersion: AppData.currentSchemaVersion,
        revision: 1,
        groups: controller().groups,
        projects: <Project>[project],
        todos: <TodoItem>[existing.copyWith(id: 'same-todo')],
        trash: <TrashItem>[trash],
      ),
    );
    final workspace = WorkspaceController(
      repository: repository,
      nowProvider: () => now,
    );
    await workspace.initialize();
    expect(workspace.restoreTrash('project-trash'), isTrue);
    final restoredProject = workspace.projects.lastWhere(
      (entry) => entry.id != project.id,
    );
    expect(restoredProject.id, isNot(project.id));
    final restored = workspace.todos
        .where((todo) => todo.projectId == restoredProject.id)
        .toList();
    expect(restored, hasLength(2));
    final child = restored.firstWhere((todo) => todo.parentId != null);
    final root = restored.firstWhere((todo) => todo.parentId == null);
    expect(child.parentId, root.id);
  });

  test('move rejects cycles and normalizes siblings', () {
    final workspace = controller();
    final first = workspace.createRootTodo('first');
    final second = workspace.createRootTodo('second');
    final child = workspace.createChildTodo('child', parentId: first.id);
    expect(
      () => workspace.moveTodo(first.id, child.id, TodoMovePosition.inside),
      throwsStateError,
    );
    workspace.moveTodo(second.id, first.id, TodoMovePosition.before);
    final roots = workspace.todos
        .where(
          (todo) =>
              todo.parentId == null &&
              <String>{first.id, second.id}.contains(todo.id),
        )
        .toList();
    roots.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    expect(roots.map((todo) => todo.id), <String>[second.id, first.id]);
    expect(roots.map((todo) => todo.sortOrder), <int>[2000, 3000]);
  });

  test('cross-project movement requires an explicit destination project', () {
    final workspace = controller();
    final firstProject = workspace.projects[0];
    final secondProject = workspace.projects[1];
    final moving = workspace.createRootTodo(
      'moving',
      projectId: firstProject.id,
    );
    final target = workspace.createRootTodo(
      'target',
      projectId: secondProject.id,
    );
    expect(
      () => workspace.moveTodo(moving.id, target.id, TodoMovePosition.before),
      throwsStateError,
    );
    workspace.moveTodo(
      moving.id,
      target.id,
      TodoMovePosition.before,
      destinationProjectId: secondProject.id,
    );
    expect(
      workspace.todos.firstWhere((todo) => todo.id == moving.id).projectId,
      secondProject.id,
    );
  });

  test('tree creation stops at six layers (depth indexes 0 through 5)', () {
    final workspace = controller();
    var parent = workspace.createRootTodo('level-0');
    for (var level = 1; level < TodoTreeService.maxTreeDepth; level++) {
      parent = workspace.createChildTodo('level-$level', parentId: parent.id);
    }
    expect(
      () => workspace.createChildTodo('too-deep', parentId: parent.id),
      throwsStateError,
    );
  });

  test(
    'archive excludes sidebar unfinished count and search is case insensitive',
    () {
      final workspace = controller();
      final project = workspace.projects.first;
      final todo = workspace.createRootTodo(
        'Needle task',
        projectId: project.id,
      );
      final before = workspace.unfinishedCountForProject(project.id);
      expect(before, greaterThan(0));
      workspace.archiveTodo(todo.id);
      expect(workspace.unfinishedCountForProject(project.id), before - 1);
      workspace.selectSearch('NEEDLE');
      expect(workspace.visibleRows.map((row) => row.todo.id), isEmpty);
      workspace.selectArchived();
      expect(
        workspace.visibleRows.map((row) => row.todo.id),
        contains(todo.id),
      );
    },
  );

  test('benchmark switching remains isolated from data snapshot', () {
    final workspace = controller();
    final before = workspace.appData;
    workspace.switchDataset(TodoDataset.thousand);
    expect(workspace.isBenchmarkMode, isTrue);
    expect(workspace.todos, hasLength(1000));
    expect(workspace.appData, before);
  });
}
