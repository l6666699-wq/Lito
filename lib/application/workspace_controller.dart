import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/models/app_data.dart';
import '../domain/models/project.dart';
import '../domain/models/todo_item.dart';
import '../domain/models/visible_todo_row.dart';
import '../domain/services/todo_tree_service.dart';
import '../infrastructure/persistence/app_data_repository.dart';

enum TodoDataset {
  fifty(50, '50 条 Todo'),
  thousand(1000, '1000 条 Todo');

  const TodoDataset(this.count, this.label);

  final int count;
  final String label;
}

enum WorkspaceScope { all, inbox }

/// The single source of truth for projects, Todos, and the current persistence
/// snapshot.  The deterministic 50/1000 datasets are an explicitly isolated
/// benchmark mode and are never written over a user's AppData.
class WorkspaceController extends ChangeNotifier {
  WorkspaceController({
    TodoDataset initialDataset = TodoDataset.fifty,
    AppDataRepository? repository,
  }) : _dataset = initialDataset,
       _repository = repository,
       _projects = _buildProjects(),
       _todos = _buildTodos(initialDataset.count) {
    _data = AppData(
      schemaVersion: AppData.currentSchemaVersion,
      revision: 0,
      projects: _projects,
      todos: _todos,
      trash: const <TrashItem>[],
    );
    _benchmarkMode = repository == null;
    _initialized = repository == null;
  }

  TodoDataset _dataset;
  final AppDataRepository? _repository;
  List<Project> _projects;
  List<TodoItem> _todos;
  late AppData _data;
  WorkspaceScope _scope = WorkspaceScope.all;
  String? _projectScopeId;
  bool _benchmarkMode = false;
  bool _initialized = false;
  bool _dirty = false;
  Timer? _saveTimer;
  String? _recoveryWarning;
  Object? _lastPersistenceError;

  TodoDataset get dataset => _dataset;
  int get datasetSize => _dataset.count;
  String get datasetLabel => _dataset.label;
  List<Project> get projects => List.unmodifiable(_projects);
  List<TodoItem> get todos => List.unmodifiable(_todos);
  AppData get appData => _data;
  int get revision => _data.revision;
  bool get isBenchmarkMode => _benchmarkMode;
  bool get isInitialized => _initialized;
  String? get recoveryWarning => _recoveryWarning;
  Object? get lastPersistenceError => _lastPersistenceError;
  bool get hasPersistenceError => _lastPersistenceError != null;
  bool get hasUnsavedChanges => _dirty;
  WorkspaceScope get scope => _scope;
  String? get projectScopeId => _projectScopeId;

  List<VisibleTodoRow> get visibleRows {
    final service = TodoTreeService(_todos);
    return service.buildVisibleRows(
      projectId: _scope == WorkspaceScope.all ? _projectScopeId : null,
      inboxOnly: _scope == WorkspaceScope.inbox,
    );
  }

  void switchDataset(TodoDataset dataset) {
    if (_dataset == dataset) return;
    _dataset = dataset;
    _benchmarkMode = true;
    // Benchmark rows are intentionally detached from [_data].  This keeps a
    // 1000-row rendering run from replacing real persisted user data.
    _todos = _buildTodos(dataset.count);
    _projects = _buildProjects();
    notifyListeners();
  }

  void setDataset(TodoDataset dataset) => switchDataset(dataset);

  void setDatasetSize(int count) {
    switch (count) {
      case 50:
        switchDataset(TodoDataset.fifty);
      case 1000:
        switchDataset(TodoDataset.thousand);
      default:
        throw ArgumentError.value(
          count,
          'count',
          'Only 50 or 1000 are supported',
        );
    }
  }

  void toggleDataset() {
    switchDataset(
      _dataset == TodoDataset.fifty ? TodoDataset.thousand : TodoDataset.fifty,
    );
  }

  void toggleCollapsed(String todoId) {
    final index = _todos.indexWhere((todo) => todo.id == todoId);
    if (index < 0) return;
    final todo = _todos[index];
    final updated = todo.copyWith(collapsed: !todo.collapsed);
    final updatedTodos = <TodoItem>[
      ..._todos.sublist(0, index),
      updated,
      ..._todos.sublist(index + 1),
    ];
    if (_benchmarkMode) {
      _todos = List.unmodifiable(updatedTodos);
    } else {
      _replaceTodos(updatedTodos);
      _markMutation();
    }
    notifyListeners();
  }

