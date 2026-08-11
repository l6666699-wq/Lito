import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_metrics.dart';
import '../../app/theme/project_palette.dart';
import '../../icons/app_icons.dart';

class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.colors});

  static const double height = 34;

  final AppColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox.shrink(),
          const SizedBox(width: 0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '设置',
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.3,
                  ),
                ),
                const SizedBox(height: AppMetrics.unit),
                Visibility(
                  visible: false,
                  child: Text(
                    '调整 LiteTodo 的外观、窗口行为与本地数据策略。',
                    style: TextStyle(color: colors.textMuted, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CategoryRail extends StatelessWidget {
  const CategoryRail({
    super.key,
    required this.selected,
    required this.colors,
    required this.onSelected,
    this.horizontal = false,
    this.height,
  });

  final int selected;
  final AppColorScheme colors;
  final ValueChanged<int> onSelected;
  final bool horizontal;

  /// A finite height supplied by the wide settings layout. Horizontal rails
  /// intentionally ignore this value and retain their intrinsic height.
  final double? height;

  static const _items = <({IconData icon, String title, String subtitle})>[
    (icon: AppIcons.settings, title: '通用设置', subtitle: '窗口与快捷键'),
    (icon: AppIcons.theme, title: '主题设置', subtitle: '颜色与外观'),
    (icon: AppIcons.font, title: '字体设置', subtitle: '字体与大小'),
    (icon: AppIcons.backup, title: '数据与备份', subtitle: '本地文件管理'),
  ];

  static const _additionalItems =
      <({IconData icon, String title, String subtitle})>[
        (icon: AppIcons.windowMaximize, title: '桌面与窗口', subtitle: '窗口行为与位置'),
        (icon: AppIcons.info, title: '关于', subtitle: '版本与许可证'),
      ];

  @override
  Widget build(BuildContext context) {
    final items = <({IconData icon, String title, String subtitle})>[
      _items[0],
      _additionalItems[0],
      _items[1],
      _items[2],
      _items[3],
      _additionalItems[1],
    ];
    final children = [
      for (var index = 0; index < items.length; index++)
        CategoryItem(
          key: ValueKey<String>('settings-category-$index'),
          item: items[index],
          selected: index == selected,
          horizontal: horizontal,
          colors: colors,
          onTap: () => onSelected(index),
        ),
    ];
    if (horizontal) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: AppMetrics.unit),
        child: Row(children: children),
      );
    }
    final railContent = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppMetrics.unit * 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
    final sizedRail = height == null
        ? ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 680),
            child: railContent,
          )
        : SizedBox(height: height, child: railContent);
    return DecoratedBox(
      key: const ValueKey<String>('settings-category-rail'),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(AppMetrics.cardRadius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppMetrics.cardRadius),
        child: sizedRail,
      ),
    );
  }
}

class CategoryItem extends StatelessWidget {
  const CategoryItem({
    super.key,
    required this.item,
    required this.selected,
    required this.horizontal,
    required this.colors,
    required this.onTap,
  });

  final ({IconData icon, String title, String subtitle}) item;
  final bool selected;
  final bool horizontal;
  final AppColorScheme colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppMetrics.unit * 2.5,
        vertical: AppMetrics.unit * 2,
      ),
      child: Row(
        mainAxisSize: horizontal ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Icon(
            item.icon,
            size: 17,
            color: selected ? colors.focus : colors.textMuted,
          ),
          const SizedBox(width: AppMetrics.unit * 2.5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: TextStyle(
                  color: selected ? colors.focus : colors.text,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              if (!horizontal) ...[
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: TextStyle(color: colors.textFaint, fontSize: 11),
                ),
              ],
            ],
          ),
        ],
      ),
    );
    return Padding(
      padding: EdgeInsets.only(
        right: horizontal ? AppMetrics.unit * 2 : 0,
        bottom: horizontal ? 0 : AppMetrics.unit,
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: selected ? colors.focusSoft : colors.transparent,
                borderRadius: BorderRadius.circular(AppMetrics.normalRadius),
                border: selected
                    ? Border.all(color: colors.focus.withValues(alpha: .16))
                    : null,
              ),
              child: content,
            ),
            if (selected && !horizontal)
              PositionedDirectional(
                start: 0,
                top: AppMetrics.unit,
                bottom: AppMetrics.unit,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.focus,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: const SizedBox(width: 3),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SettingsCard extends StatelessWidget {
  const SettingsCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final AppColorScheme colors;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppMetrics.cardRadius),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppMetrics.unit * 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.focusSoft,
                    borderRadius: BorderRadius.circular(
                      AppMetrics.normalRadius,
                    ),
                    border: Border.all(
                      color: colors.focus.withValues(alpha: .16),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppMetrics.unit * 1.5),
                    child: Icon(icon, size: 17, color: colors.focus),
                  ),
                ),
                const SizedBox(width: AppMetrics.unit * 2.5),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: colors.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(color: colors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppMetrics.unit * 3),
            DecoratedBox(
              decoration: BoxDecoration(color: colors.borderStrong),
              child: const SizedBox(height: 1),
            ),
            const SizedBox(height: AppMetrics.unit * .5),
            ...children,
          ],
        ),
      ),
    );
  }
}

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.title,
    required this.description,
    required this.colors,
    required this.trailing,
  });

  final String title;
  final String description;
  final AppColorScheme colors;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppMetrics.unit * 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(color: colors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppMetrics.unit * 4),
          Flexible(child: trailing),
        ],
      ),
    );
  }
}

