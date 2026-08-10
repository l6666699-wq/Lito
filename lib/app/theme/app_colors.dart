import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AppColorScheme {
  const AppColorScheme({
    required this.canvas,
    required this.surface,
    required this.surfaceSubtle,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.textMuted,
    required this.textFaint,
    required this.focus,
    required this.focusSoft,
    required this.white,
    required this.transparent,
  });

  final Color canvas;
  final Color surface;
  final Color surfaceSubtle;
  final Color border;
  final Color borderStrong;
  final Color text;
  final Color textMuted;
  final Color textFaint;
  final Color focus;
  final Color focusSoft;
  final Color white;
  final Color transparent;
}

class AppColors {
  const AppColors._();

  static const lightScheme = AppColorScheme(
    canvas: lightCanvas,
    surface: lightSurface,
    surfaceSubtle: lightSurfaceSubtle,
    border: lightBorder,
    borderStrong: lightBorderStrong,
    text: lightText,
    textMuted: lightTextMuted,
    textFaint: lightTextFaint,
    focus: focus,
    focusSoft: focusSoft,
    white: white,
    transparent: transparent,
  );

  static const darkScheme = AppColorScheme(
    canvas: darkCanvas,
    surface: darkSurface,
    surfaceSubtle: darkSurfaceSubtle,
    border: darkBorder,
    borderStrong: darkBorderStrong,
    text: darkText,
    textMuted: darkTextMuted,
    textFaint: darkTextFaint,
    focus: focus,
    focusSoft: Color(0x336475F5),
    white: white,
    transparent: transparent,
  );

  static AppColorScheme of(BuildContext context) {
    final shadTheme = ShadTheme.maybeOf(context, listen: false);
    final brightness =
        shadTheme?.brightness ??
        MediaQuery.maybePlatformBrightnessOf(context) ??
        Brightness.light;
    return brightness == Brightness.dark ? darkScheme : lightScheme;
  }

  static const lightCanvas = Color(0xFFF7F8FA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceSubtle = Color(0xFFF1F3F5);
  static const lightBorder = Color(0xFFE2E5E9);
  static const lightBorderStrong = Color(0xFFD6DAE0);
  static const lightText = Color(0xFF20242A);
  static const lightTextMuted = Color(0xFF707782);
  static const lightTextFaint = Color(0xFF9AA1AB);

  static const darkCanvas = Color(0xFF17191C);
  static const darkSurface = Color(0xFF202328);
  static const darkSurfaceSubtle = Color(0xFF282C32);
  static const darkBorder = Color(0xFF343941);
  static const darkBorderStrong = Color(0xFF424852);
  static const darkText = Color(0xFFF1F3F5);
  static const darkTextMuted = Color(0xFFAAB1BA);
  static const darkTextFaint = Color(0xFF7B838D);

  static const focus = Color(0xFF6475F5);
  static const focusSoft = Color(0x226475F5);
  static const white = Color(0xFFFFFFFF);
  static const transparent = Color(0x00000000);
}
