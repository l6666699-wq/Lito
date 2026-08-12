import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_metrics.dart';
import '../../app/theme/project_palette.dart';
import '../../application/workspace_controller.dart';
import '../../domain/models/project.dart';
import '../../domain/models/project_group.dart';
import '../../icons/app_icons.dart';
import '../../icons/project_icon.dart';
import '../common/app_dialog.dart';
import 'project_editor_dialog.dart';

enum ProjectManagementAction {
  createProject,
  edit,
  archive,
  unarchive,
  delete,
  disband,
}

abstract final class ProjectManagement {
  ProjectManagement._();

  static Future<bool?> showCreateProject(
    BuildContext context,
    WorkspaceController controller, {
    String? initialGroupId,
  }) {
    return showAppDialog<bool>(
      context: context,
      builder: (context) => ProjectEditorDialog(
        controller: controller,
        initialGroupId: initialGroupId,
      ),
    );
  }

  static Future<bool?> showEditProject(
    BuildContext context,
    WorkspaceController controller,
    Project project,
  ) {
    return showAppDialog<bool>(
      context: context,
      builder: (context) =>
          ProjectEditorDialog(controller: controller, project: project),
    );
  }

  static Future<bool?> showCreateGroup(
    BuildContext context,
    WorkspaceController controller,
  ) {
    return showCreateProject(context, controller);
  }

  static Future<bool?> showEditGroup(
    BuildContext context,
    WorkspaceController controller,
    ProjectGroup group,
  ) {
    return showAppDialog<bool>(
      context: context,
      builder: (context) =>
          ProjectGroupEditorDialog(controller: controller, group: group),
    );
  }

  static Future<void> showProjectActions(
    BuildContext context,
    WorkspaceController controller,
    Project project,
  ) async {
    final action = await _showActions(
      context,
      title: project.name,
      isArchived: project.archived,
      disband: false,
      iconKey: project.iconKey,
      colorKey: project.colorKey,
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case ProjectManagementAction.createProject:
        break;
      case ProjectManagementAction.edit:
        await showEditProject(context, controller, project);
      case ProjectManagementAction.archive:
        controller.archiveProject(project.id);
      case ProjectManagementAction.unarchive:
        controller.unarchiveProject(project.id);
      case ProjectManagementAction.delete:
        final confirmed = await _confirm(
          context,
          title: '删除项目？',
          description: '“${project.name}”及其全部 Todo 将进入回收站，可从回收站恢复。',
          confirmLabel: '移入回收站',
        );
        if (confirmed == true) {
          controller.deleteProject(project.id);
        }
      case ProjectManagementAction.disband:
        break;
    }
  }

  /// Actions for a project shown in the archived section.  A project can be
  /// visible there because its own archived flag is set or because its group
  /// is archived; in the latter case "取消归档" restores the group.
  static Future<void> showArchivedProjectActions(
    BuildContext context,
    WorkspaceController controller,
    Project project, {
    ProjectGroup? archivedGroup,
  }) async {
    final action = await _showActions(
      context,
      title: project.name,
      isArchived: true,
      disband: false,
      iconKey: project.iconKey,
      colorKey: project.colorKey,
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case ProjectManagementAction.createProject:
        break;
      case ProjectManagementAction.edit:
        await showEditProject(context, controller, project);
      case ProjectManagementAction.archive:
        break;
      case ProjectManagementAction.unarchive:
        if (project.archived) {
          controller.unarchiveProject(project.id);
        } else if (archivedGroup != null) {
          controller.unarchiveGroup(archivedGroup.id);
        }
      case ProjectManagementAction.delete:
        final confirmed = await _confirm(
          context,
          title: '删除项目？',
          description: '“${project.name}”及其全部 Todo 将进入回收站，可从回收站恢复。',
          confirmLabel: '移入回收站',
        );
        if (confirmed == true) controller.deleteProject(project.id);
      case ProjectManagementAction.disband:
        break;
    }
  }

