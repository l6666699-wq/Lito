import 'package:flutter_test/flutter_test.dart';
import 'package:litetodo/app/theme/app_theme.dart';

void main() {
  test('font setting maps to the live Shad text theme family', () {
    expect(
      AppTheme.lightFor(fontFamilyKey: 'system').textTheme.p.fontFamily,
      'Segoe UI Variable',
    );
    expect(
      AppTheme.lightFor(fontFamilyKey: 'segoeUi').textTheme.p.fontFamily,
      'Segoe UI',
    );
    expect(
      AppTheme.lightFor(fontFamilyKey: 'geist').textTheme.p.fontFamily,
      'Geist',
    );
  });
}
