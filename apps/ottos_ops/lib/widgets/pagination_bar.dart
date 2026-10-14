import 'package:flutter/material.dart';
import 'package:ottos_core/ottos_core.dart';

import '../app/ops_texts.dart';

/// "1–50 de 339" and the previous and next page buttons, under a paged table.
class PaginationBar extends StatelessWidget {
  const PaginationBar({required this.result, required this.onPage, super.key});

  final PageResult<Object?> result;

  /// Opens the given page (from 0).
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final first = result.totalItems == 0 ? 0 : result.page * result.size + 1;
    final last = result.page * result.size + result.items.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(OpsTexts.pageOf(first, last, result.totalItems)),
          const SizedBox(width: 8),
          IconButton(
            tooltip: OpsTexts.previousPage,
            onPressed: result.page > 0 ? () => onPage(result.page - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: OpsTexts.nextPage,
            onPressed: result.page + 1 < result.totalPages ? () => onPage(result.page + 1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
