import '../models/project.dart';
import '../models/todo_item.dart';

enum StatisticsRangeKind { recent7, recent30, currentMonth, custom }

/// An inclusive, local-calendar range used by the statistics view.
class StatisticsRange {
  const StatisticsRange({
    required this.kind,
    required this.from,
    required this.to,
  });

  factory StatisticsRange.recent7(DateTime anchor) =>
      _fromDays(StatisticsRangeKind.recent7, anchor, 7);

  factory StatisticsRange.recent30(DateTime anchor) =>
      _fromDays(StatisticsRangeKind.recent30, anchor, 30);

  factory StatisticsRange.currentMonth(DateTime anchor) {
    final local = _localDay(anchor.toLocal());
    final first = DateTime(local.year, local.month);
    final last = DateTime(local.year, local.month + 1, 0);
    return StatisticsRange(
      kind: StatisticsRangeKind.currentMonth,
      from: first,
      to: last,
    );
  }

  factory StatisticsRange.custom(DateTime from, DateTime to) {
    final start = _localDay(from.toLocal());
    final end = _localDay(to.toLocal());
    return end.isBefore(start)
        ? StatisticsRange(
            kind: StatisticsRangeKind.custom,
            from: end,
            to: start,
          )
        : StatisticsRange(
            kind: StatisticsRangeKind.custom,
            from: start,
            to: end,
          );
  }

  final StatisticsRangeKind kind;
  final DateTime from;
  final DateTime to;

  int get dayCount => to.difference(from).inDays + 1;

  StatisticsRange get previous {
    final days = dayCount;
    final previousTo = from.subtract(const Duration(days: 1));
    return StatisticsRange(
      kind: kind,
      from: previousTo.subtract(Duration(days: days - 1)),
      to: previousTo,
    );
  }

  bool contains(DateTime value) {
    final day = _localDay(value.toLocal());
    return !day.isBefore(from) && !day.isAfter(to);
  }

  List<DateTime> get days => <DateTime>[
    for (var offset = 0; offset < dayCount; offset++)
      from.add(Duration(days: offset)),
  ];

  static StatisticsRange _fromDays(
    StatisticsRangeKind kind,
    DateTime anchor,
    int count,
  ) {
    final end = _localDay(anchor.toLocal());
    return StatisticsRange(
      kind: kind,
      from: end.subtract(Duration(days: count - 1)),
      to: end,
    );
  }
}

class DailyTodoStatistics {
  const DailyTodoStatistics({
    required this.date,
    required this.completed,
    required this.uncompleted,
  });

  final DateTime date;
  final int completed;
  final int uncompleted;

  int get total => completed + uncompleted;
}

class HeatmapCell {
  const HeatmapCell({
    required this.weekday,
    required this.hour,
    required this.count,
  });

  /// ISO weekday: Monday = 1, Sunday = 7.
  final int weekday;
  final int hour;
  final int count;
}

class ProjectTodoStatistics {
  const ProjectTodoStatistics({
    required this.projectId,
    required this.name,
    required this.total,
    required this.completed,
  });

  final String? projectId;
  final String name;
  final int total;
  final int completed;

  int get uncompleted => total - completed;
}

class StatisticsComparison {
  const StatisticsComparison({
    required this.previousHasData,
    required this.previousTotal,
    required this.previousCompleted,
  });

  final bool previousHasData;
  final int previousTotal;
  final int previousCompleted;

  bool get isNeutral => !previousHasData;

  int difference(int current) => current - previousTotal;

  double? percent(int current) {
    if (isNeutral || previousTotal == 0) return null;
    return (current - previousTotal) / previousTotal;
  }

  double? completedPercent(int current) {
    if (isNeutral || previousCompleted == 0) return null;
    return (current - previousCompleted) / previousCompleted;
  }

  double? ratePercent(double currentRate) {
    if (isNeutral || previousTotal == 0) return null;
    final previousRate = previousCompleted / previousTotal;
    if (previousRate == 0) return null;
    return (currentRate - previousRate) / previousRate;
  }
}

/// Purely derived statistics. No snapshot or focus-hour value is persisted.
class TodoStatistics {
  const TodoStatistics({
    required this.total,
    required this.completed,
    required this.completionRate,
    required this.daily,
    required this.byProject,
    this.range,
    this.comparison,
    this.heatmap = const <HeatmapCell>[],
    this.focusHoursSupported = false,
    this.focusHours,
    this.eventBasis =
        '完成时间（completedAt），否则更新时间（updatedAt），否则创建时间（createdAt）；每个任务计 1 次事件',
  });

