import 'dart:convert';
import 'dart:io';

import '../../application/data_transfer_gateway.dart';
import '../../domain/models/app_data.dart';
import '../../domain/models/project.dart';
import '../../domain/models/todo_item.dart';
import '../../domain/services/todo_tree_service.dart';
import 'backup_catalog.dart';
import 'backup_service.dart';

/// Small filesystem seam used to verify replacement rollback without broad
/// deletion or platform-specific test hacks.
class DataTransferFileOperations {
  Future<File> copy(File source, String target) => source.copy(target);

  Future<File> rename(File source, String target) => source.rename(target);

  Future<void> delete(File file) => file.delete();

  Future<void> validate(
    File file,
    Future<void> Function(File file) validator,
  ) => validator(file);
}

/// Persistence-only implementation of the data transfer workflow.
class DataTransferService implements DataTransferGateway {
  DataTransferService({
    required this.backupService,
    DataTransferFileOperations? fileOperations,
  }) : _fileOperations = fileOperations ?? DataTransferFileOperations();

  final BackupService backupService;
  final DataTransferFileOperations _fileOperations;

  @override
  Future<DataTransferDocument> readImportFile(String path) async {
    final file = await _trustedFile(path, source: true);
    final raw = await _readUtf8(file);
    final decoded = _decodeJson(raw);
    if (decoded is! Map) {
      throw const DataTransferException(DataTransferErrorCode.invalidRoot);
    }
    final source = Map<String, dynamic>.from(decoded);
    final schemaVersion = _readSchemaVersion(source);
    if (schemaVersion > AppData.currentSchemaVersion || schemaVersion < 1) {
      throw const DataTransferException(
        DataTransferErrorCode.unsupportedSchemaVersion,
      );
    }
    final data = _decodeAppData(source);
    _validateStructure(data);
    return DataTransferDocument(
      raw: raw,
      data: data,
      schemaVersion: schemaVersion,
    );
  }

  @override
  Future<void> exportData(AppData snapshot, String path) async {
    if (snapshot.schemaVersion != AppData.currentSchemaVersion ||
        snapshot.revision < 0) {
      throw const DataTransferException(DataTransferErrorCode.invalidData);
    }
    _validateStructure(snapshot);
    final target = await _trustedFile(path, source: false);
    final encoded = jsonEncode(snapshot.toJson());
    final temporary = File('${target.path}.litetodo-export.tmp');
    final rollback = File('${target.path}.litetodo-export.rollback');
    await _ensureScratchIsUnused(temporary);
    await _ensureScratchIsUnused(rollback);
    var createdRollback = false;
    var installed = false;
    var preserveRollback = false;
    try {
      await temporary.writeAsString(encoded, encoding: utf8, flush: true);
      await _fileOperations.validate(temporary, _validateEncodedFile);
      if (await target.exists()) {
        await _fileOperations.copy(target, rollback.path);
        createdRollback = true;
      }
      if (await target.exists()) await _fileOperations.delete(target);
      await _fileOperations.rename(temporary, target.path);
      installed = true;
      await _fileOperations.validate(target, _validateEncodedFile);
      installed = false;
      if (createdRollback) await _fileOperations.delete(rollback);
    } catch (_) {
      if (createdRollback) {
        try {
          if (await target.exists()) await _fileOperations.delete(target);
          await _fileOperations.rename(rollback, target.path);
          createdRollback = false;
        } catch (_) {
          // Preserve the original error.  The strict rollback path only
          // touches the exact sibling created above.
          preserveRollback = true;
        }
      } else if (installed) {
        try {
          if (await target.exists()) await _fileOperations.delete(target);
        } catch (_) {
          // Preserve the original error and never delete another path.
        }
      }
      throw const DataTransferException(
        DataTransferErrorCode.targetWriteFailed,
      );
    } finally {
      await _deleteScratchIfOwned(temporary);
      if (createdRollback && !preserveRollback) {
        await _deleteScratchIfOwned(rollback);
      }
    }
  }

  @override
  Future<File> createManualBackup() async {
    try {
      return await backupService.createManualBackup();
    } catch (_) {
      throw const DataTransferException(DataTransferErrorCode.backupFailed);
    }
  }

  @override
  Future<void> createMigrationBackup(String raw) async {
    try {
      final directory = await backupService.dataDirectory;
      final backup = await BackupCatalog(
        dataDirectory: directory,
      ).createMigrationBackup(raw);
      if (backup == null) {
        throw const DataTransferException(
          DataTransferErrorCode.migrationBackupFailed,
        );
      }
    } on DataTransferException {
      rethrow;
    } catch (_) {
      throw const DataTransferException(
        DataTransferErrorCode.migrationBackupFailed,
      );
    }
  }

