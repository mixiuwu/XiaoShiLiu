import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/neon_decorations.dart';
import '../profile/profile_view.dart';

/// 「我的」：本人主页 + 增值入口 + 退出登录。
class MeScreen extends ConsumerWidget {
  const MeScreen({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title:
            const Text('退出登录', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('确定要退出当前账号吗？',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('退出', style: TextStyle(color: AppColors.primary))),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(authControllerProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) {
      // 游客态：未登录也能进首页，「我的」提供登录/注册入口。
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('我的'),
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_outline,
                  size: 56, color: AppColors.textTertiary),
              const SizedBox(height: 12),
              const Text('登录后可查看主页与互动数据',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 24),
              SizedBox(
                width: 220,
                child: NeonButton(
                  label: '登录',
                  onPressed: () => context.push('/login'),
                ),
              ),
              TextButton(
                onPressed: () => context.push('/register'),
                child: const Text('注册新账号',
                    style: TextStyle(color: AppColors.primary)),
              ),
            ],
          ),
        ),
      );
    }
    final account = user.account;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('我的'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.textSecondary),
            tooltip: '退出登录',
            onPressed: () => _confirmLogout(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        child: ProfileView(
          account: account,
          trailingAction: _editButton(context),
          entries: _entries(context),
          onStatTap: (stat) {
            switch (stat) {
              case ProfileStat.following:
                context.push('/user/$account/follows/following');
              case ProfileStat.fans:
                context.push('/user/$account/follows/followers');
              case ProfileStat.likes:
                context.go('/notify?tab=likes');
              case ProfileStat.works:
                break;
            }
          },
        ),
      ),
    );
  }

  Widget _editButton(BuildContext context) {
    return TextButton(
      onPressed: () => context.push('/edit-profile'),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        side: const BorderSide(color: AppColors.divider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: const Text('编辑资料', style: TextStyle(fontSize: 13)),
    );
  }

  Widget _entries(BuildContext context) {
    const items = <_EntryItem>[
      _EntryItem(Icons.account_balance_wallet_outlined, '钱包', '/wallet',
          AppColors.coin),
      _EntryItem(
          Icons.workspace_premium_outlined, 'VIP', '/vip', AppColors.purple),
      _EntryItem(Icons.storefront_outlined, '商城', '/shop', AppColors.cyan),
      _EntryItem(Icons.receipt_long_outlined, '订单', '/orders',
          AppColors.textSecondary),
      _EntryItem(Icons.insights_outlined, '创作看板', '/stats', AppColors.primary),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: items
            .map((e) => Expanded(
                  child: InkWell(
                    onTap: () => context.push(e.route),
                    child: Column(
                      children: [
                        Icon(e.icon, color: e.color, size: 24),
                        const SizedBox(height: 6),
                        Text(e.label,
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _EntryItem {
  final IconData icon;
  final String label;
  final String route;
  final Color color;
  const _EntryItem(this.icon, this.label, this.route, this.color);
}
