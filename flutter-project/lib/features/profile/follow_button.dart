import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../core/network/api_exception.dart';
import '../../data/models/follow.dart';
import 'profile_providers.dart';

/// 关注 / 取关按钮。自见（本人主页）时自动隐藏。
/// 依 [FollowStatus.buttonType]：follow / unfollow / mutual / back / self。
class FollowButton extends ConsumerStatefulWidget {
  final String account;
  final double height;
  const FollowButton({super.key, required this.account, this.height = 34});

  @override
  ConsumerState<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<FollowButton> {
  bool _busy = false;

  Future<void> _toggle(bool willFollow) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(userRepositoryProvider);
      if (willFollow) {
        await repo.follow(widget.account);
      } else {
        await repo.unfollow(widget.account);
      }
      // ignore: use_build_context_synchronously
      ref.invalidate(followStatusProvider(widget.account));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(followStatusProvider(widget.account));
    if (status.isLoading) return SizedBox(height: widget.height);
    final s = status.valueOrNull ?? FollowStatus.none;
    if (s.isSelf) return const SizedBox.shrink();
    final following = s.isFollowing;
    final label = switch (s.buttonType) {
      'mutual' => '互相关注',
      'back' => '回关',
      'unfollow' => '已关注',
      _ => '关注',
    };
    final primary = !following; // 关注 / 回关 为主色
    return SizedBox(
      height: widget.height,
      child: TextButton.icon(
        onPressed: _busy ? null : () => _toggle(!following), // 未关注->关注，已关注->取关
        icon: _busy
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(following ? Icons.check : Icons.add, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 13)),
        style: TextButton.styleFrom(
          backgroundColor: primary ? AppColors.primary : Colors.transparent,
          foregroundColor: primary ? Colors.white : AppColors.textSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          side: primary ? null : const BorderSide(color: AppColors.divider),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
