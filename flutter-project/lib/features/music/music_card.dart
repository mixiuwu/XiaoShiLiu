import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../data/models/music.dart';

/// 原声 / 背景音乐卡：展示曲目信息，可点击（[onTap]）。
class MusicCard extends StatelessWidget {
  final Music music;
  final VoidCallback? onTap;
  final bool dark;
  const MusicCard({
    super.key,
    required this.music,
    this.onTap,
    this.dark = true,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = dark ? Colors.white : AppColors.textPrimary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: dark ? Colors.black.withOpacity(0.3) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: ClipOval(
                child: music.coverUrl != null
                    ? CachedNetworkImage(
                        imageUrl: music.coverUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            const Icon(Icons.audiotrack, size: 16),
                      )
                    : const ColoredBox(
                        color: AppColors.surfaceAlt,
                        child: Icon(Icons.audiotrack,
                            size: 16, color: AppColors.cyan),
                      ),
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                '${music.title}${music.author != null ? ' - ${music.author}' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: textColor, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
