import '../../core/network/api_client.dart';
import '../../core/network/endpoints.dart';
import '../../core/storage/token_store.dart';
import '../models/auth.dart';
import '../models/user.dart';

/// 鉴权：登录 / 注册 / 验证码 / 当前用户 / 登出。
class AuthRepository {
  final ApiClient client;
  final TokenStore tokenStore;

  AuthRepository(this.client, this.tokenStore);

  /// 小石榴号是否可用（未被占用）。
  Future<bool> isUserIdAvailable(String userId) async {
    final data = await client
        .get(Endpoints.checkUserId, queryParameters: {'user_id': userId});
    return data is Map && data['isUnique'] == true;
  }

  /// 邮件功能是否启用（决定注册是否需要邮箱验证码）。
  Future<bool> isEmailEnabled() async {
    final data = await client.get(Endpoints.emailConfig);
    return data is Map && data['emailEnabled'] == true;
  }

  /// 发送邮箱验证码（注册 / 绑定邮箱）。
  Future<void> sendEmailCode(String email) async {
    await client.post(Endpoints.sendEmailCode, data: {'email': email});
  }

  /// 绑定 / 换绑邮箱，返回绑定后的邮箱地址。
  Future<String> bindEmail({
    required String email,
    required String emailCode,
  }) async {
    final data = await client.post(Endpoints.bindEmail, data: {
      'email': email,
      'emailCode': emailCode,
    });
    return data is Map ? (data['email'] ?? email).toString() : email;
  }

  /// 注册成功后自动落库令牌，返回用户资料。
  Future<UserProfile> register({
    required String userId,
    required String nickname,
    required String password,
    String? email,
    String? emailCode,
  }) async {
    final data = await client.post(Endpoints.register, data: {
      'user_id': userId,
      'nickname': nickname,
      'password': password,
      if (email != null && email.isNotEmpty) 'email': email,
      if (emailCode != null && emailCode.isNotEmpty) 'emailCode': emailCode,
    });
    return _persist(AuthResult.fromJson(_asMap(data)));
  }

  Future<UserProfile> login(String userId, String password) async {
    final data = await client
        .post(Endpoints.login, data: {'user_id': userId, 'password': password});
    return _persist(AuthResult.fromJson(_asMap(data)));
  }

  /// 拉取当前登录用户资料。
  Future<UserProfile> fetchMe() async {
    final data = await client.get(Endpoints.me);
    return UserProfile.fromJson(_asMap(data));
  }

  /// 退出登录：尽力通知后端，本地令牌始终清除。
  Future<void> logout() async {
    try {
      await client.post(Endpoints.logout);
    } catch (_) {}
    await tokenStore.clear();
  }

  Future<UserProfile> _persist(AuthResult result) async {
    await tokenStore.setTokens(
      accessToken: result.tokens.accessToken,
      refreshToken: result.tokens.refreshToken,
      userPk: result.user['id']?.toString(),
    );
    return UserProfile.fromJson(result.user);
  }

  Map<String, dynamic> _asMap(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
}
