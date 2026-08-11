import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_metrics.dart';
import '../../icons/app_icons.dart';
import '../../icons/project_icon.dart';
import '../../icons/project_icon_entry.dart';
import '../../icons/project_icons.dart';

/// A local-only IconPark outline picker used by project and group editors.
///
/// The persisted value is the stable catalog key.  No network lookup or
/// renderer-specific icon value is accepted here.
class ProjectIconPicker extends StatefulWidget {
  const ProjectIconPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<ProjectIconPicker> createState() => _ProjectIconPickerState();
}

class _ProjectIconPickerState extends State<ProjectIconPicker> {
  late final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppMetrics.smallRadius),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppMetrics.unit * 2.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '选择图标',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppMetrics.unit * 1.5),
            SizedBox(
              height: 32,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(AppMetrics.smallRadius),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(width: AppMetrics.unit * 2),
                    Icon(AppIcons.search, size: 14, color: colors.textMuted),
                    const SizedBox(width: AppMetrics.unit),
                    Expanded(
                      child: ShadInput(
                        key: const ValueKey<String>('project-icon-search'),
                        controller: _searchController,
                        onChanged: (value) => setState(() => _query = value),
                        placeholder: Text(
                          '搜索图标',
                          style: TextStyle(
                            color: colors.textFaint,
                            fontSize: 11,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 0,
                          vertical: 0,
                        ),
                        alignment: Alignment.centerLeft,
                        placeholderAlignment: Alignment.centerLeft,
                        // The picker already provides its own subtle surface;
                        // keep the input's internal decorator completely
                        // borderless in both idle and focused states.
                        decoration: ShadDecoration.none,
                        constraints: const BoxConstraints(minHeight: 28),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppMetrics.unit * 1.5),
            LayoutBuilder(
              builder: (context, constraints) {
                final entries = _filteredEntries;
                final crossAxisCount = constraints.maxWidth >= 300
                    ? 8
                    : constraints.maxWidth >= 220
                    ? 6
                    : 4;
                return ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 196),
                  child: entries.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppMetrics.unit * 3),
                            child: Text(
                              '没有匹配的图标',
                              style: TextStyle(
                                color: colors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        )
                      : GridView.builder(
                          key: const ValueKey<String>('project-icon-grid'),
                          shrinkWrap: true,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                mainAxisSpacing: AppMetrics.unit,
                                crossAxisSpacing: AppMetrics.unit,
                              ),
                          itemCount: entries.length,
                          itemBuilder: (context, index) {
                            final entry = entries[index];
                            final selected = entry.key == widget.value;
                            return _IconOption(
                              entry: entry,
                              selected: selected,
                              onPressed: () => widget.onChanged(entry.key),
                            );
                          },
                        ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<ProjectIconEntry> get _filteredEntries {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return ProjectIcons.entries;
    return ProjectIcons.entries
        .where((entry) => entry.key.toLowerCase().contains(query))
        .toList(growable: false);
  }
}

class _IconOption extends StatelessWidget {
  const _IconOption({
    required this.entry,
    required this.selected,
    required this.onPressed,
  });

  final ProjectIconEntry entry;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      button: true,
      label: entry.key,
      selected: selected,
      child: ShadButton.ghost(
        key: ValueKey<String>('project-icon-option-${entry.key}'),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        height: 32,
        foregroundColor: selected ? colors.focus : colors.textMuted,
        backgroundColor: selected ? colors.focusSoft : colors.surface,
        hoverBackgroundColor: colors.focusSoft,
        decoration: ShadDecoration(
          border: ShadBorder.all(
            color: selected ? colors.focus : colors.border,
            width: selected ? 1.2 : 1,
            radius: BorderRadius.circular(AppMetrics.smallRadius),
          ),
        ),
        child: ProjectIcon(
          iconKey: entry.key,
          color: selected ? colors.focus : colors.textMuted,
          size: 17,
        ),
      ),
    );
  }
}
