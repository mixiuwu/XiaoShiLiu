import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../core/utils/time_format.dart';
import '../../data/models/post.dart';
import '../music/music_card.dart';
import '../poll/poll_card.dart';
import 'comment_providers.dart';
import 'comment_section.dart';
import 'widgets/video_inline_player.dart';

final postDetailProvider = FutureProvider.family<Post, String>((ref, id) async {
  return ref.watch(postRepositoryProvider).detail(id);
});

/// 图文详情页：媒体 + 正文 + 作者 + 互动，底部评论区。
class PostDetailScreen extends ConsumerStatefulWidget {
  final String postId;
  const PostDetailScreen({super.key, required this.postId});

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  bool? _liked;
  int? _likeCount;
  bool? _collected;
  int? _collectCount;

  @override
  void initState() {
    super.initState();
    // 评论与帖子详情并发加载：路由参数即 postId，无需等 post 对象返回再拉评论。
    final intId = int.tryParse(widget.postId);
    if (intId != null) {
      Future.microtask(
        () => ref.read(commentsControllerProvider(intId).notifier).load(),
      );
    }
  }

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
    // 钉住 autoDispose 的评论控制器：CommentSection 要等帖子详情返回后才挂载并 watch，
    // 在此之前用 notifier 维持引用，保证 initState 发起的「评论与详情并发」首加载不被回收。
    final intId = int.tryParse(widget.postId);
    if (intId != null) {
      ref.watch(commentsControllerProvider(intId).notifier);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('详情'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/feed'),
        ),
      ),
      body: async.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(AppColors.primary)),
        ),
        error: (e, _) => Center(
          child: Text('加载失败：$e',
              style: const TextStyle(color: AppColors.textSecondary)),
        ),
        data: (post) {
          _sync(post);
          return Column(
            children: [
              // 播放器/媒体固定在顶部，不随详情与评论一起向上滚动
              _media(post),
              Expanded(
                child: CommentSection(
                  postId: post.id,
                  // 详情正文作为 header，与评论列表同处一个滚动视图（不再拆成两块）
                  header: _detailContent(post),
                  // 评论总数起点，发评论/回复时在 CommentSection 内实时 +1
                  initialCount: post.commentCount,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 详情正文区（作者/标题/正文/标签/时间/音乐/互动/投票 + 评论标题），
  /// 作为 CommentSection 的 header，与评论列表同处一个滚动视图。
  Widget _detailContent(Post post) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _authorRow(post),
              const SizedBox(height: 14),
              if (post.title.isNotEmpty)
                Text(
                  post.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              if (post.content.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  post.content,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
              ],
              if (post.tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: post.tags
                      .map((t) => Text('#${t.name}',
                          style: const TextStyle(
                              color: AppColors.cyan, fontSize: 13)))
                      .toList(),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                '${TimeFormat.relative(post.createdAt)} · ${TimeFormat.compact(post.viewCount)} 浏览',
                style: const TextStyle(
                    color: AppColors.textTertiary, fontSize: 12),
              ),
              const SizedBox(height: 12),
              if (post.music != null) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: MusicCard(music: post.music!, dark: false),
                ),
                const SizedBox(height: 12),
              ],
              _actionRow(post),
              if (post.poll != null) ...[
                const SizedBox(height: 16),
                PollCard(poll: post.poll!),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _media(Post post) {
    if (post.type == 2) {
      // 视频：内联播放器（暂停/继续、倍速、弹幕、投屏、全屏、下一个）。
      return VideoInlinePlayer(post: post);
    }
    if (post.images.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 320,
      child: PageView.builder(
        itemCount: post.images.length,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0),
          child: Image.network(
            post.images[i],
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const ColoredBox(
              color: AppColors.surface,
              child: Center(
                child: Icon(Icons.broken_image_outlined,
                    color: AppColors.textTertiary, size: 40),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _authorRow(Post post) {
    return Row(
      children: [
        ClipOval(
          child: Image.network(
            post.authorAvatar,
            width: 38,
            height: 38,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox(
                width: 38, height: 38, child: Icon(Icons.person)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => context.push('/user/${post.authorAccount}'),
            child: Text(
              post.authorName,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionRow(Post post) {
    return Row(
      children: [
        _pill(
          icon: _liked! ? Icons.favorite : Icons.favorite_border,
          label: '${_likeCount ?? 0}',
          color: _liked! ? AppColors.primary : AppColors.textSecondary,
          onTap: () => _toggleLike(post),
        ),
        const SizedBox(width: 12),
        _pill(
          icon: _collected! ? Icons.star : Icons.star_border,
          label: '${_collectCount ?? 0}',
          color: _collected! ? AppColors.coin : AppColors.textSecondary,
          onTap: () => _toggleCollect(post),
        ),
      ],
    );
  }

  Widget _pill({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
