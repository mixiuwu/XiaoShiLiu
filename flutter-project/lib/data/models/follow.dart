import '_json.dart';

/// 关注关系状态（`/api/users/:id/follow-status`）。
/// buttonType: follow / unfollow / mutual / back / self。
class FollowStatus {
  final bool isFollowing;
  final bool isMutual;
  final String buttonType;

  const FollowStatus({
    this.isFollowing = false,
    this.isMutual = false,
    this.buttonType = 'follow',
  });

  bool get isSelf => buttonType == 'self';

  factory FollowStatus.fromJson(Map<String, dynamic> json) => FollowStatus(
        isFollowing: asBool(json['isFollowing'] ?? json['followed']),
        isMutual: asBool(json['isMutual']),
        buttonType: asString(json['buttonType'], 'follow'),
      );

  static const FollowStatus none = FollowStatus();
}
