import 'dart:async';

import 'package:dlna_dart/dlna.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import 'package:volume_controller/volume_controller.dart';

import '../../../app/providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../data/models/post.dart';
import '../../danmaku/danmaku_settings.dart';
import '../../danmaku/danmaku_video.dart';

/// 内联播放器右侧滑出面板类型（一次只展开一个，再次点击同一入口收起）。
enum _InlinePanel { none, speed, episode, toolbox }

/// 详情页内联视频播放器：就地播放，带完整控制条——
/// 暂停/继续、可拖动进度+时间、倍速、弹幕开关、发弹幕、投屏(DLNA)、全屏、下一个。
class VideoInlinePlayer extends ConsumerStatefulWidget {
  final Post post;
  const VideoInlinePlayer({super.key, required this.post});

  @override
  ConsumerState<VideoInlinePlayer> createState() => _VideoInlinePlayerState();
}

class _VideoInlinePlayerState extends ConsumerState<VideoInlinePlayer> {
  final GlobalKey<DanmakuVideoState> _dk = GlobalKey<DanmakuVideoState>();
  VideoPlayerController? _vpc;

  bool _started = false; // 是否已点播放（决定底层 active）
  bool _isPlaying = false;
  double _speed = 1.0;
  bool _danmakuOn = true;
  bool _nextLoading = false;
  bool _dragging = false; // 正在拖动进度条
  double _dragValue = 0; // 拖动中的秒数
  _InlinePanel _panel = _InlinePanel.none; // 右侧滑出面板（倍速/剧集/弹幕工具箱）
  String? _currentEpisodeUrl; // 当前播放的分集地址（同帖切集），为空=帖子主视频
  final TextEditingController _danmakuCtrl = TextEditingController();
  final FocusNode _danmakuFocus = FocusNode();

  static const List<double> _speeds = [0.5, 1.0, 1.5, 2.0];

  bool get _ready => _vpc != null && _vpc!.value.isInitialized;

  double get _posSeconds =>
      _ready ? _vpc!.value.position.inMilliseconds / 1000.0 : 0;
  double get _durSeconds =>
      _ready ? _vpc!.value.duration.inMilliseconds / 1000.0 : 0;

  String _fmt(double s) {
    final t = s.toInt().clamp(0, 359999);
    return '${t ~/ 60}:${(t % 60).toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _vpc?.removeListener(_onTick);
    _danmakuCtrl.dispose();
    _danmakuFocus.dispose();
    super.dispose();
  }

  void _onControllerReady(VideoPlayerController? c) {
    _vpc?.removeListener(_onTick);
    _vpc = c;
    if (c != null) {
      c.addListener(_onTick);
      c.setPlaybackSpeed(_speed); // 复用控制器时保持倍速
    }
    if (mounted) setState(() {});
  }

  void _onTick() {
    if (!mounted) return;
    setState(() => _isPlaying = _vpc?.value.isPlaying ?? false);
  }

  // ---- 控制动作 ----

  void _togglePlay() {
    if (!_ready) {
      // 尚未就绪：先置为激活，待初始化完成后自动播放
      setState(() => _started = true);
      return;
    }
    if (_vpc!.value.isPlaying) {
      _vpc!.pause();
    } else {
      _vpc!.play();
      if (!_started) setState(() => _started = true);
    }
  }

  void _setSpeed(double v) {
    setState(() {
      _speed = v;
      _panel = _InlinePanel.none;
    });
    _vpc?.setPlaybackSpeed(v);
  }

  void _toggleDanmaku() {
    setState(() => _danmakuOn = !_danmakuOn);
    _dk.currentState?.setDanmakuOn(_danmakuOn);
  }

