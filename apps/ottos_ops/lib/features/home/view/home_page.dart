import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ottos_core/ottos_core.dart';

import '../../../app/destinations.dart';
import '../../../app/ops_texts.dart';
import '../cubit/home_cubit.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthBloc bloc) => bloc.state.user)!;
    final canSeeRemittances = user.can(Permissions.remittancesRead);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(OpsTexts.greeting(user.displayName), style: Theme.of(context).textTheme.headlineMedium),
        if (canSeeRemittances) ...[
          const SizedBox(height: 4),
          Text(OpsTexts.homeSubtitle, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
          const SizedBox(height: 24),
          BlocProvider(
            create: (context) => HomeCubit(remittances: context.read<RemittanceRepository>())..load(),
            child: const _Summary(),
          ),
        ],
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeCubit, HomeState>(
      builder: (context, state) => switch (state.status) {
        HomeStatus.loading => const Padding(padding: EdgeInsets.all(48), child: LoadingView()),
        HomeStatus.failure => ErrorView(message: state.error!, onRetry: context.read<HomeCubit>().load),
        HomeStatus.success => Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final item in state.openByStatus)
              _CountCard(
                label: CoreTexts.statusName(item.status.code, fallback: item.status.name),
                count: item.count,
                color: OttosColors.teal,
                icon: Icons.send_outlined,
                onTap: () => context.go(
                  Uri(path: Destinations.remittances.path, queryParameters: {'status': item.status.code}).toString(),
                ),
              ),
            _CountCard(
              label: OpsTexts.lateRemittances,
              count: state.late,
              color: OttosColors.danger,
              icon: Icons.schedule,
              onTap: () => context.go('${Destinations.remittances.path}?late=true'),
            ),
            _CountCard(
              label: OpsTexts.incidentRemittances,
              count: state.incidents,
              color: OttosColors.danger,
              icon: Icons.error_outline,
              onTap: () => context.go('${Destinations.remittances.path}?incident=true'),
            ),
          ],
        ),
      },
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final int count;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      width: 220,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color),
                const SizedBox(height: 12),
                Text(
                  '$count',
                  style: textTheme.displaySmall?.copyWith(color: color, fontWeight: FontWeight.w700),
                ),
                Text(label, style: textTheme.titleSmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
