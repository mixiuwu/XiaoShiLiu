import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';

/// 底部导航外壳：首页 / 发现 / (中央发布) / 消息 / 我的。
/// 采用 [StatefulNavigationShell] 保留各分支导航栈；中央 + 触发 push 发布页。
class HomeShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const HomeShell({super.key, required this.navigationShell});

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: navigationShell,
      bottomNavigationBar: _NeonNavBar(
        currentIndex: navigationShell.currentIndex,
        onSelect: _goBranch,
        onPublish: () => context.push('/publish'),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(this.icon, this.activeIcon, this.label);
}

class _NeonNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onPublish;

  const _NeonNavBar({
    required this.currentIndex,
    required this.onSelect,
    required this.onPublish,
  });

  static const _left = [
    _NavItem(Icons.home_outlined, Icons.home, '首页'),
    _NavItem(Icons.explore_outlined, Icons.explore, '发现'),
  ];
  static const _right = [
    _NavItem(Icons.notifications_none, Icons.notifications, '消息'),
    _NavItem(Icons.person_outline, Icons.person, '我的'),
  ];

  Widget _tile(_NavItem item, int index, bool selected) {
    final color = selected ? AppColors.primary : AppColors.textTertiary;
    return Expanded(
      child: InkWell(
        onTap: () => onSelect(index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? item.activeIcon : item.icon,
                color: color, size: 24),
            const SizedBox(height: 2),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.pureBlack,
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.6)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              _tile(_left[0], 0, currentIndex == 0),
              _tile(_left[1], 1, currentIndex == 1),
              Expanded(
                child: Center(
                  child: GestureDetector(
                    onTap: onPublish,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppColors.neonGradient,
                        shape: BoxShape.circle,
                        boxShadow:
                            AppColors.glow(AppColors.primary, blur: 14, y: 2),
                      ),
                      child:
                          const Icon(Icons.add, color: Colors.white, size: 26),
                    ),
                  ),
                ),
              ),
              _tile(_right[0], 2, currentIndex == 2),
              _tile(_right[1], 3, currentIndex == 3),
            ],
          ),
        ),
      ),
    );
  }
}
