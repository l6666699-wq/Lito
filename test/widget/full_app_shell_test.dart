import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:litetodo/app/litetodo_app.dart';
import 'package:litetodo/application/app_navigation_controller.dart';
import 'package:litetodo/application/quick_add_controller.dart';
import 'package:litetodo/application/settings_controller.dart';
import 'package:litetodo/application/sticky_notes_controller.dart';
import 'package:litetodo/application/window_controller.dart';
import 'package:litetodo/application/workspace_controller.dart';
import 'package:litetodo/app/theme/app_colors.dart';
import 'package:litetodo/app/theme/app_metrics.dart';
import 'package:litetodo/app/theme/app_motion.dart';
import 'package:litetodo/domain/models/app_settings.dart';
import 'package:litetodo/infrastructure/platform/desktop_window_service.dart';
import 'package:litetodo/infrastructure/platform/sticky_notes_window_service.dart';
import 'package:litetodo/icons/app_icons.dart';
import 'package:litetodo/icons/project_icon.dart';
import 'package:litetodo/app/theme/project_palette.dart';
import 'package:litetodo/presentation/settings/settings_scope.dart';

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

  testWidgets('topbar add task opens the inline composer in full mode', (
    tester,
  ) async {
    final workspace = WorkspaceController();
    final windows = WindowController(
      desktopService: FakeDesktopWindowService(),
    );
    final navigation = AppNavigationController(initialPage: AppPage.statistics);
    addTearDown(() {
      windows.dispose();
      workspace.dispose();
      navigation.dispose();
    });

    await tester.pumpWidget(
      LiteTodoApp(
        controller: workspace,
        windowController: windows,
        navigationController: navigation,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('统计'), findsWidgets);

    await tester.tap(
      find.byKey(const ValueKey<String>('shell-add-task-button')),
    );
    await tester.pump();

    expect(navigation.page, AppPage.home);
    expect(windows.mode, WindowMode.full);
    expect(
      find.byKey(const ValueKey<String>('todo-inline-composer')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byType(EditableText).last,
      'topbar-created-task',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(
      workspace.todos.any((todo) => todo.title == 'topbar-created-task'),
      isTrue,
    );
    expect(windows.mode, WindowMode.full);
  });

  testWidgets('topbar add task in a project keeps the project owner', (
    tester,
  ) async {
    final workspace = WorkspaceController();
    final project = workspace.projects.first;
    final navigation = AppNavigationController();
    addTearDown(() {
      workspace.dispose();
      navigation.dispose();
    });

    await tester.pumpWidget(
      LiteTodoApp(controller: workspace, navigationController: navigation),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey<String>('project-${project.id}')));
    await tester.pump();
    expect(workspace.scope, WorkspaceScope.project);
    expect(workspace.projectScopeId, project.id);

    await tester.tap(
      find.byKey(const ValueKey<String>('shell-add-task-button')),
    );
    await tester.pump();
    await tester.enterText(
      find.byType(EditableText).last,
      'project-owned-task',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(
      workspace.todos.any(
        (todo) =>
            todo.title == 'project-owned-task' && todo.projectId == project.id,
      ),
      isTrue,
    );
  });

  testWidgets(
    'sticky-note entry opens inbox and project without selecting it',
    (tester) async {
      final workspace = WorkspaceController();
      final service = FakeStickyNotesWindowService();
      addTearDown(workspace.dispose);

      await tester.pumpWidget(
        LiteTodoApp(controller: workspace, stickyNotesWindowService: service),
      );
      await tester.pumpAndSettle();

      final project = workspace.projects.first;
      final projectFinder = find.byKey(
        ValueKey<String>('project-${project.id}'),
      );
      final stickyFinder = find.byKey(
        ValueKey<String>('project-sticky-${project.id}'),
      );
      final moreFinder = find.byKey(
        ValueKey<String>('project-more-${project.id}'),
      );
      final countFinder = find.descendant(
        of: projectFinder,
        matching: find.text(
          '${workspace.unfinishedCountForProject(project.id)}',
        ),
      );

      expect(projectFinder, findsOneWidget);
      expect(stickyFinder, findsOneWidget);
      expect(find.byIcon(AppIcons.stickyNotes), findsWidgets);
      expect(moreFinder, findsOneWidget);
      expect(countFinder, findsOneWidget);

      final stickyRect = tester.getRect(stickyFinder);
      final moreRect = tester.getRect(moreFinder);
      final countRect = tester.getRect(countFinder);
      final projectRect = tester.getRect(projectFinder);
      expect(stickyRect.width, closeTo(28, 1));
      expect(stickyRect.height, closeTo(28, 1));
      expect(
        stickyRect.left - countRect.right,
        greaterThanOrEqualTo(AppMetrics.unit * 2),
      );
      expect(
        moreRect.left - stickyRect.right,
        greaterThanOrEqualTo(AppMetrics.unit * 2),
      );
      expect(
        projectRect.right - moreRect.right,
        closeTo(AppMetrics.unit * 2, 1),
      );

      // The project row starts in the all-todos scope. Clicking the nested
      // sticky action must not bubble into the row selection handler.
      expect(workspace.scope, WorkspaceScope.all);
      expect(workspace.projectScopeId, isNull);
      await tester.tap(stickyFinder);
      await tester.pump();
      expect(workspace.scope, WorkspaceScope.all);
      expect(workspace.projectScopeId, isNull);
      expect(
        service.calls,
        contains(
          'open:${StickyNotesController.keyFor(project.id)}:${project.id}',
        ),
      );
      expect(
        service.openKeys,
        contains(StickyNotesController.keyFor(project.id)),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('shell-sticky-notes-button')),
      );
      await tester.pump();
      expect(
        service.calls,
        contains('open:${StickyNotesController.inboxKey}:'),
      );
      expect(service.openKeys, contains(StickyNotesController.inboxKey));
    },
  );

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
      expect(
        find.byKey(const ValueKey<String>('shell-statistics-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('shell-settings-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('shell-theme-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('shell-window-minimize-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('shell-window-maximize-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('shell-window-close-button')),
        findsOneWidget,
      );
      final topbarRect = tester.getRect(
        find.byKey(const ValueKey<String>('shell-topbar')),
      );
      const controlKeys = <String>[
        'shell-statistics-button',
        'shell-settings-button',
        'shell-theme-button',
        'shell-window-minimize-button',
        'shell-window-maximize-button',
        'shell-window-close-button',
      ];
      final controlRects = <String, Rect>{
        for (final key in controlKeys)
          key: tester.getRect(find.byKey(ValueKey<String>(key))),
      };
      for (final rect in controlRects.values) {
        expect(rect.left, greaterThanOrEqualTo(topbarRect.left));
        expect(rect.right, lessThanOrEqualTo(topbarRect.right));
      }
      expect(
        controlRects['shell-statistics-button']!.left,
        lessThan(controlRects['shell-settings-button']!.left),
      );
      expect(
        controlRects['shell-settings-button']!.left -
            controlRects['shell-statistics-button']!.right,
        closeTo(AppMetrics.unit * 2, 1),
      );
      expect(
        controlRects['shell-settings-button']!.left,
        lessThan(controlRects['shell-theme-button']!.left),
      );
      for (final key in controlKeys) {
        expect(
          find.descendant(
            of: find.byKey(ValueKey<String>(key)),
            matching: find.byType(ShadTooltip),
          ),
          findsNothing,
        );
      }
      if (size.width == 1672) {
        expect(
          controlRects['shell-window-close-button']!.right,
          closeTo(topbarRect.right - AppMetrics.unit * 3, 1),
        );
      }
      expect(find.byIcon(AppIcons.clock), findsNothing);
      expect(find.byIcon(AppIcons.notification), findsNothing);
    });
  }

  testWidgets('theme snapshot settles to dark canvas after motion token', (
    tester,
  ) async {
    final settings = SettingsController(
      repository: InMemorySettingsRepository(),
    );
    await settings.initialize();
    addTearDown(settings.dispose);
    final workspace = WorkspaceController();
    addTearDown(workspace.dispose);

    await tester.pumpWidget(
      LiteTodoApp(settingsController: settings, controller: workspace),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<ColoredBox>(
            find.byKey(const ValueKey<String>('app-shell-canvas')),
          )
          .color,
      AppColors.lightScheme.canvas,
    );
    expect(
      tester
          .widget<DecoratedBox>(
            find.byKey(const ValueKey<String>('shell-topbar')),
          )
          .decoration,
      isA<BoxDecoration>().having(
        (decoration) => decoration.color,
        'color',
        AppColors.lightScheme.surface,
      ),
    );

    final update = settings.setThemeMode(AppThemeMode.dark);
    await tester.pump();
    await tester.pump(AppMotion.theme);
    expect(
      tester
          .widget<ColoredBox>(
            find.byKey(const ValueKey<String>('app-shell-canvas')),
          )
          .color,
      AppColors.darkScheme.canvas,
    );
    expect(
      (tester
                  .widget<DecoratedBox>(
                    find.byKey(const ValueKey<String>('shell-topbar')),
                  )
                  .decoration
              as BoxDecoration)
          .color,
      AppColors.darkScheme.surface,
    );
    expect(await update, isTrue);
  });

  testWidgets(
    'sidebar scope states use theme accent while projects keep color',
    (tester) async {
      final workspace = WorkspaceController();
      final navigation = AppNavigationController();
      await tester.pumpWidget(
        LiteTodoApp(controller: workspace, navigationController: navigation),
      );
      await tester.pumpAndSettle();

      final scopeKey = const ValueKey<String>('scope-收集箱');
      final scopeFinder = find.byKey(scopeKey);
      workspace.selectInbox();
      await tester.pump();
      final scopeContainer = find
          .descendant(of: scopeFinder, matching: find.byType(Container))
          .last;
      final scopeContext = tester.element(scopeFinder);
      final colors = AppColors.of(scopeContext);
      final scopeDecoration =
          tester.widget<Container>(scopeContainer).decoration! as BoxDecoration;
      expect(scopeDecoration.color, colors.focusSoft);
      final scopeIcon = find
          .descendant(of: scopeFinder, matching: find.byType(Icon))
          .first;
      expect(tester.widget<Icon>(scopeIcon).color, colors.focus);

      final project = workspace.projects.first;
      workspace.selectProject(project.id);
      await tester.pump();
      final projectFinder = find.byKey(
        ValueKey<String>('project-${project.id}'),
      );
      final projectContainers = find
          .descendant(of: projectFinder, matching: find.byType(Container))
          .evaluate()
          .map((element) => element.widget)
          .whereType<Container>()
          .toList(growable: false);
      final projectDecoration = projectContainers
          .map((container) => container.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((decoration) => decoration.color != null);
      expect(
        projectDecoration.color,
        ProjectPalette.resolve(project.colorKey).softBackground,
      );
      final projectIcon = find
          .descendant(of: projectFinder, matching: find.byType(ProjectIcon))
          .first;
      expect(projectIcon, findsOneWidget);
    },
  );

  testWidgets('search field and shortcut chip share a centered text baseline', (
    tester,
  ) async {
    await tester.pumpWidget(LiteTodoApp(controller: WorkspaceController()));
    await tester.pumpAndSettle();

    final box = tester.getRect(
      find.byKey(const ValueKey<String>('shell-search-box')),
    );
    final input = tester.getRect(
      find.byKey(const ValueKey<String>('shell-search-field')),
    );
    final placeholder = tester.getRect(
      find.byKey(const ValueKey<String>('shell-search-placeholder')),
    );
    final searchIcon = tester.getRect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('shell-search-box')),
        matching: find.byIcon(AppIcons.search),
      ),
    );
    final shortcut = tester.getRect(
      find.byKey(const ValueKey<String>('shell-search-shortcut')),
    );
    expect(input.top, greaterThan(box.top));
    expect(input.bottom, lessThan(box.bottom));
    expect(input.height, closeTo(18, 1));
    expect(
      (input.center.dy - placeholder.center.dy).abs(),
      lessThanOrEqualTo(1),
    );
    expect((input.center.dy - box.center.dy).abs(), lessThanOrEqualTo(1));
    expect(
      (input.center.dy - searchIcon.center.dy).abs(),
      lessThanOrEqualTo(1),
    );
    expect(input.left, closeTo(placeholder.left, 1));
    expect(shortcut.height, closeTo(22, 1));
    expect(shortcut.left - input.right, greaterThanOrEqualTo(AppMetrics.unit));
  });

  testWidgets('typed search line stays centered and keeps the shortcut right', (
    tester,
  ) async {
    final workspace = WorkspaceController();
    addTearDown(workspace.dispose);
    await tester.pumpWidget(LiteTodoApp(controller: workspace));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('shell-search-field')),
      '123',
    );
    await tester.pump();

    expect(workspace.searchQuery, '123');
    expect(
      find.byKey(const ValueKey<String>('shell-search-placeholder')),
      findsNothing,
    );

    final box = tester.getRect(
      find.byKey(const ValueKey<String>('shell-search-box')),
    );
    final inputFinder = find.byKey(
      const ValueKey<String>('shell-search-field'),
    );
    final input = tester.getRect(inputFinder);
    final searchIcon = tester.getRect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('shell-search-box')),
        matching: find.byIcon(AppIcons.search),
      ),
    );
    final shortcut = tester.getRect(
      find.byKey(const ValueKey<String>('shell-search-shortcut')),
    );
    final editable = tester.widget<EditableText>(inputFinder);

    expect(editable.controller.text, '123');
    expect(editable.strutStyle.forceStrutHeight, isTrue);
    expect(editable.strutStyle.height, closeTo(1.5, .01));
    expect(input.top, greaterThan(box.top));
    expect(input.bottom, lessThan(box.bottom));
    expect(input.height, closeTo(18, 1));
    expect((input.center.dy - box.center.dy).abs(), lessThanOrEqualTo(1));
    expect(
      (input.center.dy - searchIcon.center.dy).abs(),
      lessThanOrEqualTo(1),
    );
    expect(shortcut.right, closeTo(box.right - AppMetrics.unit * 2, 1));
    expect(shortcut.left, greaterThan(input.right));
  });

  testWidgets(
    'sidebar footer keeps a bordered create button without settings entry',
    (tester) async {
      await tester.pumpWidget(LiteTodoApp(controller: WorkspaceController()));
      await tester.pumpAndSettle();

      final button = tester.widget<ShadButton>(
        find.byKey(const ValueKey<String>('new-project-group-button')),
      );
      expect(button.variant, ShadButtonVariant.outline);
      expect(
        find.byKey(const ValueKey<String>('sidebar-settings-entry')),
        findsNothing,
      );
      final rect = tester.getRect(
        find.byKey(const ValueKey<String>('new-project-group-button')),
      );
      // Outline buttons include their one-pixel border on each edge.
      expect(rect.height, closeTo(36, 1));
      expect(rect.left, greaterThanOrEqualTo(AppMetrics.unit * 2));
      expect(rect.right, lessThanOrEqualTo(267 - AppMetrics.unit * 2));
    },
  );

  testWidgets('project group arrow keeps a stable gap before its icon', (
    tester,
  ) async {
    final workspace = WorkspaceController();
    await tester.pumpWidget(LiteTodoApp(controller: workspace));
    await tester.pumpAndSettle();

    final groupFinder = find.byKey(
      ValueKey<String>('project-group-${workspace.groups.first.id}'),
    );
    final arrowRect = tester.getRect(
      find.descendant(
        of: groupFinder,
        matching: find.byIcon(AppIcons.chevronDown),
      ),
    );
    final iconRect = tester.getRect(
      find.descendant(of: groupFinder, matching: find.byType(ProjectIcon)),
    );
    expect(
      iconRect.left - arrowRect.right,
      greaterThanOrEqualTo(AppMetrics.unit),
    );
  });

  testWidgets('project group actions keep stable spacing and hitbox', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(860, 620);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final workspace = WorkspaceController();
    addTearDown(workspace.dispose);
    await tester.pumpWidget(LiteTodoApp(controller: workspace));
    await tester.pumpAndSettle();

    final group = workspace.groups.first;
    final groupFinder = find.byKey(
      ValueKey<String>('project-group-${group.id}'),
    );
    final countFinder = find.descendant(
      of: groupFinder,
      matching: find.text('${workspace.unfinishedCountForGroup(group.id)}'),
    );
    final moreFinder = find.byKey(
      ValueKey<String>('project-group-more-${group.id}'),
    );
    final groupRect = tester.getRect(groupFinder);
    final countRect = tester.getRect(countFinder);
    final moreRect = tester.getRect(moreFinder);
    final sidebarRect = tester.getRect(
      find.byKey(const ValueKey<String>('sidebar-scroll')),
    );

    expect(moreRect.width, closeTo(28, 1));
    expect(moreRect.height, closeTo(28, 1));
    expect(
      moreRect.left - countRect.right,
      greaterThanOrEqualTo(AppMetrics.unit * 2),
    );
    expect(groupRect.right - moreRect.right, closeTo(AppMetrics.unit * 3, 1));
    expect(
      sidebarRect.right - moreRect.right,
      greaterThanOrEqualTo(AppMetrics.unit * 5),
    );
    expect(moreRect.right, lessThanOrEqualTo(sidebarRect.right));
  });
}
