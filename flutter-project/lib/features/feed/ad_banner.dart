import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../data/models/ad.dart';

/// 首页顶部广告位（轮播）。
class AdBanner extends ConsumerStatefulWidget {
  const AdBanner({super.key});

  @override
  ConsumerState<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends ConsumerState<AdBanner> {
  List<AdItem> _ads = const [];
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final ads = await ref.read(adRepositoryProvider).fetch();
      if (!mounted) return;
      setState(() {
        _ads = ads.where((ad) => ad.imageUrl.isNotEmpty).toList();
        _index = 0;
      });
      _startTimer();
    } catch (_) {
      // 广告加载失败不阻塞主流程
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (_ads.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % _ads.length);
    });
  }

  static const Map<String, String> _routeMap = {
    '/explore': '/feed',
    '/feed': '/feed',
    '/search': '/search',
    '/vip': '/vip',
    '/wallet': '/wallet',
    '/shop': '/shop',
  };

  void _open(AdItem ad) {
    final link = ad.linkUrl;
    if (link == null || link.isEmpty) return;
    final target = _routeMap[link.split('?').first];
    if (target != null) {
      context.push(target);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('请在浏览器打开：$link')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ads.isEmpty) return const SizedBox.shrink();
    final ad = _ads[_index];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: GestureDetector(
        onTap: () => _open(ad),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              Image.network(
                ad.imageUrl,
                height: 88,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
              if (ad.title.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.fromLTRB(12, 16, 12, 8),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                      ),
                    ),
                    child: Text(
                      ad.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              if (_ads.length > 1)
                Positioned(
                  right: 10,
                  bottom: 8,
                  child: Row(
                    children: List.generate(
                      _ads.length,
                      (i) => Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(left: 5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _index
                              ? Colors.white
                              : Colors.white54,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
