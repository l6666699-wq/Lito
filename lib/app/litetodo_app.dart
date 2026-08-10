import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../application/quick_add_controller.dart';
import '../application/window_controller.dart';
import '../application/workspace_controller.dart';
import '../presentation/shell/app_shell.dart';
import 'app_constants.dart';
import 'theme/app_theme.dart';

class LiteTodoApp extends StatefulWidget {
  const LiteTodoApp({
    super.key,
    this.controller,
    this.windowController,
    this.quickAddController,
  });

  final WorkspaceController? controller;
  final WindowController? windowController;
  final QuickAddController? quickAddController;

  @override
  State<LiteTodoApp> createState() => _LiteTodoAppState();
}

class _LiteTodoAppState extends State<LiteTodoApp> {
  late final WorkspaceController _controller =
      widget.controller ?? WorkspaceController();
  late final bool _ownsController = widget.controller == null;
  late final WindowController _windowController =
      widget.windowController ?? WindowController();
  late final bool _ownsWindowController = widget.windowController == null;
  late final QuickAddController _quickAddController =
      widget.quickAddController ??
      QuickAddController(
        windowController: _windowController,
        onSubmit: _controller.addTodoAndFlush,
      );
  late final bool _ownsQuickAddController = widget.quickAddController == null;

  @override
  void dispose() {
    if (_ownsQuickAddController) _quickAddController.dispose();
    if (_ownsWindowController) _windowController.dispose();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShadApp(
      title: AppConstants.appName,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: AppShell(
        controller: _controller,
        windowController: _windowController,
        quickAddController: _quickAddController,
      ),
    );
  }
}
