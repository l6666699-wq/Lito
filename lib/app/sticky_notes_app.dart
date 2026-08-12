import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart' show ThemeMode;
import 'package:shadcn_ui/shadcn_ui.dart';

import '../application/workspace_controller.dart';
import '../domain/models/app_settings.dart';
import '../app/theme/app_theme.dart';
import '../app/theme/app_motion.dart';
import '../infrastructure/platform/sticky_notes_window_service.dart';
import '../presentation/sticky_notes/sticky_notes_window.dart';

/// Lightweight shell used by a secondary Flutter engine. It deliberately does
/// not construct the primary persistence/settings/tray graph.
class StickyNotesSecondaryApp extends StatelessWidget {
  const StickyNotesSecondaryApp({
    super.key,
    required this.workspace,
    required this.windowService,
    required this.projectId,
    this.groupId,
    required this.windowKey,
    required this.settingsListenable,
  });

  final WorkspaceController workspace;
  final StickyNotesSecondaryChannel windowService;
  final String? projectId;
  final String? groupId;
  final String windowKey;
  final ValueListenable<AppSettings> settingsListenable;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[workspace, settingsListenable]),
      builder: (context, child) {
        final settings = settingsListenable.value;
        final accentColorKey = _accentColorKey(settings);
        final themeMode = switch (settings.themeMode) {
          AppThemeMode.light => ThemeMode.light,
          AppThemeMode.dark => ThemeMode.dark,
          AppThemeMode.system => ThemeMode.system,
        };
        return ShadApp(
          title: 'LiteTodo',
          theme: AppTheme.lightFor(
            accentColorKey: accentColorKey,
            fontFamilyKey: settings.fontFamilyKey,
          ),
          darkTheme: AppTheme.darkFor(
            accentColorKey: accentColorKey,
            fontFamilyKey: settings.fontFamilyKey,
          ),
          themeMode: themeMode,
          themeCurve: AppMotion.standardCurve,
          builder: (context, child) {
            final brightness = themeMode == ThemeMode.dark
                ? Brightness.dark
                : themeMode == ThemeMode.light
                ? Brightness.light
                : MediaQuery.maybePlatformBrightnessOf(context) ??
                      Brightness.light;
            final liveTheme = brightness == Brightness.dark
                ? AppTheme.darkFor(
                    accentColorKey: accentColorKey,
                    fontFamilyKey: settings.fontFamilyKey,
                  )
                : AppTheme.lightFor(
                    accentColorKey: accentColorKey,
                    fontFamilyKey: settings.fontFamilyKey,
                  );
            return ShadAnimatedTheme(
              data: liveTheme,
              duration: AppMotion.theme,
              curve: AppMotion.standardCurve,
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: StickyNotesWindow(
            controller: workspace,
            windowService: windowService,
            projectId: projectId,
            groupId: groupId,
            windowKey: windowKey,
            onToggleTodoCompleted: (todoId) => windowService.mutate(
              operation: 'toggleCompleted',
              todoId: todoId,
            ),
            onEditTodoTitle: (todoId, title) => windowService.mutate(
              operation: 'editTitle',
              todoId: todoId,
              title: title,
            ),
            onAddTodo: (title) => windowService.mutate(
              operation: 'addTodo',
              title: title,
              projectId: projectId,
              groupId: groupId,
            ),
            onReorderTodo: (movingId, targetId, position) =>
                windowService.mutate(
                  operation: 'reorderTodo',
                  todoId: movingId,
                  targetId: targetId,
                  position: position.name,
                ),
          ),
        );
      },
    );
  }

  String _accentColorKey(AppSettings settings) {
    final id = projectId;
    if (id == null || groupId != null) return settings.accentColorKey;
    for (final project in workspace.projects) {
      if (project.id == id) return project.colorKey;
    }
    return settings.accentColorKey;
  }
}
