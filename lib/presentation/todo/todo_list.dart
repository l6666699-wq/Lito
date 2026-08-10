import 'package:flutter/widgets.dart';

import '../../application/workspace_controller.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_metrics.dart';
import '../../domain/models/visible_todo_row.dart';
import 'todo_row.dart';

class TodoList extends StatelessWidget {
  const TodoList({super.key, required this.controller, required this.rows});

  final WorkspaceController controller;
  final List<VisibleTodoRow> rows;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final parentIds = controller.todos
        .where((todo) => todo.parentId != null)
        .map((todo) => todo.parentId!)
        .toSet();
    if (rows.isEmpty) {
      return Center(
        child: Text('没有可见待办', style: TextStyle(color: colors.textMuted)),
      );
    }
    return ListView.builder(
      key: const ValueKey<String>('todo-list-builder'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: rows.length,
      itemExtent: AppMetrics.rowHeight,
      itemBuilder: (context, index) {
        final row = rows[index];
        return TodoRow(
          key: ValueKey<String>(row.todo.id),
          row: row,
          hasChildren: parentIds.contains(row.todo.id),
          onToggleCollapsed: () => controller.toggleCollapsed(row.todo.id),
        );
      },
    );
  }
}
