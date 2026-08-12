import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_metrics.dart';
import '../../application/workspace_controller.dart';
import '../../domain/models/project.dart';
import '../../domain/models/todo_item.dart';
import '../../domain/models/trash_item.dart';
import '../../icons/app_icons.dart';
import '../../icons/project_icon.dart';
import '../../app/theme/project_palette.dart';

/// The local recycle bin.  Trash is intentionally a real workspace route:
/// entries are read from [WorkspaceController], not from a presentation-only
/// fixture, and every restore/clear operation uses the controller's mutation
/// and persistence path.
class TrashPage extends StatefulWidget {
  const TrashPage({super.key, required this.controller});

  final WorkspaceController controller;

  @override
  State<TrashPage> createState() => _TrashPageState();
}

enum _TrashFilter { all, todo, project }

class _TrashPageState extends State<TrashPage> {
  String? _statusMessage;
  bool _statusIsError = false;
  bool _busy = false;
  _TrashFilter _filter = _TrashFilter.all;

  WorkspaceController get controller => widget.controller;

  void _showStatus(String message, {bool error = false}) {
    if (!mounted) return;
    setState(() {
      _statusMessage = message;
      _statusIsError = error;
    });
  }

  Future<void> _restore(TrashItem item) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final restored = controller.restoreTrash(item.id);
      if (!restored) {
        _showStatus('这条回收站记录无法恢复。', error: true);
        return;
      }
      final persisted = await _flushMutation();
      if (persisted) {
        _showStatus('已恢复：${_TrashRecord.from(item, controller).title}');
      }
    } catch (_) {
      _showStatus('恢复失败，原记录仍保留在回收站。', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearTrash() async {
    if (_busy || controller.trash.isEmpty) return;
    final confirmed = await _confirmClear(context);
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final cleared = controller.clearTrash();
      if (!cleared) return;
      final persisted = await _flushMutation();
      if (persisted) _showStatus('回收站已清空，可使用 Ctrl+Z 撤销。');
    } catch (_) {
      _showStatus('清空失败，请稍后重试。', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _flushMutation() async {
    try {
      await controller.flushNow();
      return true;
    } catch (_) {
      // The controller keeps the mutation in memory and exposes the durable
      // write failure.  The page reports it without blocking restore/clear.
      _showStatus('已更新回收站，但保存失败，将稍后重试。', error: true);
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 620;
        return ListenableBuilder(
          listenable: controller,
          builder: (context, child) {
            final items = controller.trash;
            final entries = [
              for (final item in items)
                _TrashEntry(
                  item: item,
                  record: _TrashRecord.from(item, controller),
                ),
            ];
            final taskCount = entries
                .where((entry) => !entry.record.isProject)
                .length;
            final projectCount = entries
                .where((entry) => entry.record.isProject)
                .length;
            final effectiveFilter = _availableFilter(
              _filter,
              allCount: entries.length,
              taskCount: taskCount,
              projectCount: projectCount,
            );
            final visibleEntries = entries
                .where((entry) {
                  return switch (effectiveFilter) {
                    _TrashFilter.all => true,
                    _TrashFilter.todo => !entry.record.isProject,
                    _TrashFilter.project => entry.record.isProject,
                  };
                })
                .toList(growable: false);
            final headerSliver = SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppMetrics.pagePadding,
                AppMetrics.pagePadding,
                AppMetrics.pagePadding,
                0,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate(<Widget>[
                  _TrashHeader(
                    colors: colors,
                    narrow: narrow,
                    itemCount: items.length,
                    taskCount: taskCount,
                    projectCount: projectCount,
                    selectedFilter: effectiveFilter,
                    onFilterChanged: (filter) => setState(() {
                      _filter = filter;
                    }),
                    busy: _busy,
                    onClear: _clearTrash,
                  ),
                  if (_statusMessage != null) ...[
                    const SizedBox(height: AppMetrics.unit * 3),
                    _StatusBanner(
                      message: _statusMessage!,
                      error: _statusIsError,
                      colors: colors,
                      onDismiss: () => setState(() => _statusMessage = null),
                    ),
                  ],
                  const SizedBox(height: AppMetrics.unit * 4),
                ]),
              ),
            );
            if (items.isEmpty) {
              return CustomScrollView(
                slivers: [
                  headerSliver,
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppMetrics.pagePadding,
                      0,
                      AppMetrics.pagePadding,
                      AppMetrics.pagePadding,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _EmptyTrash(colors: colors),
                    ),
                  ),
                ],
              );
            }
            return CustomScrollView(
              slivers: [
                headerSliver,
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppMetrics.pagePadding,
                    0,
                    AppMetrics.pagePadding,
                    AppMetrics.pagePadding,
                  ),
                  sliver: SliverList(
                    key: const ValueKey<String>('trash-list-builder'),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final entry = visibleEntries[index];
                      return _TrashCard(
                        key: ValueKey<String>('trash-item-${entry.item.id}'),
                        record: entry.record,
                        colors: colors,
                        enabled: !_busy,
                        first: index == 0,
                        last: index == visibleEntries.length - 1,
                        onRestore: () => _restore(entry.item),
                      );
                    }, childCount: visibleEntries.length),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool?> _confirmClear(BuildContext context) {
    return showShadDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ShadDialog.alert(
        key: const ValueKey<String>('trash-clear-confirm-dialog'),
        title: const Text('清空回收站？'),
        description: const Text(
          '回收站中的 Todo 和项目将被移除，本次运行期间可使用 Ctrl+Z 撤销。',
          key: ValueKey<String>('trash-clear-confirm-description'),
        ),
        // Keep the warning copy and action row visually distinct even when
        // the responsive dialog stacks its buttons at the narrow breakpoint.
        gap: AppMetrics.unit * 4,
        actionsGap: AppMetrics.unit * 2,
        actions: [
          ShadButton.ghost(
            key: const ValueKey<String>('trash-clear-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ShadButton.destructive(
            key: const ValueKey<String>('trash-clear-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(AppIcons.delete, size: 14),
                const SizedBox(width: AppMetrics.unit),
                const Text('清空回收站'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

_TrashFilter _availableFilter(
  _TrashFilter preferred, {
  required int allCount,
  required int taskCount,
  required int projectCount,
}) {
  final count = switch (preferred) {
    _TrashFilter.all => allCount,
    _TrashFilter.todo => taskCount,
    _TrashFilter.project => projectCount,
  };
  return count == 0 ? _TrashFilter.all : preferred;
}

class _TrashHeader extends StatelessWidget {
  const _TrashHeader({
    required this.colors,
    required this.narrow,
    required this.itemCount,
    required this.taskCount,
    required this.projectCount,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.busy,
    required this.onClear,
  });

  final AppColorScheme colors;
  final bool narrow;
  final int itemCount;
  final int taskCount;
  final int projectCount;
  final _TrashFilter selectedFilter;
  final ValueChanged<_TrashFilter> onFilterChanged;
  final bool busy;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final destructive = ProjectPalette.resolve('red');
    final heading = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.focusSoft,
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppMetrics.unit * 2.75),
            child: Icon(AppIcons.trash, color: colors.focus, size: 18),
          ),
        ),
        const SizedBox(width: AppMetrics.unit * 3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '回收站',
                style: TextStyle(
                  color: colors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppMetrics.unit * .75),
              Text(
                itemCount == 0
                    ? '已删除的 Todo 和项目会暂时保留在这里。'
                    : '$itemCount 条记录，恢复后会回到原来的位置。',
                style: TextStyle(color: colors.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
    final clear = ShadButton.ghost(
      key: const ValueKey<String>('trash-clear-button'),
      onPressed: busy || itemCount == 0 ? null : onClear,
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: AppMetrics.unit * 2),
      foregroundColor: destructive.foreground,
      hoverBackgroundColor: destructive.softBackground,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(AppIcons.delete, size: 15),
          const SizedBox(width: AppMetrics.unit),
          const Text('清空回收站', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
    final filters = _TrashFilterBar(
      colors: colors,
      selected: selectedFilter,
      allCount: itemCount,
      taskCount: taskCount,
      projectCount: projectCount,
      onChanged: onFilterChanged,
    );
    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          heading,
          const SizedBox(height: AppMetrics.unit * 3.5),
          Align(alignment: Alignment.centerLeft, child: filters),
          const SizedBox(height: AppMetrics.unit * 2.5),
          Align(alignment: Alignment.centerLeft, child: clear),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: heading),
            const SizedBox(width: AppMetrics.unit * 3),
            clear,
          ],
        ),
        const SizedBox(height: AppMetrics.unit * 4),
        Align(alignment: Alignment.centerLeft, child: filters),
      ],
    );
  }
}

class _TrashFilterBar extends StatelessWidget {
  const _TrashFilterBar({
    required this.colors,
    required this.selected,
    required this.allCount,
    required this.taskCount,
    required this.projectCount,
    required this.onChanged,
  });

  final AppColorScheme colors;
  final _TrashFilter selected;
  final int allCount;
  final int taskCount;
  final int projectCount;
  final ValueChanged<_TrashFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppMetrics.normalRadius),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppMetrics.unit),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TrashFilterChip(
              label: '\u5168\u90e8',
              count: allCount,
              selected: selected == _TrashFilter.all,
              colors: colors,
              onPressed: () => onChanged(_TrashFilter.all),
            ),
            _TrashFilterChip(
              label: '\u4efb\u52a1',
              count: taskCount,
              selected: selected == _TrashFilter.todo,
              colors: colors,
              onPressed: taskCount == 0
                  ? null
                  : () => onChanged(_TrashFilter.todo),
            ),
            _TrashFilterChip(
              label: '\u9879\u76ee',
              count: projectCount,
              selected: selected == _TrashFilter.project,
              colors: colors,
              onPressed: projectCount == 0
                  ? null
                  : () => onChanged(_TrashFilter.project),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrashFilterChip extends StatelessWidget {
  const _TrashFilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.colors,
    required this.onPressed,
  });

  final String label;
  final int count;
  final bool selected;
  final AppColorScheme colors;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final textColor = !enabled
        ? colors.textFaint
        : selected
        ? colors.focus
        : colors.textMuted;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? colors.focusSoft : colors.transparent,
          borderRadius: BorderRadius.circular(AppMetrics.buttonRadius),
          border: selected
              ? Border.all(color: colors.focus.withValues(alpha: .22))
              : null,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: selected ? AppMetrics.unit * 4 : AppMetrics.unit * 3.5,
            vertical: selected ? AppMetrics.unit * 1.5 : AppMetrics.unit * 1.25,
          ),
          child: Text(
            '$label  $count',
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _TrashCard extends StatelessWidget {
  const _TrashCard({
    super.key,
    required this.record,
    required this.colors,
    required this.enabled,
    required this.first,
    required this.last,
    required this.onRestore,
  });

  final _TrashRecord record;
  final AppColorScheme colors;
  final bool enabled;
  final bool first;
  final bool last;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final palette = ProjectPalette.resolve(record.colorKey);
    final metadata = Wrap(
      spacing: AppMetrics.unit * 3,
      runSpacing: AppMetrics.unit,
      children: [
        _Meta(
          icon: AppIcons.clock,
          text: '删除于 ${record.deletedAtLabel}',
          colors: colors,
        ),
        _Meta(
          icon: AppIcons.folder,
          text: '原项目：${record.projectLabel}',
          colors: colors,
        ),
      ],
    );
    final action = ShadButton.outline(
      key: ValueKey<String>('trash-restore-${record.id}'),
      onPressed: enabled ? onRestore : null,
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: AppMetrics.unit * 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(AppIcons.restore, size: 14),
          const SizedBox(width: AppMetrics.unit),
          const Text('恢复', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(first ? AppMetrics.cardRadius : 0),
          bottom: Radius.circular(last ? AppMetrics.cardRadius : 0),
        ),
        border: Border(
          top: first ? BorderSide(color: colors.border) : BorderSide.none,
          left: BorderSide(color: colors.border),
          right: BorderSide(color: colors.border),
          bottom: BorderSide(color: colors.border),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppMetrics.unit * 3,
          AppMetrics.unit * 2.5,
          AppMetrics.unit * 3,
          AppMetrics.unit * 2.5,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 560;
            final icon = DecoratedBox(
              decoration: BoxDecoration(
                color: palette.softBackground,
                borderRadius: BorderRadius.circular(AppMetrics.normalRadius),
              ),
              child: SizedBox(
                width: AppMetrics.unit * 9,
                height: AppMetrics.unit * 9,
                child: Center(
                  child: record.isProject
                      ? ProjectIcon(
                          iconKey: record.iconKey,
                          color: palette.accent,
                          size: 18,
                        )
                      : Icon(
                          AppIcons.completed,
                          color: palette.accent,
                          size: 18,
                        ),
                ),
              ),
            );
            final details = Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    record.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppMetrics.unit * 1.25),
                  metadata,
                ],
              ),
            );
            final content = Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                icon,
                const SizedBox(width: AppMetrics.unit * 3),
                details,
                if (!compact) ...[
                  const SizedBox(width: AppMetrics.unit * 3),
                  _KindBadge(record: record, colors: colors),
                  const SizedBox(width: AppMetrics.unit * 8),
                  action,
                ],
              ],
            );
            return ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        content,
                        const SizedBox(height: AppMetrics.unit * 2),
                        Row(
                          children: [
                            _KindBadge(record: record, colors: colors),
                            const Spacer(),
                            action,
                          ],
                        ),
                      ],
                    )
                  : content,
            );
          },
        ),
      ),
    );
  }
}

