import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:litetodo/application/workspace_controller.dart';
import 'package:litetodo/presentation/statistics/statistics_page.dart';

final _fixedNow = DateTime(2026, 8, 10, 12);

WorkspaceController _controller() {
  return WorkspaceController(nowProvider: () => _fixedNow);
}

Widget _host(WorkspaceController controller, {DateTime? now}) {
  final resolvedNow = now ?? _fixedNow;
  return Directionality(
    textDirection: TextDirection.ltr,
    child: StatisticsPage(controller: controller, now: () => resolvedNow),
  );
}

Finder _totalValue(String value) {
  return find.descendant(
    of: find.byKey(const ValueKey<String>('statistics-kpi-total')),
    matching: find.text(value),
  );
}

void main() {
  testWidgets('statistics renders real KPI and chart sections', (tester) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    final completed = controller.createRootTodo('统计页完成任务');
    controller.toggleTodoCompleted(completed.id);
    await tester.pumpWidget(_host(controller));

    expect(
      find.byKey(const ValueKey<String>('statistics-page')),
      findsOneWidget,
    );
    expect(find.text('统计'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('statistics-kpi-total')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('statistics-trend-chart')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('statistics-donut-chart')),
      findsOneWidget,
    );
    expect(find.text('当前版本未记录专注时长'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('statistics shows honest empty state after deleting all todos', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    for (final todo in controller.todos.where(
      (todo) => todo.parentId == null,
    )) {
      controller.deleteTodo(todo.id);
    }
    await tester.pumpWidget(_host(controller));

    expect(find.text('暂无可展示的趋势数据'), findsOneWidget);
    expect(find.text('暂无项目分布数据'), findsOneWidget);
    expect(find.text('暂无完成记录'), findsOneWidget);
    expect(find.text('暂无项目完成记录'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('statistics ranges use the injected local now for old data', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller, now: _fixedNow));

    expect(find.text('统计时间：2026-08-04 至 2026-08-10（共 7 天）'), findsOneWidget);
    expect(_totalValue('0'), findsOneWidget);

    await tester.tap(find.text('本月'));
    await tester.pump();
    expect(find.text('统计时间：2026-08-01 至 2026-08-31（共 31 天）'), findsOneWidget);
    expect(_totalValue('0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'wide statistics header shows a read-only range and keeps KPI offset',
    (tester) async {
      tester.view.physicalSize = const Size(1672, 941);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final controller = _controller();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(controller, now: _fixedNow));

      final header = tester.getRect(
        find.byKey(const ValueKey<String>('statistics-header')),
      );
      final kpi = tester.getRect(
        find.byKey(const ValueKey<String>('statistics-kpi-total')),
      );
      expect(header.height, closeTo(71, 1));
      expect(kpi.top - header.bottom, closeTo(14, 1));
      expect(kpi.top - header.top, closeTo(85, 1));

      expect(
        tester.getRect(
          find.byKey(const ValueKey<String>('statistics-date-range')),
        ),
        isNotNull,
      );
      expect(
        find.byKey(const ValueKey<String>('statistics-range-from')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('statistics-range-to')),
        findsOneWidget,
      );
      expect(find.text('2026-08-04'), findsOneWidget);
      expect(find.text('2026-08-10'), findsOneWidget);

      await tester.tap(find.text('最近 30 天'));
      await tester.pump();
      expect(find.text('2026-07-12'), findsOneWidget);
      expect(find.text('2026-08-10'), findsOneWidget);

      await tester.tap(find.text('本月'));
      await tester.pump();
      expect(find.text('2026-08-01'), findsOneWidget);
      expect(find.text('2026-08-31'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('statistics-date-range')),
      );
      await tester.pump();
      expect(find.text('统计时间：2026-08-01 至 2026-08-31（共 31 天）'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('statistics updates when the workspace aggregate changes', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller));
    expect(_totalValue('0'), findsOneWidget);

    controller.createRootTodo('统计页测试任务');
    await tester.pump();

    expect(_totalValue('1'), findsOneWidget);
    expect(find.textContaining('统计时间：'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('range controls drive the real statistics range and heatmap', (
    tester,
  ) async {
    final controller = _controller();
    addTearDown(controller.dispose);
    final completed = controller.createRootTodo('节奏测试任务');
    controller.toggleTodoCompleted(completed.id);
    await tester.pumpWidget(_host(controller));

    expect(
      find.byKey(const ValueKey<String>('statistics-heatmap-cell-1-0')),
      findsOneWidget,
    );
    await tester.tap(find.text('最近 30 天'));
    await tester.pump();
    expect(find.textContaining('（共 30 天）'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('statistics-heatmap-cell-7-23')),
      findsOneWidget,
    );

    await tester.tap(find.text('自定义'));
    await tester.pump();
    expect(find.textContaining('（共 30 天）'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in const <Size>[
    Size(1672, 941),
    Size(860, 620),
    Size(680, 460),
  ]) {
    testWidgets('statistics fits ${size.width}x${size.height}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final controller = _controller();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(controller));
      expect(tester.takeException(), isNull);
    });
  }
}
