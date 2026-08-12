enum TodoPriority { none, low, medium, high }

TodoPriority todoPriorityFromJson(Object? value) {
  switch (value) {
    case 'high':
      return TodoPriority.high;
    case 'medium':
      return TodoPriority.medium;
    case 'low':
      return TodoPriority.low;
    default:
      return TodoPriority.none;
  }
}

String todoPriorityToJson(TodoPriority priority) {
  switch (priority) {
    case TodoPriority.high:
      return 'high';
    case TodoPriority.medium:
      return 'medium';
    case TodoPriority.low:
      return 'low';
    case TodoPriority.none:
      return 'none';
  }
}

/// The flat, persistent representation of one Todo.
class TodoItem {
  const TodoItem({
    required this.id,
    required this.projectId,
    required this.parentId,
    required this.title,
    required this.completed,
    required this.completedAt,
    required this.sortOrder,
    required this.collapsed,
    required this.createdAt,
    required this.updatedAt,
    this.dueAt,
    this.archivedAt,
    this.priority = TodoPriority.none,
    this.groupId,
  });

  final String id;
  final String? projectId;

  /// A root Todo may belong directly to a project group. Project-owned Todos
  /// keep this null; child Todos inherit the same container as their parent.
  final String? groupId;
  final String? parentId;
  final String title;
  final bool completed;
  final DateTime? completedAt;

  /// Stored as UTC; callers may construct with a local value, but persistence
  /// always serializes the instant in UTC.
  final DateTime? dueAt;

  /// A non-null value archives the Todo without removing it from the flat
  /// list.  This keeps archive/unarchive reversible and migration friendly.
  final DateTime? archivedAt;
  final TodoPriority priority;
  final int sortOrder;
  final bool collapsed;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get archived => archivedAt != null;
  bool get isArchived => archived;

  TodoItem copyWith({
    String? id,
    Object? projectId = _copyWithSentinel,
    Object? groupId = _copyWithSentinel,
    Object? parentId = _copyWithSentinel,
    String? title,
    bool? completed,
    Object? completedAt = _copyWithSentinel,
    Object? dueAt = _copyWithSentinel,
    Object? archivedAt = _copyWithSentinel,
    TodoPriority? priority,
    int? sortOrder,
    bool? collapsed,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TodoItem(
      id: id ?? this.id,
      projectId: identical(projectId, _copyWithSentinel)
          ? this.projectId
          : projectId as String?,
      groupId: identical(groupId, _copyWithSentinel)
          ? this.groupId
          : groupId as String?,
      parentId: identical(parentId, _copyWithSentinel)
          ? this.parentId
          : parentId as String?,
      title: title ?? this.title,
      completed: completed ?? this.completed,
      completedAt: identical(completedAt, _copyWithSentinel)
          ? this.completedAt
          : completedAt as DateTime?,
      dueAt: identical(dueAt, _copyWithSentinel)
          ? this.dueAt
          : dueAt as DateTime?,
      archivedAt: identical(archivedAt, _copyWithSentinel)
          ? this.archivedAt
          : archivedAt as DateTime?,
      priority: priority ?? this.priority,
      sortOrder: sortOrder ?? this.sortOrder,
      collapsed: collapsed ?? this.collapsed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    return TodoItem(
      id: json['id'] as String? ?? '',
      projectId: json['projectId'] as String?,
      groupId: json['groupId'] as String?,
      parentId: json['parentId'] as String?,
      title: json['title'] as String? ?? '',
      completed: _readBool(json['completed']),
      completedAt: _readNullableDate(json['completedAt']),
      dueAt: _readNullableDate(json['dueAt']),
      archivedAt: _readNullableDate(json['archivedAt']),
      priority: todoPriorityFromJson(json['priority']),
      sortOrder: _readInt(json['sortOrder']),
      collapsed: _readBool(json['collapsed']),
      createdAt: _readDate(json['createdAt']),
      updatedAt: _readDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'projectId': projectId,
      'groupId': groupId,
      'parentId': parentId,
      'title': title,
      'completed': completed,
      'completedAt': completedAt?.toUtc().toIso8601String(),
      'dueAt': dueAt?.toUtc().toIso8601String(),
      'archivedAt': archivedAt?.toUtc().toIso8601String(),
      'priority': todoPriorityToJson(priority),
      'sortOrder': sortOrder,
      'collapsed': collapsed,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    return other is TodoItem &&
        other.id == id &&
        other.projectId == projectId &&
        other.groupId == groupId &&
        other.parentId == parentId &&
        other.title == title &&
        other.completed == completed &&
        other.completedAt == completedAt &&
        other.dueAt == dueAt &&
        other.archivedAt == archivedAt &&
        other.priority == priority &&
        other.sortOrder == sortOrder &&
        other.collapsed == collapsed &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    groupId,
    parentId,
    title,
    completed,
    completedAt,
    dueAt,
    archivedAt,
    priority,
    sortOrder,
    collapsed,
    createdAt,
    updatedAt,
  );
}

const Object _copyWithSentinel = Object();

int _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

bool _readBool(Object? value) {
  if (value is bool) return value;
  if (value is String) return value.toLowerCase() == 'true';
  return false;
}

DateTime _readDate(Object? value) {
  if (value is DateTime) return value;
  return DateTime.tryParse(value as String? ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

DateTime? _readNullableDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value as String? ?? '');
}
