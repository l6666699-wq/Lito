import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:litetodo/icons/app_icons.dart';

void main() {
  test('settings aliases keep the intended Lucide line glyphs', () {
    expect(AppIcons.settings, LucideIcons.settings);
    expect(AppIcons.windowSettings, LucideIcons.panelsTopLeft);
    expect(AppIcons.appearance, LucideIcons.palette);
    expect(AppIcons.font, LucideIcons.type);
    expect(AppIcons.backup, LucideIcons.databaseBackup);
    expect(AppIcons.about, LucideIcons.circleHelp);
    expect(AppIcons.monitor, LucideIcons.monitor);
    expect(AppIcons.archive, LucideIcons.archive);
    expect(AppIcons.inbox, LucideIcons.inbox);
    expect(AppIcons.download, LucideIcons.download);
    expect(AppIcons.keyboard, LucideIcons.keyboard);
    expect(AppIcons.hotkeyEdit, LucideIcons.pencil);
  });
}
