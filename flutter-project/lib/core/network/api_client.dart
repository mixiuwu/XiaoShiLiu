import 'dart:io';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/token_store.dart';
import 'api_exception.dart';
import 'auth_interceptor.dart';

/// 统一网络客户端：负责解包 `{code, message, data}`、把错误归一化为 [ApiException]。
/// 所有 repository 经此客户端拿到的即业务 `data`，UI 不感知包裹结构。
class ApiClient {
  late final Dio dio;
  final TokenStore tokenStore;

  ApiClient({
    required this.tokenStore,
    required Future<void> Function() onSessionExpired,
  }) {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBase,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        sendTimeout: AppConfig.sendTimeout,
        responseType: ResponseType.json,
        headers: {'Content-Type': 'application/json'},
      ),
    );
    dio.interceptors.add(AuthInterceptor(
        tokenStore: tokenStore, onSessionExpired: onSessionExpired));
  }

  // ---- REST verbs ----
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) =>
      _run(() => dio.get<dynamic>(
            path,
            queryParameters: queryParameters,
            cancelToken: cancelToken,
          ));

  Future<dynamic> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) =>
      _run(() => dio.post<dynamic>(
            path,
            data: data,
            queryParameters: queryParameters,
            cancelToken: cancelToken,
          ));

  Future<dynamic> put(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) =>
      _run(() => dio.put<dynamic>(
            path,
            data: data,
            queryParameters: queryParameters,
            cancelToken: cancelToken,
          ));

  Future<dynamic> delete(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) =>
      _run(() => dio.delete<dynamic>(
            path,
            data: data,
            queryParameters: queryParameters,
            cancelToken: cancelToken,
          ));

  // ---- Multipart upload ----
  Future<dynamic> upload(
    String path, {
    required String field,
    required File file,
    Map<String, dynamic>? extraFields,
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    final formData = FormData.fromMap({
      field: await MultipartFile.fromFile(file.path),
      ...?extraFields,
    });
    return _run(() => dio.post<dynamic>(
          path,
          data: formData,
          onSendProgress: onSendProgress,
          cancelToken: cancelToken,
        ));
  }

  Future<dynamic> uploadFiles(
    String path, {
    required String field,
    required List<File> files,
    Map<String, dynamic>? extraFields,
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    final parts = await Future.wait(
      files.map((f) => MultipartFile.fromFile(f.path)),
    );
    // FormData.fromMap 会把 List 值展开为同名多字段（field 重复），实现多文件上传。
    final formData = FormData.fromMap({
      field: parts,
      ...?extraFields,
    });
    return _run(() => dio.post<dynamic>(
          path,
          data: formData,
          onSendProgress: onSendProgress,
          cancelToken: cancelToken,
        ));
  }

  Future<dynamic> _run(
    Future<Response<dynamic>> Function() action,
  ) async {
    try {
      final res = await action();
      return _unwrap(res.data);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// 成功响应 HTTP 200，body 形如 `{code:200, message, data?}`；返回 `data`。
  dynamic _unwrap(dynamic body) {
    if (body is Map && body.containsKey('code')) {
      final code = body['code'];
      if (code == 200) return body['data'];
      throw ApiException(
        code is int ? code : 500,
        (body['message'] ?? '请求失败').toString(),
      );
    }
    return body;
  }

  ApiException _mapError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data.containsKey('code')) {
      final code = data['code'] is int
          ? data['code'] as int
          : (e.response?.statusCode ?? 500);
      return ApiException(code, (data['message'] ?? '请求失败').toString());
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(-1, '连接超时，请检查网络', isNetwork: true);
      case DioExceptionType.connectionError:
        return const ApiException(-1, '无法连接服务器，请确认后端已启动', isNetwork: true);
      case DioExceptionType.cancel:
        return const ApiException(-2, '请求已取消', isNetwork: true);
      default:
        return ApiException(
          e.response?.statusCode ?? -1,
          e.message ?? '网络异常',
          isNetwork: true,
        );
    }
  }
}
