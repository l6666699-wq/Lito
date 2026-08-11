import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:litetodo/app/litetodo_app.dart';
import 'package:litetodo/app/theme/app_colors.dart';
import 'package:litetodo/app/theme/app_metrics.dart';
import 'package:litetodo/app/theme/project_palette.dart';
import 'package:litetodo/application/settings_controller.dart';
import 'package:litetodo/application/workspace_controller.dart';
import 'package:litetodo/domain/models/app_settings.dart';
import 'package:litetodo/presentation/projects/project_management.dart';
import 'package:litetodo/presentation/settings/settings_scope.dart';

void main() {
  Future<void> pumpApp(
    WidgetTester tester,
    WorkspaceController controller,
  ) async {
    await tester.pumpWidget(
      LiteTodoApp(
        key: ValueKey<WorkspaceController>(controller),
        controller: controller,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('creates a group from the real sidebar entry', (tester) async {
    final controller = WorkspaceController();
    await pumpApp(tester, controller);

    await tester.tap(
      find.byKey(const ValueKey<String>('new-project-group-button')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('project-group-editor-dialog')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('project-group-name-input')),
      '委托测试',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('project-group-editor-save')),
    );
    await tester.pumpAndSettle();

    expect(controller.groups.any((group) => group.name == '委托测试'), isTrue);
  });

  testWidgets('project editor keeps its hierarchy in dark theme', (
    tester,
  ) async {
    final controller = WorkspaceController();
    final settings = SettingsController(
      repository: InMemorySettingsRepository(
        initial: AppSettings(themeMode: AppThemeMode.dark),
      ),
    );
    await settings.initialize();
    addTearDown(() {
      settings.dispose();
      controller.dispose();
    });
    await tester.pumpWidget(
      LiteTodoApp(
        key: ValueKey<WorkspaceController>(controller),
        controller: controller,
        settingsController: settings,
      ),
    );
    await tester.pumpAndSettle();

    final project = controller.projects.first;
    await tester.tap(
      find.byKey(ValueKey<String>('project-more-${project.id}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('project-action-edit')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('project-editor-dialog')),
      findsOneWidget,
    );
    expect(find.text('项目名称'), findsOneWidget);
    expect(find.text('所属分组'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'creates a project in a selected group and chooses IconPark icon',
    (tester) async {
      final controller = WorkspaceController();
      await pumpApp(tester, controller);
      final group = controller.groups.first;

      await tester.tap(
        find.byKey(ValueKey<String>('project-group-more-${group.id}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('project-action-create')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('project-name-input')),
        '图标测试项目',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('project-icon-search')),
        'code',
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey<String>('project-icon-option-code')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('project-editor-save')),
      );
      await tester.pumpAndSettle();

      final project = controller.projects.firstWhere(
        (item) => item.name == '图标测试项目',
      );
      expect(project.groupId, group.id);
      expect(project.iconKey, 'code');
    },
  );

  testWidgets('edits project fields and cancel leaves the model unchanged', (
    tester,
  ) async {
    final controller = WorkspaceController();
    await pumpApp(tester, controller);
    final original = controller.projects.first;
    final alternateGroup = controller.createGroup(name: '另一个分组');

    await tester.tap(
      find.byKey(ValueKey<String>('project-more-${original.id}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('project-action-edit')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('project-name-input')),
      '编辑后的项目',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('project-color-option-red')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('project-icon-option-book')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('project-group-selector')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(ValueKey<String>('project-group-option-${alternateGroup.id}')),
    );
    await tester.tap(find.byKey(const ValueKey<String>('project-editor-save')));
    await tester.pumpAndSettle();

    final edited = controller.getProject(original.id)!;
    expect(edited.name, '编辑后的项目');
    expect(edited.colorKey, 'red');
    expect(edited.iconKey, 'book');
    expect(edited.groupId, alternateGroup.id);

    await tester.drag(
      find.byKey(const ValueKey<String>('sidebar-scroll')),
      const Offset(0, -500),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(ValueKey<String>('project-more-${original.id}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('project-action-edit')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('project-name-input')),
      '取消不应保存',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('project-editor-cancel')),
    );
    await tester.pumpAndSettle();
    expect(controller.getProject(original.id)!.name, '编辑后的项目');
  });

  testWidgets('archive removes project from sidebar and delete enters Trash', (
    tester,
  ) async {
    final controller = WorkspaceController();
    await pumpApp(tester, controller);
    final archived = controller.projects.first;

    await tester.tap(
      find.byKey(ValueKey<String>('project-more-${archived.id}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('project-action-archive')),
    );
    await tester.pumpAndSettle();
    expect(controller.getProject(archived.id)!.archived, isTrue);
    expect(
      find.byKey(ValueKey<String>('project-${archived.id}')),
      findsNothing,
    );
    await tester.drag(
      find.byKey(const ValueKey<String>('sidebar-scroll')),
      const Offset(0, -500),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('archived-projects-toggle')),
    );
    await tester.pump();
    expect(
      find.byKey(ValueKey<String>('project-${archived.id}')),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.byKey(ValueKey<String>('project-${archived.id}')),
    );
    await tester.tap(find.byKey(ValueKey<String>('project-${archived.id}')));
    expect(controller.scope, WorkspaceScope.project);
    expect(controller.projectScopeId, archived.id);

    await tester.ensureVisible(
      find.byKey(ValueKey<String>('project-more-${archived.id}')),
    );
    await tester.tap(
      find.byKey(ValueKey<String>('project-more-${archived.id}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('project-action-unarchive')),
    );
    await tester.pumpAndSettle();
    expect(controller.getProject(archived.id)!.archived, isFalse);
    expect(
      find.byKey(ValueKey<String>('project-${archived.id}')),
      findsOneWidget,
    );

    final deleteController = WorkspaceController();
    await pumpApp(tester, deleteController);
    final deletable = deleteController.projects.first;
    await tester.tap(
      find.byKey(ValueKey<String>('project-more-${deletable.id}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('project-action-delete')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('project-management-confirm-ok')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('project-management-confirm-ok')),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 50));
    expect(deleteController.getProject(deletable.id), isNull);
    expect(
      deleteController.trash.any(
        (item) =>
            item.kind == 'project_subtree' &&
            (item.payload['project'] as Map)['id'] == deletable.id,
      ),
      isTrue,
    );
  });

  testWidgets('group disband keeps projects and clears group membership', (
    tester,
  ) async {
    final controller = WorkspaceController();
    await pumpApp(tester, controller);
    final group = controller.groups.first;
    final groupProjects = controller.projects
        .where((project) => project.groupId == group.id)
        .toList(growable: false);

    await tester.tap(
      find.byKey(ValueKey<String>('project-group-more-${group.id}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('project-action-disband')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('project-management-confirm-ok')),
    );
    await tester.pumpAndSettle();

    expect(controller.getGroup(group.id), isNull);
    for (final project in groupProjects) {
      expect(controller.getProject(project.id)!.groupId, isNull);
    }
  });

  testWidgets('group edit and archive are wired through sidebar actions', (
    tester,
  ) async {
    final controller = WorkspaceController();
    await pumpApp(tester, controller);
    final group = controller.groups.first;
    final groupProjects = controller.projects
        .where((project) => project.groupId == group.id)
        .toList(growable: false);

    await tester.tap(
      find.byKey(ValueKey<String>('project-group-more-${group.id}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('project-action-edit')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('project-group-name-input')),
      '编辑后的分组',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('project-color-option-red')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('project-icon-option-book')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('project-group-editor-save')),
    );
    await tester.pumpAndSettle();

    final editedGroup = controller.getGroup(group.id)!;
    expect(editedGroup.name, '编辑后的分组');
    expect(editedGroup.colorKey, 'red');
    expect(editedGroup.iconKey, 'book');

    await tester.tap(
      find.byKey(ValueKey<String>('project-group-more-${group.id}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('project-action-archive')),
    );
    await tester.pumpAndSettle();

    expect(controller.getGroup(group.id)!.archived, isTrue);
    expect(
      find.byKey(ValueKey<String>('project-group-${group.id}')),
      findsNothing,
    );
    for (final project in groupProjects) {
      expect(controller.getProject(project.id), isNotNull);
      expect(controller.getProject(project.id)!.groupId, group.id);
      expect(
        find.byKey(ValueKey<String>('project-${project.id}')),
        findsNothing,
      );
    }
    await tester.drag(
      find.byKey(const ValueKey<String>('sidebar-scroll')),
      const Offset(0, -500),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('archived-projects-toggle')),
    );
    await tester.pump();
    for (final project in groupProjects) {
      expect(
        find.byKey(ValueKey<String>('project-${project.id}')),
        findsOneWidget,
      );
    }
  });

  testWidgets('project management dialogs do not overflow at desktop sizes', (
    tester,
  ) async {
    for (final size in const <Size>[
      Size(1672, 941),
      Size(860, 620),
      Size(680, 460),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final controller = WorkspaceController();
      await pumpApp(tester, controller);
      unawaited(
        ProjectManagement.showCreateProject(
          tester.element(
            find.byKey(const ValueKey<String>('app-shell-canvas')),
          ),
          controller,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.enterText(
        find.byKey(const ValueKey<String>('project-icon-search')),
        'code',
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('project-icon-option-code')),
        findsOneWidget,
      );
      if (find
          .byKey(const ValueKey<String>('project-editor-dialog'))
          .evaluate()
          .isNotEmpty) {
        await tester.tap(
          find.byKey(const ValueKey<String>('project-editor-cancel')),
        );
        await tester.pumpAndSettle();
      }
    }
  });

  testWidgets('project action dialog keeps compact card and action order', (
    tester,
  ) async {
    final controller = WorkspaceController();
    addTearDown(controller.dispose);
    await pumpApp(tester, controller);
    final group = controller.groups.first;

    await tester.tap(
      find.byKey(ValueKey<String>('project-group-more-${group.id}')),
    );
    await tester.pumpAndSettle();

    final dialog = find.byKey(
      const ValueKey<String>('project-action-dialog-card'),
    );
    expect(dialog, findsOneWidget);
    final size = tester.getSize(dialog);
    expect(size.width, greaterThanOrEqualTo(320));
    expect(size.width, lessThanOrEqualTo(380));
    expect(
      find.byKey(const ValueKey<String>('project-action-close')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('project-action-cancel')),
      findsOneWidget,
    );

    final keys = <String>[
      'project-action-create',
      'project-action-edit',
      'project-action-archive',
      'project-action-disband',
    ];
    final widgets = tester.allWidgets.toList(growable: false);
    final indexes = keys
        .map(
          (key) => widgets.indexWhere(
            (widget) => widget.key == ValueKey<String>(key),
          ),
        )
        .toList(growable: false);
    expect(indexes.every((index) => index >= 0), isTrue);
    expect(indexes, orderedEquals(indexes.toList()..sort()));
  });

  testWidgets('project group actions use semantic colors and stable spacing', (
    tester,
  ) async {
    final controller = WorkspaceController();
    addTearDown(controller.dispose);
    await pumpApp(tester, controller);
    final group = controller.groups.first;

    await tester.tap(
      find.byKey(ValueKey<String>('project-group-more-${group.id}')),
    );
    await tester.pumpAndSettle();

    final dialogFinder = find.byKey(
      const ValueKey<String>('project-action-dialog'),
    );
    final cardBackgroundFinder = find
        .descendant(of: dialogFinder, matching: find.byType(DecoratedBox))
        .first;
    final cardRect = tester.getRect(cardBackgroundFinder);
    expect(cardRect.width, greaterThanOrEqualTo(320));
    expect(cardRect.width, lessThanOrEqualTo(380));
    final dialog = tester.widget<ShadDialog>(dialogFinder);
    final colors = AppColors.of(tester.element(dialogFinder));
    expect(dialog.backgroundColor, colors.surface);
    expect(dialog.radius, BorderRadius.circular(AppMetrics.shellCardRadius));
    final cardBorder = dialog.border! as Border;
    expect(cardBorder.top.color, colors.border);
    expect(cardBorder.top.width, closeTo(.8, .01));

    final titleIcon = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey<String>('project-action-title-icon')),
    );
    final titleDecoration = titleIcon.decoration as BoxDecoration;
    expect(titleDecoration.color, colors.focusSoft);
    expect((titleDecoration.border! as Border).top.color, colors.border);
    expect(
      tester.getSize(
        find.byKey(const ValueKey<String>('project-action-title-icon')),
      ),
      const Size(AppMetrics.unit * 10, AppMetrics.unit * 10),
    );
    expect(
      find.byKey(const ValueKey<String>('project-action-description')),
      findsOneWidget,
    );

    const semanticKeys = <String, String>{
      'create': 'blue',
      'edit': 'green',
      'archive': 'orange',
      'disband': 'red',
    };
    final actionRects = <Rect>[];
    for (final entry in semanticKeys.entries) {
      final actionFinder = find.byKey(
        ValueKey<String>('project-action-${entry.key}'),
      );
      final iconFinder = find.byKey(
        ValueKey<String>('project-action-${entry.key}-icon'),
      );
      expect(actionFinder, findsOneWidget);
      expect(iconFinder, findsOneWidget);
      final actionButtonFinder = find.byKey(
        ValueKey<String>('project-action-${entry.key}-button'),
      );
      final action = tester.widget<ShadButton>(actionButtonFinder);
      expect(action.height, AppMetrics.unit * 12);
      expect(action.width, double.infinity);
      final actionRect = tester.getRect(actionButtonFinder);
      actionRects.add(actionRect);
      final iconBlock = tester.widget<DecoratedBox>(iconFinder);
      final iconDecoration = iconBlock.decoration as BoxDecoration;
      final palette = ProjectPalette.resolve(entry.value);
      expect(iconDecoration.color, palette.softBackground);
      expect((iconDecoration.border! as Border).top.color, palette.border);
      final icon = tester.widget<Icon>(
        find.descendant(of: iconFinder, matching: find.byType(Icon)),
      );
      expect(icon.color, palette.accent);
    }

    for (var index = 1; index < actionRects.length; index++) {
      expect(
        actionRects[index].top - actionRects[index - 1].bottom,
        closeTo(AppMetrics.unit * 2, 1),
      );
      expect(actionRects[index].width, closeTo(actionRects.first.width, 1));
    }

    final cancelFinder = find.byKey(
      const ValueKey<String>('project-action-cancel'),
    );
    final cancel = tester.widget<ShadButton>(cancelFinder);
    final cancelRect = tester.getRect(cancelFinder);
    expect(cancel.width, AppMetrics.unit * 16);
    expect(cancel.height, AppMetrics.unit * 8);
    expect(cancelRect.right, closeTo(cardRect.right - AppMetrics.unit * 5, 1));
    expect(
      cancelRect.bottom,
      closeTo(cardRect.bottom - AppMetrics.unit * 4, 1),
    );
    expect(
      cancelRect.top - actionRects.last.bottom,
      greaterThanOrEqualTo(AppMetrics.unit * 3 - 1),
    );
  });

  testWidgets('project editor exposes form sections and icon grid', (
    tester,
  ) async {
    final controller = WorkspaceController();
    addTearDown(controller.dispose);
    await pumpApp(tester, controller);
    unawaited(
      ProjectManagement.showCreateProject(
        tester.element(find.byKey(const ValueKey<String>('app-shell-canvas'))),
        controller,
      ),
    );
    await tester.pumpAndSettle();

    final dialog = find.byKey(
      const ValueKey<String>('project-editor-dialog-card'),
    );
    expect(dialog, findsOneWidget);
    final size = tester.getSize(dialog);
    expect(size.width, greaterThanOrEqualTo(400));
    expect(size.width, lessThanOrEqualTo(520));
    expect(
      find.byKey(const ValueKey<String>('project-name-input')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('project-name-label')),
      findsOneWidget,
    );
    expect(find.text('项目颜色'), findsOneWidget);
    expect(find.text('选择图标'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('project-group-selector')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('project-icon-search')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('project-icon-grid')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('project-icon-option-folder')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('project-editor-cancel')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('project-editor-save')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('project-editor-close')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('project-editor-dialog')),
      findsNothing,
    );
  });

  testWidgets('project icon search has no idle or focused borders', (
    tester,
  ) async {
    final controller = WorkspaceController();
    addTearDown(controller.dispose);
    await pumpApp(tester, controller);
    unawaited(
      ProjectManagement.showCreateProject(
        tester.element(find.byKey(const ValueKey<String>('app-shell-canvas'))),
        controller,
      ),
    );
    await tester.pumpAndSettle();

    final inputFinder = find.byKey(
      const ValueKey<String>('project-icon-search'),
    );
    final input = tester.widget<ShadInput>(inputFinder);
    expect(input.decoration, isNotNull);
    final decoration = input.decoration!;
    expect(decoration.border?.hasBorder ?? false, isFalse);
    expect(decoration.focusedBorder?.hasBorder ?? false, isFalse);
    expect(decoration.secondaryBorder?.hasBorder ?? false, isFalse);
    expect(decoration.secondaryFocusedBorder?.hasBorder ?? false, isFalse);

    final editableTextFinder = find.descendant(
      of: inputFinder,
      matching: find.byType(EditableText),
    );
    final inputRect = tester.getRect(inputFinder);
    final editableTextRect = tester.getRect(editableTextFinder);
    expect(editableTextRect.center.dy, closeTo(inputRect.center.dy, 0.5));

    final inputState = tester.state<ShadInputState>(inputFinder);
    expect(inputState.hasFocus.value, isFalse);
    await tester.tap(inputFinder);
    await tester.pump();
    expect(inputState.hasFocus.value, isTrue);
    expect(decoration.border?.hasBorder ?? false, isFalse);
    expect(decoration.focusedBorder?.hasBorder ?? false, isFalse);
    expect(decoration.secondaryBorder?.hasBorder ?? false, isFalse);
    expect(decoration.secondaryFocusedBorder?.hasBorder ?? false, isFalse);
  });

  testWidgets('project and group editor headers align icon and title tops', (
    tester,
  ) async {
    final controller = WorkspaceController();
    addTearDown(controller.dispose);
    await pumpApp(tester, controller);
    final canvas = tester.element(
      find.byKey(const ValueKey<String>('app-shell-canvas')),
    );

    void expectHeaderAlignment() {
      final iconRect = tester.getRect(
        find.byKey(const ValueKey<String>('project-editor-header-icon')),
      );
      final titleRect = tester.getRect(
        find.byKey(const ValueKey<String>('project-editor-header-title')),
      );
      final descriptionRect = tester.getRect(
        find.byKey(const ValueKey<String>('project-editor-header-description')),
      );
      expect(iconRect.top, closeTo(titleRect.top, 0.5));
      expect(descriptionRect.top, greaterThan(titleRect.bottom));
      expect(
        descriptionRect.top - titleRect.bottom,
        closeTo(AppMetrics.unit, 0.5),
      );
    }

    unawaited(ProjectManagement.showCreateProject(canvas, controller));
    await tester.pumpAndSettle();
    expectHeaderAlignment();
    await tester.tap(
      find.byKey(const ValueKey<String>('project-editor-cancel')),
    );
    await tester.pumpAndSettle();

    unawaited(ProjectManagement.showCreateGroup(canvas, controller));
    await tester.pumpAndSettle();
    expectHeaderAlignment();
  });
}
