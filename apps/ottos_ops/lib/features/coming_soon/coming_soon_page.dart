import 'package:flutter/material.dart';
import 'package:ottos_core/ottos_core.dart';

import '../../app/ops_texts.dart';

class ComingSoonPage extends StatelessWidget {
  const ComingSoonPage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const Expanded(
            child: EmptyView(message: OpsTexts.comingSoon, icon: Icons.construction_outlined),
          ),
        ],
      ),
    );
  }
}
