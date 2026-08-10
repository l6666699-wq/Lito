import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litetodo/app/theme/app_theme.dart';
import 'package:litetodo/application/app_navigation_controller.dart';
import 'package:litetodo/application/quick_add_controller.dart';
import 'package:litetodo/application/window_controller.dart';
import 'package:litetodo/application/workspace_controller.dart';
import 'package:litetodo/infrastructure/platform/desktop_window_service.dart';
import 'package:litetodo/presentation/shell/app_shell.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('AppShell inherits the selected font family', (tester) async {
    final window = WindowController(desktopService: FakeDesktopWindowService());
    await window.initialize();
    final workspace = WorkspaceController();
    final navigation = AppNavigationController();
    final quickAdd = QuickAddController(
      windowController: window,
      onSubmit: (_) async {},
    );
    addTearDown(() {
      window.dispose();
      workspace.dispose();
      navigation.dispose();
      quickAdd.dispose();
    });

    await tester.binding.setSurfaceSize(const Size(860, 620));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ShadApp(
        theme: AppTheme.lightFor(fontFamilyKey: 'geist'),
        home: AppShell(
          controller: workspace,
          windowController: window,
          quickAddController: quickAdd,
          navigationController: navigation,
          fontFamily: AppTheme.fontFamilyFor('geist'),
          fontFamilyFallback: AppTheme.fontFamilyFallbackFor('geist'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final text = find.byType(Text).first;
    expect(DefaultTextStyle.of(tester.element(text)).style.fontFamily, 'Geist');
  });
}
