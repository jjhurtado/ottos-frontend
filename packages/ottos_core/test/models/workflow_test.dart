import 'package:flutter_test/flutter_test.dart';
import 'package:ottos_core/ottos_core.dart';

/// The workflow the backend seeds: PAID → ASSIGNED (→ ASSIGNED) → DELIVERED.
final _workflow = Workflow.fromJson({
  'statuses': [
    {'code': 'DELIVERED', 'name': 'Entregada', 'position': 30, 'isFinal': true},
    {'code': 'PAID', 'name': 'Pagada', 'position': 10, 'initial': true},
    {'code': 'ASSIGNED', 'name': 'Asignada', 'position': 20, 'requiresCourier': true},
  ],
  'transitions': [
    {'from': 'PAID', 'to': 'ASSIGNED', 'permission': Permissions.remittancesAssign},
    {'from': 'ASSIGNED', 'to': 'ASSIGNED', 'permission': Permissions.remittancesAssign},
    {'from': 'ASSIGNED', 'to': 'DELIVERED', 'permission': Permissions.remittancesDeliver},
  ],
});

void main() {
  const assigner = {Permissions.remittancesAssign};
  const deliverer = {Permissions.remittancesDeliver};

  test('sorts statuses by position', () {
    expect(_workflow.statuses.map((status) => status.code), ['PAID', 'ASSIGNED', 'DELIVERED']);
  });

  test('assigning needs the permission and a transition to a status with a courier', () {
    expect(_workflow.canAssign('PAID', assigner), isTrue);
    expect(_workflow.canAssign('ASSIGNED', assigner), isTrue);
    expect(_workflow.canAssign('DELIVERED', assigner), isFalse);
    expect(_workflow.canAssign('PAID', deliverer), isFalse);
  });

  test('completing needs the permission and a transition to a final status', () {
    expect(_workflow.canComplete('ASSIGNED', deliverer), isTrue);
    expect(_workflow.canComplete('PAID', deliverer), isFalse);
    expect(_workflow.canComplete('ASSIGNED', assigner), isFalse);
  });

  test('knows final and unknown statuses', () {
    expect(_workflow.isFinal('DELIVERED'), isTrue);
    expect(_workflow.isFinal('PAID'), isFalse);
    expect(_workflow.isFinal('UNKNOWN'), isFalse);
    expect(_workflow.nameOf('UNKNOWN'), 'UNKNOWN');
  });
}
