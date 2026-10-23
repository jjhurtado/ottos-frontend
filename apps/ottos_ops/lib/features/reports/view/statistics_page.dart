import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

import '../../../app/ops_texts.dart';
import '../../../widgets/page_header.dart';

/// Sales statistics of a period (`reports:read`): by week, by day of the
/// week, average amount, by municipality and on the house.
class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final compact = isCompact(context);
    return BlocProvider(
      create: (context) => StatisticsCubit(reports: context.read<ReportRepository>())..load(),
      child: BlocBuilder<StatisticsCubit, StatisticsState>(
        builder: (context, state) => ListView(
          padding: pagePadding(context),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(OpsTexts.statistics, style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 4),
                    Text(statisticsPeriodText(state)),
                  ],
                ),
                StatisticsPeriodPicker(compact: compact),
              ],
            ),
            const SizedBox(height: 16),
            StatisticsView(compact: compact),
          ],
        ),
      ),
    );
  }
}
