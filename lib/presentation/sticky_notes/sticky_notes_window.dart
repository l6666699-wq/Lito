import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../app/app_text.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_metrics.dart';
import '../../application/workspace_controller.dart';
import '../../domain/models/visible_todo_row.dart';
import '../../infrastructure/platform/sticky_notes_window_service.dart'
    show StickyNotesSecondaryChannel;
import '../../icons/app_icons.dart';

const _stickyWindowInset = AppMetrics.unit * 2;
const _stickyListInset = AppMetrics.unit;
const _stickyHeaderHeight = AppMetrics.headerHeight + AppMetrics.unit * 2;
const _stickyRowHeight = AppMetrics.todoRowHeight + AppMetrics.unit;
const _stickyRowGap = AppMetrics.unit / 2;
const _stickyRowHorizontalPadding = AppMetrics.unit;

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
    this.onToggleTodoCompleted,
    this.onEditTodoTitle,
    this.onAddTodo,
  });

  final WorkspaceController controller;
  final StickyNotesSecondaryChannel windowService;
  final String? projectId;
  final String windowKey;
  final FutureOr<void> Function(String todoId)? onToggleTodoCompleted;
  final FutureOr<void> Function(String todoId, String title)? onEditTodoTitle;
  final FutureOr<void> Function(String title)? onAddTodo;

  Future<void> _toggleTodoDirectly(String todoId) async {
    controller.toggleTodoCompleted(todoId);
    await controller.flushNow();
  }

  Future<void> _editTodoDirectly(String todoId, String title) async {
    controller.editTodoTitle(todoId, title);
    await controller.flushNow();
  }

  Future<void> _addTodoDirectly(String title) =>
      controller.addTodoAndFlush(title, projectId: projectId);

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
                  padding: const EdgeInsets.all(_stickyWindowInset),
                  child: DecoratedBox(
                    key: const ValueKey<String>('sticky-list-card'),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      border: Border.all(color: colors.border),
                      borderRadius: BorderRadius.circular(
                        AppMetrics.cardRadius,
                      ),
                    ),
                    child: _StickyTodoList(
                      rows: rows,
                      parentIds: {
                        for (final todo in controller.todos)
                          if (todo.parentId != null) todo.parentId!,
                      },
                      onToggleTodoCompleted:
                          onToggleTodoCompleted ?? _toggleTodoDirectly,
                      onEditTodoTitle: onEditTodoTitle ?? _editTodoDirectly,
                      onAddTodo: onAddTodo ?? _addTodoDirectly,
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
      key: const ValueKey<String>('sticky-header'),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(color: colors.borderStrong.withValues(alpha: .72)),
        ),
      ),
      child: SizedBox(
        height: _stickyHeaderHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppMetrics.compactPadding,
          ),
          child: Row(
            children: [
              Expanded(
                child: MouseRegion(
                  cursor: SystemMouseCursors.move,
                  child: Listener(
                    key: const ValueKey<String>('sticky-header-drag-region'),
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: (_) =>
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

/// A lazily rendered todo projection used by sticky-note windows.
///
/// Secondary engines receive mutation callbacks that are routed to the
/// primary workspace owner.  The callbacks are intentionally supplied by the
/// parent instead of writing the snapshot controller directly.
class _StickyTodoList extends StatefulWidget {
  const _StickyTodoList({
    required this.rows,
    required this.parentIds,
    required this.onToggleTodoCompleted,
    required this.onEditTodoTitle,
    required this.onAddTodo,
  });

  final List<VisibleTodoRow> rows;
  final Set<String> parentIds;
  final FutureOr<void> Function(String todoId) onToggleTodoCompleted;
  final FutureOr<void> Function(String todoId, String title) onEditTodoTitle;
  final FutureOr<void> Function(String title) onAddTodo;

  @override
  State<_StickyTodoList> createState() => _StickyTodoListState();
}

class _StickyTodoListState extends State<_StickyTodoList> {
  String? _selectedId;
  late final TextEditingController _addController = TextEditingController();
  late final FocusNode _addFocusNode = FocusNode(debugLabel: 'sticky-add-todo');
  bool _addInFlight = false;

  @override
  void dispose() {
    _addController.dispose();
    _addFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submitTodo() async {
    if (_addInFlight) return;
    final title = _addController.text.trim();
    if (title.isEmpty) return;
    setState(() => _addInFlight = true);
    try {
      await widget.onAddTodo(title);
      if (mounted) {
        _addController.clear();
        _addFocusNode.requestFocus();
      }
    } finally {
      if (mounted) setState(() => _addInFlight = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: widget.rows.isEmpty
              ? const _StickyEmptyState()
              : ListView.builder(
                  key: const ValueKey<String>('todo-list-builder'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: _stickyListInset,
                    vertical: _stickyListInset,
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
                      onToggleTodoCompleted: widget.onToggleTodoCompleted,
                      onEditTodoTitle: widget.onEditTodoTitle,
                    );
                  },
                ),
        ),
        _StickyAddTodo(
          controller: _addController,
          focusNode: _addFocusNode,
          submitting: _addInFlight,
          onSubmitted: _submitTodo,
        ),
      ],
    );
  }
}

class _StickyAddTodo extends StatelessWidget {
  const _StickyAddTodo({
    required this.controller,
    required this.focusNode,
    required this.submitting,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool submitting;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _stickyListInset,
        AppMetrics.unit,
        _stickyListInset,
        _stickyListInset,
      ),
      child: ShadInput(
        key: const ValueKey<String>('sticky-add-todo-input'),
        controller: controller,
        focusNode: focusNode,
        enabled: !submitting,
        placeholder: Text(
          '添加待办',
          style: TextStyle(color: colors.textFaint, fontSize: 12),
        ),
        onSubmitted: (_) => onSubmitted(),
        leading: Icon(
          AppIcons.add,
          size: AppMetrics.iconSize,
          color: colors.focus,
        ),
        constraints: const BoxConstraints(minHeight: AppMetrics.rowHeight),
      ),
    );
  }
}

class _StickyTaskRow extends StatefulWidget {
  const _StickyTaskRow({
    super.key,
    required this.row,
    required this.hasChildren,
    required this.selected,
    required this.onSelect,
    required this.onToggleTodoCompleted,
    required this.onEditTodoTitle,
  });

  final VisibleTodoRow row;
  final bool hasChildren;
  final bool selected;
  final VoidCallback onSelect;
  final FutureOr<void> Function(String todoId) onToggleTodoCompleted;
  final FutureOr<void> Function(String todoId, String title) onEditTodoTitle;

  @override
  State<_StickyTaskRow> createState() => _StickyTaskRowState();
}

class _StickyTaskRowState extends State<_StickyTaskRow> {
  late final TextEditingController _editController = TextEditingController(
    text: widget.row.todo.title,
  );
  late final FocusNode _editFocusNode = FocusNode(
    debugLabel: 'sticky-inline-editor',
  );
  bool _editing = false;

  @override
  void didUpdateWidget(covariant _StickyTaskRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && oldWidget.row.todo.title != widget.row.todo.title) {
      _editController.text = widget.row.todo.title;
    }
  }

  @override
  void dispose() {
    _editController.dispose();
    _editFocusNode.dispose();
    super.dispose();
  }

  void _beginEdit() {
    if (_editing) return;
    setState(() {
      _editing = true;
      _editController.value = TextEditingValue(
        text: widget.row.todo.title,
        selection: TextSelection(
          baseOffset: 0,
          extentOffset: widget.row.todo.title.length,
        ),
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_editing) return;
      _editFocusNode.requestFocus();
      _editController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _editController.text.length,
      );
    });
  }

  void _cancelEdit() {
    if (!mounted) return;
    setState(() {
      _editing = false;
      _editController.text = widget.row.todo.title;
    });
  }

  void _commitEdit() {
    final title = _editController.text.trim();
    if (title.isEmpty) {
      _cancelEdit();
      return;
    }
    setState(() => _editing = false);
    unawaited(_submitEdit(title));
  }

  Future<void> _submitEdit(String title) async {
    try {
      await widget.onEditTodoTitle(widget.row.todo.id, title);
    } catch (_) {
      // The primary engine remains authoritative.  A later snapshot will
      // restore the title if persistence or channel forwarding fails.
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final row = widget.row;
    final completed = row.completionState == TodoVisualState.complete;
    final partial = row.completionState == TodoVisualState.partial;
    final titleColor = completed ? colors.textFaint : colors.text;
    final rowBackground = widget.selected
        ? colors.focusSoft
        : colors.transparent;

    return Semantics(
      container: true,
      selected: widget.selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onSelect,
        onDoubleTap: _beginEdit,
        child: AnimatedContainer(
          duration: Duration(milliseconds: AppMetrics.hoverDurationMs.round()),
          height: _stickyRowHeight,
          margin: const EdgeInsets.only(top: _stickyRowGap),
          padding: const EdgeInsets.symmetric(
            horizontal: _stickyRowHorizontalPadding,
          ),
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
              if (widget.hasChildren)
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
                onToggle: () => unawaited(
                  Future<void>.sync(
                    () => widget.onToggleTodoCompleted(row.todo.id),
                  ),
                ),
              ),
              const SizedBox(width: AppMetrics.unit),
              Expanded(
                child: _editing
                    ? _StickyInlineEditor(
                        controller: _editController,
                        focusNode: _editFocusNode,
                        onSubmitted: (_) => _commitEdit(),
                        onCancel: _cancelEdit,
                      )
                    : Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerUp: (_) => _beginEdit(),
                        child: Text(
                          row.todo.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: titleColor,
                            fontSize: 13,
                            fontWeight: widget.hasChildren
                                ? FontWeight.w600
                                : null,
                            decoration: completed
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
              ),
              _StickyEditAffordance(
                todoId: row.todo.id,
                onPressed: _beginEdit,
                enabled: !_editing,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StickyInlineEditor extends StatelessWidget {
  const _StickyInlineEditor({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.onCancel,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      children: [
        Expanded(
          child: EditableText(
            controller: controller,
            focusNode: focusNode,
            style: TextStyle(color: colors.text, fontSize: 13),
            cursorColor: colors.focus,
            backgroundCursorColor: colors.textFaint,
            selectionColor: colors.focusSoft,
            maxLines: 1,
            onSubmitted: onSubmitted,
            autofocus: false,
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onSubmitted(controller.text),
          child: Padding(
            padding: const EdgeInsets.all(AppMetrics.unit),
            child: Icon(AppIcons.check, size: 15, color: colors.focus),
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onCancel,
          child: Padding(
            padding: const EdgeInsets.all(AppMetrics.unit),
            child: Icon(
              AppIcons.windowClose,
              size: 14,
              color: colors.textMuted,
            ),
          ),
        ),
      ],
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
    required this.onToggle,
  });

  final String todoId;
  final bool completed;
  final bool partial;
  final String title;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final active = completed || partial;
    return Semantics(
      button: onToggle != null,
      enabled: onToggle != null,
      checked: active,
      label: title,
      onTap: onToggle,
      child: Listener(
        key: ValueKey<String>('sticky-checkbox-$todoId'),
        behavior: HitTestBehavior.opaque,
        onPointerUp: (_) => onToggle?.call(),
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
      ),
    );
  }
}

class _StickyEditAffordance extends StatelessWidget {
  const _StickyEditAffordance({
    required this.todoId,
    required this.onPressed,
    required this.enabled,
  });

  final String todoId;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      button: true,
      enabled: enabled && onPressed != null,
      label: '编辑任务',
      child: Listener(
        key: ValueKey<String>('sticky-edit-$todoId'),
        behavior: HitTestBehavior.opaque,
        onPointerUp: enabled ? (_) => onPressed?.call() : null,
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
