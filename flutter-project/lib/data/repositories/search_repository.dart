import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/network/endpoints.dart';
import '../models/_json.dart';
import '../models/page.dart';
import '../models/post.dart';
import '../models/search.dart';
import '../models/user.dart';
import '_paged.dart';

/// 笔记/综合搜索结果。
class SearchResult {
  final List<Post> posts;
  final List<TagStat> tagStats;
  final Pagination pagination;

  const SearchResult({
    required this.posts,
    required this.tagStats,
    required this.pagination,
  });
}

/// 搜索：笔记 / 用户 / 热搜词。
class SearchRepository {
  final ApiClient client;

  SearchRepository(this.client);

  /// [type]: all / posts / videos。
  Future<SearchResult> searchPosts(
    String keyword, {
    String type = 'all',
    String? tag,
    int page = 1,
    int? limit,
  }) async {
    final data = await client.get(Endpoints.search, queryParameters: {
      'keyword': keyword,
      'type': type,
      'page': page,
      'limit': limit ?? AppConfig.defaultPageSize,
      if (tag != null && tag.isNotEmpty) 'tag': tag,
    });
    final m = asDataMap(data);
    // all: {data:[], tagStats:[], pagination}; posts/videos: {posts:{data,tagStats,pagination}}
    final block = (m['data'] is List) ? m : asDataMap(m['posts']);
    return SearchResult(
      posts: asMapList(block['data']).map(Post.fromJson).toList(),
      tagStats: asMapList(block['tagStats']).map(TagStat.fromJson).toList(),
      pagination: Pagination.fromJson(asMap(block['pagination'])),
    );
  }

  Future<Paged<UserProfile>> searchUsers(
    String keyword, {
    int page = 1,
    int? limit,
  }) async {
    final data = await client.get(Endpoints.search, queryParameters: {
      'keyword': keyword,
      'type': 'users',
      'page': page,
      'limit': limit ?? AppConfig.defaultPageSize,
    });
    final m = asDataMap(data);
    final block = asDataMap(m['users']);
    return Paged(
      items: asMapList(block['data']).map(UserProfile.fromJson).toList(),
      pagination: Pagination.fromJson(asMap(block['pagination'])),
    );
  }

  Future<List<HotKeyword>> hot({int limit = 10}) async {
    final data = await client
        .get(Endpoints.searchHot, queryParameters: {'limit': limit});
    return parseList(data, HotKeyword.fromJson);
  }
}
