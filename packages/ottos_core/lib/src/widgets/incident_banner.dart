import 'package:flutter/material.dart';

import '../l10n/core_texts.dart';
import '../models/remittance.dart';
import '../theme/ottos_colors.dart';
import '../utils/formatters.dart';

/// The open incident of a remittance: reason, note and when it was reported.
class IncidentBanner extends StatelessWidget {
  const IncidentBanner({super.key, required this.incident});

  final Incident incident;

  @override
  Widget build(BuildContext context) {
    final note = incident.note;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OttosColors.danger.withValues(alpha: 0.08),
        border: Border.all(color: OttosColors.danger.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.report_outlined, color: OttosColors.danger),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${CoreTexts.incident}: ${CoreTexts.incidentReason(incident.reason)}',
                  style: const TextStyle(color: OttosColors.danger, fontWeight: FontWeight.w600),
                ),
                if (note != null && note.isNotEmpty) ...[const SizedBox(height: 4), Text(note)],
                if (incident.reportedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(Formatters.dateTime(incident.reportedAt), style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Incidencia · No estaba en casa", for lists.
class IncidentBadge extends StatelessWidget {
  const IncidentBadge({super.key, required this.incident});

  final Incident incident;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: OttosColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.report_outlined, size: 16, color: OttosColors.danger),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '${CoreTexts.incident} · ${CoreTexts.incidentReason(incident.reason)}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: OttosColors.danger, fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
