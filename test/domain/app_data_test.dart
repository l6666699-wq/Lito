import 'package:flutter_test/flutter_test.dart';
import 'package:litetodo/domain/models/app_data.dart';
import 'package:litetodo/domain/models/project.dart';
import 'package:litetodo/domain/models/todo_item.dart';

void main() {
  test(
    'TrashItem defensively freezes direct and nested payload containers',
    () {
      final source = <String, dynamic>{
        'title': 'before',
        'meta': <String, dynamic>{
          'labels': <dynamic>['one'],
        },
      };
      final item = TrashItem(id: 'trash-1', kind: 'todo', payload: source);

      source['title'] = 'after';
      (source['meta'] as Map<String, dynamic>)['labels'] = <dynamic>['changed'];

      expect(item.payload['title'], 'before');
      expect(
        (item.payload['meta'] as Map<String, dynamic>)['labels'],
        <dynamic>['one'],
      );
      expect(() => item.payload['title'] = 'blocked', throwsUnsupportedError);
      expect(
        () => (item.payload['meta'] as Map<String, dynamic>)['new'] = true,
        throwsUnsupportedError,
      );
      expect(
        () =>
            ((item.payload['meta'] as Map<String, dynamic>)['labels']
                    as List<dynamic>)[0] =
                'blocked',
        throwsUnsupportedError,
      );
    },
  );

  test('AppData keeps schema, revision, lists, and trash in JSON', () {
    final now = DateTime.utc(2026, 8, 10);
    final project = Project(
      id: 'p1',
      name: 'Project',
      iconKey: 'folder',
      colorKey: 'blue',
      sortOrder: 0,
      archived: false,
      createdAt: now,
      updatedAt: now,
    );
    final todo = TodoItem(
      id: 't1',
      projectId: 'p1',
      parentId: null,
      title: 'Task',
      completed: false,
      completedAt: null,
      sortOrder: 1000,
      collapsed: false,
      createdAt: now,
      updatedAt: now,
    );
    final source = AppData(
      schemaVersion: 1,
      revision: 7,
      projects: <Project>[project],
      todos: <TodoItem>[todo],
      trash: const <TrashItem>[],
    );

    final decoded = AppData.fromJson(source.toJson());
    expect(decoded, source);
    expect(decoded.toJson(), containsPair('schemaVersion', 1));
    expect(decoded.toJson(), containsPair('revision', 7));
    expect(decoded.toJson(), containsPair('trash', isEmpty));
    expect(() => AppData.fromJson(<String, dynamic>{}), throwsFormatException);
    expect(
      () => AppData.fromJson(<String, dynamic>{
        'schemaVersion': 2,
        'revision': 0,
        'projects': <dynamic>[],
        'todos': <dynamic>[],
        'trash': <dynamic>[],
      }),
      throwsFormatException,
    );
  });
}
