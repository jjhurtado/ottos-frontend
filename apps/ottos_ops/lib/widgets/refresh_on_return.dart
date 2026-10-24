import 'package:flutter/widgets.dart';

/// Calls [onReturn] each time the route holding [child] becomes the current
/// one again, e.g. when coming back to a list from its form or detail.
///
/// Children routes (`/remittances/new`, `/remittances/:id`…) are stacked on top
/// of their parent, which stays mounted with its old data. This lets the
/// parent reload what may have changed meanwhile.
class RefreshOnReturn extends StatefulWidget {
  const RefreshOnReturn({super.key, required this.onReturn, required this.child});

  final VoidCallback onReturn;
  final Widget child;

  @override
  State<RefreshOnReturn> createState() => _RefreshOnReturnState();
}

class _RefreshOnReturnState extends State<RefreshOnReturn> {
  bool? _wasCurrent;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Outside a route (e.g. in a bare test) it never "returns".
    final isCurrent = ModalRoute.of(context) == null || ModalRoute.isCurrentOf(context)!;
    if (_wasCurrent == false && isCurrent) widget.onReturn();
    _wasCurrent = isCurrent;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
