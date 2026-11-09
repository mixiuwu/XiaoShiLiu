import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../data/models/post.dart';

/// 视频流 / 播放页右侧互动栏（无状态展示层）：头像、点赞、收藏、评论。
/// 交互状态由宿主页面持有并通过回调下发。
class PostActionBar extends StatelessWidget {
  final Post post;
  final bool liked;
  final int likeCount;
  final bool collected;
  final int collectCount;

  /// 评论数覆盖（宿主实时计数用），为 null 时取 post.commentCount。
  final int? commentCount;
  final VoidCallback onLike;
  final VoidCallback onCollect;
  final VoidCallback onComment;

  const PostActionBar({
    super.key,
    required this.post,
    required this.liked,
    required this.likeCount,
    required this.collected,
    required this.collectCount,
    this.commentCount,
    required this.onLike,
    required this.onCollect,
    required this.onComment,
  });

  String _fmt(int n) =>
      n >= 10000 ? '${(n / 10000).toStringAsFixed(1)}w' : '$n';

  Widget _countItem({
    required IconData icon,
    required IconData activeIcon,
    required bool active,
    required int count,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(active ? activeIcon : icon,
              color: active ? activeColor : Colors.white, size: 34),
          const SizedBox(height: 4),
          Text(
            _fmt(count),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => context.push('/user/${post.authorAccount}'),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: ClipOval(
              child: CachedNetworkImage(
                imageUrl: post.authorAvatar,
                width: 46,
                height: 46,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const ColoredBox(
                  color: AppColors.surface,
                  child: Icon(Icons.person, color: AppColors.textSecondary),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),
        _countItem(
          icon: Icons.favorite_border,
          activeIcon: Icons.favorite,
          active: liked,
          count: likeCount,
          activeColor: AppColors.primary,
          onTap: onLike,
        ),
        const SizedBox(height: 20),
        _countItem(
          icon: Icons.star_border,
          activeIcon: Icons.star,
          active: collected,
          count: collectCount,
          activeColor: AppColors.coin,
          onTap: onCollect,
        ),
        const SizedBox(height: 20),
        _countItem(
          icon: Icons.mode_comment_outlined,
          activeIcon: Icons.mode_comment,
          active: false,
          count: commentCount ?? post.commentCount,
          activeColor: Colors.white,
          onTap: onComment,
        ),
      ],
    );
  }
}
