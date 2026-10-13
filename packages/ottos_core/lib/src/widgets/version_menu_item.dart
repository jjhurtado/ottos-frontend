import 'package:flutter/material.dart';

/// The last entry of the account menu: which version is running, so support can ask for it.
class VersionMenuItem<T> extends PopupMenuItem<T> {
  VersionMenuItem({super.key, required String label})
    : super(
        enabled: false,
        height: 36,
        child: Builder(
          builder: (context) {
            final color = Theme.of(context).colorScheme.onSurfaceVariant;
            return Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: color),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color)),
                ),
              ],
            );
          },
        ),
      );
}
