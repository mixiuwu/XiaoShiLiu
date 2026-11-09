import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../data/models/user.dart';
import 'profile_providers.dart';

/// 关注 / 粉丝列表（`/user/:account/follows/:type`）。
/// [type] 为 `following` 或 `followers`，决定默认选中的 tab。
class FollowListScreen extends ConsumerStatefulWidget {
  final String account;
  final String type;

  const FollowListScreen({
    super.key,
    required this.account,
    this.type = 'following',
  });

  @override
  ConsumerState<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends ConsumerState<FollowListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.type == 'followers' ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('关注与粉丝'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tab,
          indicatorWeight: 2.5,
          labelColor: AppColors.textPrimary,
          unselectedLabelColor: AppColors.textTertiary,
          tabs: const [
            Tab(text: '关注'),
            Tab(text: '粉丝'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _UserList(
            title: '暂无关注',
            provider: followingUsersProvider(widget.account),
          ),
          _UserList(
            title: '暂无粉丝',
            provider: followersUsersProvider(widget.account),
          ),
        ],
      ),
    );
  }
}

class _UserList extends ConsumerWidget {
  final String title;
  final AutoDisposeFutureProvider<List<UserProfile>> provider;

  const _UserList({required this.title, required this.provider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(provider);
    return list.when(
      loading: () => const Center(
        child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppColors.primary)),
      ),
      error: (_, __) => const Center(
        child: Text('加载失败', style: TextStyle(color: AppColors.textTertiary)),
      ),
      data: (users) {
        if (users.isEmpty) {
          return Center(
            child: Text(title,
                style: const TextStyle(color: AppColors.textTertiary)),
          );
        }
        return RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: () async => ref.invalidate(provider),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: users.length,
            itemBuilder: (_, i) => _UserTile(user: users[i]),
          ),
        );
      },
    );
  }
}

class _UserTile extends StatelessWidget {
  final UserProfile user;

  const _UserTile({required this.user});

  @override
  Widget build(BuildContext context) {
    final subtitle =
        user.bio != null && user.bio!.isNotEmpty ? user.bio! : '小石榴号 ${user.account}';
    return ListTile(
      onTap: () => context.push('/user/${user.account}'),
      leading: ClipOval(
        child: CachedNetworkImage(
          imageUrl: user.avatar,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => const ColoredBox(
              color: AppColors.surface, child: Icon(Icons.person)),
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(user.nickname,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textPrimary)),
          ),
          if (user.verified)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.check_circle, size: 14, color: AppColors.cyan),
            ),
        ],
      ),
      subtitle: Text(subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.textTertiary)),
    );
  }
}