  Future<File> _trustedFile(String path, {required bool source}) async {
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      throw DataTransferException(
        source
            ? DataTransferErrorCode.sourceUnavailable
            : DataTransferErrorCode.invalidTarget,
      );
    }
    final file = File(trimmed);
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type == FileSystemEntityType.link ||
        type != FileSystemEntityType.file) {
      if (source) {
        throw const DataTransferException(
          DataTransferErrorCode.sourceUnavailable,
        );
      }
      if (type == FileSystemEntityType.directory ||
          type == FileSystemEntityType.link) {
        throw const DataTransferException(DataTransferErrorCode.invalidTarget);
      }
    }
    if (source && type != FileSystemEntityType.file) {
      throw const DataTransferException(
        DataTransferErrorCode.sourceUnavailable,
      );
    }
    return file;
  }

  Future<String> _readUtf8(File file) async {
    try {
      return utf8.decode(await file.readAsBytes(), allowMalformed: false);
    } on FormatException {
      throw const DataTransferException(DataTransferErrorCode.invalidUtf8);
    } on FileSystemException {
      throw const DataTransferException(
        DataTransferErrorCode.sourceUnavailable,
      );
    }
  }

  Object? _decodeJson(String raw) {
    try {
      return jsonDecode(raw);
    } on FormatException {
      throw const DataTransferException(DataTransferErrorCode.invalidJson);
    }
  }

  AppData _decodeAppData(Map<String, dynamic> source) {
    try {
      return AppData.fromJson(source);
    } on Object {
      throw const DataTransferException(DataTransferErrorCode.invalidData);
    }
  }

  int _readSchemaVersion(Map<String, dynamic> source) {
    if (!source.containsKey('schemaVersion')) {
      throw const DataTransferException(
        DataTransferErrorCode.missingSchemaVersion,
      );
    }
    final value = source['schemaVersion'];
    if (value is int) return value;
    if (value is num && value == value.toInt()) return value.toInt();
    throw const DataTransferException(
      DataTransferErrorCode.unsupportedSchemaVersion,
    );
  }

  Future<void> _validateEncodedFile(File file) async {
    try {
      final raw = utf8.decode(await file.readAsBytes(), allowMalformed: false);
      final decoded = _decodeJson(raw);
      if (decoded is! Map) {
        throw const DataTransferException(DataTransferErrorCode.invalidRoot);
      }
      final source = Map<String, dynamic>.from(decoded);
      final version = _readSchemaVersion(source);
      if (version != AppData.currentSchemaVersion) {
        throw const DataTransferException(
          DataTransferErrorCode.unsupportedSchemaVersion,
        );
      }
      _validateStructure(_decodeAppData(source));
    } on DataTransferException {
      rethrow;
    } catch (_) {
      throw const DataTransferException(
        DataTransferErrorCode.targetWriteFailed,
      );
    }
  }

  Future<void> _ensureScratchIsUnused(File file) async {
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type != FileSystemEntityType.notFound) {
      throw const DataTransferException(
        DataTransferErrorCode.targetWriteFailed,
      );
    }
  }

  Future<void> _deleteScratchIfOwned(File file) async {
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type == FileSystemEntityType.file) {
      await _fileOperations.delete(file);
    }
  }

  static void _validateStructure(AppData data) {
    final ids = <String>{};
    void addId(String id) {
      if (id.trim().isEmpty || !ids.add(id)) {
        throw const DataTransferException(DataTransferErrorCode.invalidData);
      }
    }

    for (final group in data.groups) {
      addId(group.id);
    }
    final groupIds = data.groups.map((group) => group.id).toSet();
    for (final project in data.projects) {
      addId(project.id);
      if (project.groupId != null && !groupIds.contains(project.groupId)) {
        throw const DataTransferException(DataTransferErrorCode.invalidData);
      }
    }
    final projectIds = data.projects.map((project) => project.id).toSet();
    final todoById = <String, TodoItem>{};
    for (final todo in data.todos) {
      addId(todo.id);
      if (todo.title.trim().isEmpty ||
          (todo.projectId != null && !projectIds.contains(todo.projectId)) ||
          (todo.groupId != null && !groupIds.contains(todo.groupId)) ||
          (todo.projectId != null && todo.groupId != null)) {
        throw const DataTransferException(DataTransferErrorCode.invalidData);
      }
      if (todoById.containsKey(todo.id)) {
        throw const DataTransferException(DataTransferErrorCode.invalidData);
      }
      todoById[todo.id] = todo;
    }
    for (final todo in data.todos) {
      if (todo.parentId != null && !todoById.containsKey(todo.parentId)) {
        throw const DataTransferException(DataTransferErrorCode.invalidData);
      }
      final parent = todo.parentId == null ? null : todoById[todo.parentId];
      if (parent != null &&
          (parent.projectId != todo.projectId ||
              parent.groupId != todo.groupId)) {
        throw const DataTransferException(DataTransferErrorCode.invalidData);
      }
    }
    _validateTree(todoById);
    for (final trash in data.trash) {
      addId(trash.id);
      _validateTrash(trash);
    }
  }

  static void _validateTree(Map<String, TodoItem> todos) {
    final visiting = <String>{};
    final depths = <String, int>{};
    int depthOf(String id) {
      final known = depths[id];
      if (known != null) return known;
      if (!visiting.add(id)) {
        throw const DataTransferException(DataTransferErrorCode.invalidData);
      }
      final parent = todos[id]!.parentId;
      final depth = parent == null ? 1 : depthOf(parent) + 1;
      visiting.remove(id);
      if (depth > TodoTreeService.maxTreeDepth) {
        throw const DataTransferException(DataTransferErrorCode.invalidData);
      }
      depths[id] = depth;
      return depth;
    }

    for (final id in todos.keys) {
      depthOf(id);
    }
  }

  static void _validateTrash(TrashItem trash) {
    final payload = trash.payload;
    switch (trash.kind) {
      case 'todo_subtree':
        _validateTodoSubtree(payload);
      case 'project_subtree':
        _validateProjectSubtree(payload);
      default:
        throw const DataTransferException(DataTransferErrorCode.invalidData);
    }
  }

  static void _validateTodoSubtree(Map<String, dynamic> payload) {
    if (payload['rootId'] is! String ||
        payload['rootId'] == '' ||
        payload['todos'] is! List) {
      throw const DataTransferException(DataTransferErrorCode.invalidData);
    }
    final todos = _decodeTrashTodos(payload['todos'] as List);
    final ids = todos.map((todo) => todo.id).toSet();
    if (!ids.contains(payload['rootId'])) {
      throw const DataTransferException(DataTransferErrorCode.invalidData);
    }
    for (final todo in todos) {
      if (todo.parentId != null && !ids.contains(todo.parentId)) {
        throw const DataTransferException(DataTransferErrorCode.invalidData);
      }
      final parent = todo.parentId == null
          ? null
          : todos.firstWhere((entry) => entry.id == todo.parentId);
      if (parent != null &&
          (parent.projectId != todo.projectId ||
              parent.groupId != todo.groupId)) {
        throw const DataTransferException(DataTransferErrorCode.invalidData);
      }
    }
    _validateTree({for (final todo in todos) todo.id: todo});
  }

  static void _validateProjectSubtree(Map<String, dynamic> payload) {
    final rawProject = payload['project'];
    if (rawProject is! Map || payload['todos'] is! List) {
      throw const DataTransferException(DataTransferErrorCode.invalidData);
    }
    final project = _decodeTrashProject(Map<String, dynamic>.from(rawProject));
    final todos = _decodeTrashTodos(payload['todos'] as List, allowEmpty: true);
    final ids = todos.map((todo) => todo.id).toSet();
    for (final todo in todos) {
      if (todo.projectId != project.id ||
          todo.groupId != null ||
          (todo.parentId != null && !ids.contains(todo.parentId))) {
        throw const DataTransferException(DataTransferErrorCode.invalidData);
      }
      if (todo.parentId != null) {
        final parent = todos.firstWhere((entry) => entry.id == todo.parentId);
        if (parent.projectId != todo.projectId ||
            parent.groupId != todo.groupId) {
          throw const DataTransferException(DataTransferErrorCode.invalidData);
        }
      }
    }
    _validateTree({for (final todo in todos) todo.id: todo});
  }

  static List<TodoItem> _decodeTrashTodos(List raw, {bool allowEmpty = false}) {
    final result = <TodoItem>[];
    final ids = <String>{};
    for (final entry in raw) {
      if (entry is! Map) {
        throw const DataTransferException(DataTransferErrorCode.invalidData);
      }
      final todo = _decodeTrashTodo(Map<String, dynamic>.from(entry));
      if (todo.id.isEmpty || todo.title.trim().isEmpty || !ids.add(todo.id)) {
        throw const DataTransferException(DataTransferErrorCode.invalidData);
      }
      result.add(todo);
    }
    if (result.isEmpty && !allowEmpty) {
      throw const DataTransferException(DataTransferErrorCode.invalidData);
    }
    return result;
  }

  static TodoItem _decodeTrashTodo(Map<String, dynamic> source) {
    try {
      return TodoItem.fromJson(source);
    } on Object {
      throw const DataTransferException(DataTransferErrorCode.invalidData);
    }
  }

  static Project _decodeTrashProject(Map<String, dynamic> source) {
    try {
      final project = Project.fromJson(source);
      if (project.id.isEmpty || project.name.trim().isEmpty) {
        throw const DataTransferException(DataTransferErrorCode.invalidData);
      }
      return project;
    } on DataTransferException {
      rethrow;
    } on Object {
      throw const DataTransferException(DataTransferErrorCode.invalidData);
    }
  }
}
