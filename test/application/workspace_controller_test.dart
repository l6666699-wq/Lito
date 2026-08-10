import 'package:flutter_test/flutter_test.dart';
import 'package:litetodo/app/theme/project_palette.dart';
import 'package:litetodo/application/workspace_controller.dart';

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
