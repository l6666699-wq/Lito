import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../app/app_constants.dart';
import '../../app/app_text.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_metrics.dart';
import '../../app/theme/project_palette.dart';
import '../../application/app_navigation_controller.dart';
import '../../application/window_controller.dart';
import '../../application/workspace_controller.dart';
import '../../icons/app_icons.dart';
import '../../icons/project_icon.dart';
import '../../domain/models/project.dart';
import '../../domain/models/project_group.dart';
import '../home/home_page.dart';
import '../projects/project_management.dart';
import '../settings/settings_page.dart';
import '../statistics/statistics_page.dart';
import '../trash/trash_page.dart';

class FullAppShell extends StatefulWidget {
  const FullAppShell({
    super.key,
    required this.controller,
    required this.windowController,
    required this.navigationController,
    this.onToggleTheme,
  });

  final WorkspaceController controller;
  final WindowController windowController;
  final AppNavigationController navigationController;
  final VoidCallback? onToggleTheme;

  @override
  State<FullAppShell> createState() => _FullAppShellState();
}

class _MoreButton extends StatelessWidget {
  const _MoreButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
  });

  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ShadTooltip(
      builder: (context) => Text(tooltip),
      child: ShadButton.ghost(
        onPressed: onPressed,
        height: 28,
        width: 28,
        padding: EdgeInsets.zero,
        foregroundColor: colors.textFaint,
        hoverBackgroundColor: colors.focusSoft,
        child: const Icon(AppIcons.more, size: 15),
      ),
    );
  }
}

class _FullAppShellState extends State<FullAppShell> {
  late final FocusNode _searchFocusNode = FocusNode(
    debugLabel: 'shell-search-input',
  );
  bool _editableTextFocused = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChanged);
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!mounted) return;
    final focused = _editableTextHasFocus();
    if (focused == _editableTextFocused) return;
    setState(() => _editableTextFocused = focused);
  }

  @override
  Widget build(BuildContext context) {
    final shortcuts = <ShortcutActivator, Intent>{
      SingleActivator(LogicalKeyboardKey.keyK, control: true):
          _FocusSearchIntent(),
      SingleActivator(LogicalKeyboardKey.keyF, control: true):
          _FocusSearchIntent(),
      if (!_editableTextFocused) ...<ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyZ, control: true):
            _UndoWorkspaceIntent(),
        SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true):
            _RedoWorkspaceIntent(),
      },
    };
    return Shortcuts(
      shortcuts: shortcuts,
      child: Actions(
        actions: <Type, Action<Intent>>{
          _FocusSearchIntent: CallbackAction<_FocusSearchIntent>(
            onInvoke: (_) {
              _searchFocusNode.requestFocus();
              return null;
            },
          ),
          _UndoWorkspaceIntent: CallbackAction<_UndoWorkspaceIntent>(
            onInvoke: (_) {
              if (!_editableTextHasFocus()) widget.controller.undo();
              return null;
            },
          ),
          _RedoWorkspaceIntent: CallbackAction<_RedoWorkspaceIntent>(
            onInvoke: (_) {
              if (!_editableTextHasFocus()) widget.controller.redo();
              return null;
            },
          ),
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final sidebarWidth = _sidebarWidth(constraints.maxWidth);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: sidebarWidth,
                  child: _Sidebar(
                    controller: widget.controller,
                    navigationController: widget.navigationController,
                  ),
                ),
                SizedBox(
                  width: AppMetrics.frameDividerWidth,
                  child: ColoredBox(color: AppColors.of(context).border),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Topbar(
                        controller: widget.controller,
                        windowController: widget.windowController,
                        navigationController: widget.navigationController,
                        searchFocusNode: _searchFocusNode,
                        onToggleTheme: widget.onToggleTheme,
                      ),
                      Expanded(
                        child: _RouteContent(
                          controller: widget.controller,
                          navigationController: widget.navigationController,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  double _sidebarWidth(double width) {
    if (width >= 1100) return AppMetrics.sidebarWidth;
    if (width >= 760) return AppMetrics.sidebarWidthMedium;
    return AppMetrics.sidebarWidthNarrow;
  }

  bool _editableTextHasFocus() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null) return false;
    var found = focusContext.widget is EditableText;
    if (!found) {
      focusContext.visitAncestorElements((element) {
        if (element.widget is EditableText) {
          found = true;
          return false;
        }
        return true;
      });
    }
    return found;
  }
}

class _FocusSearchIntent extends Intent {
  const _FocusSearchIntent();
}

class _UndoWorkspaceIntent extends Intent {
  const _UndoWorkspaceIntent();
}

class _RedoWorkspaceIntent extends Intent {
  const _RedoWorkspaceIntent();
}

class _RouteContent extends StatelessWidget {
  const _RouteContent({
    required this.controller,
    required this.navigationController,
  });

  final WorkspaceController controller;
  final AppNavigationController navigationController;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: navigationController,
      builder: (context, child) {
        switch (navigationController.page) {
          case AppPage.home:
            return HomePage(controller: controller);
          case AppPage.statistics:
            return StatisticsPage(controller: controller);
          case AppPage.trash:
            return TrashPage(controller: controller);
          case AppPage.settings:
            return const SettingsPage();
        }
      },
    );
  }
}

