import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../domain/models/app_data.dart';
import '../domain/models/app_settings.dart';
import '../domain/models/visible_todo_row.dart';
import '../infrastructure/platform/sticky_notes_window_service.dart';
import 'workspace_controller.dart';

/// Runtime identity for one sticky-note window.
///
/// `inbox` is intentionally not an empty project ID: the key is persisted in
/// native window maps and must never collide with a generated project ID.
class StickyNoteWindowInstance {
  const StickyNoteWindowInstance({
    required this.key,
    required this.projectId,
    required this.groupId,
    required this.openedAt,
  });

  final String key;
  final String? projectId;
  final String? groupId;
  final DateTime openedAt;
}

/// Coordinates sticky-note window identity, native lifecycle and workspace
/// snapshot fan-out.
///
/// The primary engine remains the business authority. Secondary engines are
/// read-only projections fed by [WorkspaceController.appData] snapshots, so
/// they cannot race the JSON repository or create an independent data source.
class StickyNotesController extends ChangeNotifier {
  StickyNotesController({
    required this.workspace,
    required this.windowService,
    this.settingsProvider,
  }) {
    workspace.addListener(_onWorkspaceChanged);
    unawaited(_syncOpenWindows());
  }

  final WorkspaceController workspace;
  final StickyNotesWindowService windowService;
  final AppSettings Function()? settingsProvider;
  final Map<String, StickyNoteWindowInstance> _instances =
      <String, StickyNoteWindowInstance>{};
  String? _activeKey;
  String? _capabilityWarning;
  bool _disposed = false;

  static const String inboxKey = 'inbox';

  List<StickyNoteWindowInstance> get instances =>
      List<StickyNoteWindowInstance>.unmodifiable(_instances.values);

  Set<String> get openKeys => Set<String>.unmodifiable(_instances.keys.toSet());

  String? get activeKey => _activeKey;

  String? get activeProjectId =>
      _activeKey == null ? null : _instances[_activeKey]?.projectId;
  String? get activeGroupId =>
      _activeKey == null ? null : _instances[_activeKey]?.groupId;

  bool get hasActiveWindow => _activeKey != null;

  String? get capabilityWarning => _capabilityWarning;

  bool contains(String? projectId) => _instances.containsKey(keyFor(projectId));

  bool containsGroup(String groupId) =>
      _instances.containsKey(groupKeyFor(groupId));

  StickyNoteWindowInstance? instanceFor(String? projectId) =>
      _instances[keyFor(projectId)];

  StickyNoteWindowInstance? instanceForGroup(String groupId) =>
      _instances[groupKeyFor(groupId)];

  static String keyFor(String? projectId) =>
      projectId == null ? inboxKey : 'project:$projectId';

  static String groupKeyFor(String groupId) => 'group:$groupId';

  /// Opens or focuses the stable inbox instance.
  Future<void> openInbox() => open(projectId: null);

  /// Opens or focuses one stable project instance. Archived/unknown projects
  /// are rejected so a stale sidebar action cannot create an orphan window.
  Future<void> openProject(String projectId) => open(projectId: projectId);

  Future<void> openGroup(String groupId) => open(groupId: groupId);

  Future<void> open({String? projectId, String? groupId}) async {
    if (_disposed) return;
    if (projectId != null && !_isOpenableProject(projectId)) return;
    if (groupId != null && !_isOpenableGroup(groupId)) return;
    if (projectId != null && groupId != null) return;
    final key = groupId == null ? keyFor(projectId) : groupKeyFor(groupId);
    final existing = _instances[key];
    _activeKey = key;
    if (existing == null) {
      _instances[key] = StickyNoteWindowInstance(
        key: key,
        projectId: projectId,
        groupId: groupId,
        openedAt: DateTime.now().toUtc(),
      );
    }
    notifyListeners();
    try {
      await windowService.open(
        key: key,
        projectId: projectId,
        groupId: groupId,
      );
      await _syncSnapshot(key);
    } catch (error) {
      _capabilityWarning = error.toString();
      notifyListeners();
    }
  }

  /// Activates an already-open key without creating another instance.
  Future<void> activate(String key) async {
    final instance = _instances[key];
    if (instance == null || _disposed) return;
    _activeKey = key;
    notifyListeners();
    try {
      await windowService.open(
        key: key,
        projectId: instance.projectId,
        groupId: instance.groupId,
      );
    } catch (error) {
      _capabilityWarning = error.toString();
      notifyListeners();
    }
  }

