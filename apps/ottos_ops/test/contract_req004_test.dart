import 'package:flutter_test/flutter_test.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_ops/app/ops_texts.dart';

/// REQ-004 · panel against docs/api/openapi.yaml (ottos repo): the audit values
/// listed in the description of AuditEntryView.action and targetType.
void main() {
  // Copied by hand from the contract; SETTINGS is outside DFT-13 (REQ-006).
  const contractActions = {
    'USER': [
      'USER_CREATED',
      'USER_RENAMED',
      'USER_ROLES_CHANGED',
      'USER_DEACTIVATED',
      'USER_ACTIVATED',
      'USER_PASSWORD_RESET',
      'PASSWORD_CHANGED',
    ],
    'ROLE': ['ROLE_CREATED', 'ROLE_DESCRIBED', 'ROLE_PERMISSIONS_CHANGED', 'ROLE_DELETED'],
    'CUSTOMERS': ['CUSTOMERS_EXPORTED', 'CUSTOMERS_IMPORTED'],
    'BENEFICIARIES': ['BENEFICIARIES_IMPORTED'],
    'REMITTANCES': ['HISTORICAL_REMITTANCES_IMPORTED'],
    'REMITTANCE': [
      'HISTORICAL_REMITTANCE_CREATED',
      'REMITTANCE_COMPLETED_FROM_BUSINESS',
      'REMITTANCE_ON_THE_HOUSE',
      'REMITTANCE_VOIDED',
    ],
  };

  test('DFT-13: the filter offers every target and action of the contract, in Spanish', () {
    for (final MapEntry(key: target, value: actions) in contractActions.entries) {
      expect(OpsTexts.auditTarget(target), isNot(target), reason: 'target $target has no Spanish name');
      expect(OpsTexts.auditActions[target], unorderedEquals(actions), reason: 'actions of $target');
      for (final action in actions) {
        expect(OpsTexts.auditAction(action), isNot(action), reason: 'action $action has no Spanish text');
      }
    }
  });

  test('DFT-13: an action the panel does not know yet shows as it comes', () {
    expect(OpsTexts.auditAction('SOMETHING_NEW'), 'SOMETHING_NEW');
    expect(OpsTexts.auditTarget('SOMETHING_NEW'), 'SOMETHING_NEW');
  });

  test('DFT-10: every cash movement type of the contract has its own title', () {
    final generic = OpsTexts.movementTitle(CashMovementType.unknown);
    for (final type in CashMovementType.values.where((t) => t != CashMovementType.unknown)) {
      expect(OpsTexts.movementTitle(type), isNot(generic), reason: type.code);
    }
  });
}
