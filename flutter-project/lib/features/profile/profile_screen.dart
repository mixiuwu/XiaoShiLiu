import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import 'follow_button.dart';
import 'profile_view.dart';

/// 他人个人主页（`/user/:account`，account 为小石榴号）。
class ProfileScreen extends ConsumerWidget {
  final String account;
  const ProfileScreen({super.key, required this.account});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('个人主页'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ProfileView(
          account: account,
          trailingAction: FollowButton(account: account),
        ),
      ),
    );
  }
}
