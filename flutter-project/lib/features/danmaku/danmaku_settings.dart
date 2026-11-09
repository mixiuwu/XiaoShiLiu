import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';

/// 弹幕展示模式：滚动 / 顶部固定。
enum DanmakuMode { scroll, top }

/// 弹幕皮肤预设（索引与 [DanmakuSettings.skin] 对应）。
const List<String> kDanmakuSkins = ['默认', '描边', '发光', '胶囊'];

/// 弹幕配色选择（十六进制字符串）。
const List<String> kDanmakuPalette = [
  '#FFFFFF',
  '#22E1D5',
  '#FF2E63',
  '#FFC94D',
  '#6A5CFF',
];

/// 十六进制字符串解析为 Color（供配色预览）。
Color colorFromHex(String hex) {
  var s = hex.replaceFirst('#', '');
  if (s.length == 6) s = 'FF$s';
  final v = int.tryParse(s, radix: 16);
  return v == null ? Colors.white : Color(v);
}

/// 弹幕工具箱设置：全局共享，作为 Listenable 驱动 DanmakuLayer 重绘。
class DanmakuSettings extends ChangeNotifier {
  int _lanes = 3; // 显示行数
  double _opacity = 1.0; // 0.3 ~ 1.0
  double _speed = 150; // px/s（滚动速度）
  double _fontSize = 15; // 字号
  bool _colorful = false; // 彩色弹幕
  int _skin = 0; // 弹幕皮肤索引
  bool _showRole = false; // 弹幕角色（显示昵称）
  DanmakuMode _mode = DanmakuMode.scroll; // 顶部弹幕
  String _color = kDanmakuPalette.first; // 弹幕字体颜色

  int get lanes => _lanes;
  double get opacity => _opacity;
  double get speed => _speed;
  double get fontSize => _fontSize;
  bool get colorful => _colorful;
  int get skin => _skin;
  bool get showRole => _showRole;
  DanmakuMode get mode => _mode;
  String get color => _color;

  set lanes(int v) => _set(() => _lanes = v);
  set opacity(double v) => _set(() => _opacity = v);
  set speed(double v) => _set(() => _speed = v);
  set fontSize(double v) => _set(() => _fontSize = v);
  set colorful(bool v) => _set(() => _colorful = v);
  set skin(int v) => _set(() => _skin = v);
  set showRole(bool v) => _set(() => _showRole = v);
  set mode(DanmakuMode v) => _set(() => _mode = v);
  set color(String v) => _set(() => _color = v);

  void _set(void Function() apply) {
    apply();
    notifyListeners();
  }

  void reset() {
    _lanes = 3;
    _opacity = 1.0;
    _speed = 150;
    _fontSize = 15;
    _colorful = false;
    _skin = 0;
    _showRole = false;
    _mode = DanmakuMode.scroll;
    _color = kDanmakuPalette.first;
    notifyListeners();
  }
}

final danmakuSettingsProvider =
    ChangeNotifierProvider<DanmakuSettings>((_) => DanmakuSettings());

/// 从右侧滑出「弹幕工具箱」（背景半透明）。
Future<void> showDanmakuToolbox(BuildContext context) {
  return showGeneralDialog(
    context: context,
    barrierLabel: 'danmaku_toolbox',
    barrierDismissible: true,
    barrierColor: Colors.black.withOpacity(0.35),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (_, __, ___) => const DanmakuToolboxPanel(),
    transitionBuilder: (_, anim, __, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return SlideTransition(
        position:
            Tween(begin: const Offset(1, 0), end: Offset.zero).animate(curved),
        child: child,
      );
    },
  );
}

/// 弹幕工具箱右侧面板：弹幕展示（行数/透明度/速度/字号/字体颜色）+ 弹幕类型（彩色/皮肤/角色/顶部）。
class DanmakuToolboxPanel extends ConsumerWidget {
  /// 关闭回调；为空时使用 Navigator.pop（全屏弹层模式）。
  final VoidCallback? onClose;

