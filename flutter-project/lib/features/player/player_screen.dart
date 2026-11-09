import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../data/models/post.dart';
import '../../features/danmaku/danmaku_video.dart';
import '../../features/detail/post_detail_screen.dart';
import '../../features/music/music_card.dart';
import '../../features/poll/poll_card.dart';
import 'post_action_bar.dart';

/// 全屏播放页：沉浸式播放单条视频，右侧互动栏，底部文案。
class PlayerScreen extends ConsumerStatefulWidget {
  final String postId;
  const PlayerScreen({super.key, required this.postId});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  final _dk = GlobalKey<DanmakuVideoState>();
  bool? _liked;
  int? _likeCount;
  bool? _collected;
  int? _collectCount;

  void _sync(Post p) {
    if (_liked == null) {
      _liked = p.liked;
      _likeCount = p.likeCount;
      _collected = p.collected;
      _collectCount = p.collectCount;
    }
  }

  Future<void> _toggleLike(Post p) async {
    final prev = _liked!;
    final prevCount = _likeCount!;
    setState(() {
      _liked = !prev;
      _likeCount = prevCount + (_liked! ? 1 : -1);
    });
    try {
      final res = await ref.read(likeRepositoryProvider).togglePost(p.id);
      setState(() {
        _liked = res;
        _likeCount = prevCount + (res ? 1 : -1);
      });
    } catch (_) {
      setState(() {
        _liked = prev;
        _likeCount = prevCount;
      });
    }
  }

  Future<void> _toggleCollect(Post p) async {
    final prev = _collected!;
    final prevCount = _collectCount!;
    setState(() {
      _collected = !prev;
      _collectCount = prevCount + (_collected! ? 1 : -1);
    });
    try {
      final res =
          await ref.read(postRepositoryProvider).toggleCollect('${p.id}');
      setState(() {
        _collected = res;
        _collectCount = prevCount + (res ? 1 : -1);
      });
    } catch (_) {
      setState(() {
        _collected = prev;
        _collectCount = prevCount;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(postDetailProvider(widget.postId));

    return Scaffold(
      backgroundColor: AppColors.pureBlack,
      body: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(AppColors.primary)),
        ),
        error: (e, _) => _errorView(),
        data: (post) {
          _sync(post);
          return Stack(
            fit: StackFit.expand,
            children: [
              DanmakuVideo(key: _dk, post: post, active: true),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new,
                              color: Colors.white),
                          onPressed: () => context.canPop()
                              ? context.pop()
                              : context.go('/feed'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (post.poll != null)
                Positioned(
                  left: 16,
                  right: 88,
                  bottom: 150,
                  child: PollCard(poll: post.poll!),
                ),
              Positioned(
                left: 14,
                right: 88,
                bottom: 28,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '@${post.authorName}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (post.title.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        post.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                    if (post.music != null) ...[
                      const SizedBox(height: 10),
                      MusicCard(music: post.music!),
                    ],
                  ],
                ),
              ),
              Positioned(
                right: 12,
                bottom: 36,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PostActionBar(
                      post: post,
                      liked: _liked!,
                      likeCount: _likeCount!,
                      collected: _collected!,
                      collectCount: _collectCount!,
                      onLike: () => _toggleLike(post),
                      onCollect: () => _toggleCollect(post),
                      onComment: () => context.push('/post/${post.id}'),
                    ),
                    const SizedBox(height: 18),
                    GestureDetector(
                      onTap: () => _dk.currentState?.openComposer(context),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.35),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.chat_bubble_outline,
                            color: Colors.white, size: 22),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline,
              color: AppColors.textTertiary, size: 40),
          const SizedBox(height: 10),
          const Text('播放加载失败',
              style: TextStyle(color: AppColors.textSecondary)),
          TextButton(
            onPressed: () => ref.refresh(postDetailProvider(widget.postId)),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
