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

void main() {
  test(
    'workspace project scope takes precedence over last project preference',
    () async {
      final window = WindowController(
        desktopService: FakeDesktopWindowService(),
      );
      addTearDown(window.dispose);
      String? submittedProject;
      final controller = QuickAddController(
        windowController: window,
        availableTargets: <QuickAddTarget>[
          const QuickAddTarget.inbox(),
          _project('p1', 'Project One'),
          _project('p2', 'Project Two'),
        ],
        lastProjectId: 'p1',
        onSubmitWithTarget: (title, projectId) async {
          submittedProject = projectId;
        },
      );
      addTearDown(controller.dispose);

      controller.setWorkspaceProjectId('p2');
      expect(controller.selectedProjectId, 'p2');
      controller.setDraft('scope root');

      expect(await controller.submit(), isTrue);
      expect(submittedProject, 'p2');
    },
  );

  test('explicit Quick Add target still overrides workspace project scope', () {
    final window = WindowController(desktopService: FakeDesktopWindowService());
    addTearDown(window.dispose);
    final controller = QuickAddController(
      windowController: window,
      availableTargets: <QuickAddTarget>[
        const QuickAddTarget.inbox(),
        _project('p1', 'Project One'),
        _project('p2', 'Project Two'),
      ],
      lastProjectId: 'p1',
    );
    addTearDown(controller.dispose);

    controller.setWorkspaceProjectId('p2');
    controller.setTarget('p1');

    expect(controller.selectedProjectId, 'p1');
  });
}
