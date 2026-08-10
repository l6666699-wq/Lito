import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_metrics.dart';
import '../../app/theme/project_palette.dart';
import '../../application/workspace_controller.dart';
import '../../domain/models/project.dart';
import '../../domain/services/statistics_service.dart';
import '../../icons/app_icons.dart';

/// Statistics is a derived view over the same Todo collection used by the
/// workspace. It owns only the selected display range and never writes a
/// snapshot.
class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key, required this.controller, this.now});

  final WorkspaceController controller;

  /// Optional clock seam for deterministic range rendering in widget tests.
  /// Production callers leave it null so the range follows the local clock.
  final DateTime Function()? now;

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  StatisticsRangeKind _rangeKind = StatisticsRangeKind.recent7;

  DateTime _anchor() => (widget.now ?? DateTime.now)().toLocal();

  StatisticsRange _range() {
    final anchor = _anchor();
    return switch (_rangeKind) {
      StatisticsRangeKind.recent7 => StatisticsRange.recent7(anchor),
      StatisticsRangeKind.recent30 => StatisticsRange.recent30(anchor),
      StatisticsRangeKind.currentMonth => StatisticsRange.currentMonth(anchor),
      StatisticsRangeKind.custom => StatisticsRange.recent7(anchor),
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        final range = _range();
        final stats = const StatisticsService().calculate(
          widget.controller.todos,
          projects: widget.controller.projects,
          range: range,
        );
        final colors = AppColors.of(context);
        return Padding(
          key: const ValueKey<String>('statistics-page'),
          padding: const EdgeInsets.fromLTRB(6, 0, 12, 14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border.all(color: colors.border),
              borderRadius: BorderRadius.circular(AppMetrics.normalRadius),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppMetrics.normalRadius),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(21, 20, 21, 28),
                child: _StatisticsBody(
                  stats: stats,
                  projects: widget.controller.projects,
                  onRangeChanged: (kind) => setState(() {
                    _rangeKind = kind;
                  }),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatisticsBody extends StatelessWidget {
  const _StatisticsBody({
    required this.stats,
    required this.projects,
    required this.onRangeChanged,
  });

  final TodoStatistics stats;
  final List<Project> projects;
  final ValueChanged<StatisticsRangeKind> onRangeChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1040;
        final medium = constraints.maxWidth >= 680;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StatisticsHeader(stats: stats, onRangeChanged: onRangeChanged),
            const SizedBox(height: 14),
            _KpiGrid(
              stats: stats,
              columns: wide
                  ? 4
                  : medium
                  ? 2
                  : 1,
            ),
            const SizedBox(height: 20),
            if (wide)
              SizedBox(
                height: 278,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 3, child: _TrendCard(stats: stats)),
                    const SizedBox(width: 18),
                    Expanded(
                      flex: 2,
                      child: _DistributionCard(
                        stats: stats,
                        projects: projects,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              _TrendCard(stats: stats, height: 278),
              const SizedBox(height: 18),
              _DistributionCard(stats: stats, projects: projects),
            ],
            const SizedBox(height: 20),
            if (wide)
              SizedBox(
                height: 282,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _RhythmCard(stats: stats)),
                    const SizedBox(width: 18),
                    Expanded(child: _FocusCard(stats: stats)),
                    const SizedBox(width: 18),
                    Expanded(
                      child: _TopProjectsCard(stats: stats, projects: projects),
                    ),
                  ],
                ),
              )
            else ...[
              _RhythmCard(stats: stats),
              const SizedBox(height: 18),
              _FocusCard(stats: stats),
              const SizedBox(height: 18),
              _TopProjectsCard(stats: stats, projects: projects),
            ],
          ],
        );
      },
    );
  }
}

class _StatisticsHeader extends StatelessWidget {
  const _StatisticsHeader({required this.stats, required this.onRangeChanged});