  static Future<void> showGroupActions(
    BuildContext context,
    WorkspaceController controller,
    ProjectGroup group,
  ) async {
    final action = await _showActions(
      context,
      title: group.name,
      isArchived: group.archived,
      disband: true,
      iconKey: group.iconKey,
      colorKey: group.colorKey,
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case ProjectManagementAction.createProject:
        await showCreateProject(context, controller, initialGroupId: group.id);
      case ProjectManagementAction.edit:
        await showEditGroup(context, controller, group);
      case ProjectManagementAction.archive:
        controller.archiveGroup(group.id);
      case ProjectManagementAction.unarchive:
        controller.unarchiveGroup(group.id);
      case ProjectManagementAction.delete:
        break;
      case ProjectManagementAction.disband:
        final confirmed = await _confirm(
          context,
          title: '解散项目组？',
          description: '项目组“${group.name}”本身会被移除，组内项目会保留并移至未分组，不进入回收站。',
          confirmLabel: '解散分组',
        );
        if (confirmed == true) controller.deleteGroup(group.id);
    }
  }

  static Future<ProjectManagementAction?> _showActions(
    BuildContext context, {
    required String title,
    required bool isArchived,
    required bool disband,
    required String iconKey,
    required String colorKey,
  }) {
    return showAppDialog<ProjectManagementAction>(
      context: context,
      builder: (context) => _ActionDialog(
        title: title,
        isArchived: isArchived,
        disband: disband,
        iconKey: iconKey,
        colorKey: colorKey,
      ),
    );
  }

