import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_metrics.dart';
import '../../app/theme/project_palette.dart';
import '../../domain/models/app_settings.dart';
import '../../icons/app_icons.dart';
import 'settings_scope.dart';
import 'settings_shared_controls.dart';

class AppearanceSettingsSection extends StatelessWidget {
  const AppearanceSettingsSection({
    super.key,
    required this.scope,
    required this.settings,
    required this.colors,
    required this.canEdit,
  });

  final SettingsScope scope;
  final AppSettings settings;
  final AppColorScheme colors;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final controller = scope.settingsController;
    return SettingsCard(
      icon: AppIcons.appearance,
      title: '主题设置',
      subtitle: '颜色与外观偏好会即时应用',
      colors: colors,
      children: [
        SettingsRow(
          icon: AppIcons.theme,
          title: '主题模式',
          description: '跟随系统或固定使用浅色、深色主题',
          colors: colors,
          trailing: SegmentedChoice<AppThemeMode>(
            value: settings.themeMode,
            enabled: canEdit,
            choices: const [
              Choice(AppThemeMode.system, '跟随系统'),
              Choice(AppThemeMode.light, '浅色'),
              Choice(AppThemeMode.dark, '深色'),
            ],
            onChanged: controller.setThemeMode,
          ),
        ),
        SettingsRow(
          icon: AppIcons.palette,
          title: '强调色',
          description: '用于按钮、焦点和选中状态',
          colors: colors,
          trailing: AccentPicker(
            selectedKey: settings.accentColorKey,
            enabled: canEdit,
            onSelected: controller.setAccentColorKey,
          ),
        ),
        SettingsRow(
          icon: AppIcons.theme,
          title: '主题预览',
          description: '选择预览卡片，立即应用对应的主题组合',
          colors: colors,
          showDivider: false,
          trailing: ThemePreviewPicker(
            selectedMode: settings.themeMode,
            selectedAccentKey: settings.accentColorKey,
            enabled: canEdit,
            onSelected: (option) => controller.updateSettings(
              themeMode: option.mode,
              accentColorKey: option.accentKey,
            ),
          ),
        ),
      ],
    );
  }
}

class ThemePreviewOption {
  const ThemePreviewOption({
    required this.key,
    required this.label,
    required this.mode,
    required this.accentKey,
  });

  final String key;
  final String label;
  final AppThemeMode mode;
  final String accentKey;
}

class ThemePreviewPicker extends StatelessWidget {
  const ThemePreviewPicker({
    super.key,
    required this.selectedMode,
    required this.selectedAccentKey,
    required this.enabled,
    required this.onSelected,
  });

  final AppThemeMode selectedMode;
  final String selectedAccentKey;
  final bool enabled;
  final ValueChanged<ThemePreviewOption> onSelected;

  static const options = <ThemePreviewOption>[
    ThemePreviewOption(
      key: 'light-blue',
      label: '浅色',
      mode: AppThemeMode.light,
      accentKey: 'blue',
    ),
    ThemePreviewOption(
      key: 'light-purple',
      label: '浅色 · 紫色',
      mode: AppThemeMode.light,
      accentKey: 'purple',
    ),
    ThemePreviewOption(
      key: 'dark-blue',
      label: '深色',
      mode: AppThemeMode.dark,
      accentKey: 'blue',
    ),
    ThemePreviewOption(
      key: 'system-blue',
      label: '跟随系统',
      mode: AppThemeMode.system,
      accentKey: 'blue',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: AppMetrics.unit * 2,
      runSpacing: AppMetrics.unit * 2,
      children: [for (final option in options) _buildOption(option, colors)],
    );
  }

  Widget _buildOption(ThemePreviewOption option, AppColorScheme colors) {
    final selected =
        option.mode == selectedMode && option.accentKey == selectedAccentKey;
    final accent = ProjectPalette.resolve(option.accentKey).accent;
    final dark = option.mode == AppThemeMode.dark;
    final surface = dark ? AppColors.darkSurface : AppColors.lightSurface;
    final previewText = dark
        ? AppColors.darkTextMuted
        : AppColors.lightTextMuted;
    return Semantics(
      button: true,
      selected: selected,
      label: '主题预览 ${option.label}',
      child: ShadButton.ghost(
        key: ValueKey<String>('settings-theme-preview-${option.key}'),
        enabled: enabled,
        width: 124,
        height: 74,
        padding: EdgeInsets.zero,
        onPressed: () => onSelected(option),
        child: SizedBox(
          width: 120,
          height: 70,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(AppMetrics.normalRadius),
              border: Border.all(
                color: selected ? colors.focus : colors.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppMetrics.unit * 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: previewText.withValues(alpha: .35),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: const SizedBox(height: 4),
                        ),
                      ),
                      const SizedBox(width: AppMetrics.unit),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                        child: const SizedBox(width: 7, height: 7),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppMetrics.unit * 2),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: previewText.withValues(alpha: .2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: const SizedBox(height: 4),
                  ),
                  const Spacer(),
                  Text(
                    option.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: dark ? AppColors.darkText : AppColors.lightText,
                      fontSize: 10,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
