import '../../core/config/app_config.dart';
import '_json.dart';

/// 评论（含子评论回复）。
class Comment {
  final int id;
  final int postId;
  final int userId; // 数字主键
  final String userAccount; // 小石榴号
  final String nickname;
  final String avatar;
  final String? location;
  final bool verified;
  final int? parentId;
  final String content;
  final int likeCount;
  final bool liked;
  final int replyCount;
  final String? createdAt;

  const Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userAccount,
    required this.nickname,
    required this.avatar,
    this.location,
    this.verified = false,
    this.parentId,
    required this.content,
    this.likeCount = 0,
    this.liked = false,
    this.replyCount = 0,
    this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: asInt(json['id']),
      postId: asInt(json['post_id']),
      userId: asInt(json['user_auto_id'] ?? json['user_id']),
      userAccount: asString(json['user_display_id']),
      nickname: asString(json['nickname']),
      avatar: AppConfig.resolveMedia(asStringOrNull(json['user_avatar'])),
      location: asStringOrNull(json['user_location']),
      verified: asBool(json['verified']),
      parentId: json['parent_id'] == null ? null : asInt(json['parent_id']),
      content: asString(json['content']),
      likeCount: asInt(json['like_count']),
      liked: asBool(json['liked']),
      replyCount: asInt(json['reply_count']),
      createdAt: asStringOrNull(json['created_at']),
    );
  }

  /// 仅变更点赞状态 / 计数（评论点赞乐观更新用）。
  Comment copyWithLike({bool? liked, int? likeCount}) => Comment(
        id: id,
        postId: postId,
        userId: userId,
        userAccount: userAccount,
        nickname: nickname,
        avatar: avatar,
        location: location,
        verified: verified,
        parentId: parentId,
        content: content,
        likeCount: likeCount ?? this.likeCount,
        liked: liked ?? this.liked,
        replyCount: replyCount,
        createdAt: createdAt,
      );
}
