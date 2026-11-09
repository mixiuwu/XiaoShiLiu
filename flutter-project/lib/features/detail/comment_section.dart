import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../core/utils/time_format.dart';
import '../../data/models/comment.dart';
import 'comment_providers.dart';

/// 评论列表 + 输入区。用于图文详情页底部，也可作为弹层。
class CommentSection extends ConsumerStatefulWidget {
  final int postId;

  /// 详情页正文等前置内容，与评论列表同处一个滚动视图，形成连续一体滚动。
  final Widget? header;

  /// 初始评论总数（取自帖子 commentCount），作为实时 +1 的起点。
  final int initialCount;

  /// 评论发送成功通知（宿主可据此同步更新卡片上的评论数）。
  final VoidCallback? onSent;

  /// 浅色模式（白底面板）：弹层背景为白色时开启，文字/分隔线换深色系配色。
  final bool light;

  /// 固定标题栏右侧关闭按钮回调（弹层宿主传入；为 null 时不显示 ×）。
  final VoidCallback? onClose;
  const CommentSection(
      {super.key,
      required this.postId,
      this.header,
      this.initialCount = 0,
      this.onSent,
      this.light = false,
      this.onClose});

  @override
  ConsumerState<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends ConsumerState<CommentSection> {
  final _input = TextEditingController();
  Comment? _replyTo;
  bool _sending = false;

  /// 当前配色组（深色为基准，浅色用于白底弹层）。
  _CommentPalette get _pal => widget.light
      ? const _CommentPalette(
          surface: Colors.white,
          field: Color(0xFFF5F5F7),
          divider: Color(0xFFEAEAEA),
          textPrimary: Color(0xFF1A1A1A),
          textSecondary: Color(0xFF555555),
          textTertiary: Color(0xFF9B9B9B),
        )
      : const _CommentPalette(
          surface: AppColors.surface,
          field: AppColors.surfaceAlt,
          divider: AppColors.divider,
          textPrimary: AppColors.textPrimary,
          textSecondary: AppColors.textSecondary,
          textTertiary: AppColors.textTertiary,
        );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(commentsControllerProvider(widget.postId).notifier)
          .load(initialTotal: widget.initialCount);
    });
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final raw = _input.text.trim();
    if (raw.isEmpty || _sending) return;
    setState(() => _sending = true);
    final target = _replyTo;
    // 回复归属：顶级评论用自身 id；回复某条子评论时归到同一顶级线程（rootId），
    // 并加「回复 @昵称：」前缀保留上下文。
    final rootId = target == null ? null : (target.parentId ?? target.id);
    final isReplyToReply = target != null && target.parentId != null;
    final content = isReplyToReply ? '回复 @${target.nickname}：$raw' : raw;
    final ok = await ref
        .read(commentsControllerProvider(widget.postId).notifier)
        .send(content, parentId: rootId);
    _input.clear();
    setState(() {
      _sending = false;
      _replyTo = null;
    });
    if (ok) widget.onSent?.call();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('评论失败，请稍后重试')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(commentsControllerProvider(widget.postId));
    // 「评论 N」标题栏固定在顶部不随列表滚动；右侧可选 × 关闭按钮。
    final countBar = Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 2),
      child: Row(
        children: [
          Text(
            '评论 ${state.total}',
            style: TextStyle(
                color: _pal.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          if (widget.onClose != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onClose,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.close, size: 18, color: Color(0xFF555555)),
              ),
            ),
        ],
      ),
    );
    if (widget.header == null) {
      // 无前置正文：标题栏固定，列表独立滚动。
      return Column(
        children: [
          countBar,
          Expanded(child: _buildList(state, scrollable: true)),
          _buildInputBar(),
        ],
      );
    }
    // header（详情正文）与评论列表放在同一个滚动视图内，
    // 形成连续的一体滚动；输入栏固定在底部。
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                widget.header!,
                Divider(color: _pal.divider, height: 1, thickness: 0.6),
                countBar,
                _buildList(state, scrollable: false),
              ],
            ),
          ),
        ),
        _buildInputBar(),
      ],
    );
  }

  Widget _buildList(CommentsState state, {required bool scrollable}) {
    if (state.loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(AppColors.primary)),
        ),
      );
    }
    if (state.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
        child: Center(
          child: Text(
            state.error ?? '还没有评论，抢个沙发～',
            style: TextStyle(color: _pal.textTertiary),
          ),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: !scrollable,
      physics: scrollable
          ? const ClampingScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      itemCount: state.items.length,
      separatorBuilder: (_, __) => const SizedBox.shrink(),
      itemBuilder: (_, i) => _buildThread(state.items[i], state),
    );
  }

  /// 单个评论线程：顶级评论 + 「查看 N 条回复」 + 缩进的子回复列表。
  Widget _buildThread(Comment c, CommentsState state) {
    final notifier =
        ref.read(commentsControllerProvider(widget.postId).notifier);
    final reps = state.replies[c.id];
    final loading = state.loadingRepliesFor.contains(c.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CommentTile(
          comment: c,
          palette: _pal,
          onLike: () => notifier.like(c),
          onReply: () => setState(() => _replyTo = c),
        ),
        if (reps == null && c.replyCount > 0)
          Padding(
            padding: const EdgeInsets.only(left: 48, bottom: 10),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: loading ? null : () => notifier.loadReplies(c.id),
              child: Row(
                children: [
                  if (loading)
                    const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.cyan))
                  else
                    const Icon(Icons.unfold_more,
                        size: 15, color: Color(0xFF555555)),
                  const SizedBox(width: 6),
                  Text('打开 ${c.replyCount} 条回复',
                      style: const TextStyle(
                          color: Color(0xFF555555), fontSize: 12)),
                ],
              ),
            ),
          ),
        if (reps != null && reps.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final r in reps)
                  _CommentTile(
                    comment: r,
                    palette: _pal,
                    onLike: () => notifier.like(r),
                    onReply: () => setState(() => _replyTo = r),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildInputBar() {
    final pal = _pal;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: pal.surface,
          border: Border(top: BorderSide(color: pal.divider)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 3,
                style: TextStyle(color: pal.textPrimary),
                cursorColor: AppColors.primary,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  isDense: true,
                  fillColor: pal.field,
                  hintStyle: TextStyle(color: pal.textTertiary),
                  iconColor: pal.textTertiary,
                  labelStyle: TextStyle(color: pal.textTertiary),
                  counterStyle: TextStyle(color: pal.textTertiary),
                  hintText:
                      _replyTo == null ? '写评论…' : '回复 @${_replyTo!.nickname}',
                  prefixIcon: _replyTo == null
                      ? Icon(Icons.chat_bubble_outline,
                          size: 18, color: pal.textTertiary)
                      : IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() => _replyTo = null),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _sending
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.send_rounded,
                        color: AppColors.primary),
                    onPressed: _send,
                  ),
          ],
        ),
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Comment comment;
  final _CommentPalette palette;
  final VoidCallback onLike;
  final VoidCallback onReply;
  const _CommentTile({
    required this.comment,
    required this.palette,
    required this.onLike,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => context.push('/user/${comment.userAccount}'),
            child: ClipOval(
              child: CachedNetworkImage(
                imageUrl: comment.avatar,
                width: 30,
                height: 30,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const ColoredBox(
                    color: Color(0xFFE4E4E6),
                    child: Icon(Icons.person, size: 20)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.nickname,
                      style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                    if (comment.verified)
                      const Padding(
                        padding: EdgeInsets.only(left: 3),
                        child: Icon(Icons.verified,
                            size: 11, color: AppColors.cyan),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  comment.content,
                  style: TextStyle(
                      color: palette.textPrimary, fontSize: 13, height: 1.25),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      TimeFormat.relative(comment.createdAt),
                      style:
                          TextStyle(color: palette.textTertiary, fontSize: 11),
                    ),
                    const SizedBox(width: 14),
                    GestureDetector(
                      onTap: onReply,
                      child: Text(
                        '回复',
                        style: TextStyle(
                            color: palette.textTertiary, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onLike,
            child: Column(
              children: [
                Icon(
                  comment.liked ? Icons.favorite : Icons.favorite_border,
                  size: 16,
                  color:
                      comment.liked ? AppColors.primary : palette.textTertiary,
                ),
                const SizedBox(height: 1),
                Text(
                  '${comment.likeCount}',
                  style: TextStyle(color: palette.textTertiary, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 评论区配色组：深色为基准，浅色供白底弹层使用。
class _CommentPalette {
  final Color surface;
  final Color field;
  final Color divider;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  const _CommentPalette({
    required this.surface,
    required this.field,
    required this.divider,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
  });
}
