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

class _TrashPageState extends State<TrashPage> {
  String? _statusMessage;
  bool _statusIsError = false;
  bool _busy = false;

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
                      final item = items[index];
                      return Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppMetrics.unit * 2,
                        ),
                        child: _TrashCard(
                          key: ValueKey<String>('trash-item-${item.id}'),
                          record: _TrashRecord.from(item, controller),
                          colors: colors,
                          enabled: !_busy,
                          onRestore: () => _restore(item),
                        ),
                      );
                    }, childCount: items.length),
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

class _TrashHeader extends StatelessWidget {
  const _TrashHeader({
    required this.colors,
    required this.narrow,
    required this.itemCount,
    required this.busy,
    required this.onClear,
  });

  final AppColorScheme colors;
  final bool narrow;
  final int itemCount;
  final bool busy;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final heading = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.focusSoft,
            borderRadius: BorderRadius.circular(AppMetrics.normalRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppMetrics.unit * 3),
            child: Icon(AppIcons.trash, color: colors.focus, size: 22),
          ),
        ),
        const SizedBox(width: AppMetrics.unit * 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '回收站',
                style: TextStyle(
                  color: colors.text,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.3,
                ),
              ),
              const SizedBox(height: AppMetrics.unit),
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
    final clear = ShadButton.destructive(
      key: const ValueKey<String>('trash-clear-button'),
      onPressed: busy || itemCount == 0 ? null : onClear,
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: AppMetrics.unit * 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(AppIcons.delete, size: 15),
          const SizedBox(width: AppMetrics.unit),
          const Text('清空回收站', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          heading,
          const SizedBox(height: AppMetrics.unit * 3),
          clear,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: heading),
        const SizedBox(width: AppMetrics.unit * 3),
        clear,
      ],
    );
  }
}

class _TrashCard extends StatelessWidget {
  const _TrashCard({
    super.key,
    required this.record,
    required this.colors,
    required this.enabled,
    required this.onRestore,
  });

  final _TrashRecord record;
  final AppColorScheme colors;
  final bool enabled;
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
        borderRadius: BorderRadius.circular(AppMetrics.cardRadius),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppMetrics.unit * 4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 520;
            final content = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: palette.softBackground,
                    borderRadius: BorderRadius.circular(
                      AppMetrics.normalRadius,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppMetrics.unit * 2.5),
                    child: record.isProject
                        ? ProjectIcon(
                            iconKey: record.iconKey,
                            color: palette.accent,
                            size: 20,
                          )
                        : Icon(
                            AppIcons.completed,
                            color: palette.accent,
                            size: 20,
                          ),
                  ),
                ),
                const SizedBox(width: AppMetrics.unit * 3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              record.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.text,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppMetrics.unit * 2),
                          _KindBadge(record: record, colors: colors),
                        ],
                      ),
                      const SizedBox(height: AppMetrics.unit * 1.5),
                      metadata,
                    ],
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(width: AppMetrics.unit * 3),
                  action,
                ],
              ],
            );
            return compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      content,
                      const SizedBox(height: AppMetrics.unit * 2),
                      action,
                    ],
                  )
                : content;
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
        color: colors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppMetrics.smallRadius),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppMetrics.unit * 1.5,
          vertical: AppMetrics.unit,
        ),
        child: Text(
          label,
          style: TextStyle(color: colors.textMuted, fontSize: 10),
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
        Icon(icon, size: 13, color: colors.textFaint),
        const SizedBox(width: AppMetrics.unit),
        Text(text, style: TextStyle(color: colors.textMuted, fontSize: 11)),
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
