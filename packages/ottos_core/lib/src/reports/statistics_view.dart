import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/statistics.dart';
import '../theme/ottos_colors.dart';
import '../utils/formatters.dart';
import '../widgets/async_view.dart';
import 'report_texts.dart';
import 'report_widgets.dart';
import 'statistics_cubit.dart';

const _bar = OttosColors.teal;
const _otherBar = Color(0xFF9A9DA8);
const _axis = Color(0xFF9A9DA8);
const _muted = Color(0xFF44474E);

/// The period chooser of the statistics: segments on wide screens, chips that
/// scroll on a phone. «Personalizado…» opens a date range picker.
class StatisticsPeriodPicker extends StatelessWidget {
  const StatisticsPeriodPicker({super.key, required this.compact});

  final bool compact;

  static const _labels = {
    StatisticsPeriod.currentMonth: ReportTexts.periodCurrentMonth,
    StatisticsPeriod.previousMonth: ReportTexts.periodPreviousMonth,
    StatisticsPeriod.lastThreeMonths: ReportTexts.periodLastThreeMonths,
    StatisticsPeriod.custom: ReportTexts.periodCustom,
  };

  Future<void> _choose(BuildContext context, StatisticsPeriod period) async {
    final cubit = context.read<StatisticsCubit>();
    if (period != StatisticsPeriod.custom) return cubit.select(period);
    final today = cubit.today;
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: today,
      initialDateRange: DateTimeRange(start: cubit.state.from, end: cubit.state.to),
      helpText: ReportTexts.periodCustom,
    );
    if (range == null || !context.mounted) return;
    if (range.end.difference(range.start).inDays + 1 > StatisticsCubit.maxDays) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(ReportTexts.tooLongPeriod)));
      return;
    }
    await cubit.custom(range.start, range.end);
  }

  @override
  Widget build(BuildContext context) {
    final selected = context.select((StatisticsCubit cubit) => cubit.state.period);
    if (compact) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final MapEntry(key: period, value: label) in _labels.entries) ...[
              if (period != StatisticsPeriod.currentMonth) const SizedBox(width: 8),
              ChoiceChip(label: Text(label), selected: selected == period, onSelected: (_) => _choose(context, period)),
            ],
          ],
        ),
      );
    }
    return SegmentedButton<StatisticsPeriod>(
      segments: [
        for (final MapEntry(key: period, value: label) in _labels.entries)
          ButtonSegment(value: period, label: Text(label)),
      ],
      selected: {selected},
      // The custom one again opens the picker, to change its dates.
      emptySelectionAllowed: false,
      onSelectionChanged: (periods) => _choose(context, periods.first),
    );
  }
}

/// "Del 1 ago 2026 al 23 oct 2026 · por fecha de registro · …".
String statisticsPeriodText(StatisticsState state) => ReportTexts.statisticsPeriod(
  ReportTexts.date(state.from),
  ReportTexts.date(state.to),
  state.statistics?.businessCurrency ?? 'USD',
);

/// The statistics of the chosen period: totals, sales by week and by day of
/// the week, average amount, remittances by municipality and on the house.
/// Charts side by side on wide screens, one under another on a phone
/// ([compact]). Reads [StatisticsCubit].
class StatisticsView extends StatelessWidget {
  const StatisticsView({super.key, required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StatisticsCubit, StatisticsState>(
      builder: (context, state) {
        final cubit = context.read<StatisticsCubit>();
        return switch (state.status) {
          StatisticsStatus.loading => const SizedBox(height: 320, child: LoadingView()),
          StatisticsStatus.unavailable => const ReportNotice.unavailable(),
          StatisticsStatus.failure => SizedBox(
            height: 320,
            child: ErrorView(message: state.error ?? '', onRetry: cubit.load),
          ),
          StatisticsStatus.success => _Charts(state: state, compact: compact),
        };
      },
    );
  }
}

class _Charts extends StatelessWidget {
  const _Charts({required this.state, required this.compact});

