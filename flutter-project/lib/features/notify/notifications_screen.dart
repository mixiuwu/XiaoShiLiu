import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../core/utils/time_format.dart';
import '../../data/models/notification.dart';
import '../../data/repositories/notification_repository.dart';
import 'notification_providers.dart';

/// 消息中心：评论 / 点赞 / 收藏 / 关注 分组。
/// [initialTab] 支持通过 `/notify?tab=likes|collections|follows` 指定初始分组。
class NotificationsScreen extends ConsumerStatefulWidget {
  final String? initialTab;
  const NotificationsScreen({super.key, this.initialTab});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  static const _kinds = [
    NotifyGroup.comments,
    NotifyGroup.likes,
    NotifyGroup.collections,
    NotifyGroup.follows,
  ];
  static const _labels = ['评论', '点赞', '收藏', '关注'];

  static int _indexOf(String? tab) => switch (tab) {
        'likes' => 1,
        'collections' => 2,
        'follows' => 3,
        _ => 0,
      };

  @override
  void initState() {
    super.initState();
    _tab = TabController(
      length: _kinds.length,
      vsync: this,
      initialIndex: _indexOf(widget.initialTab),
    );
  }

  @override
  void didUpdateWidget(covariant NotificationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab) {
      final index = _indexOf(widget.initialTab);
      if (index != _tab.index) _tab.animateTo(index);
    }
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _markAllRead() async {
    try {
      await ref.read(notificationRepositoryProvider).markAllRead();
    } catch (_) {}
    ref.invalidate(unreadByTypeProvider);
    for (final k in _kinds) {
      ref.invalidate(notifyGroupProvider(k));
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(unreadByTypeProvider).valueOrNull;
    final counts = [
      unread?.comments ?? 0,
      unread?.likes ?? 0,
      unread?.collections ?? 0,
      unread?.follows ?? 0,
    ];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('消息'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: const Text('全部已读',
                style: TextStyle(color: AppColors.cyan, fontSize: 13)),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorWeight: 2.5,
          labelColor: AppColors.textPrimary,
          unselectedLabelColor: AppColors.textTertiary,
          tabs: List.generate(_kinds.length, (i) {
            final c = counts[i];
            return Tab(
              height: 44,
              child: _TabLabel(text: _labels[i], badge: c),
            );
          }),
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: _kinds.map((k) => _GroupTab(kind: k)).toList(),
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  final String text;
  final int badge;
  const _TabLabel({required this.text, required this.badge});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Text(text),
        if (badge > 0)
          Positioned(
            right: -12,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10)),
              child: Text(
                badge > 99 ? '99+' : '$badge',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
      ],
    );
  }
}

class _GroupTab extends ConsumerStatefulWidget {
  final String kind;
  const _GroupTab({required this.kind});

  @override
  ConsumerState<_GroupTab> createState() => _GroupTabState();
}

class _GroupTabState extends ConsumerState<_GroupTab> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
        ref.read(notifyGroupProvider(widget.kind).notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _open(AppNotification n) {
    ref.read(notifyGroupProvider(widget.kind).notifier).markRead(n.id);
    ref.invalidate(unreadByTypeProvider);
    if (n.type == 6 || n.targetId == 0) {
      context.push('/user/${n.fromAccount}');
    } else {
      context.push(
          n.postType == 2 ? '/player/${n.targetId}' : '/post/${n.targetId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notifyGroupProvider(widget.kind));
    if (state.items.isEmpty && state.loading) {
      return const Center(
        child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppColors.primary)),
      );
    }
    if (state.items.isEmpty) {
      return const Center(
          child: Text('暂无消息', style: TextStyle(color: AppColors.textTertiary)));
    }
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      onRefresh: () async => ref.invalidate(notifyGroupProvider(widget.kind)),
      child: ListView.separated(
        controller: _scroll,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: state.items.length + (state.hasMore ? 1 : 0),
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: AppColors.divider),
        itemBuilder: (_, i) {
          if (i >= state.items.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(AppColors.primary))),
              ),
            );
          }
          return _tile(state.items[i]);
        },
      ),
    );
  }

  Widget _tile(AppNotification n) {
    final opacity = n.isRead ? 0.55 : 1.0;
    final secondLine = n.commentContent != null && n.commentContent!.isNotEmpty
        ? n.commentContent!
        : (n.postTitle ?? '');
    return ListTile(
      onTap: () => _open(n),
      leading: ClipOval(
        child: CachedNetworkImage(
          imageUrl: n.fromAvatar,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => const ColoredBox(
              color: AppColors.surface, child: Icon(Icons.person)),
        ),
      ),
      title: Text(
        '${n.fromNickname} ${n.title}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            color: AppColors.textPrimary.withOpacity(opacity),
            fontSize: 14,
            fontWeight: n.isRead ? FontWeight.normal : FontWeight.w600),
      ),
      subtitle: secondLine.isEmpty
          ? null
          : Text(secondLine,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: AppColors.textTertiary.withOpacity(opacity),
                  fontSize: 12)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(TimeFormat.relative(n.createdAt),
              style:
                  const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
          const SizedBox(height: 4),
          if (n.postImage != null && n.postImage!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: CachedNetworkImage(
                imageUrl: n.postImage!,
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    const SizedBox(width: 36, height: 36),
              ),
            )
          else if (!n.isRead)
            const Icon(Icons.circle, size: 8, color: AppColors.primary),
        ],
      ),
    );
  }
}