  Future<void> closeActive() async {
    final key = _activeKey;
    if (key == null) return;
    await close(key);
  }

  Future<void> close(String key) async {
    if (_disposed) return;
    final removed = _instances.remove(key);
    if (removed == null) return;
    if (_activeKey == key) {
      _activeKey = _instances.isEmpty ? null : _instances.keys.last;
    }
    notifyListeners();
    try {
      await windowService.close(key);
      final active = _activeKey;
      if (active != null) await activate(active);
    } catch (error) {
      _capabilityWarning = error.toString();
      notifyListeners();
    }
  }

  Future<void> setAlwaysOnTop(bool value) async {
    final key = _activeKey;
    if (key == null) return;
    try {
      await windowService.setAlwaysOnTop(key, value);
    } catch (error) {
      _capabilityWarning = error.toString();
      notifyListeners();
    }
  }

  Future<void> startDragging() async {
    final key = _activeKey;
    if (key == null) return;
    try {
      await windowService.startDragging(key);
    } catch (error) {
      _capabilityWarning = error.toString();
      notifyListeners();
    }
  }

  List<VisibleTodoRow> rowsFor(String? projectId) =>
      workspace.visibleRowsForProject(projectId);

  List<VisibleTodoRow> rowsForGroup(String groupId) =>
      workspace.visibleRowsForGroup(groupId);

  String? titleFor(String? projectId) {
    if (projectId == null) return null;
    for (final project in workspace.projects) {
      if (project.id == projectId) return project.name;
    }
    return null;
  }

  String? groupTitleFor(String groupId) {
    for (final group in workspace.groups) {
      if (group.id == groupId) return group.name;
    }
    return null;
  }

  Future<void> syncOpenWindows() => _syncOpenWindows();

  Future<void> _syncOpenWindows() async {
    for (final key in _instances.keys) {
      await _syncSnapshot(key);
    }
  }

  Future<void> _syncSnapshot(String key) async {
    if (_disposed || !_instances.containsKey(key)) return;
    final currentSettingsProvider = settingsProvider;
    try {
      await windowService.syncSnapshot(
        key: key,
        snapshot: jsonEncode(<String, Object?>{
          'appData': workspace.appData.toJson(),
          if (currentSettingsProvider != null)
            'settings': currentSettingsProvider().toJson(),
        }),
      );
      _capabilityWarning = null;
    } catch (error) {
      _capabilityWarning = error.toString();
    }
    if (!_disposed) notifyListeners();
  }

  void _onWorkspaceChanged() {
    if (_disposed) return;
    for (final key in _instances.keys) {
      unawaited(_syncSnapshot(key));
    }
    notifyListeners();
  }

  bool _isOpenableProject(String id) {
    for (final project in workspace.projects) {
      if (project.id != id || project.archived) continue;
      final groupId = project.groupId;
      if (groupId != null) {
        for (final group in workspace.groups) {
          if (group.id == groupId && group.archived) return false;
        }
      }
      return true;
    }
    return false;
  }

  bool _isOpenableGroup(String id) {
    for (final group in workspace.groups) {
      if (group.id == id) return !group.archived;
    }
    return false;
  }

  @override
  void dispose() {
    _disposed = true;
    workspace.removeListener(_onWorkspaceChanged);
    _instances.clear();
    _activeKey = null;
    super.dispose();
  }
}

/// Applies a JSON snapshot received by a secondary engine without enabling
/// persistence or mutation. Kept here so the bootstrap and UI share one
/// validation path.
void applyStickySnapshot(WorkspaceController workspace, String snapshot) {
  final decoded = jsonDecode(snapshot);
  if (decoded is! Map) return;
  final appData = decoded['appData'];
  final data = AppData.fromJson(
    Map<String, dynamic>.from(appData is Map ? appData : decoded),
  );
  workspace.applyExternalSnapshot(data);
}

AppSettings? readStickySnapshotSettings(String snapshot) {
  final decoded = jsonDecode(snapshot);
  if (decoded is! Map) return null;
  final settings = decoded['settings'];
  if (settings is! Map) return null;
  return AppSettings.fromJson(Map<String, dynamic>.from(settings));
}
