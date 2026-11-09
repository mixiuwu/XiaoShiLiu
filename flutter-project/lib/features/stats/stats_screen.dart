import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../core/utils/time_format.dart';
import '../profile/profile_providers.dart';

/// 创作数据看板（`/stats`）：本人作品 / 播放 / 互动汇总。
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(authControllerProvider).user?.account;
    if (account == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('创作看板')),
        body: const Center(
            child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppColors.primary))),
      );
    }
    final stats = ref.watch(userStatsProvider(account));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('创作看板'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(userStatsProvider(account))),
        ],
      ),
      body: stats.when(
        loading: () => const Center(
            child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppColors.primary))),
        error: (e, _) => const Center(
            child: Text('数据加载失败',
                style: TextStyle(color: AppColors.textTertiary))),
        data: (s) => RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: () async => ref.invalidate(userStatsProvider(account)),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _hero(context, '本周播放', TimeFormat.compact(s.weeklyViews),
                  Icons.visibility, AppColors.cyan, '/user/$account'),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _cell(context, '作品', s.postCount, Icons.article_outlined,
                      AppColors.primary, '/user/$account'),
                  _cell(context, '获赞', s.receivedLikeCount,
                      Icons.favorite_border, AppColors.primary,
                      '/notify?tab=likes'),
                  _cell(context, '获收藏', s.collectCount, Icons.star_border,
                      AppColors.coin, '/notify?tab=collections'),
                  _cell(context, '赞藏合计', s.likesAndCollects,
                      Icons.trending_up, AppColors.purple, '/notify?tab=likes'),
                  _cell(context, '粉丝', s.fansCount, Icons.people_alt_outlined,
                      AppColors.cyan, '/user/$account/follows/followers'),
                  _cell(context, '关注', s.followCount, Icons.person_search,
                      AppColors.textSecondary,
                      '/user/$account/follows/following'),
                  _cell(context, '草稿箱', s.draftCount, Icons.edit_note,
                      AppColors.textSecondary, '/drafts'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, String location) {
    if (location.startsWith('/notify')) {
      // 通知页属于底部 Tab 分支，使用 go 切换分组
      context.go(location);
      return;
    }
    context.push(location);
  }

  Widget _hero(BuildContext context, String label, String value, IconData icon,
      Color color, String location) {
    return GestureDetector(
      onTap: () => _open(context, location),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppColors.neonGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppColors.glow(color, blur: 18, y: 6),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  Widget _cell(BuildContext context, String label, int value, IconData icon,
      Color color, String location) {
    return GestureDetector(
      onTap: () => _open(context, location),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 22),
                const Spacer(),
                const Icon(Icons.chevron_right,
                    color: AppColors.textTertiary, size: 16),
              ],
            ),
            const SizedBox(height: 10),
            Text(TimeFormat.compact(value),
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    color: AppColors.textTertiary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