  void setCollapsed(String todoId, bool collapsed) {
    final index = _todos.indexWhere((todo) => todo.id == todoId);
    if (index < 0 || _todos[index].collapsed == collapsed) return;
    final updated = _todos[index].copyWith(collapsed: collapsed);
    final updatedTodos = <TodoItem>[
      ..._todos.sublist(0, index),
      updated,
      ..._todos.sublist(index + 1),
    ];
    if (_benchmarkMode) {
      _todos = List.unmodifiable(updatedTodos);
    } else {
      _replaceTodos(updatedTodos);
      _markMutation();
    }
    notifyListeners();
  }

  void selectAll() {
    if (_scope == WorkspaceScope.all && _projectScopeId == null) return;
    _scope = WorkspaceScope.all;
    _projectScopeId = null;
    notifyListeners();
  }

  void selectInbox() {
    if (_scope == WorkspaceScope.inbox) return;
    _scope = WorkspaceScope.inbox;
    _projectScopeId = null;
    notifyListeners();
  }

  void selectProject(String projectId) {
    if (_scope == WorkspaceScope.all && _projectScopeId == projectId) return;
    _scope = WorkspaceScope.all;
    _projectScopeId = projectId;
    notifyListeners();
  }

  /// Loads the persisted snapshot and seeds a first-run file with the Phase 0
  /// 50-row sample.  Bootstrap awaits this method before showing the window.
  Future<void> initialize() async {
    if (_initialized) return;
    final repository = _repository;
    if (repository == null) {
      _initialized = true;
      return;
    }
    final result = await repository.load();
    _recoveryWarning = result.recoveryWarning;
    if (result.isInitial && result.recoveryWarning == null) {
      final seeded = AppData(
        schemaVersion: AppData.currentSchemaVersion,
        revision: 1,
        projects: _buildProjects(),
        todos: _buildTodos(TodoDataset.fifty.count),
        trash: const <TrashItem>[],
      );
      _applyData(seeded);
      await repository.save(seeded);
      _dirty = false;
    } else {
      _applyData(result.data);
      _dirty = false;
    }
    _benchmarkMode = false;
    _initialized = true;
    notifyListeners();
  }

