import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../core/network/api_exception.dart';
import '../../data/models/product.dart';
import '../wallet/wallet_screen.dart';

final productsProvider = FutureProvider.autoDispose<List<Product>>(
    (ref) => ref.watch(shopRepositoryProvider).products());

/// 商城：金币兑换商品，下单扣币。
class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  Future<void> _confirm(BuildContext context, WidgetRef ref, Product p) async {
    final coin = ref.read(walletProvider).valueOrNull?.coinBalance ?? 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title:
            const Text('确认下单', style: TextStyle(color: AppColors.textPrimary)),
        content: Text('「${p.name}」\n花费 ${p.priceCoin} 金币\n当前余额 $coin 金币',
            style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('下单', style: TextStyle(color: AppColors.primary))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final res = await ref.read(shopRepositoryProvider).createOrder(p.id);
      if (!context.mounted) return;
      ref.invalidate(productsProvider);
      ref.invalidate(walletProvider);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('下单成功，订单号 ${res.orderId}')));
      context.push('/orders');
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
            .showSnackBar(const SnackBar(content: Text('下单失败，请稍后重试')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('商城'),
        actions: [
          IconButton(
              icon: const Icon(Icons.receipt_long_outlined),
              tooltip: '我的订单',
              onPressed: () => context.push('/orders')),
        ],
      ),
      body: products.when(
        loading: () => const Center(
            child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppColors.primary))),
        error: (e, _) => const Center(
            child: Text('商品加载失败',
                style: TextStyle(color: AppColors.textTertiary))),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
                child: Text('暂无商品',
                    style: TextStyle(color: AppColors.textTertiary)));
          }
          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            onRefresh: () async => ref.invalidate(productsProvider),
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.66,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: list.length,
              itemBuilder: (_, i) => _ProductCard(
                  product: list[i],
                  onTap: () => _confirm(context, ref, list[i])),
            ),
          );
        },
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  const _ProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = product;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: p.coverUrl != null
                  ? CachedNetworkImage(
                      imageUrl: p.coverUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorWidget: (_, __, ___) => const Center(
                          child: Icon(Icons.storefront_outlined,
                              color: AppColors.textTertiary)),
                    )
                  : const Center(
                      child: Icon(Icons.storefront_outlined,
                          size: 40, color: AppColors.textTertiary)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.monetization_on,
                          size: 14, color: AppColors.coin),
                      const SizedBox(width: 3),
                      Text('${p.priceCoin}',
                          style: const TextStyle(
                              color: AppColors.coin,
                              fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Text(p.inStock ? '库存 ${p.stock}' : '缺货',
                          style: TextStyle(
                              color: p.inStock
                                  ? AppColors.textTertiary
                                  : AppColors.danger,
                              fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
