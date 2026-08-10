import 'package:flutter_test/flutter_test.dart';
import 'package:litetodo/domain/models/app_settings.dart';

void main() {
  test('defaults have stable JSON values and round-trip', () {
    final settings = AppSettings();
    final json = settings.toJson();

    expect(json['schemaVersion'], AppSettings.currentSchemaVersion);
    expect(json['revision'], 0);
    expect(json['themeMode'], 'system');
    expect(json['accentColorKey'], 'blue');
    expect(json['fontFamilyKey'], 'system');
    expect(json['globalHotkey'], 'Ctrl+Alt+Space');
    expect(AppSettings.fromJson(json), settings);
  });

  test('hotkey accepts legacy string and structured JSON forms', () {
    final fromString = AppHotkeyConfig.fromJson('Shift+Ctrl+K');
    expect(fromString.displayString, 'Ctrl+Shift+K');
    final fromObject = AppHotkeyConfig.fromJson(<String, dynamic>{
      'modifiers': <String>['control', 'alt'],
      'key': 'Space',
    });
    expect(fromObject, const AppHotkeyConfig.defaultValue());
  });

  test('lastProjectId round-trips, defaults for old settings, and clears', () {
    final settings = AppSettings(lastProjectId: 'project-focus');
    final roundTrip = AppSettings.fromJson(settings.toJson());

    expect(roundTrip.lastProjectId, 'project-focus');
    expect(
      AppSettings.fromJson(<String, dynamic>{
        'schemaVersion': 1,
        'revision': 3,
        'themeMode': 'system',
        'globalHotkey': 'Ctrl+Alt+Space',
      }).lastProjectId,
      isNull,
    );
    expect(settings.copyWith(lastProjectId: null).lastProjectId, isNull);
  });

  test('invalid values are rejected before persistence', () {
    expect(() => AppSettings(fontScale: 1.2), throwsArgumentError);
    expect(
      () => AppSettings(accentColorKey: 'not-a-palette-key'),
      throwsArgumentError,
    );
    expect(
      () => AppSettings.fromJson(<String, dynamic>{
        'schemaVersion': 1,
        'revision': 0,
        'themeMode': 'sepia',
      }),
      throwsFormatException,
    );
  });
}