  /// Adds a root Todo to the current project or the Inbox.  The normal path
  /// uses the 250ms debounce; QuickAdd calls [addTodoAndFlush] so a successful
  /// submission can report persistence failures before restoring the window.
  Future<void> addTodo(String title, {String? projectId}) async {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw ArgumentError.value(title, 'title', 'Todo title cannot be empty');
    }
    if (_benchmarkMode && _repository != null) {
      throw StateError('benchmark mode is read-only');
    }
    final targetProjectId = _resolveProjectId(projectId);
    final siblingTodos = _todos.where(
      (todo) => todo.projectId == targetProjectId && todo.parentId == null,
    );
    final maxSortOrder = siblingTodos.fold<int>(
      0,
      (max, todo) => todo.sortOrder > max ? todo.sortOrder : max,
    );
    final now = DateTime.now().toUtc();
    final todo = TodoItem(
      id: _newTodoId(),
      projectId: targetProjectId,
      parentId: null,
      title: normalizedTitle,
      completed: false,
      completedAt: null,
      sortOrder: maxSortOrder + 1000,
      collapsed: false,
      createdAt: now,
      updatedAt: now,
    );
    _replaceTodos(<TodoItem>[..._todos, todo]);
    _markMutation();
    notifyListeners();
  }

  Future<void> addTodoAndFlush(String title, {String? projectId}) async {
    final before = _capturePersistenceSnapshot();
    var mutationApplied = false;
    try {
      await addTodo(title, projectId: projectId);
      mutationApplied = true;
      await flushNow();
    } catch (error) {
      // QuickAdd retains its draft after a failed submit.  Roll back the
      // matching mutation so a retry is a new transaction rather than a
      // second copy of the same draft.  If another mutation advanced the
      // revision while the write was in flight, leave that newer state alone.
      if (mutationApplied && _data.revision == before.data.revision + 1) {
        _restorePersistenceSnapshot(before, error);
      }
      rethrow;
    }
  }

  /// Flushes the latest immutable snapshot.  The repository owns the final
  /// serialized write queue; this method only tracks dirty state and errors.
  Future<void> flushNow() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    final repository = _repository;
    if (repository == null || !_dirty) return;
    final snapshot = _data;
    try {
      await repository.save(snapshot);
      if (_data.revision == snapshot.revision) _dirty = false;
      _lastPersistenceError = null;
      notifyListeners();
    } catch (error) {
      _lastPersistenceError = error;
      notifyListeners();
      rethrow;
    }
  }

  void _replaceTodos(List<TodoItem> todos) {
    _todos = List.unmodifiable(todos);
    _data = _data.copyWith(todos: _todos);
  }

  void _applyData(AppData data) {
    _data = data;
    _projects = data.projects;
    _todos = data.todos;
    _dataset = data.todos.length == TodoDataset.thousand.count
        ? TodoDataset.thousand
        : TodoDataset.fifty;
  }

  void _markMutation() {
    _data = _data.copyWith(revision: _data.revision + 1);
    _dirty = _repository != null;
    _lastPersistenceError = null;
    if (_repository != null) {
      _saveTimer?.cancel();
      _saveTimer = Timer(const Duration(milliseconds: 250), () {
        unawaited(_flushDebounced());
      });
    }
  }

  Future<void> _flushDebounced() async {
    try {
      await flushNow();
    } catch (_) {
      // The error remains queryable through [lastPersistenceError] and is
      // surfaced by QuickAdd when it explicitly flushes its snapshot.
    }
  }

  _WorkspacePersistenceSnapshot _capturePersistenceSnapshot() {
    return _WorkspacePersistenceSnapshot(
      data: _data,
      projects: _projects,
      todos: _todos,
      dataset: _dataset,
      benchmarkMode: _benchmarkMode,
      dirty: _dirty,
    );
  }

  void _restorePersistenceSnapshot(
    _WorkspacePersistenceSnapshot snapshot,
    Object error,
  ) {
    _saveTimer?.cancel();
    _saveTimer = null;
    _data = snapshot.data;
    _projects = snapshot.projects;
    _todos = snapshot.todos;
    _dataset = snapshot.dataset;
    _benchmarkMode = snapshot.benchmarkMode;
    _dirty = snapshot.dirty;
    _lastPersistenceError = error;
    if (_dirty && _repository != null) {
      _saveTimer = Timer(const Duration(milliseconds: 250), () {
        unawaited(_flushDebounced());
      });
    }
    notifyListeners();
  }

  String? _resolveProjectId(String? requested) {
    final candidate = requested ?? _projectScopeId;
    if (_scope == WorkspaceScope.inbox) return null;
    if (candidate == null) return null;
    final project = _projects.cast<Project?>().firstWhere(
      (entry) => entry?.id == candidate,
      orElse: () => null,
    );
    return project == null || project.archived ? null : project.id;
  }

  String _newTodoId() {
    final prefix = 'todo-${DateTime.now().microsecondsSinceEpoch}';
    var id = prefix;
    var suffix = 0;
    while (_todos.any((todo) => todo.id == id)) {
      suffix += 1;
      id = '$prefix-$suffix';
    }
    return id;
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  static List<Project> _buildProjects() {
    final createdAt = DateTime.utc(2026, 1, 1);
    const definitions = <(String, String, String, String)>[
      ('project-focus', 'Focus', 'target', 'blue'),
      ('project-home', 'Home', 'home', 'green'),
      ('project-learning', 'Learning', 'book', 'violet'),
      ('project-ideas', 'Ideas', 'sparkles', 'orange'),
    ];
    return List.unmodifiable(<Project>[
      for (var i = 0; i < definitions.length; i++)
        Project(
          id: definitions[i].$1,
          name: definitions[i].$2,
          iconKey: definitions[i].$3,
          colorKey: definitions[i].$4,
          sortOrder: i * 1000,
          archived: false,
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
    ]);
  }

  static List<TodoItem> _buildTodos(int count) {
    final base = DateTime.utc(2026, 1, 1);
    const projectIds = <String>[
      'project-focus',
      'project-home',
      'project-learning',
      'project-ideas',
    ];
    final result = <TodoItem>[];
    for (var i = 0; i < count; i++) {
      final group = i ~/ 10;
      final offset = i % 10;
      final id = 'todo-$i';
      final rootId = 'todo-${group * 10}';
      final projectId = group % 5 == 0
          ? null
          : projectIds[group % projectIds.length];
      result.add(
        TodoItem(
          id: id,
          projectId: projectId,
          parentId: offset == 0 ? null : rootId,
          title: offset == 0 ? '阶段 ${group + 1}：整理下一步' : '任务 ${i + 1}：完成一个小步骤',
          completed: i % 17 == 0,
          completedAt: i % 17 == 0 ? base.add(Duration(days: i)) : null,
          sortOrder: group * 1000 + offset * 10,
          collapsed: count == TodoDataset.thousand.count && offset == 0,
          createdAt: base.add(Duration(minutes: i)),
          updatedAt: base.add(Duration(minutes: i)),
        ),
      );
    }
    return List.unmodifiable(result);
  }
}

class _WorkspacePersistenceSnapshot {
  const _WorkspacePersistenceSnapshot({
    required this.data,
    required this.projects,
    required this.todos,
    required this.dataset,
    required this.benchmarkMode,
    required this.dirty,
  });

  final AppData data;
  final List<Project> projects;
  final List<TodoItem> todos;
  final TodoDataset dataset;
  final bool benchmarkMode;
  final bool dirty;
}
