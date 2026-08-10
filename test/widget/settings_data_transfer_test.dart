import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litetodo/app/theme/app_theme.dart';
import 'package:litetodo/app/litetodo_app.dart';
import 'package:litetodo/application/app_navigation_controller.dart';
import 'package:litetodo/application/data_transfer_controller.dart';
import 'package:litetodo/application/data_transfer_file_picker.dart';
import 'package:litetodo/application/data_transfer_gateway.dart';
import 'package:litetodo/application/quick_add_controller.dart';
import 'package:litetodo/application/settings_controller.dart';
import 'package:litetodo/application/window_controller.dart';
import 'package:litetodo/application/workspace_controller.dart';
import 'package:litetodo/domain/models/app_data.dart';
import 'package:litetodo/domain/models/project.dart';
import 'package:litetodo/domain/models/todo_item.dart';
import 'package:litetodo/infrastructure/platform/data_directory_service.dart';
import 'package:litetodo/infrastructure/platform/desktop_window_service.dart';
import 'package:litetodo/infrastructure/persistence/app_data_repository.dart';
import 'package:litetodo/infrastructure/persistence/backup_service.dart';
import 'package:litetodo/icons/app_icons.dart';
import 'package:litetodo/presentation/settings/settings_page.dart';
import 'package:litetodo/presentation/settings/settings_scope.dart';
import 'package:litetodo/presentation/settings/settings_shared_controls.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class _FakePicker implements DataTransferFilePicker {
  String? importPath;
  String? exportPath;
  int importCalls = 0;
  int exportCalls = 0;

  @override
  Future<String?> pickImportFile() async {
    importCalls += 1;
    return importPath;
  }

  @override
  Future<String?> pickExportFile() async {
    exportCalls += 1;
    return exportPath;
  }
}

class _FakeGateway implements DataTransferGateway {
  _FakeGateway({this.importedData});

  AppData? importedData;
  DataTransferErrorCode? readError;
  DataTransferErrorCode? exportError;
  Completer<void>? exportGate;
  int readCalls = 0;
  int exportCalls = 0;
  int manualBackupCalls = 0;

  @override
  Future<DataTransferDocument> readImportFile(String path) async {
    readCalls += 1;
    final error = readError;
    if (error != null) throw DataTransferException(error);
    final data = importedData;
    if (data == null) throw StateError('missing test import');
    return DataTransferDocument(
      raw: '{}',
      data: data,
      schemaVersion: data.schemaVersion,
    );
  }

  @override
  Future<void> exportData(AppData snapshot, String path) async {
    exportCalls += 1;
    final gate = exportGate;
    if (gate != null) await gate.future;
    final error = exportError;
    if (error != null) throw DataTransferException(error);
  }

  @override
  Future<void> createManualBackup() async {
    manualBackupCalls += 1;
  }

  @override
  Future<void> createMigrationBackup(String raw) async {}
}

class _WorkspaceRepository implements AppDataRepository {
  _WorkspaceRepository(this.snapshot, {this.recoveryWarning});

  AppData snapshot;
  final String? recoveryWarning;
  int saveCalls = 0;

  @override
  Future<AppDataLoadResult> load() async => AppDataLoadResult(
    data: snapshot,
    source: recoveryWarning == null
        ? AppDataLoadSource.primary
        : AppDataLoadSource.previous,
    recoveryWarning: recoveryWarning,
  );

  @override
  Future<void> save(AppData next) async {
    saveCalls += 1;
    snapshot = next;
  }
}

class _SettingsHarness {
  _SettingsHarness({
    required this.directory,
    required this.settings,
    required this.window,
    required this.workspace,
    required this.backup,
    required this.dataDirectory,
    required this.transfer,
  });

  final Directory directory;
  final SettingsController settings;
  final WindowController window;
  final WorkspaceController workspace;
  final BackupService backup;
  final FakeDataDirectoryService dataDirectory;
  final DataTransferController? transfer;

  Future<void> dispose() async {
    transfer?.dispose();
    settings.dispose();
    window.dispose();
    workspace.dispose();
    if (directory.existsSync()) await directory.delete(recursive: true);
  }
}

Future<_SettingsHarness> _createHarness({
  DataTransferGateway? gateway,
  DataTransferFilePicker? picker,
  AppDataRepository? repository,
}) async {
  final root = Directory.current.absolute;
  final directory = Directory(
    '${root.path}${Platform.pathSeparator}build${Platform.pathSeparator}test_settings_transfer_${DateTime.now().microsecondsSinceEpoch}',
  );
  final settings = SettingsController(repository: InMemorySettingsRepository());
  await settings.initialize();
  final window = WindowController(desktopService: FakeDesktopWindowService());
  await window.initialize();
  final workspace = WorkspaceController(repository: repository);
  await workspace.initialize();
  final backup = BackupService(directory: directory);
  final dataDirectory = FakeDataDirectoryService(directory: directory);
  final transfer = gateway == null || picker == null
      ? null
      : DataTransferController(
          workspace: workspace,
          service: gateway,
          filePicker: picker,
        );
  return _SettingsHarness(
    directory: directory,
    settings: settings,
    window: window,
    workspace: workspace,
    backup: backup,
    dataDirectory: dataDirectory,
    transfer: transfer,
  );
}

