import 'package:flutter_test/flutter_test.dart';
import 'package:litetodo/infrastructure/platform/sticky_notes_window_service.dart';

void main() {
  test('secondary launch arguments preserve stable inbox/project identity', () {
    final inbox = StickyWindowLaunchArguments.parse(const <String>[
      '--sticky-window',
      '--sticky-key=inbox',
    ]);
    expect(inbox?.key, 'inbox');
    expect(inbox?.projectId, isNull);

    final project = StickyWindowLaunchArguments.parse(const <String>[
      '--sticky-window',
      '--sticky-key=project:abc',
      '--sticky-project-id=abc',
    ]);
    expect(project?.key, 'project:abc');
    expect(project?.projectId, 'abc');
    expect(
      StickyWindowLaunchArguments.parse(const <String>['--sticky-key=inbox']),
      isNull,
    );
  });

  test('fake service records native lifecycle operations', () async {
    final service = FakeStickyNotesWindowService();
    await service.open(key: 'inbox');
    await service.setAlwaysOnTop('inbox', true);
    await service.syncSnapshot(key: 'inbox', snapshot: '{"revision":1}');
    await service.startDragging('inbox');
    await service.close('inbox');

    expect(service.openKeys, isEmpty);
    expect(service.alwaysOnTopKeys, contains('inbox'));
    expect(service.calls, contains('open:inbox:'));
    expect(service.calls, contains('sync:inbox'));
    expect(service.calls, contains('drag:inbox'));
  });
}
