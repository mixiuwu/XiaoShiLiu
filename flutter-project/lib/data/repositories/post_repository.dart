import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/network/endpoints.dart';
import '../models/_json.dart';
import '../models/page.dart';
import '../models/post.dart';
import '../models/search.dart';
import '_paged.dart';

/// 分类（发布选择用）。
class Category {
  final int id;
  final String name;
  const Category({required this.id, required this.name});

  factory Category.fromJson(Map<String, dynamic> json) =>
      Category(id: asInt(json['id']), name: asString(json['name']));
}

/// 笔记：列表 / 详情 / 发布 / 更新 / 删除 / 收藏 / 分类与热门标签。
class PostRepository {
  final ApiClient client;

  PostRepository(this.client);

  /// 笔记列表。[category] 可传 `recommend` 走推荐算法；[type] 1图文 2视频；[status] 默认 0。
  Future<Paged<Post>> list({
    int page = 1,
    int? limit,
    String? category,
    int? type,
    int status = 0,
    int? userId,
  }) async {
    final data = await client.get(Endpoints.posts, queryParameters: {
      'page': page,
      'limit': limit ?? AppConfig.defaultPageSize,
      'status': status,
      if (category != null) 'category': category,
      if (type != null) 'type': type,
      if (userId != null) 'user_id': userId,
    });
    return parsePaged(data, 'posts', Post.fromJson);
  }

  /// 笔记详情（内联 poll / music / videos / liked / collected）。
  Future<Post> detail(String id, {bool skipViewCount = false}) async {
    final data = await client.get(Endpoints.post(id), queryParameters: {
      if (skipViewCount) 'skipViewCount': 'true',
    });
    return Post.fromJson(asDataMap(data));
  }

  /// 发布笔记，返回新笔记 id。
  Future<int> create({
    required String title,
    required String content,
    required int type,
    int status = 0,
    int? categoryId,
    List<String>? images,
    Map<String, dynamic>? video,
    List<String>? tags,
    int? musicId,
    Map<String, dynamic>? poll,
  }) async {
    final data = await client.post(Endpoints.posts, data: {
      'title': title,
      'content': content,
      'type': type,
      'status': status,
      if (categoryId != null) 'category_id': categoryId,
      if (images != null) 'images': images,
      if (video != null) 'video': video,
      if (tags != null) 'tags': tags,
      if (musicId != null) 'music_id': musicId,
      if (poll != null) 'poll': poll,
    });
    return asInt(asDataMap(data)['id']);
  }

  Future<void> update(String id, Map<String, dynamic> fields) =>
      client.put(Endpoints.post(id), data: fields);

  Future<void> delete(String id) => client.delete(Endpoints.post(id));

  /// 收藏 / 取消收藏（后端 toggle），返回收藏后的状态。
  Future<bool> toggleCollect(String id) async {
    final data = await client.post(Endpoints.postCollect(id));
    return asDataMap(data)['collected'] == true;
  }

  /// 为已有笔记创建投票（仅作者）。
  Future<void> createPoll(
    String postId, {
    required String question,
    required List<String> options,
    int durationHours = 0,
  }) =>
      client.post(Endpoints.postPoll(postId), data: {
        'question': question,
        'options': options,
        'duration_hours': durationHours,
      });

  Future<List<Category>> categories() async {
    final data = await client.get(Endpoints.categories);
    return parseList(data, Category.fromJson);
  }

  Future<List<TagStat>> hotTags({int limit = 10}) async {
    final data =
        await client.get(Endpoints.tagsHot, queryParameters: {'limit': limit});
    return parseList(
        data,
        (m) => TagStat(
              id: asString(m['name']),
              label: asString(m['name']),
              count: asInt(m['use_count']),
            ));
  }
}
