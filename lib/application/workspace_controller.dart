import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/models/app_data.dart';
import '../domain/models/project.dart';
import '../domain/models/project_group.dart';
import '../domain/models/todo_item.dart';
import '../domain/models/visible_todo_row.dart';
import '../domain/services/todo_move_service.dart';
import '../domain/services/todo_tree_service.dart';
import '../infrastructure/persistence/app_data_repository.dart';
import 'workspace_history.dart';

enum TodoDataset {
  fifty(50, '50 条 Todo'),
  thousand(1000, '1000 条 Todo');

  const TodoDataset(this.count, this.label);

  final int count;
  final String label;
}

enum WorkspaceScope {
  all,
  inbox,
  today,
  recent,
  completed,
  archived,
  project,
  search,
}

/// The single source of truth for projects, groups, Todos and persistence.
///
/// Benchmark datasets are intentionally detached from [_data], so rendering a
/// 1000-row fixture can never overwrite a user's real local JSON snapshot.
class WorkspaceController extends ChangeNotifier {
  WorkspaceController({
    TodoDataset initialDataset = TodoDataset.fifty,
    AppDataRepository? repository,
    DateTime Function()? nowProvider,
    DateTime Function()? clock,
  }) : _dataset = initialDataset,
       _repository = repository,
       _nowProvider = nowProvider ?? clock ?? DateTime.now,
       _groups = _buildGroups(),
       _projects = _buildProjects(),
       _todos = _buildTodos(initialDataset.count) {
    _data = AppData(
      schemaVersion: AppData.currentSchemaVersion,
      revision: 0,
      groups: _groups,
      projects: _projects,
      todos: _todos,
      trash: const <TrashItem>[],
    );
    _benchmarkMode = repository == null;
    _initialized = repository == null;
  }

  TodoDataset _dataset;
  final AppDataRepository? _repository;
  final DateTime Function() _nowProvider;
  List<ProjectGroup> _groups;
  List<Project> _projects;
  List<TodoItem> _todos;
  List<TrashItem> _trash = const <TrashItem>[];
  late AppData _data;
  WorkspaceScope _scope = WorkspaceScope.all;
  String? _projectScopeId;
  String _searchQuery = '';
  bool _benchmarkMode = false;
  bool _initialized = false;
  bool _disposed = false;
  bool _dirty = false;
  final WorkspaceHistory _history = WorkspaceHistory();
  AppData? _pendingHistoryBefore;
  bool _applyingHistory = false;
  Timer? _saveTimer;
  String? _recoveryWarning;
  Object? _lastPersistenceError;
  Future<void>? _flushInFlight;
  bool _flushAgain = false;

  TodoDataset get dataset => _dataset;
  int get datasetSize => _dataset.count;
  String get datasetLabel => _dataset.label;
  List<ProjectGroup> get groups => List.unmodifiable(_groups);
  List<Project> get projects => List.unmodifiable(_projects);
  List<TodoItem> get todos => List.unmodifiable(_todos);
  List<TrashItem> get trash => List.unmodifiable(_trash);
  List<TrashItem> get trashItems => trash;
  AppData get appData => _data;
  int get revision => _data.revision;
  bool get isBenchmarkMode => _benchmarkMode;
  bool get isInitialized => _initialized;
  String? get recoveryWarning => _recoveryWarning;
  Object? get lastPersistenceError => _lastPersistenceError;
  bool get hasPersistenceError => _lastPersistenceError != null;
  bool get hasUnsavedChanges => _dirty;
  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;
  int get undoCount => _history.undoCount;
  int get redoCount => _history.redoCount;
  WorkspaceScope get scope => _scope;
  String? get projectScopeId => _projectScopeId;
  String get searchQuery => _searchQuery;

  List<VisibleTodoRow> get visibleRows {
    final filtered = _todos
        .where((todo) => _matchesScope(todo))
        .toList(growable: false);
    return TodoTreeService(filtered).buildVisibleRows();
  }

  Map<WorkspaceScope, int> get scopeCounts => <WorkspaceScope, int>{
    for (final value in WorkspaceScope.values)
      value: _todos.where((todo) => _matchesScope(todo, value)).length,
  };

  int countForScope(WorkspaceScope value) =>
      _todos.where((todo) => _matchesScope(todo, value)).length;

  int get unfinishedCount => _todos.where(_isUnfinishedVisible).length;

  int unfinishedCountForProject(String projectId) {
    return _todos
        .where(
          (todo) => todo.projectId == projectId && _isUnfinishedVisible(todo),
        )
        .length;
  }

  int unfinishedCountForGroup(String groupId) {
    return _todos
        .where(
          (todo) =>
              _isUnfinishedVisible(todo) &&
              _projectFor(todo.projectId)?.groupId == groupId,
        )
        .length;
  }

  int unfinishedProjectCount(String projectId) =>
      unfinishedCountForProject(projectId);
  int unfinishedGroupCount(String groupId) => unfinishedCountForGroup(groupId);

  Map<String, int> get projectCounts => <String, int>{
    for (final project in _projects)
      project.id: unfinishedCountForProject(project.id),
  };

  Map<String, int> get groupCounts => <String, int>{
    for (final group in _groups) group.id: unfinishedCountForGroup(group.id),
  };

