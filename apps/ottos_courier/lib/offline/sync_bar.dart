import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

import '../app/courier_texts.dart';
import 'sync_cubit.dart';

extension MaybeSync on BuildContext {
  /// The user's sync, or null for who works online (sales) and in tests.
  SyncCubit? get syncCubit {
    try {
      return read<SyncCubit?>();
    } catch (_) {
      return null;
    }
  }
}

/// Under the title: whether the phone is in step with the server, what waits
/// to be sent, and the actions the server refused.
class SyncBar extends StatelessWidget {
  const SyncBar({super.key, required this.sync});

  final SyncCubit sync;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SyncCubit, SyncStatus>(
      bloc: sync,
      builder: (context, status) {
        final textTheme = Theme.of(context).textTheme;
        final warn = status.offline || status.pending > 0;
        final color = warn ? OttosColors.warning : OttosColors.success;
        return Material(
          color: color.withValues(alpha: 0.1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
                child: Row(
                  children: [
                    Icon(status.offline ? Icons.cloud_off : Icons.cloud_done_outlined, size: 18, color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        CourierTexts.syncSummary(status, now: DateTime.now()),
                        style: textTheme.bodySmall?.copyWith(color: OttosColors.navy),
                      ),
                    ),
                    if (status.syncing)
                      const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    else
                      IconButton(tooltip: CourierTexts.syncNow, icon: const Icon(Icons.sync), onPressed: sync.sync),
                  ],
                ),
              ),
              if (status.rejected.isNotEmpty)
                InkWell(
                  onTap: () => showRejectedSheet(context, sync),
                  child: Container(
                    width: double.infinity,
                    color: OttosColors.danger.withValues(alpha: 0.1),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, size: 18, color: OttosColors.danger),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            CourierTexts.notSynced(status.rejected.length),
                            style: const TextStyle(color: OttosColors.danger, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: OttosColors.danger),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The actions the server refused, with why; the courier reads and dismisses them.
Future<void> showRejectedSheet(BuildContext context, SyncCubit sync) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => BlocBuilder<SyncCubit, SyncStatus>(
      bloc: sync,
      builder: (context, status) {
        if (status.rejected.isEmpty) {
          return const Padding(padding: EdgeInsets.all(32), child: Text(CourierTexts.nothingRejected));
        }
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Text(CourierTexts.notSyncedTitle, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              const Text(CourierTexts.notSyncedHelp),
              const SizedBox(height: 8),
              for (final item in status.rejected)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.error_outline, color: OttosColors.danger),
                    title: Text(CourierTexts.actionName(item.action.type)),
                    subtitle: Text(
                      [
                        Formatters.dateTime(item.action.occurredAt),
                        item.message ?? CoreTexts.unexpectedError,
                      ].join('\n'),
                    ),
                    isThreeLine: true,
                    trailing: TextButton(
                      onPressed: () => sync.dismiss(item.action.id),
                      child: const Text(CourierTexts.dismiss),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}
