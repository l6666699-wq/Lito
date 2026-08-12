import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../application/workspace_controller.dart';
import '../app/theme/app_theme.dart';
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
    required this.windowKey,
  });

  final WorkspaceController workspace;
  final StickyNotesSecondaryChannel windowService;
  final String? projectId;
  final String windowKey;

  @override
  Widget build(BuildContext context) {
    return ShadApp(
      title: 'LiteTodo',
      theme: AppTheme.lightFor(),
      darkTheme: AppTheme.darkFor(),
      home: StickyNotesWindow(
        controller: workspace,
        windowService: windowService,
        projectId: projectId,
        windowKey: windowKey,
        onToggleTodoCompleted: (todoId) =>
            windowService.mutate(operation: 'toggleCompleted', todoId: todoId),
        onEditTodoTitle: (todoId, title) => windowService.mutate(
          operation: 'editTitle',
          todoId: todoId,
          title: title,
        ),
        onAddTodo: (title) => windowService.mutate(
          operation: 'addTodo',
          title: title,
          projectId: projectId,
        ),
        onReorderTodo: (movingId, targetId, position) => windowService.mutate(
          operation: 'reorderTodo',
          todoId: movingId,
          targetId: targetId,
          position: position.name,
        ),
      ),
    );
  }
}
