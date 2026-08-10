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

  AppColorScheme copyWith({Color? focus, Color? focusSoft}) {
    return AppColorScheme(
      canvas: canvas,
      surface: surface,
      surfaceSubtle: surfaceSubtle,
      border: border,
      borderStrong: borderStrong,
      text: text,
      textMuted: textMuted,
      textFaint: textFaint,
      focus: focus ?? this.focus,
      focusSoft: focusSoft ?? this.focusSoft,
      white: white,
      transparent: transparent,
    );
  }
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
    final scheme = brightness == Brightness.dark ? darkScheme : lightScheme;
    final primary = shadTheme?.colorScheme.primary;
    if (primary == null) return scheme;
    return scheme.copyWith(
      focus: primary,
      focusSoft: primary.withValues(alpha: .12),
    );
  }

  // Shared frame tokens mirror the reference desktop surface: a cool,
  // near-white canvas with white cards and quiet gray dividers.
  static const lightCanvas = Color(0xFFF8F9FB);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceSubtle = Color(0xFFF3F4F8);
  static const lightBorder = Color(0xFFE8EAF0);
  static const lightBorderStrong = Color(0xFFDDE0E8);
  static const lightText = Color(0xFF20232B);
  static const lightTextMuted = Color(0xFF6D7380);
  static const lightTextFaint = Color(0xFF969CAA);

  static const darkCanvas = Color(0xFF17191C);
  static const darkSurface = Color(0xFF202328);
  static const darkSurfaceSubtle = Color(0xFF282C32);
  static const darkBorder = Color(0xFF343941);
  static const darkBorderStrong = Color(0xFF424852);
  static const darkText = Color(0xFFF1F3F5);
  static const darkTextMuted = Color(0xFFAAB1BA);
  static const darkTextFaint = Color(0xFF7B838D);

  static const focus = Color(0xFF5667F5);
  static const focusSoft = Color(0x1C5667F5);
  static const white = Color(0xFFFFFFFF);
  static const transparent = Color(0x00000000);
}
