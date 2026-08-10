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
    return ShadDialog(
      key: const ValueKey<String>('project-editor-dialog'),
      title: Text(_editing ? '编辑项目' : '新建项目'),
      description: const Text('名称、颜色、图标和所属分组可以随时调整。'),
      constraints: const BoxConstraints(minWidth: 340, maxWidth: 520),
      scrollable: true,
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
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .76,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FieldLabel(label: '项目名称'),
              const SizedBox(height: AppMetrics.unit),
              ShadInput(
                key: const ValueKey<String>('project-name-input'),
                controller: _nameController,
                autofocus: !_editing,
                placeholder: const Text('例如：个人成长'),
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: AppMetrics.unit * 3),
              _FieldLabel(label: '所属分组'),
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
              const SizedBox(height: AppMetrics.unit * 3),
              _FieldLabel(label: '项目颜色'),
              const SizedBox(height: AppMetrics.unit),
              _PalettePicker(
                value: _colorKey,
                onChanged: (value) => setState(() => _colorKey = value),
              ),
              const SizedBox(height: AppMetrics.unit * 3),
              ProjectIconPicker(
                value: _iconKey,
                onChanged: (value) => setState(() => _iconKey = value),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppMetrics.unit * 2),
                Text(
                  _error!,
                  key: const ValueKey<String>('project-editor-error'),
                  style: TextStyle(color: colors.focus, fontSize: 11),
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
    return ShadDialog(
      key: const ValueKey<String>('project-group-editor-dialog'),
      title: Text(_editing ? '编辑项目组' : '新建项目组'),
      description: const Text('将相关项目放在一起，侧栏可以折叠分组。'),
      constraints: const BoxConstraints(minWidth: 340, maxWidth: 520),
      scrollable: true,
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
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .76,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _FieldLabel(label: '项目组名称'),
              const SizedBox(height: AppMetrics.unit),
              ShadInput(
                key: const ValueKey<String>('project-group-name-input'),
                controller: _nameController,
                autofocus: !_editing,
                placeholder: const Text('例如：工作'),
              ),
              const SizedBox(height: AppMetrics.unit * 3),
              const _FieldLabel(label: '项目组颜色'),
              const SizedBox(height: AppMetrics.unit),
              _PalettePicker(
                value: _colorKey,
                onChanged: (value) => setState(() => _colorKey = value),
              ),
              const SizedBox(height: AppMetrics.unit * 3),
              ProjectIconPicker(
                value: _iconKey,
                onChanged: (value) => setState(() => _iconKey = value),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppMetrics.unit * 2),
                Text(
                  _error!,
                  key: const ValueKey<String>('project-group-editor-error'),
                  style: TextStyle(color: colors.focus, fontSize: 11),
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Text(
      label,
      style: TextStyle(
        color: colors.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w600,
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
    return Wrap(
      spacing: AppMetrics.unit * 1.5,
      runSpacing: AppMetrics.unit * 1.5,
      children: [
        for (final palette in ProjectPalette.values)
          Semantics(
            button: true,
            selected: palette.key == value,
            label: palette.key,
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
                  ? const Icon(
                      AppIcons.check,
                      color: Color(0xFFFFFFFF),
                      size: 14,
                    )
                  : const SizedBox.shrink(),
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
          padding: const EdgeInsets.symmetric(horizontal: AppMetrics.unit * 2),
          child: Row(
            children: [
              ProjectIcon(
                iconKey: group?.iconKey ?? 'folder',
                color: group == null
                    ? colors.textMuted
                    : ProjectPalette.resolve(group.colorKey).accent,
                size: 15,
              ),
              const SizedBox(width: AppMetrics.unit * 1.5),
              Text(
                group?.name ?? '未分组',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.text, fontSize: 12),
              ),
              Icon(
                expanded ? AppIcons.chevronDown : AppIcons.chevronRight,
                size: 14,
                color: colors.textMuted,
              ),
            ],
          ),
        ),
        if (expanded)
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceSubtle,
              borderRadius: BorderRadius.circular(AppMetrics.smallRadius),
            ),
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
                    key: ValueKey<String>('project-group-option-${item.id}'),
                    label: item.name,
                    selected: item.id == value,
                    onPressed: () => onChanged(item.id),
                  ),
              ],
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
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: AppMetrics.unit * 2),
      foregroundColor: selected ? colors.focus : colors.text,
      backgroundColor: selected ? colors.focusSoft : null,
      hoverBackgroundColor: colors.focusSoft,
      child: Row(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
          if (selected) const Icon(AppIcons.check, size: 14),
        ],
      ),
    );
  }
}