  final int total;
  final int completed;
  final double completionRate;
  final List<DailyTodoStatistics> daily;
  final List<ProjectTodoStatistics> byProject;
  final StatisticsRange? range;
  final StatisticsComparison? comparison;
  final List<HeatmapCell> heatmap;
  final bool focusHoursSupported;
  final double? focusHours;
  final String eventBasis;

  int get uncompleted => total - completed;

  List<DailyTodoStatistics> get dailyStats => daily;

  List<ProjectTodoStatistics> get projectDistribution => byProject;

  List<ProjectTodoStatistics> get projectStats => byProject;

  String get focusHoursStatus =>
      focusHoursSupported ? 'supported' : 'unsupported';

  int heatmapCount(int weekday, int hour) {
    for (final cell in heatmap) {
      if (cell.weekday == weekday && cell.hour == hour) return cell.count;
    }
    return 0;
  }
}

class StatisticsService {
  const StatisticsService();

  TodoStatistics calculate(
    Iterable<TodoItem> todos, {
    Iterable<Project> projects = const <Project>[],
    DateTime? from,
    DateTime? to,
    StatisticsRange? range,
    DateTime? now,
    bool filterByRange = true,
    bool includeArchived = false,
  }) {
    final resolvedRange =
        range ??
        (from != null || to != null
            ? StatisticsRange.custom(from ?? to!, to ?? from!)
            : null);
    final source = todos.toList(growable: false);
    final current = _calculateWindow(
      source,
      projects,
      range: resolvedRange,
      filterByRange: filterByRange,
      includeArchived: includeArchived,
    );
    if (resolvedRange == null || !filterByRange) {
      return TodoStatistics(
        total: current.total,
        completed: current.completed,
        completionRate: current.completionRate,
        daily: current.daily,
        byProject: current.byProject,
        range: resolvedRange,
        heatmap: current.heatmap,
        focusHoursSupported: current.focusHoursSupported,
        focusHours: current.focusHours,
        eventBasis: current.eventBasis,
      );
    }

    final previous = _calculateWindow(
      source,
      projects,
      range: resolvedRange.previous,
      filterByRange: true,
      includeArchived: includeArchived,
    );
    return TodoStatistics(
      total: current.total,
      completed: current.completed,
      completionRate: current.completionRate,
      daily: current.daily,
      byProject: current.byProject,
      range: resolvedRange,
      comparison: StatisticsComparison(
        previousHasData: previous.total > 0,
        previousTotal: previous.total,
        previousCompleted: previous.completed,
      ),
      heatmap: current.heatmap,
      focusHoursSupported: current.focusHoursSupported,
      focusHours: current.focusHours,
      eventBasis: current.eventBasis,
    );
  }

  TodoStatistics aggregate(
    Iterable<TodoItem> todos, {
    Iterable<Project> projects = const <Project>[],
    DateTime? from,
    DateTime? to,
    StatisticsRange? range,
    DateTime? now,
    bool filterByRange = true,
    bool includeArchived = false,
  }) => calculate(
    todos,
    projects: projects,
    from: from,
    to: to,
    range: range,
    now: now,
    filterByRange: filterByRange,
    includeArchived: includeArchived,
  );

  TodoStatistics compute(
    Iterable<TodoItem> todos, {
    Iterable<Project> projects = const <Project>[],
    DateTime? from,
    DateTime? to,
    StatisticsRange? range,
    DateTime? now,
    bool filterByRange = true,
    bool includeArchived = false,
  }) => calculate(
    todos,
    projects: projects,
    from: from,
    to: to,
    range: range,
    now: now,
    filterByRange: filterByRange,
    includeArchived: includeArchived,
  );

