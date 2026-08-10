import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:litetodo/app/theme/app_theme.dart';
import 'package:litetodo/application/app_navigation_controller.dart';
import 'package:litetodo/application/window_controller.dart';
import 'package:litetodo/application/workspace_controller.dart';
import 'package:litetodo/infrastructure/platform/desktop_window_service.dart';
import 'package:litetodo/icons/app_icons.dart';
import 'package:litetodo/presentation/shell/full_app_shell.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('close tooltip and behavior follow the tray preference', (
    tester,
  ) async {
    final window = WindowController(desktopService: FakeDesktopWindowService());
    await window.initialize();
    final workspace = WorkspaceController();
    final navigation = AppNavigationController();
    addTearDown(() {
      window.dispose();
      workspace.dispose();
      navigation.dispose();
    });
    await tester.binding.setSurfaceSize(const Size(860, 620));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ShadApp(
        theme: AppTheme.lightFor(),
        home: FullAppShell(
          controller: workspace,
          windowController: window,
          navigationController: navigation,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final close = find.byIcon(AppIcons.windowClose);
    expect(close, findsOneWidget);
    expect(find.bySemanticsLabel('隐藏到托盘'), findsOneWidget);

    await window.setCloseToTray(false);
    await tester.pump();
    expect(find.bySemanticsLabel('退出 LiteTodo'), findsOneWidget);
    await window.close();
    expect(window.state, WindowLifecycleState.exiting);
  });
}
