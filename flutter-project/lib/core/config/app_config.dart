/// 全局应用配置
///
/// [apiBase] 默认指向线上地址 `https://git.aodde.com`。
/// 真机联调时通过 `--dart-define=API_BASE=http://<局域网IP>:3001` 覆盖。
class AppConfig {
  AppConfig._();

  static const String apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'https://git.aodde.com',
  );

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);
  static const Duration sendTimeout = Duration(seconds: 30);

  /// 分页默认每页条数
  static const int defaultPageSize = 20;

  /// 将后端返回的媒体地址解析为当前设备可访问的绝对地址。
  /// - 绝对 http(s) 且 host 为 localhost/127.0.0.1 时，改写为 [apiBase] 的 host（模拟器/真机可达）。
  /// - 以 `/` 开头的相对路径拼接 [apiBase]。
  /// - 其余原样返回。
  static String resolveMedia(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) {
      final uri = Uri.parse(url);
      if (uri.host == 'localhost' || uri.host == '127.0.0.1') {
        final base = Uri.parse(apiBase);
        return uri
            .replace(scheme: base.scheme, host: base.host, port: base.port)
            .toString();
      }
      return url;
    }
    if (url.startsWith('/')) return '$apiBase$url';
    return url;
  }
}
