import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_metrics.dart';
import '../../domain/services/todo_move_service.dart';
import '../../domain/models/visible_todo_row.dart';
import '../../icons/app_icons.dart';
import 'todo_drag_data.dart';

/// A lazily-rendered row for one flattened tree item.
///
/// The row deliberately owns only ephemeral presentation state (hover and
/// inline editing). All business mutations are supplied by [WorkspaceController]
/// callbacks from [TodoList].
class TodoRow extends StatefulWidget {
  const TodoRow({
    super.key,
    required this.row,
    required this.hasChildren,
    required this.onToggleCollapsed,
    this.onToggleCompleted,
    this.onEdit,
    this.onAddChild,
    this.onArchive,
    this.onDelete,
    this.selected = false,
    this.onSelect,
    this.isRoot = false,
    this.sectionNumber,
    this.childCount = 0,
    this.completedChildCount = 0,
    this.editRequest = 0,
    this.onEditRequestConsumed,
    this.onEditingChanged,
    this.onDragMove,
    this.onDragLeave,
    this.onAcceptDrag,
    this.dropPosition,
    this.rowHeightOverride,
  });

  final VisibleTodoRow row;
  final bool hasChildren;
  final VoidCallback onToggleCollapsed;
  final VoidCallback? onToggleCompleted;
  final ValueChanged<String>? onEdit;
  final VoidCallback? onAddChild;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;
  final bool selected;
  final VoidCallback? onSelect;
  final bool isRoot;
  final int? sectionNumber;
  final int childCount;
  final int completedChildCount;
  final int editRequest;
  final VoidCallback? onEditRequestConsumed;
  final ValueChanged<bool>? onEditingChanged;
  final ValueChanged<TodoDropCandidate>? onDragMove;
  final VoidCallback? onDragLeave;
  final ValueChanged<TodoDragData>? onAcceptDrag;
  final TodoMovePosition? dropPosition;
  final double? rowHeightOverride;

  @override
  State<TodoRow> createState() => _TodoRowState();
}

class _TodoRowState extends State<TodoRow> {
  late final TextEditingController _editController = TextEditingController(
    text: widget.row.todo.title,
  );
  late final FocusNode _editFocusNode = FocusNode(
    debugLabel: 'todo-inline-editor',
  );
  bool _hovered = false;
  bool _editing = false;
  late final GlobalKey _dropRegionKey = GlobalKey(
    debugLabel: 'todo-drop-region-${widget.row.todo.id}',
  );

