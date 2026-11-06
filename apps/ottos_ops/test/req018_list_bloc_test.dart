import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ottos_core/ottos_core.dart';
import 'package:ottos_ops/features/remittances/bloc/remittance_list_bloc.dart';

class _MockRemittances extends Mock implements RemittanceRepository {}

Remittance _remittance(String id) =>
    Remittance(id: id, code: 'OT-$id', type: RemittanceType.delivery, status: 'CREATED', statusName: 'Creada');

PageResult<Remittance> _page(int page, List<String> ids) =>
    PageResult(items: [for (final id in ids) _remittance(id)], page: page, size: 2, totalItems: 4);

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  setUpAll(() => registerFallbackValue(const RemittanceFilter()));

  test(
    'CR-1 (AC-1.5): a late answer to a cancelled search does not change the repeats dropped for the new one',
    () async {
      final remittances = _MockRemittances();
      final oldSearch = Completer<PageResult<Remittance>>();
      final newSearch = Completer<PageResult<Remittance>>();
      when(
        () => remittances.search(
          any(),
          page: any(named: 'page'),
          size: any(named: 'size'),
        ),
      ).thenAnswer((call) {
        final filter = call.positionalArguments.first as RemittanceFilter;
        final page = call.namedArguments[#page] as int;
        if (filter.late != true) return oldSearch.future;
        return page == 0 ? newSearch.future : Future.value(_page(1, ['x2', 'x3']));
      });
      final bloc = RemittanceListBloc(remittances: remittances);

      bloc.add(const RemittanceListFilterChanged(RemittanceFilter(beneficiaryQuery: 'jose')));
      await _flush();
      bloc.add(const RemittanceListFilterChanged(RemittanceFilter(beneficiaryQuery: 'jose', late: true)));
      await _flush();
      newSearch.complete(_page(0, ['x1', 'x2']));
      await _flush();
      oldSearch.complete(_page(0, ['y1']));
      await _flush();
      bloc.add(const RemittanceListPageRequested(1));
      await _flush();
      await _flush();

      expect([for (final item in bloc.state.result!.items) item.id], ['x3']);
      await bloc.close();
    },
  );
}
