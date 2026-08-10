import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:litetodo/app/litetodo_app.dart';
import 'package:litetodo/app/theme/app_colors.dart';
import 'package:litetodo/application/workspace_controller.dart';
import 'package:litetodo/presentation/home/home_page.dart';
import 'package:litetodo/presentation/shell/full_app_shell.dart';
import 'package:litetodo/presentation/todo/todo_row.dart';

void main() {
  testWidgets('root uses ShadApp and renders a lazy Todo list', (tester) async {
    final controller = WorkspaceController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(LiteTodoApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.byType(ShadApp), findsOneWidget);
    expect(find.byType(FullAppShell), findsOneWidget);
    expect(find.byType(HomePage), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('home-content-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('todo-list-builder')),
      findsOneWidget,
    );
    expect(
      tester.widget<ListView>(
        find.byKey(const ValueKey<String>('todo-list-builder')),
      ),
      isA<ListView>(),
    );
    expect(find.textContaining('counter'), findsNothing);
    expect(controller.todos, hasLength(50));
    expect(find.text('50 项任务'), findsOneWidget);
  });

  testWidgets('controller dataset switch updates the real Home route', (
    tester,
  ) async {
    final controller = WorkspaceController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(LiteTodoApp(controller: controller));
    await tester.pumpAndSettle();

    controller.switchDataset(TodoDataset.thousand);
    await tester.pump();

    expect(controller.todos, hasLength(1000));
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('1000 项任务'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('todo-list-builder')),
      findsOneWidget,
    );
  });

  testWidgets('Home route composer creates a real Todo', (tester) async {
    final controller = WorkspaceController();
    addTearDown(controller.dispose);
    await tester.binding.setSurfaceSize(const Size(1405, 879));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(LiteTodoApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('home-add-todo')));
    await tester.pump();
    final composer = find.byKey(const ValueKey<String>('todo-inline-composer'));
    expect(composer, findsOneWidget);
    final editor = find.descendant(
      of: composer,
      matching: find.byType(EditableText),
    );
    await tester.enterText(editor, '首页新增任务');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    final added = controller.todos.singleWhere(
      (todo) => todo.title == '首页新增任务',
    );
    expect(added.title, '首页新增任务');
    final addedRow = find.byKey(ValueKey<String>('todo-row-${added.id}'));
    await tester.scrollUntilVisible(
      addedRow,
      240,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey<String>('todo-list-builder')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('首页新增任务'), findsOneWidget);
  });

  testWidgets('dark platform brightness paints the shell with dark canvas', (
    tester,
  ) async {
    final controller = WorkspaceController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(860, 620),
          platformBrightness: Brightness.dark,
        ),
        child: LiteTodoApp(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    final shell = tester.widget<ColoredBox>(
      find.byKey(const ValueKey<String>('app-shell-canvas')),
    );
    expect(shell.color, AppColors.darkScheme.canvas);
    expect(shell.color, isNot(AppColors.lightScheme.canvas));
  });

  testWidgets('1000 rows remain lazy while one hundred rows are visible', (
    tester,
  ) async {
    final controller = WorkspaceController(
      initialDataset: TodoDataset.thousand,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(LiteTodoApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.byType(FullAppShell), findsOneWidget);
    expect(find.byType(HomePage), findsOneWidget);
    expect(controller.visibleRows, hasLength(100));
    final builtRowCount = tester
        .widgetList<TodoRow>(find.byType(TodoRow))
        .length;
    expect(builtRowCount, lessThan(100));
    expect(builtRowCount, lessThan(controller.visibleRows.length));
  });
}
