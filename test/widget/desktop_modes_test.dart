import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:litetodo/app/litetodo_app.dart';
import 'package:litetodo/application/quick_add_controller.dart';
import 'package:litetodo/application/window_controller.dart';
import 'package:litetodo/application/workspace_controller.dart';
import 'package:litetodo/infrastructure/platform/desktop_window_service.dart';
import 'package:litetodo/presentation/compact/compact_workspace.dart';
import 'package:litetodo/presentation/home/home_page.dart';
import 'package:litetodo/presentation/quick_add/quick_add_view.dart';
import 'package:litetodo/presentation/shell/full_app_shell.dart';
import 'package:litetodo/presentation/todo/todo_list.dart';

void main() {
  testWidgets('Full, Compact and QuickAdd share one controller and route', (
    tester,
  ) async {
    final workspace = WorkspaceController();
    final windows = WindowController(
      desktopService: FakeDesktopWindowService(),
    );
    final quickAdd = QuickAddController(windowController: windows);
    addTearDown(() {
      quickAdd.dispose();
      windows.dispose();
      workspace.dispose();
    });
    await tester.pumpWidget(
      LiteTodoApp(
        controller: workspace,
        windowController: windows,
        quickAddController: quickAdd,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ShadApp), findsOneWidget);
    expect(find.byType(FullAppShell), findsOneWidget);
    expect(find.byType(HomePage), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('home-content-card')),
      findsOneWidget,
    );
    expect(find.byType(TodoList), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('todo-list-builder')),
      findsOneWidget,
    );

    await windows.switchMode(WindowMode.compact);
    await tester.pumpAndSettle();
    expect(find.byType(CompactWorkspace), findsOneWidget);
    expect(find.byType(FullAppShell), findsNothing);
    expect(find.byType(TodoList), findsOneWidget);

    await windows.openQuickAdd();
    await tester.pumpAndSettle();
    expect(find.byType(QuickAddView), findsOneWidget);
    expect(find.byType(EditableText), findsOneWidget);
    expect(windows.mode, WindowMode.quickAdd);

    await windows.cancelQuickAdd();
    await tester.pumpAndSettle();
    expect(find.byType(CompactWorkspace), findsOneWidget);
    expect(windows.mode, WindowMode.compact);
  });

  testWidgets('QuickAdd input is focused and Escape restores the mode', (
    tester,
  ) async {
    final workspace = WorkspaceController();
    final windows = WindowController(
      desktopService: FakeDesktopWindowService(),
    );
    final quickAdd = QuickAddController(windowController: windows);
    addTearDown(() {
      quickAdd.dispose();
      windows.dispose();
      workspace.dispose();
    });
    await tester.pumpWidget(
      LiteTodoApp(
        controller: workspace,
        windowController: windows,
        quickAddController: quickAdd,
      ),
    );
    await tester.pumpAndSettle();
    await windows.openQuickAdd();
    await tester.pumpAndSettle();

    expect(
      tester.binding.focusManager.primaryFocus?.debugLabel,
      'quick-add-input',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(windows.mode, WindowMode.full);
    expect(find.byType(QuickAddView), findsNothing);
  });
}
