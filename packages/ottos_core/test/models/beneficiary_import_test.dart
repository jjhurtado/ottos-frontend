import 'package:flutter_test/flutter_test.dart';
import 'package:ottos_core/ottos_core.dart';

void main() {
  test('reads a beneficiaries import and adds batches', () {
    final first = BeneficiaryImportResult.fromJson({
      'dryRun': true,
      'summary': {'created': 1, 'existing': 0, 'rejected': 1},
      'results': [
        {'index': 0, 'ref': 'fila 2', 'status': 'CREATED', 'linked': false},
        {'index': 1, 'ref': 'fila 3', 'status': 'REJECTED', 'code': 'UNKNOWN_MUNICIPALITY'},
      ],
    });
    final second = BeneficiaryImportResult.fromJson({
      'dryRun': true,
      'summary': {'created': 0, 'existing': 2, 'rejected': 0},
      'results': [
        {'ref': 'fila 502', 'status': 'EXISTING'},
        {'ref': 'fila 503', 'status': 'EXISTING'},
      ],
    });

    final total = first + second;

    expect(total.created, 1);
    expect(total.existing, 2);
    expect(total.rejectedCount, 1);
    expect(total.results, hasLength(4));
    expect(total.rejected.single.ref, 'fila 3');
    expect(total.rejected.single.code, 'UNKNOWN_MUNICIPALITY');
  });
}
