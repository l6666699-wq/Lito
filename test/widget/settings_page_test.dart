import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litetodo/app/litetodo_app.dart';
import 'package:litetodo/app/theme/app_theme.dart';
import 'package:litetodo/application/app_navigation_controller.dart';
import 'package:litetodo/application/settings_controller.dart';
import 'package:litetodo/application/window_controller.dart';
import 'package:litetodo/application/workspace_controller.dart';
import 'package:litetodo/domain/models/app_settings.dart';
import 'package:litetodo/infrastructure/persistence/backup_service.dart';
import 'package:litetodo/infrastructure/platform/data_directory_service.dart';
import 'package:litetodo/infrastructure/platform/desktop_window_service.dart';
import 'package:litetodo/presentation/settings/settings_about_section.dart';
import 'package:litetodo/presentation/settings/settings_appearance_section.dart';
import 'package:litetodo/presentation/settings/settings_data_section.dart';
import 'package:litetodo/presentation/settings/settings_general_section.dart';
import 'package:litetodo/presentation/settings/settings_page.dart';
import 'package:litetodo/presentation/settings/settings_scope.dart';
import 'package:litetodo/presentation/settings/settings_shared_controls.dart';
import 'package:litetodo/presentation/settings/settings_typography_section.dart';
import 'package:litetodo/presentation/settings/settings_window_section.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('settings controls rebuild theme and font scale live', (
    tester,
  ) async {
    final settings = SettingsController(
      repository: InMemorySettingsRepository(),
    );
    await settings.initialize();
    final window = WindowController(desktopService: FakeDesktopWindowService());
    await window.initialize();
    final workspace = WorkspaceController();
    final backup = BackupService(
      directory: Directory(
        '${Directory.systemTemp.path}${Platform.pathSeparator}LiteTodo-settings-test',
      ),
    );
    final directory = FakeDataDirectoryService();
    addTearDown(() {
      settings.dispose();
      window.dispose();
      workspace.dispose();
    });
    await tester.binding.setSurfaceSize(const Size(860, 860));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ShadApp(
        theme: AppTheme.lightFor(),
        home: SettingsScope(
          settingsController: settings,
          backupService: backup,
          workspaceController: workspace,
          windowController: window,
          dataDirectoryService: directory,
          child: const SettingsPage(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('主题设置'), findsOneWidget);
    expect(find.text('字体设置'), findsOneWidget);
    expect(find.text('跨重启恢复完整与紧凑模式的位置和尺寸'), findsNothing);
    expect(find.text('当前会话内恢复各窗口模式的位置；跨重启位置保存尚未接入'), findsNothing);
    await settings.setAccentColorKey('purple');
    await settings.setFontScale(1.15);
    await tester.pump();
    expect(settings.accentColorKey, 'purple');
    expect(settings.fontScale, 1.15);
    await tester.tap(find.byKey(const ValueKey<String>('settings-category-1')));
    await tester.pump();
    await tester.tap(find.text('快速添加'));
    await tester.pump();
    expect(settings.defaultWindowMode, AppWindowMode.quickAdd);
    expect(window.mode, WindowMode.full);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings page fits the 1672x940 reference size', (tester) async {
    final settings = SettingsController(
      repository: InMemorySettingsRepository(),
    );
    await settings.initialize();
    final window = WindowController(desktopService: FakeDesktopWindowService());
    await window.initialize();
    final workspace = WorkspaceController();
    final backup = BackupService(
      directory: Directory(
        '${Directory.systemTemp.path}${Platform.pathSeparator}LiteTodo-settings-test',
      ),
    );
    final directory = FakeDataDirectoryService();
    addTearDown(() {
      settings.dispose();
      window.dispose();
      workspace.dispose();
    });
    await tester.binding.setSurfaceSize(const Size(1672, 940));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ShadApp(
        theme: AppTheme.lightFor(),
        home: SettingsScope(
          settingsController: settings,
          backupService: backup,
          workspaceController: workspace,
          windowController: window,
          dataDirectoryService: directory,
          child: const SettingsPage(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings page fits the 860x860 compact size', (tester) async {
    final settings = SettingsController(
      repository: InMemorySettingsRepository(),
    );
    await settings.initialize();
    final window = WindowController(desktopService: FakeDesktopWindowService());
    await window.initialize();
    final workspace = WorkspaceController();
    final backup = BackupService(
      directory: Directory(
        '${Directory.systemTemp.path}${Platform.pathSeparator}LiteTodo-settings-test',
      ),
    );
    final directory = FakeDataDirectoryService();
    addTearDown(() {
      settings.dispose();
      window.dispose();
      workspace.dispose();
    });
    await tester.binding.setSurfaceSize(const Size(860, 860));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ShadApp(
        theme: AppTheme.lightFor(),
        home: SettingsScope(
          settingsController: settings,
          backupService: backup,
          workspaceController: workspace,
          windowController: window,
          dataDirectoryService: directory,
          child: const SettingsPage(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings page fits the 680x860 narrow size', (tester) async {
    final settings = SettingsController(
      repository: InMemorySettingsRepository(),
    );
    await settings.initialize();
    final window = WindowController(desktopService: FakeDesktopWindowService());
    await window.initialize();
    final workspace = WorkspaceController();
    final backup = BackupService(
      directory: Directory(
        '${Directory.systemTemp.path}${Platform.pathSeparator}LiteTodo-settings-test',
      ),
    );
    final directory = FakeDataDirectoryService();
    addTearDown(() {
      settings.dispose();
      window.dispose();
      workspace.dispose();
    });
    await tester.binding.setSurfaceSize(const Size(680, 860));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ShadApp(
        theme: AppTheme.lightFor(),
        home: SettingsScope(
          settingsController: settings,
          backupService: backup,
          workspaceController: workspace,
          windowController: window,
          dataDirectoryService: directory,
          child: const SettingsPage(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'settings categories isolate the active module at wide and narrow sizes',
    (tester) async {
      final settings = SettingsController(
        repository: InMemorySettingsRepository(),
      );
      await settings.initialize();
      final window = WindowController(
        desktopService: FakeDesktopWindowService(),
      );
      await window.initialize();
      final workspace = WorkspaceController();
      final backup = BackupService(
        directory: Directory(
          '${Directory.systemTemp.path}${Platform.pathSeparator}LiteTodo-settings-category-test',
        ),
      );
      final directory = FakeDataDirectoryService();
      addTearDown(() {
        settings.dispose();
        window.dispose();
        workspace.dispose();
      });
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const sectionTypes = <Type>[
        GeneralSettingsSection,
        WindowSettingsSection,
        AppearanceSettingsSection,
        TypographySettingsSection,
        DataSettingsSection,
        AboutSettingsSection,
      ];

      Future<void> pumpAtSize(Size size) async {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(
          ShadApp(
            theme: AppTheme.lightFor(),
            home: SettingsScope(
              settingsController: settings,
              backupService: backup,
              workspaceController: workspace,
              windowController: window,
              dataDirectoryService: directory,
              child: const SettingsPage(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
      }

      for (final size in const [Size(1672, 941), Size(680, 860)]) {
        await pumpAtSize(size);
        for (var index = 0; index < sectionTypes.length; index++) {
          final category = find.byKey(
            ValueKey<String>('settings-category-$index'),
          );
          await tester.ensureVisible(category);
          await tester.pump();
          await tester.tap(category);
          await tester.pump();

          expect(find.byType(sectionTypes[index]), findsOneWidget);
          expect(find.byType(SettingsCard), findsOneWidget);
          for (var other = 0; other < sectionTypes.length; other++) {
            final section = find.byKey(
              ValueKey<String>('settings-section-$other'),
              skipOffstage: false,
            );
            expect(tester.widget<Offstage>(section).offstage, other != index);
            if (other != index) {
              expect(find.byType(sectionTypes[other]), findsNothing);
            }
          }
        }
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('settings P0 groups expose window, preview, and About controls', (
    tester,
  ) async {
    final settings = SettingsController(
      repository: InMemorySettingsRepository(),
    );
    await settings.initialize();
    final window = WindowController(desktopService: FakeDesktopWindowService());
    await window.initialize();
    final workspace = WorkspaceController();
    final backup = BackupService(
      directory: Directory(
        '${Directory.systemTemp.path}${Platform.pathSeparator}LiteTodo-settings-p0-test',
      ),
    );
    final directory = FakeDataDirectoryService();
    addTearDown(() {
      settings.dispose();
      window.dispose();
      workspace.dispose();
    });
    await tester.binding.setSurfaceSize(const Size(1672, 941));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ShadApp(
        theme: AppTheme.lightFor(),
        home: SettingsScope(
          settingsController: settings,
          backupService: backup,
          workspaceController: workspace,
          windowController: window,
          dataDirectoryService: directory,
          child: const SettingsPage(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey<String>('settings-category-rail')),
      findsOneWidget,
    );
    final railRect = tester.getRect(
      find.byKey(const ValueKey<String>('settings-category-rail')),
    );
    final firstCardRect = tester.getRect(find.byType(SettingsCard).first);
    expect(railRect.width, closeTo(260, 0.01));
    expect(railRect.height, closeTo(941 - 18 - 34 - 10 - 14, 0.01));
    expect(railRect.top, closeTo(62, 2));
    expect(firstCardRect.top, closeTo(railRect.top, 0.01));
    expect(firstCardRect.left - railRect.right, closeTo(24, 0.01));
    expect(find.text('桌面与窗口'), findsOneWidget);
    expect(find.text('关于 LiteTodo'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('settings-theme-preview-light-blue')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('settings-theme-preview-light-purple')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('settings-theme-preview-dark-blue')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('settings-theme-preview-system-blue')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('settings-window-reset-position')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey<String>('settings-category-1')));
    await tester.pump();
    expect(find.text('桌面与窗口'), findsNWidgets(2));
    expect(
      find.byKey(const ValueKey<String>('settings-window-reset-position')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey<String>('settings-category-2')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('settings-theme-preview-light-blue')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('settings-theme-preview-light-purple')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('settings-theme-preview-dark-blue')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('settings-theme-preview-system-blue')),
      findsOneWidget,
    );

    final purplePreview = find.byKey(
      const ValueKey<String>('settings-theme-preview-light-purple'),
    );
    await tester.ensureVisible(purplePreview);
    await tester.pump();
    await tester.tap(purplePreview);
    await tester.pumpAndSettle();
    expect(settings.themeMode, AppThemeMode.light);
    expect(settings.accentColorKey, 'purple');

    await tester.tap(find.byKey(const ValueKey<String>('settings-category-5')));
    await tester.pump();
    expect(find.text('关于 LiteTodo'), findsOneWidget);

    for (var index = 0; index < 6; index++) {
      final itemFinder = find.byKey(
        ValueKey<String>('settings-category-$index'),
      );
      await tester.ensureVisible(itemFinder);
      await tester.pump();
      await tester.tap(itemFinder);
      await tester.pump();
      final selectedItems = tester
          .widgetList<CategoryItem>(find.byType(CategoryItem))
          .where((item) => item.selected)
          .toList(growable: false);
      expect(selectedItems, hasLength(1));
      expect(tester.widget<CategoryItem>(itemFinder).selected, isTrue);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'settings route sizes the wide rail to the shell viewport and scrolls all sections',
    (tester) async {
      final navigation = AppNavigationController();
      final workspace = WorkspaceController();
      final settings = SettingsController(
        repository: InMemorySettingsRepository(),
      );
      final window = WindowController(
        desktopService: FakeDesktopWindowService(),
      );
      final backup = BackupService(
        directory: Directory(
          '${Directory.systemTemp.path}${Platform.pathSeparator}LiteTodo-settings-route-test',
        ),
      );
      final directory = FakeDataDirectoryService();
      addTearDown(() {
        navigation.dispose();
        workspace.dispose();
        settings.dispose();
        window.dispose();
      });
      await tester.binding.setSurfaceSize(const Size(1672, 941));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        LiteTodoApp(
          controller: workspace,
          windowController: window,
          navigationController: navigation,
          settingsController: settings,
          backupService: backup,
          dataDirectoryService: directory,
        ),
      );
      await tester.pumpAndSettle();
      navigation.goSettings();
      await tester.pumpAndSettle();

      final rail = find.byKey(const ValueKey<String>('settings-category-rail'));
      expect(rail, findsOneWidget);
      final railRect = tester.getRect(rail);
      expect(railRect.top, closeTo(125, 4));
      // The widget surface includes the ~9px Win32 non-client area; the
      // corresponding 1672x941 Release screenshot lands near y=918.
      expect(railRect.bottom, closeTo(927, 4));
      final firstCardRect = tester.getRect(find.byType(SettingsCard).first);
      expect(firstCardRect.top, closeTo(railRect.top, 0.01));

      await tester.tap(
        find.byKey(const ValueKey<String>('settings-category-4')),
      );
      await tester.pumpAndSettle();
      expect(find.text('数据与备份'), findsWidgets);
      final dataRect = tester.getRect(find.byType(SettingsCard).first);
      expect(dataRect.top, lessThan(941));
      expect(dataRect.bottom, greaterThan(0));

      final aboutCategory = find.byKey(
        const ValueKey<String>('settings-category-5'),
      );
      await tester.ensureVisible(aboutCategory);
      await tester.pump();
      await tester.tap(aboutCategory);
      await tester.pumpAndSettle();
      expect(find.text('关于 LiteTodo'), findsOneWidget);
      final aboutRect = tester.getRect(find.byType(SettingsCard).first);
      expect(aboutRect.top, lessThan(941));
      expect(aboutRect.bottom, greaterThan(0));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('settings surface keeps rail and hotkey readable in dark theme', (
    tester,
  ) async {
    final settings = SettingsController(
      repository: InMemorySettingsRepository(),
    );
    await settings.initialize();
    final window = WindowController(desktopService: FakeDesktopWindowService());
    await window.initialize();
    final workspace = WorkspaceController();
    final backup = BackupService(
      directory: Directory(
        '${Directory.systemTemp.path}${Platform.pathSeparator}LiteTodo-settings-dark-test',
      ),
    );
    final directory = FakeDataDirectoryService();
    addTearDown(() {
      settings.dispose();
      window.dispose();
      workspace.dispose();
    });
    await tester.binding.setSurfaceSize(const Size(860, 860));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ShadApp(
        theme: AppTheme.darkFor(),
        home: SettingsScope(
          settingsController: settings,
          backupService: backup,
          workspaceController: workspace,
          windowController: window,
          dataDirectoryService: directory,
          child: const SettingsPage(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey<String>('settings-category-0')),
      findsOneWidget,
    );
    expect(find.text('当前快捷键'), findsOneWidget);
    expect(find.text('通用设置'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
