import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:litetodo/app/theme/app_theme.dart';
import 'package:litetodo/application/quick_add_controller.dart';
import 'package:litetodo/application/settings_controller.dart';
import 'package:litetodo/application/window_controller.dart';
import 'package:litetodo/application/workspace_controller.dart';
import 'package:litetodo/app/litetodo_app.dart';
import 'package:litetodo/infrastructure/platform/desktop_window_service.dart';
import 'package:litetodo/presentation/settings/settings_scope.dart';
import 'package:litetodo/presentation/quick_add/quick_add_view.dart';

QuickAddTarget _project(String id, String name) => QuickAddTarget.project(
  id: id,
  name: name,
  iconKey: 'folder',
  colorKey: 'blue',
);

void main() {
  testWidgets('Quick Add target selector changes the stable project ID', (
    tester,
  ) async {
    final window = WindowController(desktopService: FakeDesktopWindowService());
    addTearDown(window.dispose);
    final controller = QuickAddController(
      windowController: window,
      availableTargets: <QuickAddTarget>[
        const QuickAddTarget.inbox(),
        _project('p1', '项目一'),
      ],
    );

    await tester.pumpWidget(
      ShadApp(
        theme: AppTheme.light,
        home: QuickAddView(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    expect(controller.selectedProjectId, isNull);
    await tester.tap(find.byKey(const ValueKey<String>('quick-add-target-p1')));
    await tester.pump();
    expect(controller.selectedProjectId, 'p1');
  });

  testWidgets('Quick Add target selector fits the three reference sizes', (
    tester,
  ) async {
    final sizes = <Size>[
      const Size(340, 520),
      const Size(300, 360),
      const Size(440, 760),
    ];
    for (final size in sizes) {
      await tester.binding.setSurfaceSize(size);
      final window = WindowController(
        desktopService: FakeDesktopWindowService(),
      );
      final controller = QuickAddController(
        windowController: window,
        availableTargets: <QuickAddTarget>[
          const QuickAddTarget.inbox(),
          _project('p1', '项目一'),
          _project('p2', '项目二'),
          _project('p3', '项目三'),
        ],
      );
      await tester.pumpWidget(
        ShadApp(
          theme: AppTheme.light,
          home: SizedBox(
            width: size.width,
            height: size.height,
            child: QuickAddView(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'size $size');
      controller.dispose();
      window.dispose();
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('Quick Add narrow errors stay constrained and ellipsized', (
    tester,
  ) async {
    const size = Size(300, 360);
    await tester.binding.setSurfaceSize(size);
    final window = WindowController(desktopService: FakeDesktopWindowService());
    final controller = QuickAddController(
      windowController: window,
      onSubmitWithTarget: (title, projectId) async {
        throw StateError(
          'controlled failure with a deliberately long technical message that must not expand the narrow Quick Add row',
        );
      },
    );
    addTearDown(() {
      controller.dispose();
      window.dispose();
      tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      ShadApp(
        theme: AppTheme.light,
        home: SizedBox(
          width: size.width,
          height: size.height,
          child: QuickAddView(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();
    controller.setDraft('长错误测试');
    expect(await controller.submit(), isFalse);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('LiteTodoApp removes archived group projects from Quick Add', (
    tester,
  ) async {
    final workspace = WorkspaceController();
    final window = WindowController(desktopService: FakeDesktopWindowService());
    final quickAdd = QuickAddController(windowController: window);
    addTearDown(() {
      quickAdd.dispose();
      window.dispose();
      workspace.dispose();
    });

    await tester.pumpWidget(
      LiteTodoApp(
        controller: workspace,
        windowController: window,
        quickAddController: quickAdd,
      ),
    );
    await tester.pumpAndSettle();
    await window.openQuickAdd();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('quick-add-target-project-focus')),
      findsOneWidget,
    );
    workspace.archiveGroup('group-work');
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('quick-add-target-project-focus')),
      findsNothing,
    );
  });

  testWidgets(
    'LiteTodoApp submits a selected project and stores lastProjectId',
    (tester) async {
      final workspace = WorkspaceController();
      final window = WindowController(
        desktopService: FakeDesktopWindowService(),
      );
      final quickAdd = QuickAddController(windowController: window);
      final settings = SettingsController(
        repository: InMemorySettingsRepository(),
      );
      await settings.initialize();
      addTearDown(() {
        settings.dispose();
        quickAdd.dispose();
        window.dispose();
        workspace.dispose();
      });

      await tester.pumpWidget(
        LiteTodoApp(
          controller: workspace,
          windowController: window,
          quickAddController: quickAdd,
          settingsController: settings,
        ),
      );
      await tester.pumpAndSettle();
      await window.openQuickAdd();
      await tester.pumpAndSettle();
      quickAdd.setTarget('project-focus');
      quickAdd.setDraft('选定项目任务');

      expect(await quickAdd.submit(), isTrue);
      expect(
        workspace.todos
            .where((todo) => todo.title == '选定项目任务')
            .single
            .projectId,
        'project-focus',
      );
      expect(settings.lastProjectId, 'project-focus');
    },
  );

  testWidgets('LiteTodoApp unbinds an externally owned QuickAddController', (
    tester,
  ) async {
    final workspace = WorkspaceController();
    final window = WindowController(desktopService: FakeDesktopWindowService());
    final originalTargets = <QuickAddTarget>[
      const QuickAddTarget.inbox(),
      _project('external', '外部项目'),
    ];
    String? originalSubmittedProject;
    final quickAdd = QuickAddController(
      windowController: window,
      availableTargets: originalTargets,
      lastProjectId: 'external',
      onSubmitWithTarget: (title, projectId) async {
        originalSubmittedProject = projectId;
      },
    );
    addTearDown(() {
      quickAdd.dispose();
      window.dispose();
      workspace.dispose();
    });

    await tester.pumpWidget(
      LiteTodoApp(
        controller: workspace,
        windowController: window,
        quickAddController: quickAdd,
      ),
    );
    await tester.pumpAndSettle();
    expect(quickAdd.availableTargets, isNot(equals(originalTargets)));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(quickAdd.availableTargets, equals(originalTargets));
    await window.openQuickAdd();
    quickAdd.setTarget('external');
    quickAdd.setDraft('外部复用');
    expect(await quickAdd.submit(), isTrue);
    expect(originalSubmittedProject, 'external');
  });
}
