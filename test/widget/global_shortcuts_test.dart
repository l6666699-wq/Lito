import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:litetodo/app/theme/app_theme.dart';
import 'package:litetodo/application/app_navigation_controller.dart';
import 'package:litetodo/application/window_controller.dart';
import 'package:litetodo/application/workspace_controller.dart';
import 'package:litetodo/infrastructure/platform/desktop_window_service.dart';
import 'package:litetodo/presentation/shell/full_app_shell.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('shell routes search, undo and redo shortcuts', (tester) async {
    final window = WindowController(
      desktopService: FakeDesktopWindowService(),
      registerHotkeyOnInitialize: false,
    );
    await window.initialize();
    final workspace = WorkspaceController();
    final navigation = AppNavigationController();
    addTearDown(() {
      window.dispose();
      workspace.dispose();
      navigation.dispose();
    });

    await tester.binding.setSurfaceSize(const Size(1200, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ShadApp(
        theme: AppTheme.lightFor(),
        home: FullAppShell(
          controller: workspace,
          windowController: window,
          navigationController: navigation,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final groupKey = ValueKey<String>(
      'project-group-${workspace.groups.first.id}',
    );
    await tester.tap(find.byKey(groupKey));
    await _sendControlShortcut(tester, LogicalKeyboardKey.keyF);
    final search = tester.widget<EditableText>(
      find.byKey(const ValueKey<String>('shell-search-field')),
    );
    expect(search.focusNode.hasFocus, isTrue);

    final todo = workspace.createRootTodo('shortcut undo target');
    await tester.pump();
    await tester.tap(find.byKey(groupKey));
    await tester.pump();
    await _sendControlShortcut(tester, LogicalKeyboardKey.keyZ);
    expect(workspace.todos.any((item) => item.id == todo.id), isFalse);
    await _sendControlShortcut(tester, LogicalKeyboardKey.keyZ, shift: true);
    expect(workspace.todos.any((item) => item.id == todo.id), isTrue);

    await tester.tap(find.byKey(const ValueKey<String>('shell-search-field')));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.enterText(
      find.byKey(const ValueKey<String>('shell-search-field')),
      'keep editing local',
    );
    final editableController = tester
        .widget<EditableText>(
          find.byKey(const ValueKey<String>('shell-search-field')),
        )
        .controller;
    expect(editableController.text, 'keep editing local');
    await tester.pump(const Duration(milliseconds: 600));
    await _sendControlShortcut(tester, LogicalKeyboardKey.keyZ);
    expect(editableController.text, isEmpty);
    expect(workspace.todos.any((item) => item.id == todo.id), isTrue);
    await _sendControlShortcut(tester, LogicalKeyboardKey.keyZ, shift: true);
    expect(editableController.text, 'keep editing local');
    expect(workspace.todos.any((item) => item.id == todo.id), isTrue);
  });
}

Future<void> _sendControlShortcut(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool shift = false,
}) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
  await tester.sendKeyEvent(key);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
  await tester.pump();
}
