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
  });

  final String id;
  final String? projectId;
  final String? parentId;
  final String title;
  final bool completed;
  final DateTime? completedAt;
  final int sortOrder;
  final bool collapsed;
  final DateTime createdAt;
  final DateTime updatedAt;

  TodoItem copyWith({
    String? id,
    Object? projectId = _copyWithSentinel,
    Object? parentId = _copyWithSentinel,
    String? title,
    bool? completed,
    Object? completedAt = _copyWithSentinel,
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
      parentId: identical(parentId, _copyWithSentinel)
          ? this.parentId
          : parentId as String?,
      title: title ?? this.title,
      completed: completed ?? this.completed,
      completedAt: identical(completedAt, _copyWithSentinel)
          ? this.completedAt
          : completedAt as DateTime?,
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
      parentId: json['parentId'] as String?,
      title: json['title'] as String? ?? '',
      completed: _readBool(json['completed']),
      completedAt: _readNullableDate(json['completedAt']),
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
      'parentId': parentId,
      'title': title,
      'completed': completed,
      'completedAt': completedAt?.toIso8601String(),
      'sortOrder': sortOrder,
      'collapsed': collapsed,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    return other is TodoItem &&
        other.id == id &&
        other.projectId == projectId &&
        other.parentId == parentId &&
        other.title == title &&
        other.completed == completed &&
        other.completedAt == completedAt &&
        other.sortOrder == sortOrder &&
        other.collapsed == collapsed &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    parentId,
    title,
    completed,
    completedAt,
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
