import 'package:flutter_test/flutter_test.dart';
import 'package:litetodo/domain/models/app_data.dart';

void main() {
  test('v1 JSON migrates to v2 without dropping projects, todos or trash', () {
    final v1 = <String, dynamic>{
      'schemaVersion': 1,
      'revision': 8,
      'projects': <dynamic>[
        <String, dynamic>{
          'id': 'p1',
          'name': 'Legacy project',
          'iconKey': 'folder',
          'colorKey': 'blue',
          'sortOrder': 1000,
          'archived': false,
          'createdAt': '2026-01-01T00:00:00.000Z',
          'updatedAt': '2026-01-01T00:00:00.000Z',
        },
      ],
      'todos': <dynamic>[
        <String, dynamic>{
          'id': 't1',
          'projectId': 'p1',
          'parentId': null,
          'title': 'Legacy task',
          'completed': false,
          'completedAt': null,
          'sortOrder': 1000,
          'collapsed': false,
          'createdAt': '2026-01-01T00:00:00.000Z',
          'updatedAt': '2026-01-01T00:00:00.000Z',
        },
      ],
      'trash': <dynamic>[
        <String, dynamic>{
          'id': 'trash-1',
          'kind': 'todo',
          'payload': <String, dynamic>{'title': 'deleted'},
        },
      ],
    };

    final migrated = AppData.fromJson(v1);
    expect(migrated.schemaVersion, AppData.currentSchemaVersion);
    expect(migrated.revision, 8);
    expect(migrated.groups, isEmpty);
    expect(migrated.projects.single.id, 'p1');
    expect(migrated.projects.single.groupId, isNull);
    expect(migrated.todos.single.id, 't1');
    expect(migrated.todos.single.dueAt, isNull);
    expect(migrated.todos.single.archivedAt, isNull);
    expect(migrated.trash.single.id, 'trash-1');
  });
}
