import 'package:shared_preferences/shared_preferences.dart';

/// 轻量本地偏好存储：搜索历史、草稿缓存等。
class Prefs {
  static const _searchHistoryKey = 'search_history';
  static const _maxHistory = 10;

  final SharedPreferences _prefs;

  Prefs(this._prefs);

  static Future<Prefs> create() async {
    final prefs = await SharedPreferences.getInstance();
    return Prefs(prefs);
  }

  // ---- 搜索历史 ----
  List<String> get searchHistory =>
      _prefs.getStringList(_searchHistoryKey) ?? const [];

  Future<void> addSearchHistory(String keyword) async {
    final k = keyword.trim();
    if (k.isEmpty) return;
    final list = List<String>.from(searchHistory);
    list.removeWhere((e) => e == k);
    list.insert(0, k);
    if (list.length > _maxHistory) {
      list.removeRange(_maxHistory, list.length);
    }
    await _prefs.setStringList(_searchHistoryKey, list);
  }

  Future<void> removeSearchHistory(String keyword) async {
    final list = List<String>.from(searchHistory)
      ..removeWhere((e) => e == keyword);
    await _prefs.setStringList(_searchHistoryKey, list);
  }

  Future<void> clearSearchHistory() => _prefs.remove(_searchHistoryKey);
}
