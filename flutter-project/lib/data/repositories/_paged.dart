import '../models/_json.dart';
import '../models/page.dart';

/// 从 `{ <listKey>: [...], pagination: {...} }` 结构解析为 [Paged]。
/// [data] 已是 ApiClient 解包后的业务 `data`。
Paged<T> parsePaged<T>(
  dynamic data,
  String listKey,
  T Function(Map<String, dynamic>) fromJson,
) {
  if (data is Map) {
    final m = Map<String, dynamic>.from(data);
    final list = asMapList(m[listKey]).map(fromJson).toList();
    final pagination = Pagination.fromJson(asMap(m['pagination']));
    return Paged(items: list, pagination: pagination);
  }
  return Paged(items: const [], pagination: Pagination.empty);
}

/// 直接把解包后的 `data`（数组）解析为列表。
List<T> parseList<T>(dynamic data, T Function(Map<String, dynamic>) fromJson) =>
    asMapList(data).map(fromJson).toList();

/// 把解包后的 `data`（对象）转为 Map。
Map<String, dynamic> asDataMap(dynamic data) =>
    data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
