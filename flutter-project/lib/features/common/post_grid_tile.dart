import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../data/models/post.dart';

/// 通用的笔记网格卡片（个人主页 / 搜索结果复用）。
/// 视频类跳全屏播放器，图文类跳详情页。
class PostGridTile extends StatelessWidget {
  final Post post;
  const PostGridTile({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final cover = post.thumbnail;
    return GestureDetector(
      onTap: () => context
          .push(post.type == 2 ? '/player/${post.id}' : '/post/${post.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (cover != null)
                    CachedNetworkImage(
                      imageUrl: cover,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          const Icon(Icons.broken_image_outlined),
                    )
                  else
                    const Center(
                        child: Icon(Icons.image_outlined,
                            color: AppColors.textTertiary)),
                  if (post.type == 2)
                    const Positioned(
                      left: 8,
                      top: 8,
                      child: Icon(Icons.play_circle_fill,
                          color: Colors.white70, size: 20),
                    ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Row(
                      children: [
                        const Icon(Icons.favorite,
                            size: 13, color: Colors.white70),
                        const SizedBox(width: 3),
                        Text('${post.likeCount}',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Text(
                post.title.isEmpty ? post.content : post.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
