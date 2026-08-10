import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:litetodo/icons/project_icons.dart';

void main() {
  test('IconPark catalog has 57 local SVG entries and a stable fallback', () {
    expect(ProjectIcons.entries, hasLength(57));
    expect(ProjectIcons.resolve('home').assetPath, endsWith('/home.svg'));
    expect(ProjectIcons.resolve('unknown-key').key, ProjectIcons.fallbackKey);
    expect(ProjectIcons.contains('folder'), isTrue);
    expect(ProjectIcons.keys, hasLength(57));
    for (final entry in ProjectIcons.entries) {
      expect(File(entry.assetPath).existsSync(), isTrue, reason: entry.key);
    }
  });
}
