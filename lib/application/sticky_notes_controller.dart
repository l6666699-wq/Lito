import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../domain/models/app_data.dart';
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
    required this.openedAt,
  });

  final String key;
  final String? projectId;
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
  }) {
    workspace.addListener(_onWorkspaceChanged);
    unawaited(_syncOpenWindows());
  }

  final WorkspaceController workspace;
  final StickyNotesWindowService windowService;
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

  bool get hasActiveWindow => _activeKey != null;

  String? get capabilityWarning => _capabilityWarning;

  bool contains(String? projectId) => _instances.containsKey(keyFor(projectId));

  StickyNoteWindowInstance? instanceFor(String? projectId) =>
      _instances[keyFor(projectId)];

  static String keyFor(String? projectId) =>
      projectId == null ? inboxKey : 'project:$projectId';

  /// Opens or focuses the stable inbox instance.
  Future<void> openInbox() => open(projectId: null);

  /// Opens or focuses one stable project instance. Archived/unknown projects
  /// are rejected so a stale sidebar action cannot create an orphan window.
  Future<void> openProject(String projectId) => open(projectId: projectId);

  Future<void> open({required String? projectId}) async {
    if (_disposed) return;
    if (projectId != null && !_isOpenableProject(projectId)) return;
    final key = keyFor(projectId);
    final existing = _instances[key];
    _activeKey = key;
    if (existing == null) {
      _instances[key] = StickyNoteWindowInstance(
        key: key,
        projectId: projectId,
        openedAt: DateTime.now().toUtc(),
      );
    }
    notifyListeners();
    try {
      await windowService.open(key: key, projectId: projectId);
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
      await windowService.open(key: key, projectId: instance.projectId);
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

  String? titleFor(String? projectId) {
    if (projectId == null) return null;
    for (final project in workspace.projects) {
      if (project.id == projectId) return project.name;
    }
    return null;
  }

  Future<void> _syncOpenWindows() async {
    for (final key in _instances.keys) {
      await _syncSnapshot(key);
    }
  }

  Future<void> _syncSnapshot(String key) async {
    if (_disposed || !_instances.containsKey(key)) return;
    try {
      await windowService.syncSnapshot(
        key: key,
        snapshot: jsonEncode(workspace.appData.toJson()),
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
  final data = AppData.fromJson(Map<String, dynamic>.from(decoded));
  workspace.applyExternalSnapshot(data);
}
