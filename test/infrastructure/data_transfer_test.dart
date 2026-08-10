import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:litetodo/application/data_transfer_controller.dart';
import 'package:litetodo/application/data_transfer_file_picker.dart';
import 'package:litetodo/application/workspace_controller.dart';
import 'package:litetodo/domain/models/app_data.dart';
import 'package:litetodo/domain/models/project.dart';
import 'package:litetodo/domain/models/todo_item.dart';
import 'package:litetodo/infrastructure/persistence/app_data_repository.dart';
import 'package:litetodo/infrastructure/persistence/backup_catalog.dart';
import 'package:litetodo/infrastructure/persistence/backup_service.dart';
import 'package:litetodo/application/data_transfer_gateway.dart';
import 'package:litetodo/infrastructure/persistence/data_transfer_service.dart';
import 'package:litetodo/infrastructure/persistence/json_app_data_repository.dart';

Future<Directory> _temporaryDirectory() =>
    Directory.systemTemp.createTemp('litetodo-transfer-');

Future<void> _writeJson(File file, Object value) async {
  await file.parent.create(recursive: true);
  await file.writeAsString(
    value is String ? value : jsonEncode(value),
    encoding: utf8,
    flush: true,
  );
}

AppData _data(int revision, {String title = 'candidate'}) {
  return AppData(
    schemaVersion: AppData.currentSchemaVersion,
    revision: revision,
    projects: const <Project>[],
    todos: <TodoItem>[
      TodoItem(
        id: 'todo-1',
        projectId: null,
        parentId: null,
        title: title,
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

Map<String, dynamic> _v1Json(int revision, {String title = 'v1'}) {
  final json = _data(revision, title: title).toJson();
  json['schemaVersion'] = 1;
  json.remove('groups');
  return json;
}

class _FakePicker implements DataTransferFilePicker {
  _FakePicker();

  String? importPath;
  String? exportPath;
  bool throwOnImport = false;
  bool throwOnExport = false;

  @override
  Future<String?> pickImportFile() async {
    if (throwOnImport) throw StateError('picker');
    return importPath;
  }

  @override
  Future<String?> pickExportFile() async {
    if (throwOnExport) throw StateError('picker');
    return exportPath;
  }
}

class _MemoryRepository implements AppDataRepository {
  _MemoryRepository(this.snapshot);

  AppData snapshot;
  bool failNextSave = false;
  int saveCalls = 0;

  @override
  Future<AppDataLoadResult> load() async =>
      AppDataLoadResult(data: snapshot, source: AppDataLoadSource.primary);

  @override
  Future<void> save(AppData next) async {
    saveCalls += 1;
    if (failNextSave) {
      failNextSave = false;
      throw StateError('controlled save failure');
    }
    snapshot = next;
  }
}

class _FailRollbackOperations extends DataTransferFileOperations {
  _FailRollbackOperations(this.targetPath);

  final String targetPath;
  bool failTargetValidation = true;
  bool failRollbackRename = true;

  @override
  Future<void> validate(File file, Future<void> Function(File file) validator) {
    if (failTargetValidation && file.path == targetPath) {
      failTargetValidation = false;
      throw const FormatException('controlled target validation failure');
    }
    return validator(file);
  }

  @override
  Future<File> rename(File source, String target) {
    if (failRollbackRename &&
        source.path.endsWith('.litetodo-export.rollback')) {
      failRollbackRename = false;
      throw const FileSystemException('controlled rollback failure');
    }
    return super.rename(source, target);
  }
}

class _MigrationFailureGateway implements DataTransferGateway {
  _MigrationFailureGateway(this.delegate);

  final DataTransferService delegate;
  bool manualBackupCalled = false;

  @override
  Future<DataTransferDocument> readImportFile(String path) =>
      delegate.readImportFile(path);

  @override
  Future<void> exportData(AppData snapshot, String path) =>
      delegate.exportData(snapshot, path);

  @override
  Future<void> createManualBackup() async {
    manualBackupCalled = true;
    await delegate.createManualBackup();
  }

  @override
  Future<void> createMigrationBackup(String raw) {
    throw const DataTransferException(
      DataTransferErrorCode.migrationBackupFailed,
    );
  }
}

Future<
  ({
    Directory directory,
    WorkspaceController workspace,
    DataTransferController transfer,
    DataTransferService service,
    _FakePicker picker,
  })
>
_setup() async {
  final directory = await _temporaryDirectory();
  final repository = JsonAppDataRepository(directory: directory);
  // Seed this transfer harness explicitly; production first-run initialization
  // now persists an empty snapshot instead of an implicit sample dataset.
  final initial = _data(1, title: 'initial');
  await repository.save(initial);
  final workspace = WorkspaceController(repository: repository);
  await workspace.initialize();
  if (workspace.appData != initial) {
    throw StateError('Unexpected setup snapshot');
  }
  final service = DataTransferService(
    backupService: BackupService(directory: directory),
  );
  final picker = _FakePicker();
  final transfer = DataTransferController(
    workspace: workspace,
    service: service,
    filePicker: picker,
  );
  return (
    directory: directory,
    workspace: workspace,
    transfer: transfer,
    service: service,
    picker: picker,
  );
}

void main() {
  test('picker cancellation is a no-op for import and export', () async {
    final setup = await _setup();
    addTearDown(() => setup.directory.delete(recursive: true));
    final resultExport = await setup.transfer.exportData();
    final resultImport = await setup.transfer.importData();
    expect(resultExport.isCancelled, isTrue);
    expect(resultImport.isCancelled, isTrue);
    expect(setup.workspace.revision, 1);
    expect(
      await BackupCatalog(dataDirectory: setup.directory).listBackups(),
      isEmpty,
    );
  });

  test('picker failure returns pickerFailed without changing data', () async {
    final setup = await _setup();
    addTearDown(() => setup.directory.delete(recursive: true));
    setup.picker.throwOnExport = true;
    final export = await setup.transfer.exportData();
    setup.picker.throwOnExport = false;
    setup.picker.throwOnImport = true;
    final import = await setup.transfer.importData();
    expect(export.errorCode, DataTransferErrorCode.pickerFailed);
    expect(import.errorCode, DataTransferErrorCode.pickerFailed);
    expect(setup.workspace.revision, 1);
    expect(
      await BackupCatalog(dataDirectory: setup.directory).listBackups(),
      isEmpty,
    );
  });

  test(
    'export writes complete UTF-8 JSON and round trips through validator',
    () async {
      final setup = await _setup();
      addTearDown(() => setup.directory.delete(recursive: true));
      final target = File(
        '${setup.directory.path}${Platform.pathSeparator}out.json',
      );
      await _writeJson(target, '{"old":true}');
      setup.picker.exportPath = target.path;
      final result = await setup.transfer.exportData();
      expect(result.isSuccess, isTrue);
      final decoded = await setup.service.readImportFile(target.path);
      expect(decoded.data, setup.workspace.appData);
      expect(
        utf8.decode(await target.readAsBytes()),
        contains('schemaVersion'),
      );
    },
  );

  test('invalid UTF-8, JSON, root and schema never create a backup', () async {
    final setup = await _setup();
    addTearDown(() => setup.directory.delete(recursive: true));
    final cases =
        <({List<int>? bytes, Object? value, DataTransferErrorCode code})>[
          (
            bytes: <int>[0xff, 0xfe],
            value: null,
            code: DataTransferErrorCode.invalidUtf8,
          ),
          (
            bytes: null,
            value: '{broken',
            code: DataTransferErrorCode.invalidJson,
          ),
          (
            bytes: null,
            value: <Object>[],
            code: DataTransferErrorCode.invalidRoot,
          ),
          (
            bytes: null,
            value: <String, dynamic>{'revision': 1},
            code: DataTransferErrorCode.missingSchemaVersion,
          ),
          (
            bytes: null,
            value: <String, dynamic>{'schemaVersion': 3},
            code: DataTransferErrorCode.unsupportedSchemaVersion,
          ),
        ];
    for (var index = 0; index < cases.length; index += 1) {
      final source = File(
        '${setup.directory.path}${Platform.pathSeparator}source-$index.json',
      );
      final item = cases[index];
      if (item.bytes != null) {
        await source.writeAsBytes(item.bytes!, flush: true);
      } else {
        await _writeJson(source, item.value!);
      }
      final result = await setup.transfer.importFromPath(source.path);
      expect(result.errorCode, item.code);
      expect(setup.workspace.revision, 1);
    }
    expect(
      await BackupCatalog(dataDirectory: setup.directory).listBackups(),
      isEmpty,
    );
  });

  test('structural invalid data is rejected before flush or backup', () async {
    final setup = await _setup();
    addTearDown(() => setup.directory.delete(recursive: true));
    final invalid = _data(90).toJson();
    final todos = invalid['todos']! as List<dynamic>;
    todos.add(Map<String, dynamic>.from(todos.single as Map));
    final source = File(
      '${setup.directory.path}${Platform.pathSeparator}duplicate.json',
    );
    await _writeJson(source, invalid);
    final result = await setup.transfer.importFromPath(source.path);
    expect(result.errorCode, DataTransferErrorCode.invalidData);
    expect(setup.workspace.revision, 1);
    expect(
      await BackupCatalog(dataDirectory: setup.directory).listBackups(),
      isEmpty,
    );
  });

  test(
    'cross-project parent and non-authoritative trash are rejected',
    () async {
      final setup = await _setup();
      addTearDown(() => setup.directory.delete(recursive: true));
      final projectOne = Project(
        id: 'project-one',
        name: 'One',
        iconKey: 'folder',
        colorKey: 'blue',
        sortOrder: 10,
        archived: false,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      final projectTwo = projectOne.copyWith(id: 'project-two', name: 'Two');
      final crossProject = _data(90).toJson();
      final root = Map<String, dynamic>.from(
        (crossProject['todos']! as List<dynamic>).single as Map,
      );
      root['projectId'] = projectOne.id;
      final child = Map<String, dynamic>.from(root)
        ..['id'] = 'todo-child'
        ..['projectId'] = projectTwo.id
        ..['parentId'] = root['id'];
      crossProject['projects'] = <Object>[
        projectOne.toJson(),
        projectTwo.toJson(),
      ];
      crossProject['todos'] = <Object>[root, child];
      final crossProjectFile = File(
        '${setup.directory.path}${Platform.pathSeparator}cross-project.json',
      );
      await _writeJson(crossProjectFile, crossProject);
      final crossProjectResult = await setup.transfer.importFromPath(
        crossProjectFile.path,
      );
      expect(crossProjectResult.errorCode, DataTransferErrorCode.invalidData);

      final invalidTrash = _data(91).toJson()
        ..['trash'] = <Object>[
          <String, dynamic>{
            'id': 'trash-1',
            'kind': 'todo',
            'payload': <String, dynamic>{'title': 'legacy'},
          },
        ];
      final invalidTrashFile = File(
        '${setup.directory.path}${Platform.pathSeparator}invalid-trash.json',
      );
      await _writeJson(invalidTrashFile, invalidTrash);
      final invalidTrashResult = await setup.transfer.importFromPath(
        invalidTrashFile.path,
      );
      expect(invalidTrashResult.errorCode, DataTransferErrorCode.invalidData);

      final damagedSubtree = _data(92).toJson()
        ..['trash'] = <Object>[
          <String, dynamic>{
            'id': 'trash-2',
            'kind': 'todo_subtree',
            'payload': <String, dynamic>{'rootId': 'todo-1'},
          },
        ];
      final damagedSubtreeFile = File(
        '${setup.directory.path}${Platform.pathSeparator}damaged-trash.json',
      );
      await _writeJson(damagedSubtreeFile, damagedSubtree);
      final damagedResult = await setup.transfer.importFromPath(
        damagedSubtreeFile.path,
      );
      expect(damagedResult.errorCode, DataTransferErrorCode.invalidData);
      expect(setup.workspace.revision, 1);
      expect(
        await BackupCatalog(dataDirectory: setup.directory).listBackups(),
        isEmpty,
      );
    },
  );

  test(
    'v1 import creates migration backup and writes v2 at a new revision',
    () async {
      final setup = await _setup();
      addTearDown(() => setup.directory.delete(recursive: true));
      final source = File(
        '${setup.directory.path}${Platform.pathSeparator}v1.json',
      );
      final raw = jsonEncode(_v1Json(99));
      await _writeJson(source, raw);
      final result = await setup.transfer.importFromPath(source.path);
      expect(result.isSuccess, isTrue);
      expect(setup.workspace.revision, 100);
      expect(
        setup.workspace.appData.schemaVersion,
        AppData.currentSchemaVersion,
      );
      final backups = await BackupCatalog(
        dataDirectory: setup.directory,
      ).listBackups();
      final migrations = backups
          .where(BackupCatalog.isMigrationBackup)
          .toList();
      expect(migrations, hasLength(1));
      expect(await migrations.single.readAsString(), raw);
    },
  );

  test(
    'v1 migration backup failure occurs after manual backup but before replace',
    () async {
      final setup = await _setup();
      addTearDown(() => setup.directory.delete(recursive: true));
      final dataFile = File(
        '${setup.directory.path}${Platform.pathSeparator}data.json',
      );
      final before = await dataFile.readAsString();
      final source = File(
        '${setup.directory.path}${Platform.pathSeparator}v1-failure.json',
      );
      await _writeJson(source, jsonEncode(_v1Json(200)));
      final delegate = DataTransferService(
        backupService: BackupService(directory: setup.directory),
      );
      final gateway = _MigrationFailureGateway(delegate);
      final transfer = DataTransferController(
        workspace: setup.workspace,
        service: gateway,
        filePicker: _FakePicker(),
      );
      final result = await transfer.importFromPath(source.path);
      expect(result.errorCode, DataTransferErrorCode.migrationBackupFailed);
      expect(gateway.manualBackupCalled, isTrue);
      expect(setup.workspace.revision, 1);
      expect(await dataFile.readAsString(), before);
      expect(
        (await BackupCatalog(dataDirectory: setup.directory).listBackups())
            .where((file) => !BackupCatalog.isMigrationBackup(file)),
        hasLength(1),
      );
    },
  );

  test('manual backup failure leaves memory and data file untouched', () async {
    final setup = await _setup();
    addTearDown(() => setup.directory.delete(recursive: true));
    final dataFile = File(
      '${setup.directory.path}${Platform.pathSeparator}data.json',
    );
    final before = await dataFile.readAsString();
    await _writeJson(
      File('${setup.directory.path}${Platform.pathSeparator}source.json'),
      _data(50).toJson(),
    );
    await _writeJson(
      File('${setup.directory.path}${Platform.pathSeparator}backups'),
      'not a directory',
    );
    final result = await setup.transfer.importFromPath(
      '${setup.directory.path}${Platform.pathSeparator}source.json',
    );
    expect(result.errorCode, DataTransferErrorCode.backupFailed);
    expect(setup.workspace.revision, 1);
    expect(await dataFile.readAsString(), before);
  });

  test(
    'save failure rolls back workspace selection and existing history',
    () async {
      final directory = await _temporaryDirectory();
      addTearDown(() => directory.delete(recursive: true));
      final seed = _data(4, title: 'before');
      final repository = _MemoryRepository(seed);
      final workspace = WorkspaceController(repository: repository);
      await workspace.initialize();
      workspace.selectSearch('before');
      workspace.createRootTodo('history entry');
      await workspace.flushNow();
      final before = workspace.appData;
      final undoCount = workspace.undoCount;
      await _writeJson(
        File('${directory.path}${Platform.pathSeparator}data.json'),
        before.toJson(),
      );
      final source = File(
        '${directory.path}${Platform.pathSeparator}source.json',
      );
      await _writeJson(source, _data(100, title: 'imported').toJson());
      repository.failNextSave = true;
      final transfer = DataTransferController(
        workspace: workspace,
        service: DataTransferService(
          backupService: BackupService(directory: directory),
        ),
        filePicker: _FakePicker(),
      );
      final result = await transfer.importFromPath(source.path);
      expect(result.errorCode, DataTransferErrorCode.targetWriteFailed);
      expect(workspace.appData, before);
      expect(workspace.undoCount, undoCount);
      expect(workspace.searchQuery, 'before');
      expect(repository.snapshot, before);
    },
  );

  test(
    'import revision advances from both lower and higher candidates',
    () async {
      Future<int> run(int candidateRevision) async {
        final setup = await _setup();
        addTearDown(() => setup.directory.delete(recursive: true));
        final source = File(
          '${setup.directory.path}${Platform.pathSeparator}source.json',
        );
        await _writeJson(source, _data(candidateRevision).toJson());
        final result = await setup.transfer.importFromPath(source.path);
        expect(result.isSuccess, isTrue);
        return setup.workspace.revision;
      }

      expect(await run(0), 2);
      expect(await run(100), 101);
    },
  );

  test(
    'successful import rebuilds selection and clears undo/redo history',
    () async {
      final setup = await _setup();
      addTearDown(() => setup.directory.delete(recursive: true));
      setup.workspace.selectProject('project-focus');
      setup.workspace.createRootTodo('history');
      await setup.workspace.flushNow();
      expect(setup.workspace.canUndo, isTrue);
      final source = File(
        '${setup.directory.path}${Platform.pathSeparator}empty.json',
      );
      await _writeJson(source, AppData.empty().toJson());
      final result = await setup.transfer.importFromPath(source.path);
      expect(result.isSuccess, isTrue);
      expect(setup.workspace.canUndo, isFalse);
      expect(setup.workspace.canRedo, isFalse);
      expect(setup.workspace.scope, WorkspaceScope.all);
      expect(setup.workspace.projectScopeId, isNull);
      expect(setup.workspace.searchQuery, isEmpty);
      expect(setup.workspace.todos, isEmpty);
    },
  );

  test(
    'concurrent imports are serialized by the transfer controller',
    () async {
      final setup = await _setup();
      addTearDown(() => setup.directory.delete(recursive: true));
      final first = File(
        '${setup.directory.path}${Platform.pathSeparator}first.json',
      );
      final second = File(
        '${setup.directory.path}${Platform.pathSeparator}second.json',
      );
      await _writeJson(first, _data(2, title: 'first').toJson());
      await _writeJson(second, _data(3, title: 'second').toJson());
      final results = await Future.wait(<Future<DataTransferResult>>[
        setup.transfer.importFromPath(first.path),
        setup.transfer.importFromPath(second.path),
      ]);
      expect(results.every((result) => result.isSuccess), isTrue);
      expect(setup.workspace.revision, 4);
      expect(
        (await BackupCatalog(dataDirectory: setup.directory).listBackups())
            .where((file) => !BackupCatalog.isMigrationBackup(file)),
        hasLength(2),
      );
    },
  );

  test(
    'failed target replacement keeps the rollback sibling when restore fails',
    () async {
      final directory = await _temporaryDirectory();
      addTearDown(() => directory.delete(recursive: true));
      final target = File(
        '${directory.path}${Platform.pathSeparator}existing.json',
      );
      await _writeJson(target, '{"old":true}');
      final operations = _FailRollbackOperations(target.path);
      final service = DataTransferService(
        backupService: BackupService(directory: directory),
        fileOperations: operations,
      );
      await expectLater(
        service.exportData(_data(1), target.path),
        throwsA(isA<DataTransferException>()),
      );
      final rollback = File('${target.path}.litetodo-export.rollback');
      expect(await rollback.exists(), isTrue);
      expect(await rollback.readAsString(), '{"old":true}');
    },
  );
}