  void switchDataset(TodoDataset dataset) {
    if (_dataset == dataset && _benchmarkMode) return;
    _dataset = dataset;
    _benchmarkMode = true;
    _history.clear();
    _pendingHistoryBefore = null;
    _todos = _buildTodos(dataset.count);
    _projects = _buildProjects();
    _groups = _buildGroups();
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

  /// Restores the previous business snapshot without adding a second history
  /// entry. The restored state receives a fresh revision and follows the same
  /// debounced persistence path as a normal mutation.
  void undo() {
    final entry = _history.takeUndo();
    if (entry == null) return;
    _applyHistorySnapshot(entry.before);
  }

  /// Reapplies the next snapshot after an undo.
  void redo() {
    final entry = _history.takeRedo();
    if (entry == null) return;
    _applyHistorySnapshot(entry.after);
  }

  void toggleCollapsed(String todoId) {
    final todo = _todoById(todoId);
    if (todo == null) return;
    setCollapsed(todoId, !todo.collapsed);
  }

  void setCollapsed(String todoId, bool collapsed) {
    final index = _todos.indexWhere((todo) => todo.id == todoId);
    if (index < 0 || _todos[index].collapsed == collapsed) return;
    final updated = _todos[index].copyWith(collapsed: collapsed);
    final next = <TodoItem>[..._todos]..[index] = updated;
    if (_benchmarkMode) {
      _todos = List.unmodifiable(next);
      notifyListeners();
      return;
    }
    _setTodos(next);
    _commitMutation(recordHistory: false);
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

  void selectToday() => selectScope(WorkspaceScope.today);
  void selectRecent() => selectScope(WorkspaceScope.recent);
  void selectCompleted() => selectScope(WorkspaceScope.completed);
  void selectArchived() => selectScope(WorkspaceScope.archived);

  void selectSearch([String query = '']) {
    _searchQuery = query;
    _scope = WorkspaceScope.search;
    _projectScopeId = null;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    if (_searchQuery == query && _scope == WorkspaceScope.search) return;
    _searchQuery = query;
    _scope = WorkspaceScope.search;
    _projectScopeId = null;
    notifyListeners();
  }

  void selectScope(WorkspaceScope scope, {String? projectId}) {
    _scope = scope;
    _projectScopeId = scope == WorkspaceScope.project ? projectId : null;
    notifyListeners();
  }

  void selectProject(String projectId) {
    if (_scope == WorkspaceScope.project && _projectScopeId == projectId) {
      return;
    }
    _scope = WorkspaceScope.project;
    _projectScopeId = projectId;
    notifyListeners();
  }

  /// Loads the persisted snapshot without creating synthetic first-run data.
  /// A v1 snapshot is decoded as v2 in memory and is written back only after
  /// the next business mutation (or an explicit flush).
  Future<void> initialize() async {
    if (_disposed) return;
    if (_initialized) return;
    final repository = _repository;
    if (repository == null) {
      _initialized = true;
      return;
    }
    late AppDataLoadResult result;
    try {
      result = await repository.load();
    } catch (error) {
      // A broken local file or an unavailable data directory must not prevent
      // the shell from starting. Keep the in-memory workspace empty and make
      // the failure observable through the existing settings data surface.
      _applyData(AppData.empty());
      _recoveryWarning =
          'LiteTodo data could not be loaded; the workspace started empty.';
      _lastPersistenceError = error;
      _dirty = false;
      _history.clear();
      _pendingHistoryBefore = null;
      _benchmarkMode = false;
      _initialized = true;
      notifyListeners();
      return;
    }
    _recoveryWarning = result.recoveryWarning;
    final initialEmpty = result.isInitial && result.recoveryWarning == null;
    _applyData(initialEmpty ? AppData.empty() : result.data);
    if (initialEmpty) {
      // Materialize the real empty snapshot so first-run backup/import flows
      // have a concrete data.json, while keeping the revision at zero.
      try {
        await repository.save(_data);
      } catch (error) {
        // The first-run write is best effort. The workspace remains usable and
        // the next successful mutation can retry persistence.
        _lastPersistenceError = error;
      }
    }
    _dirty = false;
    _history.clear();
    _pendingHistoryBefore = null;
    _benchmarkMode = false;
    _initialized = true;
    notifyListeners();
  }

  Future<void> addTodo(
    String title, {
    String? projectId,
    DateTime? dueAt,
  }) async {
    createRootTodo(title, projectId: projectId, dueAt: dueAt);
  }

  Future<void> addTodoAndFlush(
    String title, {
    String? projectId,
    DateTime? dueAt,
  }) async {
    final before = _capturePersistenceSnapshot();
    int? mutationRevision;
    var mutationApplied = false;
    try {
      await addTodo(title, projectId: projectId, dueAt: dueAt);
      mutationApplied = true;
      mutationRevision = _data.revision;
      await flushNow();
    } catch (error) {
      if (mutationApplied &&
          mutationRevision != null &&
          _data.revision == mutationRevision) {
        _history.discardLatestAfterRevision(_data.revision);
        _restorePersistenceSnapshot(before, error);
      }
      rethrow;
    }
  }

  /// Creates a child Todo and persists the same transaction boundary used by
  /// Quick Add/root composer submissions. A failed write restores the exact
  /// pre-submit snapshot so retrying cannot duplicate the child.
  Future<TodoItem> createChildTodoAndFlush(
    String title, {
    required String parentId,
    DateTime? dueAt,
  }) async {
    final before = _capturePersistenceSnapshot();
    TodoItem? created;
    try {
      final createdTodo = createChildTodo(
        title,
        parentId: parentId,
        dueAt: dueAt,
      );
      created = createdTodo;
      final mutationRevision = _data.revision;
      await flushNow();
      if (_data.revision != mutationRevision) {
        // A concurrent mutation superseded this snapshot; leave the newer
        // state authoritative rather than rolling it back.
        return createdTodo;
      }
      return createdTodo;
    } catch (error) {
      if (created != null && _data.revision == before.data.revision + 1) {
        _history.discardLatestAfterRevision(_data.revision);
        _restorePersistenceSnapshot(before, error);
      }
      rethrow;
    }
  }

  TodoItem createRootTodo(String title, {String? projectId, DateTime? dueAt}) {
    return _createTodo(title, projectId: projectId, dueAt: dueAt);
  }

  TodoItem createChildTodo(
    String title, {
    required String parentId,
    DateTime? dueAt,
  }) {
    final parent = _todoById(parentId);
    if (parent == null) {
      throw StateError('Parent Todo does not exist: $parentId');
    }
    return _createTodo(
      title,
      projectId: parent.projectId,
      parentId: parent.id,
      dueAt: dueAt,
    );
  }

  TodoItem addRootTodo(String title, {String? projectId, DateTime? dueAt}) =>
      createRootTodo(title, projectId: projectId, dueAt: dueAt);

  TodoItem addChildTodo(
    String title, {
    required String parentId,
    DateTime? dueAt,
  }) => createChildTodo(title, parentId: parentId, dueAt: dueAt);

  TodoItem createTodo(
    String title, {
    String? projectId,
    String? parentId,
    DateTime? dueAt,
  }) {
    return _createTodo(
      title,
      projectId: projectId,
      parentId: parentId,
      dueAt: dueAt,
    );
  }

  TodoItem _createTodo(
    String title, {
    String? projectId,
    String? parentId,
    DateTime? dueAt,
  }) {
    _ensureWritable();
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw ArgumentError.value(title, 'title', 'Todo title cannot be empty');
    }
    final targetProjectId = _resolveProjectId(projectId);
    final parent = parentId == null ? null : _todoById(parentId);
    if (parentId != null && parent == null) {
      throw StateError('Parent Todo does not exist: $parentId');
    }
    if (parent != null && parent.projectId != targetProjectId) {
      throw StateError('A child Todo must stay in its parent project');
    }
    if (parent != null &&
        _depthOf(parent.id) + 1 >= TodoTreeService.maxTreeDepth) {
      throw StateError(
        'Todo tree depth cannot exceed ${TodoTreeService.maxTreeDepth}',
      );
    }
    final siblings = _todos.where(
      (todo) => todo.projectId == targetProjectId && todo.parentId == parentId,
    );
    final maxSortOrder = siblings.fold<int>(
      0,
      (max, todo) => todo.sortOrder > max ? todo.sortOrder : max,
    );
    final now = _nowProvider().toUtc();
    final todo = TodoItem(
      id: _newTodoId(),
      projectId: targetProjectId,
      parentId: parentId,
      title: normalizedTitle,
      completed: false,
      completedAt: null,
      dueAt: dueAt?.toUtc(),
      archivedAt: null,
      sortOrder: maxSortOrder + TodoMoveService.sortGap,
      collapsed: false,
      createdAt: now,
      updatedAt: now,
    );
    _setTodos(<TodoItem>[..._todos, todo]);
    _commitMutation();
    return todo;
  }

  TodoItem? editTodoTitle(String todoId, String title) {
    _ensureWritable();
    final todo = _todoById(todoId);
    if (todo == null) return null;
    final normalized = title.trim();
    if (normalized.isEmpty) throw ArgumentError.value(title, 'title');
    if (todo.title == normalized) return todo;
    final updated = todo.copyWith(
      title: normalized,
      updatedAt: _nowProvider().toUtc(),
    );
    _setTodos(_replaceTodo(todoId, updated));
    _commitMutation();
    return updated;
  }

  TodoItem? updateTodoTitle(String todoId, String title) =>
      editTodoTitle(todoId, title);

  TodoItem? editTodo(String todoId, String title) =>
      editTodoTitle(todoId, title);

  void toggleTodoCompleted(String todoId) {
    final todo = _todoById(todoId);
    if (todo == null) return;
    setTodoCompleted(todoId, !todo.completed);
  }

  void toggleCompletion(String todoId) => toggleTodoCompleted(todoId);

  void setTodoCompleted(String todoId, bool completed) {
    _ensureWritable();
    final todo = _todoById(todoId);
    if (todo == null) return;
    final index = TodoTreeService(_todos).index;
    final ids = <String>{todoId};
    void collect(String id) {
      for (final child in index.childrenOf(id)) {
        if (ids.add(child)) collect(child);
      }
    }

    collect(todoId);
    final now = _nowProvider().toUtc();
    final nextById = <String, TodoItem>{
      for (final item in _todos) item.id: item,
    };
    for (final id in ids) {
      final current = nextById[id]!;
      nextById[id] = current.copyWith(
        completed: completed,
        completedAt: completed ? now : null,
        updatedAt: now,
      );
    }
    var parentId = todo.parentId;
    while (parentId != null) {
      final parent = nextById[parentId];
      if (parent == null) break;
      final children = _todos
          .where((item) => item.parentId == parentId)
          .map((item) => nextById[item.id] ?? item)
          .toList(growable: false);
      if (children.isNotEmpty) {
        final allComplete = children.every((item) => item.completed);
        nextById[parentId] = parent.copyWith(
          completed: allComplete,
          completedAt: allComplete ? now : null,
          updatedAt: now,
        );
      }
      parentId = parent.parentId;
    }
    _setTodos(<TodoItem>[for (final item in _todos) nextById[item.id] ?? item]);
    _commitMutation();
  }

  void archiveTodo(String todoId) => _setTodoArchived(todoId, true);
  void unarchiveTodo(String todoId) => _setTodoArchived(todoId, false);
  void archive(String todoId) => archiveTodo(todoId);
  void unarchive(String todoId) => unarchiveTodo(todoId);

  void _setTodoArchived(String todoId, bool archived) {
    _ensureWritable();
    final root = _todoById(todoId);
    if (root == null) return;
    final index = TodoTreeService(_todos).index;
    final ids = <String>{todoId};
    void collect(String id) {
      for (final child in index.childrenOf(id)) {
        if (ids.add(child)) collect(child);
      }
    }

    collect(todoId);
    final stamp = archived ? _nowProvider().toUtc() : null;
    final updated = <TodoItem>[
      for (final todo in _todos)
        ids.contains(todo.id)
            ? todo.copyWith(
                archivedAt: stamp,
                updatedAt: _nowProvider().toUtc(),
              )
            : todo,
    ];
    _setTodos(updated);
    _commitMutation();
  }

  TrashItem? deleteTodo(String todoId) {
    _ensureWritable();
    final root = _todoById(todoId);
    if (root == null) return null;
    final index = TodoTreeService(_todos).index;
    final ids = <String>{todoId};
    void collect(String id) {
      for (final child in index.childrenOf(id)) {
        if (ids.add(child)) collect(child);
      }
    }

    collect(todoId);
    final deleted = _todos
        .where((todo) => ids.contains(todo.id))
        .toList(growable: false);
    final trash = TrashItem(
      id: _newTrashId(),
      kind: 'todo_subtree',
      payload: <String, dynamic>{
        'rootId': todoId,
        'deletedAt': _nowProvider().toUtc().toIso8601String(),
        'todos': <dynamic>[for (final todo in deleted) todo.toJson()],
      },
    );
    _setTodos(
      _todos.where((todo) => !ids.contains(todo.id)).toList(growable: false),
    );
    _setTrash(<TrashItem>[..._trash, trash]);
    _commitMutation();
    return trash;
  }

  TrashItem? moveTodoToTrash(String todoId) => deleteTodo(todoId);

  bool restoreTrash(String trashId) {
    _ensureWritable();
    final itemIndex = _trash.indexWhere((item) => item.id == trashId);
    if (itemIndex < 0) return false;
    final item = _trash[itemIndex];
    if (item.kind == 'project_subtree') {
      return _restoreProjectTrash(item, itemIndex);
    }
    return _restoreTodoTrash(item, itemIndex);
  }

  bool _restoreTodoTrash(TrashItem item, int itemIndex) {
    final rawTodos = item.payload['todos'];
    if (rawTodos is! List) return false;
    final decoded = <TodoItem>[];
    for (final entry in rawTodos) {
      if (entry is Map) {
        decoded.add(TodoItem.fromJson(Map<String, dynamic>.from(entry)));
      }
    }
    if (decoded.isEmpty) return false;
    final existingIds = _todos.map((todo) => todo.id).toSet();
    final idMap = <String, String>{};
    for (final original in decoded) {
      idMap[original.id] = existingIds.contains(original.id)
          ? _newUniqueId('todo', existingIds)
          : original.id;
      existingIds.add(idMap[original.id]!);
    }
    final now = _nowProvider().toUtc();
    final restored = <TodoItem>[];
    for (final original in decoded) {
      final projectValid =
          original.projectId != null && _projectFor(original.projectId) != null;
      final projectId = projectValid ? original.projectId : null;
      String? parentId;
      if (original.parentId != null) {
        parentId = idMap[original.parentId!];
        if (parentId == null) {
          final existingParent = _todoById(original.parentId!);
          if (existingParent != null && existingParent.projectId == projectId) {
            parentId = existingParent.id;
          }
        }
      }
      restored.add(
        original.copyWith(
          id: idMap[original.id],
          projectId: projectId,
          parentId: parentId,
          archivedAt: null,
          updatedAt: now,
        ),
      );
    }
    _setTodos(<TodoItem>[..._todos, ...restored]);
    _setTrash(<TrashItem>[..._trash]..removeAt(itemIndex));
    _commitMutation();
    return true;
  }

  bool _restoreProjectTrash(TrashItem item, int itemIndex) {
    final rawProject = item.payload['project'];
    final rawTodos = item.payload['todos'];
    if (rawProject is! Map || rawTodos is! List) return false;
    final originalProject = Project.fromJson(
      Map<String, dynamic>.from(rawProject),
    );
    final existingProjectIds = _projects.map((project) => project.id).toSet();
    final projectId = existingProjectIds.contains(originalProject.id)
        ? _newUniqueId('project', existingProjectIds)
        : originalProject.id;
    final groupId =
        originalProject.groupId != null &&
            _groupFor(originalProject.groupId) != null
        ? originalProject.groupId
        : null;
    final restoredProject = originalProject.copyWith(
      id: projectId,
      groupId: groupId,
      updatedAt: _nowProvider().toUtc(),
    );
    final decoded = <TodoItem>[];
    for (final entry in rawTodos) {
      if (entry is Map) {
        decoded.add(TodoItem.fromJson(Map<String, dynamic>.from(entry)));
      }
    }
    final existingTodoIds = _todos.map((todo) => todo.id).toSet();
    final idMap = <String, String>{};
    for (final original in decoded) {
      idMap[original.id] = existingTodoIds.contains(original.id)
          ? _newUniqueId('todo', existingTodoIds)
          : original.id;
      existingTodoIds.add(idMap[original.id]!);
    }
    final now = _nowProvider().toUtc();
    final restoredTodos = <TodoItem>[];
    for (final original in decoded) {
      String? parentId = idMap[original.parentId];
      if (parentId == null && original.parentId != null) {
        final existingParent = _todoById(original.parentId!);
        if (existingParent != null && existingParent.projectId == projectId) {
          parentId = existingParent.id;
        }
      }
      restoredTodos.add(
        original.copyWith(
          id: idMap[original.id],
          projectId: projectId,
          parentId: parentId,
          archivedAt: null,
          updatedAt: now,
        ),
      );
    }
    _setProjects(<Project>[..._projects, restoredProject]);
    _setTodos(<TodoItem>[..._todos, ...restoredTodos]);
    _setTrash(<TrashItem>[..._trash]..removeAt(itemIndex));
    _commitMutation();
    return true;
  }

  bool restoreTodo(String trashId) => restoreTrash(trashId);

  /// Permanently removes every item currently in the recycle bin.
  ///
  /// Clearing is one user-visible workspace mutation, so the whole previous
  /// trash snapshot is captured as a single Undo entry.  An empty recycle bin
  /// is deliberately a no-op and does not advance the revision or history.
  bool clearTrash() {
    _ensureWritable();
    if (_trash.isEmpty) return false;
    _setTrash(const <TrashItem>[]);
    _commitMutation();
    return true;
  }

  List<TodoItem> moveTodo(
    String movingId,
    String targetId,
    TodoMovePosition position, {
    String? destinationProjectId,
  }) {
    _ensureWritable();
    final moved = TodoMoveService.moveTodos(
      todos: _todos,
      movingId: movingId,
      targetId: targetId,
      position: position,
      destinationProjectId: destinationProjectId,
      now: _nowProvider(),
    );
    _setTodos(moved);
    _commitMutation();
    return moved;
  }

  List<TodoItem> move(
    String movingId,
    String targetId,
    TodoMovePosition position, {
    String? destinationProjectId,
  }) => moveTodo(
    movingId,
    targetId,
    position,
    destinationProjectId: destinationProjectId,
  );

  ProjectGroup createGroup({
    required String name,
    String iconKey = 'folder',
    String colorKey = 'blue',
  }) {
    _ensureWritable();
    final normalized = name.trim();
    if (normalized.isEmpty) throw ArgumentError.value(name, 'name');
    final now = _nowProvider().toUtc();
    final sort = _groups.fold<int>(
      0,
      (max, group) => group.sortOrder > max ? group.sortOrder : max,
    );
    final group = ProjectGroup(
      id: _newGroupId(),
      name: normalized,
      iconKey: iconKey,
      colorKey: colorKey,
      sortOrder: sort + TodoMoveService.sortGap,
      archived: false,
      createdAt: now,
      updatedAt: now,
    );
    _setGroups(<ProjectGroup>[..._groups, group]);
    _commitMutation();
    return group;
  }

  ProjectGroup createProjectGroup({
    required String name,
    String iconKey = 'folder',
    String colorKey = 'blue',
  }) {
    return createGroup(name: name, iconKey: iconKey, colorKey: colorKey);
  }

  ProjectGroup? getGroup(String groupId) => _groupFor(groupId);

  ProjectGroup? updateGroup(ProjectGroup group) {
    _ensureWritable();
    final index = _groups.indexWhere((entry) => entry.id == group.id);
    if (index < 0) return null;
    final updated = group.copyWith(updatedAt: _nowProvider().toUtc());
    final next = <ProjectGroup>[..._groups]..[index] = updated;
    _setGroups(next);
    _commitMutation();
    return updated;
  }

  ProjectGroup? editGroup(ProjectGroup group) => updateGroup(group);

  bool deleteGroup(String groupId) {
    _ensureWritable();
    if (_groupFor(groupId) == null) return false;
    final now = _nowProvider().toUtc();
    _setProjects(<Project>[
      for (final project in _projects)
        project.groupId == groupId
            ? project.copyWith(groupId: null, updatedAt: now)
            : project,
    ]);
    _setGroups(
      _groups.where((group) => group.id != groupId).toList(growable: false),
    );
    _commitMutation();
    return true;
  }

  bool deleteProjectGroup(String groupId) => deleteGroup(groupId);

  void archiveGroup(String groupId) => _setGroupArchived(groupId, true);
  void unarchiveGroup(String groupId) => _setGroupArchived(groupId, false);
  void setGroupArchived(String groupId, bool archived) =>
      _setGroupArchived(groupId, archived);

  void _setGroupArchived(String groupId, bool archived) {
    _ensureWritable();
    final index = _groups.indexWhere((group) => group.id == groupId);
    if (index < 0 || _groups[index].archived == archived) return;
    final updated = _groups[index].copyWith(
      archived: archived,
      updatedAt: _nowProvider().toUtc(),
    );
    final next = <ProjectGroup>[..._groups]..[index] = updated;
    _setGroups(next);
    _commitMutation();
  }

  Project createProject({
    required String name,
    String iconKey = 'folder',
    String colorKey = 'blue',
    String? groupId,
  }) {
    _ensureWritable();
    final normalized = name.trim();
    if (normalized.isEmpty) throw ArgumentError.value(name, 'name');
    final validGroup = groupId != null && _groupFor(groupId) != null
        ? groupId
        : null;
    final now = _nowProvider().toUtc();
    final sort = _projects.fold<int>(
      0,
      (max, project) => project.sortOrder > max ? project.sortOrder : max,
    );
    final project = Project(
      id: _newProjectId(),
      name: normalized,
      iconKey: iconKey,
      colorKey: colorKey,
      sortOrder: sort + TodoMoveService.sortGap,
      archived: false,
      createdAt: now,
      updatedAt: now,
      groupId: validGroup,
    );
    _setProjects(<Project>[..._projects, project]);
    _commitMutation();
    return project;
  }

  Project? getProject(String projectId) => _projectFor(projectId);

  Project? updateProject(Project project) {
    _ensureWritable();
    final index = _projects.indexWhere((entry) => entry.id == project.id);
    if (index < 0) return null;
    final validGroup =
        project.groupId != null && _groupFor(project.groupId!) != null
        ? project.groupId
        : null;
    final updated = project.copyWith(
      groupId: validGroup,
      updatedAt: _nowProvider().toUtc(),
    );
    final next = <Project>[..._projects]..[index] = updated;
    _setProjects(next);
    _commitMutation();
    return updated;
  }

  Project? editProject(Project project) => updateProject(project);

  void archiveProject(String projectId) => _setProjectArchived(projectId, true);
  void unarchiveProject(String projectId) =>
      _setProjectArchived(projectId, false);
  void setProjectArchived(String projectId, bool archived) =>
      _setProjectArchived(projectId, archived);

  void _setProjectArchived(String projectId, bool archived) {
    _ensureWritable();
    final index = _projects.indexWhere((project) => project.id == projectId);
    if (index < 0 || _projects[index].archived == archived) return;
    final updated = _projects[index].copyWith(
      archived: archived,
      updatedAt: _nowProvider().toUtc(),
    );
    final next = <Project>[..._projects]..[index] = updated;
    _setProjects(next);
    _commitMutation();
  }

  TrashItem? deleteProject(String projectId) {
    _ensureWritable();
    final project = _projectFor(projectId);
    if (project == null) return null;
    final deletedTodos = _todos
        .where((todo) => todo.projectId == projectId)
        .toList(growable: false);
    final trash = TrashItem(
      id: _newTrashId(),
      kind: 'project_subtree',
      payload: <String, dynamic>{
        'project': project.toJson(),
        'deletedAt': _nowProvider().toUtc().toIso8601String(),
        'todos': <dynamic>[for (final todo in deletedTodos) todo.toJson()],
      },
    );
    _setProjects(
      _projects.where((entry) => entry.id != projectId).toList(growable: false),
    );
    _setTodos(
      _todos
          .where((todo) => todo.projectId != projectId)
          .toList(growable: false),
    );
    _setTrash(<TrashItem>[..._trash, trash]);
    _commitMutation();
    return trash;
  }

  Future<void> flushNow() {
    final inFlight = _flushInFlight;
    if (inFlight != null) {
      // A caller explicitly requested a flush while an older snapshot is
      // still being written. The in-flight operation will loop once more and
      // persist the newest revision before completing.
      _flushAgain = true;
      return inFlight;
    }
    late Future<void> tracked;
    tracked = _flushNowInternal().whenComplete(() {
      if (identical(_flushInFlight, tracked)) _flushInFlight = null;
    });
    _flushInFlight = tracked;
    return tracked;
  }

  Future<void> _flushNowInternal() async {
    while (true) {
      _flushAgain = false;
      _saveTimer?.cancel();
      _saveTimer = null;
      final repository = _repository;
      if (repository == null || !_dirty || _benchmarkMode) return;
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
      if (!_flushAgain && !(_dirty && _data.revision != snapshot.revision)) {
        return;
      }
    }
  }

  /// Replaces the business dataset as one persistence transaction.
  ///
  /// The caller must validate and back up the source before invoking this
  /// method.  The imported revision never moves backwards: the saved snapshot
  /// receives `max(currentRevision, importedRevision) + 1`.
  Future<void> replaceDataTransactional(AppData imported) async {
    if (_repository == null || _benchmarkMode) {
      throw StateError('Workspace persistence is unavailable');
    }
    if (imported.schemaVersion != AppData.currentSchemaVersion ||
        imported.revision < 0) {
      throw StateError('Imported AppData is not a current schema snapshot');
    }
    final before = _capturePersistenceSnapshot();
    _saveTimer?.cancel();
    _saveTimer = null;
    final nextRevision =
        (imported.revision > _data.revision
            ? imported.revision
            : _data.revision) +
        1;
    final next = imported.copyWith(
      schemaVersion: AppData.currentSchemaVersion,
      revision: nextRevision,
    );
    _applyData(next);
    _scope = WorkspaceScope.all;
    _projectScopeId = null;
    _searchQuery = '';
    _pendingHistoryBefore = null;
    _dirty = true;
    _lastPersistenceError = null;
    notifyListeners();
    try {
      await flushNow();
    } catch (error) {
      _restorePersistenceSnapshot(before, error);
      rethrow;
    }
    _history.clear();
    _pendingHistoryBefore = null;
    _dirty = false;
    _lastPersistenceError = null;
    notifyListeners();
  }

  void _setGroups(List<ProjectGroup> groups) {
    _captureMutationBefore();
    _groups = List.unmodifiable(groups);
    _data = _data.copyWith(groups: _groups);
  }

  void _setProjects(List<Project> projects) {
    _captureMutationBefore();
    _projects = List.unmodifiable(projects);
    _data = _data.copyWith(projects: _projects);
  }

  void _setTodos(List<TodoItem> todos) {
    _captureMutationBefore();
    _todos = List.unmodifiable(todos);
    _data = _data.copyWith(todos: _todos);
  }

  void _setTrash(List<TrashItem> trash) {
    _captureMutationBefore();
    _trash = List.unmodifiable(trash);
    _data = _data.copyWith(trash: _trash);
  }

  void _commitMutation({bool recordHistory = true}) {
    final before = _pendingHistoryBefore;
    _pendingHistoryBefore = null;
    _data = _data.copyWith(
      schemaVersion: AppData.currentSchemaVersion,
      revision: _data.revision + 1,
      groups: _groups,
      projects: _projects,
      todos: _todos,
      trash: _trash,
    );
    if (recordHistory && before != null && !_applyingHistory) {
      _history.record(before, _data);
    }
    _dirty = _repository != null && !_benchmarkMode;
    _lastPersistenceError = null;
    if (_dirty) {
      _saveTimer?.cancel();
      _saveTimer = Timer(const Duration(milliseconds: 250), () {
        unawaited(_flushDebounced());
      });
    }
    notifyListeners();
  }

  void _captureMutationBefore() {
    if (_applyingHistory || _pendingHistoryBefore != null) return;
    _pendingHistoryBefore = _data;
  }

  void _applyHistorySnapshot(AppData snapshot) {
    _applyingHistory = true;
    try {
      _pendingHistoryBefore = null;
      _groups = List.unmodifiable(snapshot.groups);
      _projects = List.unmodifiable(snapshot.projects);
      _todos = List.unmodifiable(snapshot.todos);
      _trash = List.unmodifiable(snapshot.trash);
      _dataset = _todos.length == TodoDataset.thousand.count
          ? TodoDataset.thousand
          : TodoDataset.fifty;
      _data = snapshot.copyWith(
        schemaVersion: AppData.currentSchemaVersion,
        revision: _data.revision + 1,
        groups: _groups,
        projects: _projects,
        todos: _todos,
        trash: _trash,
      );
      _dirty = _repository != null && !_benchmarkMode;
      _lastPersistenceError = null;
      if (_dirty) {
        _saveTimer?.cancel();
        _saveTimer = Timer(const Duration(milliseconds: 250), () {
          unawaited(_flushDebounced());
        });
      }
      notifyListeners();
    } finally {
      _applyingHistory = false;
    }
  }

  Future<void> _flushDebounced() async {
    try {
      await flushNow();
    } catch (_) {
      // The error remains queryable through [lastPersistenceError].
    }
  }

  _WorkspacePersistenceSnapshot _capturePersistenceSnapshot() {
    return _WorkspacePersistenceSnapshot(
      data: _data,
      groups: _groups,
      projects: _projects,
      todos: _todos,
      trash: _trash,
      dataset: _dataset,
      benchmarkMode: _benchmarkMode,
      dirty: _dirty,
      scope: _scope,
      projectScopeId: _projectScopeId,
      searchQuery: _searchQuery,
      pendingHistoryBefore: _pendingHistoryBefore,
    );
  }

  void _restorePersistenceSnapshot(
    _WorkspacePersistenceSnapshot snapshot,
    Object error,
  ) {
    _saveTimer?.cancel();
    _saveTimer = null;
    _data = snapshot.data;
    _groups = snapshot.groups;
    _projects = snapshot.projects;
    _todos = snapshot.todos;
    _trash = snapshot.trash;
    _dataset = snapshot.dataset;
    _benchmarkMode = snapshot.benchmarkMode;
    _dirty = snapshot.dirty;
    _scope = snapshot.scope;
    _projectScopeId = snapshot.projectScopeId;
    _searchQuery = snapshot.searchQuery;
    _pendingHistoryBefore = snapshot.pendingHistoryBefore;
    _lastPersistenceError = error;
    if (_dirty && _repository != null && !_benchmarkMode) {
      _saveTimer = Timer(const Duration(milliseconds: 250), () {
        unawaited(_flushDebounced());
      });
    }
    notifyListeners();
  }

  void _applyData(AppData data) {
    final normalized = data.schemaVersion == AppData.currentSchemaVersion
        ? data
        : AppData.fromJson(data.toJson());
    _data = normalized;
    _groups = normalized.groups;
    _projects = normalized.projects;
    _todos = normalized.todos;
    _trash = normalized.trash;
    _dataset = normalized.todos.length == TodoDataset.thousand.count
        ? TodoDataset.thousand
        : TodoDataset.fifty;
  }

  void _ensureWritable() {
    if (_disposed) {
      throw StateError('WorkspaceController is disposed');
    }
    if (_benchmarkMode && _repository != null) {
      throw StateError('benchmark mode is read-only');
    }
  }

  TodoItem? _todoById(String id) {
    for (final todo in _todos) {
      if (todo.id == id) return todo;
    }
    return null;
  }

  Project? _projectFor(String? id) {
    if (id == null) return null;
    for (final project in _projects) {
      if (project.id == id) return project;
    }
    return null;
  }

  ProjectGroup? _groupFor(String? id) {
    if (id == null) return null;
    for (final group in _groups) {
      if (group.id == id) return group;
    }
    return null;
  }

  String? _resolveProjectId(String? requested) {
    final candidate =
        requested ??
        (_scope == WorkspaceScope.project ? _projectScopeId : null);
    if (candidate == null) return null;
    final project = _projectFor(candidate);
    if (project == null || project.archived) return null;
    final group = _groupFor(project.groupId);
    if (group?.archived == true) return null;
    return project.id;
  }

  int _depthOf(String id) {
    var depth = 0;
    var current = _todoById(id);
    final path = <String>{};
    while (current?.parentId != null) {
      if (!path.add(current!.id)) {
        throw StateError('Todo tree contains a cycle');
      }
      depth += 1;
      current = _todoById(current.parentId!);
      if (current == null) break;
    }
    return depth;
  }

  List<TodoItem> _replaceTodo(String id, TodoItem replacement) => <TodoItem>[
    for (final todo in _todos) todo.id == id ? replacement : todo,
  ];

  bool _isUnfinishedVisible(TodoItem todo) {
    if (todo.completed || todo.archivedAt != null) return false;
    final project = _projectFor(todo.projectId);
    if (project?.archived == true) return false;
    if (_groupFor(project?.groupId)?.archived == true) return false;
    return true;
  }

  bool _matchesScope(TodoItem todo, [WorkspaceScope? requested]) {
    final value = requested ?? _scope;
    if (value == WorkspaceScope.archived) return todo.archivedAt != null;
    if (todo.archivedAt != null) return false;
    if (value != WorkspaceScope.project && value != WorkspaceScope.archived) {
      final project = _projectFor(todo.projectId);
      if (project?.archived == true ||
          _groupFor(project?.groupId)?.archived == true) {
        return false;
      }
    }
    switch (value) {
      case WorkspaceScope.all:
        return true;
      case WorkspaceScope.inbox:
        return todo.projectId == null;
      case WorkspaceScope.today:
        return _isDueOn(todo, _nowProvider().toLocal());
      case WorkspaceScope.recent:
        return _isDueInRecent(todo, _nowProvider().toLocal());
      case WorkspaceScope.completed:
        return todo.completed;
      case WorkspaceScope.archived:
        return todo.archivedAt != null;
      case WorkspaceScope.project:
        return todo.projectId == _projectScopeId;
      case WorkspaceScope.search:
        final needle = _searchQuery.trim().toLowerCase();
        if (needle.isEmpty) return true;
        final projectName = _projectFor(todo.projectId)?.name ?? '';
        return todo.title.toLowerCase().contains(needle) ||
            projectName.toLowerCase().contains(needle);
    }
  }

  bool _isDueOn(TodoItem todo, DateTime localDate) {
    final due = todo.dueAt?.toLocal();
    return due != null &&
        due.year == localDate.year &&
        due.month == localDate.month &&
        due.day == localDate.day;
  }

  bool _isDueInRecent(TodoItem todo, DateTime localDate) {
    final due = todo.dueAt?.toLocal();
    if (due == null) return false;
    final start = DateTime(localDate.year, localDate.month, localDate.day);
    final end = start.add(const Duration(days: 7));
    return !due.isBefore(start) && due.isBefore(end);
  }

  String _newTodoId() => _newUniqueId('todo', _todos.map((todo) => todo.id));
  String _newProjectId() =>
      _newUniqueId('project', _projects.map((project) => project.id));
  String _newGroupId() =>
      _newUniqueId('group', _groups.map((group) => group.id));
  String _newTrashId() => _newUniqueId('trash', _trash.map((item) => item.id));

  String _newUniqueId(String prefix, Iterable<String> existing) {
    final used = existing.toSet();
    final stamp = _nowProvider().microsecondsSinceEpoch;
    var id = '$prefix-$stamp';
    var suffix = 0;
    while (used.contains(id)) {
      suffix += 1;
      id = '$prefix-$stamp-$suffix';
    }
    return id;
  }

  @override
  void dispose() {
    _disposed = true;
    _saveTimer?.cancel();
    super.dispose();
  }

  /// ChangeNotifier throws when a late asynchronous callback notifies after
  /// dispose. Persistence timers and UI listeners can legitimately finish on
  /// a later event-loop turn, so make that boundary a no-op instead of taking
  /// down the Flutter isolate.
  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  static List<ProjectGroup> _buildGroups() {
    final createdAt = DateTime.utc(2026, 1, 1);
    const definitions = <(String, String, String, String)>[
      ('group-work', '工作', 'briefcase', 'blue'),
      ('group-growth', '学习成长', 'book', 'violet'),
      ('group-life', '生活', 'home', 'green'),
    ];
    return List.unmodifiable(<ProjectGroup>[
      for (var i = 0; i < definitions.length; i++)
        ProjectGroup(
          id: definitions[i].$1,
          name: definitions[i].$2,
          iconKey: definitions[i].$3,
          colorKey: definitions[i].$4,
          sortOrder: (i + 1) * TodoMoveService.sortGap,
          archived: false,
          createdAt: createdAt,
          updatedAt: createdAt,
        ),
    ]);
  }

  static List<Project> _buildProjects() {
    final createdAt = DateTime.utc(2026, 1, 1);
    const definitions = <(String, String, String, String, String)>[
      ('project-focus', 'Focus', 'target', 'blue', 'group-work'),
      ('project-home', 'Home', 'home', 'green', 'group-life'),
      ('project-learning', 'Learning', 'book', 'violet', 'group-growth'),
      ('project-ideas', 'Ideas', 'sparkles', 'orange', 'group-work'),
    ];
    return List.unmodifiable(<Project>[
      for (var i = 0; i < definitions.length; i++)
        Project(
          id: definitions[i].$1,
          name: definitions[i].$2,
          iconKey: definitions[i].$3,
          colorKey: definitions[i].$4,
          groupId: definitions[i].$5,
          sortOrder: (i + 1) * TodoMoveService.sortGap,
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
          dueAt: base.add(Duration(days: i % 8)),
          archivedAt: null,
          sortOrder: (offset + 1) * 10,
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
    required this.groups,
    required this.projects,
    required this.todos,
    required this.trash,
    required this.dataset,
    required this.benchmarkMode,
    required this.dirty,
    required this.scope,
    required this.projectScopeId,
    required this.searchQuery,
    required this.pendingHistoryBefore,
  });

  final AppData data;
  final List<ProjectGroup> groups;
  final List<Project> projects;
  final List<TodoItem> todos;
  final List<TrashItem> trash;
  final TodoDataset dataset;
  final bool benchmarkMode;
  final bool dirty;
  final WorkspaceScope scope;
  final String? projectScopeId;
  final String searchQuery;
  final AppData? pendingHistoryBefore;
}