  Future<void> _submitDanmaku() async {
    final text = _danmakuCtrl.text.trim();
    if (text.isEmpty) return;
    _danmakuFocus.unfocus();
    final color = ref.read(danmakuSettingsProvider).color;
    final ok =
        await _dk.currentState?.sendDanmaku(text, colorHex: color) ?? false;
    if (!mounted) return;
    if (ok) {
      _danmakuCtrl.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('弹幕发送失败'), duration: Duration(seconds: 2)));
    }
  }

  void _openDanmakuSettings() => _togglePanel(_InlinePanel.toolbox);

  /// 切换右侧滑出面板：再次点击同一入口则收起。
  void _togglePanel(_InlinePanel kind) {
    setState(() => _panel = (_panel == kind) ? _InlinePanel.none : kind);
  }

  /// 选择分集：同一帖子内切换播放地址（PostMediaView 会据覆盖地址重建控制器）。
  void _playEpisode(Episode e) {
    setState(() {
      _currentEpisodeUrl = e.videoUrl;
      _panel = _InlinePanel.none;
    });
  }

  /// 当前高亮分集地址（未切集时以帖子主视频为准，通常即第 01 集）。
  String? get _activeEpisodeUrl => _currentEpisodeUrl ?? widget.post.videoUrl;

  /// 右侧滑出面板内容（倍速/剧集/弹幕工具箱），背景透明、高度随播放器。
  Widget _buildInlinePanel() {
    switch (_panel) {
      case _InlinePanel.speed:
        return _SpeedPanel(
            speeds: _speeds, current: _speed, onSelect: _setSpeed);
      case _InlinePanel.episode:
        return _EpisodePanel(
          episodes: widget.post.episodes,
          currentUrl: _activeEpisodeUrl,
          onSelect: _playEpisode,
        );
      case _InlinePanel.toolbox:
        return DanmakuToolboxPanel(
            compact: true,
            onClose: () => setState(() => _panel = _InlinePanel.none));
      case _InlinePanel.none:
        return const SizedBox.shrink();
    }
  }

  Future<void> _goFullscreen() async {
    final c = _vpc;
    final pos =
        (c != null && c.value.isInitialized) ? c.value.position : Duration.zero;
    // 进入横屏全屏前先停掉内联播放，避免与全屏页双解码。
    c?.pause();
    setState(() {
      _started = false;
      _isPlaying = false;
    });
    // 真正的横屏沉浸式全屏：从当前位置续播，退出自动恢复竖屏。
    await Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => LandscapeFullScreen(
        post: widget.post,
        startPosition: pos,
        startVideoUrl: _currentEpisodeUrl,
      ),
    ));
  }

  Future<void> _playNext() async {
    if (_nextLoading) return;
    setState(() => _nextLoading = true);
    final repo = ref.read(postRepositoryProvider);
    try {
      final res =
          await repo.list(page: 1, limit: 50, type: 2, category: 'recommend');
      final ids = res.items.map((p) => p.id).toList();
      final idx = ids.indexOf(widget.post.id);
      if (idx == -1) {
        _snack('该视频不在推荐列表中');
      } else if (idx + 1 >= ids.length) {
        _snack('已经是最后一个视频');
      } else {
        if (!mounted) return;
        context.pushReplacement('/post/${ids[idx + 1]}');
        return;
      }
    } catch (_) {
      _snack('加载下一个视频失败');
    } finally {
      if (mounted) setState(() => _nextLoading = false);
    }
  }

  void _showCastSheet() {
    final url = widget.post.videoUrl;
    if (url == null || url.isEmpty) {
      _snack('该视频暂不支持投屏');
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => _DlnaCastSheet(url: url, title: widget.post.title),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 视频 + 弹幕层（点画面切换播放/暂停）
          GestureDetector(
            onTap: _togglePlay,
            child: DanmakuVideo(
              key: _dk,
              post: widget.post,
              active: _started,
              showDanmakuBadge: false,
              videoUrlOverride: _currentEpisodeUrl,
              onControllerReady: _onControllerReady,
            ),
          ),

          // 底部渐变：让集成在时间轴下方的控制区更清晰
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 110,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black54],
                  ),
                ),
              ),
            ),
          ),

          // 中央播放/暂停大按钮（未播放时显示；弹幕工具箱展开时隐藏）
          if (!_isPlaying && _panel != _InlinePanel.toolbox)
            Center(
              child: GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 40),
                ),
              ),
            ),

          // 右上角：投屏（弹幕工具箱展开时隐藏，避免与弹窗叠加造成混乱）
          if (_panel != _InlinePanel.toolbox)
            Positioned(
              top: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.only(top: 2, right: 6),
                child: _CtrlChip(icon: Icons.cast, onTap: _showCastSheet),
              ),
            ),

          // 面板展开时的透明拦截层（点击空白处收起）
          if (_panel != _InlinePanel.none)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _panel = _InlinePanel.none),
                child: const SizedBox.expand(),
              ),
            ),

          // 右侧滑出面板（倍速/剧集/弹幕工具箱，背景透明、高度随播放器）。
          // 刻意先于底部控制行渲染（z 序更低），使入口 chip 在面板展开时仍可点击以 toggle 收起；
          // 面板本身在拦截层之上，面板选项行仍可点击。
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              offset: _panel != _InlinePanel.none
                  ? Offset.zero
                  : const Offset(1, 0),
              child: IgnorePointer(
                ignoring: _panel == _InlinePanel.none,
                child: _buildInlinePanel(),
              ),
            ),
          ),

          // 底部集成控制区：时间轴 + 弹幕 / 发弹幕 / 倍速 / 剧集 / 全屏
          // （弹幕工具箱/选集面板展开时整体隐藏，避免与面板叠加错位）
          if (_panel != _InlinePanel.toolbox && _panel != _InlinePanel.episode)
            Positioned(
              left: 4,
              right: 4,
              bottom: 2,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 时间轴行：播放/暂停 · 进度 · 下一个
                  Row(
                    children: [
                      IconButton(
                        onPressed: _togglePlay,
                        visualDensity: VisualDensity.compact,
                        color: Colors.white,
                        icon: Icon(_isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded),
                      ),
                      Text(_fmt(_dragging ? _dragValue : _posSeconds),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10)),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            activeTrackColor: AppColors.primary,
                            inactiveTrackColor: Colors.white24,
                            thumbColor: AppColors.primary,
                            overlayColor: AppColors.primary.withOpacity(0.2),
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 12),
                          ),
                          child: Slider(
                            value: _durSeconds > 0
                                ? (_dragging ? _dragValue : _posSeconds)
                                    .clamp(0, _durSeconds)
                                : 0,
                            max: _durSeconds > 0 ? _durSeconds : 1,
                            onChanged: _durSeconds > 0
                                ? (v) => setState(() {
                                      _dragging = true;
                                      _dragValue = v;
                                    })
                                : null,
                            onChangeEnd: _durSeconds > 0
                                ? (v) {
                                    _vpc?.seekTo(Duration(
                                        milliseconds: (v * 1000).round()));
                                    setState(() => _dragging = false);
                                  }
                                : null,
                          ),
                        ),
                      ),
                      Text(_fmt(_durSeconds),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 10)),
                      IconButton(
                        onPressed: _nextLoading ? null : _playNext,
                        visualDensity: VisualDensity.compact,
                        color: Colors.white,
                        tooltip: '下一个',
                        icon: _nextLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.skip_next_rounded),
                      ),
                    ],
                  ),
                  // 控制行（集成到时间轴下方）：弹幕开关 · 输入 …… 倍速 · 投屏 · 全屏
                  Padding(
                    padding: const EdgeInsets.only(right: 4, top: 2),
                    child: Row(
                      children: [
                        _CtrlChip(
                          icon: _danmakuOn
                              ? Icons.subtitles
                              : Icons.subtitles_off,
                          onTap: _toggleDanmaku,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _DanmakuInputPill(
                            controller: _danmakuCtrl,
                            focusNode: _danmakuFocus,
                            onSettings: _openDanmakuSettings,
                            onSend: _submitDanmaku,
                          ),
                        ),
                        _CtrlChip(
                            label: '${_speed.toStringAsFixed(1)}x',
                            highlight: _speed != 1.0,
                            onTap: () => _togglePanel(_InlinePanel.speed)),
                        _CtrlChip(
                            label: '剧集',
                            highlight: _panel == _InlinePanel.episode,
                            onTap: () => _togglePanel(_InlinePanel.episode)),
                        _CtrlChip(icon: Icons.fullscreen, onTap: _goFullscreen),
                      ],
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

/// 控制小件：背景透明（无深色圆圈），可纯图标、纯文字或图标+文字。
class _CtrlChip extends StatelessWidget {
  final IconData? icon;
  final String? label;
  final bool highlight;
  final VoidCallback onTap;
  const _CtrlChip(
      {this.icon, this.label, this.highlight = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = highlight ? AppColors.primary : Colors.white;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: color, size: 22),
              if (label != null) const SizedBox(width: 4),
            ],
            if (label != null)
              Text(label!,
                  style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      shadows: const [
                        Shadow(blurRadius: 6, color: Colors.black87)
                      ])),
          ],
        ),
      ),
    );
  }
}

