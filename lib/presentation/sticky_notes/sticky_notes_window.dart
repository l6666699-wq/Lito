import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../app/app_text.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_metrics.dart';
import '../../application/workspace_controller.dart';
import '../../infrastructure/platform/sticky_notes_window_service.dart';
import '../../icons/app_icons.dart';
import '../todo/todo_list.dart';

/// The content hosted by each native sticky-note engine.
///
/// It intentionally receives a read-only [WorkspaceController] projection in
/// secondary engines. The primary engine's controller remains authoritative;
/// native snapshot events keep this list live without a second persistence
/// writer.
class StickyNotesWindow extends StatelessWidget {
  const StickyNotesWindow({
    super.key,
    required this.controller,
    required this.windowService,
    required this.projectId,
    required this.windowKey,
  });

  final WorkspaceController controller;
  final StickyNotesSecondaryChannel windowService;
  final String? projectId;
  final String windowKey;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final colors = AppColors.of(context);
        final rows = controller.visibleRowsForProject(projectId);
        var title = AppText.inbox;
        if (projectId != null) {
          for (final project in controller.projects) {
            if (project.id == projectId) {
              title = project.name;
              break;
            }
          }
        }
        return ColoredBox(
          color: colors.canvas,
          child: Column(
            children: [
              _StickyHeader(
                title: title,
                windowKey: windowKey,
                windowService: windowService,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppMetrics.compactPadding),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      border: Border.all(color: colors.border),
                      borderRadius: BorderRadius.circular(
                        AppMetrics.cardRadius,
                      ),
                    ),
                    child: TodoList(
                      controller: controller,
                      rows: rows,
                      readOnly: true,
                      emptyLabel: AppText.inbox,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StickyHeader extends StatelessWidget {
  const _StickyHeader({
    required this.title,
    required this.windowKey,
    required this.windowService,
  });

  final String title;
  final String windowKey;
  final StickyNotesSecondaryChannel windowService;

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
              Icon(AppIcons.stickyNotes, color: colors.focus, size: 17),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onPanStart: (_) =>
                      unawaited(windowService.startDragging(windowKey)),
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              _StickyHeaderButton(
                key: const ValueKey<String>('sticky-back-full-button'),
                icon: AppIcons.back,
                tooltip: '返回全屏',
                onPressed: () => unawaited(windowService.close(windowKey)),
              ),
              _StickyHeaderButton(
                key: const ValueKey<String>('sticky-pin-button'),
                icon: AppIcons.pin,
                tooltip: '置顶',
                onPressed: () =>
                    unawaited(windowService.setAlwaysOnTop(windowKey, true)),
              ),
              _StickyHeaderButton(
                key: const ValueKey<String>('sticky-close-button'),
                icon: AppIcons.windowClose,
                tooltip: '关闭',
                onPressed: () => unawaited(windowService.close(windowKey)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StickyHeaderButton extends StatelessWidget {
  const _StickyHeaderButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      button: true,
      label: tooltip,
      child: ShadTooltip(
        builder: (context) => Text(tooltip),
        child: ShadButton.ghost(
          onPressed: onPressed,
          height: 28,
          width: 28,
          padding: EdgeInsets.zero,
          foregroundColor: colors.textMuted,
          hoverBackgroundColor: colors.focusSoft,
          child: Icon(icon, size: 14),
        ),
      ),
    );
  }
}
