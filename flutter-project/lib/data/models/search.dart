import '_json.dart';

/// 热搜词（/api/search/hot）。
class HotKeyword {
  final String keyword;
  final int count;

  const HotKeyword({required this.keyword, required this.count});

  factory HotKeyword.fromJson(Map<String, dynamic> json) => HotKeyword(
        keyword: asString(json['keyword']),
        count: asInt(json['count']),
      );
}

/// 搜索联想标签统计（/api/search 返回的 tagStats）。
class TagStat {
  final String id;
  final String label;
  final int count;

  const TagStat({required this.id, required this.label, required this.count});

  factory TagStat.fromJson(Map<String, dynamic> json) => TagStat(
        id: asString(json['id']),
        label: asString(json['label']),
        count: asInt(json['count']),
      );
}
