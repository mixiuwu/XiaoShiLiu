import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../data/models/danmaku.dart';
import '../../data/models/post.dart';
import '../player/post_media_view.dart';
import 'danmaku_layer.dart';
import 'danmaku_settings.dart';

/// 视频 + 弹幕层封装：内部加载弹幕列表、按播放进度滚动，并提供发送入口。
class DanmakuVideo extends ConsumerStatefulWidget {
  final Post post;
  final bool active;

  /// 是否显示内置的弹幕开关角标（宿主自带控制条时可关闭）。
  final bool showDanmakuBadge;

  /// 播放地址覆盖（同帖切集），转发给内部 PostMediaView。
  final String? videoUrlOverride;

  /// 弹幕开关状态变化回调（宿主自绘开关按钮时用于同步显示）。
  final ValueChanged<bool>? onDanmakuChanged;

  /// 控制器就绪回调，转发给宿主用于播放/暂停/倍速等控制；释放时回调 null。
  final void Function(VideoPlayerController? controller)? onControllerReady;

  /// 视频画面铺放方式，转发给内部 PostMediaView（cover 可消除缩小时的两侧黑边）。
  final BoxFit videoFit;
  const DanmakuVideo({
    super.key,
    required this.post,
    this.active = false,
    this.showDanmakuBadge = true,
    this.videoUrlOverride,
    this.onControllerReady,
    this.onDanmakuChanged,
    this.videoFit = BoxFit.contain,
  });

  @override
  ConsumerState<DanmakuVideo> createState() => DanmakuVideoState();
}

class DanmakuVideoState extends ConsumerState<DanmakuVideo> {
  final ValueNotifier<Duration> _progress = ValueNotifier(Duration.zero);
  List<Danmaku> _items = const [];
  VideoPlayerController? _attached;
  bool _danmakuOn = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _detach();
    _progress.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list =
          await ref.read(danmakuRepositoryProvider).list('${widget.post.id}');
      if (mounted) setState(() => _items = list);
    } catch (_) {}
  }

  void _onControllerReady(VideoPlayerController? c) {
    _detach();
    if (c != null) {
      _attached = c..addListener(_syncProgress);
    }
    widget.onControllerReady?.call(c);
  }

  void _detach() {
    _attached?.removeListener(_syncProgress);
    _attached = null;
  }

  void _syncProgress() {
    final c = _attached;
    if (c != null) _progress.value = c.value.position;
  }

  /// 供宿主页面（互动栏按钮）调用，弹出弹幕输入框。
  Future<void> openComposer(BuildContext context) async {
    final result = await showModalBottomSheet<_ComposeResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _DanmakuComposerSheet(),
    );
    if (result == null || result.text.trim().isEmpty) return;
    final offset = _progress.value.inSeconds;
    try {
      final d = await ref.read(danmakuRepositoryProvider).send(
            '${widget.post.id}',
            content: result.text.trim(),
            offsetSec: offset,
            color: result.colorHex,
          );
      setState(() => _items = [..._items, d]);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('弹幕发送失败')));
    }
  }

  void _toggleDanmaku() {
    setState(() => _danmakuOn = !_danmakuOn);
    widget.onDanmakuChanged?.call(_danmakuOn);
  }

  /// 供宿主切换弹幕显隐（宿主自绘开关按钮时调用）。
  void toggleDanmaku() => _toggleDanmaku();

  /// 供宿主直接发送一条弹幕（使用当前播放进度作为出现时间点）；成功返回 true。
  Future<bool> sendDanmaku(String text, {String? colorHex}) async {
    final t = text.trim();
    if (t.isEmpty) return false;
    final offset = _progress.value.inSeconds;
    try {
      final d = await ref.read(danmakuRepositoryProvider).send(
            '${widget.post.id}',
            content: t,
            offsetSec: offset,
            color: colorHex ?? kDanmakuPalette.first,
          );
      setState(() => _items = [..._items, d]);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 供宿主控制弹幕显隐。
  void setDanmakuOn(bool on) {
    if (_danmakuOn == on) return;
    setState(() => _danmakuOn = on);
  }

  bool get danmakuOn => _danmakuOn;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PostMediaView(
          post: widget.post,
          active: widget.active,
          videoUrlOverride: widget.videoUrlOverride,
          videoFit: widget.videoFit,
          onControllerReady: _onControllerReady,
        ),
        DanmakuLayer(
          items: _items,
          progress: _progress,
          settings: ref.read(danmakuSettingsProvider),
          visible: _danmakuOn,
        ),
        if (widget.showDanmakuBadge)
          Positioned(
            right: 12,
            top: MediaQuery.of(context).padding.top + 8,
            child: GestureDetector(
              onTap: _toggleDanmaku,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _danmakuOn ? Icons.subtitles : Icons.subtitles_off,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _danmakuOn ? '弹' : '关',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ComposeResult {
  final String text;
  final String colorHex;
  _ComposeResult(this.text, this.colorHex);
}

class _DanmakuComposerSheet extends StatefulWidget {
  const _DanmakuComposerSheet();

  @override
  State<_DanmakuComposerSheet> createState() => _DanmakuComposerSheetState();
}

class _DanmakuComposerSheetState extends State<_DanmakuComposerSheet> {
  final _ctrl = TextEditingController();
  String _colorHex = kDanmakuPalette.first;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        color: AppColors.surface,
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    autofocus: true,
                    maxLength: 40,
                    decoration: const InputDecoration(
                      counterText: '',
                      hintText: '发个弹幕～',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: () => Navigator.pop(
                      context, _ComposeResult(_ctrl.text, _colorHex)),
                  child: const Text('发送',
                      style: TextStyle(color: AppColors.primary)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: kDanmakuPalette
                  .map(
                    (hex) => GestureDetector(
                      onTap: () => setState(() => _colorHex = hex),
                      child: Container(
                        width: 26,
                        height: 26,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: colorFromHex(hex),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _colorHex == hex
                                ? AppColors.primary
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
