import 'dart:async';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../application/app_navigation_controller.dart';
import '../application/data_transfer_controller.dart';
import '../application/quick_add_controller.dart';
import '../application/settings_controller.dart';
import '../application/sticky_notes_controller.dart';
import '../application/window_controller.dart';
import '../application/workspace_controller.dart';
import '../domain/models/app_settings.dart';
import '../domain/models/project_group.dart';
import '../infrastructure/platform/data_directory_service.dart';
import '../infrastructure/platform/sticky_notes_window_service.dart';
import '../infrastructure/persistence/backup_service.dart';
import '../presentation/shell/app_shell.dart';
import '../presentation/settings/settings_scope.dart';
import 'app_constants.dart';
import 'theme/app_theme.dart';

class LiteTodoApp extends StatefulWidget {
  const LiteTodoApp({
    super.key,
    this.controller,
    this.windowController,
    this.quickAddController,
    this.navigationController,
    this.settingsController,
    this.backupService,
    this.dataTransferController,
    this.dataDirectoryService,
    this.stickyNotesWindowService,
  });

  final WorkspaceController? controller;
  final WindowController? windowController;
  final QuickAddController? quickAddController;
  final AppNavigationController? navigationController;
  final SettingsController? settingsController;
  final BackupService? backupService;
  final DataTransferController? dataTransferController;
  final DataDirectoryService? dataDirectoryService;
  final StickyNotesWindowService? stickyNotesWindowService;

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
        onSubmitWithTarget: (title, projectId) =>
            _controller.addTodoAndFlush(title, projectId: projectId),
      );
  late final bool _ownsQuickAddController = widget.quickAddController == null;
  late final AppNavigationController _navigationController =
      widget.navigationController ?? AppNavigationController();
  late final bool _ownsNavigationController =
      widget.navigationController == null;
  late final SettingsController _settingsController =
      widget.settingsController ??
      SettingsController(repository: InMemorySettingsRepository());
  late final bool _ownsSettingsController = widget.settingsController == null;
  late final BackupService _backupService =
      widget.backupService ?? createTestBackupService();
  late final DataDirectoryService _dataDirectoryService =
      widget.dataDirectoryService ?? FakeDataDirectoryService();
  late final StickyNotesController _stickyNotesController =
      StickyNotesController(
        workspace: _controller,
        windowService:
            widget.stickyNotesWindowService ?? FakeStickyNotesWindowService(),
      );
  QuickAddControllerBinding? _quickAddBinding;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncQuickAddTargets);
    _settingsController.addListener(_syncQuickAddSettings);
    _quickAddBinding = _quickAddController.bindApp(
      onSubmitWithTarget: (title, projectId) =>
          _controller.addTodoAndFlush(title, projectId: projectId),
      lastProjectId: _settingsController.lastProjectId,
      onLastProjectChanged: _settingsController.setLastProjectId,
    );
    _syncQuickAddTargets();
    unawaited(_initializeSettings());
  }

  Future<void> _initializeSettings() async {
    if (_settingsController.isInitialized) return;
    try {
      await _settingsController.initialize();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_syncQuickAddTargets);
    _settingsController.removeListener(_syncQuickAddSettings);
    _quickAddBinding?.dispose();
    _stickyNotesController.dispose();
    if (_ownsQuickAddController) _quickAddController.dispose();
    if (_ownsWindowController) _windowController.dispose();
    if (_ownsController) _controller.dispose();
    if (_ownsNavigationController) _navigationController.dispose();
    if (_ownsSettingsController) _settingsController.dispose();
    super.dispose();
  }

  void _syncQuickAddSettings() {
    _quickAddController.setLastProjectId(_settingsController.lastProjectId);
  }

  void _syncQuickAddTargets() {
    final groups = <String, ProjectGroup>{
      for (final group in _controller.groups) group.id: group,
    };
    final projects =
        _controller.projects
            .where((project) {
              if (project.archived) return false;
              final group = groups[project.groupId];
              return group == null || group.archived != true;
            })
            .toList(growable: false)
          ..sort((left, right) {
            final order = left.sortOrder.compareTo(right.sortOrder);
            if (order != 0) return order;
            final name = left.name.toLowerCase().compareTo(
              right.name.toLowerCase(),
            );
            return name != 0 ? name : left.id.compareTo(right.id);
          });
    _quickAddController.setAvailableTargets(<QuickAddTarget>[
      const QuickAddTarget.inbox(),
      for (final project in projects)
        QuickAddTarget.project(
          id: project.id,
          name: project.name,
          iconKey: project.iconKey,
          colorKey: project.colorKey,
          groupId: project.groupId,
          groupName: groups[project.groupId]?.name,
        ),
    ]);
    _quickAddController.setWorkspaceProjectId(
      _controller.scope == WorkspaceScope.project
          ? _controller.projectScopeId
          : null,
    );
  }

  void _toggleTheme() {
    final next = _settingsController.themeMode == AppThemeMode.dark
        ? AppThemeMode.light
        : AppThemeMode.dark;
    unawaited(_settingsController.setThemeMode(next));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _settingsController,
      builder: (context, child) {
        final settings = _settingsController.settings;
        final themeMode = switch (settings.themeMode) {
          AppThemeMode.light => ThemeMode.light,
          AppThemeMode.dark => ThemeMode.dark,
          AppThemeMode.system => ThemeMode.system,
        };
        return ShadApp(
          title: AppConstants.appName,
          theme: AppTheme.lightFor(
            accentColorKey: settings.accentColorKey,
            fontFamilyKey: settings.fontFamilyKey,
          ),
          darkTheme: AppTheme.darkFor(
            accentColorKey: settings.accentColorKey,
            fontFamilyKey: settings.fontFamilyKey,
          ),
          themeMode: themeMode,
          // Keep ShadApp's built-in 200ms theme controller, but evaluate the
          // end state from its first frame so a user toggle is immediate.
          themeCurve: const Threshold(0.0),
          // WidgetsApp keeps the initial home route alive while its inherited
          // theme changes.  Apply the current snapshot at the app builder
          // boundary so the mounted shell sees the new palette immediately,
          // even when the route itself is not recreated.
          builder: (context, child) {
            final brightness = themeMode == ThemeMode.dark
                ? Brightness.dark
                : themeMode == ThemeMode.light
                ? Brightness.light
                : MediaQuery.maybePlatformBrightnessOf(context) ??
                      Brightness.light;
            final liveTheme = brightness == Brightness.dark
                ? AppTheme.darkFor(
                    accentColorKey: settings.accentColorKey,
                    fontFamilyKey: settings.fontFamilyKey,
                  )
                : AppTheme.lightFor(
                    accentColorKey: settings.accentColorKey,
                    fontFamilyKey: settings.fontFamilyKey,
                  );
            return ShadTheme(
              data: liveTheme,
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: Builder(
            key: ValueKey<AppThemeMode>(settings.themeMode),
            builder: (context) {
              final media = MediaQuery.maybeOf(context);
              final scaledMedia = media?.copyWith(
                textScaler: TextScaler.linear(settings.fontScale),
              );
              final appShell = SettingsScope(
                settingsController: _settingsController,
                backupService: _backupService,
                dataTransferController: widget.dataTransferController,
                workspaceController: _controller,
                windowController: _windowController,
                dataDirectoryService: _dataDirectoryService,
                child: AppShell(
                  controller: _controller,
                  windowController: _windowController,
                  quickAddController: _quickAddController,
                  navigationController: _navigationController,
                  stickyNotesController: _stickyNotesController,
                  onToggleTheme: _toggleTheme,
                  fontFamily: AppTheme.fontFamilyFor(settings.fontFamilyKey),
                  fontFamilyFallback: AppTheme.fontFamilyFallbackFor(
                    settings.fontFamilyKey,
                  ),
                ),
              );
              if (scaledMedia == null) return appShell;
              return MediaQuery(data: scaledMedia, child: appShell);
            },
          ),
        );
      },
    );
  }
}
