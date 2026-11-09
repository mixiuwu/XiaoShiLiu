import '../../core/network/api_client.dart';
import '../../core/network/endpoints.dart';
import '../models/danmaku.dart';
import '_paged.dart';

/// 弹幕：按视频时间点获取 / 发送。
class DanmakuRepository {
  final ApiClient client;

  DanmakuRepository(this.client);

  Future<List<Danmaku>> list(String postId) async {
    final data = await client.get(Endpoints.danmaku(postId));
    return parseList(data, Danmaku.fromJson);
  }

  Future<Danmaku> send(
    String postId, {
    required String content,
    int offsetSec = 0,
    String color = '#FFFFFF',
  }) async {
    final data = await client.post(Endpoints.danmaku(postId), data: {
      'content': content,
      'offset_sec': offsetSec,
      'color': color,
    });
    return Danmaku.fromJson(asDataMap(data));
  }
}
