import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litetodo/icons/app_icons.dart';
import 'package:litetodo/icons/project_icons.dart';

List<File> _dartFiles(String path) => Directory(path)
    .listSync(recursive: true)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'))
    .toList();

void main() {
  test('Lucide and platform icon sources stay behind the catalogs', () {
    final offenders = <String>[];
    for (final file in _dartFiles('lib')) {
      final relative = file.path.replaceAll('\\', '/');
      final lines = file.readAsLinesSync();
      for (var index = 0; index < lines.length; index++) {
        final line = lines[index];
        if (line.contains('LucideIcons.') &&
            !relative.endsWith('/icons/app_icons.dart')) {
          offenders.add('$relative:${index + 1}: LucideIcons');
        }
        if (RegExp(r'\bIcons\.').hasMatch(line) ||
            line.contains('CupertinoIcons') ||
            line.contains('FontAwesome') ||
            line.contains('FluentIcons')) {
          offenders.add('$relative:${index + 1}: platform icon source');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('presentation uses semantic and project icon APIs only', () {
    final offenders = <String>[];
    const forbiddenNames = <String>['LocalProjectIcon', 'IconCatalog'];
    const forbiddenGlyphs = <String>[
      '✓',
      '−',
      '…',
      '→',
      '←',
      '↓',
      '↑',
      '■',
      '★',
      '➕',
      '➖',
      '✕',
      '×',
      '⌄',
      '›',
    ];
    for (final file in _dartFiles('lib/presentation')) {
      final relative = file.path.replaceAll('\\', '/');
      final lines = file.readAsLinesSync();
      for (var index = 0; index < lines.length; index++) {
        final line = lines[index];
        if (forbiddenNames.any(line.contains) ||
            forbiddenGlyphs.any(line.contains)) {
          offenders.add('$relative:${index + 1}');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('AppIcons exposes the stable semantic contract', () {
    final required = <IconData>[
      AppIcons.search,
      AppIcons.add,
      AppIcons.delete,
      AppIcons.trash,
      AppIcons.restore,
      AppIcons.edit,
      AppIcons.settings,
      AppIcons.statistics,
      AppIcons.theme,
      AppIcons.palette,
      AppIcons.inbox,
      AppIcons.today,
      AppIcons.recent,
      AppIcons.completed,
      AppIcons.archive,
      AppIcons.expand,
      AppIcons.collapse,
      AppIcons.more,
      AppIcons.filter,
      AppIcons.sort,
      AppIcons.shortcut,
      AppIcons.font,
      AppIcons.folder,
      AppIcons.backup,
      AppIcons.exportData,
      AppIcons.importData,
      AppIcons.tray,
      AppIcons.windowMinimize,
      AppIcons.windowMaximize,
      AppIcons.windowClose,
      AppIcons.info,
      AppIcons.notification,
      AppIcons.clock,
      AppIcons.calendar,
      AppIcons.check,
      AppIcons.minus,
      AppIcons.dragHandle,
      AppIcons.layers,
      AppIcons.star,
      AppIcons.chevronDown,
      AppIcons.chevronRight,
      AppIcons.chevronLeft,
      AppIcons.lock,
      AppIcons.pin,
      AppIcons.compact,
      AppIcons.quickAdd,
    ];
    expect(required, hasLength(46));
    expect(
      required.every((icon) => icon.fontPackage == 'lucide_icons_flutter'),
      isTrue,
    );
  });

  test('ProjectIcons keeps all 57 persisted keys and local assets', () {
    expect(ProjectIcons.entries, hasLength(57));
    expect(ProjectIcons.resolve('unknown').key, ProjectIcons.fallbackKey);
    expect(ProjectIcons.fallback.key, ProjectIcons.fallbackKey);
    expect(ProjectIcons.contains(ProjectIcons.fallbackKey), isTrue);
    expect(ProjectIcons.keys, contains('check_correct'));
    for (final entry in ProjectIcons.entries) {
      expect(File(entry.assetPath).existsSync(), isTrue, reason: entry.key);
    }
  });
}
