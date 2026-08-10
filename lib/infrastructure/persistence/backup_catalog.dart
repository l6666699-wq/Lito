import 'dart:convert';
import 'dart:io';

/// Safe discovery and creation of files inside the local `backups/` folder.
///
/// The catalog is intentionally independent from either JSON repository.  It
/// rejects links while enumerating, validates the resolved path before every
/// read/write, and keeps the naming/sorting policy in one place.
class BackupCatalog {
  BackupCatalog({required this.dataDirectory, this.maxBackups = 14});

  final Directory dataDirectory;
  final int maxBackups;

  Directory get backupsDirectory =>
      Directory('${dataDirectory.path}${Platform.pathSeparator}backups');

  Future<List<File>> listBackups() async {
    final root = await _prepareRoot(create: false);
    if (root == null) return const <File>[];
    final directory = backupsDirectory;
    final files = <File>[];
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File || !isBackupFileName(entity.path)) continue;
      if (!await _isSafeFile(entity, root)) continue;
      files.add(entity);
    }
    files.sort((left, right) {
      final byDate = timestampFromName(
        right.path,
      ).compareTo(timestampFromName(left.path));
      return byDate == 0 ? right.path.compareTo(left.path) : byDate;
    });
    return files;
  }

  /// Writes a raw v1 snapshot as a unique migration backup.
  ///
  /// The contents are written and read back before the file is returned.  An
  /// existing byte-identical migration backup is reused, which prevents a
  /// repeated load of the same source from creating duplicates.
  Future<File?> createMigrationBackup(String contents) async {
    final root = await _prepareRoot(create: true);
    if (root == null) return null;
    final existing = await listBackups();
    for (final file in existing) {
      if (!isMigrationBackup(file)) continue;
      try {
        if (await file.readAsString(encoding: utf8) == contents) return file;
      } catch (_) {
        // A damaged candidate is ignored; a new validated copy can replace it
        // through a different unique filename.
      }
    }

    final timestamp = DateTime.now();
    var suffix = 0;
    File target;
    do {
      final suffixPart = suffix == 0 ? '' : '-$suffix';
      target = File(
        '${backupsDirectory.path}${Platform.pathSeparator}'
        'litetodo-backup-${_formatTimestamp(timestamp)}-migration$suffixPart.json',
      );
      suffix += 1;
    } while (await target.exists());
    if (!await _isSafeFile(target, root, allowMissing: true)) return null;

    try {
      await target.writeAsString(contents, encoding: utf8, flush: true);
      final reread = await target.readAsString(encoding: utf8);
      if (reread != contents) {
        throw const FormatException('Migration backup validation failed');
      }
      await prune();
      return target;
    } catch (_) {
      try {
        if (await target.exists() &&
            await _isSafeFile(target, root, allowMissing: false)) {
          await target.delete();
        }
      } catch (_) {
        // Preserve the original failure and never delete outside the catalog.
      }
      rethrow;
    }
  }

  Future<void> prune() async {
    final files = await listBackups();
    final keep = maxBackups < 1 ? 1 : maxBackups;
    for (final file in files.skip(keep)) {
      final root = await _prepareRoot(create: false);
      if (root != null && await _isSafeFile(file, root)) {
        await file.delete();
      }
    }
  }

  static bool isMigrationBackup(File file) =>
      _basename(file.path).contains('-migration');

  static bool isBackupFileName(String path) =>
      _backupPattern.hasMatch(_basename(path));

  static DateTime timestampFromName(String path) {
    final match = _timestampPattern.firstMatch(_basename(path));
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

  Future<String?> _prepareRoot({required bool create}) async {
    final directory = backupsDirectory;
    final type = await FileSystemEntity.type(
      directory.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.link ||
        type == FileSystemEntityType.file) {
      return null;
    }
    if (create) await directory.create(recursive: true);
    if (!await directory.exists()) return null;
    final dataRoot = await _resolveDirectory(dataDirectory);
    final backupsRoot = await _resolveDirectory(directory);
    if (dataRoot == null || backupsRoot == null) return null;
    final prefix = _withSeparator(dataRoot);
    if (!backupsRoot.toLowerCase().startsWith(prefix.toLowerCase())) {
      return null;
    }
    return backupsRoot;
  }

  Future<bool> _isSafeFile(
    File file,
    String root, {
    bool allowMissing = false,
  }) async {
    final candidate = _normalize(file.absolute.path);
    final prefix = _withSeparator(root);
    if (!candidate.toLowerCase().startsWith(prefix.toLowerCase())) {
      return false;
    }
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type == FileSystemEntityType.link) return false;
    if (!allowMissing && type != FileSystemEntityType.file) return false;
    if (allowMissing && type != FileSystemEntityType.notFound) {
      if (type != FileSystemEntityType.file) return false;
    }
    if (type == FileSystemEntityType.notFound) return allowMissing;
    final resolved = await _resolveFile(file);
    return resolved != null &&
        resolved.toLowerCase().startsWith(prefix.toLowerCase());
  }

  static Future<String?> _resolveDirectory(Directory directory) async {
    try {
      return _normalize(await directory.resolveSymbolicLinks());
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _resolveFile(File file) async {
    try {
      return _normalize(await file.resolveSymbolicLinks());
    } catch (_) {
      return null;
    }
  }

  static String _basename(String path) => path.split(RegExp(r'[\\/]')).last;

  static String _withSeparator(String path) =>
      path.endsWith(Platform.pathSeparator)
      ? path
      : '$path${Platform.pathSeparator}';

  static String _normalize(String path) => path
      .replaceAll('/', Platform.pathSeparator)
      .replaceAll(RegExp(r'[\\/]+$'), '');

  static String _formatTimestamp(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}'
      '${value.month.toString().padLeft(2, '0')}'
      '${value.day.toString().padLeft(2, '0')}-'
      '${value.hour.toString().padLeft(2, '0')}'
      '${value.minute.toString().padLeft(2, '0')}'
      '${value.second.toString().padLeft(2, '0')}';
}

final RegExp _backupPattern = RegExp(
  r'^litetodo-backup-\d{8}-\d{6}(?:-migration)?(?:-\d+)?\.json$',
  caseSensitive: false,
);

final RegExp _timestampPattern = RegExp(
  r'^litetodo-backup-(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})(\d{2})',
  caseSensitive: false,
);
