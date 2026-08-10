import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:litetodo/icons/icon_catalog.dart';

void main() {
  test(
    'IconPark catalog has 48-64 local SVG entries and a stable fallback',
    () {
      expect(IconCatalog.entries.length, inInclusiveRange(48, 64));
      expect(IconCatalog.resolve('home').assetPath, endsWith('/home.svg'));
      expect(IconCatalog.resolve('unknown-key').key, IconCatalog.fallbackKey);
      for (final entry in IconCatalog.entries) {
        expect(File(entry.assetPath).existsSync(), isTrue, reason: entry.key);
      }
    },
  );
}
