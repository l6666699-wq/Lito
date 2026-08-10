import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

import 'package:litetodo/app/litetodo_app.dart';
import 'package:litetodo/application/app_navigation_controller.dart';
import 'package:litetodo/application/quick_add_controller.dart';
import 'package:litetodo/application/window_controller.dart';
import 'package:litetodo/application/workspace_controller.dart';
import 'package:litetodo/infrastructure/platform/desktop_window_service.dart';

void main() {
  testWidgets('full shell routes and preserves page across Quick Add', (
    tester,
  ) async {
    final windows = WindowController(
      desktopService: FakeDesktopWindowService(),
    );
    final navigation = AppNavigationController();
    final workspace = WorkspaceController();
    await tester.pumpWidget(
      LiteTodoApp(
        controller: workspace,
        windowController: windows,
        quickAddController: QuickAddController(windowController: windows),
        navigationController: navigation,
      ),
    );
    await tester.pumpAndSettle();

    expect(navigation.page, AppPage.home);
    final firstGroup = workspace.groups.first;
    final firstProject = workspace.projects.firstWhere(
      (project) => project.groupId == firstGroup.id,
    );
    await tester.tap(
      find.byKey(ValueKey<String>('project-group-${firstGroup.id}')),
    );
    await tester.pump();
    expect(
      find.byKey(ValueKey<String>('project-${firstProject.id}')),
      findsNothing,
    );
    await tester.tap(
      find.byKey(ValueKey<String>('project-group-${firstGroup.id}')),
    );
    await tester.pump();
    expect(
      find.byKey(ValueKey<String>('project-${firstProject.id}')),
      findsOneWidget,
    );

    final archivedGroup = workspace.createGroup(name: 'Archived group');
    final archivedProject = workspace.createProject(
      name: 'Archived project',
      groupId: archivedGroup.id,
    );
    workspace.archiveGroup(archivedGroup.id);
    await tester.pump();
    expect(
      find.byKey(ValueKey<String>('project-${archivedProject.id}')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(ValueKey<String>('project-group-${firstGroup.id}')),
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    expect(
      FocusManager.instance.primaryFocus?.debugLabel,
      'shell-search-input',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('shell-search-field')),
      'Focus',
    );
    expect(workspace.scope, WorkspaceScope.search);
    expect(workspace.searchQuery, 'Focus');

    navigation.goStatistics();
    await tester.pump();
    expect(find.text('统计'), findsWidgets);
    await windows.openQuickAdd();
    await tester.pump();
    await windows.cancelQuickAdd();
    await tester.pump();
    expect(navigation.page, AppPage.statistics);
  });

  for (final size in const <Size>[
    Size(1672, 941),
    Size(860, 620),
    Size(680, 460),
  ]) {
    testWidgets('full shell fits ${size.width}x${size.height}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(LiteTodoApp(controller: WorkspaceController()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
