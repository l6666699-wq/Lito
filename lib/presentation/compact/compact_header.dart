import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../app/app_constants.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_metrics.dart';
import '../../application/window_controller.dart';
import '../../icons/local_project_icon.dart';

class CompactHeader extends StatelessWidget {
  const CompactHeader({super.key, required this.windowController});

  final WindowController windowController;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: SizedBox(
        height: AppMetrics.headerHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.focusSoft,
                  borderRadius: BorderRadius.circular(AppMetrics.smallRadius),
                ),
                child: LocalProjectIcon(
                  iconKey: 'check_correct',
                  color: colors.focus,
                  size: 15,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  AppConstants.appName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              _HeaderButton(
                label: '置顶',
                active: windowController.isAlwaysOnTop,
                tooltip: '置顶窗口',
                onPressed: windowController.toggleAlwaysOnTop,
              ),
              _HeaderButton(
                label: '锁定',
                active: windowController.isLocked,
                tooltip: '锁定位置',
                onPressed: windowController.toggleLocked,
              ),
              _HeaderButton(
                label: '快速',
                active: false,
                tooltip: '快速添加',
                onPressed: windowController.openQuickAdd,
              ),
              _HeaderButton(
                label: '全屏',
                active: false,
                tooltip: '切换到完整工作区',
                onPressed: () => windowController.switchMode(WindowMode.full),
              ),
              _HeaderButton(
                label: '×',
                active: false,
                tooltip: '隐藏到托盘',
                onPressed: windowController.hideToTray,
              ),
              if (windowController.hotkeyError != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    '热键不可用',
                    style: TextStyle(color: colors.textMuted, fontSize: 10),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.label,
    required this.active,
    required this.tooltip,
    required this.onPressed,
  });

  final String label;
  final bool active;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      button: true,
      label: tooltip,
      child: ShadButton.ghost(
        onPressed: onPressed,
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        foregroundColor: active ? colors.focus : colors.textMuted,
        backgroundColor: active ? colors.focusSoft : null,
        hoverBackgroundColor: colors.focusSoft,
        child: Text(label, style: const TextStyle(fontSize: 11)),
      ),
    );
  }
}
