import 'package:flutter/material.dart';

/// Two form fields side by side on a wide screen and one under the other on a
/// phone, where side by side they would not fit. [secondWidth] fixes the width
/// of the second one when side by side; otherwise both share the row.
class FormPair extends StatelessWidget {
  const FormPair({super.key, required this.first, required this.second, this.secondWidth});

  final Widget first;
  final Widget second;
  final double? secondWidth;

  /// Below this screen width the fields stack.
  static const narrowWidth = 600.0;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < narrowWidth) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [first, second]);
    }
    final width = secondWidth;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: 12),
        if (width == null) Expanded(child: second) else SizedBox(width: width, child: second),
      ],
    );
  }
}