  final StatisticsState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final statistics = state.statistics!;
    final totals = statistics.totals;
    final currency = statistics.businessCurrency;
    String money(double value) => Formatters.money(value, currency);
    final empty = totals.remittances == 0;
    final gap = compact ? 12.0 : 16.0;
    final average = _Average(statistics: statistics, previous: state.previous, compact: compact);
    final cards = [
      ReportFigure(
        label: ReportTexts.remittances,
        value: '${totals.remittances}',
        help: ReportTexts.deliveriesAndPickups(totals.deliveries, totals.pickups),
      ),
      ReportFigure(
        label: ReportTexts.averageAmount,
        value: money(totals.averageAmount),
        trailing: statistics.hasFewData && !empty ? const _FewDataChip() : null,
      ),
      ReportFigure(
        label: ReportTexts.collectedCard,
        value: money(totals.collected),
        help: ReportTexts.collectedCardHelp,
      ),
      ReportFigure(
        label: ReportTexts.earnings,
        value: money(totals.fees),
        help: ReportTexts.earningsHelpShort,
        highlight: true,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (statistics.hasFewData && !empty) ...[_FewDataBanner(state: state), SizedBox(height: gap)],
        _Grid(columns: compact ? 2 : 4, spacing: compact ? 8 : 12, children: cards),
        SizedBox(height: gap),
        _WeekSection(statistics: statistics, compact: compact),
        SizedBox(height: gap),
        _Pair(
          compact: compact,
          gap: gap,
          first: _DaySection(statistics: statistics, compact: compact),
          second: average,
        ),
        SizedBox(height: gap),
        _Pair(
          compact: compact,
          gap: gap,
          first: _MunicipalitySection(statistics: statistics, compact: compact),
          second: _OnTheHouseSection(statistics: statistics, compact: compact),
        ),
      ],
    );
  }
}

/// Two sections side by side when there is room, else one under the other.
class _Pair extends StatelessWidget {
  const _Pair({required this.compact, required this.gap, required this.first, required this.second});

  final bool compact;
  final double gap;
  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (compact || constraints.maxWidth < 860) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              first,
              SizedBox(height: gap),
              second,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            SizedBox(width: gap),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}

/// [children] in rows of [columns] (fewer on narrow screens), the same width.
class _Grid extends StatelessWidget {
  const _Grid({required this.columns, required this.spacing, required this.children});

  final int columns;
  final double spacing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fit = math.max(1, math.min(columns, (constraints.maxWidth / 170).floor()));
        final width = (constraints.maxWidth - spacing * (fit - 1)) / fit;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [for (final child in children) SizedBox(width: width, child: child)],
        );
      },
    );
  }
}

class _FewDataChip extends StatelessWidget {
  const _FewDataChip();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(color: const Color(0xFFECEEF2), borderRadius: BorderRadius.circular(12)),
    child: const Text(
      ReportTexts.fewDataChip,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _muted),
    ),
  );
}

class _FewDataBanner extends StatelessWidget {
  const _FewDataBanner({required this.state});

  final StatisticsState state;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF5A3A00);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: const Color(0xFFFFF4DC), borderRadius: BorderRadius.circular(12)),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Icon(Icons.info_outline, color: color),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Text(
              ReportTexts.fewData(state.statistics!.totals.remittances),
              style: const TextStyle(color: color),
            ),
          ),
          if (state.period == StatisticsPeriod.currentMonth)
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: const BorderSide(color: color),
              ),
              onPressed: () => context.read<StatisticsCubit>().select(StatisticsPeriod.previousMonth),
              child: const Text(ReportTexts.seePreviousMonth),
            ),
        ],
      ),
    );
  }
}

/// A notice in place of a chart without data.
class _NoData extends StatelessWidget {
  const _NoData({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) =>
      ReportNotice(title: ReportTexts.noDataFor(title), message: ReportTexts.noDataHelp);
}

/// Vertical bars with a label under each, the values of some above them and
/// a tooltip with the figures.
class _Bars extends StatelessWidget {
  const _Bars({
    required this.values,
    required this.labels,
    required this.tips,
    required this.valueLabels,
    required this.height,
    required this.maxBarWidth,
    required this.semantics,
    this.gap = 2,
  });

  final List<double> values;
  final List<String> labels;
  final List<String> tips;
  final List<String> valueLabels;
  final double height;
  final double maxBarWidth;
  final double gap;
  final String semantics;

