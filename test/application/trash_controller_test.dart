import 'package:flutter_test/flutter_test.dart';
import 'package:litetodo/application/workspace_controller.dart';

void main() {
  final fixedNow = DateTime.utc(2026, 8, 10, 12, 34);

  WorkspaceController controller() =>
      WorkspaceController(nowProvider: () => fixedNow);

  test('clearTrash is an empty no-op and records one undoable mutation', () {
    final workspace = controller();
    final initialRevision = workspace.revision;
    final initialUndoCount = workspace.undoCount;

    expect(workspace.clearTrash(), isFalse);
    expect(workspace.revision, initialRevision);
    expect(workspace.undoCount, initialUndoCount);

    final root = workspace.todos.first;
    workspace.deleteTodo(root.id);
    final trashSnapshot = workspace.trash;
    final beforeClearUndoCount = workspace.undoCount;
    final beforeClearRevision = workspace.revision;

    expect(workspace.clearTrash(), isTrue);
    expect(workspace.trash, isEmpty);
    expect(workspace.undoCount, beforeClearUndoCount + 1);
    expect(workspace.revision, beforeClearRevision + 1);

    workspace.undo();
    expect(workspace.trash, trashSnapshot);
    expect(workspace.todos.any((todo) => todo.id == root.id), isFalse);
  });

  test('restore and clear mutations are each independently undoable', () {
    final workspace = controller();
    final roots = workspace.todos
        .where((todo) => todo.parentId == null)
        .take(2)
        .toList(growable: false);
    final first = roots.first;
    final second = roots.last;
    final firstTrash = workspace.deleteTodo(first.id)!;
    final secondTrash = workspace.deleteTodo(second.id)!;
    expect(workspace.trash, containsAll(<Object>[firstTrash, secondTrash]));

    expect(workspace.restoreTrash(firstTrash.id), isTrue);
    expect(workspace.trash, contains(secondTrash));
    expect(workspace.canUndo, isTrue);
    workspace.undo();
    expect(workspace.trash, containsAll(<Object>[firstTrash, secondTrash]));

    expect(workspace.clearTrash(), isTrue);
    workspace.undo();
    expect(workspace.trash, containsAll(<Object>[firstTrash, secondTrash]));
  });

  test(
    'restoring a Todo whose project disappeared falls back to inbox root',
    () {
      final workspace = controller();
      final project = workspace.projects.first;
      final root = workspace.createRootTodo('待恢复项目任务', projectId: project.id);
      final child = workspace.createChildTodo('待恢复子任务', parentId: root.id);
      final todoTrash = workspace.deleteTodo(root.id)!;
      workspace.deleteProject(project.id);

      expect(workspace.restoreTrash(todoTrash.id), isTrue);
      final restoredRoot = workspace.todos.firstWhere(
        (todo) => todo.title == root.title,
      );
      final restoredChild = workspace.todos.firstWhere(
        (todo) => todo.title == child.title,
      );
      expect(restoredRoot.projectId, isNull);
      expect(restoredRoot.parentId, isNull);
      expect(restoredChild.projectId, isNull);
      expect(restoredChild.parentId, restoredRoot.id);
    },
  );
}
