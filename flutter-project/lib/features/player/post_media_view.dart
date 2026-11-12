import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../app/theme/app_colors.dart';
import '../../data/models/post.dart';

/// 单条笔记的主媒体区：视频用 video_player，图文用可横滑的 [PageView]。
/// [active] 控制视频是否播放（Feed 中仅当前页 active=true，其余暂停）。
class PostMediaView extends StatefulWidget {
  final Post post;
  final bool active;

  /// 播放地址覆盖（用于同一帖子内切换剧集分集）；为空时回退 post.videoUrl。
  final String? videoUrlOverride;

  /// 视频控制器就绪回调（供弹幕层读取播放进度）；控制器释放时回调 null。
  final void Function(VideoPlayerController? controller)? onControllerReady;

  /// 视频画面铺放方式：contain（默认，完整画面可能留黑边）或 cover（铺满容器、裁切溢出边，无黑边）。
  final BoxFit videoFit;
  const PostMediaView({
    super.key,
    required this.post,
    this.active = false,
    this.videoUrlOverride,
    this.onControllerReady,
    this.videoFit = BoxFit.contain,
  });

  @override
  State<PostMediaView> createState() => _PostMediaViewState();
}

class _PostMediaViewState extends State<PostMediaView> {
  VideoPlayerController? _controller;
  bool _inited = false;
  bool _failed = false;

  /// 当前实际播放地址：优先覆盖（切集），否则帖子主视频。
  String? get _effectiveUrl => widget.videoUrlOverride ?? widget.post.videoUrl;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  void _setup() {
    final url = _effectiveUrl;
    if (url == null || url.isEmpty) return;
    // 显式告知 ExoPlayer 使用 HLS MediaSource，避免模拟器上自动检测失败导致解码模糊
    final isHls = url.contains('.m3u8');
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      formatHint: isHls ? VideoFormat.hls : null,
      httpHeaders: const {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36',
      },
    )..initialize().then((_) {
        if (!mounted) return;
        setState(() => _inited = true);
        _controller!
          ..setLooping(true)
          ..setVolume(1);
        widget.onControllerReady?.call(_controller);
        if (widget.active) _controller!.play();
      }).catchError((_) {
        if (!mounted) return;
        setState(() => _failed = true);
      });
  }

  @override
  void didUpdateWidget(covariant PostMediaView old) {
    super.didUpdateWidget(old);
    final oldUrl = old.videoUrlOverride ?? old.post.videoUrl;
    if (old.post.id != widget.post.id || oldUrl != _effectiveUrl) {
      // 重建需通过 onControllerReady 通知父组件（其内部会 setState），而
      // didUpdateWidget 处于 build 阶段，直接调用会触发「setState during build」异常。
      // 因此延到本帧结束后再重建控制器（旧控制器多播一帧，无感）。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reinit();
      });
      return;
    }
    if (old.active != widget.active && _inited) {
      if (widget.active) {
        _controller!.play();
      } else {
        _controller!.pause();
      }
    }
  }

  /// 释放旧控制器并按当前有效地址重建（切集 / 换帖子时调用）。
  void _reinit() {
    widget.onControllerReady?.call(null);
    _controller?.dispose();
    _controller = null;
    _inited = false;
    _failed = false;
    _setup();
  }

  @override
  void dispose() {
    widget.onControllerReady?.call(null);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.post.type == 2 && _effectiveUrl != null) {
      return _videoLayer();
    }
    return _imageLayer();
  }

  Widget _videoLayer() {
    if (_failed) return _coverOrPlaceholder();
    if (!_inited || _controller == null) {
      // 有封面时只展示封面、不叠转圈（避免「图片状态还在转圈」的突兀观感），
      // 视频初始化完成后自然切换为画面；仅在无封面时才用转圈提示正在加载。
      if (_hasCover) return _coverOrPlaceholder();
      return Stack(
        fit: StackFit.expand,
        children: [
          _coverOrPlaceholder(),
          const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        ],
      );
    }
    if (widget.videoFit == BoxFit.cover) {
      // cover：画面铺满容器、居中裁切溢出部分，消除两侧黑边。
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _controller!.value.size.width,
          height: _controller!.value.size.height,
          child: Texture(
            // ignore: invalid_use_of_visible_for_testing_member
            textureId: _controller!.textureId,
            filterQuality: FilterQuality.high,
          ),
        ),
      );
    }
    return Center(
      child: AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        // 直接用 Texture 并开启高质量采样，缩放时画面更清晰
        child: Texture(
          // ignore: invalid_use_of_visible_for_testing_member
          textureId: _controller!.textureId,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }

  bool get _hasCover {
    final cover = widget.post.coverUrl ?? widget.post.thumbnail;
    return cover != null && cover.isNotEmpty;
  }

  Widget _coverOrPlaceholder() {
    final cover = widget.post.coverUrl ?? widget.post.thumbnail;
    if (cover == null || cover.isEmpty) {
      return const ColoredBox(
        color: AppColors.pureBlack,
        child: Center(
          child: Icon(Icons.movie_outlined,
              color: AppColors.textTertiary, size: 48),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: cover,
      fit: BoxFit.cover,
      placeholder: (_, __) => const ColoredBox(color: AppColors.pureBlack),
      errorWidget: (_, __, ___) => const ColoredBox(color: AppColors.pureBlack),
    );
  }

  Widget _imageLayer() {
    final images = widget.post.images;
    if (images.isEmpty) {
      return const ColoredBox(
        color: AppColors.pureBlack,
        child: Center(
          child: Icon(Icons.image_outlined,
              color: AppColors.textTertiary, size: 48),
        ),
      );
    }
    return PageView.builder(
      itemCount: images.length,
      itemBuilder: (_, i) => CachedNetworkImage(
        imageUrl: images[i],
        fit: BoxFit.contain,
        placeholder: (_, __) => const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
        errorWidget: (_, __, ___) => const ColoredBox(color: AppColors.surface),
      ),
    );
  }
}