  @override
  Widget build(BuildContext context) {
    final max = values.fold<double>(0, math.max);
    const labelStyle = TextStyle(fontSize: 10.5, color: Color(0xFF6B6F7B));
    return Semantics(
      label: semantics,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: height,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _axis)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < values.length; i++) ...[
                  if (i > 0) SizedBox(width: gap),
                  Expanded(
                    child: Tooltip(
                      message: tips[i],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (valueLabels[i].isNotEmpty)
                            Text(
                              valueLabels[i],
                              maxLines: 1,
                              overflow: TextOverflow.visible,
                              softWrap: false,
                              style: const TextStyle(fontSize: 11, color: _muted),
                            ),
                          const SizedBox(height: 2),
                          Container(
                            constraints: BoxConstraints(maxWidth: maxBarWidth),
                            height: max == 0 ? 0 : math.max(values[i] > 0 ? 2.0 : 0.0, values[i] / max * (height - 22)),
                            decoration: const BoxDecoration(
                              color: _bar,
                              borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (var i = 0; i < labels.length; i++) ...[
                if (i > 0) SizedBox(width: gap),
                Expanded(
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    softWrap: false,
                    style: labelStyle,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// The label of each week: its first day, with the month when it starts one
/// ("4 ago", "11", "18", "25", "1 sep"…).
List<String> _weekLabels(List<StatisticsGroup> weeks) {
  final labels = <String>[];
  int? lastMonth;
  for (final week in weeks) {
    final from = week.from;
    if (from == null) {
      labels.add('');
      continue;
    }
    labels.add(lastMonth == from.month ? '${from.day}' : ReportTexts.shortDate(from));
    lastMonth = from.month;
  }
  // Many weeks: only the month changes, so the labels never overlap.
  if (weeks.length > 16) {
    return [for (final label in labels) label.contains(' ') ? label : ''];
  }
  return labels;
}

/// The values worth writing above the bars: the highest and the last.
List<String> _peakLabels(List<double> values, String Function(double) format) {
  if (values.isEmpty) return const [];
  final max = values.fold<double>(0, math.max);
  final peak = values.indexOf(max);
  return [
    for (var i = 0; i < values.length; i++)
      (i == peak || i == values.length - 1) && values[i] > 0 ? format(values[i]) : '',
  ];
}

class _WeekSection extends StatelessWidget {
  const _WeekSection({required this.statistics, required this.compact});

  final Statistics statistics;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (statistics.totals.remittances == 0) return const _NoData(title: ReportTexts.salesByWeek);
    final weeks = statistics.byWeek;
    final labels = _weekLabels(weeks);
    String weekName(StatisticsGroup week) {
      final label = week.from == null ? week.key : ReportTexts.shortDate(week.from!);
      return week.partial ? ReportTexts.incomplete(label) : label;
    }

    final counts = [for (final week in weeks) week.figures.remittances.toDouble()];
    final collected = [for (final week in weeks) week.figures.collected];
    final height = compact ? 130.0 : 190.0;
    Widget chart(String caption, List<double> values, List<String> tips, String Function(double) format) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(caption, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        _Bars(
          values: values,
          labels: labels,
          tips: tips,
          valueLabels: _peakLabels(values, format),
          height: height,
          maxBarWidth: 40,
          semantics: caption,
        ),
      ],
    );
    final countChart = chart(compact ? ReportTexts.remittancesByWeek : ReportTexts.weekCount, counts, [
      for (final week in weeks) ReportTexts.weekTip(weekName(week), week.figures.remittances),
    ], (value) => value.toStringAsFixed(0));
    final collectedChart = chart(ReportTexts.weekCollected(statistics.businessCurrency), collected, [
      for (final week in weeks)
        ReportTexts.weekCollectedTip(
          weekName(week),
          Formatters.money(week.figures.collected, statistics.businessCurrency),
        ),
    ], (value) => value.toStringAsFixed(0));
    return ReportSection(
      title: ReportTexts.salesByWeek,
      help: compact ? null : ReportTexts.salesByWeekHelp,
      padding: compact ? 14 : 20,
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < 760
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [countChart, const SizedBox(height: 20), collectedChart],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: countChart),
                  const SizedBox(width: 28),
                  Expanded(child: collectedChart),
                ],
              ),
      ),
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({required this.statistics, required this.compact});

  final Statistics statistics;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (statistics.totals.remittances == 0) return const _NoData(title: ReportTexts.salesByDay);
    final days = [
      for (final group in statistics.byDayOfWeek)
        if (DayOfWeek.fromCode(group.key) case final day?) (day, group.figures.remittances),
    ];
    return ReportSection(
      title: ReportTexts.salesByDay,
      padding: compact ? 14 : 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Bars(
            values: [for (final (_, count) in days) count.toDouble()],
            labels: [for (final (day, _) in days) compact ? ReportTexts.dayShort(day)[0] : ReportTexts.dayShort(day)],
            tips: [for (final (day, count) in days) ReportTexts.dayTip(ReportTexts.dayName(day), count)],
            valueLabels: [for (final (_, count) in days) '$count'],
            height: compact ? 120 : 190,
            maxBarWidth: 56,
            gap: compact ? 6 : 8,
            semantics: ReportTexts.salesByDay,
          ),
          if (!compact) ...[
            const SizedBox(height: 8),
            Text(ReportTexts.salesByDayHelp, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _Average extends StatelessWidget {
  const _Average({required this.statistics, required this.previous, required this.compact});

  final Statistics statistics;
  final Statistics? previous;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final totals = statistics.totals;
    if (totals.deliveries == 0) return const _NoData(title: ReportTexts.averageTitle);
    final currency = statistics.businessCurrency;
    final textTheme = Theme.of(context).textTheme;
    final before = previous;
    final comparable =
        !statistics.hasFewData && before != null && !before.hasFewData && before.totals.averageAmount > 0;
    Widget? comparison;
    if (comparable) {
      final change = (totals.averageAmount - before.totals.averageAmount) / before.totals.averageAmount * 100;
      final rounded = (change * 10).round() / 10;
      comparison = Text(
        rounded == 0
            ? ReportTexts.sameAsBefore
            : ReportTexts.comparison(ReportTexts.percent(rounded.abs()), rounded > 0),
        style: TextStyle(
          fontSize: 13,
          color: rounded == 0 ? _muted : (rounded > 0 ? OttosColors.success : OttosColors.danger),
        ),
      );
    }
    final weekly = [
      for (final week in statistics.byWeek) week.figures.deliveries == 0 ? null : week.figures.averageAmount,
    ];
    return ReportSection(
      title: ReportTexts.averageTitle,
      padding: compact ? 14 : 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                Formatters.money(totals.averageAmount, currency),
                style: (compact ? textTheme.headlineSmall : textTheme.headlineMedium)?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: statistics.hasFewData ? _muted : null,
                ),
              ),
              if (statistics.hasFewData) const _FewDataChip(),
              ?comparison,
            ],
          ),
          const SizedBox(height: 6),
          Text(
            statistics.hasFewData
                ? ReportTexts.averageFewData(totals.deliveries)
                : ReportTexts.averageHelp(totals.pickups == 0 ? '' : Formatters.money(totals.averagePickup, currency)),
            style: textTheme.bodySmall,
          ),
          if (weekly.whereType<double>().length > 1) ...[
            const SizedBox(height: 12),
            Text(ReportTexts.weeklyEvolution, style: textTheme.bodySmall),
            const SizedBox(height: 6),
            SizedBox(
              height: compact ? 90 : 120,
              child: Semantics(
                label: ReportTexts.weeklyEvolution,
                child: CustomPaint(painter: _LinePainter(weekly), size: Size.infinite),
              ),
            ),
            const SizedBox(height: 4),
            _EdgeLabels(weeks: statistics.byWeek),
          ],
        ],
      ),
    );
  }
}

/// The first and last week under the line.
class _EdgeLabels extends StatelessWidget {
  const _EdgeLabels({required this.weeks});

