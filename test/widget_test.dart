import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:litetodo/app/litetodo_app.dart';
import 'package:litetodo/app/theme/app_colors.dart';
import 'package:litetodo/application/workspace_controller.dart';
import 'package:litetodo/presentation/todo/todo_row.dart';

void main() {
  testWidgets('root uses ShadApp and renders a lazy Todo list', (tester) async {
    final controller = WorkspaceController();
    await tester.pumpWidget(LiteTodoApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.byType(ShadApp), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('todo-list-builder')),
      findsOneWidget,
    );
    expect(find.byType(ListView), findsOneWidget);
    expect(find.textContaining('counter'), findsNothing);
    expect(find.text('50 条 Todo'), findsWidgets);
  });

  testWidgets('dataset control switches the controller to 1000 rows', (
    tester,
  ) async {
    final controller = WorkspaceController();
    await tester.pumpWidget(LiteTodoApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('1000 条 Todo').first);
    await tester.pumpAndSettle();

    expect(controller.todos, hasLength(1000));
    expect(find.text('1000 条 Todo'), findsWidgets);
    expect(find.textContaining('可见'), findsOneWidget);
  });

  testWidgets('dark platform brightness paints the shell with dark canvas', (
    tester,
  ) async {
    final controller = WorkspaceController();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(platformBrightness: Brightness.dark),
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
    await tester.pumpWidget(LiteTodoApp(controller: controller));
    await tester.pumpAndSettle();

    expect(controller.visibleRows, hasLength(100));
    final builtRowCount = tester
        .widgetList<TodoRow>(find.byType(TodoRow))
        .length;
    expect(builtRowCount, lessThan(100));
    expect(builtRowCount, lessThan(controller.visibleRows.length));
  });
}
