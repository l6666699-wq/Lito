import '../../domain/services/todo_move_service.dart';

/// Payload carried by the explicit Todo drag handle.
///
/// Keeping the payload separate from the widget means a row can expose a real
/// mouse drag affordance without making the title/check controls draggable.
class TodoDragData {
  const TodoDragData(this.movingId);

  final String movingId;
}

/// Current vertical hit-test result for a Todo drop target.
class TodoDropCandidate {
  const TodoDropCandidate({
    required this.movingId,
    required this.targetId,
    required this.position,
  });

  final String movingId;
  final String targetId;
  final TodoMovePosition position;
}
