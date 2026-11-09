import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../core/network/api_exception.dart';
import '../../data/models/poll.dart';

/// 投票卡：未投票显示可选项；已投票/过期显示百分比进度条。每人仅可投一次。
class PollCard extends ConsumerStatefulWidget {
  final Poll poll;
  const PollCard({super.key, required this.poll});

  @override
  ConsumerState<PollCard> createState() => _PollCardState();
}

class _PollCardState extends ConsumerState<PollCard> {
  late Poll _poll = widget.poll;
  bool _busy = false;

  @override
  void didUpdateWidget(covariant PollCard old) {
    super.didUpdateWidget(old);
    if (old.poll.id != widget.poll.id) _poll = widget.poll;
  }

  bool get _showResult => _poll.voted || _poll.expired;

  Future<void> _vote(int optionId) async {
    if (_busy || _showResult) return;
    setState(() => _busy = true);
    try {
      final res =
          await ref.read(pollRepositoryProvider).vote('${_poll.id}', optionId);
      setState(() => _poll = res);
    } on ApiException catch (e) {
      _toast(e.isConflict ? '你已参与过该投票' : e.message);
      if (e.isConflict) {
        try {
          final res =
              await ref.read(pollRepositoryProvider).detail('${_poll.id}');
          setState(() => _poll = res);
        } catch (_) {}
      }
    } catch (_) {
      _toast('投票失败，请稍后重试');
    } finally {
      setState(() => _busy = false);
    }
  }

  void _toast(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.poll_outlined, color: AppColors.cyan, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _poll.question,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${_poll.totalVotes} 人参与${_poll.expired ? ' · 已结束' : ''}',
            style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
          ),
          const SizedBox(height: 10),
          ..._poll.options.map(_optionRow),
        ],
      ),
    );
  }

  Widget _optionRow(PollOption o) {
    final highlight = o.selected;
    if (!_showResult) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          onTap: _busy ? null : () => _vote(o.id),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary.withOpacity(0.6)),
            ),
            child: Text(
              o.content,
              style:
                  const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            ),
          ),
        ),
      );
    }

    final pct = o.percentage.clamp(0, 100) / 100;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: LayoutBuilder(
        builder: (_, constraints) {
          return Stack(
            children: [
              Container(
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: pct),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOut,
                    builder: (_, v, __) => Container(
                      height: 42,
                      width: constraints.maxWidth * v,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: LinearGradient(
                          colors: [
                            (highlight ? AppColors.primary : AppColors.purple)
                                .withOpacity(0.55),
                            (highlight ? AppColors.purple : AppColors.cyan)
                                .withOpacity(0.25),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      if (highlight) ...[
                        const Icon(Icons.check_circle,
                            color: AppColors.primary, size: 16),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          o.content,
                          style: TextStyle(
                            color: highlight
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontSize: 14,
                            fontWeight:
                                highlight ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                      ),
                      Text(
                        '${o.percentage.toStringAsFixed(0)}%',
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