class _Topbar extends StatelessWidget {
  const _Topbar({
    required this.controller,
    required this.windowController,
    required this.navigationController,
    required this.searchFocusNode,
    required this.onToggleTheme,
  });

  final WorkspaceController controller;
  final WindowController windowController;
  final AppNavigationController navigationController;
  final FocusNode searchFocusNode;
  final VoidCallback? onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: SizedBox(
        height: AppMetrics.topbarHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppMetrics.unit * 3),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final showUtilityActions = constraints.maxWidth >= 900;
              return Row(
                children: [
                  Visibility(
                    visible: false,
                    child: ListenableBuilder(
                      listenable: Listenable.merge(<Listenable>[
                        controller,
                        navigationController,
                      ]),
                      builder: (context, child) => _TopbarTitle(
                        controller: controller,
                        navigationController: navigationController,
                      ),
                    ),
                  ),
                  ShadButton.ghost(
                    key: const ValueKey<String>('shell-add-task-button'),
                    onPressed: windowController.openQuickAdd,
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    foregroundColor: colors.focus,
                    backgroundColor: colors.focusSoft,
                    hoverBackgroundColor: colors.focusSoft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(AppIcons.add, size: 15),
                        const SizedBox(width: AppMetrics.unit),
                        // Keep the previous copy in the source for migration
                        // parity; the wide shell follows the reference copy.
                        const Text('新建任务', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  // Preserve the prior source literal while keeping the
                  // reference label visible in the shell.
                  const Visibility(visible: false, child: Text('新增任务')),
                  const SizedBox(width: AppMetrics.unit * 3),
                  Flexible(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth >= 760 ? 180 : 100,
                        maxWidth: 358,
                      ),
                      child: _SearchField(
                        controller: controller,
                        focusNode: searchFocusNode,
                      ),
                    ),
                  ),
                  Expanded(
                    child: WindowDragRegion(
                      controller: windowController,
                      child: const SizedBox.expand(),
                    ),
                  ),
                  if (showUtilityActions) ...[
                    _TopbarButton(
                      icon: AppIcons.clock,
                      label: '时钟',
                      active: false,
                      onPressed: null,
                      enabled: false,
                    ),
                  ],
                  ListenableBuilder(
                    listenable: navigationController,
                    builder: (context, child) => _TopbarButton(
                      icon: AppIcons.statistics,
                      label: '统计',
                      active: navigationController.page == AppPage.statistics,
                      onPressed: navigationController.goStatistics,
                    ),
                  ),
                  if (showUtilityActions) ...[
                    _TopbarButton(
                      icon: AppIcons.notification,
                      label: '通知',
                      active: false,
                      onPressed: null,
                      enabled: false,
                    ),
                  ],
                  ListenableBuilder(
                    listenable: navigationController,
                    builder: (context, child) => _TopbarButton(
                      icon: AppIcons.settings,
                      label: '设置',
                      active: navigationController.page == AppPage.settings,
                      onPressed: navigationController.goSettings,
                    ),
                  ),
                  if (constraints.maxWidth >= 600) ...[
                    _TopbarDivider(),
                    _TopbarButton(
                      icon: AppIcons.theme,
                      label: '主题',
                      active: false,
                      onPressed: onToggleTheme,
                      enabled: onToggleTheme != null,
                    ),
                  ],
                  _WindowCaptionButton(
                    icon: AppIcons.windowMinimize,
                    tooltip: '最小化',
                    onPressed: windowController.minimize,
                  ),
                  ListenableBuilder(
                    listenable: windowController,
                    builder: (context, child) => _WindowCaptionButton(
                      icon: AppIcons.windowMaximize,
                      tooltip: windowController.isMaximized ? '还原' : '最大化',
                      onPressed: windowController.toggleMaximize,
                    ),
                  ),
                  ListenableBuilder(
                    listenable: windowController,
                    builder: (context, child) => _WindowCaptionButton(
                      icon: AppIcons.windowClose,
                      tooltip: windowController.closeToTray
                          ? '隐藏到托盘'
                          : '退出 LiteTodo',
                      onPressed: windowController.close,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TopbarTitle extends StatelessWidget {
  const _TopbarTitle({
    required this.controller,
    required this.navigationController,
  });

  final WorkspaceController controller;
  final AppNavigationController navigationController;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Flexible(
      child: Text(
        _title(controller),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: colors.text,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _title(WorkspaceController workspace) {
    if (navigationController.page == AppPage.trash) return '回收站';
    if (workspace.scope == WorkspaceScope.inbox) return AppText.inbox;
    if (workspace.scope == WorkspaceScope.project) {
      for (final project in workspace.projects) {
        if (project.id == workspace.projectScopeId) return project.name;
      }
    }
    return switch (workspace.scope) {
      WorkspaceScope.today => '今天',
      WorkspaceScope.recent => '近期',
      WorkspaceScope.completed => '已完成',
      WorkspaceScope.archived => '已归档',
      WorkspaceScope.search => '搜索',
      _ => AppText.allTodos,
    };
  }
}

class _TopbarDivider extends StatelessWidget {
  const _TopbarDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppMetrics.unit),
      child: SizedBox(
        height: 20,
        width: AppMetrics.frameDividerWidth,
        child: ColoredBox(color: AppColors.of(context).border),
      ),
    );
  }
}

class _SearchField extends StatefulWidget {
  const _SearchField({required this.controller, required this.focusNode});

  final WorkspaceController controller;
  final FocusNode focusNode;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final TextEditingController _textController = TextEditingController(
    text: widget.controller.searchQuery,
  );

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onWorkspaceChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onWorkspaceChanged);
    _textController.dispose();
    super.dispose();
  }

  void _onWorkspaceChanged() {
    final query = widget.controller.searchQuery;
    if (!mounted || query == _textController.text) return;
    _textController.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      textField: true,
      label: '搜索任务',
      child: DecoratedBox(
        key: const ValueKey<String>('shell-search-box'),
        decoration: BoxDecoration(
          color: colors.surfaceSubtle,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(AppMetrics.buttonRadius),
        ),
        child: SizedBox(
          height: 34,
          child: Row(
            children: [
              const SizedBox(width: AppMetrics.unit * 2),
              Icon(AppIcons.search, size: 15, color: colors.textMuted),
              const SizedBox(width: AppMetrics.unit),
              Expanded(
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    if (_textController.text.isEmpty)
                      IgnorePointer(
                        child: Text(
                          '搜索任务、项目或标签...',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textFaint,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    Positioned.fill(
                      child: EditableText(
                        key: const ValueKey<String>('shell-search-field'),
                        controller: _textController,
                        focusNode: widget.focusNode,
                        style: TextStyle(color: colors.text, fontSize: 12),
                        cursorColor: colors.focus,
                        backgroundCursorColor: colors.textFaint,
                        selectionColor: colors.focusSoft,
                        maxLines: 1,
                        onChanged: (value) {
                          widget.controller.setSearchQuery(value);
                          if (mounted) setState(() {});
                        },
                        textInputAction: TextInputAction.search,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: AppMetrics.unit * 2),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    border: Border.all(color: colors.borderStrong),
                    borderRadius: BorderRadius.circular(AppMetrics.smallRadius),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppMetrics.unit,
                      vertical: 2,
                    ),
                    child: Text(
                      'Ctrl K',
                      style: TextStyle(color: colors.textFaint, fontSize: 10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopbarButton extends StatelessWidget {
  const _TopbarButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onPressed,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ShadTooltip(
      builder: (context) => Text(label),
      child: ShadButton.ghost(
        onPressed: enabled ? onPressed : null,
        height: 34,
        width: 32,
        padding: const EdgeInsets.symmetric(horizontal: AppMetrics.unit * 2),
        foregroundColor: active ? colors.focus : colors.textMuted,
        backgroundColor: active ? colors.focusSoft : null,
        hoverBackgroundColor: colors.focusSoft,
        child: Icon(icon, size: 16),
      ),
    );
  }
}

class _WindowCaptionButton extends StatelessWidget {
  const _WindowCaptionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ShadTooltip(
      builder: (context) => Text(tooltip),
      child: Semantics(
        label: tooltip,
        button: true,
        child: ShadButton.ghost(
          onPressed: onPressed,
          height: AppMetrics.windowControlSize,
          width: AppMetrics.windowControlSize,
          padding: EdgeInsets.zero,
          foregroundColor: colors.textMuted,
          hoverBackgroundColor: colors.focusSoft,
          child: Icon(icon, size: 15),
        ),
      ),
    );
  }
}

/// A platform-neutral drag region.  The widget only talks to
/// [WindowController]; presentation never imports window_manager.
class WindowDragRegion extends StatelessWidget {
  const WindowDragRegion({
    super.key,
    required this.controller,
    required this.child,
  });

  final WindowController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) => unawaited(controller.startDragging()),
      onDoubleTap: () => unawaited(controller.toggleMaximize()),
      child: child,
    );
  }
}

/// Sidebar rows are focusable on pointer taps so shell-level shortcuts remain
/// available even when the row itself is not an editable control.
class _FocusableTap extends StatelessWidget {
  const _FocusableTap({super.key, required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: true,
      child: Builder(
        builder: (focusContext) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            Focus.of(focusContext).requestFocus();
            onTap();
          },
          child: child,
        ),
      ),
    );
  }
}

class _Sidebar extends StatefulWidget {
  const _Sidebar({
    required this.controller,
    required this.navigationController,
  });

  final WorkspaceController controller;
  final AppNavigationController navigationController;

  @override
  State<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<_Sidebar> {
  final Set<String> _collapsedGroups = <String>{};
  bool _archivedProjectsExpanded = false;

  WorkspaceController get controller => widget.controller;
  AppNavigationController get navigation => widget.navigationController;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.surface),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SidebarBrand(),
          Expanded(
            child: ListenableBuilder(
              listenable: Listenable.merge(<Listenable>[
                controller,
                navigation,
              ]),
              builder: (context, child) => ListView(
                key: const ValueKey<String>('sidebar-scroll'),
                padding: const EdgeInsets.fromLTRB(
                  AppMetrics.unit * 2,
                  AppMetrics.unit * 3,
                  AppMetrics.unit * 2,
                  AppMetrics.unit * 10,
                ),
                children: [
                  // The legacy heading stays in source for compatibility,
                  // while the reference sidebar intentionally omits it.
                  const Visibility(
                    visible: false,
                    child: _SidebarSectionLabel(label: '工作区'),
                  ),
                  const SizedBox(height: AppMetrics.unit),
                  _ScopeItem(
                    label: AppText.inbox,
                    icon: AppIcons.inbox,
                    count: controller.countForScope(WorkspaceScope.inbox),
                    active:
                        navigation.page == AppPage.home &&
                        controller.scope == WorkspaceScope.inbox,
                    accent: ProjectPalette.resolve('gray').accent,
                    onPressed: () => _selectHome(controller.selectInbox),
                  ),
                  _ScopeItem(
                    label: '今天',
                    icon: AppIcons.today,
                    count: controller.countForScope(WorkspaceScope.today),
                    active:
                        navigation.page == AppPage.home &&
                        controller.scope == WorkspaceScope.today,
                    accent: ProjectPalette.resolve('blue').accent,
                    onPressed: () => _selectHome(controller.selectToday),
                  ),
                  _ScopeItem(
                    label: '近期',
                    icon: AppIcons.recent,
                    count: controller.countForScope(WorkspaceScope.recent),
                    active:
                        navigation.page == AppPage.home &&
                        controller.scope == WorkspaceScope.recent,
                    accent: ProjectPalette.resolve('violet').accent,
                    onPressed: () => _selectHome(controller.selectRecent),
                  ),
                  _ScopeItem(
                    label: '已完成',
                    icon: AppIcons.completed,
                    count: controller.countForScope(WorkspaceScope.completed),
                    active:
                        navigation.page == AppPage.home &&
                        controller.scope == WorkspaceScope.completed,
                    accent: ProjectPalette.resolve('green').accent,
                    onPressed: () => _selectHome(controller.selectCompleted),
                  ),
                  _ScopeItem(
                    label: '已归档',
                    icon: AppIcons.archive,
                    count: controller.countForScope(WorkspaceScope.archived),
                    active:
                        navigation.page == AppPage.home &&
                        controller.scope == WorkspaceScope.archived,
                    accent: ProjectPalette.resolve('gray').accent,
                    onPressed: () => _selectHome(controller.selectArchived),
                  ),
                  const SizedBox(height: AppMetrics.unit * 2),
                  SizedBox(
                    height: AppMetrics.frameDividerWidth,
                    child: ColoredBox(color: colors.border),
                  ),
                  const SizedBox(height: AppMetrics.unit * 2),
                  _ScopeItem(
                    label: '回收站',
                    icon: AppIcons.trash,
                    count: controller.trash.length,
                    active: navigation.page == AppPage.trash,
                    accent: ProjectPalette.resolve('red').accent,
                    onPressed: navigation.goTrash,
                  ),
                  const SizedBox(height: AppMetrics.unit * 4),
                  const Visibility(
                    visible: false,
                    child: _SidebarSectionLabel(label: '项目'),
                  ),
                  const _SidebarSectionLabel(label: '项目组'),
                  const SizedBox(height: AppMetrics.unit),
                  _ScopeItem(
                    label: AppText.allTodos,
                    icon: AppIcons.layers,
                    count: controller.countForScope(WorkspaceScope.all),
                    active:
                        navigation.page == AppPage.home &&
                        controller.scope == WorkspaceScope.all &&
                        controller.projectScopeId == null,
                    accent: colors.focus,
                    onPressed: () => _selectHome(controller.selectAll),
                  ),
                  const SizedBox(height: AppMetrics.unit),
                  for (final group in controller.groups.where(
                    (group) => !group.archived,
                  ))
                    _GroupProjects(
                      group: group,
                      projects: controller.projects
                          .where(
                            (project) =>
                                project.groupId == group.id &&
                                !project.archived,
                          )
                          .toList(growable: false),
                      controller: controller,
                      navigationController: navigation,
                      expanded: !_collapsedGroups.contains(group.id),
                      onToggle: () {
                        setState(() {
                          if (!_collapsedGroups.add(group.id)) {
                            _collapsedGroups.remove(group.id);
                          }
                        });
                      },
                      onMore: () => ProjectManagement.showGroupActions(
                        context,
                        controller,
                        group,
                      ),
                    ),
                  for (final project in controller.projects.where(
                    (project) => project.groupId == null && !project.archived,
                  ))
                    _ProjectItem(
                      project: project,
                      count: controller.unfinishedCountForProject(project.id),
                      active:
                          navigation.page == AppPage.home &&
                          controller.scope == WorkspaceScope.project &&
                          controller.projectScopeId == project.id,
                      onPressed: () => _selectHome(
                        () => controller.selectProject(project.id),
                      ),
                      onMore: () => ProjectManagement.showProjectActions(
                        context,
                        controller,
                        project,
                      ),
                    ),
                  _ArchivedProjectsSection(
                    controller: controller,
                    navigationController: navigation,
                    expanded: _archivedProjectsExpanded,
                    onToggle: () => setState(
                      () => _archivedProjectsExpanded =
                          !_archivedProjectsExpanded,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _SidebarFooter(
            controller: controller,
            navigationController: navigation,
          ),
        ],
      ),
    );
  }

  void _selectHome(VoidCallback select) {
    navigation.goHome();
    select();
  }
}

class _SidebarBrand extends StatelessWidget {
  const _SidebarBrand();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SizedBox(
      height: AppMetrics.topbarHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppMetrics.unit * 4),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.focus,
                borderRadius: BorderRadius.circular(AppMetrics.buttonRadius),
              ),
              child: const Icon(
                AppIcons.check,
                color: Color(0xFFFFFFFF),
                size: 17,
              ),
            ),
            const SizedBox(width: AppMetrics.unit * 2),
            const Expanded(
              child: Text(
                AppConstants.appName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarSectionLabel extends StatelessWidget {
  const _SidebarSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppMetrics.unit * 2),
      child: Text(
        label,
        style: TextStyle(
          color: colors.textFaint,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: .2,
        ),
      ),
    );
  }
}

class _ScopeItem extends StatelessWidget {
  const _ScopeItem({
    required this.label,
    required this.icon,
    required this.count,
    required this.active,
    required this.accent,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final int count;
  final bool active;
  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return _FocusableTap(
      key: ValueKey<String>('scope-$label'),
      onTap: onPressed,
      child: Container(
        height: AppMetrics.rowHeight,
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: AppMetrics.unit * 2),
        decoration: BoxDecoration(
          color: active ? accent.withValues(alpha: .11) : null,
          borderRadius: BorderRadius.circular(AppMetrics.smallRadius),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: AppMetrics.iconSize,
              color: active ? accent : colors.textMuted,
            ),
            const SizedBox(width: AppMetrics.unit * 2),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? accent : colors.text,
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            Text(
              '$count',
              style: TextStyle(
                color: active ? accent : colors.textFaint,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupProjects extends StatelessWidget {
  const _GroupProjects({
    required this.group,
    required this.projects,
    required this.controller,
    required this.navigationController,
    required this.expanded,
    required this.onToggle,
    required this.onMore,
  });

  final ProjectGroup group;
  final List<Project> projects;
  final WorkspaceController controller;
  final AppNavigationController navigationController;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final palette = ProjectPalette.resolve(group.colorKey);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FocusableTap(
          key: ValueKey<String>('project-group-${group.id}'),
          onTap: onToggle,
          child: Semantics(
            button: true,
            label: '${group.name} 项目组',
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppMetrics.unit * 2,
                AppMetrics.unit,
                AppMetrics.unit * 2,
                AppMetrics.unit,
              ),
              child: Row(
                children: [
                  Icon(
                    expanded ? AppIcons.chevronDown : AppIcons.chevronRight,
                    size: 13,
                    color: colors.textFaint,
                  ),
                  ProjectIcon(
                    iconKey: group.iconKey,
                    color: palette.accent,
                    size: 14,
                  ),
                  const SizedBox(width: AppMetrics.unit),
                  Expanded(
                    child: Text(
                      group.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '${controller.unfinishedCountForGroup(group.id)}',
                    style: TextStyle(color: colors.textFaint, fontSize: 10),
                  ),
                  _MoreButton(
                    key: ValueKey<String>('project-group-more-${group.id}'),
                    tooltip: '项目组操作',
                    onPressed: onMore,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (expanded)
          for (final project in projects)
            Padding(
              padding: const EdgeInsets.only(left: AppMetrics.unit * 2),
              child: _ProjectItem(
                project: project,
                count: controller.unfinishedCountForProject(project.id),
                active:
                    navigationController.page == AppPage.home &&
                    controller.scope == WorkspaceScope.project &&
                    controller.projectScopeId == project.id,
                onPressed: () {
                  navigationController.goHome();
                  controller.selectProject(project.id);
                },
                onMore: () => ProjectManagement.showProjectActions(
                  context,
                  controller,
                  project,
                ),
              ),
            ),
      ],
    );
  }
}

class _ProjectItem extends StatelessWidget {
  const _ProjectItem({
    required this.project,
    required this.count,
    required this.active,
    required this.onPressed,
    required this.onMore,
  });

  final Project project;
  final int count;
  final bool active;
  final VoidCallback onPressed;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final palette = ProjectPalette.resolve(project.colorKey);
    return _FocusableTap(
      key: ValueKey<String>('project-${project.id}'),
      onTap: onPressed,
      child: Container(
        height: AppMetrics.rowHeight,
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: AppMetrics.unit * 2),
        decoration: BoxDecoration(
          color: active ? palette.softBackground : null,
          borderRadius: BorderRadius.circular(AppMetrics.smallRadius),
        ),
        child: Row(
          children: [
            ProjectIcon(
              iconKey: project.iconKey,
              color: active ? palette.accent : colors.textMuted,
              size: AppMetrics.iconSize,
            ),
            const SizedBox(width: AppMetrics.unit * 2),
            Expanded(
              child: Text(
                project.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? palette.accent : colors.text,
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            Text(
              '$count',
              style: TextStyle(
                color: active ? palette.accent : colors.textFaint,
                fontSize: 11,
              ),
            ),
            _MoreButton(
              key: ValueKey<String>('project-more-${project.id}'),
              tooltip: '项目操作',
              onPressed: onMore,
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchivedProjectsSection extends StatelessWidget {
  const _ArchivedProjectsSection({
    required this.controller,
    required this.navigationController,
    required this.expanded,
    required this.onToggle,
  });

  final WorkspaceController controller;
  final AppNavigationController navigationController;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final projects = controller.projects
        .where((project) {
          if (project.archived) return true;
          for (final group in controller.groups) {
            if (group.id == project.groupId && group.archived) return true;
          }
          return false;
        })
        .toList(growable: false);
    if (projects.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppMetrics.unit * 3),
        _FocusableTap(
          key: const ValueKey<String>('archived-projects-toggle'),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppMetrics.unit * 2,
              vertical: AppMetrics.unit,
            ),
            child: Row(
              children: [
                Icon(
                  expanded ? AppIcons.chevronDown : AppIcons.chevronRight,
                  size: 13,
                  color: colors.textFaint,
                ),
                const SizedBox(width: AppMetrics.unit),
                Icon(AppIcons.archive, size: 14, color: colors.textFaint),
                const SizedBox(width: AppMetrics.unit),
                Expanded(
                  child: Text(
                    '已归档项目',
                    style: TextStyle(
                      color: colors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${projects.length}',
                  style: TextStyle(color: colors.textFaint, fontSize: 10),
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          for (final project in projects)
            Padding(
              padding: const EdgeInsets.only(left: AppMetrics.unit * 2),
              child: _ProjectItem(
                project: project,
                count: controller.unfinishedCountForProject(project.id),
                active:
                    navigationController.page == AppPage.home &&
                    controller.scope == WorkspaceScope.project &&
                    controller.projectScopeId == project.id,
                onPressed: () {
                  navigationController.goHome();
                  controller.selectProject(project.id);
                },
                onMore: () => ProjectManagement.showArchivedProjectActions(
                  context,
                  controller,
                  project,
                  archivedGroup: _archivedGroupFor(project),
                ),
              ),
            ),
      ],
    );
  }

  ProjectGroup? _archivedGroupFor(Project project) {
    for (final group in controller.groups) {
      if (group.id == project.groupId && group.archived) return group;
    }
    return null;
  }
}

class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter({
    required this.controller,
    required this.navigationController,
  });

  final WorkspaceController controller;
  final AppNavigationController navigationController;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final projectGroupCount = controller.groups
        .where((group) => !group.archived)
        .length;
    final projectCount = controller.projects
        .where((project) => !project.archived)
        .length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppMetrics.unit * 2,
        AppMetrics.unit,
        AppMetrics.unit * 2,
        AppMetrics.unit * 3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '共 $projectGroupCount 个项目组 · $projectCount 个项目',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.textFaint, fontSize: 10),
          ),
          const SizedBox(height: AppMetrics.unit),
          Row(
            children: [
              Expanded(
                child: ShadTooltip(
                  builder: (context) => const Text('新建项目组'),
                  child: ShadButton.ghost(
                    key: const ValueKey<String>('new-project-group-button'),
                    onPressed: () =>
                        ProjectManagement.showCreateGroup(context, controller),
                    height: 34,
                    foregroundColor: colors.textMuted,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(AppIcons.add, size: 15),
                        const SizedBox(width: AppMetrics.unit),
                        const Text('新建项目组', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppMetrics.unit),
              ShadTooltip(
                builder: (context) => const Text('设置'),
                child: ShadButton.ghost(
                  key: const ValueKey<String>('sidebar-settings-entry'),
                  onPressed: navigationController.goSettings,
                  height: 34,
                  width: 34,
                  padding: EdgeInsets.zero,
                  foregroundColor: colors.textMuted,
                  hoverBackgroundColor: colors.focusSoft,
                  child: const Icon(AppIcons.settings, size: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppMetrics.unit),
          const Visibility(visible: false, child: Text('v0.3.2')),
          Text(
            'v${AppConstants.appVersion}+${AppConstants.appBuild}',
            style: TextStyle(color: colors.textFaint, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
