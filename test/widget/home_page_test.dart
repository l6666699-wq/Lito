import 'package:flutter/widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:litetodo/application/workspace_controller.dart';
import 'package:litetodo/domain/models/app_data.dart';
import 'package:litetodo/infrastructure/persistence/app_data_repository.dart';
import 'package:litetodo/presentation/home/home_page.dart';

class _EmptyRepository implements AppDataRepository {
  AppData saved = AppData.empty();

  @override
  Future<AppDataLoadResult> load() async => AppDataLoadResult(
    data: AppData.empty(),
    source: AppDataLoadSource.primary,
  );

  @override
  Future<void> save(AppData snapshot) async {
    saved = snapshot;
  }
}

void main() {
  Future<void> pumpHome(
    WidgetTester tester,
    WorkspaceController controller, {
    Size size = const Size(1405, 879),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ShadApp(home: HomePage(controller: controller)));
    await tester.pumpAndSettle();
  }

  Future<TestGesture> hoverRow(WidgetTester tester, String todoId) async {
    final row = find.byKey(ValueKey<String>('todo-row-$todoId'));
    await tester.ensureVisible(row);
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.moveTo(tester.getCenter(row));
    await tester.pump();
    return gesture;
  }

  testWidgets('renders the real scope and visible tree rows', (tester) async {
    final controller = WorkspaceController();
    await pumpHome(tester, controller);

    expect(
      find.byKey(const ValueKey<String>('home-content-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('todo-list-builder')),
      findsOneWidget,
    );
    expect(find.text('所有待办'), findsWidgets);
    expect(find.textContaining('50 条 Todo'), findsOneWidget);

    controller.selectInbox();
    await tester.pump();
    expect(controller.scope, WorkspaceScope.inbox);
    expect(
      find.byKey(const ValueKey<String>('todo-list-builder')),
      findsOneWidget,
    );
  });

  testWidgets('wide header keeps scopes and actions in one row', (
    tester,
  ) async {
    final controller = WorkspaceController();
    await pumpHome(tester, controller, size: const Size(1672, 941));

    final header = find.byKey(const ValueKey<String>('home-header-row'));
    final scopes = tester.getRect(
      find.byKey(const ValueKey<String>('home-header-scopes')),
    );
    final actions = tester.getRect(
      find.byKey(const ValueKey<String>('home-header-actions')),
    );
    final firstRow = tester.getRect(
      find.byKey(ValueKey<String>('todo-row-${controller.todos.first.id}')),
    );

    expect(header, findsOneWidget);
    expect((scopes.center.dy - actions.center.dy).abs(), lessThanOrEqualTo(1));
    expect(firstRow.top, lessThan(170));
    expect(find.byKey(const ValueKey<String>('home-add-todo')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('medium header retains the top add composer trigger', (
    tester,
  ) async {
    final controller = WorkspaceController();
    await pumpHome(tester, controller, size: const Size(860, 620));

    final add = find.byKey(const ValueKey<String>('home-add-todo'));
    expect(add, findsOneWidget);
    await tester.tap(add);
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('todo-inline-composer')),
      findsOneWidget,
    );
  });

  testWidgets('parent collapse and completion propagate to descendants', (
    tester,
  ) async {
    final controller = WorkspaceController();
    await pumpHome(tester, controller);
    final rootId = controller.todos.first.id;
    final childId = controller.todos[1].id;
    controller.setTodoCompleted(rootId, false);
    final nested = controller.createChildTodo('二级测试任务', parentId: childId);
    expect(nested.parentId, childId);
    await tester.pump();

    await tester.tap(find.byKey(ValueKey<String>('todo-collapse-$rootId')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      controller.visibleRows.any((row) => row.todo.id == childId),
      isFalse,
    );

    await tester.tap(find.byKey(ValueKey<String>('todo-collapse-$rootId')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(ValueKey<String>('todo-collapse-$childId')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      controller.visibleRows.any((row) => row.todo.id == nested.id),
      isFalse,
    );
    await tester.tap(find.byKey(ValueKey<String>('todo-collapse-$childId')));
    await tester.pump(const Duration(milliseconds: 100));
    controller.setTodoCompleted(rootId, true);
    await tester.pump();
    expect(
      controller.todos
          .where((todo) => todo.parentId == rootId)
          .every((todo) => todo.completed),
      isTrue,
    );
  });

  testWidgets('checkbox listener toggles a real Todo row', (tester) async {
    final controller = WorkspaceController();
    await pumpHome(tester, controller);
    final child = controller.todos[1];
    expect(child.completed, isFalse);
    await tester.tap(find.byKey(ValueKey<String>('todo-toggle-${child.id}')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      controller.todos.firstWhere((todo) => todo.id == child.id).completed,
      isTrue,
    );
  });

  testWidgets('hover actions edit and add child through controller mutations', (
    tester,
  ) async {
    final controller = WorkspaceController();
    await pumpHome(tester, controller);
    final root = controller.todos.first;

    final rootHover = await hoverRow(tester, root.id);
    await tester.tap(
      find.byKey(ValueKey<String>('todo-action-${root.id}-编辑任务')),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(EditableText).last, '首页编辑任务');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(controller.todos.first.title, '首页编辑任务');
    await tester.pump(const Duration(milliseconds: 100));

    await rootHover.removePointer();
    final addHover = await hoverRow(tester, root.id);
    await tester.tap(
      find.byKey(ValueKey<String>('todo-action-${root.id}-添加子任务')),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await addHover.removePointer();
    expect(
      find.byKey(const ValueKey<String>('todo-inline-composer')),
      findsOneWidget,
    );
    await tester.enterText(find.byType(EditableText).last, '新增子任务');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(
      controller.todos.any(
        (todo) => todo.title == '新增子任务' && todo.parentId == root.id,
      ),
      isTrue,
    );
    await rootHover.removePointer();
  });

  testWidgets('archive and delete update visible rows and trash', (
    tester,
  ) async {
    final controller = WorkspaceController();
    await pumpHome(tester, controller);
    final targetId = controller.todos.first.id;
    final targetHover = await hoverRow(tester, targetId);
    await tester.tap(
      find.byKey(ValueKey<String>('todo-action-$targetId-归档任务')),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.todos.first.archived, isTrue);
    expect(
      controller.visibleRows.any((row) => row.todo.id == targetId),
      isFalse,
    );

    await targetHover.removePointer();
    final deleteId = controller.todos.firstWhere((todo) => !todo.archived).id;
    final deleteHover = await hoverRow(tester, deleteId);
    await tester.tap(
      find.byKey(ValueKey<String>('todo-action-$deleteId-移入回收站')),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.trash, isNotEmpty);
    expect(controller.todos.any((todo) => todo.id == deleteId), isFalse);
    await deleteHover.removePointer();
  });

  testWidgets('empty state and desktop reference sizes stay exception-free', (
    tester,
  ) async {
    final controller = WorkspaceController();
    await pumpHome(tester, controller, size: const Size(860, 620));
    for (final root
        in controller.todos.where((todo) => todo.parentId == null).toList()) {
      controller.deleteTodo(root.id);
    }
    await tester.pump();
    expect(find.text('没有可见待办'), findsOneWidget);

    for (final size in const <Size>[
      Size(1672, 941),
      Size(860, 620),
      Size(680, 460),
    ]) {
      await pumpHome(tester, WorkspaceController(), size: size);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('empty workspace can create its first root Todo', (tester) async {
    final repository = _EmptyRepository();
    final controller = WorkspaceController(repository: repository);
    await controller.initialize();
    await pumpHome(tester, controller, size: const Size(860, 620));

    await tester.tap(find.byKey(const ValueKey<String>('home-add-todo')));
    await tester.pump();
    await tester.enterText(find.byType(EditableText).last, 'first root');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(controller.todos.map((todo) => todo.title), <String>['first root']);
    expect(repository.saved.todos.single.title, 'first root');
    expect(
      find.byKey(const ValueKey<String>('todo-inline-composer')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
