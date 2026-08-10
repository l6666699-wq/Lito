import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../application/workspace_controller.dart';
import '../../application/window_controller.dart';
import '../../app/app_constants.dart';
import '../../app/app_text.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_metrics.dart';
import '../../app/theme/project_palette.dart';
import '../../domain/models/project.dart';
import '../../domain/models/visible_todo_row.dart';
import '../../icons/app_icons.dart';
import '../../icons/project_icon.dart';
import '../todo/todo_list.dart';

class FullWorkspace extends StatelessWidget {
  const FullWorkspace({
    super.key,
    required this.controller,
    required this.windowController,
  });

  final WorkspaceController controller;
  final WindowController windowController;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final colors = AppColors.of(context);
        final rows = controller.visibleRows;
        return ColoredBox(
          color: colors.canvas,
          child: Column(
            children: [
              _WorkspaceHeader(
                controller: controller,
                windowController: windowController,
              ),
              Expanded(
                child: Row(
                  children: [
                    _ProjectSidebar(controller: controller),
                    SizedBox(width: 1, child: ColoredBox(color: colors.border)),
                    Expanded(
                      child: _WorkspaceContent(
                        controller: controller,
                        rows: rows,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({
    required this.controller,
    required this.windowController,
  });

  final WorkspaceController controller;
  final WindowController windowController;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: SizedBox(
        height: AppMetrics.headerHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppMetrics.compactPadding,
          ),
          child: Row(
            children: [
              const _BrandMark(),
              const SizedBox(width: 10),
              const Text(
                AppConstants.appName,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 22),
              Text(
                AppText.workspace,
                style: TextStyle(color: colors.textMuted),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _DatasetButton(
                        label: TodoDataset.fifty.label,
                        active: controller.dataset == TodoDataset.fifty,
                        onPressed: () =>
                            controller.switchDataset(TodoDataset.fifty),
                      ),
                      const SizedBox(width: 4),
                      _DatasetButton(
                        label: TodoDataset.thousand.label,
                        active: controller.dataset == TodoDataset.thousand,
                        onPressed: () =>
                            controller.switchDataset(TodoDataset.thousand),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        controller.datasetLabel,
                        style: TextStyle(color: colors.textFaint, fontSize: 12),
                      ),
                      const SizedBox(width: 10),
                      _WindowControls(controller: windowController),
                      if (windowController.hotkeyError != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text(
                            '热键不可用',
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WindowControls extends StatelessWidget {
  const _WindowControls({required this.controller});

  final WindowController controller;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WindowButton(
          label: 'Full',
          active: controller.mode == WindowMode.full,
          onPressed: () => controller.switchMode(WindowMode.full),
          colors: colors,
        ),
        _WindowButton(
          label: 'Compact',
          active: controller.mode == WindowMode.compact,
          onPressed: () => controller.switchMode(WindowMode.compact),
          colors: colors,
        ),
        _WindowButton(
          label: 'Quick Add',
          active: false,
          onPressed: controller.openQuickAdd,
          colors: colors,
        ),
        _WindowButton(
          label: '置顶',
          active: controller.isAlwaysOnTop,
          onPressed: controller.toggleAlwaysOnTop,
          colors: colors,
        ),
        _WindowButton(
          label: '锁定',
          active: controller.isLocked,
          onPressed: controller.toggleLocked,
          colors: colors,
        ),
        _WindowButton(
          icon: AppIcons.windowClose,
          active: false,
          onPressed: controller.hideToTray,
          colors: colors,
        ),
      ],
    );
  }
}

class _WindowButton extends StatelessWidget {
  const _WindowButton({
    this.label,
    this.icon,
    required this.active,
    required this.onPressed,
    required this.colors,
  });

  final String? label;
  final IconData? icon;
  final bool active;
  final VoidCallback onPressed;
  final AppColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return ShadButton.ghost(
      onPressed: onPressed,
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      foregroundColor: active ? colors.focus : colors.textMuted,
      backgroundColor: active ? colors.focusSoft : null,
      hoverBackgroundColor: colors.focusSoft,
      child: icon == null
          ? Text(label!, style: const TextStyle(fontSize: 11))
          : Icon(icon, size: 14),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.focusSoft,
        borderRadius: BorderRadius.circular(AppMetrics.smallRadius),
        border: Border.all(color: colors.focus.withValues(alpha: .22)),
      ),
      child: Icon(AppIcons.check, color: colors.focus, size: 15),
    );
  }
}

class _DatasetButton extends StatelessWidget {
  const _DatasetButton({
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
    return ShadButton.ghost(
      onPressed: onPressed,
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      backgroundColor: active ? colors.focusSoft : null,
      hoverBackgroundColor: colors.focusSoft,
      foregroundColor: active ? colors.focus : colors.textMuted,
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _ProjectSidebar extends StatelessWidget {
  const _ProjectSidebar({required this.controller});

  final WorkspaceController controller;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final inboxActive = controller.scope == WorkspaceScope.inbox;
    final allActive =
        controller.scope == WorkspaceScope.all &&
        controller.projectScopeId == null;
    return SizedBox(
      width: AppMetrics.sidebarWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(color: colors.surface),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 16, 10, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SectionLabel(label: AppText.workspace),
              const SizedBox(height: 7),
              _SidebarItem(
                label: AppText.allTodos,
                icon: Icon(AppIcons.layers, color: colors.textMuted, size: 16),
                active: allActive,
                accent: colors.focus,
                onPressed: controller.selectAll,
              ),
              _SidebarItem(
                label: AppText.inbox,
                icon: Icon(
                  AppIcons.inbox,
                  color: ProjectPalette.resolve('gray').accent,
                  size: 16,
                ),
                active: inboxActive,
                accent: ProjectPalette.resolve('gray').accent,
                onPressed: controller.selectInbox,
              ),
              const SizedBox(height: 20),
              const _SectionLabel(label: AppText.projects),
              const SizedBox(height: 7),
              for (final project in controller.projects)
                _ProjectSidebarItem(
                  project: project,
                  active: controller.projectScopeId == project.id,
                  onPressed: () => controller.selectProject(project.id),
                ),
              const Spacer(),
              _SidebarItem(
                label: AppText.addProject,
                icon: Icon(AppIcons.add, color: colors.textMuted, size: 16),
                active: false,
                accent: colors.textMuted,
                onPressed: () {},
              ),
              const SizedBox(height: 6),
              Text(
                'Phase 0 · 本地 Mock',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textFaint, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9),
      child: Text(
        label,
        style: TextStyle(
          color: colors.textFaint,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: .4,
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.label,
    required this.icon,
    required this.active,
    required this.accent,
    required this.onPressed,
  });

  final String label;
  final Widget icon;
  final bool active;
  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: AppMetrics.rowHeight,
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: active ? accent.withValues(alpha: .11) : null,
          borderRadius: BorderRadius.circular(AppMetrics.smallRadius),
        ),
        child: Row(
          children: [
            Container(
              width: 2,
              height: 18,
              decoration: BoxDecoration(
                color: active ? accent : colors.transparent,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(width: 8),
            icon,
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? accent : colors.text,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectSidebarItem extends StatelessWidget {
  const _ProjectSidebarItem({
    required this.project,
    required this.active,
    required this.onPressed,
  });

  final Project project;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final palette = ProjectPalette.resolve(project.colorKey);
    return _SidebarItem(
      label: project.name,
      icon: ProjectIcon(
        iconKey: project.iconKey,
        color: active ? palette.accent : colors.textMuted,
        size: 16,
      ),
      active: active,
      accent: palette.accent,
      onPressed: onPressed,
    );
  }
}

class _WorkspaceContent extends StatelessWidget {
  const _WorkspaceContent({required this.controller, required this.rows});

  final WorkspaceController controller;
  final List<VisibleTodoRow> rows;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final title = controller.scope == WorkspaceScope.inbox
        ? AppText.inbox
        : controller.projectScopeId == null
        ? AppText.allTodos
        : controller.projects
              .firstWhere((project) => project.id == controller.projectScopeId)
              .name;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppMetrics.pagePadding,
        20,
        AppMetrics.pagePadding,
        AppMetrics.pagePadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.3,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${controller.datasetLabel} · 可见 ${rows.length} 行',
                      style: TextStyle(color: colors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              ShadButton.ghost(
                onPressed: controller.toggleDataset,
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                foregroundColor: colors.textMuted,
                child: const Text('切换场景', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border.all(color: colors.border),
                borderRadius: BorderRadius.circular(AppMetrics.cardRadius),
              ),
              child: TodoList(controller: controller, rows: rows),
            ),
          ),
        ],
      ),
    );
  }
}
