import 'package:flutter/widgets.dart';

import '../utils/business_time.dart';

/// Rebuilds everything below it when the business time zone changes, so
/// every time on screen follows the new zone without a reload (AC-2.3).
///
/// Times are formatted through the static [BusinessTime], which no widget
/// depends on, so a change marks every element below for a rebuild. It
/// happens only when the zone really changes.
class BusinessTimeScope extends StatefulWidget {
  const BusinessTimeScope({super.key, required this.child});

  final Widget child;

  @override
  State<BusinessTimeScope> createState() => _BusinessTimeScopeState();
}

class _BusinessTimeScopeState extends State<BusinessTimeScope> {
  @override
  void initState() {
    super.initState();
    BusinessTime.changes.addListener(_rebuildAll);
  }

  @override
  void dispose() {
    BusinessTime.changes.removeListener(_rebuildAll);
    super.dispose();
  }

  void _rebuildAll() {
    if (!mounted) return;
    void rebuild(Element element) {
      element.markNeedsBuild();
      element.visitChildren(rebuild);
    }

    (context as Element).visitChildren(rebuild);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
