import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_metrics.dart';
import '../../domain/models/app_settings.dart';
import '../../icons/app_icons.dart';
import 'settings_shared_controls.dart';

/// Desktop-only window behavior kept separate from the general preferences.
///
/// The callbacks are supplied by [SettingsPage], so this section does not know
/// about platform services and keeps the existing persistence/rollback path.
class WindowSettingsSection extends StatelessWidget {
  const WindowSettingsSection({
    super.key,
    required this.settings,
    required this.colors,
    required this.canEdit,
    required this.onWindowMode,
    required this.onRememberWindowPosition,
    required this.onCompactAlwaysOnTop,
    required this.onCompactSkipTaskbar,
    required this.onLockCompactPosition,
    required this.onResetWindowPosition,
    required this.crossRestartGeometryAvailable,
  });

  final AppSettings settings;
  final AppColorScheme colors;
  final bool canEdit;
  final Future<void> Function(AppWindowMode value) onWindowMode;
  final Future<void> Function(bool value) onRememberWindowPosition;
  final Future<void> Function(bool value) onCompactAlwaysOnTop;
  final Future<void> Function(bool value) onCompactSkipTaskbar;
  final Future<void> Function(bool value) onLockCompactPosition;
  final Future<void> Function() onResetWindowPosition;
  final bool crossRestartGeometryAvailable;

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      icon: AppIcons.windowMaximize,
      title: '桌面与窗口',
      subtitle: '默认布局、紧凑模式与窗口位置',
      colors: colors,
      children: [
        SettingsRow(
          title: '默认窗口模式',
          description: '下次启动时使用的窗口布局',
          colors: colors,
          trailing: SegmentedChoice<AppWindowMode>(
            value: settings.defaultWindowMode,
            enabled: canEdit,
            choices: const [
              Choice(AppWindowMode.full, '全视图'),
              Choice(AppWindowMode.compact, '紧凑模式'),
              Choice(AppWindowMode.quickAdd, '快速添加'),
            ],
            onChanged: onWindowMode,
          ),
        ),
        SettingsRow(
          title: '记住窗口位置',
          description: crossRestartGeometryAvailable
              ? '跨重启恢复完整与紧凑模式的位置和尺寸'
              : '当前会话内恢复各窗口模式的位置；跨重启位置保存尚未接入',
          colors: colors,
          trailing: ShadSwitch(
            value: settings.rememberWindowPosition,
            enabled: canEdit,
            onChanged: onRememberWindowPosition,
          ),
        ),
        SettingsRow(
          title: '紧凑模式置顶',
          description: '紧凑模式始终显示在其他窗口上方',
          colors: colors,
          trailing: ShadSwitch(
            value: settings.compactAlwaysOnTop,
            enabled: canEdit,
            onChanged: onCompactAlwaysOnTop,
          ),
        ),
        SettingsRow(
          title: '紧凑模式跳过任务栏',
          description: '紧凑模式不在 Windows 任务栏显示按钮',
          colors: colors,
          trailing: ShadSwitch(
            value: settings.compactSkipTaskbar,
            enabled: canEdit,
            onChanged: onCompactSkipTaskbar,
          ),
        ),
        SettingsRow(
          title: '锁定紧凑模式位置',
          description: '锁定后禁止拖动和调整尺寸，但不影响 Todo 操作',
          colors: colors,
          trailing: ShadSwitch(
            value: settings.lockCompactPosition,
            enabled: canEdit,
            onChanged: onLockCompactPosition,
          ),
        ),
        SettingsRow(
          title: '恢复默认窗口位置',
          description: '清除完整与紧凑模式的保存位置，下次使用默认尺寸',
          colors: colors,
          trailing: ShadButton.outline(
            key: const ValueKey<String>('settings-window-reset-position'),
            size: ShadButtonSize.sm,
            leading: const Icon(AppIcons.restore, size: 14),
            enabled: canEdit,
            onPressed: onResetWindowPosition,
            child: const Text('恢复默认'),
          ),
        ),
        const SizedBox(height: AppMetrics.unit),
      ],
    );
  }
}
