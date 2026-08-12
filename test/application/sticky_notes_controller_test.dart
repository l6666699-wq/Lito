import 'package:flutter_test/flutter_test.dart';
import 'package:litetodo/application/sticky_notes_controller.dart';
import 'package:litetodo/application/workspace_controller.dart';
import 'package:litetodo/domain/models/app_settings.dart';
import 'package:litetodo/infrastructure/platform/sticky_notes_window_service.dart';

void main() {
  test('stable keys deduplicate inbox and project sticky windows', () async {
    final workspace = WorkspaceController();
    final service = FakeStickyNotesWindowService();
    final controller = StickyNotesController(
      workspace: workspace,
      windowService: service,
    );
    addTearDown(() {
      controller.dispose();
      workspace.dispose();
    });

    await controller.openInbox();
    await controller.openInbox();
    expect(controller.instances, hasLength(1));
    expect(controller.activeKey, StickyNotesController.inboxKey);
    expect(service.openKeys, contains(StickyNotesController.inboxKey));

    final project = workspace.projects.first;
    await controller.openProject(project.id);
    await controller.openProject(project.id);
    expect(controller.instances, hasLength(2));
    expect(controller.contains(project.id), isTrue);
    expect(controller.activeKey, StickyNotesController.keyFor(project.id));
  });

  test('workspace mutations are synchronised to every open key', () async {
    final workspace = WorkspaceController();
    final service = FakeStickyNotesWindowService();
    final controller = StickyNotesController(
      workspace: workspace,
      windowService: service,
    );
    addTearDown(() {
      controller.dispose();
      workspace.dispose();
    });

    await controller.openInbox();
    await controller.openProject(workspace.projects.first.id);
    service.calls.clear();
    await workspace.addTodo('sticky-sync');
    await Future<void>.delayed(Duration.zero);

    expect(
      service.calls.where((call) => call.startsWith('sync:')),
      hasLength(2),
    );
    expect(
      service.snapshots.values.any((value) => value.contains('sticky-sync')),
      isTrue,
    );
  });

  test('settings are included in sticky snapshots', () async {
    final workspace = WorkspaceController();
    final service = FakeStickyNotesWindowService();
    final controller = StickyNotesController(
      workspace: workspace,
      windowService: service,
      settingsProvider: () => AppSettings(themeMode: AppThemeMode.dark),
    );
    addTearDown(() {
      controller.dispose();
      workspace.dispose();
    });

    await controller.openProject(workspace.projects.first.id);
    final snapshot = service.snapshots.values.single;
    final settings = readStickySnapshotSettings(snapshot);

    expect(settings?.themeMode, AppThemeMode.dark);
  });

  test('invalid project does not create a native window', () async {
    final workspace = WorkspaceController();
    final service = FakeStickyNotesWindowService();
    final controller = StickyNotesController(
      workspace: workspace,
      windowService: service,
    );
    addTearDown(() {
      controller.dispose();
      workspace.dispose();
    });

    await controller.openProject('missing-project');
    expect(controller.instances, isEmpty);
    expect(service.openKeys, isEmpty);
  });
}