  final List<StatisticsGroup> weeks;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 10.5, color: Color(0xFF6B6F7B));
    String label(StatisticsGroup week) => week.from == null ? '' : ReportTexts.shortDate(week.from!);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label(weeks.first), style: style),
        Text(label(weeks.last), style: style),
      ],
    );
  }
}

/// A line through the weeks with deliveries; the weeks without any are skipped.
class _LinePainter extends CustomPainter {
  _LinePainter(this.values);

  final List<double?> values;

  @override
  void paint(Canvas canvas, Size size) {
    final present = values.whereType<double>();
    if (present.isEmpty) return;
    var low = present.reduce(math.min);
    var high = present.reduce(math.max);
    if (high - low < 1) {
      low -= 1;
      high += 1;
    }
    const top = 14.0;
    final bottom = size.height - 6;
    final grid = Paint()
      ..color = const Color(0xFFECEEF2)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, bottom), Offset(size.width, bottom), grid..color = const Color(0xFFD9DCE3));
    canvas.drawLine(Offset(0, top), Offset(size.width, top), grid..color = const Color(0xFFECEEF2));
    final step = values.length == 1 ? 0.0 : (size.width - 16) / (values.length - 1);
    Offset point(int index, double value) =>
        Offset(8 + index * step, bottom - (value - low) / (high - low) * (bottom - top));
    final path = Path();
    Offset? last;
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      if (value == null) continue;
      final p = point(i, value);
      if (last == null) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
      last = p;
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = _bar
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    if (last != null) {
      canvas.drawCircle(last, 5, Paint()..color = Colors.white);
      canvas.drawCircle(last, 3.5, Paint()..color = _bar);
    }
    final painter = TextPainter(
      text: TextSpan(
        text: Formatters.money(high, null),
        style: const TextStyle(fontSize: 10, color: Color(0xFF6B6F7B)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, const Offset(2, 0));
  }

  @override
  bool shouldRepaint(_LinePainter oldDelegate) => oldDelegate.values != values;
}

