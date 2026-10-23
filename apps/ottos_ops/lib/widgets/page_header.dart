import 'package:flutter/material.dart';

/// Below this width the panel is on a phone: lists instead of tables, and
/// page actions under the title.
const compactWidth = 600.0;

bool isCompact(BuildContext context) => MediaQuery.sizeOf(context).width < compactWidth;

/// The space around a page's content: less on a phone.
EdgeInsets pagePadding(BuildContext context) => EdgeInsets.all(isCompact(context) ? 12 : 24);

/// A page's title with its actions on the right; on a phone the actions go
/// under the title, so neither gets squeezed.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.actions = const []});

  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final heading = Text(title, style: Theme.of(context).textTheme.headlineMedium);
    if (actions.isEmpty) return heading;
    if (!isCompact(context)) {
      return Row(
        children: [
          Expanded(child: heading),
          for (final (index, action) in actions.indexed) ...[if (index > 0) const SizedBox(width: 8), action],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading,
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: actions),
      ],
    );
  }
}
