import 'dart:async';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/token_store.dart';
import 'endpoints.dart';

/// 鉴权拦截器：
/// - 请求：为非公开接口注入 `Authorization: Bearer <access>`。
/// - 响应：HTTP 401 且非公开接口 → 单飞刷新双令牌 → 用新令牌重试原请求一次；
///   刷新失败则清理会话并回调跳登录。
class AuthInterceptor extends Interceptor {
  final TokenStore tokenStore;

  /// 会话彻底失效（刷新失败）时的回调（通常清理 Riverpod 会话并跳转登录）。
  final Future<void> Function() onSessionExpired;

  /// 仅用于刷新与重试的旁路 Dio（不再挂本拦截器，避免递归）。
  late final Dio _bypassDio;

  Completer<String?>? _refreshCompleter;

  AuthInterceptor({
    required this.tokenStore,
    required this.onSessionExpired,
  }) {
    _bypassDio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBase,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        sendTimeout: AppConfig.sendTimeout,
        headers: {'Content-Type': 'application/json'},
      ),
    );
  }

  static const List<String> _publicPaths = [
    Endpoints.login,
    Endpoints.register,
    Endpoints.captcha,
    Endpoints.refresh,
    Endpoints.checkUserId,
    Endpoints.emailConfig,
    Endpoints.sendResetCode,
    Endpoints.verifyResetCode,
    Endpoints.resetPassword,
  ];

  bool _isPublic(String path) =>
      _publicPaths.any((p) => path == p || path.startsWith('$p?'));

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isPublic(options.path)) {
      final token = await tokenStore.accessToken;
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final status = err.response?.statusCode;
    final path = err.requestOptions.path;

    if (status == 401 && !_isPublic(path)) {
      final newToken = await _runRefresh();
      if (newToken != null) {
        try {
          final requestOptions = err.requestOptions
            ..headers['Authorization'] = 'Bearer $newToken';
          final retry = await _bypassDio.fetch(requestOptions);
          handler.resolve(retry);
          return;
        } on DioException catch (retryErr) {
          handler.next(retryErr);
          return;
        }
      }
      await tokenStore.clear();
      await onSessionExpired();
    }
    handler.next(err);
  }

  /// 单飞刷新：并发 401 共享同一次刷新，成功返回新 access token，失败返回 null。
  Future<String?> _runRefresh() async {
    final existing = _refreshCompleter;
    if (existing != null) return existing.future;

    final completer = Completer<String?>();
    _refreshCompleter = completer;
    try {
      final rt = await tokenStore.refreshToken;
      if (rt == null || rt.isEmpty) {
        completer.complete(null);
        return null;
      }
      final res = await _bypassDio.post(
        Endpoints.refresh,
        data: {'refresh_token': rt},
      );
      final body = res.data;
      final ok = body is Map && body['code'] == 200 && body['data'] is Map;
      if (!ok) {
        completer.complete(null);
        return null;
      }
      final data = body['data'] as Map;
      final access = data['access_token']?.toString();
      final refresh = data['refresh_token']?.toString();
      if (access == null || refresh == null) {
        completer.complete(null);
        return null;
      }
      await tokenStore.setTokens(accessToken: access, refreshToken: refresh);
      completer.complete(access);
      return access;
    } catch (_) {
      completer.complete(null);
      return null;
    } finally {
      _refreshCompleter = null;
    }
  }
}
