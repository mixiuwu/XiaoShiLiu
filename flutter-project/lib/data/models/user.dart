import '../../core/config/app_config.dart';
import '_json.dart';

/// 封禁信息（个人主页附带）。
class BanInfo {
  final String? endTime;
  final String reason;
  final String? createdAt;

  const BanInfo({this.endTime, required this.reason, this.createdAt});

  factory BanInfo.fromJson(Map<String, dynamic> json) => BanInfo(
        endTime: asStringOrNull(json['end_time']),
        reason: asString(json['reason']),
        createdAt: asStringOrNull(json['created_at']),
      );
}

/// 用户资料：适配 `/api/auth/me`、`/api/users/:id`、登录/注册返回的 user 子集。
class UserProfile {
  final int id; // 数字主键
  final String account; // 小石榴号（user_id 字符串）
  final String nickname;
  final String avatar;
  final String? bio;
  final String? location;
  final String? email;
  final String? gender;
  final String? zodiacSign;
  final String? mbti;
  final String? education;
  final String? major;
  final List<String> interests;
  final int followCount;
  final int fansCount;
  final int likeCount;
  final int postCount;
  final bool verified;
  final String? verifiedTitle;
  final bool isVip;
  final int vipLevel;
  final String? createdAt;
  final BanInfo? ban;

  const UserProfile({
    required this.id,
    required this.account,
    required this.nickname,
    required this.avatar,
    this.bio,
    this.location,
    this.email,
    this.gender,
    this.zodiacSign,
    this.mbti,
    this.education,
    this.major,
    this.interests = const [],
    this.followCount = 0,
    this.fansCount = 0,
    this.likeCount = 0,
    this.postCount = 0,
    this.verified = false,
    this.verifiedTitle,
    this.isVip = false,
    this.vipLevel = 0,
    this.createdAt,
    this.ban,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final banMap = asMap(json['ban']);
    return UserProfile(
      id: asInt(json['id']),
      account: asString(json['user_id'] ?? json['author_account']),
      nickname: asString(json['nickname']),
      avatar: AppConfig.resolveMedia(
          asStringOrNull(json['avatar'] ?? json['user_avatar'])),
      bio: asStringOrNull(json['bio']),
      location: asStringOrNull(json['location']),
      email: asStringOrNull(json['email']),
      gender: asStringOrNull(json['gender']),
      zodiacSign: asStringOrNull(json['zodiac_sign']),
      mbti: asStringOrNull(json['mbti']),
      education: asStringOrNull(json['education']),
      major: asStringOrNull(json['major']),
      interests: asStringList(json['interests']),
      followCount: asInt(json['follow_count']),
      fansCount: asInt(json['fans_count']),
      likeCount: asInt(json['like_count']),
      postCount: asInt(json['post_count']),
      verified: asBool(json['verified']),
      verifiedTitle: asStringOrNull(json['verified_title']),
      isVip: asBool(json['is_vip']),
      vipLevel: asInt(json['vip_level']),
      createdAt: asStringOrNull(json['created_at']),
      ban: banMap == null ? null : BanInfo.fromJson(banMap),
    );
  }
}
