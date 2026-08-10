import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:litetodo/domain/models/app_data.dart';
import 'package:litetodo/infrastructure/persistence/backup_service.dart';

Future<Directory> _temporaryDirectory() =>
    Directory.systemTemp.createTemp('litetodo-backup-');

Future<void> _writeEmptyData(Directory directory, int revision) async {
  final file = File('${directory.path}\\data.json');
  await file.parent.create(recursive: true);
  await file.writeAsString(
    jsonEncode(AppData.empty().copyWith(revision: revision).toJson()),
    flush: true,
  );
}

void main() {
  test(
    'manual/daily backup validates and never overwrites data.prev',
    () async {
      final directory = await _temporaryDirectory();
      await _writeEmptyData(directory, 4);
      final previous = File('${directory.path}\\data.prev.json');
      await previous.writeAsString('keep-me');
      final service = BackupService(
        directory: directory,
        now: () => DateTime(2026, 8, 10, 12),
      );

      final manual = await service.createManualBackup();
      expect(manual.existsSync(), isTrue);
      expect(
        RegExp(
          r'litetodo-backup-20260810-120000(?:-\d+)?\.json$',
        ).hasMatch(manual.path),
        isTrue,
      );
      expect(
        await service.restoreCandidate(manual),
        AppData.empty().copyWith(revision: 4),
      );
      expect(await service.createDailyBackup(), isNull);
      expect(await previous.readAsString(), 'keep-me');
    },
  );

  test('retention and path boundary only touch named backups', () async {
    final directory = await _temporaryDirectory();
    await _writeEmptyData(directory, 1);
    final outside = File(
      '${directory.parent.path}\\litetodo-backup-20200101-000000.json',
    );
    await outside.writeAsString('outside');
    var current = DateTime(2026, 1, 1);
    final service = BackupService(
      directory: directory,
      maxBackups: 2,
      now: () => current,
    );
    for (var index = 0; index < 4; index++) {
      await service.createManualBackup();
      current = current.add(const Duration(days: 1));
    }
    expect(await service.listBackups(), hasLength(2));
    expect(await outside.readAsString(), 'outside');
    expect(() => service.restoreCandidate(outside), throwsArgumentError);
  });
}
