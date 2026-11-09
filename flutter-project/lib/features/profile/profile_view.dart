import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../core/utils/time_format.dart';
import '../../data/models/post.dart';
import '../../data/models/user.dart';
import '../common/post_grid_tile.dart';
import 'profile_providers.dart';

/// 个人主页统计项：关注 / 粉丝 / 获赞 / 作品。
enum ProfileStat { following, fans, likes, works }

/// 个人主页主体：头像资料 + 关注/粉丝/获赞/作品 + 作品/喜欢/收藏 tabs。
/// 被他人主页（profile_screen）与「我的」（me_screen）复用。
class ProfileView extends ConsumerStatefulWidget {
  final String account;

  /// 头部右侧操作位（关注按钮 / 编辑资料按钮）。
  final Widget? trailingAction;

  /// 头部与 tabs 之间的额外区块（「我的」页的增值入口）。
  final Widget? entries;

  /// 点击「关注 / 粉丝 / 获赞」统计项的回调；「作品」由组件内部切换到作品 tab。
  final ValueChanged<ProfileStat>? onStatTap;
  const ProfileView({
    super.key,
    required this.account,
    this.trailingAction,
    this.entries,
    this.onStatTap,
  });

  @override
  ConsumerState<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<ProfileView>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(userDetailProvider(widget.account));
    return detail.when(
      loading: () => const Center(
        child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppColors.primary)),
      ),
      error: (e, _) => const Center(
        child:
            Text('用户不存在或加载失败', style: TextStyle(color: AppColors.textTertiary)),
      ),
      data: (profile) => Column(
        children: [
          _header(profile),
          if (widget.entries != null) widget.entries!,
          TabBar(
            controller: _tab,
            indicatorWeight: 2.5,
            labelColor: AppColors.textPrimary,
            unselectedLabelColor: AppColors.textTertiary,
            tabs: const [
              Tab(text: '作品'),
              Tab(text: '喜欢'),
              Tab(text: '收藏'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _grid(userWorksProvider(widget.account)),
                _grid(userLikesProvider(widget.account)),
                _grid(userCollectionsProvider(widget.account)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(UserProfile p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipOval(
                child: CachedNetworkImage(
                  imageUrl: p.avatar,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const ColoredBox(
                      color: AppColors.surface,
                      child: Icon(Icons.person, size: 36)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(p.nickname,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700)),
                        ),
                        if (p.isVip) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => context.push('/vip'),
                            child: _VipBadge(level: p.vipLevel),
                          ),
                        ],
                        if (p.verified) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.check_circle,
                              size: 16, color: AppColors.cyan),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('小石榴号 ${p.account}',
                        style: const TextStyle(
                            color: AppColors.textTertiary, fontSize: 12)),
                    if (p.bio != null && p.bio!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(p.bio!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)),
                    ],
                    if (p.location != null && p.location!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.place_outlined,
                              size: 12, color: AppColors.textTertiary),
                          const SizedBox(width: 2),
                          Text(p.location!,
                              style: const TextStyle(
                                  color: AppColors.textTertiary, fontSize: 12)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.trailingAction != null) widget.trailingAction!,
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _stat('${p.followCount}', '关注', ProfileStat.following),
              _stat('${p.fansCount}', '粉丝', ProfileStat.fans),
              _stat(TimeFormat.compact(p.likeCount), '获赞', ProfileStat.likes),
              _stat('${p.postCount}', '作品', ProfileStat.works),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label, ProfileStat stat) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          if (stat == ProfileStat.works) {
            // 作品：回到同一主页的「作品」tab。
            _tab.animateTo(0);
            return;
          }
          widget.onStatTap?.call(stat);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Text(value,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textTertiary, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _grid(ProviderListenable<AsyncValue<List<Post>>> provider) {
    final list = ref.watch(provider);
    return list.when(
      loading: () => const Center(
        child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppColors.primary)),
      ),
      error: (e, _) => const Center(
          child: Text('加载失败', style: TextStyle(color: AppColors.textTertiary))),
      data: (posts) {
        if (posts.isEmpty) {
          return const Center(
              child: Text('暂无内容',
                  style: TextStyle(color: AppColors.textTertiary)));
        }
        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.72,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: posts.length,
          itemBuilder: (_, i) => PostGridTile(post: posts[i]),
        );
      },
    );
  }
}

class _VipBadge extends StatelessWidget {
  final int level;

  const _VipBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    // 等级收敛到 1~7，按等级展示对应的 VIP 徽章图
    final badgeLevel = level < 1 ? 1 : (level > 7 ? 7 : level);
    return Image.asset(
      'assets/images/vip/vip$badgeLevel.png',
      height: 20,
      fit: BoxFit.contain,
    );
  }
}
