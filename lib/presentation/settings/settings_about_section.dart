import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../app/app_constants.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_metrics.dart';
import '../../icons/app_icons.dart';
import 'settings_shared_controls.dart';

/// Supplies the registered package licenses when the license dialog opens.
///
/// Keeping the collector injectable makes the UI deterministic in tests while
/// retaining Flutter's lazy [LicenseRegistry.licenses] behavior in production.
typedef LicenseStreamFactory = Stream<LicenseEntry> Function();

/// Standalone About content for the future Settings route.
///
/// This section intentionally has no route or controller dependency. It can be
/// placed into the existing settings page when the integration milestone is
/// approved.
class AboutSettingsSection extends StatelessWidget {
  const AboutSettingsSection({super.key, this.licenseStreamFactory});

  final LicenseStreamFactory? licenseStreamFactory;

  Future<void> _showLicenses(BuildContext context) async {
    final streamFactory =
        licenseStreamFactory ?? (() => LicenseRegistry.licenses);
    await showShadDialog<void>(
      context: context,
      barrierLabel: '关闭第三方许可证',
      builder: (context) => _LicenseDialog(streamFactory: streamFactory),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SettingsCard(
      icon: AppIcons.info,
      title: '关于 LiteTodo',
      subtitle: '版本信息与第三方许可',
      colors: colors,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppMetrics.unit * 3),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.focusSoft,
                  borderRadius: BorderRadius.circular(AppMetrics.normalRadius),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppMetrics.unit * 3),
                  child: Icon(AppIcons.info, color: colors.focus, size: 22),
                ),
              ),
              const SizedBox(width: AppMetrics.unit * 3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppConstants.appName,
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppMetrics.unit),
                    Text(
                      '本地优先的桌面任务管理器',
                      style: TextStyle(color: colors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SettingsRow(
          title: '版本',
          description: '当前安装版本与构建号',
          colors: colors,
          trailing: Text(
            AppConstants.appVersionLabel,
            style: TextStyle(
              color: colors.text,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SettingsRow(
          title: '技术',
          description: '应用运行平台',
          colors: colors,
          trailing: Text(
            AppConstants.technologyLabel,
            textAlign: TextAlign.end,
            style: TextStyle(color: colors.textMuted, fontSize: 12),
          ),
        ),
        SettingsRow(
          title: '第三方许可证',
          description: '查看 LiteTodo 使用的开源软件许可',
          colors: colors,
          trailing: Semantics(
            button: true,
            label: '查看第三方许可证',
            child: ShadButton.outline(
              key: const ValueKey<String>('about-licenses-button'),
              size: ShadButtonSize.sm,
              leading: Icon(AppIcons.info, size: 15),
              onPressed: () => _showLicenses(context),
              child: const Text('查看许可证'),
            ),
          ),
        ),
      ],
    );
  }
}

class _LicenseDialog extends StatefulWidget {
  const _LicenseDialog({required this.streamFactory});

  final LicenseStreamFactory streamFactory;

  @override
  State<_LicenseDialog> createState() => _LicenseDialogState();
}

class _LicenseDialogState extends State<_LicenseDialog> {
  StreamSubscription<LicenseEntry>? _subscription;
  final List<LicenseEntry> _entries = <LicenseEntry>[];
  LicenseEntry? _selectedEntry;
  Object? _error;
  bool _isComplete = false;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _loadEntries() {
    _subscription?.cancel();
    _entries.clear();
    _selectedEntry = null;
    _error = null;
    _isComplete = false;
    if (mounted) setState(() {});

    try {
      final stream = widget.streamFactory();
      _subscription = stream.listen(
        (entry) {
          if (!mounted) return;
          setState(() => _entries.add(entry));
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!mounted) return;
          setState(() => _error = error);
        },
        onDone: () {
          if (!mounted) return;
          setState(() => _isComplete = true);
        },
      );
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final size = MediaQuery.sizeOf(context);
    final maxHeight = (size.height * .82).clamp(320.0, 680.0).toDouble();
    final bodyHeight = (maxHeight - 112).clamp(180.0, 560.0).toDouble();
    final bodyWidth = (size.width * .84).clamp(260.0, 640.0).toDouble();
    final selected = _selectedEntry;

    return ShadDialog(
      key: const ValueKey<String>('about-licenses-dialog'),
      title: selected == null
          ? const Text('第三方许可证')
          : Row(
              children: [
                Semantics(
                  button: true,
                  label: '返回许可证列表',
                  child: ShadButton.ghost(
                    key: const ValueKey<String>('license-detail-back'),
                    size: ShadButtonSize.sm,
                    width: 28,
                    height: 28,
                    padding: EdgeInsets.zero,
                    leading: Icon(AppIcons.chevronLeft, size: 16),
                    onPressed: () => setState(() => _selectedEntry = null),
                  ),
                ),
                const SizedBox(width: AppMetrics.unit),
                const Text('许可证详情'),
              ],
            ),
      description: Text(
        selected == null ? '按软件包查看已注册的开源许可文本。' : _packageLabel(selected),
      ),
      closeIcon: Semantics(
        button: true,
        label: '关闭第三方许可证',
        child: ShadIconButton.ghost(
          key: const ValueKey<String>('license-dialog-close'),
          icon: Icon(AppIcons.windowClose, size: 16),
          width: 20,
          height: 20,
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      scrollable: false,
      constraints: BoxConstraints(maxWidth: 720, maxHeight: maxHeight),
      child: SizedBox(
        width: bodyWidth,
        height: bodyHeight,
        child: selected == null
            ? _buildEntryBody(colors)
            : _LicenseDetail(entry: selected, colors: colors),
      ),
    );
  }

  Widget _buildEntryBody(AppColorScheme colors) {
    if (_error != null && _entries.isEmpty) {
      return _LicenseErrorState(colors: colors, onRetry: _loadEntries);
    }
    if (!_isComplete && _entries.isEmpty) {
      return _LicenseLoadingState(colors: colors);
    }
    if (_entries.isEmpty) {
      return _LicenseEmptyState(colors: colors);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null) ...[
          _InlineLicenseError(colors: colors, onRetry: _loadEntries),
          const SizedBox(height: AppMetrics.unit * 2),
        ],
        Expanded(
          child: ListView.separated(
            key: const ValueKey<String>('license-entry-list'),
            padding: EdgeInsets.zero,
            itemCount: _entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppMetrics.unit),
            itemBuilder: (context, index) {
              final entry = _entries[index];
              final label = _packageLabel(entry);
              return ShadButton.ghost(
                key: ValueKey<String>('license-entry-$index'),
                width: double.infinity,
                expands: true,
                mainAxisAlignment: MainAxisAlignment.start,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppMetrics.unit * 3,
                  vertical: AppMetrics.unit * 2.5,
                ),
                leading: Icon(AppIcons.info, size: 16),
                trailing: Icon(AppIcons.chevronRight, size: 16),
                onPressed: () => setState(() => _selectedEntry = entry),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LicenseDetail extends StatelessWidget {
  const _LicenseDetail({required this.entry, required this.colors});

  final LicenseEntry entry;
  final AppColorScheme colors;

  @override
  Widget build(BuildContext context) {
    // Paragraphs are computed only after a user selects one package. The list
    // view never touches license text, keeping the initial dialog lightweight.
    final paragraphs = entry.paragraphs.toList(growable: false);
    if (paragraphs.isEmpty) {
      return Center(
        child: Text(
          '此许可证没有可显示的文本。',
          style: TextStyle(color: colors.textMuted, fontSize: 12),
        ),
      );
    }
    return ListView.builder(
      key: const ValueKey<String>('license-paragraph-list'),
      padding: EdgeInsets.zero,
      itemCount: paragraphs.length,
      itemBuilder: (context, index) {
        final paragraph = paragraphs[index];
        final centered = paragraph.indent == LicenseParagraph.centeredIndent;
        return Padding(
          padding: EdgeInsets.only(
            left: centered ? 0 : paragraph.indent * AppMetrics.unit * 2,
            bottom: AppMetrics.unit * 3,
          ),
          child: Text(
            paragraph.text,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: TextStyle(color: colors.text, fontSize: 12, height: 1.45),
          ),
        );
      },
    );
  }
}

class _LicenseLoadingState extends StatelessWidget {
  const _LicenseLoadingState({required this.colors});

  final AppColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.clock, color: colors.textMuted, size: 22),
          const SizedBox(height: AppMetrics.unit * 2),
          Text(
            '正在加载许可证...',
            style: TextStyle(color: colors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _LicenseEmptyState extends StatelessWidget {
  const _LicenseEmptyState({required this.colors});

  final AppColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.info, color: colors.textMuted, size: 22),
          const SizedBox(height: AppMetrics.unit * 2),
          Text(
            '暂无已注册的第三方许可证。',
            style: TextStyle(color: colors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _LicenseErrorState extends StatelessWidget {
  const _LicenseErrorState({required this.colors, required this.onRetry});

  final AppColorScheme colors;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.info, color: colors.focus, size: 22),
          const SizedBox(height: AppMetrics.unit * 2),
          Text(
            '许可证加载失败',
            style: TextStyle(
              color: colors.text,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppMetrics.unit),
          Text(
            '请稍后重试。',
            style: TextStyle(color: colors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: AppMetrics.unit * 3),
          ShadButton.outline(
            key: const ValueKey<String>('license-retry-button'),
            size: ShadButtonSize.sm,
            leading: Icon(AppIcons.restore, size: 15),
            onPressed: onRetry,
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}

class _InlineLicenseError extends StatelessWidget {
  const _InlineLicenseError({required this.colors, required this.onRetry});

  final AppColorScheme colors;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '部分许可证加载失败。',
            style: TextStyle(color: colors.focus, fontSize: 11),
          ),
        ),
        ShadButton.ghost(
          key: const ValueKey<String>('license-inline-retry-button'),
          size: ShadButtonSize.sm,
          padding: const EdgeInsets.symmetric(
            horizontal: AppMetrics.unit * 2,
            vertical: AppMetrics.unit,
          ),
          onPressed: onRetry,
          child: const Text('重试'),
        ),
      ],
    );
  }
}

String _packageLabel(LicenseEntry entry) {
  final packages = entry.packages
      .map((packageName) => packageName.trim())
      .where((packageName) => packageName.isNotEmpty)
      .toList(growable: false);
  if (packages.isEmpty) return '未命名软件包';
  return packages.join('、');
}
