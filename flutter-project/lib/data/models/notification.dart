import '../../core/config/app_config.dart';
import '_json.dart';

/// 消息中心通知。type: 1/2 点赞，3 收藏，4/5/7/8 评论，6 关注。
class AppNotification {
  final int id;
  final int type;
  final String title;
  final int targetId; // 关联帖子 id
  final int? commentId;
  final bool isRead;
  final String? createdAt;

  // 发送者
  final int fromUserId; // 数字主键
  final String fromAccount; // 小石榴号
  final String fromNickname;
  final String fromAvatar;
  final bool fromVerified;

  // 关联内容
  final String? postTitle;
  final int? postType;
  final String? postImage;
  final String? commentContent;
  final String? parentCommentContent;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.targetId,
    this.commentId,
    this.isRead = false,
    this.createdAt,
    required this.fromUserId,
    required this.fromAccount,
    required this.fromNickname,
    required this.fromAvatar,
    this.fromVerified = false,
    this.postTitle,
    this.postType,
    this.postImage,
    this.commentContent,
    this.parentCommentContent,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: asInt(json['id']),
      type: asInt(json['type']),
      title: asString(json['title']),
      targetId: asInt(json['target_id']),
      commentId: json['comment_id'] == null ? null : asInt(json['comment_id']),
      isRead: asBool(json['is_read']),
      createdAt: asStringOrNull(json['created_at']),
      fromUserId: asInt(json['from_user_auto_id']),
      fromAccount: asString(json['from_user_id']),
      fromNickname: asString(json['from_nickname']),
      fromAvatar: AppConfig.resolveMedia(asStringOrNull(json['from_avatar'])),
      fromVerified: asBool(json['from_verified'] ?? json['verified']),
      postTitle: asStringOrNull(json['post_title']),
      postType: json['post_type'] == null ? null : asInt(json['post_type']),
      postImage: AppConfig.resolveMedia(asStringOrNull(json['post_image'])),
      commentContent: asStringOrNull(json['comment_content']),
      parentCommentContent: asStringOrNull(json['parent_comment_content']),
    );
  }
}

/// 按类型分组的未读数量。
class UnreadCounts {
  final int comments;
  final int likes;
  final int collections;
  final int follows;
  final int total;

  const UnreadCounts({
    this.comments = 0,
    this.likes = 0,
    this.collections = 0,
    this.follows = 0,
    this.total = 0,
  });

  factory UnreadCounts.fromJson(Map<String, dynamic> json) => UnreadCounts(
        comments: asInt(json['comments']),
        likes: asInt(json['likes']),
        collections: asInt(json['collections']),
        follows: asInt(json['follows']),
        total: asInt(json['total']),
      );
}
