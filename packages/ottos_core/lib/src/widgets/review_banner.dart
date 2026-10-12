import 'package:flutter/material.dart';

import '../l10n/core_texts.dart';
import '../models/remittance.dart';
import '../theme/ottos_colors.dart';
import '../utils/formatters.dart';

/// A remittance marked for sales to check, why and since when; [action] is
/// the panel's way to resolve it.
class ReviewBanner extends StatelessWidget {
  const ReviewBanner({super.key, required this.review, this.action});

  final Review review;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OttosColors.warning.withValues(alpha: 0.08),
        border: Border.all(color: OttosColors.warning.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.flag_outlined, color: OttosColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${CoreTexts.toReview}: ${CoreTexts.reviewReason(review.reason)}',
                  style: const TextStyle(color: OttosColors.warning, fontWeight: FontWeight.w600),
                ),
                if (review.flaggedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(Formatters.dateTime(review.flaggedAt), style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
          if (action != null) ...[const SizedBox(width: 12), action!],
        ],
      ),
    );
  }
}

/// "Para revisar", for lists.
class ReviewBadge extends StatelessWidget {
  const ReviewBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: OttosColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag_outlined, size: 16, color: OttosColors.warning),
          SizedBox(width: 6),
          Text(
            CoreTexts.toReview,
            style: TextStyle(color: OttosColors.warning, fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
