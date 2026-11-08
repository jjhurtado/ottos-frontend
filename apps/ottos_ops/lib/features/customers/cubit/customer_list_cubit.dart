import 'package:ottos_core/ottos_core.dart';

import '../../../widgets/paged_search_cubit.dart';

export '../../../widgets/paged_search_cubit.dart' show PagedSearchStatus;

typedef CustomerListState = PagedSearchState<Customer>;

/// Customers by pages, the most recent first: all of them without a query,
/// matches by name or phone with one.
class CustomerListCubit extends PagedSearchCubit<Customer> {
  CustomerListCubit({required CustomerRepository customers, super.searchDelay, super.pageSize})
    : super(customers.customerPage);
}
