import 'package:flutter/widgets.dart';

import '../../app/app_constants.dart';
import '../../app/theme/app_colors.dart';
import '../../application/quick_add_controller.dart';
import '../../application/app_navigation_controller.dart';
import '../../application/window_controller.dart';
import '../../application/workspace_controller.dart';
import '../compact/compact_workspace.dart';
import 'full_app_shell.dart';
import '../quick_add/quick_add_view.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.controller,
    required this.windowController,
    required this.quickAddController,
    required this.navigationController,
    this.onToggleTheme,
    this.fontFamily = AppConstants.systemFontFamily,
    this.fontFamilyFallback = const <String>[AppConstants.fallbackFontFamily],
  });

  final WorkspaceController controller;
  final WindowController windowController;
  final QuickAddController quickAddController;
  final AppNavigationController navigationController;
  final VoidCallback? onToggleTheme;
  final String fontFamily;
  final List<String> fontFamilyFallback;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ColoredBox(
      key: const ValueKey<String>('app-shell-canvas'),
      color: colors.canvas,
      child: DefaultTextStyle(
        style: TextStyle(
          fontFamily: fontFamily,
          fontFamilyFallback: fontFamilyFallback,
          fontSize: 13,
          color: colors.text,
        ),
        child: ListenableBuilder(
          listenable: windowController,
          builder: (context, child) {
            final content = switch (windowController.state) {
              WindowLifecycleState.fullVisible ||
              WindowLifecycleState.hiddenToTray => FullAppShell(
                controller: controller,
                windowController: windowController,
                navigationController: navigationController,
                onToggleTheme: onToggleTheme,
              ),
              WindowLifecycleState.compactVisible => CompactWorkspace(
                controller: controller,
                windowController: windowController,
              ),
              WindowLifecycleState.quickAddVisible => QuickAddView(
                controller: quickAddController,
              ),
              WindowLifecycleState.exiting => const SizedBox.shrink(),
            };
            return content;
          },
        ),
      ),
    );
  }
}
