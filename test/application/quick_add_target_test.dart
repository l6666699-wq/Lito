import 'package:flutter_test/flutter_test.dart';
import 'package:litetodo/application/quick_add_controller.dart';
import 'package:litetodo/application/window_controller.dart';
import 'package:litetodo/infrastructure/platform/desktop_window_service.dart';

QuickAddTarget _project(String id, String name) => QuickAddTarget.project(
  id: id,
  name: name,
  iconKey: 'folder',
  colorKey: 'blue',
);

Future<WindowController> _openWindow() async {
  final window = WindowController(desktopService: FakeDesktopWindowService());
  await window.initialize();
  await window.openQuickAdd();
  return window;
}

class _FailingRestoreDesktopService extends FakeDesktopWindowService {
  bool failFullRestore = false;

  @override
  Future<void> configure(WindowLayout layout) async {
    if (failFullRestore && layout.size == WindowLayout.full.size) {
      throw StateError('controlled window restore failure');
    }
    await super.configure(layout);
  }
}

void main() {
  test('default target resolves the persisted last project', () async {
    final window = await _openWindow();
    addTearDown(window.dispose);
    final controller = QuickAddController(
      windowController: window,
      availableTargets: <QuickAddTarget>[
        const QuickAddTarget.inbox(),
        _project('p1', '项目一'),
      ],
      lastProjectId: 'p1',
    );

    expect(controller.selectedProjectId, 'p1');
    expect(controller.selectedTarget.name, '项目一');
  });

  test(
    'selection submits the real project and persists it after success',
    () async {
      final window = await _openWindow();
      addTearDown(window.dispose);
      String? submittedProject;
      final persisted = <String?>[];
      final controller = QuickAddController(
        windowController: window,
        availableTargets: <QuickAddTarget>[
          const QuickAddTarget.inbox(),
          _project('p1', '项目一'),
        ],
        onSubmitWithTarget: (title, projectId) async {
          expect(title, '真实项目任务');
          submittedProject = projectId;
        },
        onLastProjectChanged: (projectId) async {
          persisted.add(projectId);
          return true;
        },
      );
      controller.setTarget('p1');
      controller.setDraft('真实项目任务');

      expect(await controller.submit(), isTrue);
      expect(submittedProject, 'p1');
      expect(persisted, <String?>['p1']);
      expect(controller.lastProjectId, 'p1');
    },
  );

  test(
    'archived or deleted target falls back to inbox and clears preference',
    () async {
      final window = await _openWindow();
      addTearDown(window.dispose);
      String? submittedProject = 'unexpected';
      final persisted = <String?>[];
      final controller = QuickAddController(
        windowController: window,
        availableTargets: <QuickAddTarget>[
          const QuickAddTarget.inbox(),
          _project('p1', '项目一'),
        ],
        lastProjectId: 'p1',
        onSubmitWithTarget: (title, projectId) async {
          submittedProject = projectId;
        },
        onLastProjectChanged: (projectId) async {
          persisted.add(projectId);
          return true;
        },
      );
      controller.setTarget('p1');
      // The workspace listener supplies this same shape when a project or its
      // group becomes archived, or when the project is deleted.
      controller.setAvailableTargets(const <QuickAddTarget>[
        QuickAddTarget.inbox(),
      ]);
      controller.setDraft('归档后回退');

      expect(await controller.submit(), isTrue);
      expect(submittedProject, isNull);
      expect(persisted, <String?>[null]);
      expect(controller.lastProjectId, isNull);
    },
  );

  test(
    'failed submission keeps the draft and last project preference',
    () async {
      final window = await _openWindow();
      addTearDown(window.dispose);
      var persisted = false;
      final controller = QuickAddController(
        windowController: window,
        availableTargets: <QuickAddTarget>[
          const QuickAddTarget.inbox(),
          _project('p1', '项目一'),
        ],
        lastProjectId: 'p1',
        onSubmitWithTarget: (title, projectId) async {
          throw StateError('controlled save failure');
        },
        onLastProjectChanged: (projectId) async {
          persisted = true;
          return true;
        },
      );
      controller.setDraft('保留输入');

      expect(await controller.submit(), isFalse);
      expect(controller.draft, '保留输入');
      expect(controller.lastProjectId, 'p1');
      expect(persisted, isFalse);
      expect(controller.error, contains('添加失败'));
      expect(window.mode, WindowMode.quickAdd);
    },
  );

  test('preference save failure keeps the Todo success boundary', () async {
    final window = await _openWindow();
    addTearDown(window.dispose);
    final controller = QuickAddController(
      windowController: window,
      availableTargets: <QuickAddTarget>[
        const QuickAddTarget.inbox(),
        _project('p1', '项目一'),
      ],
      lastProjectId: 'previous',
      onSubmitWithTarget: (title, projectId) async {},
      onLastProjectChanged: (projectId) async => false,
    );
    controller.setTarget('p1');
    controller.setDraft('偏好保存失败仍添加');

    expect(await controller.submit(), isTrue);
    expect(controller.submittedCount, 1);
    expect(controller.draft, isEmpty);
    expect(controller.lastProjectId, 'previous');
    expect(controller.error, contains('偏好'));
  });

  test(
    'window restore failure does not turn a successful Todo into a retry',
    () async {
      final desktop = _FailingRestoreDesktopService();
      final window = WindowController(desktopService: desktop);
      await window.initialize();
      await window.openQuickAdd();
      addTearDown(window.dispose);
      final controller = QuickAddController(
        windowController: window,
        onSubmitWithTarget: (title, projectId) async {},
      );
      controller.setDraft('窗口恢复失败仍添加');
      desktop.failFullRestore = true;

      expect(await controller.submit(), isTrue);
      expect(controller.submittedCount, 1);
      expect(controller.draft, isEmpty);
      expect(controller.error, contains('窗口恢复失败'));
    },
  );
}
