import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/models/danmaku.dart';
import 'danmaku_settings.dart';

/// 弹幕滚动层：以视频播放进度为时间轴，将 [items] 按 offsetSec 出现并从右向左滚动。
/// 显示样式（行数/透明度/速度/字号/彩色/皮肤/角色/顶部）由 [settings] 驱动。
class DanmakuLayer extends StatelessWidget {
  final List<Danmaku> items;
  final ValueListenable<Duration> progress;
  final DanmakuSettings settings;
  final bool visible;

  const DanmakuLayer({
    super.key,
    required this.items,
    required this.progress,
    required this.settings,
    this.visible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible || items.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: Listenable.merge([progress, settings]),
        builder: (_, __) => CustomPaint(
          size: Size.infinite,
          painter: _DanmakuPainter(
              items, progress.value.inMilliseconds / 1000, settings),
        ),
      ),
    );
  }
}

class _DanmakuPainter extends CustomPainter {
  final List<Danmaku> items;
  final double nowSec;
  final DanmakuSettings cfg;
  _DanmakuPainter(this.items, this.nowSec, this.cfg);

  static const List<Color> _rainbow = [
    Color(0xFFFF5964),
    Color(0xFFFFC107),
    Color(0xFF4CD964),
    Color(0xFF22E1D5),
    Color(0xFF5AC8FA),
    Color(0xFFFF2E63),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // 按时间点升序，保证同帧绘制顺序稳定
    final sorted = [...items]
      ..sort((a, b) => a.offsetSec.compareTo(b.offsetSec));

    final laneHeight = size.height * (cfg.fontSize >= 20 ? 0.085 : 0.07);
    final topPad = size.height * 0.08;
    final lanes = cfg.lanes.clamp(1, 8);

    for (final d in sorted) {
      final local = nowSec - d.offsetSec;
      if (local < 0) continue;

      final baseColor = _parseColor(d.color).withOpacity(cfg.opacity);
      final tp = _buildPainter(d, baseColor);

      if (cfg.mode == DanmakuMode.top) {
        const dur = 5.0;
        if (local > dur) continue;
        final lane = d.id % lanes;
        final y = topPad + lane * laneHeight;
        final x = (size.width - tp.width) / 2;
        double alpha = 1.0;
        if (local < 0.3) {
          alpha = local / 0.3;
        } else if (local > dur - 0.5) {
          alpha = (dur - local) / 0.5;
        }
        _drawOne(canvas, d, tp, Offset(x, y), baseColor,
            (alpha * cfg.opacity).clamp(0.0, 1.0));
        continue;
      }

      final lane = d.id % lanes;
      final x = size.width - local * cfg.speed - tp.width;
      if (x > size.width || x < -tp.width) continue;
      final y = topPad + lane * laneHeight;
      _drawOne(canvas, d, tp, Offset(x, y), baseColor, cfg.opacity);
    }
  }

  TextPainter _buildPainter(Danmaku d, Color baseColor) {
    final children = <InlineSpan>[];
    if (cfg.showRole && d.nickname.isNotEmpty) {
      children.add(TextSpan(
        text: '${d.nickname}: ',
        style: TextStyle(
          color: Colors.white.withOpacity(0.78 * cfg.opacity),
          fontSize: cfg.fontSize * 0.85,
          fontWeight: FontWeight.w500,
          shadows: const [Shadow(blurRadius: 3, color: Colors.black87)],
        ),
      ));
    }
    children.add(TextSpan(text: d.content, style: _contentStyle(baseColor)));
    return TextPainter(
      text: TextSpan(children: children),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  TextStyle _contentStyle(Color color) {
    final weight = cfg.skin == 1 ? FontWeight.w700 : FontWeight.w600;
    List<Shadow> shadows;
    switch (cfg.skin) {
      case 1: // 描边
        shadows = const [
          Shadow(offset: Offset(-1, -1), color: Colors.black),
          Shadow(offset: Offset(1, -1), color: Colors.black),
          Shadow(offset: Offset(-1, 1), color: Colors.black),
          Shadow(offset: Offset(1, 1), color: Colors.black),
        ];
        break;
      case 2: // 发光
        shadows = [Shadow(blurRadius: 10, color: color)];
        break;
      default:
        shadows = const [Shadow(blurRadius: 3, color: Colors.black87)];
    }
    return TextStyle(
      color: color,
      fontSize: cfg.fontSize,
      fontWeight: weight,
      shadows: shadows,
    );
  }

  void _drawOne(Canvas canvas, Danmaku d, TextPainter tp, Offset pos,
      Color color, double alpha) {
    // 背景胶囊
    final bgAlpha = (cfg.skin == 3 ? 0.42 : 0.18) * alpha;
    final radius = cfg.skin == 3 ? 10.0 : 6.0;
    final pad = cfg.skin == 3 ? 8.0 : 6.0;
    final bg = Paint()..color = Colors.black.withOpacity(bgAlpha);
    final rect = Rect.fromLTWH(
        pos.dx - pad, pos.dy - 2, tp.width + pad * 2, tp.height + 4);
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)), bg);

    if (cfg.colorful) {
      // 彩虹渐变前景：整条弹幕（含昵称）统一铺渐变
      final full = (cfg.showRole && d.nickname.isNotEmpty)
          ? '${d.nickname}: ${d.content}'
          : d.content;
      final fg = Paint()
        ..shader = const LinearGradient(colors: _rainbow)
            .createShader(Rect.fromLTWH(pos.dx, pos.dy, tp.width, tp.height));
      final ctp = TextPainter(
        text: TextSpan(
          text: full,
          style: TextStyle(
            foreground: fg,
            fontSize: cfg.fontSize,
            fontWeight: FontWeight.w700,
            shadows: const [Shadow(blurRadius: 3, color: Colors.black87)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      ctp.paint(canvas, pos);
    } else {
      tp.paint(canvas, pos);
    }
  }

  Color _parseColor(String hex) {
    var s = hex.replaceFirst('#', '');
    if (s.length == 6) s = 'FF$s';
    final v = int.tryParse(s, radix: 16);
    if (v == null) return Colors.white;
    return Color(v);
  }

  @override
  bool shouldRepaint(covariant _DanmakuPainter old) =>
      old.nowSec != nowSec ||
      old.items.length != items.length ||
      old.cfg != cfg;
}
