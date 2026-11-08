import 'package:ottos_core/ottos_core.dart';

import '../../../widgets/paged_search_cubit.dart';

export '../../../widgets/paged_search_cubit.dart' show PagedSearchStatus;

typedef BeneficiaryListState = PagedSearchState<Beneficiary>;

/// Every active beneficiary, with a customer or not, by pages and the most
/// recent first: all of them without a query, matches by name or phone with one.
class BeneficiaryListCubit extends PagedSearchCubit<Beneficiary> {
  BeneficiaryListCubit({required CustomerRepository customers, super.searchDelay, super.pageSize})
    : super(customers.beneficiaryPage);

  /// An edited beneficiary changes in place; a new one is the most recent, so
  /// the first page is loaded again to show it with the new total.
  Future<void> saved(Beneficiary beneficiary) async {
    final result = state.result;
    final index = state.items.indexWhere((item) => item.id == beneficiary.id);
    if (result == null || index == -1) return load(page: 0);
    final items = [...result.items]..[index] = beneficiary;
    emit(
      BeneficiaryListState(
        status: state.status,
        query: state.query,
        result: PageResult(items: items, page: result.page, size: result.size, totalItems: result.totalItems),
      ),
    );
  }
}
