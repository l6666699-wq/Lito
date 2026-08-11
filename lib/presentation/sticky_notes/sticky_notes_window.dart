import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../app/app_text.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_metrics.dart';
import '../../application/workspace_controller.dart';
import '../../domain/models/visible_todo_row.dart';
import '../../infrastructure/platform/sticky_notes_window_service.dart';
import '../../icons/app_icons.dart';

/// The content hosted by each native sticky-note engine.
///
/// It intentionally receives a read-only [WorkspaceController] projection in
/// secondary engines. The primary engine's controller remains authoritative;
/// native snapshot events keep this list live without a second persistence
/// writer.
class StickyNotesWindow extends StatelessWidget {
  const StickyNotesWindow({
    super.key,
    required this.controller,
    required this.windowService,
    required this.projectId,
    required this.windowKey,
  });

  final WorkspaceController controller;
  final StickyNotesSecondaryChannel windowService;
  final String? projectId;
  final String windowKey;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final colors = AppColors.of(context);
        final rows = controller.visibleRowsForProject(projectId);
        var title = AppText.inbox;
        if (projectId != null) {
          for (final project in controller.projects) {
            if (project.id == projectId) {
              title = project.name;
              break;
            }
          }
        }
        return ColoredBox(
          color: colors.canvas,
          child: Column(
            children: [
              _StickyHeader(
                title: title,
                windowKey: windowKey,
                windowService: windowService,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppMetrics.compactPadding,
                    AppMetrics.compactPadding,
                    AppMetrics.compactPadding,
                    AppMetrics.compactPadding,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      border: Border.all(color: colors.border),
                      borderRadius: BorderRadius.circular(
                        AppMetrics.shellCardRadius,
                      ),
                    ),
                    child: _StickyTodoList(
                      rows: rows,
                      parentIds: {
                        for (final todo in controller.todos)
                          if (todo.parentId != null) todo.parentId!,
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StickyHeader extends StatelessWidget {
  const _StickyHeader({
    required this.title,
    required this.windowKey,
    required this.windowService,
  });

  final String title;
  final String windowKey;
  final StickyNotesSecondaryChannel windowService;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(color: colors.borderStrong.withValues(alpha: .72)),
        ),
      ),
      child: SizedBox(
        height: AppMetrics.headerHeight + AppMetrics.unit,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppMetrics.compactPadding,
          ),
          child: Row(
            children: [
              Expanded(
                child: MouseRegion(
                  cursor: SystemMouseCursors.move,
                  child: GestureDetector(
                    key: const ValueKey<String>('sticky-header-drag-region'),
                    behavior: HitTestBehavior.translucent,
                    onPanStart: (_) =>
                        unawaited(windowService.startDragging(windowKey)),
                    child: Row(
                      children: [
                        Icon(
                          AppIcons.stickyNotes,
                          color: colors.focus,
                          size: AppMetrics.iconSize + 2,
                        ),
                        const SizedBox(width: AppMetrics.unit * 2),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _StickyHeaderButton(
                key: const ValueKey<String>('sticky-back-full-button'),
                icon: AppIcons.back,
                tooltip: '返回全屏',
                onPressed: () => unawaited(windowService.close(windowKey)),
              ),
              _StickyHeaderButton(
                key: const ValueKey<String>('sticky-pin-button'),
                icon: AppIcons.pin,
                tooltip: '置顶',
                onPressed: () =>
                    unawaited(windowService.setAlwaysOnTop(windowKey, true)),
              ),
              _StickyHeaderButton(
                key: const ValueKey<String>('sticky-close-button'),
                icon: AppIcons.windowClose,
                tooltip: '关闭',
                onPressed: () => unawaited(windowService.close(windowKey)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StickyHeaderButton extends StatelessWidget {
  const _StickyHeaderButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      button: true,
      label: tooltip,
      child: ShadTooltip(
        builder: (context) => Text(tooltip),
        child: ShadButton.ghost(
          onPressed: onPressed,
          height: AppMetrics.windowControlSize,
          width: AppMetrics.windowControlSize,
          padding: EdgeInsets.zero,
          foregroundColor: colors.textMuted,
          hoverBackgroundColor: colors.focusSoft,
          child: Icon(icon, size: AppMetrics.iconSize),
        ),
      ),
    );
  }
}

/// A deliberately read-only projection for secondary sticky-note windows.
///
/// The primary [TodoList] owns editing, completion and drag mutations. A
/// sticky window must still show those familiar affordances for visual parity,
/// but none of the controls below have an action or write back to the model.
class _StickyTodoList extends StatefulWidget {
  const _StickyTodoList({required this.rows, required this.parentIds});

  final List<VisibleTodoRow> rows;
  final Set<String> parentIds;

  @override
  State<_StickyTodoList> createState() => _StickyTodoListState();
}

class _StickyTodoListState extends State<_StickyTodoList> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty) {
      return const _StickyEmptyState();
    }

    return ListView.builder(
      key: const ValueKey<String>('todo-list-builder'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppMetrics.unit * 2,
        vertical: AppMetrics.unit * 2,
      ),
      itemCount: widget.rows.length,
      itemBuilder: (context, index) {
        final row = widget.rows[index];
        return _StickyTaskRow(
          key: ValueKey<String>('sticky-task-row-${row.todo.id}'),
          row: row,
          hasChildren: widget.parentIds.contains(row.todo.id),
          selected: _selectedId == row.todo.id,
          onSelect: () => setState(() => _selectedId = row.todo.id),
        );
      },
    );
  }
}

class _StickyTaskRow extends StatelessWidget {
  const _StickyTaskRow({
    super.key,
    required this.row,
    required this.hasChildren,
    required this.selected,
    required this.onSelect,
  });

  final VisibleTodoRow row;
  final bool hasChildren;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final completed = row.completionState == TodoVisualState.complete;
    final partial = row.completionState == TodoVisualState.partial;
    final titleColor = completed ? colors.textFaint : colors.text;
    final rowBackground = selected ? colors.focusSoft : colors.transparent;

    return Semantics(
      container: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onSelect,
        child: AnimatedContainer(
          duration: Duration(milliseconds: AppMetrics.hoverDurationMs.round()),
          height: AppMetrics.todoRootRowHeight,
          margin: const EdgeInsets.only(top: AppMetrics.unit),
          padding: const EdgeInsets.symmetric(horizontal: AppMetrics.unit * 2),
          decoration: BoxDecoration(
            color: rowBackground,
            border: Border(bottom: BorderSide(color: colors.border)),
            borderRadius: BorderRadius.circular(AppMetrics.smallRadius),
          ),
          child: Row(
            children: [
              SizedBox(width: row.depth * AppMetrics.treeIndent),
              _StickyDragAffordance(todoId: row.todo.id),
              const SizedBox(width: AppMetrics.unit),
              if (hasChildren)
                Icon(
                  row.todo.collapsed
                      ? AppIcons.chevronRight
                      : AppIcons.chevronDown,
                  size: AppMetrics.iconSize - 2,
                  color: colors.textMuted,
                )
              else
                const SizedBox(width: AppMetrics.iconSize - 2),
              const SizedBox(width: AppMetrics.unit),
              _StickyCheckbox(
                todoId: row.todo.id,
                completed: completed,
                partial: partial,
                title: row.todo.title,
              ),
              const SizedBox(width: AppMetrics.unit),
              Expanded(
                child: Text(
                  row.todo.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 13,
                    fontWeight: hasChildren ? FontWeight.w600 : null,
                    decoration: completed ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              _StickyEditAffordance(todoId: row.todo.id),
            ],
          ),
        ),
      ),
    );
  }
}

class _StickyDragAffordance extends StatelessWidget {
  const _StickyDragAffordance({required this.todoId});

  final String todoId;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      key: ValueKey<String>('sticky-drag-handle-$todoId'),
      enabled: false,
      label: '拖拽排序',
      child: SizedBox(
        width: AppMetrics.windowControlSize,
        height: AppMetrics.windowControlSize,
        child: Center(
          child: Icon(
            AppIcons.dragHandle,
            size: AppMetrics.iconSize,
            color: colors.textFaint,
          ),
        ),
      ),
    );
  }
}

class _StickyCheckbox extends StatelessWidget {
  const _StickyCheckbox({
    required this.todoId,
    required this.completed,
    required this.partial,
    required this.title,
  });

  final String todoId;
  final bool completed;
  final bool partial;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final active = completed || partial;
    return Semantics(
      key: ValueKey<String>('sticky-checkbox-$todoId'),
      enabled: false,
      checked: active,
      label: title,
      child: SizedBox(
        width: AppMetrics.windowControlSize,
        height: AppMetrics.windowControlSize,
        child: Center(
          child: Container(
            width: AppMetrics.iconSize + 2,
            height: AppMetrics.iconSize + 2,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: completed ? colors.focus : colors.transparent,
              border: Border.all(
                color: active ? colors.focus : colors.borderStrong,
                width: 1.2,
              ),
              borderRadius: BorderRadius.circular(AppMetrics.smallRadius),
            ),
            child: completed
                ? Icon(AppIcons.check, color: colors.white, size: 12)
                : partial
                ? Icon(AppIcons.minus, color: colors.focus, size: 12)
                : null,
          ),
        ),
      ),
    );
  }
}

class _StickyEditAffordance extends StatelessWidget {
  const _StickyEditAffordance({required this.todoId});

  final String todoId;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      key: ValueKey<String>('sticky-edit-$todoId'),
      button: true,
      enabled: false,
      label: '编辑任务',
      child: SizedBox(
        width: AppMetrics.windowControlSize,
        height: AppMetrics.windowControlSize,
        child: Center(
          child: Icon(
            AppIcons.edit,
            size: AppMetrics.iconSize - 1,
            color: colors.textFaint,
          ),
        ),
      ),
    );
  }
}

class _StickyEmptyState extends StatelessWidget {
  const _StickyEmptyState();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.inbox, size: 28, color: colors.textFaint),
          const SizedBox(height: AppMetrics.unit * 2),
          Text(AppText.inbox, style: TextStyle(color: colors.textMuted)),
        ],
      ),
    );
  }
}
