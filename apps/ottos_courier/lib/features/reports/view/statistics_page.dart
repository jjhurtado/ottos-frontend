import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

/// Sales › Estadísticas: the same charts as the panel, one under another
/// (`reports:read`).
class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => StatisticsCubit(reports: context.read<ReportRepository>())..load(),
      child: BlocBuilder<StatisticsCubit, StatisticsState>(
        builder: (context, state) => RefreshIndicator(
          onRefresh: context.read<StatisticsCubit>().load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            children: [
              const StatisticsPeriodPicker(compact: true),
              const SizedBox(height: 8),
              Text(statisticsPeriodText(state), style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              const StatisticsView(compact: true),
            ],
          ),
        ),
      ),
    );
  }
}
