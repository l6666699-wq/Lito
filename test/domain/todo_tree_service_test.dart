import 'package:flutter_test/flutter_test.dart';
import 'package:litetodo/domain/models/todo_item.dart';
import 'package:litetodo/domain/models/visible_todo_row.dart';
import 'package:litetodo/domain/services/todo_tree_service.dart';

TodoItem todo(
  String id, {
  String? parentId,
  int sortOrder = 0,
  bool collapsed = false,
  bool completed = false,
  String? projectId = 'project',
}) {
  final now = DateTime.utc(2026, 1, 1);
  return TodoItem(
    id: id,
    projectId: projectId,
    parentId: parentId,
    title: id,
    completed: completed,
    completedAt: completed ? now : null,
    sortOrder: sortOrder,
    collapsed: collapsed,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  test('flattens parentId hierarchy with depth metadata', () {
    final rows = TodoTreeService(<TodoItem>[
      todo('child', parentId: 'root', sortOrder: 20),
      todo('root', sortOrder: 10),
      todo('grandchild', parentId: 'child', sortOrder: 30),
    ]).visibleRows();

    expect(rows.map((row) => row.todo.id), <String>[
      'root',
      'child',
      'grandchild',
    ]);
    expect(rows.map((row) => row.depth), <int>[0, 1, 2]);
  });

  test('collapsed parent hides all descendants', () {
    final rows = TodoTreeService(<TodoItem>[
      todo('root', collapsed: true),
      todo('child', parentId: 'root'),
      todo('grandchild', parentId: 'child'),
    ]).visibleRows();

    expect(rows.map((row) => row.todo.id), <String>['root']);
  });

  test('same sortOrder keeps source order stable', () {
    final rows = TodoTreeService(<TodoItem>[
      todo('second', sortOrder: 10),
      todo('first', sortOrder: 10),
      todo('third', sortOrder: 20),
    ]).visibleRows();

    expect(rows.map((row) => row.todo.id), <String>[
      'second',
      'first',
      'third',
    ]);
  });

  test('completion state is derived without changing the model', () {
    final rows = TodoTreeService(<TodoItem>[
      todo('root'),
      todo('done', parentId: 'root', completed: true),
      todo('open', parentId: 'root'),
    ]).visibleRows();

    expect(rows.first.completionState, TodoVisualState.partial);
    expect(rows[1].completionState, TodoVisualState.complete);
  });

  test('a completed parent with a new incomplete child is partial', () {
    final rows = TodoTreeService(<TodoItem>[
      todo('parent', completed: true),
      todo('completed-child', parentId: 'parent', completed: true),
      todo('new-child', parentId: 'parent'),
    ]).visibleRows();

    expect(rows.first.completionState, TodoVisualState.partial);
    expect(rows[1].completionState, TodoVisualState.complete);
    expect(rows[2].completionState, TodoVisualState.incomplete);
  });

  test('a completed parent is complete when every child is complete', () {
    final rows = TodoTreeService(<TodoItem>[
      todo('parent', completed: true),
      todo('child', parentId: 'parent', completed: true),
    ]).visibleRows();

    expect(rows.first.completionState, TodoVisualState.complete);
  });

  test(
    'an incomplete parent with only incomplete children stays incomplete',
    () {
      final rows = TodoTreeService(<TodoItem>[
        todo('parent'),
        todo('first-child', parentId: 'parent'),
        todo('second-child', parentId: 'parent'),
      ]).visibleRows();

      expect(rows.first.completionState, TodoVisualState.incomplete);
    },
  );

  test('orphan and cyclic parent links do not throw or loop', () {
    final rows = TodoTreeService(<TodoItem>[
      todo('orphan', parentId: 'missing'),
      todo('cycle-a', parentId: 'cycle-b'),
      todo('cycle-b', parentId: 'cycle-a'),
    ]).visibleRows();

    expect(rows.map((row) => row.todo.id).toSet(), <String>{
      'orphan',
      'cycle-a',
      'cycle-b',
    });
    expect(
      rows.every((row) => row.depth <= TodoTreeService.maxTreeDepth),
      true,
    );
  });

  test('inbox filtering uses projectId null', () {
    final rows = TodoTreeService(<TodoItem>[
      todo('inbox', projectId: null),
      todo('project', projectId: 'project'),
    ]).visibleRows(inboxOnly: true);

    expect(rows.map((row) => row.todo.id), <String>['inbox']);
  });
}
