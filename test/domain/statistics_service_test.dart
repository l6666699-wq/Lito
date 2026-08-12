import 'package:flutter_test/flutter_test.dart';
import 'package:litetodo/domain/models/todo_item.dart';
import 'package:litetodo/domain/services/statistics_service.dart';

TodoItem _todo(
  String id, {
  bool completed = false,
  bool archived = false,
  String? projectId,
}) {
  final date = DateTime.utc(2026, 8, completed ? 11 : 10);
  return TodoItem(
    id: id,
    projectId: projectId,
    parentId: null,
    title: id,
    completed: completed,
    completedAt: completed ? date : null,
    dueAt: date,
    archivedAt: archived ? date : null,
    sortOrder: 1000,
    collapsed: false,
    createdAt: date,
    updatedAt: date,
  );
}

void main() {
  test(
    'statistics are derived from real todos and exclude archived by default',
    () {
      final service = const StatisticsService();
      final todos = <TodoItem>[
        _todo('open', projectId: 'p1'),
        _todo('done', completed: true, projectId: 'p1'),
        _todo('archived', archived: true, projectId: 'p2'),
      ];
      final stats = service.calculate(todos);
      expect(stats.total, 2);
      expect(stats.completed, 1);
      expect(stats.uncompleted, 1);
      expect(stats.completionRate, 0.5);
      expect(
        stats.projectDistribution.map((entry) => entry.projectId),
        contains('p1'),
      );
      expect(stats.focusHoursSupported, isFalse);
      expect(service.calculate(todos, includeArchived: true).total, 3);
    },
  );

  test('range comparison is equal-length and the heatmap is a 7x24 matrix', () {
    final anchor = DateTime(2026, 8, 10, 12);
    final current = _todo('current').copyWith(
      createdAt: DateTime(2026, 8, 10, 9),
      updatedAt: DateTime(2026, 8, 10, 9),
    );
    final previous = _todo('previous').copyWith(
      createdAt: DateTime(2026, 8, 3, 9),
      updatedAt: DateTime(2026, 8, 3, 9),
    );
    final stats = const StatisticsService().calculate([
      current,
      previous,
    ], range: StatisticsRange.recent7(anchor));

    expect(stats.range!.dayCount, 7);
    expect(stats.range!.previous.dayCount, 7);
    expect(stats.heatmap, hasLength(7 * 24));
    expect(stats.comparison?.previousHasData, isTrue);
    expect(stats.daily, hasLength(7));
  });

  test('completed timestamps are the only heatmap event source', () {
    final utcBoundary = DateTime.utc(2026, 8, 10, 16, 30);
    final completed = _todo('completed', completed: true).copyWith(
      createdAt: DateTime(2026, 8, 9, 10),
      updatedAt: DateTime(2026, 8, 9, 10),
      completedAt: utcBoundary,
    );
    final openUpdated = _todo(
      'open-updated',
    ).copyWith(createdAt: DateTime(2026, 8, 9, 10), updatedAt: utcBoundary);
    final range = StatisticsRange.recent7(utcBoundary.toLocal());
    final stats = const StatisticsService().calculate([
      completed,
      openUpdated,
    ], range: range);
    final local = utcBoundary.toLocal();

    expect(stats.completed, 1);
    expect(stats.heatmapCount(local.weekday, local.hour), 1);
    expect(stats.eventBasis, contains('completedAt'));
  });

  test('no previous events produce a neutral comparison', () {
    final anchor = DateTime(2026, 8, 10);
    final stats = const StatisticsService().calculate([
      _todo('only').copyWith(createdAt: anchor, updatedAt: anchor),
    ], range: StatisticsRange.recent7(anchor));

    expect(stats.comparison?.isNeutral, isTrue);
    expect(stats.comparison?.percent(stats.total), isNull);
  });

  test('range metrics share the createdAt cohort at both boundaries', () {
    final anchor = DateTime(2026, 8, 10);
    final completedFromEarlier = _todo('earlier', completed: true).copyWith(
      createdAt: DateTime(2026, 7, 1),
      updatedAt: DateTime(2026, 8, 10),
      completedAt: DateTime(2026, 8, 10),
    );
    final newOpen = _todo('new').copyWith(createdAt: anchor, updatedAt: anchor);
    final completedOutsideRange = _todo('outside-completion', completed: true)
        .copyWith(
          createdAt: anchor,
          updatedAt: anchor,
          completedAt: DateTime(2026, 8, 20),
        );
    final completedInRange = _todo('in-range', completed: true).copyWith(
      createdAt: anchor,
      updatedAt: anchor,
      completedAt: anchor,
      projectId: 'p1',
    );
    final stats = const StatisticsService().calculate([
      completedFromEarlier,
      newOpen,
      completedOutsideRange,
      completedInRange,
    ], range: StatisticsRange.recent7(anchor));

    expect(stats.total, 3);
    expect(stats.completed, 1);
    expect(stats.completionRate, closeTo(1 / 3, 0.000001));
    expect(stats.daily.where((day) => day.completed == 1), hasLength(1));
    expect(
      stats.daily.fold<int>(0, (sum, day) => sum + day.total),
      stats.total,
    );
    expect(stats.byProject, isNotEmpty);
    expect(
      stats.byProject.every((project) => project.uncompleted >= 0),
      isTrue,
    );
  });
}
