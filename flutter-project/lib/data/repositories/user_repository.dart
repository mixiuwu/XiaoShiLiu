import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/network/endpoints.dart';
import '../models/follow.dart';
import '../models/page.dart';
import '../models/post.dart';
import '../models/stats.dart';
import '../models/user.dart';
import '_paged.dart';

/// 用户：主页资料 / 作品 / 收藏 / 喜欢 / 关注关系 / 统计 / 资料编辑。
/// 注意：所有 :id 路径参数均为「小石榴号」字符串，而非数字主键。
class UserRepository {
  final ApiClient client;

  UserRepository(this.client);

  Future<UserProfile> detail(String account) async {
    final data = await client.get(Endpoints.user(account));
    return UserProfile.fromJson(asDataMap(data));
  }

  Future<Paged<Post>> posts(
    String account, {
    int page = 1,
    int? limit,
    String? status,
    String? category,
    String? keyword,
    String sort = 'created_at',
  }) async {
    final data =
        await client.get(Endpoints.userPosts(account), queryParameters: {
      'page': page,
      'limit': limit ?? AppConfig.defaultPageSize,
      'sort': sort,
      if (status != null) 'status': status,
      if (category != null) 'category': category,
      if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
    });
    return parsePaged(data, 'posts', Post.fromJson);
  }

  Future<Paged<Post>> collections(String account,
      {int page = 1, int? limit}) async {
    final data =
        await client.get(Endpoints.userCollections(account), queryParameters: {
      'page': page,
      'limit': limit ?? AppConfig.defaultPageSize,
    });
    return parsePaged(data, 'collections', Post.fromJson);
  }

  Future<Paged<Post>> likes(String account, {int page = 1, int? limit}) async {
    final data =
        await client.get(Endpoints.userLikes(account), queryParameters: {
      'page': page,
      'limit': limit ?? AppConfig.defaultPageSize,
    });
    return parsePaged(data, 'posts', Post.fromJson);
  }

  Future<UserStats> stats(String account) async {
    final data = await client.get(Endpoints.userStats(account));
    return UserStats.fromJson(asDataMap(data));
  }

  Future<FollowStatus> followStatus(String account) async {
    final data = await client.get(Endpoints.followStatus(account));
    return FollowStatus.fromJson(asDataMap(data));
  }

  Future<void> follow(String account) => client.post(Endpoints.follow(account));
  Future<void> unfollow(String account) =>
      client.delete(Endpoints.follow(account));

  Future<Paged<UserProfile>> following(String account,
      {int page = 1, int? limit}) async {
    final data =
        await client.get(Endpoints.following(account), queryParameters: {
      'page': page,
      'limit': limit ?? AppConfig.defaultPageSize,
    });
    return parsePaged(data, 'following', UserProfile.fromJson);
  }

  Future<Paged<UserProfile>> followers(String account,
      {int page = 1, int? limit}) async {
    final data =
        await client.get(Endpoints.followers(account), queryParameters: {
      'page': page,
      'limit': limit ?? AppConfig.defaultPageSize,
    });
    return parsePaged(data, 'followers', UserProfile.fromJson);
  }

  /// 更新资料，返回后端回执（通常含更新后的用户信息）。
  Future<Map<String, dynamic>> updateProfile(
    String account, {
    String? nickname,
    String? avatar,
    String? bio,
    String? location,
    String? gender,
    String? zodiacSign,
    String? mbti,
    String? education,
    String? major,
    List<String>? interests,
  }) async {
    final data = await client.put(Endpoints.updateProfile(account), data: {
      if (nickname != null) 'nickname': nickname,
      if (avatar != null) 'avatar': avatar,
      if (bio != null) 'bio': bio,
      if (location != null) 'location': location,
      if (gender != null) 'gender': gender,
      if (zodiacSign != null) 'zodiac_sign': zodiacSign,
      if (mbti != null) 'mbti': mbti,
      if (education != null) 'education': education,
      if (major != null) 'major': major,
      if (interests != null) 'interests': interests,
    });
    return asDataMap(data);
  }

  /// 修改密码。
  Future<void> updatePassword(
          String account, String currentPassword, String newPassword) =>
      client.put(Endpoints.passwordUpdate(account), data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword
      });
}
