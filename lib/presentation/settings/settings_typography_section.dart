import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../app/theme/app_colors.dart';
import '../../domain/models/app_settings.dart';
import '../../icons/app_icons.dart';
import 'settings_scope.dart';
import 'settings_shared_controls.dart';

class TypographySettingsSection extends StatelessWidget {
  const TypographySettingsSection({
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
      icon: AppIcons.font,
      title: '字体设置',
      subtitle: '阅读舒适度可以随时调整',
      colors: colors,
      children: [
        SettingsRow(
          title: '字体',
          description: '应用界面使用的字体族',
          colors: colors,
          trailing: SegmentedChoice<String>(
            value: settings.fontFamilyKey,
            enabled: canEdit,
            choices: const [
              Choice('system', '系统字体'),
              Choice('segoeUi', 'Segoe UI'),
              Choice('geist', 'Geist（可选）'),
            ],
            onChanged: controller.setFontFamilyKey,
          ),
        ),
        SettingsRow(
          title: '字体大小',
          description: '${(settings.fontScale * 100).round()}% · 范围 90%–115%',
          colors: colors,
          trailing: SizedBox(
            width: 240,
            child: ShadSlider(
              key: ValueKey<double>(settings.fontScale),
              initialValue: settings.fontScale,
              min: AppSettings.minFontScale,
              max: AppSettings.maxFontScale,
              divisions: 5,
              enabled: canEdit,
              onChanged: controller.setFontScale,
            ),
          ),
        ),
      ],
    );
  }
}