/// 右侧滑出的倍速选择面板：背景透明，高度由外层 Positioned 撑满（随播放器）。
class _SpeedPanel extends StatelessWidget {
  final List<double> speeds;
  final double current;
  final ValueChanged<double> onSelect;
  const _SpeedPanel({
    required this.speeds,
    required this.current,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      alignment: Alignment.center,
      color: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final s in speeds)
            InkWell(
              onTap: () => onSelect(s),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Text(
                  '${s.toStringAsFixed(1)}x',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: s == current ? AppColors.primary : Colors.white,
                    fontSize: 14,
                    fontWeight:
                        s == current ? FontWeight.w700 : FontWeight.w500,
                    shadows: const [
                      Shadow(blurRadius: 8, color: Colors.black87)
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 右侧滑出的剧集（选集）面板：网格数字按钮布局（4 列），当前集高亮边框。
class _EpisodePanel extends StatelessWidget {
  final List<Episode> episodes;
  final String? currentUrl;
  final ValueChanged<Episode> onSelect;
  const _EpisodePanel({
    required this.episodes,
    required this.currentUrl,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Text('选集',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: episodes.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Text('无选集',
                        style: TextStyle(color: Colors.white54, fontSize: 12)))
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      childAspectRatio: 1.3,
                    ),
                    itemCount: episodes.length,
                    itemBuilder: (_, i) {
                      final selected = episodes[i].videoUrl == currentUrl;
                      return GestureDetector(
                        onTap: () => onSelect(episodes[i]),
                        child: Container(
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFF4A2D12)
                                : const Color(0xFF3A3A3A),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Text(
                                '${i + 1}',
                                style: TextStyle(
                                  color: selected
                                      ? const Color(0xFFFF9432)
                                      : Colors.white70,
                                  fontSize: 13,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                              if (selected)
                                const Positioned(
                                  top: 2,
                                  right: 3,
                                  child: Icon(Icons.equalizer,
                                      size: 11, color: Color(0xFFFF9432)),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// 亮度/音量拖动时的中央指示条。
class _GestureBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  const _GestureBadge(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 30),
          const SizedBox(height: 10),
          SizedBox(
            width: 130,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: value.clamp(0, 1),
                minHeight: 4,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('$label ${(value * 100).round()}%',
              style: const TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }
}

/// 弹幕输入胶囊（内联与全屏共用）：半透明圆角、左侧青色齿轮（打开工具箱）、右侧发送。
class _DanmakuInputPill extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSettings;
  final VoidCallback onSend;
  const _DanmakuInputPill({
    required this.controller,
    required this.focusNode,
    required this.onSettings,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onSettings,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Icon(Icons.tune_rounded, color: AppColors.cyan, size: 20),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12, width: 1),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                maxLength: 40,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                style: const TextStyle(color: Colors.white, fontSize: 12),
                decoration: const InputDecoration(
                  isDense: true,
                  counterText: '',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  // 聚焦时的高亮框：小圆角，避免继承主题的大弧度红框
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                    borderSide: BorderSide(color: AppColors.primary, width: 1),
                  ),
                  contentPadding: EdgeInsets.zero,
                  hintText: '发个友善的弹幕吧!',
                  hintStyle: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onSend,
            child: const Icon(Icons.send_rounded,
                color: AppColors.primary, size: 20),
          ),
        ],
      ),
    );
  }
}

/// 真实 DLNA/UPnP 投屏面板：通过 SSDP 组播发现局域网渲染设备，
/// 选中后 SetAVTransportURI + Play 推流；关闭面板会停止投屏。
class _DlnaCastSheet extends StatefulWidget {
  final String url;
  final String title;
  const _DlnaCastSheet({required this.url, required this.title});

  @override
  State<_DlnaCastSheet> createState() => _DlnaCastSheetState();
}

class _DlnaCastSheetState extends State<_DlnaCastSheet> {
  final DLNAManager _manager = DLNAManager();
  final Map<String, DLNADevice> _devices = {};
  StreamSubscription? _sub;
  bool _searching = false;
  String? _error;
  DLNADevice? _casting;
  String _castingName = '';
  Timer? _timeout;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    _timeout?.cancel();
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final dm = await _manager.start();
      _sub = dm.devices.stream.listen((list) {
        if (!mounted) return;
        setState(() {
          _devices
            ..clear()
            ..addAll(list);
        });
      });
      // 10s 内无设备响应则停止转圈，提示未发现并可重试。
      _timeout = Timer(const Duration(seconds: 10), () {
        if (mounted && _devices.isEmpty) setState(() => _searching = false);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '投屏发现失败：$e';
        _searching = false;
      });
    }
  }

  Future<void> _cast(DLNADevice device) async {
    try {
      await device.setUrl(widget.url,
          title: widget.title.isEmpty ? '小石榴视频' : widget.title);
      await device.play();
      if (!mounted) return;
      setState(() {
        _casting = device;
        _castingName = device.info.friendlyName;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('投屏失败：$e')));
    }
  }

  Future<void> _disconnect() async {
    try {
      await _casting?.stop();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _casting = null;
      _castingName = '';
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timeout?.cancel();
    try {
      _casting?.stop();
    } catch (_) {}
    _manager.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.cast, color: AppColors.primary),
                SizedBox(width: 8),
                Text('投屏设备（DLNA）',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 10),
            if (_casting == null)
              InkWell(
                onTap: _searching ? null : _start,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      if (_searching)
                        const SizedBox(
                            width: 13,
                            height: 13,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation(AppColors.primary)))
                      else
                        const Icon(Icons.refresh,
                            size: 16, color: AppColors.textTertiary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error ??
                              (_searching
                                  ? '正在搜索局域网投屏设备…'
                                  : (_devices.isEmpty
                                      ? '未发现设备，请确认手机与电视处于同一 Wi-Fi（点击重试）'
                                      : '点击设备即可投屏')),
                          style: const TextStyle(
                              color: AppColors.textTertiary, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 6),
            if (_casting != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading:
                    const Icon(Icons.cast_connected, color: AppColors.primary),
                title: Text('正在投屏：$_castingName',
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 14)),
                trailing: TextButton(
                  onPressed: _disconnect,
                  child: const Text('断开',
                      style: TextStyle(color: AppColors.primary)),
                ),
              )
            else ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: _devices.isEmpty
                    ? const SizedBox(height: 48)
                    : ListView(
                        shrinkWrap: true,
                        children: _devices.values
                            .map(
                              (d) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.tv,
                                    color: AppColors.textSecondary),
                                title: Text(
                                    d.info.friendlyName.isEmpty
                                        ? '未命名设备'
                                        : d.info.friendlyName,
                                    style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 14)),
                                onTap: () => _cast(d),
                              ),
                            )
                            .toList(),
                      ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('关闭',
                      style: TextStyle(color: AppColors.textTertiary)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 右侧滑出面板的类型。
enum _PanelKind { none, speed, source, subtitle, episode }

class LandscapeFullScreen extends ConsumerStatefulWidget {
  final Post post;
  final Duration startPosition;
  final String? startVideoUrl; // 从内联播放器带入的当前分集地址
  const LandscapeFullScreen({
    super.key,
    required this.post,
    required this.startPosition,
    this.startVideoUrl,
  });

  @override
  ConsumerState<LandscapeFullScreen> createState() =>
      LandscapeFullScreenState();
}

class LandscapeFullScreenState extends ConsumerState<LandscapeFullScreen> {
  final GlobalKey<DanmakuVideoState> _dk = GlobalKey<DanmakuVideoState>();
  VideoPlayerController? _c;

  bool _playing = false;
  double _speed = 1.0;
  bool _danmakuOn = true;
  bool _dragging = false;
  double _dragValue = 0;
  bool _showControls = true; // 控制层是否可见
  bool _locked = false; // 锁定后控制层不自动隐藏
  Timer? _hideTimer;
  final TextEditingController _danmakuCtrl = TextEditingController();
  final FocusNode _danmakuFocus = FocusNode();
  _PanelKind _panel = _PanelKind.none; // 右侧滑出面板当前类型
  bool _ccOn = false; // 字幕开关
  late String? _currentEpisodeUrl = widget.startVideoUrl; // 当前分集地址（同屏切集）
  late List<Episode> _episodes =
      widget.post.episodes; // 剧集列表（Feed 进入时列表数据不含，需补拉详情）

  // 亮度/音量手势
  double _brightness = 1.0; // 屏幕调光亮度 0~1（1=最亮，不遮挡）
  double _volume = 0.0; // 系统媒体音量 0~1
  bool _draggingSide = false; // 正在竖滑调节中
  bool _dragLeft = true; // true=左(亮度) false=右(音量)
  bool _showGesture = false; // 是否显示中央调节指示
  Timer? _gestureTimer;

  static const List<double> _speeds = [0.5, 1.0, 1.5, 2.0];

  bool get _ready => _c != null && _c!.value.isInitialized;
  double get _posSeconds =>
      _ready ? _c!.value.position.inMilliseconds / 1000.0 : 0;
  double get _durSeconds =>
      _ready ? _c!.value.duration.inMilliseconds / 1000.0 : 0;

  String _fmt(double s) {
    final t = s.toInt().clamp(0, 359999);
    return '${t ~/ 60}:${(t % 60).toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    // 强制横屏 + 沉浸式隐藏系统状态/导航栏。
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky,
        overlays: []);
    // 音量：接管系统媒体音量，自行绘制指示条（不弹系统音量 UI）。
    VolumeController.instance.showSystemUI = false;
    VolumeController.instance.getVolume().then((v) {
      if (mounted) setState(() => _volume = v);
    });
    // 从 Feed 直接进入全屏时 post 为列表数据（不带 episodes），补拉详情获取选集。
    if (_episodes.isEmpty && widget.post.id > 0) _loadEpisodes(0);
  }

  /// 补拉剧集列表；云端 DB 偶发重置会让详情返回空 episodes，最多重试 3 次。
  Future<void> _loadEpisodes(int attempt) async {
    try {
      final detail = await ref
          .read(postRepositoryProvider)
          .detail(widget.post.id.toString());
      if (!mounted) return;
      if (detail.episodes.isNotEmpty) {
        setState(() => _episodes = detail.episodes);
        return;
      }
    } catch (_) {
      if (!mounted) return;
    }
    if (attempt < 2) {
      Future.delayed(const Duration(milliseconds: 1200),
          () => mounted ? _loadEpisodes(attempt + 1) : null);
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _gestureTimer?.cancel();
    _danmakuCtrl.dispose();
    _danmakuFocus.dispose();
    _c?.removeListener(_onTick);
    // 退出全屏：恢复系统栏显示并放开屏幕方向（回到默认行为）。
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  // ---- 控制层显隐 / 自动隐藏 ----
  void _poke() {
    // 用户交互：显示控制层并重排自动隐藏。
    if (!_showControls) setState(() => _showControls = true);
    _scheduleHide();
  }

  void _onLockedTap() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('已锁定，点击左侧解锁按钮解除'), duration: Duration(seconds: 1)));
  }

  // ---- 左侧竖滑调亮度 / 右侧竖滑调音量 ----
  void _onVS(DragStartDetails d) {
    if (_locked) return;
    final w = MediaQuery.of(context).size.width;
    _gestureTimer?.cancel();
    setState(() {
      _draggingSide = true;
      _dragLeft = d.globalPosition.dx < w / 2;
      _showGesture = true;
    });
  }

  void _onVU(DragUpdateDetails d) {
    if (_locked || !_draggingSide) return;
    final h = MediaQuery.of(context).size.height;
    final delta = -d.delta.dy / h; // 上滑增大
    if (_dragLeft) {
      _brightness = (_brightness + delta).clamp(0.0, 1.0);
    } else {
      _volume = (_volume + delta).clamp(0.0, 1.0);
      VolumeController.instance.setVolume(_volume);
    }
    setState(() => _showGesture = true);
    _scheduleGestureHide();
  }

  void _onVE(DragEndDetails d) {
    _draggingSide = false;
    _scheduleGestureHide();
  }

  void _scheduleGestureHide() {
    _gestureTimer?.cancel();
    _gestureTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _showGesture = false);
    });
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (_locked || !_playing || _panel != _PanelKind.none) {
      return;
    }
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _playing && !_locked && _panel == _PanelKind.none) {
        setState(() => _showControls = false);
      }
    });
  }

  void _onReady(VideoPlayerController? c) {
    _c?.removeListener(_onTick);
    _c = c;
    if (c != null) {
      c.addListener(_onTick);
      if (widget.startPosition > Duration.zero) c.seekTo(widget.startPosition);
      c.setPlaybackSpeed(_speed);
    }
    if (mounted) setState(() {});
    _scheduleHide();
  }

  void _onTick() {
    if (!mounted) return;
    final playing = _c?.value.isPlaying ?? false;
    final wasPlaying = _playing;
    setState(() {
      _playing = playing;
      if (!playing) _showControls = true; // 暂停时始终显示控制层
    });
    if (playing && !wasPlaying) _scheduleHide();
  }

  void _togglePlay() {
    final c = _c;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      c.play();
      _poke();
    }
  }

  void _setSpeed(double v) {
    setState(() {
      _speed = v;
      _panel = _PanelKind.none;
    });
    _c?.setPlaybackSpeed(v);
    _poke();
  }

  void _openPanel(_PanelKind kind) {
    // 再次点击同一入口则收起面板（回弹隐藏）
    setState(() => _panel = (_panel == kind) ? _PanelKind.none : kind);
    _poke();
  }

  void _closePanel() {
    if (_panel == _PanelKind.none) return;
    setState(() => _panel = _PanelKind.none);
  }

  void _showEpisodes() {
    // 剧集面板已展开时，再次点击收起
    if (_panel == _PanelKind.episode) {
      setState(() => _panel = _PanelKind.none);
      _poke();
      return;
    }
    setState(() => _panel = _PanelKind.episode);
    // 之前补拉失败时，打开面板再试一次
    if (_episodes.isEmpty && widget.post.id > 0) _loadEpisodes(0);
    _poke();
  }

  /// 当前高亮分集地址（未切集时以帖子主视频为准）。
  String? get _activeEpisodeUrl => _currentEpisodeUrl ?? widget.post.videoUrl;

  void _playEpisode(Episode e) {
    _closePanel();
    setState(() => _currentEpisodeUrl = e.videoUrl);
  }

  /// 右侧滑出面板内容（根据 _panel 切换），背景透明、高度随播放器。
  Widget _buildRightPanel() {
    switch (_panel) {
      case _PanelKind.speed:
        return _panelShell(title: '播放倍速', children: [
          for (final s in _speeds)
            _panelRow(
                '${s.toStringAsFixed(1)}x', s == _speed, () => _setSpeed(s)),
        ]);
      case _PanelKind.source:
        return _panelShell(title: '当前线路', children: [
          _panelRow('默认线路', true, _closePanel),
          _panelRow('高清线路（不可用）', false, null, enabled: false),
        ]);
      case _PanelKind.subtitle:
        return _panelShell(title: '字幕', children: [
          _panelRow('关闭', !_ccOn, () {
            setState(() {
              _ccOn = false;
              _panel = _PanelKind.none;
            });
          }),
          _panelRow('中文（暂无字幕）', _ccOn, null, enabled: false),
        ]);
      case _PanelKind.episode:
        // 全屏选集面板：右侧悬浮圆角面板，4 列网格数字按钮，当前集橙色高亮
        return Padding(
          padding: const EdgeInsets.fromLTRB(0, 14, 14, 14),
          child: Container(
            width: 264,
            decoration: BoxDecoration(
              color: const Color(0xFF181818),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 头部：左侧 × 关闭，居中标题「选集」
                SizedBox(
                  height: 40,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        child: IconButton(
                          onPressed: _closePanel,
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 32, minHeight: 32),
                          icon: const Icon(Icons.close,
                              color: Colors.white, size: 22),
                        ),
                      ),
                      const Center(
                        child: Text('选集',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _episodes.isEmpty
                      ? const Center(
                          child: Text('无选集',
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 12)))
                      : GridView.builder(
                          padding: const EdgeInsets.only(top: 4),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 1.15,
                          ),
                          itemCount: _episodes.length,
                          itemBuilder: (_, i) {
                            final selected =
                                _episodes[i].videoUrl == _activeEpisodeUrl;
                            return GestureDetector(
                              onTap: () => _playEpisode(_episodes[i]),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: selected
                                      ? const Color(0xFF4A2D12)
                                      : const Color(0xFF2B2B2B),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Text(
                                      '${i + 1}',
                                      style: TextStyle(
                                        color: selected
                                            ? const Color(0xFFFF9432)
                                            : Colors.white70,
                                        fontSize: 16,
                                        fontWeight: selected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                    ),
                                    // 当前播放集右上角橙色音波小图标
                                    if (selected)
                                      const Positioned(
                                        top: 5,
                                        right: 6,
                                        child: Icon(Icons.equalizer,
                                            size: 13, color: Color(0xFFFF9432)),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      case _PanelKind.none:
        return const SizedBox.shrink();
    }
  }

  Widget _panelShell({
    required String title,
    required List<Widget> children,
    bool scrollable = false,
    Color background = Colors.transparent,
  }) {
    return Container(
      width: 190,
      color: background,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: scrollable ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment:
            scrollable ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
            child: Text(title,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(blurRadius: 6, color: Colors.black87)])),
          ),
          if (scrollable)
            Expanded(
                child: SingleChildScrollView(child: Column(children: children)))
          else
            Column(mainAxisSize: MainAxisSize.min, children: children),
        ],
      ),
    );
  }

  Widget _panelRow(String label, bool selected, VoidCallback? onTap,
      {bool enabled = true, int maxLines = 1}) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: !enabled
                      ? Colors.white30
                      : selected
                          ? AppColors.primary
                          : Colors.white,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  shadows: const [Shadow(blurRadius: 6, color: Colors.black87)],
                ),
              ),
            ),
            if (selected)
              const Icon(Icons.check, color: AppColors.primary, size: 18),
          ],
        ),
      ),
    );
  }

  void _toggleDanmaku() {
    setState(() => _danmakuOn = !_danmakuOn);
    _dk.currentState?.setDanmakuOn(_danmakuOn);
    _poke();
  }

  Future<void> _submitDanmaku() async {
    final text = _danmakuCtrl.text.trim();
    if (text.isEmpty) return;
    _danmakuFocus.unfocus();
    final color = ref.read(danmakuSettingsProvider).color;
    final ok =
        await _dk.currentState?.sendDanmaku(text, colorHex: color) ?? false;
    if (!mounted) return;
    if (ok) {
      _danmakuCtrl.clear();
      _poke();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('弹幕发送失败'), duration: Duration(seconds: 2)));
    }
  }

  void _showCast() {
    final url = widget.post.videoUrl;
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('该视频暂不支持投屏'), duration: Duration(seconds: 2)));
      return;
    }
    _poke();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => _DlnaCastSheet(url: url, title: widget.post.title),
    );
  }

  void _toggleLock() {
    setState(() {
      _locked = !_locked;
      if (_locked) {
        // 锁定：关闭右侧面板，保持控制层可见（仅解锁按钮可用）。
        _panel = _PanelKind.none;
        _hideTimer?.cancel();
        _showControls = true;
      }
    });
    if (!_locked) _scheduleHide();
  }

  void _openDanmakuSettings() => showDanmakuToolbox(context);

  void _exit() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final show = _showControls;
    return Scaffold(
      backgroundColor: AppColors.pureBlack,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 视频 + 弹幕层；单击画面=播放/暂停，左侧竖滑=亮度，右侧竖滑=音量
          // 选集面板弹出时，画面向左按比例缩小，为右侧面板让出空间
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, box) => Align(
                alignment: Alignment.centerLeft,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  width:
                      box.maxWidth * (_panel == _PanelKind.episode ? 0.7 : 1.0),
                  height: box.maxHeight,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _locked ? _onLockedTap : _togglePlay,
                    onVerticalDragStart: _onVS,
                    onVerticalDragUpdate: _onVU,
                    onVerticalDragEnd: _onVE,
                    child: DanmakuVideo(
                      key: _dk,
                      post: widget.post,
                      active: true,
                      showDanmakuBadge: false,
                      videoUrlOverride: _currentEpisodeUrl,
                      onControllerReady: _onReady,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 屏幕调光遮罩（模拟亮度，覆盖视频/弹幕，位于控制层之下）
          if (_brightness < 1.0)
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                    color:
                        Colors.black.withOpacity((1.0 - _brightness) * 0.85)),
              ),
            ),

          // 顶部渐变（仅显示控制层且未锁定时）
          if (show && !_locked)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 96,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black54, Colors.transparent],
                    ),
                  ),
                ),
              ),
            ),
          // 底部渐变（仅显示控制层且未锁定时）
          if (show && !_locked)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 150,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black87],
                    ),
                  ),
                ),
              ),
            ),

          // 面板展开时的背景拦截层：点击面板外区域收起。
          // 刻意置于控制层之下，保证底部功能按钮仍可再次点击以收起对应面板。
          if (_panel != _PanelKind.none)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closePanel,
                child: const SizedBox.expand(),
              ),
            ),

          // 中央播放/暂停大按钮（暂停且未锁定时显示）
          if (!_playing && !_locked)
            Center(
              child: GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 44),
                ),
              ),
            ),

          // 左侧：锁定控制层
          if (show)
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  onPressed: _toggleLock,
                  color: Colors.white,
                  tooltip: _locked ? '已锁定' : '锁定屏幕',
                  icon: Icon(_locked ? Icons.lock : Icons.lock_open),
                ),
              ),
            ),

          // 顶部栏：返回 · 标题/作者 · 投屏（锁定时隐藏）
          if (show && !_locked)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 6, 12, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _exit,
                        color: Colors.white,
                        icon: const Icon(Icons.arrow_back_ios_new, size: 22),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.post.title.isEmpty
                                  ? '小石榴视频'
                                  : widget.post.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '@${widget.post.authorName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _showCast,
                        color: Colors.white,
                        tooltip: '投屏',
                        icon: const Icon(Icons.cast),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 右侧滑出面板（字幕/换源/倍速/选集，背景透明、高度随播放器）。
          // 刻意先于底部控制行渲染（z 序更低），使换源/倍速/剧集入口在面板展开时仍能被点击以 toggle 收起；
          // 面板本身在背景拦截层之上，面板选项行仍可点击。
          Positioned(
            top: 0,
            right: 0,
            bottom: 0,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              offset:
                  _panel != _PanelKind.none ? Offset.zero : const Offset(1, 0),
              child: IgnorePointer(
                ignoring: _panel == _PanelKind.none,
                child: _buildRightPanel(),
              ),
            ),
          ),

          // 底部：进度条 + 弹幕输入 + 控制（锁定或选集面板展开时隐藏，避免与面板叠加错位）
          if (show && !_locked && _panel != _PanelKind.episode)
            Positioned(
              left: 12,
              right: 12,
              bottom: MediaQuery.viewInsetsOf(context).bottom,
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 进度行：播放/暂停 · Slider · 时间
                    Row(
                      children: [
                        IconButton(
                          onPressed: _togglePlay,
                          color: Colors.white,
                          icon: Icon(_playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded),
                        ),
                        Text(_fmt(_dragging ? _dragValue : _posSeconds),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11)),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3,
                              activeTrackColor: AppColors.primary,
                              inactiveTrackColor: Colors.white24,
                              thumbColor: AppColors.primary,
                              overlayColor: AppColors.primary.withOpacity(0.2),
                              thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 12),
                            ),
                            child: Slider(
                              value: _durSeconds > 0
                                  ? (_dragging ? _dragValue : _posSeconds)
                                      .clamp(0, _durSeconds)
                                  : 0,
                              max: _durSeconds > 0 ? _durSeconds : 1,
                              onChanged: _durSeconds > 0
                                  ? (v) => setState(() {
                                        _dragging = true;
                                        _dragValue = v;
                                      })
                                  : null,
                              onChangeEnd: _durSeconds > 0
                                  ? (v) {
                                      _c?.seekTo(Duration(
                                          milliseconds: (v * 1000).round()));
                                      setState(() => _dragging = false);
                                      _poke();
                                    }
                                  : null,
                            ),
                          ),
                        ),
                        Text(_fmt(_durSeconds),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                    // 控制行：弹幕开关 · 输入 …… 字幕 · 换源 · 倍速 · 选集 · 退出全屏
                    Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 6),
                      child: Row(
                        children: [
                          _CtrlChip(
                            icon: _danmakuOn
                                ? Icons.subtitles
                                : Icons.subtitles_off,
                            onTap: _toggleDanmaku,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: SizedBox(
                                width: 240,
                                child: _DanmakuInputPill(
                                  controller: _danmakuCtrl,
                                  focusNode: _danmakuFocus,
                                  onSettings: _openDanmakuSettings,
                                  onSend: _submitDanmaku,
                                ),
                              ),
                            ),
                          ),
                          _CtrlChip(
                              label: '字幕',
                              onTap: () => _openPanel(_PanelKind.subtitle)),
                          _CtrlChip(
                              label: '换源',
                              onTap: () => _openPanel(_PanelKind.source)),
                          _CtrlChip(
                              label: '${_speed.toStringAsFixed(1)}x',
                              highlight: _speed != 1.0,
                              onTap: () => _openPanel(_PanelKind.speed)),
                          _CtrlChip(label: '剧集', onTap: _showEpisodes),
                          _CtrlChip(icon: Icons.fullscreen_exit, onTap: _exit),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 亮度/音量调节指示（拖动时中央显示）
          if (_showGesture)
            Center(
              child: _GestureBadge(
                icon: _dragLeft
                    ? Icons.brightness_6_rounded
                    : (_volume > 0
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded),
                label: _dragLeft ? '亮度' : '音量',
                value: _dragLeft ? _brightness : _volume,
              ),
            ),
        ],
      ),
    );
  }
}
