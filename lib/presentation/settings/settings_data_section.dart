import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_metrics.dart';
import '../../domain/models/app_settings.dart';
import '../../icons/app_icons.dart';
import 'settings_scope.dart';
import 'settings_shared_controls.dart';

class DataSettingsSection extends StatelessWidget {
  const DataSettingsSection({
    super.key,
    required this.scope,
    required this.settings,
    required this.colors,
    required this.canEdit,
    required this.backupFuture,
    required this.backupInProgress,
    required this.onOpenDirectory,
    required this.onCreateBackup,
    required this.dataTransferAvailable,
    required this.dataTransferBusy,
    required this.dataTransferStatus,
    required this.dataTransferStatusIsError,
    required this.onExportData,
    required this.onImportData,
    required this.recoveryWarning,
    required this.onDismissRecoveryWarning,
  });

  final SettingsScope scope;
  final AppSettings settings;
  final AppColorScheme colors;
  final bool canEdit;
  final Future<List<File>> backupFuture;
  final bool backupInProgress;
  final Future<void> Function() onOpenDirectory;
  final Future<void> Function() onCreateBackup;
  final bool dataTransferAvailable;
  final bool dataTransferBusy;
  final String? dataTransferStatus;
  final bool dataTransferStatusIsError;
  final Future<void> Function()? onExportData;
  final Future<void> Function()? onImportData;
  final String? recoveryWarning;
  final VoidCallback? onDismissRecoveryWarning;

  @override
  Widget build(BuildContext context) {
    final controller = scope.settingsController;
    return SettingsCard(
      icon: AppIcons.backup,
      title: '数据与备份',
      subtitle: '数据留在本机，备份操作不会改变当前内容',
      colors: colors,
      children: [
        if (recoveryWarning != null)
          StatusBanner(
            key: const ValueKey<String>('settings-recovery-warning'),
            message: recoveryWarning!,
            colors: colors,
            onDismiss: onDismissRecoveryWarning,
          ),
        if (recoveryWarning != null)
          const SizedBox(height: AppMetrics.unit * 2),
        SettingsRow(
          title: '自动备份',
          description: '应用退出时保留有效的数据快照',
          colors: colors,
          trailing: ShadSwitch(
            value: settings.autoBackup,
            enabled: canEdit,
            onChanged: controller.setAutoBackup,
          ),
        ),
        SettingsRow(
          title: '数据目录',
          description: 'settings.json、data.json 与 backups 文件夹',
          colors: colors,
          trailing: FutureBuilder<Directory>(
            future: scope.dataDirectoryService.resolve(),
            builder: (context, snapshot) {
              final path = snapshot.data?.path ?? '正在读取...';
              return ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        path,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.textMuted, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: AppMetrics.unit * 2),
                    ShadButton.outline(
                      size: ShadButtonSize.sm,
                      leading: const Icon(AppIcons.folder, size: 14),
                      onPressed: onOpenDirectory,
                      child: const Text('打开'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        SettingsRow(
          title: '手动备份',
          description: '先保存当前数据，再创建只读 JSON 快照',
          colors: colors,
          trailing: ShadButton.outline(
            size: ShadButtonSize.sm,
            leading: backupInProgress
                ? const Icon(AppIcons.clock, size: 14)
                : const Icon(AppIcons.backup, size: 14),
            enabled: canEdit && !backupInProgress,
            onPressed: onCreateBackup,
            child: Text(backupInProgress ? '备份中...' : '立即备份'),
          ),
        ),
        SettingsRow(
          title: '数据导出',
          description: '导出完整 data.json 快照到本机文件',
          colors: colors,
          trailing: ShadButton.outline(
            key: const ValueKey<String>('settings-export-data'),
            size: ShadButtonSize.sm,
            leading: const Icon(AppIcons.exportData, size: 14),
            enabled:
                canEdit &&
                dataTransferAvailable &&
                !dataTransferBusy &&
                onExportData != null,
            onPressed: onExportData,
            child: Text(dataTransferBusy ? '处理中...' : '导出数据'),
          ),
        ),
        SettingsRow(
          title: '数据导入',
          description: '先备份当前数据，再替换为选中的 JSON 快照',
          colors: colors,
          trailing: ShadButton.outline(
            key: const ValueKey<String>('settings-import-data'),
            size: ShadButtonSize.sm,
            leading: const Icon(AppIcons.importData, size: 14),
            enabled:
                canEdit &&
                dataTransferAvailable &&
                !dataTransferBusy &&
                onImportData != null,
            onPressed: onImportData,
            child: Text(dataTransferBusy ? '处理中...' : '导入数据'),
          ),
        ),
        if (dataTransferStatus != null) ...[
          const SizedBox(height: AppMetrics.unit * 2),
          StatusBanner(
            message: dataTransferStatus!,
            error: dataTransferStatusIsError,
            colors: colors,
          ),
        ],
        RecentBackups(future: backupFuture, colors: colors),
      ],
    );
  }
}
