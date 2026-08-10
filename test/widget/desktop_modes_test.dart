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
import 'package:litetodo/presentation/full/full_workspace.dart';
import 'package:litetodo/presentation/quick_add/quick_add_view.dart';

void main() {
  testWidgets('Full, Compact and QuickAdd share one controller and ShadApp', (
    tester,
  ) async {
    final windows = WindowController(
      desktopService: FakeDesktopWindowService(),
    );
    final quickAdd = QuickAddController(windowController: windows);
    await tester.pumpWidget(
      LiteTodoApp(
        controller: WorkspaceController(),
        windowController: windows,
        quickAddController: quickAdd,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ShadApp), findsOneWidget);
    expect(find.byType(FullWorkspace), findsOneWidget);
    expect(find.byType(ShadApp), findsOneWidget);

    await windows.switchMode(WindowMode.compact);
    await tester.pumpAndSettle();
    expect(find.byType(CompactWorkspace), findsOneWidget);
    expect(find.byType(FullWorkspace), findsNothing);

    await windows.openQuickAdd();
    await tester.pumpAndSettle();
    expect(find.byType(QuickAddView), findsOneWidget);
    expect(find.byType(EditableText), findsOneWidget);

    await windows.cancelQuickAdd();
    await tester.pumpAndSettle();
    expect(find.byType(CompactWorkspace), findsOneWidget);
  });

  testWidgets('QuickAdd input is focused and Escape restores the mode', (
    tester,
  ) async {
    final windows = WindowController(
      desktopService: FakeDesktopWindowService(),
    );
    await tester.pumpWidget(
      LiteTodoApp(
        controller: WorkspaceController(),
        windowController: windows,
        quickAddController: QuickAddController(windowController: windows),
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
