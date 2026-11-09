import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/neon_decorations.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/time_format.dart';
import '../../data/models/wallet.dart';
import '../../data/repositories/wallet_repository.dart';

final walletProvider = FutureProvider.autoDispose<Wallet>(
    (ref) => ref.watch(walletRepositoryProvider).get());

class TxState {
  final List<CoinTransaction> items;
  final int page;
  final bool hasMore;
  final bool loading;
  const TxState({
    this.items = const [],
    this.page = 0,
    this.hasMore = true,
    this.loading = false,
  });

  TxState copyWith(
          {List<CoinTransaction>? items,
          int? page,
          bool? hasMore,
          bool? loading}) =>
      TxState(
        items: items ?? this.items,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        loading: loading ?? this.loading,
      );
}

class TxController extends StateNotifier<TxState> {
  final WalletRepository repo;
  TxController(this.repo) : super(const TxState());

  Future<void> load() async {
    if (state.loading || state.page > 0) return;
    state = state.copyWith(loading: true);
    try {
      final p = await repo.transactions(page: 1);
      state = state.copyWith(
          items: p.items,
          page: 1,
          hasMore: p.pagination.hasNext,
          loading: false);
    } catch (_) {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> loadMore() async {
    if (state.loading || !state.hasMore || state.page == 0) return;
    state = state.copyWith(loading: true);
    try {
      final p = await repo.transactions(page: state.page + 1);
      state = state.copyWith(
        items: [...state.items, ...p.items],
        page: state.page + 1,
        hasMore: p.pagination.hasNext,
        loading: false,
      );
    } catch (_) {
      state = state.copyWith(loading: false);
    }
  }
}

final txProvider =
    StateNotifierProvider.autoDispose<TxController, TxState>((ref) {
  final c = TxController(ref.watch(walletRepositoryProvider));
  c.load();
  return c;
});

/// 钱包：金币余额 / 可提现 / 提现 / 金币流水。
class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  static const int minWithdrawCoin = 100;

  Future<void> _withdraw(
      BuildContext context, WidgetRef ref, Wallet wallet) async {
    final amount = await showWithdrawSheet(context, wallet);
    if (amount == null || amount < minWithdrawCoin) {
      if (amount != null && amount > 0 && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('提现金币不能少于 $minWithdrawCoin')));
      }
      return;
    }
    try {
      final res = await ref.read(walletRepositoryProvider).withdraw(amount);
      if (!context.mounted) return;
      ref.invalidate(walletProvider);
      ref.invalidate(txProvider);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('提现申请已受理',
              style: TextStyle(color: AppColors.textPrimary)),
          content: Text(
              '提现 ${res.withdrawnCoin} 金币 ≈ ¥${res.yuan.toStringAsFixed(2)}\n'
              '剩余金币 ${res.coinBalance}\n状态：${res.status == 'pending' ? '处理中' : res.status}',
              style: const TextStyle(color: AppColors.textSecondary)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('知道了',
                    style: TextStyle(color: AppColors.primary))),
          ],
        ),
      );
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('提现失败，请稍后重试')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(walletProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('钱包'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(walletProvider);
              ref.invalidate(txProvider);
            },
          ),
        ],
      ),
      body: wallet.when(
        loading: () => const Center(
            child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppColors.primary))),
        error: (e, _) => const Center(
            child: Text('钱包加载失败',
                style: TextStyle(color: AppColors.textTertiary))),
        data: (w) => Column(
          children: [
            _balanceCard(context, ref, w),
            Expanded(child: _transactions(ref)),
          ],
        ),
      ),
    );
  }

  Widget _balanceCard(BuildContext context, WidgetRef ref, Wallet w) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.neonGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.glow(AppColors.primary, blur: 20, y: 6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('金币余额',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 6),
          Text('${w.coinBalance}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('可提现',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text('¥ ${w.withdrawableYuan.toStringAsFixed(2)}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('1 元 = ${w.coinPerYuan} 金币',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: w.coinBalance >= minWithdrawCoin
                    ? () => _withdraw(context, ref, w)
                    : null,
                icon: const Icon(Icons.account_balance, size: 18),
                label: const Text('提现'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  disabledBackgroundColor: Colors.white24,
                  disabledForegroundColor: Colors.white54,
                  // 覆盖全局主题的 Size.fromHeight(48)（= 无限最小宽），
                  // 否则本按钮位于 Row 中会触发 "BoxConstraints forces an infinite width"。
                  minimumSize: const Size(96, 40),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _transactions(WidgetRef ref) {
    final state = ref.watch(txProvider);
    if (state.items.isEmpty && !state.loading) {
      return const Center(
          child:
              Text('暂无金币流水', style: TextStyle(color: AppColors.textTertiary)));
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: state.items.length + (state.hasMore ? 1 : 0),
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: AppColors.divider),
      itemBuilder: (_, i) {
        if (i >= state.items.length) {
          WidgetsBinding.instance.addPostFrameCallback(
              (_) => ref.read(txProvider.notifier).loadMore());
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(AppColors.primary))),
            ),
          );
        }
        return _txTile(state.items[i]);
      },
    );
  }

  /// 金币流水场景字段 → 中文文案
  static const Map<String, String> _sceneLabels = {
    'register': '注册奖励',
    'post': '发布笔记',
    'like': '点赞奖励',
    'follow': '关注奖励',
    'publish_note': '发表内容',
    'publish_video': '发布视频',
    'watch_ad': '看广告',
    'watch_video': '看视频',
    'danmaku': '发弹幕',
    'comment': '发表评论',
    'vip': 'VIP开通',
    'vip_renew': 'VIP续费',
    'shop': '商城消费',
    'withdraw': '金币提现',
    'admin_adjust': '管理员调整',
    'sign_in': '每日签到',
  };

  String _sceneLabel(CoinTransaction t) {
    final label = _sceneLabels[t.scene];
    if (label != null) return label;
    // 未知场景不直接展示原始字段，统一按收支文案兜底
    return t.isIncome ? '金币收入' : '金币支出';
  }

  Widget _txTile(CoinTransaction t) {
    final color = t.isIncome ? AppColors.success : AppColors.danger;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Row(
        children: [
          Expanded(
            child: Text(_sceneLabel(t),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 14)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(t.isIncome ? '收入' : '支出',
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      subtitle: Text(
          '${TimeFormat.relative(t.createdAt)} · 余额 ${t.balanceAfter}',
          style: const TextStyle(color: AppColors.textTertiary, fontSize: 11)),
      trailing: Text(
        '${t.isIncome ? '+' : '-'}${t.amount.abs()}',
        style:
            TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15),
      ),
    );
  }
}

/// 提现金额输入弹层，返回输入的金币数（null 表示取消）。
Future<int?> showWithdrawSheet(BuildContext context, Wallet wallet) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    builder: (_) => _WithdrawSheet(wallet: wallet),
  );
}

class _WithdrawSheet extends StatefulWidget {
  final Wallet wallet;
  const _WithdrawSheet({required this.wallet});

  @override
  State<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends State<_WithdrawSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('申请提现',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
              '当前金币 ${widget.wallet.coinBalance}，最低提现 ${WalletScreen.minWithdrawCoin} 金币',
              style:
                  const TextStyle(color: AppColors.textTertiary, fontSize: 12)),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: '提现金币数',
              labelStyle: TextStyle(color: AppColors.textSecondary),
              enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.divider)),
              focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary)),
            ),
          ),
          const SizedBox(height: 18),
          NeonButton(
            label: '提交',
            height: 46,
            onPressed: () {
              final v = int.tryParse(_ctrl.text) ?? 0;
              Navigator.pop(context, v > 0 ? v : null);
            },
          ),
        ],
      ),
    );
  }
}
