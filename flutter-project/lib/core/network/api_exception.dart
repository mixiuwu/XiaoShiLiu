/// 统一业务异常：由后端 `{code, message}` 错误体或网络故障归一化而来。
class ApiException implements Exception {
  final int code;
  final String message;

  /// 标记是否为网络层错误（超时/断网/无法解析），用于 UI 区分展示。
  final bool isNetwork;

  const ApiException(
    this.code,
    this.message, {
    this.isNetwork = false,
  });

  static const int unauthorized = 401;
  static const int notFound = 404;
  static const int conflict = 409;
  static const int validationError = 400;
  static const int serverError = 500;

  bool get isUnauthorized => code == unauthorized;
  bool get isConflict => code == conflict;

  @override
  String toString() => 'ApiException($code): $message';
}
