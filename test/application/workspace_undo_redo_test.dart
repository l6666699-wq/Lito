import 'package:flutter_test/flutter_test.dart';

import 'package:litetodo/application/workspace_controller.dart';
import 'package:litetodo/domain/models/app_data.dart';
import 'package:litetodo/infrastructure/persistence/app_data_repository.dart';
import 'package:litetodo/domain/services/todo_move_service.dart';

class _MemoryRepository implements AppDataRepository {
  _MemoryRepository(this.data);

  AppData data;
  int saveCount = 0;

  @override
  Future<AppDataLoadResult> load() async =>
      AppDataLoadResult(data: data, source: AppDataLoadSource.primary);

  @override
  Future<void> save(AppData snapshot) async {
    saveCount++;
    data = snapshot;
  }
}

class _FailingRepository extends _MemoryRepository {
  _FailingRepository(super.data);

  @override
  Future<void> save(AppData snapshot) async {
    throw StateError('save failed');
  }
}

void main() {
  test('undo/redo restores complete Todo, Trash and tree snapshots', () {
    final workspace = WorkspaceController();
    final root = workspace.createRootTodo('undo root');
    final child = workspace.createChildTodo('undo child', parentId: root.id);
    final grandchild = workspace.createChildTodo(
      'undo grandchild',
      parentId: child.id,
    );

    workspace.setTodoCompleted(root.id, true);
    final completeRevision = workspace.revision;
    expect(
      workspace.todos
          .where(
            (todo) =>
                <String>{root.id, child.id, grandchild.id}.contains(todo.id) &&
                todo.completed,
          )
          .length,
      3,
    );
    workspace.undo();
    expect(workspace.revision, completeRevision + 1);
    expect(
      workspace.todos.where(
        (todo) =>
            <String>{root.id, child.id, grandchild.id}.contains(todo.id) &&
            todo.completed,
      ),
      isEmpty,
    );
    expect(workspace.canRedo, isTrue);
    workspace.redo();
    expect(
      workspace.todos
          .where(
            (todo) =>
                <String>{root.id, child.id, grandchild.id}.contains(todo.id),
          )
          .every((todo) => todo.completed),
      isTrue,
    );

    final trash = workspace.deleteTodo(root.id)!;
    expect(workspace.trash, contains(trash));
    workspace.undo();
    expect(workspace.todos.map((todo) => todo.id), contains(root.id));
    expect(workspace.trash, isEmpty);
    workspace.redo();
    expect(workspace.todos.map((todo) => todo.id), isNot(contains(root.id)));
    expect(workspace.trash, contains(trash));
  });

  test(
    'move/project/group mutations undo and redo as one business operation',
    () {
      final workspace = WorkspaceController();
      final first = workspace.createRootTodo('first');
      final second = workspace.createRootTodo('second');
      final originalSecondSort = workspace.todos
          .firstWhere((todo) => todo.id == second.id)
          .sortOrder;
      workspace.moveTodo(second.id, first.id, TodoMovePosition.before);
      expect(
        workspace.todos
            .where((todo) => todo.parentId == null)
            .toList()
            .map((todo) => todo.id),
        containsAll(<String>[first.id, second.id]),
      );
      workspace.undo();
      expect(
        workspace.todos.firstWhere((todo) => todo.id == second.id).sortOrder,
        originalSecondSort,
      );
      workspace.redo();
      expect(
        workspace.todos.firstWhere((todo) => todo.id == second.id).sortOrder,
        lessThan(
          workspace.todos.firstWhere((todo) => todo.id == first.id).sortOrder,
        ),
      );

      final project = workspace.projects.first;
      final edited = project.copyWith(name: 'Edited project');
      workspace.updateProject(edited);
      workspace.undo();
      expect(
        workspace.projects.firstWhere((item) => item.id == project.id).name,
        project.name,
      );
      workspace.redo();
      expect(
        workspace.projects.firstWhere((item) => item.id == project.id).name,
        'Edited project',
      );

      final group = workspace.createGroup(name: 'Undo group');
      expect(workspace.canUndo, isTrue);
      workspace.undo();
      expect(workspace.groups.any((item) => item.id == group.id), isFalse);
      workspace.redo();
      expect(workspace.groups.any((item) => item.id == group.id), isTrue);
    },
  );

  test(
    'new mutation invalidates redo and history is capped at fifty entries',
    () {
      final workspace = WorkspaceController();
      final first = workspace.createRootTodo('first');
      workspace.createRootTodo('second');
      workspace.undo();
      expect(workspace.canRedo, isTrue);
      workspace.editTodoTitle(first.id, 'changed after undo');
      expect(workspace.canRedo, isFalse);

      for (var i = 0; i < 60; i++) {
        workspace.createRootTodo('cap $i');
      }
      expect(workspace.undoCount, 50);
      for (var i = 0; i < 50; i++) {
        workspace.undo();
      }
      expect(workspace.canUndo, isFalse);
    },
  );

  test('collapse persists without entering or clearing history', () async {
    final workspace = WorkspaceController(
      repository: _MemoryRepository(
        AppData(
          schemaVersion: AppData.currentSchemaVersion,
          revision: 0,
          groups: const [],
          projects: const [],
          todos: const [],
          trash: const [],
        ),
      ),
    );
    await workspace.initialize();
    final first = workspace.createRootTodo('collapse target');
    final second = workspace.createRootTodo('redo target');
    workspace.undo();
    expect(workspace.canRedo, isTrue);
    final undoCount = workspace.undoCount;
    final beforeRevision = workspace.revision;

    workspace.setCollapsed(first.id, true);

    expect(workspace.revision, beforeRevision + 1);
    expect(
      workspace.todos.firstWhere((todo) => todo.id == first.id).collapsed,
      isTrue,
    );
    expect(workspace.undoCount, undoCount);
    expect(workspace.canRedo, isTrue);
    workspace.redo();
    expect(workspace.todos.any((todo) => todo.id == second.id), isTrue);
  });

  test(
    'initialize/benchmark load do not create history and save rollback removes entry',
    () async {
      final seed = AppData(
        schemaVersion: AppData.currentSchemaVersion,
        revision: 7,
        groups: const [],
        projects: const [],
        todos: const [],
        trash: const [],
      );
      final repository = _MemoryRepository(seed);
      final workspace = WorkspaceController(repository: repository);
      await workspace.initialize();
      expect(workspace.canUndo, isFalse);
      workspace.createRootTodo('persisted');
      await workspace.flushNow();
      expect(repository.saveCount, greaterThanOrEqualTo(1));
      final savedRevision = workspace.revision;
      workspace.undo();
      expect(workspace.revision, savedRevision + 1);
      await workspace.flushNow();
      expect(repository.data.revision, workspace.revision);

      final failing = _FailingRepository(seed);
      final failingWorkspace = WorkspaceController(repository: failing);
      await failingWorkspace.initialize();
      final redoTarget = failingWorkspace.createRootTodo('redo after failure');
      failingWorkspace.undo();
      expect(failingWorkspace.canRedo, isTrue);
      await expectLater(
        failingWorkspace.addTodoAndFlush('fails safely'),
        throwsStateError,
      );
      expect(failingWorkspace.canUndo, isFalse);
      expect(failingWorkspace.canRedo, isTrue);
      expect(failingWorkspace.todos, isEmpty);
      failingWorkspace.redo();
      expect(
        failingWorkspace.todos.any((todo) => todo.id == redoTarget.id),
        isTrue,
      );
    },
  );
}
