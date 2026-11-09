import 'package:flutter/material.dart';

/// 小石榴深色霓虹配色（取自 UI小石榴.sketch）
class AppColors {
  AppColors._();

  // 背景
  static const Color background = Color(0xFF121212);
  static const Color pureBlack = Color(0xFF000000);
  static const Color surface = Color(0xFF1C1C1E);
  static const Color surfaceAlt = Color(0xFF242426);
  static const Color divider = Color(0xFF2E2E30);

  // 强调色
  static const Color primary = Color(0xFFFF2E63); // 玫红
  static const Color cyan = Color(0xFF22E1D5); // 弹幕 / 次强调
  static const Color purple = Color(0xFF6A5CFF); // VIP / 会员

  // 文本
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB4B4B4);
  static const Color textTertiary = Color(0xFF7A7A7A);

  // 语义色
  static const Color coin = Color(0xFFFFC94D); // 金币
  static const Color success = Color(0xFF33D9B1);
  static const Color danger = Color(0xFFFF5A5A);

  /// 主按钮霓虹渐变
  static const LinearGradient neonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [primary, purple],
  );

  /// 发光阴影
  static List<BoxShadow> glow(Color color, {double blur = 18, double y = 0}) =>
      [
        BoxShadow(
          color: color.withOpacity(0.45),
          blurRadius: blur,
          offset: Offset(0, y),
        ),
      ];
}
