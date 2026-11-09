import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../data/models/post.dart';
import '../danmaku/danmaku_video.dart';
import '../detail/comment_section.dart';
import '../detail/widgets/video_inline_player.dart' show LandscapeFullScreen;
import '../music/music_card.dart';
import '../player/post_action_bar.dart';
import 'ad_banner.dart';
import 'feed_providers.dart';

/// 推荐竖滑视频流（TikTok 式）。
class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final _pageController = PageController();
  int _current = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(feedControllerProvider.notifier).loadFirst();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _current = index);
    final state = ref.read(feedControllerProvider);
    if (index >= state.posts.length - 2) {
      ref.read(feedControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(feedControllerProvider);

    if (state.loading && state.posts.isEmpty) {
      return const Scaffold(
        backgroundColor: AppColors.pureBlack,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
      );
    }

    if (state.posts.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.pureBlack,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off,
                  color: AppColors.textTertiary, size: 42),
              const SizedBox(height: 10),
              Text(
                state.error ?? '暂时没有内容',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: () =>
                    ref.read(feedControllerProvider.notifier).loadFirst(),
                child: const Text('重新加载'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.pureBlack,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: state.posts.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (_, i) => _FeedItem(
              post: state.posts[i],
              active: i == _current,
            ),
          ),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(child: AdBanner()),
          ),
        ],
      ),
    );
  }
}

class _FeedItem extends ConsumerStatefulWidget {
  final Post post;
  final bool active;
  const _FeedItem({required this.post, required this.active});

  @override
  ConsumerState<_FeedItem> createState() => _FeedItemState();
}