  TodoStatistics _calculateWindow(
    List<TodoItem> todos,
    Iterable<Project> projects, {
    required StatisticsRange? range,
    required bool filterByRange,
    required bool includeArchived,
  }) {
    final projectById = <String, Project>{
      for (final project in projects) project.id: project,
    };
    final available = todos
        .where((todo) => includeArchived || !todo.archived)
        .toList(growable: false);
    final created = available
        .where(
          (todo) =>
              !filterByRange || range == null || range.contains(todo.createdAt),
        )
        .toList(growable: false);
    final completedEvents = created
        .where(
          (todo) =>
              todo.completed &&
              todo.completedAt != null &&
              (!filterByRange ||
                  range == null ||
                  range.contains(todo.completedAt!)),
        )
        .toList(growable: false);
    final daily = _daily(created, range, filterByRange);
    final byProject = _projects(created, completedEvents, projectById);
    final heatmap = _heatmap(available, range, filterByRange);
    return TodoStatistics(
      total: created.length,
      completed: completedEvents.length,
      completionRate: created.isEmpty
          ? 0
          : completedEvents.length / created.length,
      daily: daily,
      byProject: byProject,
      range: range,
      heatmap: heatmap,
      focusHoursSupported: false,
    );
  }

  List<DailyTodoStatistics> _daily(
    List<TodoItem> todos,
    StatisticsRange? range,
    bool filterByRange,
  ) {
    final buckets = <DateTime, List<int>>{};
    if (range != null) {
      for (final day in range.days) {
        buckets[day] = <int>[0, 0];
      }
    }
    for (final todo in todos) {
      final completedAt = todo.completedAt;
      final completionInRange =
          todo.completed &&
          completedAt != null &&
          (!filterByRange || range == null || range.contains(completedAt));
      final eventDate = completionInRange ? completedAt : todo.createdAt;
      final date = _localDay(eventDate.toLocal());
      if (filterByRange && range != null && !range.contains(date)) continue;
      final bucket = buckets.putIfAbsent(date, () => <int>[0, 0]);
      bucket[completionInRange ? 0 : 1]++;
    }
    final daily = <DailyTodoStatistics>[
      for (final entry in buckets.entries)
        DailyTodoStatistics(
          date: entry.key,
          completed: entry.value[0],
          uncompleted: entry.value[1],
        ),
    ]..sort((a, b) => a.date.compareTo(b.date));
    return List.unmodifiable(daily);
  }

  List<ProjectTodoStatistics> _projects(
    List<TodoItem> created,
    List<TodoItem> completedEvents,
    Map<String, Project> projectById,
  ) {
    final projectMap = <String?, List<int>>{};
    for (final todo in created) {
      final bucket = projectMap.putIfAbsent(todo.projectId, () => <int>[0, 0]);
      bucket[0]++;
    }
    for (final todo in completedEvents) {
      final bucket = projectMap.putIfAbsent(todo.projectId, () => <int>[0, 0]);
      bucket[1]++;
    }
    final values = <ProjectTodoStatistics>[
      for (final entry in projectMap.entries)
        ProjectTodoStatistics(
          projectId: entry.key,
          name: entry.key == null
              ? '收集箱'
              : projectById[entry.key!]?.name ?? entry.key!,
          total: entry.value[0],
          completed: entry.value[1],
        ),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return List.unmodifiable(values);
  }

  List<HeatmapCell> _heatmap(
    List<TodoItem> todos,
    StatisticsRange? range,
    bool filterByRange,
  ) {
    final buckets = <int, int>{};
    for (final todo in todos) {
      final event = _heatmapEvent(todo);
      if (event == null) continue;
      final local = event.toLocal();
      if (filterByRange && range != null && !range.contains(local)) continue;
      final key = (local.weekday - 1) * 24 + local.hour;
      buckets[key] = (buckets[key] ?? 0) + 1;
    }
    if (range == null) {
      return List.unmodifiable(<HeatmapCell>[
        for (final entry in buckets.entries)
          HeatmapCell(
            weekday: entry.key ~/ 24 + 1,
            hour: entry.key % 24,
            count: entry.value,
          ),
      ]);
    }
    return List.unmodifiable(<HeatmapCell>[
      for (var weekday = 1; weekday <= 7; weekday++)
        for (var hour = 0; hour < 24; hour++)
          HeatmapCell(
            weekday: weekday,
            hour: hour,
            count: buckets[(weekday - 1) * 24 + hour] ?? 0,
          ),
    ]);
  }

  DateTime? _heatmapEvent(TodoItem todo) {
    if (todo.completed && todo.completedAt != null) return todo.completedAt;
    if (todo.updatedAt != todo.createdAt) return todo.updatedAt;
    return todo.createdAt;
  }
}

DateTime _localDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);
