/// A page of results (`PageView`). Pages start at 0.
class PageResult<T> {
  const PageResult({required this.items, required this.page, required this.size, required this.totalItems});

  factory PageResult.fromJson(Map<String, dynamic> json, T Function(Map<String, dynamic>) fromJson) => PageResult(
    items: (json['items'] as List? ?? const []).map((item) => fromJson(item as Map<String, dynamic>)).toList(),
    page: json['page'] as int? ?? 0,
    size: json['size'] as int? ?? 0,
    totalItems: json['totalItems'] as int? ?? 0,
  );

  final List<T> items;
  final int page;
  final int size;
  final int totalItems;

  int get totalPages => size == 0 ? 0 : (totalItems / size).ceil();
}