  static Future<bool?> _confirm(
    BuildContext context, {
    required String title,
    required String description,
    required String confirmLabel,
  }) {
    return showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ShadDialog.alert(
        key: const ValueKey<String>('project-management-confirm-dialog'),
        title: Text(title),
        description: Text(description),
        actions: [
          ShadButton.ghost(
            key: const ValueKey<String>('project-management-confirm-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ShadButton.destructive(
            key: const ValueKey<String>('project-management-confirm-ok'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(AppIcons.delete, size: 14),
                const SizedBox(width: AppMetrics.unit),
                Text(confirmLabel),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionDialog extends StatelessWidget {
  const _ActionDialog({
    required this.title,
    required this.isArchived,
    required this.disband,
    required this.iconKey,
    required this.colorKey,
  });

  final String title;
  final bool isArchived;
  final bool disband;
  final String iconKey;
  final String colorKey;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final palette = ProjectPalette.resolve(colorKey);
    final actionButtons = <Widget>[
      if (disband)
        _ActionButton(
          key: const ValueKey<String>('project-action-create'),
          actionKey: 'create',
          icon: AppIcons.add,
          label: '新建项目',
          palette: ProjectPalette.resolve('blue'),
          onPressed: () =>
              Navigator.of(context).pop(ProjectManagementAction.createProject),
        ),
      _ActionButton(
        key: const ValueKey<String>('project-action-edit'),
        actionKey: 'edit',
        icon: AppIcons.edit,
        label: '编辑',
        palette: ProjectPalette.resolve('green'),
        onPressed: () =>
            Navigator.of(context).pop(ProjectManagementAction.edit),
      ),
      _ActionButton(
        key: ValueKey<String>(
          'project-action-${isArchived ? 'unarchive' : 'archive'}',
        ),
        actionKey: isArchived ? 'unarchive' : 'archive',
        icon: AppIcons.archive,
        label: isArchived ? '取消归档' : '归档',
        palette: ProjectPalette.resolve('orange'),
        onPressed: () => Navigator.of(context).pop(
          isArchived
              ? ProjectManagementAction.unarchive
              : ProjectManagementAction.archive,
        ),
      ),
      if (disband)
        _ActionButton(
          key: const ValueKey<String>('project-action-disband'),
          actionKey: 'disband',
          icon: AppIcons.delete,
          label: '解散分组',
          palette: ProjectPalette.resolve('red'),
          foregroundColor: ProjectPalette.resolve('red').foreground,
          onPressed: () =>
              Navigator.of(context).pop(ProjectManagementAction.disband),
        )
      else
        _ActionButton(
          key: const ValueKey<String>('project-action-delete'),
          actionKey: 'delete',
          icon: AppIcons.delete,
          label: '移入回收站',
          palette: ProjectPalette.resolve('red'),
          foregroundColor: ProjectPalette.resolve('red').foreground,
          onPressed: () =>
              Navigator.of(context).pop(ProjectManagementAction.delete),
        ),
    ];
    return Center(
      child: SizedBox(
        key: const ValueKey<String>('project-action-dialog-card'),
        width: 380,
        child: ShadDialog(
          key: const ValueKey<String>('project-action-dialog'),
          title: Padding(
            // Keep the heading clear of the close affordance, even when a
            // project name wraps to a second line.
            padding: const EdgeInsets.only(right: AppMetrics.unit * 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  key: const ValueKey<String>('project-action-title-icon'),
                  decoration: BoxDecoration(
                    color: colors.focusSoft,
                    borderRadius: BorderRadius.circular(
                      AppMetrics.normalRadius,
                    ),
                    border: Border.all(color: colors.border, width: .8),
                  ),
                  child: SizedBox(
                    width: AppMetrics.unit * 10,
                    height: AppMetrics.unit * 10,
                    child: Center(
                      child: ProjectIcon(
                        iconKey: iconKey,
                        color: palette.accent,
                        size: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppMetrics.unit * 2.5),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppMetrics.unit * .5),
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          description: Text(
            disband ? '项目组操作' : '项目操作',
            key: const ValueKey<String>('project-action-description'),
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          closeIcon: Semantics(
            button: true,
            label: 'project-action-close',
            child: ShadIconButton.ghost(
              key: const ValueKey<String>('project-action-close'),
              icon: const Icon(AppIcons.windowClose, size: 15),
              width: 26,
              height: 26,
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          closeIconPosition: ShadPosition.directional(
            top: AppMetrics.unit * 3,
            end: AppMetrics.unit * 3,
            textDirection: Directionality.of(context),
          ),
          backgroundColor: colors.surface,
          border: Border.all(color: colors.border, width: .8),
          radius: BorderRadius.circular(AppMetrics.shellCardRadius),
          removeBorderRadiusWhenTiny: false,
          padding: const EdgeInsets.fromLTRB(
            AppMetrics.unit * 5,
            AppMetrics.unit * 5,
            AppMetrics.unit * 5,
            AppMetrics.unit * 4,
          ),
          gap: AppMetrics.unit * 3,
          constraints: const BoxConstraints(minWidth: 320, maxWidth: 380),
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          actions: const [],
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 300),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < actionButtons.length; index++) ...[
                  actionButtons[index],
                  if (index < actionButtons.length - 1)
                    const SizedBox(height: AppMetrics.unit * 2),
                ],
                const SizedBox(height: AppMetrics.unit * 3),
                Align(
                  key: const ValueKey<String>('project-action-cancel-slot'),
                  alignment: Alignment.centerRight,
                  child: ShadButton.ghost(
                    key: const ValueKey<String>('project-action-cancel'),
                    onPressed: () => Navigator.of(context).pop(),
                    width: AppMetrics.unit * 16,
                    height: AppMetrics.unit * 8,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppMetrics.unit * 3,
                    ),
                    child: const Text('取消'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    super.key,
    required this.actionKey,
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.palette,
    this.foregroundColor,
  });

  final String actionKey;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final ProjectPaletteEntry palette;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ShadButton.ghost(
      key: ValueKey<String>('project-action-$actionKey-button'),
      onPressed: onPressed,
      width: double.infinity,
      height: AppMetrics.unit * 12,
      expands: true,
      mainAxisAlignment: MainAxisAlignment.start,
      padding: const EdgeInsets.symmetric(horizontal: AppMetrics.unit * 2),
      foregroundColor: foregroundColor ?? colors.text,
      hoverBackgroundColor: colors.focusSoft,
      decoration: ShadDecoration(
        color: colors.surface,
        border: ShadBorder.all(
          color: colors.border,
          width: .8,
          radius: BorderRadius.circular(AppMetrics.normalRadius),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          DecoratedBox(
            key: ValueKey<String>('project-action-$actionKey-icon'),
            decoration: BoxDecoration(
              color: palette.softBackground,
              borderRadius: BorderRadius.circular(AppMetrics.smallRadius),
              border: Border.all(color: palette.border, width: .8),
            ),
            child: SizedBox(
              width: AppMetrics.unit * 8,
              height: AppMetrics.unit * 8,
              child: Center(
                child: Icon(
                  icon,
                  size: AppMetrics.iconSize,
                  color: palette.accent,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppMetrics.unit * 2.5),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          Icon(
            AppIcons.chevronRight,
            size: AppMetrics.iconSize,
            color: colors.textFaint,
          ),
        ],
      ),
    );
  }
}
