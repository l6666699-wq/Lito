import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:litetodo/app/litetodo_app.dart';
import 'package:litetodo/application/quick_add_controller.dart';
import 'package:litetodo/application/settings_controller.dart';
import 'package:litetodo/application/window_controller.dart';
import 'package:litetodo/application/workspace_controller.dart';
import 'package:litetodo/infrastructure/platform/desktop_window_service.dart';
import 'package:litetodo/presentation/settings/settings_scope.dart';

void main() {
  testWidgets(
    'topbar inline composer uses the selected project instead of the stale preference',
    (tester) async {
      final workspace = WorkspaceController();
      final window = WindowController(
        desktopService: FakeDesktopWindowService(),
      );
      final quickAdd = QuickAddController(
        windowController: window,
        lastProjectId: 'project-home',
      );
      final settings = SettingsController(
        repository: InMemorySettingsRepository(),
      );
      addTearDown(() {
        settings.dispose();
        quickAdd.dispose();
        window.dispose();
        workspace.dispose();
      });

      await tester.pumpWidget(
        LiteTodoApp(
          controller: workspace,
          windowController: window,
          quickAddController: quickAdd,
          settingsController: settings,
        ),
      );
      await tester.pumpAndSettle();

      workspace.selectProject('project-focus');
      await tester.pump();
      expect(quickAdd.selectedProjectId, 'project-focus');

      await tester.tap(
        find.byKey(const ValueKey<String>('shell-add-task-button')),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('todo-inline-composer')),
        findsOneWidget,
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey<String>('todo-inline-composer')),
          matching: find.byType(EditableText),
        ),
        'project scoped root',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(
        workspace.todos
            .where((todo) => todo.title == 'project scoped root')
            .single
            .projectId,
        'project-focus',
      );
    },
  );
}
