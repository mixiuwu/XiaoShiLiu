import '../../core/network/api_client.dart';
import '../../core/network/endpoints.dart';
import '../models/_json.dart';
import '_paged.dart';

/// 点赞目标类型。
class LikeTarget {
  static const int post = 1;
  static const int comment = 2;
}

/// 点赞 / 取消点赞（后端 toggle），返回操作后的点赞状态。
class LikeRepository {
  final ApiClient client;

  LikeRepository(this.client);

  Future<bool> toggle(int targetType, int targetId) async {
    final data = await client.post(Endpoints.likes, data: {
      'target_type': targetType,
      'target_id': targetId,
    });
    return asBool(asDataMap(data)['liked']);
  }

  Future<bool> togglePost(int postId) => toggle(LikeTarget.post, postId);
  Future<bool> toggleComment(int commentId) =>
      toggle(LikeTarget.comment, commentId);
}
