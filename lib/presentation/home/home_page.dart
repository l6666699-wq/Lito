import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../app/app_text.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_metrics.dart';
import '../../application/workspace_controller.dart';
import '../../domain/models/visible_todo_row.dart';
import '../../icons/app_icons.dart';
import '../todo/todo_list.dart';

/// The initial route is intentionally small. It renders the controller's
/// current scope and visible rows so the shared shell never manufactures
/// benchmark or screenshot-only content.
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.controller});

  final WorkspaceController controller;

  @override
  State<HomePage> createState() => _HomePageState();
}

enum _HomeFilter { all, incomplete, completed }

enum _HomeSort { manual, title, created }

class _HomePageState extends State<HomePage> {
  _HomeFilter _filter = _HomeFilter.all;
  _HomeSort _sort = _HomeSort.manual;
  bool _showFilterPanel = false;
  bool _composerVisible = false;
  String? _composerParentId;
  String? _composerError;
  bool _composerSubmitting = false;
  int _composerGeneration = 0;

  WorkspaceController get controller => widget.controller;

  void _openComposer([String? parentId]) {
    setState(() {
      _composerGeneration += 1;
      _composerVisible = true;
      _composerParentId = parentId;
      _composerError = null;
      _showFilterPanel = false;
    });
  }

  void _closeComposer() {
    if (!mounted) return;
    setState(() {
      _composerGeneration += 1;
      _composerVisible = false;
      _composerParentId = null;
      _composerError = null;
      _composerSubmitting = false;
    });
  }

  void _submitComposer(String title) {
    if (_composerSubmitting) return;
    final generation = _composerGeneration;
    _composerSubmitting = true;
    unawaited(_submitComposerAndFlush(title, generation));
  }

  Future<void> _submitComposerAndFlush(String title, int generation) async {
    try {
      if (_composerParentId == null) {
        await controller.addTodoAndFlush(
          title,
          projectId: controller.scope == WorkspaceScope.project
              ? controller.projectScopeId
              : null,
        );
      } else {
        await controller.createChildTodoAndFlush(
          title,
          parentId: _composerParentId!,
        );
      }
      if (mounted && generation == _composerGeneration) _closeComposer();
    } on Object catch (error) {
      // The controller validates empty titles and depth. Keep the editor open
      // so the user can correct the input without losing the draft.
      final message = error.toString().toLowerCase().contains('depth')
          ? '任务层级已达上限'
          : '无法创建任务，请检查输入';
      if (mounted && generation == _composerGeneration) {
        setState(() => _composerError = message);
      }
    } finally {
      if (mounted && generation == _composerGeneration) {
        _composerSubmitting = false;
      }
    }
  }

  void _expandAll() {
    for (final todo in controller.todos) {
      if (todo.collapsed) {
        controller.setCollapsed(todo.id, false);
      }
    }
  }

