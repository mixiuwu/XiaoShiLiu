import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../data/models/post.dart';
import '../common/post_grid_tile.dart';

/// 草稿箱（`/drafts`）：当前登录用户的未发布笔记。
final draftsProvider = FutureProvider.autoDispose<List<Post>>((ref) async {
  final paged = await ref.watch(postRepositoryProvider).list(
        status: 1,
        limit: 30,
      );
  return paged.items;
});

class DraftsScreen extends ConsumerWidget {
  const DraftsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drafts = ref.watch(draftsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('草稿箱'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(draftsProvider),
          ),
        ],
      ),
      body: drafts.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
        error: (_, __) => const Center(
          child: Text(
            '草稿加载失败，请下拉重试',
            style: TextStyle(color: AppColors.textTertiary),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.edit_note,
                      size: 56, color: AppColors.textTertiary),
                  const SizedBox(height: 12),
                  const Text(
                    '暂无草稿',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => context.push('/publish'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: AppColors.neonGradient,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        '去创作',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            onRefresh: () async => ref.invalidate(draftsProvider),
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.75,
              ),
              itemCount: items.length,
              itemBuilder: (_, i) => _DraftTile(post: items[i]),
            ),
          );
        },
      ),
    );
  }
}

class _DraftTile extends StatelessWidget {
  final Post post;
  const _DraftTile({required this.post});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: PostGridTile(post: post)),
        Positioned(
          left: 8,
          top: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              '草稿',
              style: TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }
}
