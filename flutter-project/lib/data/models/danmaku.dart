import '../../core/config/app_config.dart';
import '_json.dart';

/// 弹幕（danmaku），带视频时间点与颜色。
class Danmaku {
  final int id;
  final int postId;
  final int userId;
  final String nickname;
  final String avatar;
  final String content;
  final int offsetSec;
  final String color;
  final String? createdAt;

  const Danmaku({
    required this.id,
    required this.postId,
    required this.userId,
    required this.nickname,
    required this.avatar,
    required this.content,
    required this.offsetSec,
    required this.color,
    this.createdAt,
  });

  factory Danmaku.fromJson(Map<String, dynamic> json) {
    return Danmaku(
      id: asInt(json['id']),
      postId: asInt(json['post_id']),
      userId: asInt(json['user_id']),
      nickname: asString(json['nickname']),
      avatar: AppConfig.resolveMedia(asStringOrNull(json['avatar'])),
      content: asString(json['content']),
      offsetSec: asInt(json['offset_sec']),
      color: asString(json['color'], '#FFFFFF'),
      createdAt: asStringOrNull(json['created_at']),
    );
  }
}
