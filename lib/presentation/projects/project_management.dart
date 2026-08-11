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
    return showShadDialog<bool>(
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
    return showShadDialog<bool>(
      context: context,
      builder: (context) =>
          ProjectEditorDialog(controller: controller, project: project),
    );
  }

  static Future<bool?> showCreateGroup(
    BuildContext context,
    WorkspaceController controller,
  ) {
    return showShadDialog<bool>(
      context: context,
      builder: (context) => ProjectGroupEditorDialog(controller: controller),
    );
  }

  static Future<bool?> showEditGroup(
    BuildContext context,
    WorkspaceController controller,
    ProjectGroup group,
  ) {
    return showShadDialog<bool>(
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
    return showShadDialog<ProjectManagementAction>(
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
    return showShadDialog<bool>(
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
    return ShadDialog(
      key: const ValueKey<String>('project-action-dialog'),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: palette.softBackground,
              borderRadius: BorderRadius.circular(AppMetrics.normalRadius),
              border: Border.all(color: palette.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppMetrics.unit * 2),
              child: ProjectIcon(
                iconKey: iconKey,
                color: palette.accent,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: AppMetrics.unit * 2),
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
      description: Text(
        disband ? '项目组操作' : '项目操作',
        style: TextStyle(color: colors.textMuted, fontSize: 12),
      ),
      backgroundColor: colors.surface,
      border: Border.all(color: colors.borderStrong),
      padding: const EdgeInsets.all(AppMetrics.unit * 5),
      gap: AppMetrics.unit * 2,
      constraints: const BoxConstraints(minWidth: 300, maxWidth: 400),
      actionsGap: AppMetrics.unit * 2,
      actions: [
        ShadButton.ghost(
          key: const ValueKey<String>('project-action-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceSubtle,
              borderRadius: BorderRadius.circular(AppMetrics.normalRadius),
              border: Border.all(color: colors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppMetrics.unit),
              child: Column(
                children: [
                  if (disband)
                    _ActionButton(
                      key: const ValueKey<String>('project-action-create'),
                      icon: AppIcons.add,
                      label: '新建项目',
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(ProjectManagementAction.createProject),
                    ),
                  _ActionButton(
                    key: const ValueKey<String>('project-action-edit'),
                    icon: AppIcons.edit,
                    label: '编辑',
                    onPressed: () =>
                        Navigator.of(context).pop(ProjectManagementAction.edit),
                  ),
                  _ActionButton(
                    key: ValueKey<String>(
                      'project-action-${isArchived ? 'unarchive' : 'archive'}',
                    ),
                    icon: AppIcons.archive,
                    label: isArchived ? '取消归档' : '归档',
                    onPressed: () => Navigator.of(context).pop(
                      isArchived
                          ? ProjectManagementAction.unarchive
                          : ProjectManagementAction.archive,
                    ),
                  ),
                  if (disband)
                    _ActionButton(
                      key: const ValueKey<String>('project-action-disband'),
                      icon: AppIcons.delete,
                      label: '解散分组',
                      foregroundColor: colors.focus,
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(ProjectManagementAction.disband),
                    )
                  else
                    _ActionButton(
                      key: const ValueKey<String>('project-action-delete'),
                      icon: AppIcons.delete,
                      label: '移入回收站',
                      foregroundColor: colors.focus,
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(ProjectManagementAction.delete),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.foregroundColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ShadButton.ghost(
      onPressed: onPressed,
      width: double.infinity,
      height: 38,
      expands: true,
      mainAxisAlignment: MainAxisAlignment.start,
      padding: const EdgeInsets.symmetric(horizontal: AppMetrics.unit * 2),
      foregroundColor: foregroundColor ?? colors.text,
      hoverBackgroundColor: colors.focusSoft,
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          Icon(icon, size: AppMetrics.iconSize),
          const SizedBox(width: AppMetrics.unit * 2),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
          Icon(AppIcons.chevronRight, size: 14, color: colors.textFaint),
        ],
      ),
    );
  }
}
