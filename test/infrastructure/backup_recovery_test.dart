import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:litetodo/domain/models/app_data.dart';
import 'package:litetodo/domain/models/project.dart';
import 'package:litetodo/domain/models/todo_item.dart';
import 'package:litetodo/infrastructure/persistence/backup_catalog.dart';
import 'package:litetodo/infrastructure/persistence/backup_service.dart';
import 'package:litetodo/infrastructure/persistence/app_data_repository.dart';
import 'package:litetodo/infrastructure/persistence/json_app_data_repository.dart';

Future<Directory> _temporaryDirectory() =>
    Directory.systemTemp.createTemp('litetodo-recovery-');

Map<String, dynamic> _snapshotJson(
  int revision, {
  int schemaVersion = AppData.currentSchemaVersion,
}) {
  final data = AppData(
    schemaVersion: AppData.currentSchemaVersion,
    revision: revision,
    projects: const <Project>[],
    todos: const <TodoItem>[],
    trash: const <TrashItem>[],
  ).toJson();
  data['schemaVersion'] = schemaVersion;
  if (schemaVersion == 1) data.remove('groups');
  return data;
}

String _snapshot(int revision, {int schemaVersion = 2}) =>
    jsonEncode(_snapshotJson(revision, schemaVersion: schemaVersion));

Future<void> _write(File file, String contents) async {
  await file.parent.create(recursive: true);
  await file.writeAsString(contents, encoding: utf8, flush: true);
}

File _backupFile(Directory directory, String name) => File(
  '${directory.path}${Platform.pathSeparator}backups${Platform.pathSeparator}$name',
);

