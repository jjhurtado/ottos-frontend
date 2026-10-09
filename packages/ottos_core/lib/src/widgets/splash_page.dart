import 'package:flutter/material.dart';

import '../theme/ottos_colors.dart';
import 'ottos_logo.dart';

/// Shown while the stored session is being restored.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: OttosColors.navy,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OttosLogo(size: 200),
            SizedBox(height: 16),
            CircularProgressIndicator(color: OttosColors.teal),
          ],
        ),
      ),
    );
  }
}
