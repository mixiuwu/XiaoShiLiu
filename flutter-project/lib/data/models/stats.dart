import '_json.dart';

/// 创作数据看板 / 个人主页统计。
class UserStats {
  final int followCount;
  final int fansCount;
  final int postCount;
  final int likeCount;
  final int collectCount;
  final int likesAndCollects;
  final int weeklyViews;
  final int receivedLikeCount;
  final int draftCount;

  const UserStats({
    this.followCount = 0,
    this.fansCount = 0,
    this.postCount = 0,
    this.likeCount = 0,
    this.collectCount = 0,
    this.likesAndCollects = 0,
    this.weeklyViews = 0,
    this.receivedLikeCount = 0,
    this.draftCount = 0,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) => UserStats(
        followCount: asInt(json['follow_count']),
        fansCount: asInt(json['fans_count']),
        postCount: asInt(json['post_count']),
        likeCount: asInt(json['like_count']),
        collectCount: asInt(json['collect_count']),
        likesAndCollects: asInt(json['likes_and_collects']),
        weeklyViews: asInt(json['weekly_views']),
        receivedLikeCount: asInt(json['received_like_count']),
        draftCount: asInt(json['draft_count']),
      );
}
