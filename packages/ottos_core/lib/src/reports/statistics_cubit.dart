import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../api/api_exception.dart';
import '../models/statistics.dart';
import '../utils/cuba_time.dart';
import 'report_repository.dart';

enum StatisticsPeriod { currentMonth, previousMonth, lastThreeMonths, custom }

/// [unavailable]: the backend does not have the statistics yet (404).
enum StatisticsStatus { loading, success, failure, unavailable }

/// A range of days, both included.
typedef DayRange = ({DateTime from, DateTime to});

final class StatisticsState extends Equatable {
  const StatisticsState({
    required this.period,
    required this.from,
    required this.to,
    this.status = StatisticsStatus.loading,
    this.statistics,
    this.previous,
    this.error,
  });

  final StatisticsPeriod period;
  final DateTime from;
  final DateTime to;
  final StatisticsStatus status;
  final Statistics? statistics;

  /// The period just before, as long, for the comparisons; null if it failed.
  final Statistics? previous;
  final String? error;

  @override
  List<Object?> get props => [period, from, to, status, statistics, previous, error];
}

/// The statistics of a period and of the one before it (two calls, in parallel).
class StatisticsCubit extends Cubit<StatisticsState> {
  StatisticsCubit({required this._reports, DateTime? today, StatisticsPeriod period = StatisticsPeriod.currentMonth})
    : _today = today,
      super(_initial(period, today ?? CubaTime.today()));

  final ReportRepository _reports;
  final DateTime? _today;

  /// The longest period the backend takes.
  static const maxDays = 366;

  DateTime get today => _today ?? CubaTime.today();

  static StatisticsState _initial(StatisticsPeriod period, DateTime today) {
    final range = rangeFor(period, today);
    return StatisticsState(period: period, from: range.from, to: range.to);
  }

  /// The days of [period] up to [today]: the month so far, last month, or this
  /// month and the two before it.
  static DayRange rangeFor(StatisticsPeriod period, DateTime today) => switch (period) {
    StatisticsPeriod.previousMonth => (
      from: DateTime(today.year, today.month - 1),
      to: DateTime(today.year, today.month, 0),
    ),
    StatisticsPeriod.lastThreeMonths => (from: DateTime(today.year, today.month - 2), to: today),
    _ => (from: DateTime(today.year, today.month), to: today),
  };

  /// The period before [from]–[to]: as many months before when it starts on a
  /// first day (whole months stay whole), else as many days before.
  static DayRange previousRange(DateTime from, DateTime to) {
    if (from.day == 1) {
      final months = (to.year * 12 + to.month) - (from.year * 12 + from.month) + 1;
      final wholeMonth = DateTime(to.year, to.month, to.day + 1).day == 1;
      final start = DateTime(from.year, from.month - months);
      final end = wholeMonth ? DateTime(to.year, to.month - months + 1, 0) : _shiftMonths(to, -months);
      return (from: start, to: end);
    }
    final days = to.difference(from).inDays + 1;
    return (from: DateTime(from.year, from.month, from.day - days), to: DateTime(from.year, from.month, from.day - 1));
  }

  /// [date] [months] later (or earlier), on the same day or the month's last.
  static DateTime _shiftMonths(DateTime date, int months) {
    final last = DateTime(date.year, date.month + months + 1, 0).day;
    return DateTime(date.year, date.month + months, date.day > last ? last : date.day);
  }

  Future<void> select(StatisticsPeriod period) {
    final range = rangeFor(period, today);
    emit(StatisticsState(period: period, from: range.from, to: range.to));
    return load();
  }

  /// A period of the user's choice, at most [maxDays] days.
  Future<void> custom(DateTime from, DateTime to) {
    emit(StatisticsState(period: StatisticsPeriod.custom, from: from, to: to));
    return load();
  }

  Future<void> load() async {
    final period = state.period;
    final from = state.from;
    final to = state.to;
    emit(StatisticsState(period: period, from: from, to: to));
    final before = previousRange(from, to);
    // Never fails: without it there is just no comparison.
    final previous = Future(() => _reports.statistics(before.from, before.to))
        .then<Statistics?>((value) => value)
        .catchError((Object _) => null, test: (error) => error is ApiException);
    try {
      final statistics = await _reports.statistics(from, to);
      final compared = await previous;
      if (isClosed || state.from != from || state.to != to) return;
      emit(
        StatisticsState(
          period: period,
          from: from,
          to: to,
          status: StatisticsStatus.success,
          statistics: statistics,
          previous: compared,
        ),
      );
    } on ApiException catch (error) {
      if (isClosed || state.from != from || state.to != to) return;
      emit(
        StatisticsState(
          period: period,
          from: from,
          to: to,
          status: error.statusCode == 404 ? StatisticsStatus.unavailable : StatisticsStatus.failure,
          error: error.message,
        ),
      );
    }
  }
}
