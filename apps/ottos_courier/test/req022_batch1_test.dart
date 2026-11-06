import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_courier/features/assigned/cubit/assigned_cubit.dart';
import 'package:ottos_courier/offline/remittance_source.dart';

class _MockRemittances extends Mock implements RemittanceRepository {}

final _workflow = Workflow.fromJson({
  'statuses': [
    {'code': 'PAID', 'name': 'Pagada', 'position': 10, 'initial': true},
    {'code': 'DELIVERED', 'name': 'Entregada', 'position': 30, 'isFinal': true},
    {'code': 'PICKED_UP', 'name': 'Recogida', 'position': 31, 'isFinal': true},
  ],
  'transitions': const [],
});

const _totals = PendingTotals(toDeliver: [PendingAmount(currency: 'USD', remittances: 101, amount: 10100)]);

Remittance _open(String code) =>
    Remittance(id: code, code: code, type: RemittanceType.delivery, status: 'PAID', statusName: 'Pagada');

/// REQ-022 OPT-F3: sales' list asks only the open ones, with the totals, in one call.
void main() {
  late _MockRemittances remittances;

  setUpAll(() => registerFallbackValue(const RemittanceFilter()));

  setUp(() {
    remittances = _MockRemittances();
    when(() => remittances.workflow()).thenAnswer((_) async => _workflow);
  });

  test('sales: one call for the open ones and the business totals', () async {
    // 100 open ones: before, they hid behind the latest 100 of any status.
    final open = [for (var i = 0; i < 100; i++) _open('OT-$i')];
    when(() => remittances.pending(size: 100))
        .thenAnswer((_) async => (page: PageResult(items: open, page: 0, size: 100, totalItems: 101), totals: _totals));
    final source = OnlineSource(remittances: remittances);

    expect(await source.list(), open);
    expect(source.totals, _totals);
    verifyNever(() => remittances.search(any(), size: any(named: 'size')));
    verifyNever(() => remittances.pendingTotals());
  });

  test('the list cubit shows the totals that came with the list', () async {
    when(() => remittances.pending(size: 100)).thenAnswer(
      (_) async => (page: PageResult(items: [_open('OT-1')], page: 0, size: 100, totalItems: 1), totals: _totals),
    );
    final cubit = AssignedCubit(source: OnlineSource(remittances: remittances));
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.status, AssignedStatus.success);
    expect(cubit.state.items.single.code, 'OT-1');
    expect(cubit.state.totals, _totals);
    verify(() => remittances.pending(size: 100)).called(1);
  });

  test('a backend without totals: the list shows, without them', () async {
    when(() => remittances.pending(size: 100)).thenAnswer(
      (_) async => (page: PageResult(items: [_open('OT-1')], page: 0, size: 100, totalItems: 1), totals: null),
    );
    final cubit = AssignedCubit(source: OnlineSource(remittances: remittances));
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.status, AssignedStatus.success);
    expect(cubit.state.totals, isNull);
  });

  test('the courier online: their assigned ones, no business totals', () async {
    when(() => remittances.assignedToMe()).thenAnswer((_) async => [_open('OT-1')]);
    final source = OnlineSource(remittances: remittances, onlyMine: true);

    expect(await source.list(), hasLength(1));
    expect(source.totals, isNull);
    verifyNever(() => remittances.pending(size: any(named: 'size')));
  });

  test('completed: every final status asked to the server, not filtered on the phone', () async {
    final page = PageResult<Remittance>(items: const [], page: 1, size: 50, totalItems: 60);
    when(
      () => remittances.search(
        any(),
        page: any(named: 'page'),
        size: any(named: 'size'),
      ),
    ).thenAnswer((_) async => page);

    expect(await OnlineSource(remittances: remittances).completed(page: 1), page);
    verify(
      () => remittances.search(const RemittanceFilter(voided: false, status: 'DELIVERED,PICKED_UP'), page: 1, size: 50),
    ).called(1);
  });
}
