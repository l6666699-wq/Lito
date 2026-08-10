import 'project.dart';
import 'project_group.dart';
import 'trash_item.dart';
import 'todo_item.dart';

export 'trash_item.dart';

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
    List<ProjectGroup> groups = const <ProjectGroup>[],
    required List<Project> projects,
    required List<TodoItem> todos,
    required List<TrashItem> trash,
  }) : groups = List.unmodifiable(groups),
       projects = List.unmodifiable(projects),
       todos = List.unmodifiable(todos),
       trash = List.unmodifiable(trash);

  static const int currentSchemaVersion = 2;

  AppData.empty()
    : schemaVersion = currentSchemaVersion,
      revision = 0,
      groups = const <ProjectGroup>[],
      projects = const <Project>[],
      todos = const <TodoItem>[],
      trash = const <TrashItem>[];

  final int schemaVersion;
  final int revision;
  final List<ProjectGroup> groups;
  final List<Project> projects;
  final List<TodoItem> todos;
  final List<TrashItem> trash;

  AppData copyWith({
    int? schemaVersion,
    int? revision,
    List<ProjectGroup>? groups,
    List<Project>? projects,
    List<TodoItem>? todos,
    List<TrashItem>? trash,
  }) {
    return AppData(
      schemaVersion: schemaVersion ?? this.schemaVersion,
      revision: revision ?? this.revision,
      groups: groups ?? this.groups,
      projects: projects ?? this.projects,
      todos: todos ?? this.todos,
      trash: trash ?? this.trash,
    );
  }

  factory AppData.fromJson(Map<String, dynamic> json) {
    final schemaVersion = _readRequiredInt(json, 'schemaVersion');
    if (schemaVersion != 1 && schemaVersion != currentSchemaVersion) {
      throw FormatException(
        'Unsupported LiteTodo schemaVersion: $schemaVersion',
      );
    }
    final revision = _readRequiredInt(json, 'revision');
    if (revision < 0) {
      throw const FormatException('revision must be non-negative');
    }
    final migrated = schemaVersion == 1
        ? _migrateV1(json)
        : Map<String, dynamic>.from(json);
    final projects = _readList(
      migrated,
      'projects',
    ).map((entry) => Project.fromJson(entry)).toList(growable: false);
    final todos = _readList(
      migrated,
      'todos',
    ).map((entry) => TodoItem.fromJson(entry)).toList(growable: false);
    final trash = _readList(
      migrated,
      'trash',
    ).map((entry) => TrashItem.fromJson(entry)).toList(growable: false);
    final groups = _readListOrEmpty(
      migrated,
      'groups',
    ).map((entry) => ProjectGroup.fromJson(entry)).toList(growable: false);
    return AppData(
      schemaVersion: currentSchemaVersion,
      revision: revision,
      groups: groups,
      projects: projects,
      todos: todos,
      trash: trash,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schemaVersion': schemaVersion,
      'revision': revision,
      'groups': groups.map((group) => group.toJson()).toList(),
      'projects': projects.map((project) => project.toJson()).toList(),
      'todos': todos.map((todo) => todo.toJson()).toList(),
      'trash': trash.map((item) => item.toJson()).toList(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (other is! AppData ||
        _effectiveSchemaVersion(other.schemaVersion) !=
            _effectiveSchemaVersion(schemaVersion) ||
        other.revision != revision ||
        other.groups.length != groups.length ||
        other.projects.length != projects.length ||
        other.todos.length != todos.length ||
        other.trash.length != trash.length) {
      return false;
    }
    for (var i = 0; i < groups.length; i++) {
      if (groups[i] != other.groups[i]) {
        return false;
      }
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
    _effectiveSchemaVersion(schemaVersion),
    revision,
    Object.hashAll(groups),
    Object.hashAll(projects),
    Object.hashAll(todos),
    Object.hashAll(trash),
  );
}

int _effectiveSchemaVersion(int version) =>
    version == 1 ? AppData.currentSchemaVersion : version;

Map<String, dynamic> _migrateV1(Map<String, dynamic> source) {
  final migrated = <String, dynamic>{...source};
  migrated['schemaVersion'] = AppData.currentSchemaVersion;
  migrated['groups'] = <dynamic>[];
  migrated['projects'] = _readListOrEmpty(source, 'projects')
      .map(
        (project) => <String, dynamic>{
          ...project,
          'groupId': project['groupId'],
        },
      )
      .toList(growable: false);
  migrated['todos'] = _readListOrEmpty(source, 'todos')
      .map(
        (todo) => <String, dynamic>{
          ...todo,
          'dueAt': todo['dueAt'],
          'archivedAt': todo['archivedAt'],
        },
      )
      .toList(growable: false);
  migrated['trash'] = _readListOrEmpty(source, 'trash');
  return migrated;
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

List<Map<String, dynamic>> _readListOrEmpty(
  Map<String, dynamic> json,
  String key,
) {
  final value = json[key];
  if (value == null) return const <Map<String, dynamic>>[];
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
