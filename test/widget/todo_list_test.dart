import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:litetodo/app/theme/app_metrics.dart';
import 'package:litetodo/application/workspace_controller.dart';
import 'package:litetodo/domain/models/todo_item.dart';
import 'package:litetodo/presentation/todo/todo_list.dart';

void main() {
  testWidgets('TodoList keeps lazy builder and renders a real parent row', (
    tester,
  ) async {
    final controller = WorkspaceController();
    await tester.pumpWidget(
      ShadApp(
        home: SizedBox(
          width: 860,
          height: 620,
          child: TodoList(controller: controller, rows: controller.visibleRows),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('todo-list-builder')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('todo-row-todo-0')),
      findsOneWidget,
    );
    expect(find.byType(ListView), findsOneWidget);
  });

  testWidgets('composer is available for a child and receives the title', (
    tester,
  ) async {
    final controller = WorkspaceController();
    String? submitted;
    await tester.pumpWidget(
      ShadApp(
        home: SizedBox(
          width: 680,
          height: 460,
          child: TodoList(
            controller: controller,
            rows: controller.visibleRows,
            composerVisible: true,
            composerParentId: controller.todos.first.id,
            onComposerSubmit: (title) => submitted = title,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('todo-inline-composer')),
      findsOneWidget,
    );
    await tester.enterText(find.byType(EditableText).first, '子任务标题');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(submitted, '子任务标题');
  });

  testWidgets('todo rows keep horizontal inset while editing', (tester) async {
    final controller = WorkspaceController();
    final rowKey = ValueKey<String>(
      'todo-row-${controller.visibleRows.first.todo.id}',
    );
    await tester.pumpWidget(
      ShadApp(
        home: SizedBox(
          width: 860,
          height: 620,
          child: TodoList(controller: controller, rows: controller.visibleRows),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rowFinder = find.byKey(rowKey);
    final rowContainerFinder = find.descendant(
      of: rowFinder,
      matching: find.byWidgetPredicate(
        (widget) => widget is Container && widget.margin is EdgeInsets,
      ),
    );
    EdgeInsets rowMargin() =>
        tester.widget<Container>(rowContainerFinder).margin! as EdgeInsets;

    expect(rowContainerFinder, findsOneWidget);
    expect(rowMargin().left, AppMetrics.unit * 2);
    expect(rowMargin().right, AppMetrics.unit * 2);

    await tester.tap(rowFinder);
    await tester.sendKeyEvent(LogicalKeyboardKey.f2);
    await tester.pumpAndSettle();

    expect(rowMargin().left, AppMetrics.unit * 2);
    expect(rowMargin().right, AppMetrics.unit * 2);
  });

  testWidgets('composer stores priority and selected project in its draft', (
    tester,
  ) async {
    final controller = WorkspaceController();
    TodoComposerDraft? submitted;
    final project = controller.projects.first;
    await tester.pumpWidget(
      ShadApp(
        home: SizedBox(
          width: 860,
          height: 620,
          child: TodoList(
            controller: controller,
            rows: controller.visibleRows,
            composerVisible: true,
            onComposerSubmitDraft: (draft) => submitted = draft,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('todo-inline-composer-input')),
      '带优先级任务',
    );
    await tester.tap(find.bySemanticsLabel('优先级'));
    await tester.pump();
    await tester.tap(find.text('高优先级'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('收集箱'));
    await tester.pump();
    await tester.tap(find.text(project.name));
    await tester.pump();
    await tester.tap(find.text('添加'));
    await tester.pump();

    expect(submitted?.title, '带优先级任务');
    expect(submitted?.priority, TodoPriority.high);
    expect(submitted?.projectId, project.id);
  });
}
