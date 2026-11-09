import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/network/endpoints.dart';
import '../models/comment.dart';
import '../models/page.dart';
import '_paged.dart';

/// 评论：顶级列表 / 子回复 / 发布 / 删除。点赞走 LikeRepository。
class CommentRepository {
  final ApiClient client;

  CommentRepository(this.client);

  Future<Paged<Comment>> listByPost(
    int postId, {
    int page = 1,
    int? limit,
    String sort = 'desc',
  }) async {
    final data =
        await client.get(Endpoints.postComments('$postId'), queryParameters: {
      'page': page,
      'limit': limit ?? AppConfig.defaultPageSize,
      'sort': sort,
    });
    return parsePaged(data, 'comments', Comment.fromJson);
  }

  /// 备用：通过 /api/comments?post_id= 获取顶级评论。
  Future<Paged<Comment>> list({
    required int postId,
    int page = 1,
    int? limit,
  }) async {
    final data = await client.get(Endpoints.comments, queryParameters: {
      'post_id': postId,
      'page': page,
      'limit': limit ?? AppConfig.defaultPageSize,
    });
    return parsePaged(data, 'comments', Comment.fromJson);
  }

  Future<Paged<Comment>> replies(
    int commentId, {
    int page = 1,
    int? limit,
  }) async {
    final data = await client
        .get(Endpoints.commentReplies('$commentId'), queryParameters: {
      'page': page,
      'limit': limit ?? AppConfig.defaultPageSize,
    });
    return parsePaged(data, 'comments', Comment.fromJson);
  }

  /// 发表评论 / 回复，返回新建的评论。
  Future<Comment> create({
    required int postId,
    required String content,
    int? parentId,
  }) async {
    final data = await client.post(Endpoints.comments, data: {
      'post_id': postId,
      'content': content,
      if (parentId != null) 'parent_id': parentId,
    });
    return Comment.fromJson(asDataMap(data));
  }

  Future<void> delete(int commentId) =>
      client.delete(Endpoints.comment('$commentId'));
}
