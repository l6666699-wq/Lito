import '../models/todo_item.dart';
import '../models/visible_todo_row.dart';

/// An index over the flat parentId Todo representation.
///
/// The index stores only ids in sibling order. It never creates nested model
/// objects, which keeps both persistence and ListView rendering predictable.
class TodoTreeIndex {
  factory TodoTreeIndex(Iterable<TodoItem> todos) => TodoTreeIndex.build(todos);

  TodoTreeIndex._({
    required Map<String, TodoItem> byId,
    required Map<String?, List<String>> childrenByParent,
    required Map<String, int> sourceOrder,
  }) : byId = Map.unmodifiable(byId),
       childrenByParent = Map.unmodifiable(<String?, List<String>>{
         for (final entry in childrenByParent.entries)
           entry.key: List.unmodifiable(entry.value),
       }),
       _sourceOrder = Map.unmodifiable(sourceOrder);

  factory TodoTreeIndex.build(Iterable<TodoItem> todos) {
    final byId = <String, TodoItem>{};
    final sourceOrder = <String, int>{};
    var order = 0;
    for (final todo in todos) {
      // Duplicate ids cannot describe a valid flat model. Keeping the first
      // occurrence avoids silently changing a previously indexed parent link.
      if (byId.containsKey(todo.id)) {
        order++;
        continue;
      }
      byId[todo.id] = todo;
      sourceOrder[todo.id] = order++;
    }

    final childrenByParent = <String?, List<String>>{};
    for (final todo in byId.values) {
      final parentId = todo.parentId != null && byId.containsKey(todo.parentId)
          ? todo.parentId
          : null;
      childrenByParent.putIfAbsent(parentId, () => <String>[]).add(todo.id);
    }

    for (final children in childrenByParent.values) {
      children.sort((left, right) {
        final leftTodo = byId[left]!;
        final rightTodo = byId[right]!;
        final bySort = leftTodo.sortOrder.compareTo(rightTodo.sortOrder);
        if (bySort != 0) return bySort;
        return sourceOrder[left]!.compareTo(sourceOrder[right]!);
      });
    }

    return TodoTreeIndex._(
      byId: byId,
      childrenByParent: childrenByParent,
      sourceOrder: sourceOrder,
    );
  }

  /// Alias kept concise for callers that treat the index as a value object.
  factory TodoTreeIndex.fromTodos(Iterable<TodoItem> todos) =>
      TodoTreeIndex.build(todos);

  final Map<String, TodoItem> byId;
  final Map<String?, List<String>> childrenByParent;
  final Map<String, int> _sourceOrder;

  List<String> childrenOf(String? parentId) {
    return childrenByParent[parentId] ?? const <String>[];
  }

  int sourceOrderOf(String id) => _sourceOrder[id] ?? 0;
}

/// Converts a flat Todo list into only the rows visible in the current tree.
class TodoTreeService {
  TodoTreeService(Iterable<TodoItem> todos)
    : index = TodoTreeIndex.build(todos);

  static const int maxTreeDepth = 6;
  static const int maxDepth = maxTreeDepth;

  final TodoTreeIndex index;

  List<VisibleTodoRow> buildVisibleRows({
    String? projectId,
    bool inboxOnly = false,
    Set<String> collapsedIds = const <String>{},
  }) {
    final allowed = <String>{
      for (final todo in index.byId.values)
        if (inboxOnly
            ? todo.projectId == null
            : projectId == null || todo.projectId == projectId)
          todo.id,
    };
    final rows = <VisibleTodoRow>[];
    final seen = <String>{};
    final suppressed = <String>{};
    final path = <String>{};

    bool isCollapsed(TodoItem todo) =>
        todo.collapsed || collapsedIds.contains(todo.id);

    TodoVisualState visualState(String id, Set<String> statePath) {
      final todo = index.byId[id];
      if (todo == null || !allowed.contains(id)) {
        return TodoVisualState.incomplete;
      }
      if (!statePath.add(id)) return TodoVisualState.incomplete;

      final childIds = index.childrenOf(id).where(allowed.contains).toList();
      if (childIds.isEmpty) {
        statePath.remove(id);
        return todo.completed
            ? TodoVisualState.complete
            : TodoVisualState.incomplete;
      }
      var completeCount = 0;
      var hasPartial = false;
      for (final childId in childIds) {
        final childState = visualState(childId, statePath);
        if (childState == TodoVisualState.complete) {
          completeCount++;
        } else if (childState == TodoVisualState.partial) {
          hasPartial = true;
        }
      }
      statePath.remove(id);
      if (completeCount == childIds.length) {
        return TodoVisualState.complete;
      }
      if (todo.completed || completeCount > 0 || hasPartial) {
        return TodoVisualState.partial;
      }
      return TodoVisualState.incomplete;
    }

    void suppressDescendants(String id, Set<String> suppressPath) {
      if (!allowed.contains(id) || !suppressPath.add(id)) return;
      suppressed.add(id);
      for (final childId in index.childrenOf(id)) {
        suppressDescendants(childId, suppressPath);
      }
      suppressPath.remove(id);
    }

    void visit(String id, int depth) {
      if (!allowed.contains(id) || seen.contains(id) || path.contains(id)) {
        return;
      }
      final todo = index.byId[id];
      if (todo == null) return;
      seen.add(id);
      path.add(id);
      rows.add(
        VisibleTodoRow(
          todo: todo,
          depth: depth,
          completionState: visualState(id, <String>{}),
        ),
      );

      // A depth beyond the contract is not allowed to fan out indefinitely.
      // Any unvisited descendants are promoted to a safe root pass below.
      if (!isCollapsed(todo) && depth + 1 < maxTreeDepth) {
        for (final childId in index.childrenOf(id)) {
          visit(childId, depth + 1);
        }
      } else {
        for (final childId in index.childrenOf(id)) {
          suppressDescendants(childId, <String>{});
        }
      }
      path.remove(id);
    }

    final roots = <String>[];
    for (final id in allowed) {
      final todo = index.byId[id]!;
      final parent = todo.parentId;
      if (parent == null || !allowed.contains(parent)) {
        roots.add(id);
      }
    }
    roots.sort(_compareIds);
    for (final id in roots) {
      visit(id, 0);
    }

    // A closed cycle has no root. Emit each component once as a root instead
    // of recursing forever, preserving deterministic source/sort order.
    final orphans = allowed
        .where((id) => !seen.contains(id) && !suppressed.contains(id))
        .toList();
    orphans.sort(_compareIds);
    for (final id in orphans) {
      visit(id, 0);
    }
    return List.unmodifiable(rows);
  }

  List<VisibleTodoRow> visibleRows({
    String? projectId,
    bool inboxOnly = false,
    Set<String> collapsedIds = const <String>{},
  }) {
    return buildVisibleRows(
      projectId: projectId,
      inboxOnly: inboxOnly,
      collapsedIds: collapsedIds,
    );
  }

  int _compareIds(String left, String right) {
    final leftTodo = index.byId[left]!;
    final rightTodo = index.byId[right]!;
    final bySort = leftTodo.sortOrder.compareTo(rightTodo.sortOrder);
    if (bySort != 0) return bySort;
    return index.sourceOrderOf(left).compareTo(index.sourceOrderOf(right));
  }
}