class _FeedItemState extends ConsumerState<_FeedItem>
    with SingleTickerProviderStateMixin {
  final _dk = GlobalKey<DanmakuVideoState>();
  late bool _liked = widget.post.liked;
  late int _likeCount = widget.post.likeCount;
  late bool _collected = widget.post.collected;
  late int _collectCount = widget.post.collectCount;

  /// 信息流内联播放的视频控制器（供全屏续播取当前位置）。
  VideoPlayerController? _ctrl;

  /// 原视频宽高比：>1 视为横屏（16:9），在视频下方显示「全屏播放」键；
  /// <1（9:16 竖屏）或尚未就绪（=0）时不显示。
  double _aspectRatio = 0;

  /// 评论面板是否弹出：弹出时视频画面向上缩小让出面板区域。
  bool _commentsOpen = false;

  /// 评论面板高度占屏比：横屏视频按「满宽铺满无黑边」动态计算，竖屏保持 70%。
  double _panelFrac = 0.7;

  /// 弹幕开关状态（按钮已移到作者名称上方，与 DanmakuVideo 内部同步）。
  bool _danmakuOn = true;

  /// 实时评论数：初始取帖子值，面板内发送成功后 +1。
  late int _commentCount;

  late final AnimationController _heartCtrl;
  late final Animation<double> _heartScale;

  @override
  void initState() {
    super.initState();
    _commentCount = widget.post.commentCount;
    _heartCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _heartScale = Tween<double>(begin: 0.6, end: 1.3).animate(
      CurvedAnimation(parent: _heartCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    super.dispose();
  }

  Future<void> _setLike(bool target) async {
    if (_liked == target) return;
    final prevLiked = _liked;
    final prevCount = _likeCount;
    setState(() {
      _liked = target;
      _likeCount = prevCount + (target ? 1 : -1);
    });
    try {
      final res =
          await ref.read(likeRepositoryProvider).togglePost(widget.post.id);
      if (!mounted) return;
      setState(() {
        _liked = res;
        _likeCount = prevCount + (res ? 1 : -1);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _liked = prevLiked;
        _likeCount = prevCount;
      });
    }
  }

  void _doubleTapLike() {
    _heartCtrl.forward(from: 0).then((_) => _heartCtrl.reverse());
    _setLike(true);
  }

  Future<void> _toggleCollect() async {
    final prev = _collected;
    final prevCount = _collectCount;
    setState(() {
      _collected = !prev;
      _collectCount = prevCount + (_collected ? 1 : -1);
    });
    try {
      final res = await ref
          .read(postRepositoryProvider)
          .toggleCollect('${widget.post.id}');
      if (!mounted) return;
      setState(() {
        _collected = res;
        _collectCount = prevCount + (res ? 1 : -1);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _collected = prev;
        _collectCount = prevCount;
      });
    }
  }

  /// 控制器就绪：记录引用并读取原视频宽高比，据此决定是否显示全屏播放键。
  void _onControllerReady(VideoPlayerController? c) {
    _ctrl = c;
    if (c != null && c.value.isInitialized) {
      final ratio = c.value.aspectRatio;
      if (ratio != _aspectRatio && mounted) {
        setState(() => _aspectRatio = ratio);
      }
    }
  }

  /// 从底部滑出评论面板（复用详情页 CommentSection，不跳页），
  /// 面板高度随视频画面比例动态调整：横屏（16:9/4:3）刚好让画面满宽铺满、
  /// 两侧无黑边；竖屏保持 70%。关闭后视频恢复全屏。
  Future<void> _openComments() async {
    final mq = MediaQuery.of(context);
    double frac = 0.7;
    if (_aspectRatio > 1) {
      // 横屏：满宽播放时画面高占屏比，面板取剩余部分（限幅 55%~70%）。
      final videoHFrac = (mq.size.width / _aspectRatio) / mq.size.height;
      frac = (1 - videoHFrac).clamp(0.55, 0.7);
    }
    setState(() {
      _panelFrac = frac;
      _commentsOpen = true;
    });
    // 挂到根 Navigator，让弹层盖住底部导航栏。
    await showModalBottomSheet(
      context: Navigator.of(context, rootNavigator: true).context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheetContext) => SizedBox(
        height: mq.size.height * _panelFrac,
        child: SafeArea(
          top: false,
          child: CommentSection(
              postId: widget.post.id,
              initialCount: _commentCount,
              light: true,
              // 用弹层自身 context pop，避免宿主 State 失活报错。
              onClose: () =>
                  Navigator.of(sheetContext, rootNavigator: true).pop(),
              onSent: () {
                if (mounted) setState(() => _commentCount++);
              }),
        ),
      ),
    );
    if (mounted) setState(() => _commentsOpen = false);
  }

  /// 进入横屏沉浸式全屏：从当前进度续播，先暂停信息流内联解码避免双解码。
  void _enterFullscreen() {
    final c = _ctrl;
    final pos =
        (c != null && c.value.isInitialized) ? c.value.position : Duration.zero;
    c?.pause();
    // Feed 位于 StatefulShellRoute 分支 Navigator 内，需推到根 Navigator 才能盖住底栏、形成真沉浸式全屏。
    Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) =>
          LandscapeFullScreen(post: widget.post, startPosition: pos),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    // 16:9 横屏视频：在居中画面下边缘之下方放置「全屏播放」键。
    final mq = MediaQuery.of(context);
    final bool landscape = _aspectRatio > 1.0;
    double fsTop = 0;
    if (landscape) {
      final videoH = mq.size.width / _aspectRatio;
      fsTop = mq.size.height / 2 + videoH / 2 + 18;
      final maxTop = mq.size.height - 150; // 夹取，避免超出底部或与互动栏重叠
      if (fsTop > maxTop) fsTop = maxTop;
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        // 视频层：评论面板弹出时缩到上方区域（高度与面板互补），保证画面满宽无侧黑边。
        // 横屏：容器按满宽反推视频高、contain 铺满（本就无黑边）；
        // 竖屏：容器满宽×可用高、cover 裁切铺满（消除原本按高夹紧产生的侧黑边）。
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, box) {
              double w = box.maxWidth;
              double h = box.maxHeight;
              BoxFit fit = BoxFit.contain;
              if (_commentsOpen) {
                final availH = box.maxHeight * (1 - _panelFrac);
                final aspect = _aspectRatio > 0 ? _aspectRatio : 9 / 16;
                if (aspect > 1) {
                  // 横屏：满宽时视频高，通常小于可用高，无黑边。
                  w = box.maxWidth;
                  h = w / aspect;
                  if (h > availH) h = availH;
                  fit = BoxFit.contain;
                } else {
                  // 竖屏：满宽×可用高，cover 铺满、上下裁切。
                  w = box.maxWidth;
                  h = availH;
                  fit = BoxFit.cover;
                }
              }
              return Align(
                alignment: Alignment.topCenter,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  width: w,
                  height: h,
                  child: GestureDetector(
                    onDoubleTap: _doubleTapLike,
                    child: DanmakuVideo(
                      key: _dk,
                      post: post,
                      active: widget.active,
                      videoFit: fit,
                      showDanmakuBadge: false,
                      onDanmakuChanged: (on) {
                        if (mounted) setState(() => _danmakuOn = on);
                      },
                      onControllerReady: _onControllerReady,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // 心形点赞动画
        Center(
          child: FadeTransition(
            opacity: _heartCtrl,
            child: ScaleTransition(
              scale: _heartScale,
              child: const Icon(Icons.favorite,
                  color: AppColors.primary, size: 96),
            ),
          ),
        ),
        // 顶部渐变
        const _TopScrim(),
        // 底部信息 + 右侧互动栏
        Positioned(
          left: 12,
          right: 84,
          bottom: 24,
          // 点击作者/标题/标签等信息区进入详情页
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.push('/post/${post.id}'),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 弹幕开关（由右上角角标移至作者名称上方）。
                GestureDetector(
                  onTap: () => _dk.currentState?.toggleDanmaku(),
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
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '@${post.authorName}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
                  ),
                ),
                if (post.title.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    post.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
                    ),
                  ),
                ],
                if (post.tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: post.tags
                        .map((t) => Text(
                              '#${t.name}',
                              style: const TextStyle(
                                  color: AppColors.cyan, fontSize: 13),
                            ))
                        .toList(),
                  ),
                ],
                if (post.music != null) ...[
                  const SizedBox(height: 10),
                  MusicCard(music: post.music!),
                ],
              ],
            ),
          ),
        ),
        Positioned(
          right: 12,
          bottom: 32,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PostActionBar(
                post: post,
                liked: _liked,
                likeCount: _likeCount,
                collected: _collected,
                collectCount: _collectCount,
                commentCount: _commentCount,
                onLike: () => _setLike(!_liked),
                onCollect: _toggleCollect,
                onComment: _openComments,
              ),
              const SizedBox(height: 18),
              _RoundIconButton(
                icon: Icons.chat_bubble_outline,
                onTap: () => _dk.currentState?.openComposer(context),
              ),
            ],
          ),
        ),
        // 仅 16:9 横屏视频：画面下方显示全屏播放功能键（9:16 竖屏不显示）。
        if (landscape)
          Positioned(
            top: fsTop,
            left: 0,
            right: 0,
            child: Center(
              child: _FullScreenPlayButton(onTap: _enterFullscreen),
            ),
          ),
      ],
    );
  }
}

/// 16:9 横屏视频下方的「全屏播放」功能键。
class _FullScreenPlayButton extends StatelessWidget {
  final VoidCallback onTap;
  const _FullScreenPlayButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.45),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fullscreen, color: AppColors.cyan, size: 18),
            SizedBox(width: 6),
            Text(
              '全屏播放',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// 圆形半透明小按钮（弹幕发送入口等）。
class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _TopScrim extends StatelessWidget {
  const _TopScrim();

  @override
  Widget build(BuildContext context) {
    return const Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 90,
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
    );
  }
}
