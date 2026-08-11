import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:litetodo/app/theme/app_theme.dart';
import 'package:litetodo/application/app_navigation_controller.dart';
import 'package:litetodo/application/quick_add_controller.dart';
import 'package:litetodo/application/sticky_notes_controller.dart';
import 'package:litetodo/application/window_controller.dart';
import 'package:litetodo/application/workspace_controller.dart';
import 'package:litetodo/domain/models/visible_todo_row.dart';
import 'package:litetodo/infrastructure/platform/desktop_window_service.dart';
import 'package:litetodo/infrastructure/platform/sticky_notes_window_service.dart';
import 'package:litetodo/icons/app_icons.dart';
import 'package:litetodo/presentation/shell/app_shell.dart';
import 'package:litetodo/presentation/sticky_notes/sticky_notes_window.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('full shell exposes the Lucide sticky-note launcher', (
    tester,
  ) async {
    final workspace = WorkspaceController();
    final window = WindowController(desktopService: FakeDesktopWindowService());
    final navigation = AppNavigationController();
    final quickAdd = QuickAddController(windowController: window);
    final service = FakeStickyNotesWindowService();
    final sticky = StickyNotesController(
      workspace: workspace,
      windowService: service,
    );
    addTearDown(() {
      sticky.dispose();
      quickAdd.dispose();
      navigation.dispose();
      window.dispose();
      workspace.dispose();
    });

    await tester.pumpWidget(
      ShadApp(
        theme: AppTheme.lightFor(),
        home: AppShell(
          controller: workspace,
          windowController: window,
          quickAddController: quickAdd,
          navigationController: navigation,
          stickyNotesController: sticky,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final launcher = find.byKey(
      const ValueKey<String>('shell-sticky-notes-button'),
    );
    expect(launcher, findsOneWidget);
    await tester.tap(launcher);
    await tester.pump();
    expect(service.openKeys, contains(StickyNotesController.inboxKey));
  });

  testWidgets('sticky note renders live project rows read-only', (
    tester,
  ) async {
    final workspace = WorkspaceController();
    final project = workspace.projects.first;
    final channel = StickyNotesSecondaryChannel();
    addTearDown(workspace.dispose);
    await tester.pumpWidget(
      ShadApp(
        theme: AppTheme.lightFor(),
        home: StickyNotesWindow(
          controller: workspace,
          windowService: channel,
          projectId: project.id,
          windowKey: StickyNotesController.keyFor(project.id),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('sticky-close-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('sticky-back-full-button')),
      findsOneWidget,
    );
    expect(find.byIcon(AppIcons.stickyNotes), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('todo-list-builder')),
      findsOneWidget,
    );

    final rows = workspace.visibleRowsForProject(project.id);
    expect(rows, isNotEmpty);
    final firstRow = rows.first;
    expect(
      find.byKey(ValueKey<String>('sticky-header-drag-region')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey<String>('sticky-task-row-${firstRow.todo.id}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey<String>('sticky-drag-handle-${firstRow.todo.id}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey<String>('sticky-checkbox-${firstRow.todo.id}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey<String>('sticky-edit-${firstRow.todo.id}')),
      findsOneWidget,
    );

    final completedRows = rows
        .where((row) => row.completionState == TodoVisualState.complete)
        .toList();
    if (completedRows.isNotEmpty) {
      final completedRow = completedRows.first;
      final completedTitle = find.descendant(
        of: find.byKey(
          ValueKey<String>('sticky-task-row-${completedRow.todo.id}'),
        ),
        matching: find.text(completedRow.todo.title),
      );
      expect(
        tester.widget<Text>(completedTitle).style?.decoration,
        TextDecoration.lineThrough,
      );
    }

    await tester.tap(
      find.byKey(ValueKey<String>('sticky-task-row-${firstRow.todo.id}')),
    );
    await tester.pump();
    expect(
      workspace.todos.firstWhere((todo) => todo.id == firstRow.todo.id),
      firstRow.todo,
    );
  });
}
