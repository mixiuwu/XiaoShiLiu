import '../../core/config/app_config.dart';
import '_json.dart';

/// 令牌包（登录/注册/刷新返回的 tokens）。
class TokenBundle {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;

  const TokenBundle({
    required this.accessToken,
    required this.refreshToken,
    this.expiresIn = 3600,
  });

  factory TokenBundle.fromJson(Map<String, dynamic> json) => TokenBundle(
        accessToken: asString(json['access_token']),
        refreshToken: asString(json['refresh_token']),
        expiresIn: asInt(json['expires_in'], 3600),
      );
}

/// 登录 / 注册返回结果：用户资料 + 双令牌。
class AuthResult {
  final Map<String, dynamic> user;
  final TokenBundle tokens;

  const AuthResult({required this.user, required this.tokens});

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
        user: asMap(json['user']) ?? const {},
        tokens: TokenBundle.fromJson(asMap(json['tokens']) ?? const {}),
      );
}

/// 媒体上传结果（/api/upload 与 /api/upload/multiple）。
/// 兼容 code 封装返回 `{url}` 及 multiple 的 `{uploaded:[{url}]}` 两种形态。
class UploadResult {
  final List<String> urls;

  const UploadResult({required this.urls});

  String get firstUrl => urls.isEmpty ? '' : urls.first;

  factory UploadResult.fromJson(dynamic json) {
    if (json is Map) {
      final m = Map<String, dynamic>.from(json);
      // 单文件：data:{url} 或 data:{file_url}
      final single = asStringOrNull(m['url'] ?? m['file_url']);
      if (single != null) {
        return UploadResult(urls: [AppConfig.resolveMedia(single)]);
      }
      // 多文件：data:{uploaded:[{url}]}
      final uploaded = asMapList(m['uploaded']);
      if (uploaded.isNotEmpty) {
        return UploadResult(
          urls: uploaded
              .map((e) => AppConfig.resolveMedia(asStringOrNull(e['url'])))
              .whereType<String>()
              .toList(),
        );
      }
    }
    return const UploadResult(urls: []);
  }
}
