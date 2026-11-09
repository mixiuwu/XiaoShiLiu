import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 令牌 / 会话存储（基于 flutter_secure_storage 的弱安全存储）。
/// 仅保存 access/refresh 令牌与当前登录用户主键，业务用户资料由 Riverpod 缓存。
class TokenStore {
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  static const _uidKey = 'user_pk';

  final FlutterSecureStorage _storage;

  TokenStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  Future<String?> get accessToken => _storage.read(key: _accessKey);
  Future<String?> get refreshToken => _storage.read(key: _refreshKey);
  Future<String?> get userPk => _storage.read(key: _uidKey);

  Future<void> setTokens({
    required String accessToken,
    required String refreshToken,
    String? userPk,
  }) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
    if (userPk != null) {
      await _storage.write(key: _uidKey, value: userPk);
    }
  }

  Future<void> updateAccessToken(String accessToken) =>
      _storage.write(key: _accessKey, value: accessToken);

  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _uidKey);
  }

  Future<bool> get hasSession async => (await accessToken) != null;
}
