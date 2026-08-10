import 'package:flutter_test/flutter_test.dart';
import 'package:litetodo/domain/models/project.dart';
import 'package:litetodo/domain/models/todo_item.dart';

void main() {
  test('Project and TodoItem round trip JSON and copyWith', () {
    final now = DateTime.utc(2026, 1, 1, 12);
    final project = Project(
      id: 'p',
      name: '项目',
      iconKey: 'folder',
      colorKey: 'blue',
      sortOrder: 10,
      archived: false,
      createdAt: now,
      updatedAt: now,
    );
    final todo = TodoItem(
      id: 't',
      projectId: 'p',
      parentId: 'parent',
      title: '待办',
      completed: false,
      completedAt: null,
      sortOrder: 20,
      collapsed: true,
      createdAt: now,
      updatedAt: now,
    );

    expect(Project.fromJson(project.toJson()), project);
    expect(TodoItem.fromJson(todo.toJson()), todo);
    expect(todo.copyWith(parentId: null, completed: true).parentId, isNull);
    expect(project.copyWith(name: '新项目').name, '新项目');
  });
}
