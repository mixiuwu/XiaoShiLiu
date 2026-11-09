/// 时间与数字格式化工具。
class TimeFormat {
  TimeFormat._();

  /// 相对时间：刚刚 / x分钟前 / x小时前 / x天前 / yyyy-MM-dd。
  static String relative(Object? value) {
    final dt = parse(value);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.isNegative) return '刚刚';
    final minutes = diff.inMinutes;
    if (minutes < 1) return '刚刚';
    if (minutes < 60) return '$minutes分钟前';
    final hours = diff.inHours;
    if (hours < 24) return '$hours小时前';
    final days = diff.inDays;
    if (days < 30) return '$days天前';
    return date(dt);
  }

  /// 解析后端时间字段（ISO 字符串 / DateTime / MySQL DATETIME 文本）。
  static DateTime? parse(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    final s = value.toString();
    if (s.isEmpty) return null;
    // MySQL "2024-05-01 12:30:00" -> ISO 兼容
    final normalized = s.contains('T') ? s : s.replaceFirst(' ', 'T');
    return DateTime.tryParse(normalized)?.toLocal();
  }

  /// yyyy-MM-dd
  static String date(DateTime dt) =>
      '${dt.year}-${_two(dt.month)}-${_two(dt.day)}';

  /// yyyy-MM-dd HH:mm
  static String dateTime(DateTime dt) =>
      '${date(dt)} ${_two(dt.hour)}:${_two(dt.minute)}';

  /// 大数字缩写：1.2w / 3.4k
  static String compact(num? value) {
    final n = value?.toInt() ?? 0;
    if (n < 1000) return '$n';
    if (n < 10000) {
      final k = n / 1000;
      return '${k.toStringAsFixed(1)}k';
    }
    final w = n / 10000;
    return '${w.toStringAsFixed(1)}w';
  }

  /// 秒 -> mm:ss
  static String duration(int seconds) {
    final m = (seconds ~/ 60);
    final s = seconds % 60;
    return '${_two(m)}:${_two(s)}';
  }

  static String _two(int v) => v.toString().padLeft(2, '0');
}
