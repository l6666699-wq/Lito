import 'package:flutter/widgets.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_metrics.dart';
import '../../domain/models/visible_todo_row.dart';

class TodoRow extends StatelessWidget {
  const TodoRow({
    super.key,
    required this.row,
    required this.hasChildren,
    required this.onToggleCollapsed,
  });

  final VisibleTodoRow row;
  final bool hasChildren;
  final VoidCallback onToggleCollapsed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final completed = row.completionState == TodoVisualState.complete;
    final partial = row.completionState == TodoVisualState.partial;
    final titleColor = completed ? colors.textFaint : colors.text;
    return SizedBox(
      height: AppMetrics.rowHeight,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Row(
          children: [
            SizedBox(width: row.depth * AppMetrics.treeIndent),
            SizedBox(
              width: AppMetrics.treeIndent,
              child: hasChildren
                  ? GestureDetector(
                      onTap: onToggleCollapsed,
                      child: Center(
                        child: Text(
                          row.todo.collapsed ? '›' : '⌄',
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    )
                  : null,
            ),
            Container(
              width: 1,
              height: 19,
              margin: const EdgeInsets.only(right: 9),
              color: row.depth == 0 ? colors.transparent : colors.border,
            ),
            _TodoCheck(completed: completed, partial: partial),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                row.todo.title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 13,
                  decoration: completed ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodoCheck extends StatelessWidget {
  const _TodoCheck({required this.completed, required this.partial});

  final bool completed;
  final bool partial;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final active = completed || partial;
    return Container(
      width: 17,
      height: 17,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: completed ? colors.focus : colors.transparent,
        border: Border.all(
          color: active ? colors.focus : colors.borderStrong,
          width: 1.2,
        ),
        borderRadius: BorderRadius.circular(5),
      ),
      child: completed
          ? Text(
              '✓',
              style: TextStyle(
                color: colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            )
          : partial
          ? Container(width: 7, height: 2, color: colors.focus)
          : null,
    );
  }
}
