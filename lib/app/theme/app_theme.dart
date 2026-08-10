import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AppTheme {
  const AppTheme._();

  static ShadThemeData get light => ShadThemeData(
    brightness: Brightness.light,
    radius: const BorderRadius.all(Radius.circular(8)),
  );

  static ShadThemeData get dark => ShadThemeData(
    brightness: Brightness.dark,
    radius: const BorderRadius.all(Radius.circular(8)),
  );
}
