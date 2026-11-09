import '_json.dart';

/// 统一分页信息 `{page, limit, total, pages}`。
class Pagination {
  final int page;
  final int limit;
  final int total;
  final int pages;

  const Pagination({
    required this.page,
    required this.limit,
    required this.total,
    required this.pages,
  });

  factory Pagination.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const Pagination(page: 1, limit: 20, total: 0, pages: 0);
    }
    return Pagination(
      page: asInt(json['page'], 1),
      limit: asInt(json['limit'], 20),
      total: asInt(json['total']),
      pages: asInt(json['pages']),
    );
  }

  bool get hasNext => page < pages;
  bool get isEmpty => total == 0;

  static const empty = Pagination(page: 1, limit: 20, total: 0, pages: 0);
}

/// 分页列表封装：数据 + 分页。
class Paged<T> {
  final List<T> items;
  final Pagination pagination;

  const Paged({required this.items, required this.pagination});

  bool get hasNext => pagination.hasNext;
}
