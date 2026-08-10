import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/models/app_data.dart';
import 'backup_catalog.dart';
import 'data_directory_resolver.dart';

/// Creates and validates copies of the current `data.json` snapshot.
class BackupService {
  BackupService({
    Directory? directory,
    this.appDirectoryName = 'LiteTodo',
    this.maxBackups = 14,
    DateTime Function()? now,
  }) : _directory = directory, // ignore: prefer_initializing_formals
       _now = now ?? DateTime.now;

  final Directory? _directory;
  final String appDirectoryName;
  final int maxBackups;
  final DateTime Function() _now;
  Future<void> _operationTail = Future<void>.value();

  Future<Directory> get dataDirectory async {
    final directory =
        _directory ??
        resolveLiteTodoDataDirectoryOverride(
          Platform.environment['LITETODO_DATA_DIR'],
        ) ??
        Directory(
          '${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}$appDirectoryName',
        );
    await directory.create(recursive: true);
    return directory;
  }

  Future<Directory> get backupsDirectory async {
    final directory = Directory(
      '${(await dataDirectory).path}${Platform.pathSeparator}backups',
    );
    final type = await FileSystemEntity.type(
      directory.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.link ||
        type == FileSystemEntityType.file) {
      throw StateError('LiteTodo backups directory must not be a link or file');
    }
    await directory.create(recursive: true);
    return directory;
  }

  Future<File> get dataFile async =>
      File('${(await dataDirectory).path}${Platform.pathSeparator}data.json');

  /// Creates a manual backup and returns its path.
  Future<File> createManualBackup() => _enqueue(() async {
    final backup = await _createBackup(dailyOnly: false);
    // Manual backups never take the daily short circuit.
    return backup!;
  });

  Future<File> createBackup() => createManualBackup();

  /// Creates at most one valid backup for the current local calendar day.
  /// Returns `null` when a backup for today already exists.
  Future<File?> createDailyBackup() =>
      _enqueue(() => _createBackup(dailyOnly: true));

  /// Compatibility aliases for callers that use shorter operation names.
  Future<File> manualBackup() => createManualBackup();

  Future<File?> dailyBackup() => createDailyBackup();