class _MunicipalitySection extends StatelessWidget {
  const _MunicipalitySection({required this.statistics, required this.compact});

  final Statistics statistics;
  final bool compact;

  static const top = 10;

  @override
  Widget build(BuildContext context) {
    final groups = statistics.byMunicipality;
    if (groups.isEmpty) return const _NoData(title: ReportTexts.byMunicipality);
    final rows = <(String, int, bool)>[
      for (final group in groups.take(top)) (group.name ?? group.key, group.figures.remittances, false),
      if (groups.length > top)
        (
          ReportTexts.others(groups.length - top),
          groups.skip(top).fold(0, (sum, group) => sum + group.figures.remittances),
          true,
        ),
    ];
    final max = rows.fold(0, (value, row) => math.max(value, row.$2));
    return ReportSection(
      title: ReportTexts.byMunicipality,
      help: ReportTexts.byMunicipalityHelp,
      padding: compact ? 14 : 20,
      child: Column(
        children: [
          for (final (name, count, other) in rows)
            Tooltip(
              message: ReportTexts.dayTip(name, count),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: compact ? 120 : 170,
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: other ? _muted : null,
                          fontStyle: other ? FontStyle.italic : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) => Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            height: 14,
                            width: max == 0 ? 0 : constraints.maxWidth * count / max,
                            decoration: BoxDecoration(
                              color: other ? _otherBar : _bar,
                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text('$count', textAlign: TextAlign.right, style: const TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OnTheHouseSection extends StatelessWidget {
  const _OnTheHouseSection({required this.statistics, required this.compact});

  final Statistics statistics;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final totals = statistics.totals;
    final onTheHouse = totals.onTheHouse;
    if (onTheHouse.remittances == 0) {
      return const ReportNotice(title: ReportTexts.onTheHouseNone);
    }
    final currency = statistics.businessCurrency;
    final share = totals.remittances == 0 ? 0.0 : onTheHouse.remittances / totals.remittances * 100;
    // By month when the period spans several; by week inside one month.
    final byMonth = statistics.byMonth.length > 1;
    final groups = byMonth ? statistics.byMonth : statistics.byWeek;
    String name(StatisticsGroup group) {
      if (byMonth) {
        final from = group.from;
        return from == null ? group.key : ReportTexts.monthTitle(from).split(' ').first;
      }
      return group.from == null ? group.key : ReportTexts.shortDate(group.from!);
    }

    final textTheme = Theme.of(context).textTheme;
    const header = TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _muted);
    Widget tableRow(String first, String second, String third, {TextStyle? style}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(first, style: style)),
          SizedBox(
            width: 80,
            child: Text(second, textAlign: TextAlign.right, style: style),
          ),
          SizedBox(
            width: compact ? 110 : 160,
            child: Text(third, textAlign: TextAlign.right, style: style),
          ),
        ],
      ),
    );
    return ReportSection(
      title: ReportTexts.onTheHouseTitle,
      padding: compact ? 14 : 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Grid(
            columns: 3,
            spacing: 10,
            children: [
              ReportFigure(
                label: ReportTexts.remittances,
                value: '${onTheHouse.remittances}',
                help: ReportTexts.percentOfTotal(ReportTexts.percent(share)),
              ),
              ReportFigure(
                label: ReportTexts.waivedFees,
                value: Formatters.money(onTheHouse.waivedFees, currency),
                help: ReportTexts.waivedFeesHelp,
              ),
              ReportFigure(
                label: ReportTexts.sent,
                value: Formatters.money(onTheHouse.amount, currency),
                help: ReportTexts.onTheHouseSentHelp,
              ),
            ],
          ),
          const SizedBox(height: 12),
          tableRow(
            byMonth ? ReportTexts.month : ReportTexts.week,
            ReportTexts.remittances,
            ReportTexts.waivedFees,
            style: header,
          ),
          const Divider(height: 1),
          for (final group in groups)
            tableRow(
              name(group),
              '${group.figures.onTheHouse.remittances}',
              Formatters.money(group.figures.onTheHouse.waivedFees, null),
            ),
          const SizedBox(height: 8),
          Text(ReportTexts.onTheHouseTableHelp, style: textTheme.bodySmall),
        ],
      ),
    );
  }
}