  @override
  void didUpdateWidget(covariant TodoRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && oldWidget.row.todo.title != widget.row.todo.title) {
      _editController.text = widget.row.todo.title;
    }
    if (oldWidget.editRequest != widget.editRequest &&
        widget.editRequest != 0) {
      _beginEdit(deferNotification: true);
      widget.onEditRequestConsumed?.call();
    }
  }

  @override
  void dispose() {
    _editController.dispose();
    _editFocusNode.dispose();
    super.dispose();
  }

  void _beginEdit({bool deferNotification = false}) {
    if (widget.onEdit == null) return;
    setState(() {
      _editing = true;
      _editController.value = TextEditingValue(
        text: widget.row.todo.title,
        selection: TextSelection.collapsed(
          offset: widget.row.todo.title.length,
        ),
      );
    });
    if (deferNotification) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onEditingChanged?.call(true);
      });
    } else {
      widget.onEditingChanged?.call(true);
    }
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
    widget.onEditingChanged?.call(false);
  }

  void _commitEdit() {
    final title = _editController.text.trim();
    if (title.isEmpty) {
      _cancelEdit();
      return;
    }
    widget.onEdit?.call(title);
    if (mounted) {
      setState(() => _editing = false);
      widget.onEditingChanged?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final state = widget.row.completionState;
    final completed = state == TodoVisualState.complete;
    final partial = state == TodoVisualState.partial;
    final titleColor = completed ? colors.textFaint : colors.text;
    final rowHeight = widget.isRoot
        ? AppMetrics.todoRootRowHeight
        : widget.rowHeightOverride ?? AppMetrics.todoRowHeight;
    final background = widget.selected
        ? colors.focusSoft
        : _hovered
        ? colors.surfaceSubtle
        : colors.transparent;

    return Builder(
      builder: (_) {
        return DragTarget<TodoDragData>(
          onWillAcceptWithDetails: (details) =>
              details.data.movingId != widget.row.todo.id,
          onMove: (details) {
            final renderObject = _dropRegionKey.currentContext
                ?.findRenderObject();
            if (renderObject is! RenderBox) return;
            final local = renderObject.globalToLocal(details.offset);
            final fraction = (local.dy / renderObject.size.height).clamp(
              0.0,
              1.0,
            );
            final position = fraction < .30
                ? TodoMovePosition.before
                : fraction > .70
                ? TodoMovePosition.after
                : TodoMovePosition.inside;
            widget.onDragMove?.call(
              TodoDropCandidate(
                movingId: details.data.movingId,
                targetId: widget.row.todo.id,
                position: position,
              ),
            );
          },
          onLeave: (_) => widget.onDragLeave?.call(),
          onAcceptWithDetails: (details) =>
              widget.onAcceptDrag?.call(details.data),
          builder: (context, candidateData, rejectedData) {
            final content = Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => widget.onSelect?.call(),
              child: MouseRegion(
                onEnter: (_) => setState(() => _hovered = true),
                onExit: (_) => setState(() => _hovered = false),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    widget.onSelect?.call();
                  },
                  onDoubleTap: _beginEdit,
                  child: AnimatedContainer(
                    key: _dropRegionKey,
                    duration: const Duration(milliseconds: 100),
                    curve: Curves.easeOut,
                    height: rowHeight,
                    margin: EdgeInsets.only(
                      left: widget.isRoot
                          ? 0
                          : widget.row.depth * AppMetrics.treeIndent,
                      right: widget.isRoot ? 0 : AppMetrics.unit * 2,
                      top: widget.isRoot ? 0 : 1,
                    ),
                    padding: EdgeInsets.only(
                      left: widget.isRoot
                          ? AppMetrics.unit * 2
                          : AppMetrics.unit,
                      right: AppMetrics.unit * 2,
                    ),
                    decoration: BoxDecoration(
                      color: background,
                      border: widget.isRoot
                          ? Border(
                              top: BorderSide(color: colors.border),
                              bottom: BorderSide(color: colors.border),
                            )
                          : null,
                      borderRadius: BorderRadius.circular(
                        AppMetrics.smallRadius,
                      ),
                    ),
                    child: _editing
                        ? Focus(
                            onKeyEvent: (node, event) {
                              if (event is KeyDownEvent &&
                                  event.logicalKey ==
                                      LogicalKeyboardKey.escape) {
                                _cancelEdit();
                                return KeyEventResult.handled;
                              }
                              return KeyEventResult.ignored;
                            },
                            child: _InlineEditor(
                              controller: _editController,
                              focusNode: _editFocusNode,
                              onSubmitted: (_) => _commitEdit(),
                              onCancel: _cancelEdit,
                            ),
                          )
                        : widget.isRoot
                        ? _rootContent(
                            colors: colors,
                            completed: completed,
                            partial: partial,
                            titleColor: titleColor,
                          )
                        : _todoContent(
                            colors: colors,
                            completed: completed,
                            partial: partial,
                            titleColor: titleColor,
                          ),
                  ),
                ),
              ),
            );
            final dropPosition = widget.dropPosition;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                content,
                if (dropPosition == TodoMovePosition.before)
                  _dropIndicator(colors, top: 0),
                if (dropPosition == TodoMovePosition.after)
                  _dropIndicator(colors, bottom: 0),
                if (dropPosition == TodoMovePosition.inside)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.focusSoft.withValues(alpha: .35),
                          border: Border.all(color: colors.focus, width: 1.2),
                          borderRadius: BorderRadius.circular(
                            AppMetrics.smallRadius,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _dropIndicator(AppColorScheme colors, {double? top, double? bottom}) {
    return Positioned(
      left: widget.row.depth * AppMetrics.treeIndent,
      right: AppMetrics.unit * 2,
      top: top,
      bottom: bottom,
      height: 2,
      child: IgnorePointer(child: ColoredBox(color: colors.focus)),
    );
  }

  Widget _dragHandle(AppColorScheme colors) {
    return Draggable<TodoDragData>(
      key: ValueKey<String>('todo-drag-handle-${widget.row.todo.id}'),
      data: TodoDragData(widget.row.todo.id),
      onDragStarted: () => widget.onDragMove?.call(
        TodoDropCandidate(
          movingId: widget.row.todo.id,
          targetId: widget.row.todo.id,
          position: TodoMovePosition.before,
        ),
      ),
      feedback: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.borderStrong),
          borderRadius: BorderRadius.circular(AppMetrics.smallRadius),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: colors.text.withValues(alpha: .12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppMetrics.unit * 2,
            vertical: AppMetrics.unit,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIcons.dragHandle, size: 14, color: colors.textMuted),
              const SizedBox(width: AppMetrics.unit),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: Text(
                  widget.row.todo.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.text, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: .35,
        child: Icon(AppIcons.dragHandle, size: 15, color: colors.textFaint),
      ),
      child: Semantics(
        button: true,
        label: '拖拽排序',
        child: Icon(
          AppIcons.dragHandle,
          size: 15,
          color: _hovered ? colors.textMuted : colors.textFaint,
        ),
      ),
    );
  }

  Widget _actionButton({
    required BuildContext context,
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    final colors = AppColors.of(context);
    if (onPressed == null) return const SizedBox.shrink();
    return Semantics(
      button: true,
      label: tooltip,
      child: Listener(
        key: ValueKey<String>('todo-action-${widget.row.todo.id}-$tooltip'),
        behavior: HitTestBehavior.opaque,
        onPointerUp: (_) => onPressed(),
        child: Padding(
          padding: const EdgeInsets.all(AppMetrics.unit * 1.5),
          child: Icon(icon, size: 14, color: colors.textMuted),
        ),
      ),
    );
  }

  Widget _leadingCheck({
    required BuildContext context,
    required bool completed,
    required bool partial,
  }) {
    final colors = AppColors.of(context);
    final active = completed || partial;
    return Listener(
      key: ValueKey<String>('todo-toggle-${widget.row.todo.id}'),
      behavior: HitTestBehavior.opaque,
      onPointerUp: (_) => widget.onToggleCompleted?.call(),
      child: Semantics(
        button: true,
        label: completed
            ? '取消完成 ${widget.row.todo.title}'
            : '完成 ${widget.row.todo.title}',
        child: Container(
          width: widget.isRoot ? 19 : 18,
          height: widget.isRoot ? 19 : 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: completed ? colors.focus : colors.transparent,
            border: Border.all(
              color: active ? colors.focus : colors.borderStrong,
              width: 1.2,
            ),
            borderRadius: BorderRadius.circular(widget.isRoot ? 5 : 4),
          ),
          child: completed
              ? Icon(AppIcons.check, color: colors.white, size: 12)
              : partial
              ? Icon(AppIcons.minus, color: colors.focus, size: 12)
              : null,
        ),
      ),
    );
  }

  Widget _todoContent({
    required AppColorScheme colors,
    required bool completed,
    required bool partial,
    required Color titleColor,
  }) {
    return Row(
      children: [
        const SizedBox(width: AppMetrics.unit),
        _dragHandle(colors),
        const SizedBox(width: AppMetrics.unit),
        widget.hasChildren
            ? Listener(
                key: ValueKey<String>('todo-collapse-${widget.row.todo.id}'),
                behavior: HitTestBehavior.opaque,
                onPointerUp: (_) => widget.onToggleCollapsed(),
                child: SizedBox(
                  width: 14,
                  child: Icon(
                    widget.row.todo.collapsed
                        ? AppIcons.chevronRight
                        : AppIcons.chevronDown,
                    size: 13,
                    color: colors.textMuted,
                  ),
                ),
              )
            : const SizedBox(width: 14),
        const SizedBox(width: AppMetrics.unit * 2),
        _leadingCheck(context: context, completed: completed, partial: partial),
        const SizedBox(width: AppMetrics.unit * 2),
        Expanded(
          child: Text(
            widget.row.todo.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: titleColor,
              fontSize: 13,
              decoration: completed ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
        if (_hovered) ...[
          _actionButton(
            context: context,
            icon: AppIcons.add,
            tooltip: '添加子任务',
            onPressed: widget.onAddChild,
          ),
          _actionButton(
            context: context,
            icon: AppIcons.archive,
            tooltip: '归档任务',
            onPressed: widget.onArchive,
          ),
          _actionButton(
            context: context,
            icon: AppIcons.delete,
            tooltip: '移入回收站',
            onPressed: widget.onDelete,
          ),
          _actionButton(
            context: context,
            icon: AppIcons.edit,
            tooltip: '编辑任务',
            onPressed: _beginEdit,
          ),
        ],
      ],
    );
  }

  Widget _rootContent({
    required AppColorScheme colors,
    required bool completed,
    required bool partial,
    required Color titleColor,
  }) {
    final total = widget.childCount;
    final done = widget.completedChildCount;
    final ratio = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    return Row(
      children: [
        _dragHandle(colors),
        const SizedBox(width: AppMetrics.unit),
        widget.hasChildren
            ? Listener(
                key: ValueKey<String>('todo-collapse-${widget.row.todo.id}'),
                behavior: HitTestBehavior.opaque,
                onPointerUp: (_) => widget.onToggleCollapsed(),
                child: SizedBox(
                  width: 22,
                  child: Icon(
                    widget.row.todo.collapsed
                        ? AppIcons.chevronRight
                        : AppIcons.chevronDown,
                    size: 15,
                    color: colors.textMuted,
                  ),
                ),
              )
            : const SizedBox(width: 22),
        if (widget.sectionNumber != null) ...[
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.focusSoft,
              border: Border.all(color: colors.focus.withValues(alpha: .35)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${widget.sectionNumber}',
              style: TextStyle(
                color: colors.focus,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppMetrics.unit * 2),
        ],
        _leadingCheck(context: context, completed: completed, partial: partial),
        const SizedBox(width: AppMetrics.unit * 2),
        Expanded(
          child: Text(
            widget.row.todo.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: titleColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              decoration: completed ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
        if (total > 0) ...[
          Text(
            '$done/$total',
            style: TextStyle(color: colors.textMuted, fontSize: 11),
          ),
          const SizedBox(width: AppMetrics.unit * 2),
          SizedBox(
            width: 86,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 5,
                child: Stack(
                  children: [
                    ColoredBox(color: colors.surfaceSubtle),
                    FractionallySizedBox(
                      widthFactor: ratio,
                      child: ColoredBox(color: colors.focus),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        if (_hovered) ...[
          _actionButton(
            context: context,
            icon: AppIcons.add,
            tooltip: '添加子任务',
            onPressed: widget.onAddChild,
          ),
          _actionButton(
            context: context,
            icon: AppIcons.edit,
            tooltip: '编辑任务',
            onPressed: _beginEdit,
          ),
          _actionButton(
            context: context,
            icon: AppIcons.archive,
            tooltip: '归档任务',
            onPressed: widget.onArchive,
          ),
          _actionButton(
            context: context,
            icon: AppIcons.delete,
            tooltip: '移入回收站',
            onPressed: widget.onDelete,
          ),
        ],
      ],
    );
  }
}

class _InlineEditor extends StatelessWidget {
  const _InlineEditor({
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
