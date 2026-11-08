import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ottos_core/ottos_core.dart';

enum PagedSearchStatus { loading, success, failure }

final class PagedSearchState<T> extends Equatable {
  const PagedSearchState({this.status = PagedSearchStatus.loading, this.query = '', this.result, this.error});

  final PagedSearchStatus status;
  final String query;

  /// The page on screen; kept while the next one loads.
  final PageResult<T>? result;
  final String? error;

  List<T> get items => result?.items ?? const [];

  @override
  List<Object?> get props => [status, query, result, error];
}

/// Reads one page of matches for a query (all items when it is empty).
typedef PageSearch<T> = Future<PageResult<T>> Function(String query, {int page, int size});

/// A list by pages, the most recent first: all items without a query, matches
/// with one. Typing waits [searchDelay]; only the latest request is shown.
class PagedSearchCubit<T> extends Cubit<PagedSearchState<T>> {
  PagedSearchCubit(this._fetch, {this.searchDelay = const Duration(milliseconds: 300), this.pageSize = 50})
    : super(PagedSearchState<T>());

  final PageSearch<T> _fetch;

  /// Wait after the last keystroke before searching.
  final Duration searchDelay;
  final int pageSize;
  Timer? _timer;
  int _request = 0;

  /// Loads [page], or the current one again.
  Future<void> load({int? page}) => _search(state.query, page ?? state.result?.page ?? 0);

  /// A new search starts at the first page.
  void queryChanged(String query) {
    _timer?.cancel();
    _timer = Timer(searchDelay, () => _search(query, 0));
  }

  Future<void> _search(String query, int page) async {
    final request = ++_request;
    emit(PagedSearchState<T>(query: query, result: state.result));
    try {
      final result = await _fetch(query, page: page, size: pageSize);
      if (request == _request && !isClosed) {
        emit(PagedSearchState<T>(status: PagedSearchStatus.success, query: query, result: result));
      }
    } on ApiException catch (error) {
      if (request == _request && !isClosed) {
        emit(
          PagedSearchState<T>(
            status: PagedSearchStatus.failure,
            query: query,
            result: state.result,
            error: error.message,
          ),
        );
      }
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