  final TodoStatistics stats;
  final ValueChanged<StatisticsRangeKind> onRangeChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final controls = _RangeControls(
          colors: colors,
          selected: stats.range?.kind ?? StatisticsRangeKind.recent7,
          onChanged: onRangeChanged,
        );
        final dateRange = _ReadOnlyDateRange(range: stats.range);
        final range = _rangeLabel(stats);
        final wide = constraints.maxWidth >= 1040;
        if (wide) {
          return Column(
            key: const ValueKey<String>('statistics-header'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    '统计',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  controls,
                  const SizedBox(width: 16),
                  dateRange,
                ],
              ),
              const SizedBox(height: 18),
              _StatisticsSummaryRow(range: range, colors: colors),
            ],
          );
        }

        return Column(
          key: const ValueKey<String>('statistics-header'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '统计',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [controls, dateRange],
              ),
            ),
            const SizedBox(height: 18),
            _StatisticsSummaryRow(range: range, colors: colors),
          ],
        );
      },
    );
  }
}

class _StatisticsSummaryRow extends StatelessWidget {
  const _StatisticsSummaryRow({required this.range, required this.colors});

  final String range;
  final AppColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 16,
      child: Row(
        children: [
          Expanded(
            child: Center(
              child: ColoredBox(
                color: colors.border,
                child: const SizedBox(height: 1),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              range,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(color: colors.textMuted, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyDateRange extends StatelessWidget {
  const _ReadOnlyDateRange({required this.range});

  final StatisticsRange? range;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final resolved = range;
    if (resolved == null) return const SizedBox.shrink();
    final from = _date(resolved.from);
    final to = _date(resolved.to);
    return Semantics(
      container: true,
      label: '统计日期范围：$from 至 $to',
      child: DecoratedBox(
        key: const ValueKey<String>('statistics-date-range'),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(AppMetrics.buttonRadius),
        ),
        child: SizedBox(
          height: 37,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 8),
                child: Text(
                  from,
                  key: const ValueKey<String>('statistics-range-from'),
                  style: TextStyle(color: colors.textMuted, fontSize: 11),
                ),
              ),
              Icon(AppIcons.chevronRight, size: 13, color: colors.textFaint),
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 12),
                child: Text(
                  to,
                  key: const ValueKey<String>('statistics-range-to'),
                  style: TextStyle(color: colors.textMuted, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RangeControls extends StatelessWidget {
  const _RangeControls({
    required this.colors,
    required this.selected,
    required this.onChanged,
  });

  final AppColorScheme colors;
  final StatisticsRangeKind selected;
  final ValueChanged<StatisticsRangeKind> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = <String>['最近 7 天', '最近 30 天', '本月', '自定义'];
    const kinds = <StatisticsRangeKind>[
      StatisticsRangeKind.recent7,
      StatisticsRangeKind.recent30,
      StatisticsRangeKind.currentMonth,
      StatisticsRangeKind.custom,
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(AppMetrics.buttonRadius),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < labels.length; index++)
              Semantics(
                button: true,
                enabled: kinds[index] != StatisticsRangeKind.custom,
                label: kinds[index] == StatisticsRangeKind.custom
                    ? '${labels[index]}（暂不可用）'
                    : labels[index],
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: kinds[index] == StatisticsRangeKind.custom
                      ? null
                      : () => onChanged(kinds[index]),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: selected == kinds[index]
                          ? colors.focusSoft
                          : colors.transparent,
                      border: selected == kinds[index]
                          ? Border.all(color: colors.focus)
                          : const Border.fromBorderSide(BorderSide.none),
                      borderRadius: BorderRadius.circular(
                        AppMetrics.buttonRadius,
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        selected == kinds[index] ? 14 : 13,
                        11,
                        index == labels.length - 1 ? 10 : 13,
                        11,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            labels[index],
                            style: TextStyle(
                              color: selected == kinds[index]
                                  ? colors.focus
                                  : colors.textMuted,
                              fontSize: 11,
                              fontWeight: selected == kinds[index]
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                          if (index == labels.length - 1) ...[
                            const SizedBox(width: 5),
                            Icon(
                              AppIcons.calendar,
                              size: 13,
                              color: colors.textMuted,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _rangeLabel(TodoStatistics stats) {
  final range = stats.range;
  if (range == null) return '统计时间：暂无数据';
  return '统计时间：${_date(range.from)} 至 ${_date(range.to)}（共 ${range.dayCount} 天）';
}

String _date(DateTime date) {
  String pad(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${pad(date.month)}-${pad(date.day)}';
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.stats, required this.columns});

  final TodoStatistics stats;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final dailyAverage = stats.daily.isEmpty
        ? 0.0
        : stats.completed / stats.daily.length;
    final comparison = stats.comparison;
    final cards = <Widget>[
      _KpiCard(
        key: const ValueKey<String>('statistics-kpi-total'),
        icon: AppIcons.layers,
        iconColor: const Color(0xFF5A79EF),
        iconBackground: const Color(0x145A79EF),
        label: '总任务数',
        value: '${stats.total}',
        detail: _comparisonDetail(
          comparison?.percent(stats.total),
          fallback: '暂无对比数据 · 当前统计范围',
        ),
        colors: colors,
      ),
      _KpiCard(
        key: const ValueKey<String>('statistics-kpi-completed'),
        icon: AppIcons.completed,
        iconColor: const Color(0xFF39B878),
        iconBackground: const Color(0x1439B878),
        label: '已完成',
        value: '${stats.completed}',
        detail:
            '${_comparisonDetail(comparison?.completedPercent(stats.completed), fallback: '暂无对比数据')} · 未完成 ${stats.uncompleted}',
        colors: colors,
      ),
      _KpiCard(
        key: const ValueKey<String>('statistics-kpi-rate'),
        icon: AppIcons.statistics,
        iconColor: const Color(0xFFF39A16),
        iconBackground: const Color(0x14F39A16),
        label: '完成率',
        value: stats.total == 0
            ? '暂无'
            : '${(stats.completionRate * 100).toStringAsFixed(1)}%',
        detail: _comparisonDetail(
          comparison?.ratePercent(stats.completionRate),
          fallback: '暂无对比数据 · 已完成 / 总任务',
        ),
        colors: colors,
      ),
      _KpiCard(
        key: const ValueKey<String>('statistics-kpi-average'),
        icon: AppIcons.recent,
        iconColor: const Color(0xFF9168DC),
        iconBackground: const Color(0x149168DC),
        label: '平均每日完成',
        value: stats.daily.isEmpty ? '暂无' : dailyAverage.toStringAsFixed(1),
        detail: stats.range == null
            ? '按有记录日期计算'
            : '按 ${stats.range!.dayCount} 天计算',
        colors: colors,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = 16.0;
        final width = (constraints.maxWidth - (columns - 1) * gap) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final card in cards) SizedBox(width: width, child: card),
          ],
        );
      },
    );
  }
}

String _comparisonDetail(double? change, {required String fallback}) {
  if (change == null || change.isNaN || change.isInfinite) return fallback;
  final percent = (change * 100).abs().toStringAsFixed(1);
  final prefix = change >= 0 ? '增加' : '减少';
  return '$prefix $percent% · 较上一周期';
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.label,
    required this.value,
    required this.detail,
    required this.colors,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String label;
  final String value;
  final String detail;
  final AppColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(AppMetrics.cardRadius),
      ),
      child: SizedBox(
        height: 104,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: iconBackground,
                  shape: BoxShape.circle,
                ),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: Icon(icon, color: iconColor, size: 28),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.text,
                        fontSize: 25,
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.textFaint, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.stats, this.height});

  final TodoStatistics stats;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return _StatisticsCard(
      key: const ValueKey<String>('statistics-trend-card'),
      title: '任务完成趋势',
      trailing: const _ChartSelectLabel(label: '按天'),
      height: height,
      child: stats.total == 0 || stats.daily.isEmpty
          ? const _ChartEmptyState(message: '暂无可展示的趋势数据')
          : Column(
              children: [
                const SizedBox(height: 10),
                Expanded(
                  child: CustomPaint(
                    key: const ValueKey<String>('statistics-trend-chart'),
                    painter: _TrendPainter(stats: stats, colors: colors),
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({required this.stats, required this.colors});

  final TodoStatistics stats;
  final AppColorScheme colors;

  @override
  void paint(Canvas canvas, Size size) {
    final daily = stats.daily;
    if (daily.isEmpty || size.width <= 0 || size.height <= 0) return;
    const left = 34.0;
    const right = 37.0;
    const top = 19.0;
    const bottom = 32.0;
    final plot = Rect.fromLTRB(
      left,
      top,
      math.max(left + 10, size.width - right).toDouble(),
      math.max(top + 10, size.height - bottom).toDouble(),
    );
    final maxValue = daily.fold<int>(1, (maximum, day) {
      return day.total > maximum ? day.total : maximum;
    });
    final gridPaint = Paint()
      ..color = colors.border.withValues(alpha: .68)
      ..strokeWidth = 1;
    final gridDashPaint = Paint()
      ..color = colors.border.withValues(alpha: .35)
      ..strokeWidth = 1;
    final gridRows = maxValue < 2
        ? 2
        : maxValue > 4
        ? 4
        : maxValue;
    for (var row = 0; row <= gridRows; row++) {
      final y = plot.bottom - plot.height * row / gridRows;
      _drawDashedLine(
        canvas,
        Offset(plot.left, y),
        Offset(plot.right, y),
        row == 0 ? gridPaint : gridDashPaint,
      );
      _drawLabel(
        canvas,
        '${(maxValue * row / gridRows).round()}',
        Offset(4, y - 7),
        colors.textFaint,
        10,
      );
    }
    final barWidth = math
        .min(27.0, plot.width / math.max(10, daily.length * 2))
        .toDouble();
    final points = <Offset>[];
    final ratePoints = <Offset>[];
    for (var index = 0; index < daily.length; index++) {
      final day = daily[index];
      final x = daily.length == 1
          ? plot.center.dx
          : plot.left + plot.width * index / (daily.length - 1);
      final totalHeight = plot.height * day.total / maxValue;
      final uncompletedHeight = plot.height * day.uncompleted / maxValue;
      final barRect = Rect.fromLTRB(
        x - barWidth / 2,
        plot.bottom - totalHeight,
        x + barWidth / 2,
        plot.bottom,
      );
      final barPaint = Paint()..color = const Color(0x336475F5);
      canvas.drawRRect(
        RRect.fromRectAndRadius(barRect, const Radius.circular(4)),
        barPaint,
      );
      if (uncompletedHeight > 0) {
        final completedRect = Rect.fromLTRB(
          x - barWidth / 2,
          plot.bottom - totalHeight,
          x + barWidth / 2,
          plot.bottom - uncompletedHeight,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(completedRect, const Radius.circular(4)),
          Paint()..color = const Color(0xFF6475F5),
        );
      }
      final completedY = plot.bottom - plot.height * day.completed / maxValue;
      points.add(Offset(x, completedY));
      final rateY = plot.bottom - plot.height * _completionRate(day);
      ratePoints.add(Offset(x, rateY));
      _drawLabel(
        canvas,
        _shortDate(day.date),
        Offset(x - 17, plot.bottom + 10),
        colors.textMuted,
        10,
      );
      if (day.completed > 0) {
        _drawLabel(
          canvas,
          '${day.completed}',
          Offset(x - 5, completedY - 20),
          const Color(0xFF5667F5),
          10,
        );
      }
    }
    final linePaint = Paint()
      ..color = const Color(0xFF5667F5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    _drawPolyline(canvas, points, linePaint);
    final ratePaint = Paint()
      ..color = const Color(0xFF9A6BF0)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    _drawDashedPolyline(canvas, ratePoints, ratePaint);
    final dotPaint = Paint()..color = const Color(0xFF5667F5);
    for (final point in points) {
      canvas.drawCircle(point, 3.5, Paint()..color = colors.surface);
      canvas.drawCircle(point, 2.2, dotPaint);
    }
    _drawLabel(canvas, '完成数', Offset(plot.left + 7, 0), colors.textMuted, 10);
    _drawLabel(
      canvas,
      '完成率',
      Offset(plot.right - 36, 0),
      const Color(0xFF9A6BF0),
      10,
    );
  }

  double _completionRate(DailyTodoStatistics day) {
    return day.total == 0 ? 0 : day.completed / day.total;
  }

  String _shortDate(DateTime value) =>
      '${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.stats != stats || oldDelegate.colors != colors;
}

class _DistributionCard extends StatelessWidget {
  const _DistributionCard({required this.stats, required this.projects});

  final TodoStatistics stats;
  final List<Project> projects;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final values = _projectValues(stats);
    return _StatisticsCard(
      key: const ValueKey<String>('statistics-distribution-card'),
      title: '项目分布',
      trailing: const _ChartSelectLabel(label: '按完成数'),
      child: values.isEmpty
          ? const _ChartEmptyState(message: '暂无项目分布数据')
          : LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 450;
                return Row(
                  children: [
                    SizedBox(
                      width: compact ? 135 : 160,
                      child: CustomPaint(
                        key: const ValueKey<String>('statistics-donut-chart'),
                        painter: _DonutPainter(
                          values: values,
                          colors: colors,
                          projects: projects,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DistributionLegend(
                        values: values,
                        projects: projects,
                        colors: colors,
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _DistributionLegend extends StatelessWidget {
  const _DistributionLegend({
    required this.values,
    required this.projects,
    required this.colors,
  });

  final List<ProjectTodoStatistics> values;
  final List<Project> projects;
  final AppColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final total = values.fold<int>(0, (sum, value) => sum + value.completed);
    final rows = values.take(6).toList(growable: false);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < rows.length; index++) ...[
          _LegendRow(
            value: rows[index],
            total: total,
            color: _projectColor(rows[index], projects, index),
            colors: colors,
          ),
          if (index != rows.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.value,
    required this.total,
    required this.color,
    required this.colors,
  });

  final ProjectTodoStatistics value;
  final int total;
  final Color color;
  final AppColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : value.completed / total;
    return Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: const SizedBox(width: 8, height: 8),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: Text(
            _displayProjectName(value.name),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.text, fontSize: 11),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 5,
              child: Stack(
                children: [
                  ColoredBox(color: colors.surfaceSubtle),
                  FractionallySizedBox(
                    widthFactor: ratio.clamp(0.0, 1.0).toDouble(),
                    child: ColoredBox(color: color),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 9),
        SizedBox(
          width: 22,
          child: Text(
            '${value.completed}',
            textAlign: TextAlign.right,
            style: TextStyle(color: colors.textMuted, fontSize: 10),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 31,
          child: Text(
            '${(ratio * 100).toStringAsFixed(1)}%',
            textAlign: TextAlign.right,
            style: TextStyle(color: colors.textFaint, fontSize: 10),
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.values,
    required this.colors,
    required this.projects,
  });

  final List<ProjectTodoStatistics> values;
  final AppColorScheme colors;
  final List<Project> projects;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<int>(0, (sum, value) => sum + value.completed);
    if (total == 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 12;
    final stroke = math.min(25.0, radius * .35);
    var start = -math.pi / 2;
    for (var index = 0; index < values.length; index++) {
      final value = values[index];
      final sweep = math.pi * 2 * value.completed / total;
      final paint = Paint()
        ..color = _projectColor(value, projects, index)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        math.max(0.01, sweep - .025).toDouble(),
        false,
        paint,
      );
      start += sweep;
    }
    final painter = TextPainter(
      text: TextSpan(
        text: '$total',
        style: TextStyle(
          color: colors.text,
          fontSize: 21,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, center - Offset(painter.width / 2, painter.height));
    final label = TextPainter(
      text: TextSpan(
        text: total == 0 ? '总任务' : '已完成',
        style: TextStyle(color: colors.textMuted, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, center + Offset(-label.width / 2, 3));
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.colors != colors;
}

class _RhythmCard extends StatelessWidget {
  const _RhythmCard({required this.stats});

  final TodoStatistics stats;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return _StatisticsCard(
      key: const ValueKey<String>('statistics-rhythm-card'),
      title: _rhythmTitle(stats),
      trailing: Semantics(
        label: '事件来源：${stats.eventBasis}',
        child: Text(
          '完成任务数',
          style: TextStyle(color: colors.textFaint, fontSize: 10),
        ),
      ),
      child:
          stats.heatmap.isEmpty ||
              stats.heatmap.every((cell) => cell.count == 0)
          ? const _ChartEmptyState(message: '暂无完成记录')
          : _RhythmGrid(stats: stats, colors: colors),
    );
  }
}

class _RhythmGrid extends StatelessWidget {
  const _RhythmGrid({required this.stats, required this.colors});

  final TodoStatistics stats;
  final AppColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final maximum = stats.heatmap.fold<int>(0, (max, cell) {
      return cell.count > max ? cell.count : max;
    });
    const hourLabels = <int>[0, 4, 8, 12, 16, 20, 23];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const SizedBox(width: 30),
            for (var hour = 0; hour < 24; hour++)
              Expanded(
                child: Text(
                  hourLabels.contains(hour) ? '$hour' : '',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.textFaint, fontSize: 9),
                ),
              ),
          ],
        ),
        const SizedBox(height: 7),
        Expanded(
          child: Column(
            children: [
              for (var weekday = 1; weekday <= 7; weekday++)
                Expanded(
                  child: Row(
                    children: [
                      SizedBox(
                        width: 30,
                        child: Text(
                          _weekdayLabel(weekday),
                          style: TextStyle(
                            color: colors.textFaint,
                            fontSize: 9,
                          ),
                        ),
                      ),
                      for (var hour = 0; hour < 24; hour++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(1.5),
                            child: DecoratedBox(
                              key: ValueKey<String>(
                                'statistics-heatmap-cell-$weekday-$hour',
                              ),
                              decoration: BoxDecoration(
                                color: _heatColor(
                                  colors,
                                  maximum == 0
                                      ? 0
                                      : stats.heatmapCount(weekday, hour) /
                                            maximum,
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FocusCard extends StatelessWidget {
  const _FocusCard({required this.stats});

  final TodoStatistics stats;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return _StatisticsCard(
      key: const ValueKey<String>('statistics-focus-card'),
      title: '今日专注时段',
      trailing: Text(
        '专注时长（小时）',
        style: TextStyle(color: colors.textFaint, fontSize: 10),
      ),
      child: stats.focusHoursSupported
          ? const _ChartEmptyState(message: '暂无专注时段记录')
          : const _ChartEmptyState(message: '当前版本未记录专注时长'),
    );
  }
}

class _TopProjectsCard extends StatelessWidget {
  const _TopProjectsCard({required this.stats, required this.projects});

  final TodoStatistics stats;
  final List<Project> projects;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final ranked =
        stats.byProject.where((value) => value.completed > 0).toList()
          ..sort((a, b) {
            final completed = b.completed.compareTo(a.completed);
            return completed == 0 ? b.total.compareTo(a.total) : completed;
          });
    final rows = ranked.take(5).toList(growable: false);
    final maximum = rows.fold<int>(0, (max, value) {
      return value.completed > max ? value.completed : max;
    });
    return _StatisticsCard(
      key: const ValueKey<String>('statistics-top-projects-card'),
      title: '完成最多的项目',
      trailing: _ChartSelectLabel(label: _periodLabel(stats)),
      child: rows.isEmpty
          ? const _ChartEmptyState(message: '暂无项目完成记录')
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var index = 0; index < rows.length; index++) ...[
                  _RankingRow(
                    rank: index + 1,
                    value: rows[index],
                    maximum: maximum,
                    color: _projectColor(rows[index], projects, index),
                    colors: colors,
                  ),
                  if (index != rows.length - 1) const SizedBox(height: 13),
                ],
              ],
            ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({
    required this.rank,
    required this.value,
    required this.maximum,
    required this.color,
    required this.colors,
  });

  final int rank;
  final ProjectTodoStatistics value;
  final int maximum;
  final Color color;
  final AppColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final ratio = maximum == 0 ? 0.0 : value.completed / maximum;
    return Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: color.withValues(alpha: .9),
            borderRadius: BorderRadius.circular(3),
          ),
          child: SizedBox(
            width: 19,
            height: 19,
            child: Center(
              child: Text(
                '$rank',
                style: const TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 9),
        SizedBox(
          width: 62,
          child: Text(
            _displayProjectName(value.name),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.text, fontSize: 11),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 5,
              child: Stack(
                children: [
                  ColoredBox(color: colors.surfaceSubtle),
                  FractionallySizedBox(
                    widthFactor: ratio.clamp(0.0, 1.0).toDouble(),
                    child: ColoredBox(color: color),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 25,
          child: Text(
            '${value.completed}',
            textAlign: TextAlign.right,
            style: TextStyle(color: colors.textMuted, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _StatisticsCard extends StatelessWidget {
  const _StatisticsCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.height,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              trailing == null ? const SizedBox.shrink() : trailing!,
            ],
          ),
          const SizedBox(height: 10),
          Expanded(child: child),
        ],
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(AppMetrics.cardRadius),
      ),
      child: SizedBox(height: height ?? 250, child: content),
    );
  }
}

class _ChartSelectLabel extends StatelessWidget {
  const _ChartSelectLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(AppMetrics.smallRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(color: colors.textMuted, fontSize: 10),
            ),
            const SizedBox(width: 5),
            Icon(AppIcons.chevronDown, size: 12, color: colors.textFaint),
          ],
        ),
      ),
    );
  }
}

class _ChartEmptyState extends StatelessWidget {
  const _ChartEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Center(
      key: const ValueKey<String>('statistics-empty-state'),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: colors.textFaint, fontSize: 12),
      ),
    );
  }
}

List<ProjectTodoStatistics> _projectValues(TodoStatistics stats) {
  final values = stats.byProject.where((value) => value.completed > 0).toList();
  values.sort((a, b) => b.completed.compareTo(a.completed));
  return values;
}

Color _projectColor(
  ProjectTodoStatistics value,
  List<Project> projects,
  int index,
) {
  if (value.projectId == null) return const Color(0xFF6E77F4);
  for (final project in projects) {
    if (project.id == value.projectId) {
      return ProjectPalette.resolve(project.colorKey).accent;
    }
  }
  const fallback = <Color>[
    Color(0xFF6475F5),
    Color(0xFF3DBD82),
    Color(0xFFF39A16),
    Color(0xFF9568E4),
    Color(0xFF36AFC7),
    Color(0xFFE9B22C),
  ];
  return fallback[index % fallback.length];
}

String _displayProjectName(String name) => name == 'Inbox' ? '收集箱' : name;

String _periodLabel(TodoStatistics stats) {
  const defaultLabel = '本周';
  final dayCount = stats.range?.dayCount;
  return dayCount == null || dayCount == 7 ? defaultLabel : '$dayCount天';
}

String _rhythmTitle(TodoStatistics stats) {
  const defaultTitle = '本周完成节奏';
  final dayCount = stats.range?.dayCount;
  return dayCount == null || dayCount == 7 ? defaultTitle : '$dayCount天完成节奏';
}

String _weekdayLabel(int weekday) {
  const labels = <String>['一', '二', '三', '四', '五', '六', '日'];
  return '周${labels[weekday - 1]}';
}

Color _heatColor(AppColorScheme colors, double amount) {
  final clamped = amount.clamp(0.0, 1.0).toDouble();
  return Color.lerp(colors.surfaceSubtle, colors.focus, clamped) ??
      colors.focus;
}

void _drawLabel(
  Canvas canvas,
  String text,
  Offset offset,
  Color color,
  double fontSize,
) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(color: color, fontSize: fontSize),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(canvas, offset);
}

void _drawPolyline(Canvas canvas, List<Offset> points, Paint paint) {
  if (points.length < 2) return;
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  for (final point in points.skip(1)) {
    path.lineTo(point.dx, point.dy);
  }
  canvas.drawPath(path, paint);
}

void _drawDashedPolyline(Canvas canvas, List<Offset> points, Paint paint) {
  if (points.length < 2) return;
  for (var index = 0; index < points.length - 1; index++) {
    _drawDashedLine(
      canvas,
      points[index],
      points[index + 1],
      paint,
      dash: 3,
      gap: 4,
    );
  }
}

void _drawDashedLine(
  Canvas canvas,
  Offset start,
  Offset end,
  Paint paint, {
  double dash = 4,
  double gap = 4,
}) {
  final delta = end - start;
  final distance = delta.distance;
  if (distance == 0) return;
  final direction = delta / distance;
  var travelled = 0.0;
  while (travelled < distance) {
    final segmentStart = start + direction * travelled;
    final segmentEnd =
        start + direction * math.min(distance, travelled + dash).toDouble();
    canvas.drawLine(segmentStart, segmentEnd, paint);
    travelled += dash + gap;
  }
}
