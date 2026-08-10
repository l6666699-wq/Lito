import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:litetodo/app/litetodo_app.dart';
import 'package:litetodo/application/app_navigation_controller.dart';
import 'package:litetodo/application/quick_add_controller.dart';
import 'package:litetodo/application/window_controller.dart';
import 'package:litetodo/application/workspace_controller.dart';
import 'package:litetodo/infrastructure/platform/desktop_window_service.dart';
import 'package:litetodo/presentation/trash/trash_page.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  Future<void> pumpTrash(
    WidgetTester tester,
    WorkspaceController controller, {
    Size size = const Size(860, 620),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ShadApp(home: TrashPage(controller: controller)));
    await tester.pumpAndSettle();
  }

  testWidgets('renders empty state and restores a Todo subtree', (
    tester,
  ) async {
    final controller = WorkspaceController();
    await pumpTrash(tester, controller);
    expect(find.text('回收站是空的'), findsOneWidget);

    final root = controller.todos.first;
    final child = controller.todos[1];
    controller.deleteTodo(root.id);
    await tester.pump();
    expect(find.text(root.title), findsOneWidget);
    expect(find.text('Todo 子树'), findsOneWidget);
    expect(find.text('原项目：收集箱'), findsOneWidget);
    expect(find.textContaining('删除于'), findsOneWidget);

    await tester.tap(
      find.byKey(
        ValueKey<String>('trash-restore-${controller.trash.single.id}'),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.trash, isEmpty);
    expect(controller.todos.any((todo) => todo.id == root.id), isTrue);
    expect(controller.todos.any((todo) => todo.id == child.id), isTrue);
  });

  testWidgets('clear requires confirmation and supports cancel/confirm', (
    tester,
  ) async {
    final controller = WorkspaceController();
    controller.deleteTodo(controller.todos.first.id);
    await pumpTrash(tester, controller);

    await tester.tap(find.byKey(const ValueKey<String>('trash-clear-button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('trash-clear-confirm-dialog')),
      findsOneWidget,
    );
    expect(find.textContaining('本次运行期间可使用 Ctrl+Z 撤销'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('trash-clear-cancel')));
    await tester.pumpAndSettle();
    expect(controller.trash, isNotEmpty);

    await tester.tap(find.byKey(const ValueKey<String>('trash-clear-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('trash-clear-confirm')));
    await tester.pumpAndSettle();
    expect(controller.trash, isEmpty);
    expect(find.text('回收站是空的'), findsOneWidget);
  });

  testWidgets('renders and restores a deleted project subtree', (tester) async {
    final controller = WorkspaceController();
    final project = controller.projects.first;
    controller.deleteProject(project.id);
    await pumpTrash(tester, controller);

    expect(find.text(project.name), findsOneWidget);
    expect(find.text('项目'), findsOneWidget);
    expect(find.text('原项目：${project.name}'), findsOneWidget);
    final trashId = controller.trash.single.id;
    await tester.tap(find.byKey(ValueKey<String>('trash-restore-$trashId')));
    await tester.pumpAndSettle();
    expect(controller.trash, isEmpty);
    expect(controller.projects.any((entry) => entry.id == project.id), isTrue);
  });

  testWidgets('sidebar exposes trash count and route', (tester) async {
    final controller = WorkspaceController();
    final windows = WindowController(
      desktopService: FakeDesktopWindowService(),
    );
    final navigation = AppNavigationController();
    controller.deleteTodo(controller.todos.first.id);
    await tester.pumpWidget(
      LiteTodoApp(
        controller: controller,
        windowController: windows,
        quickAddController: QuickAddController(windowController: windows),
        navigationController: navigation,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('scope-回收站')), findsOneWidget);
    expect(find.text('1'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey<String>('scope-回收站')));
    await tester.pumpAndSettle();
    expect(navigation.page, AppPage.trash);
    expect(find.text('回收站'), findsWidgets);
    expect(
      find.byKey(ValueKey<String>('trash-item-${controller.trash.single.id}')),
      findsOneWidget,
    );
  });

  testWidgets('trash entries use a lazy sliver and remain scrollable', (
    tester,
  ) async {
    final controller = WorkspaceController();
    for (var index = 0; index < 80; index++) {
      final todo = controller.createRootTodo('回收测试 $index');
      controller.deleteTodo(todo.id);
    }
    await pumpTrash(tester, controller, size: const Size(680, 460));
    expect(controller.trash, hasLength(80));
    expect(
      find.byKey(const ValueKey<String>('trash-list-builder')),
      findsOneWidget,
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  for (final size in const <Size>[
    Size(1672, 941),
    Size(860, 620),
    Size(680, 460),
  ]) {
    testWidgets('trash route fits ${size.width}x${size.height}', (
      tester,
    ) async {
      final controller = WorkspaceController();
      controller.deleteTodo(controller.todos.first.id);
      await pumpTrash(tester, controller, size: size);
      expect(tester.takeException(), isNull);
    });
  }
}
