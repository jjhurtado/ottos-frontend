import 'package:flutter/material.dart';

import '../theme/ottos_colors.dart';

/// "Rosa Pérez · OT-ABC123", or only the code when there is no name: how a
/// remittance is named in plain text (snackbars, notifications, exports).
/// The team names remittances by their beneficiary, never by the code
/// (REQ-019 BR-1, BR-2).
String remittanceLabel(String? name, String code) {
  final trimmed = name?.trim() ?? '';
  return trimmed.isEmpty ? code : '$trimmed · $code';
}

/// A remittance named by its beneficiary, with the code small under it
/// (REQ-019 AC-1.1, AC-1.2). For a pickup, [name] is the person the cash is
/// collected from. With no name, the code takes the title's place.
class RemittanceTitle extends StatelessWidget {
  const RemittanceTitle({
    super.key,
    required this.name,
    required this.code,
    this.style,
    this.codeStyle,
    this.maxLines = 1,
  });

  final String? name;
  final String code;

  /// Style of the name; the title text style when null.
  final TextStyle? style;

  /// Style of the code; small and muted when null.
  final TextStyle? codeStyle;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final titleStyle = style ?? textTheme.titleMedium;
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) {
      return Text(code, style: titleStyle, maxLines: maxLines, overflow: TextOverflow.ellipsis);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(trimmed, style: titleStyle, maxLines: maxLines, overflow: TextOverflow.ellipsis),
        Text(
          code,
          style: codeStyle ?? textTheme.bodySmall?.copyWith(color: OttosColors.inkMuted),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
