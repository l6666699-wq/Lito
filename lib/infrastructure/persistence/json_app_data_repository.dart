import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/models/app_data.dart';
import 'app_data_repository.dart';
import 'safe_file_writer.dart';

/// JSON implementation of [AppDataRepository].
///
/// Tests can pass an explicit [directory].  Production should use the default
/// constructor, which resolves the Application Support directory through
/// path_provider and creates a dedicated `LiteTodo` child directory.
class JsonAppDataRepository implements AppDataRepository {
  JsonAppDataRepository({
    Directory? directory,
    this.appDirectoryName = 'LiteTodo',
    SafeFileWriter? writer,
  }) : _directory = directory, // ignore: prefer_initializing_formals
       _writer = writer ?? const SafeFileWriter();

  final Directory? _directory;
  final String appDirectoryName;
  final SafeFileWriter _writer;
  Future<void> _writeTail = Future<void>.value();

  Future<Directory> get dataDirectory async {
    final directory =
        _directory ??
        _resolveEnvironmentDirectory() ??
        Directory(
          '${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}$appDirectoryName',
        );
    await directory.create(recursive: true);
    return directory;
  }

  Future<File> get dataFile async =>
      File('${(await dataDirectory).path}${Platform.pathSeparator}data.json');

  Future<File> get previousFile async => File(
    '${(await dataDirectory).path}${Platform.pathSeparator}data.prev.json',
  );

  Future<File> get temporaryFile async =>
      File('${(await dataDirectory).path}${Platform.pathSeparator}data.tmp');

  @override
  Future<AppDataLoadResult> load() async {
    // A caller cannot observe a half-finished save through this repository.
    await _writeTail;
    final primary = await _readValid(await dataFile);
    if (primary != null) {
      return AppDataLoadResult(
        data: primary,
        source: AppDataLoadSource.primary,
      );
    }

    final previous = await _readValid(await previousFile);
    if (previous != null) {
      return AppDataLoadResult(
        data: previous,
        source: AppDataLoadSource.previous,
        recoveryWarning: '主数据文件无效，已从 data.prev.json 恢复；原文件保持不变。',
      );
    }

    final hasPrimary = await (await dataFile).exists();
    final hasPrevious = await (await previousFile).exists();
    final warning = hasPrimary || hasPrevious
        ? 'LiteTodo 数据文件无法解析，已创建空数据；原文件保持不变。'
        : null;
    return AppDataLoadResult(
      data: AppData.empty(),
      source: AppDataLoadSource.empty,
      recoveryWarning: warning,
    );
  }

  @override
  Future<void> save(AppData snapshot) {
    final operation = _writeTail.then<void>((_) => _saveNow(snapshot));
    _writeTail = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return operation;
  }

  Future<void> _saveNow(AppData snapshot) async {
    if (snapshot.schemaVersion != AppData.currentSchemaVersion) {
      throw StateError('Unsupported schemaVersion ${snapshot.schemaVersion}');
    }
    if (snapshot.revision < 0) {
      throw StateError('revision must be non-negative');
    }
    final encoded = jsonEncode(snapshot.toJson());
    await _writer.writeJson(
      await dataFile,
      encoded,
      validator: (contents) {
        final decoded = jsonDecode(contents);
        if (decoded is! Map) throw const FormatException('JSON root must map');
        AppData.fromJson(Map<String, dynamic>.from(decoded));
      },
    );
  }

  Future<AppData?> _readValid(File file) async {
    try {
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) throw const FormatException('JSON root must map');
      return AppData.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  Directory? _resolveEnvironmentDirectory() {
    return resolveLiteTodoDataDirectoryOverride(
      Platform.environment['LITETODO_DATA_DIR'],
    );
  }
}

/// Production bootstrap helper kept outside the application layer.
Future<JsonAppDataRepository> createDefaultAppDataRepository() async {
  if (Platform.environment['LITETODO_DATA_DIR']?.trim().isNotEmpty == true) {
    return JsonAppDataRepository();
  }
  // Resolving the provider here validates availability before the app starts,
  // while JsonAppDataRepository still owns the filesystem details.
  final support = await getApplicationSupportDirectory();
  return JsonAppDataRepository(
    directory: Directory('${support.path}${Platform.pathSeparator}LiteTodo'),
  );
}

bool _isAbsolutePath(String path) {
  if (path.startsWith('/') || path.startsWith('\\')) return true;
  return path.length >= 3 && RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path);
}

/// Resolves the optional process-only data directory override.  It is exposed
/// as a pure helper so tests can verify path validation without mutating the
/// host process environment.
Directory? resolveLiteTodoDataDirectoryOverride(String? value) {
  final override = value?.trim();
  if (override == null || override.isEmpty) return null;
  if (!_isAbsolutePath(override)) {
    throw StateError('LITETODO_DATA_DIR must be an absolute path');
  }
  return Directory(override);
}
