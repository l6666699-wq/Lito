import 'todo_item.dart';

enum TodoVisualState { incomplete, partial, complete }

/// A row ready for lazy rendering. The model is intentionally flat; depth is
/// metadata for indentation rather than a nested Widget tree.
class VisibleTodoRow {
  const VisibleTodoRow({
    required this.todo,
    required this.depth,
    required this.completionState,
  });

  final TodoItem todo;
  final int depth;
  final TodoVisualState completionState;
}