class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.record, required this.colors});

  final _TrashRecord record;
  final AppColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final label = record.isProject ? '项目' : 'Todo 子树';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: record.isProject ? colors.focusSoft : colors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppMetrics.smallRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppMetrics.unit * 2,
          vertical: AppMetrics.unit * 1.25,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: record.isProject ? colors.focus : colors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text, required this.colors});

  final IconData icon;
  final String text;
  final AppColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: colors.textFaint),
        const SizedBox(width: AppMetrics.unit),
        Text(text, style: TextStyle(color: colors.textMuted, fontSize: 10.5)),
      ],
    );
  }
}

class _EmptyTrash extends StatelessWidget {
  const _EmptyTrash({required this.colors});

  final AppColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppMetrics.cardRadius),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppMetrics.unit * 14),
        child: Column(
          children: [
            Icon(AppIcons.trash, size: 32, color: colors.textFaint),
            const SizedBox(height: AppMetrics.unit * 3),
            Text(
              '回收站是空的',
              style: TextStyle(
                color: colors.text,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppMetrics.unit),
            Text(
              '删除的 Todo 和项目会显示在这里。',
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.message,
    required this.error,
    required this.colors,
    required this.onDismiss,
  });

  final String message;
  final bool error;
  final AppColorScheme colors;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final color = error ? const Color(0xFFDC5A62) : colors.focus;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(AppMetrics.normalRadius),
        border: Border.all(color: color.withValues(alpha: .22)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppMetrics.unit * 3,
          vertical: AppMetrics.unit * 2,
        ),
        child: Row(
          children: [
            Icon(
              error ? AppIcons.info : AppIcons.check,
              size: 16,
              color: color,
            ),
            const SizedBox(width: AppMetrics.unit * 2),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: colors.text, fontSize: 12),
              ),
            ),
            ShadButton.ghost(
              key: const ValueKey<String>('trash-status-dismiss'),
              onPressed: onDismiss,
              height: 26,
              width: 26,
              padding: EdgeInsets.zero,
              foregroundColor: colors.textMuted,
              hoverBackgroundColor: colors.focusSoft,
              child: const Icon(AppIcons.windowClose, size: 15),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrashEntry {
  const _TrashEntry({required this.item, required this.record});

  final TrashItem item;
  final _TrashRecord record;
}

class _TrashRecord {
  const _TrashRecord({
    required this.id,
    required this.title,
    required this.projectLabel,
    required this.deletedAtLabel,
    required this.isProject,
    required this.iconKey,
    required this.colorKey,
  });

  final String id;
  final String title;
  final String projectLabel;
  final String deletedAtLabel;
  final bool isProject;
  final String iconKey;
  final String colorKey;

  factory _TrashRecord.from(TrashItem item, WorkspaceController controller) {
    final isProject = item.kind == 'project_subtree';
    if (isProject) return _projectRecord(item);
    return _todoRecord(item, controller);
  }

  static _TrashRecord _projectRecord(TrashItem item) {
    final raw = item.payload['project'];
    final project = raw is Map
        ? Project.fromJson(Map<String, dynamic>.from(raw))
        : null;
    final deletedAt = _readDeletedAt(item, project?.updatedAt);
    return _TrashRecord(
      id: item.id,
      title: project?.name.isNotEmpty == true ? project!.name : '已删除项目',
      projectLabel: project?.name.isNotEmpty == true ? project!.name : '项目已删除',
      deletedAtLabel: deletedAt,
      isProject: true,
      iconKey: project?.iconKey ?? 'folder',
      colorKey: project?.colorKey ?? 'gray',
    );
  }

  static _TrashRecord _todoRecord(
    TrashItem item,
    WorkspaceController controller,
  ) {
    final todos = _decodeTodos(item.payload['todos']);
    final rootId = item.payload['rootId'] as String?;
    TodoItem? root;
    for (final todo in todos) {
      if (todo.id == rootId) {
        root = todo;
        break;
      }
    }
    root ??= todos.isEmpty ? null : todos.first;
    final project = root == null
        ? null
        : _projectFor(controller, root.projectId);
    final projectLabel = root?.projectId == null
        ? '收集箱'
        : project?.name ?? '项目已删除';
    return _TrashRecord(
      id: item.id,
      title: root?.title.isNotEmpty == true ? root!.title : '已删除 Todo 子树',
      projectLabel: projectLabel,
      deletedAtLabel: _readDeletedAt(item, root?.updatedAt),
      isProject: false,
      iconKey: project?.iconKey ?? 'check-circle',
      colorKey: project?.colorKey ?? 'gray',
    );
  }

  static Project? _projectFor(WorkspaceController controller, String? id) {
    if (id == null) return null;
    for (final project in controller.projects) {
      if (project.id == id) return project;
    }
    return null;
  }

  static List<TodoItem> _decodeTodos(Object? raw) {
    if (raw is! List) return const <TodoItem>[];
    return <TodoItem>[
      for (final entry in raw)
        if (entry is Map) TodoItem.fromJson(Map<String, dynamic>.from(entry)),
    ];
  }

  static String _readDeletedAt(TrashItem item, DateTime? fallback) {
    final raw = item.payload['deletedAt'];
    final parsed = raw is String ? DateTime.tryParse(raw) : null;
    return _formatDate(parsed ?? fallback);
  }

  static String _formatDate(DateTime? value) {
    if (value == null) return '时间未知';
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}
