import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/models/app_data.dart';
import 'app_data_repository.dart';
import 'backup_catalog.dart';
import 'data_directory_resolver.dart';
import 'safe_file_writer.dart';

export 'data_directory_resolver.dart' show resolveLiteTodoDataDirectoryOverride;

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
    final directory = await dataDirectory;
    final catalog = BackupCatalog(dataDirectory: directory);
    final primaryFile = await dataFile;
    final primary = await _readCandidate(primaryFile, directory, catalog);
    if (primary != null) {
      return AppDataLoadResult(
        data: primary.data,
        source: AppDataLoadSource.primary,
      );
    }

    final previousFileRef = await previousFile;
    final previous = await _readCandidate(previousFileRef, directory, catalog);
    if (previous != null) {
      return AppDataLoadResult(
        data: previous.data,
        source: AppDataLoadSource.previous,
        recoveryWarning: '主数据文件无效，已从 data.prev.json 恢复；原文件保持不变。',
      );
    }

    final backups = await catalog.listBackups();
    for (final backup in backups) {
      final candidate = await _readCandidate(backup, directory, catalog);
      if (candidate == null) continue;
      return AppDataLoadResult(
        data: candidate.data,
        source: AppDataLoadSource.backup,
        recoveryWarning:
            '主数据文件与 data.prev.json 无效，已从备份 ${_safeBackupName(backup)} 恢复；原文件保持不变。',
      );
    }

    final hasPrimary = await primaryFile.exists();
    final hasPrevious = await previousFileRef.exists();
    final warning = hasPrimary || hasPrevious || backups.isNotEmpty
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
      throw StateError(
        'Only schemaVersion ${AppData.currentSchemaVersion} snapshots can be saved',
      );
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

  Future<_DecodedCandidate?> _readCandidate(
    File file,
    Directory dataDirectory,
    BackupCatalog catalog,
  ) async {
    try {
      if (!await _isTrustedFile(file, dataDirectory, catalog)) return null;
      final raw = await file.readAsString(encoding: utf8);
      final decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException('JSON root must map');
      final source = Map<String, dynamic>.from(decoded);
      final schemaVersion = _readSchemaVersion(source);
      final data = AppData.fromJson(source);
      if (schemaVersion == 1) {
        final migrationBackup = await catalog.createMigrationBackup(raw);
        if (migrationBackup == null) return null;
      }
      return _DecodedCandidate(data: data, schemaVersion: schemaVersion);
    } catch (_) {
      return null;
    }
  }

  Future<bool> _isTrustedFile(
    File file,
    Directory dataDirectory,
    BackupCatalog catalog,
  ) async {
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type != FileSystemEntityType.file) return false;
    final root = await dataDirectory.resolveSymbolicLinks();
    final candidate = await file.resolveSymbolicLinks();
    final normalizedRoot = root.replaceAll('/', Platform.pathSeparator);
    final normalizedCandidate = candidate.replaceAll(
      '/',
      Platform.pathSeparator,
    );
    final isInsideData = normalizedCandidate.toLowerCase().startsWith(
      normalizedRoot.toLowerCase(),
    );
    if (!isInsideData) return false;
    final backupsPrefix = catalog.backupsDirectory.path
        .replaceAll('/', Platform.pathSeparator)
        .toLowerCase();
    final normalizedPath = file.path
        .replaceAll('/', Platform.pathSeparator)
        .toLowerCase();
    if (normalizedPath.startsWith('$backupsPrefix${Platform.pathSeparator}')) {
      final backups = await catalog.listBackups();
      return backups.any((entry) => entry.path == file.path);
    }
    final prefix = normalizedRoot.endsWith(Platform.pathSeparator)
        ? normalizedRoot
        : '$normalizedRoot${Platform.pathSeparator}';
    return normalizedCandidate.toLowerCase().startsWith(prefix.toLowerCase());
  }

  static int _readSchemaVersion(Map<String, dynamic> source) {
    final value = source['schemaVersion'];
    if (value is int) return value;
    if (value is num && value == value.toInt()) return value.toInt();
    throw const FormatException('schemaVersion must be an integer');
  }

  static String _safeBackupName(File file) {
    final name = file.path.split(RegExp(r'[\\/]')).last;
    return BackupCatalog.isBackupFileName(name) ? name : 'backup.json';
  }

  Directory? _resolveEnvironmentDirectory() {
    return resolveLiteTodoDataDirectoryOverride(
      Platform.environment['LITETODO_DATA_DIR'],
    );
  }
}

class _DecodedCandidate {
  const _DecodedCandidate({required this.data, required this.schemaVersion});

  final AppData data;
  final int schemaVersion;
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
