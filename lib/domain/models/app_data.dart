import 'project.dart';
import 'todo_item.dart';

/// The immutable snapshot written to the local LiteTodo data file.
///
/// `schemaVersion` is intentionally kept in the model from the first
/// persisted version so future migrations can be applied without guessing the
/// shape of an older file.  Lists are copied and exposed as unmodifiable views
/// to keep the controller's snapshot safe while a write is in flight.
class AppData {
  AppData({
    required this.schemaVersion,
    required this.revision,
    required List<Project> projects,
    required List<TodoItem> todos,
    required List<TrashItem> trash,
  }) : projects = List.unmodifiable(projects),
       todos = List.unmodifiable(todos),
       trash = List.unmodifiable(trash);

  static const int currentSchemaVersion = 1;

  AppData.empty()
    : schemaVersion = currentSchemaVersion,
      revision = 0,
      projects = const <Project>[],
      todos = const <TodoItem>[],
      trash = const <TrashItem>[];

  final int schemaVersion;
  final int revision;
  final List<Project> projects;
  final List<TodoItem> todos;
  final List<TrashItem> trash;

  AppData copyWith({
    int? schemaVersion,
    int? revision,
    List<Project>? projects,
    List<TodoItem>? todos,
    List<TrashItem>? trash,
  }) {
    return AppData(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      revision: revision ?? this.revision,
      projects: projects ?? this.projects,
      todos: todos ?? this.todos,
      trash: trash ?? this.trash,
    );
  }

  factory AppData.fromJson(Map<String, dynamic> json) {
    final schemaVersion = _readRequiredInt(json, 'schemaVersion');
    if (schemaVersion != currentSchemaVersion) {
      throw FormatException(
        'Unsupported LiteTodo schemaVersion: $schemaVersion',
      );
    }
    final revision = _readRequiredInt(json, 'revision');
    if (revision < 0) {
      throw const FormatException('revision must be non-negative');
    }
    final projects = _readList(
      json,
      'projects',
    ).map((entry) => Project.fromJson(entry)).toList(growable: false);
    final todos = _readList(
      json,
      'todos',
    ).map((entry) => TodoItem.fromJson(entry)).toList(growable: false);
    final trash = _readList(
      json,
      'trash',
    ).map((entry) => TrashItem.fromJson(entry)).toList(growable: false);
    return AppData(
      schemaVersion: schemaVersion,
      revision: revision,
      projects: projects,
      todos: todos,
      trash: trash,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'revision': revision,
      'projects': projects.map((project) => project.toJson()).toList(),
      'todos': todos.map((todo) => todo.toJson()).toList(),
      'trash': trash.map((item) => item.toJson()).toList(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (other is! AppData ||
        other.schemaVersion != schemaVersion ||
        other.revision != revision ||
        other.projects.length != projects.length ||
        other.todos.length != todos.length ||
        other.trash.length != trash.length) {
      return false;
    }
    for (var i = 0; i < projects.length; i++) {
      if (projects[i] != other.projects[i]) {
        return false;
      }
    }
    for (var i = 0; i < todos.length; i++) {
      if (todos[i] != other.todos[i]) {
        return false;
      }
    }
    for (var i = 0; i < trash.length; i++) {
      if (trash[i] != other.trash[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    schemaVersion,
    revision,
    Object.hashAll(projects),
    Object.hashAll(todos),
    Object.hashAll(trash),
  );
}

/// A deliberately small trash placeholder for Phase 0.
///
/// Todo deletion and restoration are a Phase 1 concern.  Keeping an explicit
/// typed entry here nevertheless makes the `trash` JSON field forward
/// compatible and prevents an untyped map from leaking into the domain model.
class TrashItem {
  TrashItem({
    required this.id,
    required this.kind,
    required Map<String, dynamic> payload,
  }) : payload = _freezeJsonMap(payload);

  final String id;
  final String kind;
  final Map<String, dynamic> payload;

  factory TrashItem.fromJson(Map<String, dynamic> json) {
    final rawPayload = json['payload'];
    final payload = rawPayload is Map
        ? Map<String, dynamic>.from(rawPayload)
        : <String, dynamic>{};
    return TrashItem(
      id: json['id'] as String? ?? '',
      kind: json['kind'] as String? ?? 'todo',
      payload: Map.unmodifiable(payload),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'id': id, 'kind': kind, 'payload': payload};
  }

  @override
  bool operator ==(Object other) {
    if (other is! TrashItem ||
        other.id != id ||
        other.kind != kind ||
        other.payload.length != payload.length) {
      return false;
    }
    for (final entry in payload.entries) {
      if (other.payload[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(id, kind, Object.hashAll(payload.entries));
}

Map<String, dynamic> _freezeJsonMap(Map<String, dynamic> source) {
  return Map.unmodifiable(<String, dynamic>{
    for (final entry in source.entries)
      entry.key: _freezeJsonValue(entry.value),
  });
}

Object? _freezeJsonValue(Object? value) {
  if (value is Map) {
    return _freezeJsonMap(<String, dynamic>{
      for (final entry in value.entries) '${entry.key}': entry.value,
    });
  }
  if (value is List) {
    return List.unmodifiable(value.map(_freezeJsonValue));
  }
  return value;
}

int _readRequiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num && value == value.toInt()) return value.toInt();
  throw FormatException('$key must be an integer');
}

List<Map<String, dynamic>> _readList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) throw FormatException('$key must be an array');
  return value
      .map((entry) {
        if (entry is! Map) {
          throw FormatException('$key contains an invalid entry');
        }
        return Map<String, dynamic>.from(entry);
      })
      .toList(growable: false);
}
