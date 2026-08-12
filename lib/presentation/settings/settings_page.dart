import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show precisionErrorTolerance;
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_metrics.dart';
import '../../application/data_transfer_controller.dart';
import '../../application/settings_controller.dart';
import '../../application/window_controller.dart';
import '../../domain/models/app_settings.dart';
import '../../icons/app_icons.dart';
import '../common/app_dialog.dart';
import 'settings_appearance_section.dart';
import 'settings_data_section.dart';
import 'settings_general_section.dart';
import 'settings_about_section.dart';
import 'settings_scope.dart';
import 'settings_shared_controls.dart';
import 'settings_typography_section.dart';
import 'settings_window_section.dart';

// Settings uses a slightly tighter header rhythm than the global shell so the
// first card lines up with the supplied wide-screen reference.
const double _settingsPageTopPadding = 18;
// The shell's client area keeps a 14px visual breathing room below the rail;
// this is intentionally settings-local rather than changing AppMetrics.
const double _settingsPageBottomPadding = 14;
const double _settingsHeaderToContentGap = 10;
const double _settingsHeaderExtent = PageHeader.height;
const double _settingsRailMinHeight = 680;

/// The settings surface talks to injected application services through
/// [SettingsScope]; it never writes a file or calls a desktop plugin directly.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _sectionKeys = List<GlobalKey>.generate(
    6,
    (_) => GlobalKey(),
  );
  int _selectedSection = 0;
  Future<List<File>>? _backupsFuture;
  bool _backupInProgress = false;
  bool _dataTransferBusy = false;
  String? _dataTransferStatus;
  bool _dataTransferStatusIsError = false;
  bool _workspaceRecoveryDismissed = false;
  String? _statusMessage;
  bool _statusIsError = false;
  TextEditingController? _hotkeyTextController;

  @override
  void dispose() {
    _scrollController.dispose();
    _hotkeyTextController?.dispose();
    super.dispose();
  }

  void _selectSection(int index) {
    if (index < 0 ||
        index >= _sectionKeys.length ||
        index == _selectedSection) {
      return;
    }
    final previousOffset = _scrollController.hasClients
        ? _scrollController.offset
        : null;
    setState(() => _selectedSection = index);
    // Changing the active category swaps the content in place. Keep the
    // existing page position when the newly selected module has a shorter
    // scroll extent; the controller will clamp only when that extent requires
    // it, rather than jumping back to the top on every category change.
    if (previousOffset != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        final position = _scrollController.position;
        final offset = previousOffset
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble();
        if ((position.pixels - offset).abs() > precisionErrorTolerance) {
          _scrollController.jumpTo(offset);
        }
      });
    }
  }

  void _showStatus(String message, {bool error = false}) {
    if (!mounted) return;
    setState(() {
      _statusMessage = message;
      _statusIsError = error;
    });
  }

  Future<void> _setLaunchAtStartup(SettingsScope scope, bool value) async {
    final applied = await scope.settingsController.setLaunchAtStartup(value);
    if (!applied) {
      _showStatus('开机启动设置失败，请检查系统权限。', error: true);
    }
  }

  Future<void> _setStartHidden(SettingsScope scope, bool value) async {
    final applied = await scope.settingsController.setStartHidden(value);
    if (!applied) {
      _showStatus(
        _localizedSettingsError(scope.settingsController),
        error: true,
      );
    }
  }

  Future<void> _setGlobalHotkeyEnabled(SettingsScope scope, bool value) async {
    final applied = await scope.settingsController.setGlobalHotkeyEnabled(
      value,
    );
    if (!applied) {
      _showStatus('全局快捷键注册失败，请检查权限或按键冲突。', error: true);
    }
  }

  Future<void> _setCloseToTray(SettingsScope scope, bool value) async {
    final applied = await scope.settingsController.setCloseToTray(value);
    if (applied) {
      await scope.windowController.setCloseToTray(value);
    } else {
      _showStatus(
        _localizedSettingsError(scope.settingsController),
        error: true,
      );
    }
  }

  Future<void> _setRememberWindowPosition(
    SettingsScope scope,
    bool value,
  ) async {
    final applied = await scope.settingsController.setRememberWindowPosition(
      value,
    );
    if (applied) {
      await scope.windowController.setRememberWindowPosition(value);
    } else {
      _showStatus(
        _localizedSettingsError(scope.settingsController),
        error: true,
      );
    }
  }

  Future<void> _setCompactAlwaysOnTop(SettingsScope scope, bool value) async {
    final previous = scope.settingsController.compactAlwaysOnTop;
    try {
      await scope.windowController.setCompactAlwaysOnTop(value);
      final applied = await scope.settingsController.setCompactAlwaysOnTop(
        value,
      );
      if (!applied) {
        await scope.windowController.setCompactAlwaysOnTop(previous);
        _showStatus('紧凑模式置顶设置未能应用，请稍后重试。', error: true);
      }
    } catch (_) {
      _showStatus('紧凑模式置顶设置未能应用，请稍后重试。', error: true);
    }
  }

  Future<void> _setCompactSkipTaskbar(SettingsScope scope, bool value) async {
    final previous = scope.settingsController.compactSkipTaskbar;
    try {
      await scope.windowController.setCompactSkipTaskbar(value);
      final applied = await scope.settingsController.setCompactSkipTaskbar(
        value,
      );
      if (!applied) {
        await scope.windowController.setCompactSkipTaskbar(previous);
        _showStatus('紧凑模式任务栏设置未能应用，请稍后重试。', error: true);
      }
    } catch (_) {
      _showStatus('紧凑模式任务栏设置未能应用，请稍后重试。', error: true);
    }
  }

  Future<void> _setLockCompactPosition(SettingsScope scope, bool value) async {
    final previous = scope.settingsController.lockCompactPosition;
    try {
      await scope.windowController.setLockCompactPosition(value);
      final applied = await scope.settingsController.setLockCompactPosition(
        value,
      );
      if (!applied) {
        await scope.windowController.setLockCompactPosition(previous);
        _showStatus('紧凑模式位置锁定设置未能应用，请稍后重试。', error: true);
      }
    } catch (_) {
      _showStatus('紧凑模式位置锁定设置未能应用，请稍后重试。', error: true);
    }
  }

  Future<void> _resetWindowPosition(SettingsScope scope) async {
    final previousFull = scope.windowController.geometryFor(WindowMode.full);
    final previousCompact = scope.windowController.geometryFor(
      WindowMode.compact,
    );
    try {
      await scope.windowController.resetDefaultWindowPosition(persist: false);
      final applied = await scope.settingsController.resetWindowGeometries();
      if (applied) {
        _showStatus('窗口位置已恢复默认。');
      } else {
        await scope.windowController.restoreGeometrySnapshot(
          fullGeometry: previousFull,
          compactGeometry: previousCompact,
        );
        _showStatus('窗口位置设置未能应用，请稍后重试。', error: true);
      }
    } catch (_) {
      try {
        await scope.windowController.restoreGeometrySnapshot(
          fullGeometry: previousFull,
          compactGeometry: previousCompact,
        );
      } catch (_) {}
      _showStatus('窗口位置设置未能应用，请稍后重试。', error: true);
    }
  }

  Future<void> _setWindowMode(SettingsScope scope, AppWindowMode value) async {
    final applied = await scope.settingsController.setDefaultWindowMode(value);
    if (!applied) {
      _showStatus(
        _localizedSettingsError(scope.settingsController),
        error: true,
      );
    }
  }

  Future<void> _openDirectory(SettingsScope scope) async {
    final opened = await scope.dataDirectoryService.open();
    if (!opened) _showStatus('暂时无法打开数据目录。', error: true);
  }

  Future<void> _createBackup(SettingsScope scope) async {
    if (_backupInProgress) return;
    setState(() => _backupInProgress = true);
    try {
      await scope.workspaceController.flushNow();
      final file = await scope.backupService.createManualBackup();
      _backupsFuture = scope.backupService.listBackups();
      if (mounted) _showStatus('备份已完成：${file.path}');
    } catch (error) {
      _showStatus('备份失败，请稍后重试：$error', error: true);
    } finally {
      if (mounted) setState(() => _backupInProgress = false);
    }
  }

  Future<void> _exportData(SettingsScope scope) async {
    final transfer = scope.dataTransferController;
    if (transfer == null || _dataTransferBusy) return;
    await _runDataTransfer(() => transfer.exportData());
  }

  Future<void> _importData(BuildContext context, SettingsScope scope) async {
    final transfer = scope.dataTransferController;
    if (transfer == null || _dataTransferBusy) return;
    final confirmed = await _confirmImport(context);
    if (confirmed != true || !mounted) return;
    await _runDataTransfer(() => transfer.importData());
    if (mounted) {
      setState(() {
        _backupsFuture = scope.backupService.listBackups();
      });
    }
  }

  Future<void> _runDataTransfer(
    Future<DataTransferResult> Function() operation,
  ) async {
    if (_dataTransferBusy) return;
    setState(() {
      _dataTransferBusy = true;
      _dataTransferStatus = null;
    });
    try {
      final result = await operation();
      if (!mounted || result.isCancelled) return;
      setState(() {
        _dataTransferStatus = result.message;
        _dataTransferStatusIsError = !result.isSuccess;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _dataTransferStatus = '数据导入或导出未完成，原数据保持不变。';
          _dataTransferStatusIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _dataTransferBusy = false);
    }
  }

  Future<bool?> _confirmImport(BuildContext context) {
    return showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ShadDialog.alert(
        key: const ValueKey<String>('settings-import-confirm-dialog'),
        title: const Text('导入数据？'),
        description: const Text('导入会先备份当前数据，然后替换当前 Todo 数据。此操作不会修改设置。'),
        actions: [
          ShadButton.ghost(
            key: const ValueKey<String>('settings-import-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ShadButton(
            key: const ValueKey<String>('settings-import-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(AppIcons.importData, size: 14),
                const SizedBox(width: AppMetrics.unit),
                const Text('继续导入'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _setHotkey(SettingsScope scope, String value) async {
    try {
      final config = AppHotkeyConfig.parse(value);
      final applied = await scope.settingsController.setGlobalHotkey(config);
      if (!applied) {
        _showStatus(
          _localizedSettingsError(scope.settingsController),
          error: true,
        );
      } else {
        _hotkeyTextController?.text = config.displayString;
        _showStatus('全局快捷键已更新为 ${config.displayString}');
      }
    } on FormatException {
      _showStatus('快捷键格式无效，请使用 Ctrl+Alt+Space 这样的组合。', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = SettingsScope.of(context);
    final settings = scope.settingsController.settings;
    final colors = AppColors.of(context);
    final canEdit = scope.settingsController.isInitialized;
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 1120;
        final sections = _sections(scope, settings, colors, canEdit);
        final wideRailHeight = constraints.hasBoundedHeight
            ? _wideRailHeight(constraints.maxHeight)
            : null;
        return SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(
            AppMetrics.pagePadding,
            _settingsPageTopPadding,
            AppMetrics.pagePadding,
            _settingsPageBottomPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(colors: colors),
              if (_statusMessage != null) ...[
                const SizedBox(height: AppMetrics.unit * 3),
                StatusBanner(
                  message: _statusMessage!,
                  error: _statusIsError,
                  colors: colors,
                  onDismiss: () => setState(() => _statusMessage = null),
                ),
              ],
              if (_statusMessage == null &&
                  scope.settingsController.lastPersistenceError != null) ...[
                const SizedBox(height: AppMetrics.unit * 3),
                StatusBanner(
                  message: _localizedSettingsError(scope.settingsController),
                  error: true,
                  colors: colors,
                ),
              ],
              if (scope.settingsController.recoveryWarning != null) ...[
                const SizedBox(height: AppMetrics.unit * 2),
                StatusBanner(
                  message: '设置恢复提示：${scope.settingsController.recoveryWarning}',
                  colors: colors,
                ),
              ],
              const SizedBox(height: _settingsHeaderToContentGap),
              if (narrow) ...[
                CategoryRail(
                  selected: _selectedSection,
                  horizontal: true,
                  colors: colors,
                  onSelected: _selectSection,
                ),
                const SizedBox(height: AppMetrics.unit * 4),
                ...sections,
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 260,
                      child: CategoryRail(
                        selected: _selectedSection,
                        colors: colors,
                        onSelected: _selectSection,
                        height: wideRailHeight,
                      ),
                    ),
                    const SizedBox(width: AppMetrics.unit * 6),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1075),
                          child: SizedBox(
                            width: double.infinity,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: sections,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: AppMetrics.unit * 2),
              SettingsFooterHint(colors: colors),
            ],
          ),
        );
      },
    );
  }

  double _wideRailHeight(double viewportHeight) {
    final remaining =
        viewportHeight -
        _settingsPageTopPadding -
        _settingsHeaderExtent -
        _settingsHeaderToContentGap -
        _settingsPageBottomPadding;
    return remaining < _settingsRailMinHeight
        ? _settingsRailMinHeight
        : remaining;
  }

  List<Widget> _sections(
    SettingsScope scope,
    AppSettings settings,
    AppColorScheme colors,
    bool canEdit,
  ) {
    final hotkeyController = _hotkeyControllerFor(settings.globalHotkey);
    final sectionWidgets = <Widget>[
      GeneralSettingsSection(
        settings: settings,
        colors: colors,
        canEdit: canEdit,
        hotkeyController: hotkeyController,
        onLaunchAtStartup: (value) => _setLaunchAtStartup(scope, value),
        onStartHidden: (value) => _setStartHidden(scope, value),
        onCloseToTray: (value) => _setCloseToTray(scope, value),
        onWindowMode: (value) => _setWindowMode(scope, value),
        onHotkeyEnabled: (value) => _setGlobalHotkeyEnabled(scope, value),
        onHotkeySubmitted: (value) => _setHotkey(scope, value),
        onRememberWindowPosition: (value) =>
            _setRememberWindowPosition(scope, value),
        onCompactAlwaysOnTop: (value) => _setCompactAlwaysOnTop(scope, value),
        onCompactSkipTaskbar: (value) => _setCompactSkipTaskbar(scope, value),
        onLockCompactPosition: (value) => _setLockCompactPosition(scope, value),
        onResetWindowPosition: () => _resetWindowPosition(scope),
        crossRestartGeometryAvailable:
            scope.settingsController.supportsCrossRestartWindowGeometry,
        includeWindowSettings: false,
      ),
      WindowSettingsSection(
        settings: settings,
        colors: colors,
        canEdit: canEdit,
        onWindowMode: (value) => _setWindowMode(scope, value),
        onRememberWindowPosition: (value) =>
            _setRememberWindowPosition(scope, value),
        onCompactAlwaysOnTop: (value) => _setCompactAlwaysOnTop(scope, value),
        onCompactSkipTaskbar: (value) => _setCompactSkipTaskbar(scope, value),
        onLockCompactPosition: (value) => _setLockCompactPosition(scope, value),
        onResetWindowPosition: () => _resetWindowPosition(scope),
        crossRestartGeometryAvailable:
            scope.settingsController.supportsCrossRestartWindowGeometry,
      ),
      AppearanceSettingsSection(
        scope: scope,
        settings: settings,
        colors: colors,
        canEdit: canEdit,
      ),
      TypographySettingsSection(
        scope: scope,
        settings: settings,
        colors: colors,
        canEdit: canEdit,
      ),
      DataSettingsSection(
        scope: scope,
        settings: settings,
        colors: colors,
        canEdit: canEdit,
        backupFuture: _backupsFuture ??= scope.backupService.listBackups(),
        backupInProgress: _backupInProgress,
        onOpenDirectory: () => _openDirectory(scope),
        onCreateBackup: () => _createBackup(scope),
        dataTransferAvailable: scope.dataTransferController != null,
        dataTransferBusy: _dataTransferBusy,
        dataTransferStatus: _dataTransferStatus,
        dataTransferStatusIsError: _dataTransferStatusIsError,
        onExportData: scope.dataTransferController == null
            ? null
            : () => _exportData(scope),
        onImportData: scope.dataTransferController == null
            ? null
            : () => _importData(context, scope),
        recoveryWarning:
            scope.workspaceController.recoveryWarning == null ||
                _workspaceRecoveryDismissed
            ? null
            : '数据恢复提示：${scope.workspaceController.recoveryWarning}',
        onDismissRecoveryWarning: () =>
            setState(() => _workspaceRecoveryDismissed = true),
      ),
      const AboutSettingsSection(),
    ];
    return [
      for (var index = 0; index < sectionWidgets.length; index++)
        Offstage(
          key: ValueKey<String>('settings-section-$index'),
          offstage: index != _selectedSection,
          child: KeyedSubtree(
            key: _sectionKeys[index],
            child: sectionWidgets[index],
          ),
        ),
    ];
  }

  TextEditingController _hotkeyControllerFor(AppHotkeyConfig value) {
    final controller = _hotkeyTextController ??= TextEditingController();
    if (controller.text.isEmpty) controller.text = value.displayString;
    return controller;
  }
}

String _localizedSettingsError(SettingsController controller) {
  final error = controller.lastPersistenceError;
  if (error == null || error.isEmpty) return '设置未能应用，请稍后重试。';
  return '设置未能应用：$error';
}
