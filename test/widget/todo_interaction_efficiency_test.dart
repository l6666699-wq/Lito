import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:litetodo/application/workspace_controller.dart';
import 'package:litetodo/presentation/home/home_page.dart';
import 'package:litetodo/presentation/todo/todo_list.dart';

void main() {
  Future<void> pumpList(
    WidgetTester tester,
    WorkspaceController controller, {
    ValueChanged<String>? onComposerSubmit,
    VoidCallback? onComposerCancel,
    ValueChanged<String>? onRequestAddChild,
    ValueChanged<String?>? onRequestAddSibling,
    bool composerVisible = false,
    String? composerParentId,
  }) async {
    await tester.pumpWidget(
      ShadApp(
        home: SizedBox(
          width: 860,
          height: 620,
          child: TodoList(
            controller: controller,
            rows: controller.visibleRows,
            composerVisible: composerVisible,
            composerParentId: composerParentId,
            onComposerSubmit: onComposerSubmit,
            onComposerCancel: onComposerCancel,
            onRequestAddChild: onRequestAddChild,
            onRequestAddSibling: onRequestAddSibling,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'keyboard edits, creates sibling/child and deletes selected Todo',
    (tester) async {
      final controller = WorkspaceController();
      await tester.binding.setSurfaceSize(const Size(860, 620));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(ShadApp(home: HomePage(controller: controller)));
      await tester.pumpAndSettle();

      final childId = controller.todos[1].id;
      final childRow = find.byKey(ValueKey<String>('todo-row-$childId'));
      await tester.ensureVisible(childRow);
      await tester.tap(childRow);
      await tester.sendKeyEvent(LogicalKeyboardKey.f2);
      await tester.pump();
      expect(find.byType(EditableText), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'keyboard edited');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(
        controller.todos.firstWhere((todo) => todo.id == childId).title,
        'keyboard edited',
      );

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('todo-inline-composer')),
        findsOneWidget,
      );
      await tester.enterText(find.byType(EditableText), 'keyboard child');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(
        controller.todos.any(
          (todo) => todo.title == 'keyboard child' && todo.parentId == childId,
        ),
        isTrue,
      );

      final childRowAfterComposer = find.byKey(
        ValueKey<String>('todo-row-$childId'),
      );
      await tester.ensureVisible(childRowAfterComposer);
      await tester.tap(childRowAfterComposer);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('todo-inline-composer')),
        findsOneWidget,
      );
      await tester.enterText(find.byType(EditableText), 'keyboard sibling');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(
        controller.todos.any(
          (todo) =>
              todo.title == 'keyboard sibling' &&
              todo.parentId ==
                  controller.todos
                      .firstWhere((item) => item.id == childId)
                      .parentId,
        ),
        isTrue,
      );

      final sibling = controller.todos.firstWhere(
        (todo) => todo.title == 'keyboard sibling',
      );
      final siblingRow = find.byKey(ValueKey<String>('todo-row-${sibling.id}'));
      await tester.ensureVisible(siblingRow);
      await tester.tap(siblingRow);
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pump();
      expect(
        controller.trash.any((item) => item.kind == 'todo_subtree'),
        isTrue,
      );
      expect(controller.todos.any((todo) => todo.id == sibling.id), isFalse);
      await tester.pumpAndSettle();
    },
  );

  testWidgets('Tab and Shift+Tab use tree move semantics', (tester) async {
    final controller = WorkspaceController();
    final extra = controller.createRootTodo('keyboard move root');
    await pumpList(tester, controller);
    final previousRoot = controller.visibleRows.reversed.firstWhere(
      (row) =>
          row.todo.parentId == null &&
          row.todo.id != extra.id &&
          row.todo.projectId == extra.projectId,
    );
    await tester.scrollUntilVisible(
      find.byKey(ValueKey<String>('todo-row-${extra.id}')),
      120,
    );
    await tester.tap(find.byKey(ValueKey<String>('todo-row-${extra.id}')));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      controller.todos.firstWhere((todo) => todo.id == extra.id).parentId,
      previousRoot.todo.id,
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(
      controller.todos.firstWhere((todo) => todo.id == extra.id).parentId,
      isNull,
    );
    await tester.pumpAndSettle();
  });

  testWidgets('mouse drag handle moves before target and leaves indicator', (
    tester,
  ) async {
    final controller = WorkspaceController();
    await pumpList(tester, controller);
    const movingId = 'todo-2';
    const targetId = 'todo-1';
    final movingHandle = find.byKey(
      const ValueKey<String>('todo-drag-handle-$movingId'),
    );
    final targetRow = find.byKey(const ValueKey<String>('todo-row-$targetId'));
    expect(movingHandle, findsOneWidget);
    expect(targetRow, findsOneWidget);
    final targetRect = tester.getRect(targetRow);
    final gesture = await tester.startGesture(
      tester.getCenter(movingHandle),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveTo(targetRect.topCenter + const Offset(0, 8));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    final moving = controller.todos.firstWhere((todo) => todo.id == movingId);
    final target = controller.todos.firstWhere((todo) => todo.id == targetId);
    expect(moving.parentId, target.parentId);
    expect(moving.sortOrder, lessThan(target.sortOrder));
  });
}