void main() {
  test('primary and previous take priority over backups', () async {
    final directory = await _temporaryDirectory();
    addTearDown(() => directory.delete(recursive: true));
    await _write(
      File('${directory.path}${Platform.pathSeparator}data.json'),
      _snapshot(3),
    );
    await _write(
      File('${directory.path}${Platform.pathSeparator}data.prev.json'),
      _snapshot(2),
    );
    await _write(
      _backupFile(directory, 'litetodo-backup-20260810-120000.json'),
      _snapshot(1),
    );

    final result = await JsonAppDataRepository(directory: directory).load();
    expect(result.source, AppDataLoadSource.primary);
    expect(result.data.revision, 3);

    await File('${directory.path}${Platform.pathSeparator}data.json').delete();
    final previous = await JsonAppDataRepository(directory: directory).load();
    expect(previous.source, AppDataLoadSource.previous);
    expect(previous.data.revision, 2);
  });

  test('invalid primary and previous recover newest valid backup', () async {
    final directory = await _temporaryDirectory();
    addTearDown(() => directory.delete(recursive: true));
    await _write(
      File('${directory.path}${Platform.pathSeparator}data.json'),
      '{broken',
    );
    await _write(
      File('${directory.path}${Platform.pathSeparator}data.prev.json'),
      '{also broken',
    );
    await _write(
      _backupFile(directory, 'litetodo-backup-20260810-120000.json'),
      _snapshot(1),
    );
    await _write(
      _backupFile(directory, 'litetodo-backup-20260810-130000.json'),
      _snapshot(2),
    );

    final result = await JsonAppDataRepository(directory: directory).load();
    expect(result.source, AppDataLoadSource.backup);
    expect(result.data.revision, 2);
    expect(
      result.recoveryWarning,
      contains('litetodo-backup-20260810-130000.json'),
    );
    expect(
      await File(
        '${directory.path}${Platform.pathSeparator}data.json',
      ).readAsString(),
      '{broken',
    );
  });

  test(
    'newest corrupt backup is skipped in favor of the next valid one',
    () async {
      final directory = await _temporaryDirectory();
      addTearDown(() => directory.delete(recursive: true));
      await _write(
        File('${directory.path}${Platform.pathSeparator}data.json'),
        '{broken',
      );
      await _write(
        _backupFile(directory, 'litetodo-backup-20260810-130000.json'),
        '{broken backup',
      );
      await _write(
        _backupFile(directory, 'litetodo-backup-20260810-120000.json'),
        _snapshot(12),
      );

      final result = await JsonAppDataRepository(directory: directory).load();
      expect(result.source, AppDataLoadSource.backup);
      expect(result.data.revision, 12);
    },
  );

  test('all candidates corrupt return empty data with a warning', () async {
    final directory = await _temporaryDirectory();
    addTearDown(() => directory.delete(recursive: true));
    await _write(
      File('${directory.path}${Platform.pathSeparator}data.json'),
      '{broken',
    );
    await _write(
      File('${directory.path}${Platform.pathSeparator}data.prev.json'),
      '{broken previous',
    );
    await _write(
      _backupFile(directory, 'litetodo-backup-20260810-120000.json'),
      '{broken backup',
    );

    final result = await JsonAppDataRepository(directory: directory).load();
    expect(result.source, AppDataLoadSource.empty);
    expect(result.recoveryWarning, isNotNull);
  });

  test('backup recovery is not written until the next business save', () async {
    final directory = await _temporaryDirectory();
    addTearDown(() => directory.delete(recursive: true));
    final primary = File('${directory.path}${Platform.pathSeparator}data.json');
    await _write(primary, '{broken');
    await _write(
      _backupFile(directory, 'litetodo-backup-20260810-120000.json'),
      _snapshot(4),
    );
    final repository = JsonAppDataRepository(directory: directory);
    final loaded = await repository.load();
    expect(loaded.source, AppDataLoadSource.backup);
    expect(await primary.readAsString(), '{broken');

    await repository.save(
      loaded.data.copyWith(revision: loaded.data.revision + 1),
    );
    final decoded =
        jsonDecode(await primary.readAsString()) as Map<String, dynamic>;
    expect(decoded['schemaVersion'], AppData.currentSchemaVersion);
    expect(decoded['revision'], 5);
  });

  test(
    'save rejects a legacy schema snapshot without a raw migration source',
    () async {
      final directory = await _temporaryDirectory();
      addTearDown(() => directory.delete(recursive: true));
      final repository = JsonAppDataRepository(directory: directory);
      final legacy = AppData(
        schemaVersion: 1,
        revision: 1,
        projects: const <Project>[],
        todos: const <TodoItem>[],
        trash: const <TrashItem>[],
      );
      await expectLater(repository.save(legacy), throwsStateError);
      expect(
        await BackupCatalog(dataDirectory: directory).listBackups(),
        isEmpty,
      );
    },
  );

  test(
    'v1 primary, previous and backup each receive one raw migration copy',
    () async {
      Future<void> verify(String sourceName) async {
        final directory = await _temporaryDirectory();
        addTearDown(() => directory.delete(recursive: true));
        final raw = _snapshot(7, schemaVersion: 1);
        await _write(
          File('${directory.path}${Platform.pathSeparator}data.json'),
          sourceName == 'primary' ? raw : '{broken',
        );
        if (sourceName == 'previous') {
          await _write(
            File('${directory.path}${Platform.pathSeparator}data.prev.json'),
            raw,
          );
        }
        if (sourceName == 'backup') {
          await _write(
            _backupFile(directory, 'litetodo-backup-20260810-120000.json'),
            raw,
          );
        }

        final repository = JsonAppDataRepository(directory: directory);
        final first = await repository.load();
        expect(first.data.schemaVersion, AppData.currentSchemaVersion);
        final catalog = BackupCatalog(dataDirectory: directory);
        var migrations = (await catalog.listBackups())
            .where(BackupCatalog.isMigrationBackup)
            .toList(growable: false);
        expect(migrations, hasLength(1));
        expect(
          jsonDecode(await migrations.single.readAsString())['schemaVersion'],
          1,
        );

        await repository.load();
        migrations = (await catalog.listBackups())
            .where(BackupCatalog.isMigrationBackup)
            .toList(growable: false);
        expect(migrations, hasLength(1));
      }

      await verify('primary');
      await verify('previous');
      await verify('backup');
    },
  );

  test(
    'v1 source is rejected when its migration backup cannot be created',
    () async {
      final directory = await _temporaryDirectory();
      addTearDown(() => directory.delete(recursive: true));
      final raw = _snapshot(11, schemaVersion: 1);
      await _write(
        File('${directory.path}${Platform.pathSeparator}data.json'),
        raw,
      );
      await _write(
        File('${directory.path}${Platform.pathSeparator}backups'),
        'not a directory',
      );
      final result = await JsonAppDataRepository(directory: directory).load();
      expect(result.source, AppDataLoadSource.empty);
      expect(
        await File(
          '${directory.path}${Platform.pathSeparator}data.json',
        ).readAsString(),
        raw,
      );
    },
  );

  test(
    'external backup links are ignored when the platform permits links',
    () async {
      final directory = await _temporaryDirectory();
      final external = await _temporaryDirectory();
      addTearDown(() async {
        if (await directory.exists()) await directory.delete(recursive: true);
        if (await external.exists()) await external.delete(recursive: true);
      });
      final externalFile = _backupFile(
        external,
        'litetodo-backup-20260810-140000.json',
      );
      await _write(externalFile, _snapshot(99));
      final link = Link(
        '${directory.path}${Platform.pathSeparator}backups${Platform.pathSeparator}litetodo-backup-20260810-140000.json',
      );
      try {
        await link.parent.create(recursive: true);
        await link.create(externalFile.path);
      } catch (_) {
        return;
      }
      await _write(
        File('${directory.path}${Platform.pathSeparator}data.json'),
        '{broken',
      );
      final result = await JsonAppDataRepository(directory: directory).load();
      expect(result.source, AppDataLoadSource.empty);
      expect(result.data.revision, 0);
    },
  );

  test(
    'backup retention keeps the newest fourteen and preserves data.prev',
    () async {
      final directory = await _temporaryDirectory();
      addTearDown(() => directory.delete(recursive: true));
      await _write(
        File('${directory.path}${Platform.pathSeparator}data.json'),
        _snapshot(1),
      );
      final previous = File(
        '${directory.path}${Platform.pathSeparator}data.prev.json',
      );
      await _write(previous, _snapshot(0));
      for (var index = 0; index < 16; index += 1) {
        await _write(
          _backupFile(
            directory,
            'litetodo-backup-202608${(10 + index).toString().padLeft(2, '0')}-120000.json',
          ),
          _snapshot(index),
        );
      }
      final service = BackupService(directory: directory, maxBackups: 14);
      await service.createManualBackup();
      expect(await service.listBackups(), hasLength(14));
      expect(await previous.exists(), isTrue);
    },
  );

  test('migration backups do not suppress the same-day daily backup', () async {
    final directory = await _temporaryDirectory();
    addTearDown(() => directory.delete(recursive: true));
    await _write(
      File('${directory.path}${Platform.pathSeparator}data.json'),
      _snapshot(8, schemaVersion: 1),
    );
    final repository = JsonAppDataRepository(directory: directory);
    await repository.load();
    final service = BackupService(
      directory: directory,
      now: () => DateTime(2026, 8, 10, 15),
    );
    final daily = await service.createDailyBackup();
    expect(daily, isNotNull);
    final backups = await service.listBackups();
    expect(backups.where(BackupCatalog.isMigrationBackup), hasLength(1));
    expect(
      backups.where((file) => !BackupCatalog.isMigrationBackup(file)),
      hasLength(1),
    );
  });

  test('backup service rejects an external backups directory link', () async {
    final directory = await _temporaryDirectory();
    final external = await _temporaryDirectory();
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
      if (await external.exists()) await external.delete(recursive: true);
    });
    final externalFile = _backupFile(
      external,
      'litetodo-backup-20260810-140000.json',
    );
    await _write(externalFile, _snapshot(99));
    final link = Link('${directory.path}${Platform.pathSeparator}backups');
    try {
      await link.create(external.path);
    } catch (_) {
      return;
    }
    await _write(
      File('${directory.path}${Platform.pathSeparator}data.json'),
      _snapshot(1),
    );
    final service = BackupService(directory: directory);
    expect(await service.listBackups(), isEmpty);
    await expectLater(service.createManualBackup(), throwsStateError);
    await expectLater(service.createDailyBackup(), throwsStateError);
    await expectLater(
      service.restoreCandidate(externalFile),
      throwsArgumentError,
    );
    expect(await externalFile.readAsString(), _snapshot(99));
  });
}
