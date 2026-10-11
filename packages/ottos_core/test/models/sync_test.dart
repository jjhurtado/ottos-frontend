import 'package:flutter_test/flutter_test.dart';
import 'package:ottos_core/ottos_core.dart';

void main() {
  test('action ids are UUID v4 and unique', () {
    final ids = {for (var i = 0; i < 100; i++) SyncRepository.newActionId()};
    expect(ids, hasLength(100));
    for (final id in ids) {
      expect(id, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    }
  });

  test('a queued action survives storing it as JSON, with its time in UTC', () {
    final action = SyncAction(
      id: SyncRepository.newActionId(),
      type: SyncActionType.deliverWithPin,
      remittanceId: 'r1',
      occurredAt: DateTime.utc(2026, 10, 10, 14, 3),
      payload: const {'pin': '123456', 'strictPin': false},
    );

    final json = action.toJson();

    expect(json['occurredAt'], '2026-10-10T14:03:00.000Z');
    expect(json['type'], 'DELIVER_WITH_PIN');
    expect(SyncAction.fromJson(json), action);
    expect(action.type.completes, isTrue);
    expect(SyncActionType.postpone.completes, isFalse);
  });

  test('reads the batch results', () {
    final response = SyncResponse.fromJson({
      'serverTime': '2026-10-10T18:05:12.345Z',
      'results': [
        {
          'id': 'a1',
          'status': 'APPLIED',
          'flaggedForReview': true,
          'remittance': {'id': 'r1', 'code': 'OT-1', 'type': 'DELIVERY', 'status': 'DELIVERED'},
        },
        {'id': 'a2', 'status': 'REJECTED', 'code': 'CONCURRENT_UPDATE', 'message': 'Try again'},
      ],
    });

    expect(response.results.first.done, isTrue);
    expect(response.results.first.flaggedForReview, isTrue);
    expect(response.results.last.done, isFalse);
    expect(response.results.last.retryable, isTrue);
  });

  test('reads the downloaded state', () {
    final state = SyncState.fromJson({
      'serverTime': '2026-10-10T18:05:12.345Z',
      'full': true,
      'remittances': [
        {
          'id': 'r1',
          'code': 'OT-1',
          'type': 'PICKUP',
          'status': 'ASSIGNED',
          'review': {'reason': 'PIN_MISMATCH', 'flaggedAt': '2026-10-10T18:00:00Z', 'actionId': 'a1'},
        },
      ],
      'removedIds': ['r9'],
      'cash': null,
    });

    expect(state.full, isTrue);
    expect(state.parsedRemittances.single.review?.reason, ReviewReason.pinMismatch);
    expect(state.removedIds, ['r9']);
    expect(state.parsedCash, isNull);
  });

  test('review reasons and filter', () {
    expect(ReviewReason.fromCode('LATE_SYNC'), ReviewReason.lateSync);
    expect(ReviewReason.fromCode('SOMETHING_NEW'), ReviewReason.other);
    expect(CoreTexts.reviewReason(ReviewReason.duplicateDelivery), isNotEmpty);
    expect(const RemittanceFilter(review: true).toQuery()['review'], isTrue);
  });
}
