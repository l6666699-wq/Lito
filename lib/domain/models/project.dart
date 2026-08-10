/// A user-defined Todo project.
///
/// The model intentionally stays pure Dart so it can be used by persistence,
/// tree algorithms, and the Flutter presentation without platform coupling.
class Project {
  const Project({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.colorKey,
    required this.sortOrder,
    required this.archived,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String iconKey;
  final String colorKey;
  final int sortOrder;
  final bool archived;
  final DateTime createdAt;
  final DateTime updatedAt;

  Project copyWith({
    String? id,
    String? name,
    String? iconKey,
    String? colorKey,
    int? sortOrder,
    bool? archived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      iconKey: iconKey ?? this.iconKey,
      colorKey: colorKey ?? this.colorKey,
      sortOrder: sortOrder ?? this.sortOrder,
      archived: archived ?? this.archived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      iconKey: json['iconKey'] as String? ?? 'folder',
      colorKey: json['colorKey'] as String? ?? 'blue',
      sortOrder: _readInt(json['sortOrder']),
      archived: _readBool(json['archived']),
      createdAt: _readDate(json['createdAt']),
      updatedAt: _readDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'iconKey': iconKey,
      'colorKey': colorKey,
      'sortOrder': sortOrder,
      'archived': archived,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    return other is Project &&
        other.id == id &&
        other.name == name &&
        other.iconKey == iconKey &&
        other.colorKey == colorKey &&
        other.sortOrder == sortOrder &&
        other.archived == archived &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    iconKey,
    colorKey,
    sortOrder,
    archived,
    createdAt,
    updatedAt,
  );
}

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