  /// Lists only files with the LiteTodo backup naming shape, newest first.
  Future<List<File>> listBackups() async {
    late final Directory directory;
    try {
      directory = await backupsDirectory;
    } catch (_) {
      return const <File>[];
    }
    final safeFiles = <File>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File || !_isBackupName(entity.path)) continue;
      if (!await _isWithinBackupsDirectory(entity)) continue;
      safeFiles.add(entity);
    }
    safeFiles.sort((left, right) {
      final leftDate = _timestampFromName(left.path);
      final rightDate = _timestampFromName(right.path);
      final byName = rightDate.compareTo(leftDate);
      if (byName != 0) return byName;
      return right.path.compareTo(left.path);
    });
    return safeFiles;
  }

  Future<List<File>> list() => listBackups();

  /// Reads and validates a backup without replacing `data.json`.
  /// Both a [File] and a path [String] are accepted for ergonomic callers.
  Future<AppData> restoreCandidate(Object candidate) async {
    final file = candidate is File ? candidate : File(candidate.toString());
    if (!_isBackupName(file.path) || !await _isWithinBackupsDirectory(file)) {
      throw ArgumentError('Backup path is outside the backups directory');
    }
    if (!await file.exists()) {
      throw const FileSystemException('Backup not found');
    }
    return _decodeAppData(await file.readAsString());
  }

  Future<AppData> readRestoreCandidate(Object candidate) =>
      restoreCandidate(candidate);

  Future<File?> _createBackup({required bool dailyOnly}) async {
    final source = await dataFile;
    if (!await source.exists()) {
      throw const FileSystemException('data.json does not exist');
    }
    // Validate the source before writing anything to the backups directory.
    final contents = await source.readAsString();
    _decodeAppData(contents);

    final timestamp = _now();
    if (dailyOnly) {
      final today = _dateKey(timestamp);
      final existing = await listBackups();
      for (final file in existing) {
        if (BackupCatalog.isMigrationBackup(file)) continue;
        if (_dateKey(_timestampFromName(file.path)) == today) {
          try {
            _decodeAppData(await file.readAsString());
            return null;
          } catch (_) {
            // An invalid old copy should not block today's valid backup.
          }
        }
      }
    }

    final directory = await backupsDirectory;
    final path = await _nextBackupPath(directory, timestamp);
    final backup = File(path);
    if (!await _isWithinBackupsDirectory(backup)) {
      throw const FileSystemException('Backup path escaped backups directory');
    }
    try {
      await backup.writeAsString(contents, flush: true);
      // Re-read the copy so a truncated or otherwise corrupt write is never
      // reported as a successful backup.
      _decodeAppData(await backup.readAsString());
    } catch (_) {
      // Do not leave a corrupt candidate behind.  The path is checked again
      // before deletion so only this newly created file inside backups/ can be
      // removed.
      try {
        if (await backup.exists() && await _isWithinBackupsDirectory(backup)) {
          await backup.delete();
        }
      } catch (_) {
        // Preserve the original write/validation error.
      }
      rethrow;
    }
    await _pruneBackups();
    return backup;
  }

  Future<String> _nextBackupPath(
    Directory directory,
    DateTime timestamp,
  ) async {
    final prefix = 'litetodo-backup-${_formatTimestamp(timestamp)}';
    var candidate = '${directory.path}${Platform.pathSeparator}$prefix.json';
    var suffix = 1;
    while (await File(candidate).exists()) {
      candidate =
          '${directory.path}${Platform.pathSeparator}$prefix-$suffix.json';
      suffix += 1;
    }
    return candidate;
  }

  Future<void> _pruneBackups() async {
    final keep = maxBackups < 1 ? 1 : maxBackups;
    final files = await listBackups();
    for (final file in files.skip(keep)) {
      if (await _isWithinBackupsDirectory(file)) {
        await file.delete();
      }
    }
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final next = _operationTail.then<T>((_) => operation());
    _operationTail = next.then<void>((_) {}, onError: (_, _) {});
    return next;
  }

  Future<bool> _isWithinBackupsDirectory(File file) async {
    late final Directory backups;
    try {
      backups = await backupsDirectory;
    } catch (_) {
      return false;
    }
    final root = _normalizePath(await backups.resolveSymbolicLinks());
    final candidatePath = _normalizePath(file.absolute.path);
    final prefix = root.endsWith(Platform.pathSeparator)
        ? root
        : '$root${Platform.pathSeparator}';
    // A target that is exactly the backups directory is not a file candidate.
    if (!candidatePath.toLowerCase().startsWith(prefix.toLowerCase())) {
      return false;
    }
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type == FileSystemEntityType.link ||
        (type != FileSystemEntityType.notFound &&
            type != FileSystemEntityType.file)) {
      return false;
    }
    if (await file.exists()) {
      try {
        final resolvedFile = _normalizePath(await file.resolveSymbolicLinks());
        if (!resolvedFile.toLowerCase().startsWith(prefix.toLowerCase())) {
          return false;
        }
      } catch (_) {
        return false;
      }
    }
    final parent = file.parent;
    try {
      final resolvedParent = _normalizePath(
        await parent.resolveSymbolicLinks(),
      );
      if (!resolvedParent.toLowerCase().startsWith(root.toLowerCase())) {
        return false;
      }
    } catch (_) {
      return false;
    }
    return true;
  }

  AppData _decodeAppData(String contents) {
    final decoded = jsonDecode(contents);
    if (decoded is! Map) throw const FormatException('JSON root must map');
    return AppData.fromJson(Map<String, dynamic>.from(decoded));
  }
}

const _backupPattern =
    r'^litetodo-backup-\d{8}-\d{6}(?:-migration)?(?:-\d+)?\.json$';

bool _isBackupName(String path) => RegExp(
  _backupPattern,
  caseSensitive: false,
).hasMatch(path.split(RegExp(r'[\\/]')).last);

DateTime _timestampFromName(String path) {
  final name = path.split(RegExp(r'[\\/]')).last;
  final match = RegExp(
    r'^litetodo-backup-(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})(\d{2})',
    caseSensitive: false,
  ).firstMatch(name);
  if (match == null) return DateTime.fromMillisecondsSinceEpoch(0);
  return DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
    int.parse(match.group(4)!),
    int.parse(match.group(5)!),
    int.parse(match.group(6)!),
  );
}

String _formatTimestamp(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}'
    '${value.month.toString().padLeft(2, '0')}'
    '${value.day.toString().padLeft(2, '0')}-'
    '${value.hour.toString().padLeft(2, '0')}'
    '${value.minute.toString().padLeft(2, '0')}'
    '${value.second.toString().padLeft(2, '0')}';

String _dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String _normalizePath(String path) => path
    .replaceAll('/', Platform.pathSeparator)
    .replaceAll(RegExp(r'[\\/]+$'), '');
