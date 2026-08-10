import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_metrics.dart';
import '../../domain/models/app_settings.dart';
import '../../icons/app_icons.dart';
import 'settings_shared_controls.dart';

class GeneralSettingsSection extends StatelessWidget {
  const GeneralSettingsSection({
    super.key,
    required this.settings,
    required this.colors,
    required this.canEdit,
    required this.hotkeyController,
    required this.onLaunchAtStartup,
    required this.onStartHidden,
    required this.onCloseToTray,
    required this.onWindowMode,
    required this.onHotkeyEnabled,
    required this.onHotkeySubmitted,
    required this.onRememberWindowPosition,
    required this.onCompactAlwaysOnTop,
    required this.onCompactSkipTaskbar,
    required this.onLockCompactPosition,
    required this.onResetWindowPosition,
    required this.crossRestartGeometryAvailable,
    this.includeWindowSettings = true,
  });

  final AppSettings settings;
  final AppColorScheme colors;
  final bool canEdit;
  final TextEditingController hotkeyController;
  final Future<void> Function(bool value) onLaunchAtStartup;
  final Future<void> Function(bool value) onStartHidden;
  final Future<void> Function(bool value) onCloseToTray;
  final Future<void> Function(AppWindowMode value) onWindowMode;
  final Future<void> Function(bool value) onHotkeyEnabled;
  final Future<void> Function(String value) onHotkeySubmitted;
  final Future<void> Function(bool value) onRememberWindowPosition;
  final Future<void> Function(bool value) onCompactAlwaysOnTop;
  final Future<void> Function(bool value) onCompactSkipTaskbar;
  final Future<void> Function(bool value) onLockCompactPosition;
  final Future<void> Function() onResetWindowPosition;
  final bool crossRestartGeometryAvailable;
  final bool includeWindowSettings;

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      icon: AppIcons.settings,
      title: '通用设置',
      subtitle: '启动、窗口行为与快捷键',
      colors: colors,
      children: [
        SettingsRow(
          title: '开机启动',
          description: '登录 Windows 后自动启动 LiteTodo',
          colors: colors,
          trailing: ShadSwitch(
            value: settings.launchAtStartup,
            enabled: canEdit,
            onChanged: onLaunchAtStartup,
          ),
        ),
        SettingsRow(
          title: '启动时隐藏到托盘',
          description: '应用启动后不主动显示窗口，可从托盘打开',
          colors: colors,
          trailing: ShadSwitch(
            value: settings.startHidden,
            enabled: canEdit,
            onChanged: onStartHidden,
          ),
        ),
        SettingsRow(
          title: '关闭时最小化到托盘',
          description: '关闭窗口后继续在后台运行',
          colors: colors,
          trailing: ShadSwitch(
            value: settings.closeToTray,
            enabled: canEdit,
            onChanged: onCloseToTray,
          ),
        ),
        if (includeWindowSettings) ...[
          SettingsRow(
            title: '默认窗口模式',
            description: '下次启动时使用的窗口布局',
            colors: colors,
            trailing: SegmentedChoice<AppWindowMode>(
              value: settings.defaultWindowMode,
              enabled: canEdit,
              choices: const [
                Choice(AppWindowMode.full, '完整'),
                Choice(AppWindowMode.compact, '紧凑'),
                Choice(AppWindowMode.quickAdd, '快速添加'),
              ],
              onChanged: onWindowMode,
            ),
          ),
        ],
        SettingsRow(
          title: '全局快捷键',
          description: '按下组合键快速打开添加 Todo',
          colors: colors,
          trailing: ShadSwitch(
            value: settings.globalHotkeyEnabled,
            enabled: canEdit,
            onChanged: onHotkeyEnabled,
          ),
        ),
        HotkeyRow(
          value: settings.globalHotkey.displayString,
          enabled: canEdit && settings.globalHotkeyEnabled,
          controller: hotkeyController,
          colors: colors,
          onSubmitted: onHotkeySubmitted,
        ),
        if (includeWindowSettings) ...[
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
          const SizedBox(height: AppMetrics.unit),
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
              size: ShadButtonSize.sm,
              leading: const Icon(AppIcons.restore, size: 14),
              enabled: canEdit,
              onPressed: onResetWindowPosition,
              child: const Text('恢复默认'),
            ),
          ),
          const SizedBox(height: AppMetrics.unit),
        ],
      ],
    );
  }
}