  /// 紧凑模式：详情页内嵌播放器用（尺寸更小、背景不透明）；
  /// 全屏对话框保持原尺寸、半透明背景。
  final bool compact;
  const DanmakuToolboxPanel({super.key, this.onClose, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(danmakuSettingsProvider);
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: compact ? 240.0 : 288.0,
        height: double.infinity,
        child: Material(
          color: compact ? Colors.black : Colors.black.withOpacity(0.55),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: compact
                      ? const EdgeInsets.fromLTRB(12, 8, 6, 2)
                      : const EdgeInsets.fromLTRB(16, 12, 8, 4),
                  child: Row(
                    children: [
                      Text('弹幕工具箱',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: compact ? 14.0 : 16.0,
                              fontWeight: FontWeight.w700)),
                      const Spacer(),
                      TextButton(
                        onPressed: s.reset,
                        child: const Text('重置',
                            style: TextStyle(color: AppColors.primary)),
                      ),
                      IconButton(
                        onPressed: onClose ?? () => Navigator.of(context).pop(),
                        visualDensity: VisualDensity.compact,
                        color: Colors.white70,
                        icon: const Icon(Icons.close, size: 20),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: compact
                        ? const EdgeInsets.fromLTRB(12, 2, 12, 10)
                        : const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionLabel('弹幕展示', compact: compact),
                        _SegRow(
                          compact: compact,
                          label: '行数',
                          items: const ['1', '2', '3', '4', '5'],
                          index: (s.lanes - 1).clamp(0, 4),
                          onChanged: (i) => s.lanes = i + 1,
                        ),
                        _SliderRow(
                          compact: compact,
                          label: '透明度',
                          value: s.opacity,
                          min: 0.3,
                          max: 1.0,
                          display: '${(s.opacity * 100).round()}%',
                          onChanged: (v) => s.opacity = v,
                        ),
                        _SegRow(
                          compact: compact,
                          label: '速度',
                          items: const ['慢', '正常', '快'],
                          index: s.speed <= 120
                              ? 0
                              : s.speed >= 200
                                  ? 2
                                  : 1,
                          onChanged: (i) => s.speed = [100.0, 150.0, 220.0][i],
                        ),
                        _SegRow(
                          compact: compact,
                          label: '字号',
                          items: const ['小', '中', '大'],
                          index: s.fontSize <= 12
                              ? 0
                              : s.fontSize >= 20
                                  ? 2
                                  : 1,
                          onChanged: (i) => s.fontSize = [12.0, 15.0, 20.0][i],
                        ),
                        _ColorRow(
                          compact: compact,
                          current: s.color,
                          onPick: (hex) => s.color = hex,
                        ),
                        _SectionLabel('弹幕类型', compact: compact),
                        _SwitchRow(
                          compact: compact,
                          label: '彩色弹幕',
                          desc: '彩虹渐变配色',
                          value: s.colorful,
                          onChanged: (v) => s.colorful = v,
                        ),
                        _SegRow(
                          compact: compact,
                          label: '弹幕皮肤',
                          items: kDanmakuSkins,
                          index: s.skin,
                          onChanged: (i) => s.skin = i,
                        ),
                        _SwitchRow(
                          compact: compact,
                          label: '弹幕角色',
                          desc: '显示发送者昵称',
                          value: s.showRole,
                          onChanged: (v) => s.showRole = v,
                        ),
                        _SwitchRow(
                          compact: compact,
                          label: '顶部弹幕',
                          desc: '置顶固定显示（不滚动）',
                          value: s.mode == DanmakuMode.top,
                          onChanged: (v) =>
                              s.mode = v ? DanmakuMode.top : DanmakuMode.scroll,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final bool compact;
  const _SectionLabel(this.text, {this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          top: compact ? 10.0 : 16.0, bottom: compact ? 5.0 : 8.0),
      child: Text(text,
          style: TextStyle(
              color: AppColors.cyan,
              fontSize: compact ? 12.0 : 13.0,
              fontWeight: FontWeight.w700)),
    );
  }
}

class _ColorRow extends StatelessWidget {
  final String current;
  final ValueChanged<String> onPick;
  final bool compact;
  const _ColorRow(
      {required this.current, required this.onPick, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 5.0 : 8.0),
      child: Row(
        children: [
          SizedBox(
              width: compact ? 56.0 : 64.0,
              child: Text('字体颜色',
                  style: TextStyle(
                      color: Colors.white70, fontSize: compact ? 13.0 : 14.0))),
          Expanded(
            child: Wrap(
              spacing: compact ? 10.0 : 14.0,
              runSpacing: compact ? 6.0 : 8.0,
              children: [
                for (final hex in kDanmakuPalette)
                  GestureDetector(
                    onTap: () => onPick(hex),
                    child: Container(
                      width: compact ? 22.0 : 26.0,
                      height: compact ? 22.0 : 26.0,
                      decoration: BoxDecoration(
                        color: colorFromHex(hex),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: current == hex
                              ? AppColors.primary
                              : Colors.white24,
                          width: current == hex ? 2.5 : 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SegRow extends StatelessWidget {
  final String label;
  final List<String> items;
  final int index;
  final ValueChanged<int> onChanged;
  final bool compact;
  const _SegRow({
    required this.label,
    required this.items,
    required this.index,
    required this.onChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 5.0 : 8.0),
      child: Row(
        children: [
          SizedBox(
              width: compact ? 56.0 : 64.0,
              child: Text(label,
                  style: TextStyle(
                      color: Colors.white70, fontSize: compact ? 13.0 : 14.0))),
          Expanded(
            child: Wrap(
              spacing: compact ? 6.0 : 8.0,
              runSpacing: compact ? 6.0 : 8.0,
              children: [
                for (var i = 0; i < items.length; i++)
                  GestureDetector(
                    onTap: () => onChanged(i),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: compact ? 10.0 : 14.0,
                          vertical: compact ? 5.0 : 7.0),
                      decoration: BoxDecoration(
                        color: i == index
                            ? AppColors.primary.withOpacity(0.18)
                            : AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: i == index
                              ? AppColors.primary
                              : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        items[i],
                        style: TextStyle(
                          color:
                              i == index ? AppColors.primary : Colors.white70,
                          fontSize: compact ? 12.0 : 13.0,
                          fontWeight:
                              i == index ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String display;
  final ValueChanged<double> onChanged;
  final bool compact;
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 2.0 : 4.0),
      child: Row(
        children: [
          SizedBox(
              width: compact ? 56.0 : 64.0,
              child: Text(label,
                  style: TextStyle(
                      color: Colors.white70, fontSize: compact ? 13.0 : 14.0))),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              activeColor: AppColors.primary,
              inactiveColor: Colors.white24,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
              width: compact ? 38.0 : 44.0,
              child: Text(display,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      color: Colors.white70, fontSize: compact ? 11.0 : 12.0))),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final String desc;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool compact;
  const _SwitchRow({
    required this.label,
    required this.desc,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 2.0 : 4.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 13.0 : 14.0,
                        fontWeight: FontWeight.w600)),
                Text(desc,
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: compact ? 10.0 : 11.0)),
              ],
            ),
          ),
          Transform.scale(
            scale: compact ? 0.8 : 1.0,
            child: Switch(
              value: value,
              activeColor: AppColors.primary,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
