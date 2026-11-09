import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../core/utils/time_format.dart';
import '../../data/models/order.dart';
import '../../data/repositories/shop_repository.dart';

class OrdersState {
  final List<Order> items;
  final int page;
  final bool hasMore;
  final bool loading;
  const OrdersState({
    this.items = const [],
    this.page = 0,
    this.hasMore = true,
    this.loading = false,
  });

  OrdersState copyWith(
          {List<Order>? items, int? page, bool? hasMore, bool? loading}) =>
      OrdersState(
        items: items ?? this.items,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        loading: loading ?? this.loading,
      );
}

class OrdersController extends StateNotifier<OrdersState> {
  final ShopRepository repo;
  OrdersController(this.repo) : super(const OrdersState());

  Future<void> load() async {
    if (state.loading || state.page > 0) return;
    state = state.copyWith(loading: true);
    try {
      final p = await repo.orders(page: 1);
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
      final p = await repo.orders(page: state.page + 1);
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

final ordersProvider =
    StateNotifierProvider.autoDispose<OrdersController, OrdersState>((ref) {
  final c = OrdersController(ref.watch(shopRepositoryProvider));
  c.load();
  return c;
});

/// 我的订单。
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
        ref.read(ordersProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Color _statusColor(int status) => switch (status) {
        2 => AppColors.success,
        1 => AppColors.cyan,
        _ => AppColors.coin,
      };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ordersProvider);
    if (state.items.isEmpty && state.loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
            child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppColors.primary))),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('我的订单')),
      body: state.items.isEmpty
          ? const Center(
              child: Text('还没有订单，去逛逛商城吧',
                  style: TextStyle(color: AppColors.textTertiary)))
          : RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              onRefresh: () async => ref.invalidate(ordersProvider),
              child: ListView.separated(
                controller: _scroll,
                padding: const EdgeInsets.all(12),
                itemCount: state.items.length + (state.hasMore ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  if (i >= state.items.length) {
                    return const Center(
                        child: Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation(AppColors.primary))),
                    ));
                  }
                  final o = state.items[i];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: o.coverUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: o.coverUrl!,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => const ColoredBox(
                                      color: AppColors.surfaceAlt,
                                      child: Icon(Icons.image_outlined)))
                              : const SizedBox(
                                  width: 56,
                                  height: 56,
                                  child: ColoredBox(
                                      color: AppColors.surfaceAlt,
                                      child: Icon(Icons.storefront_outlined,
                                          color: AppColors.textTertiary))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(o.productName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(
                                  'x${o.quantity} · ${TimeFormat.relative(o.createdAt)}',
                                  style: const TextStyle(
                                      color: AppColors.textTertiary,
                                      fontSize: 11)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _statusColor(o.status).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(o.statusText,
                                  style: TextStyle(
                                      color: _statusColor(o.status),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.monetization_on,
                                    size: 13, color: AppColors.coin),
                                Text('${o.totalCoin}',
                                    style: const TextStyle(
                                        color: AppColors.coin,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}
