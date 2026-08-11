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
import 'project_icon_picker.dart';

const BoxConstraints _projectEditorInputConstraints = BoxConstraints(
  minHeight: 34,
  maxHeight: 34,
);

const EdgeInsets _projectEditorInputPadding = EdgeInsets.symmetric(
  horizontal: AppMetrics.unit * 2.5,
  vertical: AppMetrics.unit,
);

ShadDecoration _projectEditorInputDecoration(AppColorScheme colors) {
  final radius = BorderRadius.circular(AppMetrics.normalRadius);
  return ShadDecoration(
    border: ShadBorder.all(color: colors.border, width: .8, radius: radius),
    focusedBorder: ShadBorder.all(
      color: colors.focus,
      width: .8,
      radius: radius,
    ),
    secondaryFocusedBorder: ShadBorder.none,
  );
}

class ProjectEditorDialog extends StatefulWidget {
  const ProjectEditorDialog({
    super.key,
    required this.controller,
    this.project,
    this.initialGroupId,
  });

  final WorkspaceController controller;
  final Project? project;
  final String? initialGroupId;

  @override
  State<ProjectEditorDialog> createState() => _ProjectEditorDialogState();
}

class _ProjectEditorDialogState extends State<ProjectEditorDialog> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.project?.name ?? '',
  );
  late String _iconKey = widget.project?.iconKey ?? 'folder';
  late String _colorKey = widget.project?.colorKey ?? 'blue';
  late String? _groupId = widget.project?.groupId ?? widget.initialGroupId;
  bool _showGroups = false;
  String? _error;

  bool get _editing => widget.project != null;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Center(
      child: SizedBox(
        key: const ValueKey<String>('project-editor-dialog-card'),
        width: 520,
        child: ShadDialog(
          key: const ValueKey<String>('project-editor-dialog'),
          title: _EditorDialogHeader(
            title: _editing ? '编辑项目' : '新建项目',
            description: '名称、颜色、图标和所属分组可以随时调整。',
            iconKey: _iconKey,
            colorKey: _colorKey,
          ),
          closeIcon: Semantics(
            button: true,
            label: 'project-editor-close',
            child: ShadIconButton.ghost(
              key: const ValueKey<String>('project-editor-close'),
              icon: const Icon(AppIcons.windowClose, size: 15),
              width: 26,
              height: 26,
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ),
          backgroundColor: colors.surface,
          border: Border.all(color: colors.borderStrong),
          radius: BorderRadius.circular(AppMetrics.cardRadius),
          removeBorderRadiusWhenTiny: false,
          padding: const EdgeInsets.fromLTRB(
            AppMetrics.unit * 5,
            AppMetrics.unit * 4.5,
            AppMetrics.unit * 5,
            AppMetrics.unit * 3,
          ),
          gap: AppMetrics.unit * 2.5,
          constraints: BoxConstraints(
            minWidth: 400,
            maxWidth: 520,
            maxHeight: _editorMaxHeight(context),
          ),
          scrollable: true,
          titlePinned: true,
          actionsPinned: true,
          actionsGap: AppMetrics.unit * 2,
          actions: [
            ShadButton.ghost(
              key: const ValueKey<String>('project-editor-cancel'),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            ShadButton(
              key: const ValueKey<String>('project-editor-save'),
              onPressed: _save,
              child: Text(_editing ? '保存' : '创建'),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _FieldLabel(
                key: ValueKey<String>('project-name-label'),
                label: '项目名称',
              ),
              const SizedBox(height: AppMetrics.unit * 1.5),
              ShadInput(
                key: const ValueKey<String>('project-name-input'),
                controller: _nameController,
                autofocus: !_editing,
                placeholder: const Text('例如：个人成长'),
                onSubmitted: (_) => _save(),
                constraints: _projectEditorInputConstraints,
                padding: _projectEditorInputPadding,
                decoration: _projectEditorInputDecoration(colors),
              ),
              const SizedBox(height: AppMetrics.unit * 2.5),
              const _FieldLabel(label: '所属分组'),
              const SizedBox(height: AppMetrics.unit),
              _GroupSelector(
                controller: widget.controller,
                value: _groupId,
                expanded: _showGroups,
                onToggle: () => setState(() => _showGroups = !_showGroups),
                onChanged: (value) => setState(() {
                  _groupId = value;
                  _showGroups = false;
                }),
              ),
              const SizedBox(height: AppMetrics.unit * 2.5),
              const _FieldLabel(label: '项目颜色'),
              const SizedBox(height: AppMetrics.unit),
              _PalettePicker(
                value: _colorKey,
                onChanged: (value) => setState(() => _colorKey = value),
              ),
              const SizedBox(height: AppMetrics.unit * 2.5),
              ProjectIconPicker(
                value: _iconKey,
                onChanged: (value) => setState(() => _iconKey = value),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppMetrics.unit * 2),
                _EditorError(
                  key: const ValueKey<String>('project-editor-error'),
                  message: _error!,
                  colors: colors,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '请输入项目名称');
      return;
    }
    try {
      if (_editing) {
        final project = widget.project!;
        widget.controller.updateProject(
          project.copyWith(
            name: name,
            iconKey: _iconKey,
            colorKey: _colorKey,
            groupId: _groupId,
          ),
        );
      } else {
        widget.controller.createProject(
          name: name,
          iconKey: _iconKey,
          colorKey: _colorKey,
          groupId: _groupId,
        );
      }
      Navigator.of(context).pop(true);
    } on Object catch (error) {
      setState(() => _error = '保存失败：$error');
    }
  }
}

class ProjectGroupEditorDialog extends StatefulWidget {
  const ProjectGroupEditorDialog({
    super.key,
    required this.controller,
    this.group,
  });

  final WorkspaceController controller;
  final ProjectGroup? group;

  @override
  State<ProjectGroupEditorDialog> createState() =>
      _ProjectGroupEditorDialogState();
}

class _ProjectGroupEditorDialogState extends State<ProjectGroupEditorDialog> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.group?.name ?? '',
  );
  late String _iconKey = widget.group?.iconKey ?? 'folder';
  late String _colorKey = widget.group?.colorKey ?? 'blue';
  String? _error;

  bool get _editing => widget.group != null;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Center(
      child: SizedBox(
        key: const ValueKey<String>('project-group-editor-dialog-card'),
        width: 520,
        child: ShadDialog(
          key: const ValueKey<String>('project-group-editor-dialog'),
          title: _EditorDialogHeader(
            title: _editing ? '编辑项目组' : '新建项目组',
            description: '将相关项目放在一起，侧栏可以折叠分组。',
            iconKey: _iconKey,
            colorKey: _colorKey,
          ),
          closeIcon: Semantics(
            button: true,
            label: 'project-group-editor-close',
            child: ShadIconButton.ghost(
              key: const ValueKey<String>('project-group-editor-close'),
              icon: const Icon(AppIcons.windowClose, size: 15),
              width: 26,
              height: 26,
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ),
          backgroundColor: colors.surface,
          border: Border.all(color: colors.borderStrong),
          radius: BorderRadius.circular(AppMetrics.cardRadius),
          removeBorderRadiusWhenTiny: false,
          padding: const EdgeInsets.fromLTRB(
            AppMetrics.unit * 5,
            AppMetrics.unit * 4.5,
            AppMetrics.unit * 5,
            AppMetrics.unit * 3,
          ),
          gap: AppMetrics.unit * 2.5,
          constraints: BoxConstraints(
            minWidth: 400,
            maxWidth: 520,
            maxHeight: _editorMaxHeight(context),
          ),
          scrollable: true,
          titlePinned: true,
          actionsPinned: true,
          actionsGap: AppMetrics.unit * 2,
          actions: [
            ShadButton.ghost(
              key: const ValueKey<String>('project-group-editor-cancel'),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            ShadButton(
              key: const ValueKey<String>('project-group-editor-save'),
              onPressed: _save,
              child: Text(_editing ? '保存' : '创建'),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _FieldLabel(
                key: ValueKey<String>('project-group-name-label'),
                label: '项目组名称',
              ),
              const SizedBox(height: AppMetrics.unit * 1.5),
              ShadInput(
                key: const ValueKey<String>('project-group-name-input'),
                controller: _nameController,
                autofocus: !_editing,
                placeholder: const Text('例如：工作'),
                constraints: _projectEditorInputConstraints,
                padding: _projectEditorInputPadding,
                decoration: _projectEditorInputDecoration(colors),
              ),
              const SizedBox(height: AppMetrics.unit * 2.5),
              const _FieldLabel(label: '项目组颜色'),
              const SizedBox(height: AppMetrics.unit),
              _PalettePicker(
                value: _colorKey,
                onChanged: (value) => setState(() => _colorKey = value),
              ),
              const SizedBox(height: AppMetrics.unit * 2.5),
              ProjectIconPicker(
                value: _iconKey,
                onChanged: (value) => setState(() => _iconKey = value),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppMetrics.unit * 2),
                _EditorError(
                  key: const ValueKey<String>('project-group-editor-error'),
                  message: _error!,
                  colors: colors,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = '请输入项目组名称');
      return;
    }
    try {
      if (_editing) {
        widget.controller.updateGroup(
          widget.group!.copyWith(
            name: name,
            iconKey: _iconKey,
            colorKey: _colorKey,
          ),
        );
      } else {
        widget.controller.createGroup(
          name: name,
          iconKey: _iconKey,
          colorKey: _colorKey,
        );
      }
      Navigator.of(context).pop(true);
    } on Object catch (error) {
      setState(() => _error = '保存失败：$error');
    }
  }
}

double _editorMaxHeight(BuildContext context) {
  final viewportHeight = MediaQuery.sizeOf(context).height;
  return (viewportHeight * .84).clamp(320.0, 720.0).toDouble();
}

class _EditorDialogHeader extends StatelessWidget {
  const _EditorDialogHeader({
    required this.title,
    required this.description,
    required this.iconKey,
    required this.colorKey,
  });

  final String title;
  final String description;
  final String iconKey;
  final String colorKey;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final palette = ProjectPalette.resolve(colorKey);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          key: const ValueKey<String>('project-editor-header-icon'),
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
              size: 21,
            ),
          ),
        ),
        const SizedBox(width: AppMetrics.unit * 2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                key: const ValueKey<String>('project-editor-header-title'),
                style: TextStyle(
                  color: colors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppMetrics.unit),
              Text(
                description,
                key: const ValueKey<String>(
                  'project-editor-header-description',
                ),
                style: TextStyle(color: colors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Text(
      label,
      style: TextStyle(
        color: colors.text,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _EditorError extends StatelessWidget {
  const _EditorError({super.key, required this.message, required this.colors});

  final String message;
  final AppColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.focusSoft,
        borderRadius: BorderRadius.circular(AppMetrics.smallRadius),
        border: Border.all(color: colors.focus.withValues(alpha: .24)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppMetrics.unit * 2,
          vertical: AppMetrics.unit * 1.5,
        ),
        child: Row(
          children: [
            Icon(AppIcons.info, size: 14, color: colors.focus),
            const SizedBox(width: AppMetrics.unit * 1.5),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: colors.text, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PalettePicker extends StatelessWidget {
  const _PalettePicker({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Wrap(
      alignment: WrapAlignment.start,
      spacing: AppMetrics.unit * 1.5,
      runSpacing: AppMetrics.unit * 1.5,
      children: [
        for (final palette in ProjectPalette.values)
          Semantics(
            button: true,
            selected: palette.key == value,
            label: palette.key,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: palette.key == value
                    ? palette.softBackground
                    : colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: palette.key == value
                      ? palette.accent
                      : colors.transparent,
                  width: 2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: ShadButton.ghost(
                  key: ValueKey<String>('project-color-option-${palette.key}'),
                  onPressed: () => onChanged(palette.key),
                  height: 28,
                  width: 28,
                  padding: EdgeInsets.zero,
                  backgroundColor: palette.accent,
                  hoverBackgroundColor: palette.accent.withValues(alpha: .82),
                  decoration: const ShadDecoration(shape: BoxShape.circle),
                  child: palette.key == value
                      ? Icon(
                          AppIcons.check,
                          color: palette.foreground,
                          size: 14,
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _GroupSelector extends StatelessWidget {
  const _GroupSelector({
    required this.controller,
    required this.value,
    required this.expanded,
    required this.onToggle,
    required this.onChanged,
  });

  final WorkspaceController controller;
  final String? value;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    ProjectGroup? group;
    for (final item in controller.groups) {
      if (item.id == value) {
        group = item;
        break;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShadButton.outline(
          key: const ValueKey<String>('project-group-selector'),
          onPressed: onToggle,
          height: 36,
          width: double.infinity,
          expands: true,
          mainAxisAlignment: MainAxisAlignment.start,
          padding: const EdgeInsets.symmetric(horizontal: AppMetrics.unit * 2),
          leading: ProjectIcon(
            iconKey: group?.iconKey ?? 'folder',
            color: group == null
                ? colors.textMuted
                : ProjectPalette.resolve(group.colorKey).accent,
            size: 15,
          ),
          trailing: Icon(
            expanded ? AppIcons.chevronDown : AppIcons.chevronRight,
            size: 14,
            color: colors.textMuted,
          ),
          child: Text(
            group?.name ?? '未分组',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.text, fontSize: 12),
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.only(top: AppMetrics.unit),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceSubtle,
                borderRadius: BorderRadius.circular(AppMetrics.smallRadius),
                border: Border.all(color: colors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppMetrics.unit),
                child: Column(
                  children: [
                    _GroupOption(
                      key: const ValueKey<String>('project-group-option-none'),
                      label: '未分组',
                      selected: value == null,
                      onPressed: () => onChanged(null),
                    ),
                    for (final item in controller.groups.where(
                      (item) => !item.archived,
                    ))
                      _GroupOption(
                        key: ValueKey<String>(
                          'project-group-option-${item.id}',
                        ),
                        label: item.name,
                        selected: item.id == value,
                        onPressed: () => onChanged(item.id),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _GroupOption extends StatelessWidget {
  const _GroupOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ShadButton.ghost(
      onPressed: onPressed,
      width: double.infinity,
      height: 32,
      expands: true,
      mainAxisAlignment: MainAxisAlignment.start,
      padding: const EdgeInsets.symmetric(horizontal: AppMetrics.unit * 2),
      foregroundColor: selected ? colors.focus : colors.text,
      backgroundColor: selected ? colors.focusSoft : null,
      hoverBackgroundColor: colors.focusSoft,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? colors.focus : colors.text,
                fontSize: 12,
              ),
            ),
          ),
          if (selected) const Icon(AppIcons.check, size: 14),
        ],
      ),
    );
  }
}
