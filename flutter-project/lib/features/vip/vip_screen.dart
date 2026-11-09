import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/neon_decorations.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/time_format.dart';
import '../../data/models/vip.dart';
import '../profile/profile_providers.dart';
import '../wallet/wallet_screen.dart';

final vipPlansProvider = FutureProvider.autoDispose<List<VipPlan>>(
    (ref) => ref.watch(vipRepositoryProvider).plans());

final vipStatusProvider = FutureProvider.autoDispose<VipStatus>(
    (ref) => ref.watch(vipRepositoryProvider).status());

/// VIP：会员状态 + 套餐 + 金币开通。
class VipScreen extends ConsumerWidget {
  const VipScreen({super.key});

  Future<void> _purchase(
      BuildContext context, WidgetRef ref, VipPlan plan) async {
    try {
      final res = await ref.read(vipRepositoryProvider).purchase(plan.id);
      if (!context.mounted) return;
      ref.invalidate(vipStatusProvider);
      ref.invalidate(walletProvider);
      final account = ref.read(authControllerProvider).user?.account;
      if (account != null) {
        final fresh = await ref.read(userRepositoryProvider).detail(account);
        ref.read(authControllerProvider.notifier).setUser(fresh);
        ref.invalidate(userDetailProvider(account));
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '开通成功！Lv.${res.level} · 到期 ${TimeFormat.date(DateTime.tryParse(res.expireAt ?? '') ?? DateTime.now())}'),
      ));
    } on ApiException catch (e) {
      if (!context.mounted) return;
      final insufficient = e.message.contains('金币') || e.message.contains('足');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          action: insufficient
              ? SnackBarAction(
                  label: '去赚币',
                  textColor: AppColors.coin,
                  onPressed: () => context.push('/wallet'))
              : null,
        ),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('开通失败，请稍后重试')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(vipStatusProvider);
    final plans = ref.watch(vipPlansProvider);
    final coin = ref.watch(walletProvider).valueOrNull?.coinBalance ?? 0;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('VIP 会员'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(vipStatusProvider);
              ref.invalidate(vipPlansProvider);
              ref.invalidate(walletProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () async {
          ref.invalidate(vipStatusProvider);
          ref.invalidate(vipPlansProvider);
          ref.invalidate(walletProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _statusCard(status),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // SectionTitle 内部含 Expanded，必须置于有界宽：用 Expanded 包裹，
                // 否则作为本 Row 的非 flex 子项会拿到无限宽导致布局崩溃。
                const Expanded(child: SectionTitle(title: '选择套餐')),
                Text('我的金币 $coin',
                    style:
                        const TextStyle(color: AppColors.coin, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 8),
            plans.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                    child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(AppColors.primary))),
              ),
              error: (e, _) => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('套餐加载失败',
                      style: TextStyle(color: AppColors.textTertiary))),
              data: (list) => Column(
                children:
                    list.map((p) => _planCard(context, ref, p, coin)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusCard(AsyncValue<VipStatus> status) {
    final s = status.valueOrNull;
    final active = s?.isVip ?? false;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.purple, AppColors.primary]),
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.glow(AppColors.purple, blur: 20, y: 6),
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium, color: Colors.white, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: status.isLoading
                ? const Text('加载中…', style: TextStyle(color: Colors.white70))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          active
                              ? '${s!.planName ?? '会员'} · Lv.${s.level}'
                              : '暂未开通会员',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(
                          active
                              ? '剩余 ${s!.remainingDays} 天 · 到期 ${TimeFormat.date(DateTime.tryParse(s.expireAt ?? '') ?? DateTime.now())}'
                              : '开通会员享专属标识与权益',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _planCard(BuildContext context, WidgetRef ref, VipPlan p, int coin) {
    final enough = coin >= p.priceCoin;
    return NeonCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(p.name,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ),
              Text('Lv.${p.level}',
                  style: const TextStyle(
                      color: AppColors.purple, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          Text('${p.durationDays} 天',
              style:
                  const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
          if (p.perks.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: p.perks
                  .map((perk) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(perk,
                            style: const TextStyle(
                                color: AppColors.cyan, fontSize: 11)),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    children: [
                      const TextSpan(
                          text: '仅需 ',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)),
                      TextSpan(
                          text: '${p.priceCoin}',
                          style: const TextStyle(
                              color: AppColors.coin,
                              fontSize: 20,
                              fontWeight: FontWeight.w800)),
                      const TextSpan(
                          text: ' 金币',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: 40,
                child: ElevatedButton(
                  onPressed: enough ? () => _purchase(context, ref, p) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.surfaceAlt,
                    disabledForegroundColor: AppColors.textTertiary,
                    // 覆盖全局主题的无限最小宽，避免本按钮在 Row 中报 "infinite width"。
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(enough ? '立即开通' : '金币不足'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