class SegmentedChoice<T> extends StatelessWidget {
  const SegmentedChoice({
    super.key,
    required this.value,
    required this.choices,
    required this.onChanged,
    required this.enabled,
  });

  final T value;
  final List<Choice<T>> choices;
  final bool enabled;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Wrap(
      spacing: AppMetrics.unit,
      runSpacing: AppMetrics.unit,
      alignment: WrapAlignment.end,
      children: [
        for (final choice in choices)
          GestureDetector(
            onTap: enabled ? () => onChanged(choice.value) : null,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: choice.value == value
                    ? colors.focusSoft
                    : colors.surfaceSubtle,
                borderRadius: BorderRadius.circular(AppMetrics.smallRadius),
                border: Border.all(
                  color: choice.value == value ? colors.focus : colors.border,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppMetrics.unit * 2.5,
                  vertical: AppMetrics.unit * 1.5,
                ),
                child: Text(
                  choice.label,
                  style: TextStyle(
                    color: choice.value == value
                        ? colors.focus
                        : colors.textMuted,
                    fontSize: 11,
                    fontWeight: choice.value == value
                        ? FontWeight.w600
                        : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class Choice<T> {
  const Choice(this.value, this.label);

  final T value;
  final String label;
}

class AccentPicker extends StatelessWidget {
  const AccentPicker({
    super.key,
    required this.selectedKey,
    required this.enabled,
    required this.onSelected,
  });

  final String selectedKey;
  final bool enabled;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Wrap(
      spacing: AppMetrics.unit * 1.5,
      children: [
        for (final entry in ProjectPalette.values)
          GestureDetector(
            onTap: enabled ? () => onSelected(entry.key) : null,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: entry.key == selectedKey
                      ? colors.text
                      : colors.transparent,
                  width: 2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: entry.accent,
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox(width: 17, height: 17),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class HotkeyRow extends StatelessWidget {
  const HotkeyRow({
    super.key,
    required this.value,
    required this.enabled,
    required this.controller,
    required this.colors,
    required this.onSubmitted,
  });

  final String value;
  final bool enabled;
  final TextEditingController controller;
  final AppColorScheme colors;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppMetrics.unit,
        bottom: AppMetrics.unit * 1.5,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceSubtle,
          borderRadius: BorderRadius.circular(AppMetrics.normalRadius),
          border: Border.all(color: colors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppMetrics.unit * 2.5,
            vertical: AppMetrics.unit * 1.5,
          ),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.focusSoft,
                  borderRadius: BorderRadius.circular(AppMetrics.smallRadius),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppMetrics.unit * 1.5),
                  child: Icon(AppIcons.shortcut, size: 15, color: colors.focus),
                ),
              ),
              const SizedBox(width: AppMetrics.unit * 2),
              Expanded(
                child: Text(
                  '当前快捷键',
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppMetrics.unit * 2),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 156, maxWidth: 220),
                child: ShadInput(
                  key: ValueKey<String>(value),
                  controller: controller,
                  enabled: enabled,
                  onSubmitted: onSubmitted,
                  placeholder: const Text('Ctrl+Alt+Space'),
                  leading: const Icon(AppIcons.shortcut, size: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RecentBackups extends StatelessWidget {
  const RecentBackups({super.key, required this.future, required this.colors});

  final Future<List<File>> future;
  final AppColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppMetrics.unit * 2),
      child: FutureBuilder<List<File>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Text(
              '正在读取备份列表...',
              style: TextStyle(color: colors.textMuted, fontSize: 11),
            );
          }
          if (snapshot.hasError) {
            return Text(
              '备份列表读取失败。',
              style: TextStyle(color: colors.textMuted, fontSize: 11),
            );
          }
          final files = snapshot.data ?? const <File>[];
          if (files.isEmpty) {
            return Text(
              '暂无备份记录。',
              style: TextStyle(color: colors.textMuted, fontSize: 11),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '最近备份（只读）',
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppMetrics.unit),
              for (final file in files.take(5))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(AppIcons.check, size: 13, color: colors.focus),
                      const SizedBox(width: AppMetrics.unit),
                      Expanded(
                        child: Text(
                          file.path,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.message,
    required this.colors,
    this.error = false,
    this.onDismiss,
  });

  final String message;
  final AppColorScheme colors;
  final bool error;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final color = error
        ? ProjectPalette.resolve('red').foreground
        : colors.focus;
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
            if (onDismiss != null)
              GestureDetector(
                onTap: onDismiss,
                child: Icon(
                  AppIcons.windowClose,
                  size: 15,
                  color: colors.textMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
