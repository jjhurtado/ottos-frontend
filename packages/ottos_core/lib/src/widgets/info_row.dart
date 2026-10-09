import 'package:flutter/material.dart';

/// A label and its value, for detail screens. Hidden when [value] is empty.
class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.label, required this.value, this.labelWidth = 150});

  final String label;
  final String? value;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    final text = value;
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
          ),
          Expanded(child: SelectableText(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
