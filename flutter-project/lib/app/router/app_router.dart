import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../features/auth/edit_profile_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/auth/splash_screen.dart';
import '../../features/detail/post_detail_screen.dart';
import '../../features/feed/feed_screen.dart';
import '../../features/me/me_screen.dart';
import '../../features/notify/notifications_screen.dart';
import '../../features/player/player_screen.dart';
import '../../features/profile/follow_list_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/publish/publish_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/shop/orders_screen.dart';
import '../../features/shop/shop_screen.dart';
import '../../features/shell/home_shell.dart';
import '../../features/stats/stats_screen.dart';
import '../../features/stats/drafts_screen.dart';
import '../../features/vip/vip_screen.dart';
import '../../features/wallet/wallet_screen.dart';

/// 会话状态驱动的路由。登录/注册成功后依赖 redirect 自动进入 Feed，页面不手动跳转。
final routerProvider = Provider<GoRouter>((ref) {
  // authController 状态变化时自增，作为 go_router 的刷新信号（redirect 会重新执行）。
  final refresh = ValueNotifier<int>(0);
  ref.listen<AuthState>(authControllerProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final status = ref.read(authControllerProvider).status;
      final loc = state.matchedLocation;
      final onSplash = loc == '/splash';
      final onAuthPages = loc == '/login' || loc == '/register';

      if (status == AuthStatus.unknown) {
        return onSplash ? null : '/splash';
      }
      if (status == AuthStatus.unauthenticated) {
        // 未登录：启动页直接进首页；需要登录的页面统一拦截到登录页。
        if (onSplash) return '/feed';
        if (_requiresAuth(loc)) return '/login';
        return null;
      }
      // authenticated
      if (onSplash || onAuthPages) return '/feed';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/feed',
              pageBuilder: (_, state) => NoTransitionPage<void>(
                  key: state.pageKey, child: const FeedScreen()),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/search',
              pageBuilder: (_, state) => NoTransitionPage<void>(
                  key: state.pageKey, child: const SearchScreen()),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/notify',
              pageBuilder: (_, state) => NoTransitionPage<void>(
                  key: state.pageKey,
                  child: NotificationsScreen(
                      initialTab: state.uri.queryParameters['tab'])),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/me',
              pageBuilder: (_, state) => NoTransitionPage<void>(
                  key: state.pageKey, child: const MeScreen()),
            ),
          ]),
        ],
      ),
      // ---- 独立 push 路由（隐藏底栏）----
      GoRoute(path: '/publish', builder: (_, __) => const PublishScreen()),
      GoRoute(
        path: '/post/:id',
        builder: (_, state) =>
            PostDetailScreen(postId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/player/:id',
        builder: (_, state) =>
            PlayerScreen(postId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/user/:account',
        builder: (_, state) =>
            ProfileScreen(account: state.pathParameters['account']!),
      ),
      GoRoute(
        path: '/user/:account/follows/:type',
        builder: (_, state) => FollowListScreen(
          account: state.pathParameters['account']!,
          type: state.pathParameters['type']!,
        ),
      ),
      GoRoute(
          path: '/edit-profile', builder: (_, __) => const EditProfileScreen()),
      GoRoute(path: '/wallet', builder: (_, __) => const WalletScreen()),
      GoRoute(path: '/vip', builder: (_, __) => const VipScreen()),
      GoRoute(path: '/shop', builder: (_, __) => const ShopScreen()),
      GoRoute(path: '/orders', builder: (_, __) => const OrdersScreen()),
      GoRoute(path: '/stats', builder: (_, __) => const StatsScreen()),
      GoRoute(path: '/drafts', builder: (_, __) => const DraftsScreen()),
    ],
  );
});

/// 需要登录才能访问的路由（按前缀匹配）；其余页面允许游客浏览。
const _authRequiredPrefixes = <String>[
  '/notify',
  '/publish',
  '/stats',
  '/drafts',
  '/wallet',
  '/orders',
  '/vip',
  '/edit-profile',
];

bool _requiresAuth(String location) =>
    _authRequiredPrefixes.any((p) => location == p || location.startsWith('$p/'));
