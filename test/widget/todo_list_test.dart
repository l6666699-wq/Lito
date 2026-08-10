import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:litetodo/application/workspace_controller.dart';
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
}