Future<void> _pumpSettings(
  WidgetTester tester,
  _SettingsHarness harness, {
  Size size = const Size(860, 860),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ShadApp(
      theme: AppTheme.lightFor(),
      home: SettingsScope(
        settingsController: harness.settings,
        backupService: harness.backup,
        dataTransferController: harness.transfer,
        workspaceController: harness.workspace,
        windowController: harness.window,
        dataDirectoryService: harness.dataDirectory,
        child: const SettingsPage(),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
}

AppData _candidateData() {
  return AppData(
    schemaVersion: AppData.currentSchemaVersion,
    revision: 3,
    projects: const <Project>[],
    todos: <TodoItem>[
      TodoItem(
        id: 'imported-todo',
        projectId: null,
        parentId: null,
        title: 'imported',
        completed: false,
        completedAt: null,
        sortOrder: 10,
        collapsed: false,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    ],
    trash: const <TrashItem>[],
  );
}

void main() {
  test('data transfer test doubles stay plugin-free', () {
    expect(_FakePicker().importCalls, 0);
    expect(_FakeGateway().readCalls, 0);
  });

  testWidgets('embedded settings keeps transfer controls disabled', (
    tester,
  ) async {
    final harness = await _createHarness();
    addTearDown(harness.dispose);
    await _pumpSettings(tester, harness);
    final exportButton = tester.widget<ShadButton>(
      find.byKey(const ValueKey<String>('settings-export-data')),
    );
    final importButton = tester.widget<ShadButton>(
      find.byKey(const ValueKey<String>('settings-import-data')),
    );
    expect(exportButton.enabled, isFalse);
    expect(importButton.enabled, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings scope preserves the injected transfer instance', (
    tester,
  ) async {
    final picker = _FakePicker()..exportPath = 'export.json';
    final gateway = _FakeGateway();
    final harness = await _createHarness(gateway: gateway, picker: picker);
    addTearDown(harness.dispose);
    DataTransferController? observed;
    await tester.pumpWidget(
      ShadApp(
        theme: AppTheme.lightFor(),
        home: SettingsScope(
          settingsController: harness.settings,
          backupService: harness.backup,
          dataTransferController: harness.transfer,
          workspaceController: harness.workspace,
          windowController: harness.window,
          dataDirectoryService: harness.dataDirectory,
          child: Builder(
            builder: (context) {
              observed = SettingsScope.of(context).dataTransferController;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    expect(observed, same(harness.transfer));
    expect(harness.transfer!.workspace, same(harness.workspace));
  });

  testWidgets('LiteTodoApp forwards the same transfer controller to settings', (
    tester,
  ) async {
    final picker = _FakePicker()..exportPath = 'export.json';
    final gateway = _FakeGateway();
    final harness = await _createHarness(gateway: gateway, picker: picker);
    addTearDown(harness.dispose);
    final navigation = AppNavigationController();
    final quickAdd = QuickAddController(windowController: harness.window);
    addTearDown(() {
      quickAdd.dispose();
      navigation.dispose();
    });
    await tester.binding.setSurfaceSize(const Size(860, 860));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      LiteTodoApp(
        controller: harness.workspace,
        windowController: harness.window,
        quickAddController: quickAdd,
        navigationController: navigation,
        settingsController: harness.settings,
        backupService: harness.backup,
        dataTransferController: harness.transfer,
        dataDirectoryService: harness.dataDirectory,
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final scope = tester.widget<SettingsScope>(find.byType(SettingsScope));
    expect(scope.dataTransferController, same(harness.transfer));
    expect(tester.takeException(), isNull);
  });

  testWidgets('import confirmation cancellation never opens the picker', (
    tester,
  ) async {
    final picker = _FakePicker()..importPath = 'import.json';
    final gateway = _FakeGateway(importedData: _candidateData());
    final harness = await _createHarness(gateway: gateway, picker: picker);
    addTearDown(harness.dispose);
    await _pumpSettings(tester, harness);
    final importFinder = find.byKey(
      const ValueKey<String>('settings-import-data'),
    );
    await _scrollTo(tester, importFinder);
    await tester.tap(importFinder);
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('settings-import-confirm-dialog')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('settings-import-cancel')),
    );
    await tester.pumpAndSettle();
    expect(picker.importCalls, 0);
    expect(gateway.readCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('picker cancellation leaves data unchanged and no error banner', (
    tester,
  ) async {
    final picker = _FakePicker();
    final gateway = _FakeGateway(importedData: _candidateData());
    final harness = await _createHarness(gateway: gateway, picker: picker);
    addTearDown(harness.dispose);
    await _pumpSettings(tester, harness);
    final revision = harness.workspace.revision;
    final importFinder = find.byKey(
      const ValueKey<String>('settings-import-data'),
    );
    await _scrollTo(tester, importFinder);
    await tester.tap(importFinder);
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('settings-import-confirm')),
    );
    await tester.pumpAndSettle();
    expect(picker.importCalls, 1);
    expect(harness.workspace.revision, revision);
    expect(find.text('数据导入或导出未完成，原数据保持不变。'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('export success exposes the stable result message', (
    tester,
  ) async {
    final picker = _FakePicker()..exportPath = 'export.json';
    final gateway = _FakeGateway();
    final harness = await _createHarness(gateway: gateway, picker: picker);
    addTearDown(harness.dispose);
    await _pumpSettings(tester, harness);
    final exportFinder = find.byKey(
      const ValueKey<String>('settings-export-data'),
    );
    await _scrollTo(tester, exportFinder);
    await tester.tap(exportFinder);
    await tester.pumpAndSettle();
    final banner = tester
        .widgetList<StatusBanner>(find.byType(StatusBanner))
        .singleWhere(
          (entry) =>
              entry.message == const DataTransferResult.success().message,
        );
    expect(banner.error, isFalse);
    expect(picker.exportCalls, 1);
    expect(gateway.exportCalls, 1);
  });

  testWidgets('export failure renders DataTransferResult.message', (
    tester,
  ) async {
    final picker = _FakePicker()..exportPath = 'export.json';
    final gateway = _FakeGateway()
      ..exportError = DataTransferErrorCode.targetWriteFailed;
    final harness = await _createHarness(gateway: gateway, picker: picker);
    addTearDown(harness.dispose);
    await _pumpSettings(tester, harness);
    final exportFinder = find.byKey(
      const ValueKey<String>('settings-export-data'),
    );
    await _scrollTo(tester, exportFinder);
    await tester.tap(exportFinder);
    await tester.pumpAndSettle();
    final expected = DataTransferResult.failure(
      DataTransferErrorCode.targetWriteFailed,
    );
    final banner = tester
        .widgetList<StatusBanner>(find.byType(StatusBanner))
        .singleWhere((entry) => entry.message == expected.message);
    expect(banner.error, isTrue);
  });

  testWidgets('import success replaces data and reports completion', (
    tester,
  ) async {
    final repository = _WorkspaceRepository(WorkspaceController().appData);
    final picker = _FakePicker()..importPath = 'import.json';
    final gateway = _FakeGateway(importedData: _candidateData());
    final harness = await _createHarness(
      gateway: gateway,
      picker: picker,
      repository: repository,
    );
    addTearDown(harness.dispose);
    await _pumpSettings(tester, harness);
    final importFinder = find.byKey(
      const ValueKey<String>('settings-import-data'),
    );
    await _scrollTo(tester, importFinder);
    await tester.tap(importFinder);
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('settings-import-confirm')),
    );
    await tester.pumpAndSettle();
    expect(harness.workspace.todos.single.title, 'imported');
    expect(repository.saveCalls, greaterThan(0));
    expect(
      find.text(const DataTransferResult.success().message),
      findsOneWidget,
    );
  });

  testWidgets('busy state prevents a second export operation', (tester) async {
    final picker = _FakePicker()..exportPath = 'export.json';
    final gateway = _FakeGateway()..exportGate = Completer<void>();
    final harness = await _createHarness(gateway: gateway, picker: picker);
    addTearDown(harness.dispose);
    await _pumpSettings(tester, harness);
    final exportFinder = find.byKey(
      const ValueKey<String>('settings-export-data'),
    );
    await _scrollTo(tester, exportFinder);
    await tester.tap(exportFinder);
    await tester.pump();
    expect(picker.exportCalls, 1);
    expect(gateway.exportCalls, 1);
    expect(tester.widget<ShadButton>(exportFinder).enabled, isFalse);
    await tester.tap(exportFinder);
    expect(picker.exportCalls, 1);
    expect(gateway.exportCalls, 1);
    gateway.exportGate!.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<ShadButton>(exportFinder).enabled, isTrue);
  });

  testWidgets('workspace recovery warning is shown once and dismissible', (
    tester,
  ) async {
    final repository = _WorkspaceRepository(
      WorkspaceController().appData,
      recoveryWarning: 'previous snapshot restored',
    );
    final harness = await _createHarness(repository: repository);
    addTearDown(harness.dispose);
    await _pumpSettings(tester, harness);
    final warning = find.byKey(
      const ValueKey<String>('settings-recovery-warning'),
    );
    await _scrollTo(tester, warning);
    expect(warning, findsOneWidget);
    expect(find.textContaining('previous snapshot restored'), findsOneWidget);
    await tester.tap(
      find.descendant(of: warning, matching: find.byIcon(AppIcons.windowClose)),
    );
    await tester.pump();
    expect(warning, findsNothing);
  });
}
