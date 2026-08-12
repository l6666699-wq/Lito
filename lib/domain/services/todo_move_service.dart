import '../models/todo_item.dart';

/// Position of the dragged Todo relative to the drop target.
enum TodoMovePosition { before, inside, after }

/// Short aliases make the service convenient for callers that use the terms
/// from the drag/drop specification directly.
typedef MovePosition = TodoMovePosition;
typedef TodoMovePlacement = TodoMovePosition;

/// Pure flat-list tree movement.  The service never persists children and
/// returns a new immutable list with normalized sibling sort orders.
class TodoMoveService {
  const TodoMoveService();

  static const int maxTreeDepth = 6;
  static const int sortGap = 1000;

  List<TodoItem> move({
    required Iterable<TodoItem> todos,
    required String movingId,
    required String targetId,
    required TodoMovePosition position,
    String? destinationProjectId,
    String? destinationGroupId,
    bool allowCrossProject = false,
    DateTime? now,
  }) {
    return moveTodos(
      todos: todos,
      movingId: movingId,
      targetId: targetId,
      position: position,
      destinationProjectId: destinationProjectId,
      destinationGroupId: destinationGroupId,
      allowCrossProject: allowCrossProject,
      now: now,
    );
  }

  static List<TodoItem> moveTodos({
    required Iterable<TodoItem> todos,
    required String movingId,
    required String targetId,
    required TodoMovePosition position,
    String? destinationProjectId,
    String? destinationGroupId,
    bool allowCrossProject = false,
    DateTime? now,
  }) {
    final source = todos.toList(growable: true);
    final byId = <String, TodoItem>{for (final todo in source) todo.id: todo};
    final moving = byId[movingId];
    final target = byId[targetId];
    if (moving == null) {
      throw StateError('Moving Todo does not exist: $movingId');
    }
    if (target == null) {
      throw StateError('Target Todo does not exist: $targetId');
    }
    if (movingId == targetId) {
      throw StateError('A Todo cannot move onto itself');
    }

    final children = <String?, List<String>>{};
    for (final todo in source) {
      children.putIfAbsent(todo.parentId, () => <String>[]).add(todo.id);
    }
    final subtree = <String>{};
    void collect(String id) {
      if (!subtree.add(id)) return;
      for (final child in children[id] ?? const <String>[]) {
        collect(child);
      }
    }

    collect(movingId);
    if (subtree.contains(targetId)) {
      throw StateError('A Todo cannot move into its own descendant');
    }

    final targetProject = destinationProjectId ?? moving.projectId;
    final targetGroup = destinationGroupId ?? moving.groupId;
    if ((target.projectId != moving.projectId ||
            target.groupId != moving.groupId) &&
        destinationProjectId == null &&
        destinationGroupId == null) {
      throw StateError('Cross-project movement requires destinationProjectId');
    }
    if (destinationProjectId != null &&
        target.projectId != destinationProjectId) {
      throw StateError('Destination project must match the drop target');
    }
    if (destinationGroupId != null && target.groupId != destinationGroupId) {
      throw StateError('Destination group must match the drop target');
    }
    final projectChanged = targetProject != moving.projectId ||
        targetGroup != moving.groupId;
    if (projectChanged &&
        !allowCrossProject &&
        destinationProjectId == null &&
        destinationGroupId == null) {
      throw StateError('Cross-project movement requires destinationProjectId');
    }

    String? destinationParent;
    switch (position) {
      case TodoMovePosition.before:
      case TodoMovePosition.after:
        destinationParent = target.parentId;
      case TodoMovePosition.inside:
        destinationParent = target.id;
    }

    int depthOf(String? id) {
      var depth = 0;
      final path = <String>{};
      var current = id;
      while (current != null) {
        if (!path.add(current)) throw StateError('Todo tree contains a cycle');
        final parent = byId[current]?.parentId;
        if (parent == null || subtree.contains(current)) break;
        depth += 1;
        current = parent;
      }
      return depth;
    }

    final destinationDepth = destinationParent == null
        ? 0
        : depthOf(destinationParent) + 1;
    var subtreeHeight = 0;
    void measure(String id, int depth) {
      if (depth > subtreeHeight) subtreeHeight = depth;
      for (final child in children[id] ?? const <String>[]) {
        if (subtree.contains(child)) measure(child, depth + 1);
      }
    }

    measure(movingId, 0);
    if (destinationDepth + subtreeHeight >= maxTreeDepth) {
      throw StateError('Todo tree depth cannot exceed $maxTreeDepth');
    }

    final stamp = (now ?? DateTime.now()).toUtc();
    final updated = <String, TodoItem>{};
    for (final todo in source) {
      if (!subtree.contains(todo.id)) continue;
      updated[todo.id] = todo.copyWith(
        projectId: targetProject,
        groupId: targetGroup,
        parentId: todo.id == movingId ? destinationParent : todo.parentId,
        updatedAt: stamp,
      );
    }

    final transformed = <TodoItem>[
      for (final todo in source) updated[todo.id] ?? todo,
    ];

    // Build sibling lists in source order, remove the moving root from its old
    // list, then insert it around the target.  Descendants keep their own
    // sibling order under their unchanged parent IDs.
    final siblingIds = <String, List<String>>{};
    final order = <String, int>{};
    for (var i = 0; i < transformed.length; i++) {
      final todo = transformed[i];
      order[todo.id] = i;
      final key = _siblingKey(todo.projectId, todo.groupId, todo.parentId);
      siblingIds.putIfAbsent(key, () => <String>[]).add(todo.id);
    }
    for (final ids in siblingIds.values) {
      ids.sort((left, right) {
        final a =
            byId[left] ?? transformed.firstWhere((todo) => todo.id == left);
        final b =
            byId[right] ?? transformed.firstWhere((todo) => todo.id == right);
        final bySort = a.sortOrder.compareTo(b.sortOrder);
        return bySort != 0 ? bySort : order[left]!.compareTo(order[right]!);
      });
    }

    final oldKey = _siblingKey(
      moving.projectId,
      moving.groupId,
      moving.parentId,
    );
    siblingIds[oldKey]?.remove(movingId);
    final destinationKey = _siblingKey(
      targetProject,
      targetGroup,
      destinationParent,
    );
    final destinationSiblings = siblingIds.putIfAbsent(
      destinationKey,
      () => <String>[],
    );
    destinationSiblings.remove(movingId);
    final targetIndex = destinationSiblings.indexOf(targetId);
    if (targetIndex < 0) {
      destinationSiblings.add(movingId);
    } else {
      final insertAt = position == TodoMovePosition.after
          ? targetIndex + 1
          : targetIndex;
      destinationSiblings.insert(
        insertAt.clamp(0, destinationSiblings.length),
        movingId,
      );
    }

    final normalizedSort = <String, int>{};
    for (final ids in siblingIds.values) {
      for (var i = 0; i < ids.length; i++) {
        normalizedSort[ids[i]] = (i + 1) * sortGap;
      }
    }
    return List.unmodifiable(<TodoItem>[
      for (final todo in transformed)
        todo.copyWith(sortOrder: normalizedSort[todo.id] ?? todo.sortOrder),
    ]);
  }

  static String _siblingKey(
    String? projectId,
    String? groupId,
    String? parentId,
  ) {
    return '${projectId ?? '<project>'}|${groupId ?? '<inbox>'}|${parentId ?? '<root>'}';
  }
}

List<TodoItem> moveTodos({
  required Iterable<TodoItem> todos,
  required String movingId,
  required String targetId,
  required TodoMovePosition position,
  String? destinationProjectId,
  String? destinationGroupId,
  bool allowCrossProject = false,
  DateTime? now,
}) => TodoMoveService.moveTodos(
  todos: todos,
  movingId: movingId,
  targetId: targetId,
  position: position,
    destinationProjectId: destinationProjectId,
    destinationGroupId: destinationGroupId,
  allowCrossProject: allowCrossProject,
  now: now,
);