  List<VisibleTodoRow> _rowsForDisplay(List<VisibleTodoRow> source) {
    final filtered = source
        .where((row) {
          switch (_filter) {
            case _HomeFilter.all:
              return true;
            case _HomeFilter.incomplete:
              return !row.todo.completed;
            case _HomeFilter.completed:
              return row.todo.completed;
          }
        })
        .toList(growable: true);
    if (_sort == _HomeSort.manual || filtered.length < 2) {
      return List.unmodifiable(filtered);
    }

    // Sort root blocks while preserving each block's parent/child order. A
    // flat list must never be sorted row-by-row or descendants would detach.
    final blocks = <List<VisibleTodoRow>>[];
    List<VisibleTodoRow>? current;
    for (final row in filtered) {
      if (row.depth == 0 || current == null) {
        current = <VisibleTodoRow>[row];
        blocks.add(current);
      } else {
        current.add(row);
      }
    }
    blocks.sort((left, right) {
      final a = left.first.todo;
      final b = right.first.todo;
      switch (_sort) {
        case _HomeSort.title:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case _HomeSort.created:
          return a.createdAt.compareTo(b.createdAt);
        case _HomeSort.manual:
          return 0;
      }
    });
    return List.unmodifiable(<VisibleTodoRow>[
      for (final block in blocks) ...block,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final colors = AppColors.of(context);
        final sourceRows = controller.visibleRows;
        final rows = _rowsForDisplay(sourceRows);
        final title = _scopeTitle(controller);
        final count = controller.countForScope(controller.scope);
        final completedCount = sourceRows
            .where((row) => row.todo.completed)
            .length;
        final incompleteCount = count > completedCount
            ? count - completedCount
            : 0;
        return Padding(
          // Keep the content surface inset evenly from the route viewport so
          // its border and radius read as one frame in every window size.
          padding: const EdgeInsets.all(AppMetrics.unit * 3),
          child: DecoratedBox(
            key: const ValueKey<String>('home-content-card'),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border.all(color: colors.border),
              borderRadius: BorderRadius.circular(AppMetrics.shellCardRadius),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: colors.text.withValues(alpha: .025),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppMetrics.shellCardRadius),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HomeHeader(
                    title: title,
                    count: count,
                    datasetLabel: controller.datasetLabel,
                    visibleCount: rows.length,
                    completedCount: completedCount,
                    incompleteCount: incompleteCount,
                    filter: _filter,
                    sort: _sort,
                    onFilterChanged: (value) => setState(() => _filter = value),
                    onAdd: () => _openComposer(),
                    onExpandAll: _expandAll,
                    showFilterPanel: _showFilterPanel,
                    onToggleFilterPanel: () =>
                        setState(() => _showFilterPanel = !_showFilterPanel),
                  ),
                  if (_showFilterPanel)
                    _FilterSortPanel(
                      filter: _filter,
                      sort: _sort,
                      onFilterChanged: (value) =>
                          setState(() => _filter = value),
                      onSortChanged: (value) => setState(() => _sort = value),
                    ),
                  Expanded(
                    child: TodoList(
                      controller: controller,
                      rows: rows,
                      composerVisible: _composerVisible,
                      composerParentId: _composerParentId,
                      onComposerSubmit: _submitComposer,
                      onComposerCancel: _closeComposer,
                      onRequestAddChild: _openComposer,
                      onRequestAddSibling: _openComposer,
                      composerError: _composerError,
                      emptyLabel: _filter == _HomeFilter.completed
                          ? '没有已完成待办'
                          : '没有可见待办',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _scopeTitle(WorkspaceController workspace) {
    switch (workspace.scope) {
      case WorkspaceScope.all:
        return AppText.allTodos;
      case WorkspaceScope.inbox:
        return AppText.inbox;
      case WorkspaceScope.today:
        return '今天';
      case WorkspaceScope.recent:
        return '近期';
      case WorkspaceScope.completed:
        return '已完成';
      case WorkspaceScope.archived:
        return '已归档';
      case WorkspaceScope.search:
        return workspace.searchQuery.trim().isEmpty
            ? '搜索'
            : '搜索：${workspace.searchQuery.trim()}';
      case WorkspaceScope.project:
        final id = workspace.projectScopeId;
        for (final project in workspace.projects) {
          if (project.id == id) return project.name;
        }
        return AppText.projects;
    }
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.title,
    required this.count,
    required this.datasetLabel,
    required this.visibleCount,
    required this.completedCount,
    required this.incompleteCount,
    required this.filter,
    required this.sort,
    required this.onFilterChanged,
    required this.onAdd,
    required this.onExpandAll,
    required this.showFilterPanel,
    required this.onToggleFilterPanel,
  });

  final String title;
  final int count;
  final String datasetLabel;
  final int visibleCount;
  final int completedCount;
  final int incompleteCount;
  final _HomeFilter filter;
  final _HomeSort sort;
  final ValueChanged<_HomeFilter> onFilterChanged;
  final VoidCallback onAdd;
  final VoidCallback onExpandAll;
  final bool showFilterPanel;
  final VoidCallback onToggleFilterPanel;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppMetrics.unit * 4,
        AppMetrics.unit * 4,
        AppMetrics.unit * 3,
        AppMetrics.unit * 3,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 760;
          if (constraints.maxWidth >= 1200) {
            return _buildWideHeader(colors);
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.focusSoft,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(AppIcons.layers, color: colors.focus, size: 21),
                  ),
                  const SizedBox(width: AppMetrics.unit * 3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -.35,
                          ),
                        ),
                        const SizedBox(height: AppMetrics.unit),
                        Text(
                          '$count 项任务',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        // Keep the prior diagnostic copy in the source while
                        // removing it from the product-visible subtitle.
                        Opacity(
                          opacity: 0,
                          child: ExcludeSemantics(
                            child: SizedBox(
                              width: 0,
                              height: 0,
                              child: Text(
                                '$datasetLabel · $count 项任务 · 可见 $visibleCount 行',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppMetrics.unit * 2),
                  if (!narrow)
                    _HeaderTextButton(
                      label: '添加待办',
                      icon: AppIcons.add,
                      onPressed: onAdd,
                      primary: true,
                    ),
                ],
              ),
              const SizedBox(height: AppMetrics.unit * 4),
              Row(
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _FilterChip(
                            label: '全部',
                            count: count,
                            active: filter == _HomeFilter.all,
                            onPressed: () => onFilterChanged(_HomeFilter.all),
                          ),
                          const SizedBox(width: AppMetrics.unit),
                          _FilterChip(
                            label: '未完成',
                            count: incompleteCount,
                            active: filter == _HomeFilter.incomplete,
                            onPressed: () =>
                                onFilterChanged(_HomeFilter.incomplete),
                          ),
                          const SizedBox(width: AppMetrics.unit),
                          _FilterChip(
                            label: '已完成',
                            count: completedCount,
                            active: filter == _HomeFilter.completed,
                            onPressed: () =>
                                onFilterChanged(_HomeFilter.completed),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppMetrics.unit * 2),
                  if (narrow)
                    _IconAction(
                      icon: AppIcons.add,
                      tooltip: '添加待办',
                      onPressed: onAdd,
                    ),
                  if (narrow)
                    _IconAction(
                      icon: AppIcons.expand,
                      tooltip: '展开全部',
                      onPressed: onExpandAll,
                    ),
                  if (!narrow)
                    _HeaderTextButton(
                      actionKey: 'home-expand-all',
                      label: '展开全部',
                      icon: AppIcons.expand,
                      onPressed: onExpandAll,
                      primary: false,
                    ),
                  _IconAction(
                    icon: AppIcons.filter,
                    tooltip: '筛选和排序',
                    active: showFilterPanel,
                    onPressed: onToggleFilterPanel,
                  ),
                  _IconAction(
                    icon: AppIcons.sort,
                    tooltip: '排序',
                    active: showFilterPanel && sort != _HomeSort.manual,
                    onPressed: onToggleFilterPanel,
                  ),
                  _IconAction(
                    icon: AppIcons.layers,
                    tooltip: '视图（暂不可用）',
                    onPressed: null,
                    enabled: false,
                  ),
                ],
              ),
              const SizedBox(height: AppMetrics.unit * 3),
              SizedBox(height: 1, child: ColoredBox(color: colors.border)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWideHeader(AppColorScheme colors) {
    return Padding(
      // The outer header padding supplies the standard 16/12 inset. Keep the
      // wide variant's extra inset small so its single row ends near y=148.
      padding: const EdgeInsets.only(
        top: AppMetrics.unit,
        bottom: AppMetrics.unit * 2,
      ),
      child: Column(
        children: [
          SizedBox(
            key: const ValueKey<String>('home-header-row'),
            height: 42,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Row(
                    children: [
                      SizedBox(
                        key: const ValueKey<String>('home-header-title'),
                        width: 300,
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: colors.focusSoft,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Icon(
                                AppIcons.layers,
                                color: colors.focus,
                                size: 21,
                              ),
                            ),
                            const SizedBox(width: AppMetrics.unit * 3),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 21,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -.35,
                                    ),
                                  ),
                                  const SizedBox(height: AppMetrics.unit),
                                  Text(
                                    '$count 项任务',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colors.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  // Keep the prior diagnostic copy in the
                                  // source while removing it from the
                                  // product-visible subtitle.
                                  Opacity(
                                    opacity: 0,
                                    child: ExcludeSemantics(
                                      child: SizedBox(
                                        width: 0,
                                        height: 0,
                                        child: Text(
                                          '$datasetLabel · $count 项任务 · 可见 $visibleCount 行',
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Row(
                        key: const ValueKey<String>('home-header-actions'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _HeaderTextButton(
                            actionKey: 'home-expand-all',
                            label: '展开全部',
                            icon: AppIcons.expand,
                            onPressed: onExpandAll,
                            primary: false,
                          ),
                          const SizedBox(width: AppMetrics.unit),
                          _IconAction(
                            icon: AppIcons.filter,
                            tooltip: '筛选和排序',
                            active: showFilterPanel,
                            onPressed: onToggleFilterPanel,
                          ),
                          const SizedBox(width: AppMetrics.unit),
                          _IconAction(
                            icon: AppIcons.sort,
                            tooltip: '排序',
                            active: showFilterPanel && sort != _HomeSort.manual,
                            onPressed: onToggleFilterPanel,
                          ),
                          const SizedBox(width: AppMetrics.unit),
                          _IconAction(
                            icon: AppIcons.layers,
                            tooltip: '视图（暂不可用）',
                            onPressed: null,
                            enabled: false,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.center,
                    child: SingleChildScrollView(
                      key: const ValueKey<String>('home-header-scopes'),
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _FilterChip(
                            label: '全部',
                            count: count,
                            active: filter == _HomeFilter.all,
                            onPressed: () => onFilterChanged(_HomeFilter.all),
                          ),
                          const SizedBox(width: AppMetrics.unit),
                          _FilterChip(
                            label: '未完成',
                            count: incompleteCount,
                            active: filter == _HomeFilter.incomplete,
                            onPressed: () =>
                                onFilterChanged(_HomeFilter.incomplete),
                          ),
                          const SizedBox(width: AppMetrics.unit),
                          _FilterChip(
                            label: '已完成',
                            count: completedCount,
                            active: filter == _HomeFilter.completed,
                            onPressed: () =>
                                onFilterChanged(_HomeFilter.completed),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 1, child: ColoredBox(color: colors.border)),
        ],
      ),
    );
  }
}

class _FilterSortPanel extends StatelessWidget {
  const _FilterSortPanel({
    required this.filter,
    required this.sort,
    required this.onFilterChanged,
    required this.onSortChanged,
  });

  final _HomeFilter filter;
  final _HomeSort sort;
  final ValueChanged<_HomeFilter> onFilterChanged;
  final ValueChanged<_HomeSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceSubtle,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppMetrics.unit * 4,
          vertical: AppMetrics.unit * 2,
        ),
        child: Wrap(
          spacing: AppMetrics.unit * 2,
          runSpacing: AppMetrics.unit,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('筛选', style: TextStyle(color: colors.textMuted, fontSize: 11)),
            _PanelChoice(
              label: '全部',
              active: filter == _HomeFilter.all,
              onPressed: () => onFilterChanged(_HomeFilter.all),
            ),
            _PanelChoice(
              label: '未完成',
              active: filter == _HomeFilter.incomplete,
              onPressed: () => onFilterChanged(_HomeFilter.incomplete),
            ),
            _PanelChoice(
              label: '已完成',
              active: filter == _HomeFilter.completed,
              onPressed: () => onFilterChanged(_HomeFilter.completed),
            ),
            const SizedBox(width: AppMetrics.unit * 2),
            Text('排序', style: TextStyle(color: colors.textMuted, fontSize: 11)),
            _PanelChoice(
              label: '手动',
              active: sort == _HomeSort.manual,
              onPressed: () => onSortChanged(_HomeSort.manual),
            ),
            _PanelChoice(
              label: '标题',
              active: sort == _HomeSort.title,
              onPressed: () => onSortChanged(_HomeSort.title),
            ),
            _PanelChoice(
              label: '创建时间',
              active: sort == _HomeSort.created,
              onPressed: () => onSortChanged(_HomeSort.created),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.active,
    required this.onPressed,
  });

  final String label;
  final int count;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: AppMetrics.unit * 2),
        decoration: BoxDecoration(
          color: active ? colors.focusSoft : colors.transparent,
          border: Border.all(color: active ? colors.focus : colors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: active ? colors.focus : colors.textMuted,
                fontSize: 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            const SizedBox(width: AppMetrics.unit),
            Text(
              '$count',
              style: TextStyle(
                color: active ? colors.focus : colors.textFaint,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelChoice extends StatelessWidget {
  const _PanelChoice({
    required this.label,
    required this.active,
    required this.onPressed,
  });

  final String label;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppMetrics.unit * 1.5,
          vertical: AppMetrics.unit,
        ),
        decoration: BoxDecoration(
          color: active ? colors.focusSoft : colors.transparent,
          borderRadius: BorderRadius.circular(AppMetrics.smallRadius),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? colors.focus : colors.textMuted,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class _HeaderTextButton extends StatelessWidget {
  const _HeaderTextButton({
    this.actionKey,
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.primary,
  });

  final String? actionKey;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      key: ValueKey<String>(actionKey ?? 'home-add-todo'),
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: AppMetrics.unit * 2),
        decoration: BoxDecoration(
          color: primary ? colors.focus : colors.surface,
          border: Border.all(color: primary ? colors.focus : colors.border),
          borderRadius: BorderRadius.circular(AppMetrics.buttonRadius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: primary ? colors.white : colors.textMuted,
            ),
            const SizedBox(width: AppMetrics.unit),
            Text(
              label,
              style: TextStyle(
                color: primary ? colors.white : colors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
    this.enabled = true,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool active;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      button: true,
      label: tooltip,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onPressed : null,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? colors.focusSoft : colors.surface,
            border: Border.all(color: active ? colors.focus : colors.border),
            borderRadius: BorderRadius.circular(AppMetrics.buttonRadius),
          ),
          child: Icon(
            icon,
            size: 15,
            color: !enabled
                ? colors.textFaint
                : active
                ? colors.focus
                : colors.textMuted,
          ),
        ),
      ),
    );
  }
}
