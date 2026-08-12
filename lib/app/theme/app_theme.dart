import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../app_constants.dart';
import 'app_colors.dart';
import 'app_motion.dart';
import 'project_palette.dart';

class AppTheme {
  const AppTheme._();

  static ShadThemeData get light => lightFor();

  static ShadThemeData get dark => darkFor();

  static ShadThemeData lightFor({
    String accentColorKey = 'blue',
    String fontFamilyKey = 'system',
  }) => _build(Brightness.light, accentColorKey, fontFamilyKey);

  static ShadThemeData darkFor({
    String accentColorKey = 'blue',
    String fontFamilyKey = 'system',
  }) => _build(Brightness.dark, accentColorKey, fontFamilyKey);

  static String fontFamilyFor(String key) {
    return switch (key) {
      'segoeUi' => AppConstants.fallbackFontFamily,
      'geist' => 'Geist',
      _ => AppConstants.systemFontFamily,
    };
  }

  static List<String> fontFamilyFallbackFor(String key) {
    return switch (key) {
      'geist' => const <String>[
        AppConstants.systemFontFamily,
        AppConstants.fallbackFontFamily,
      ],
      'segoeUi' => const <String>[AppConstants.systemFontFamily],
      _ => const <String>[AppConstants.fallbackFontFamily],
    };
  }

  static ShadThemeData _build(
    Brightness brightness,
    String accentColorKey,
    String fontFamilyKey,
  ) {
    final accent = ProjectPalette.resolve(accentColorKey).accent;
    final base = ShadColorScheme.fromName('blue', brightness: brightness);
    final appColors = brightness == Brightness.dark
        ? AppColors.darkScheme
        : AppColors.lightScheme;
    final colorScheme = base.copyWith(
      background: appColors.canvas,
      foreground: appColors.text,
      card: appColors.surface,
      cardForeground: appColors.text,
      popover: appColors.surface,
      popoverForeground: appColors.text,
      primary: accent,
      ring: accent,
      selection: accent.withValues(
        alpha: brightness == Brightness.dark ? .35 : .25,
      ),
      secondary: appColors.surfaceSubtle,
      secondaryForeground: appColors.text,
      muted: appColors.surfaceSubtle,
      mutedForeground: appColors.textMuted,
      accent: appColors.surfaceSubtle,
      accentForeground: appColors.text,
      border: appColors.border,
      input: appColors.border,
      primaryForeground: brightness == Brightness.dark
          ? const Color(0xFF12141A)
          : const Color(0xFFFFFFFF),
    );
    return ShadThemeData(
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: ShadTextTheme(
        family: fontFamilyFor(fontFamilyKey),
      ).apply(fontFamilyFallback: fontFamilyFallbackFor(fontFamilyKey)),
      radius: const BorderRadius.all(Radius.circular(8)),
      primaryDialogTheme: _dialogTheme(),
      alertDialogTheme: _dialogTheme(),
      tooltipTheme: const ShadTooltipTheme(
        effects: [
          FadeEffect(duration: AppMotion.instant, curve: AppMotion.enterCurve),
        ],
        duration: AppMotion.instant,
        reverseDuration: AppMotion.instant,
      ),
      popoverTheme: const ShadPopoverTheme(
        effects: [
          FadeEffect(
            duration: AppMotion.popoverEnter,
            curve: AppMotion.enterCurve,
          ),
          ScaleEffect(
            begin: Offset(.98, .98),
            end: Offset(1, 1),
            duration: AppMotion.popoverEnter,
            curve: AppMotion.enterCurve,
          ),
          MoveEffect(
            begin: Offset(0, 4),
            end: Offset.zero,
            duration: AppMotion.popoverEnter,
            curve: AppMotion.enterCurve,
          ),
        ],
        reverseDuration: AppMotion.popoverExit,
      ),
      checkboxTheme: const ShadCheckboxTheme(duration: AppMotion.fast),
      switchTheme: const ShadSwitchTheme(duration: AppMotion.fast),
    );
  }

  static ShadDialogTheme _dialogTheme() {
    return const ShadDialogTheme(
      animateIn: [
        FadeEffect(
          duration: AppMotion.dialogEnter,
          curve: AppMotion.enterCurve,
        ),
        ScaleEffect(
          begin: Offset(.985, .985),
          end: Offset(1, 1),
          duration: AppMotion.dialogEnter,
          curve: AppMotion.enterCurve,
        ),
        MoveEffect(
          begin: Offset(0, 6),
          end: Offset.zero,
          duration: AppMotion.dialogEnter,
          curve: AppMotion.enterCurve,
        ),
      ],
      animateOut: [
        FadeEffect(
          begin: 1,
          end: 0,
          duration: AppMotion.dialogExit,
          curve: AppMotion.exitCurve,
        ),
        ScaleEffect(
          begin: Offset(1, 1),
          end: Offset(.99, .99),
          duration: AppMotion.dialogExit,
          curve: AppMotion.exitCurve,
        ),
        MoveEffect(
          begin: Offset.zero,
          end: Offset(0, 4),
          duration: AppMotion.dialogExit,
          curve: AppMotion.exitCurve,
        ),
      ],
    );
  }
}
