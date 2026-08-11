import 'package:flutter_test/flutter_test.dart';
import 'package:litetodo/app/theme/app_colors.dart';
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

  test('Shad surfaces follow the application light and dark tokens', () {
    final light = AppTheme.lightFor();
    final dark = AppTheme.darkFor();

    expect(light.colorScheme.background, AppColors.lightCanvas);
    expect(light.colorScheme.card, AppColors.lightSurface);
    expect(light.colorScheme.foreground, AppColors.lightText);
    expect(light.colorScheme.border, AppColors.lightBorder);
    expect(dark.colorScheme.background, AppColors.darkCanvas);
    expect(dark.colorScheme.card, AppColors.darkSurface);
    expect(dark.colorScheme.foreground, AppColors.darkText);
    expect(dark.colorScheme.border, AppColors.darkBorder);
  });

  test('settings surfaces retain quiet contrast in both theme modes', () {
    expect(AppColors.lightSurface, isNot(AppColors.lightCanvas));
    expect(AppColors.lightSurfaceSubtle, isNot(AppColors.lightSurface));
    expect(AppColors.lightBorder, isNot(AppColors.lightSurface));
    expect(AppColors.darkSurface, isNot(AppColors.darkCanvas));
    expect(AppColors.darkSurfaceSubtle, isNot(AppColors.darkSurface));
    expect(AppColors.darkBorder, isNot(AppColors.darkSurface));
  });
}
