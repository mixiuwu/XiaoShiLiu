import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/prefs.dart';
import '../../core/storage/token_store.dart';
import '../../data/models/user.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/ad_repository.dart';
import '../../data/repositories/comment_repository.dart';
import '../../data/repositories/danmaku_repository.dart';
import '../../data/repositories/like_repository.dart';
import '../../data/repositories/music_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/poll_repository.dart';
import '../../data/repositories/post_repository.dart';
import '../../data/repositories/search_repository.dart';
import '../../data/repositories/shop_repository.dart';
import '../../data/repositories/upload_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/vip_repository.dart';
import '../../data/repositories/wallet_repository.dart';

/// 本地偏好（在 main 中通过 overrideWithValue 注入已实例化的 [Prefs]）。
final prefsProvider = Provider<Prefs>((ref) {
  throw UnimplementedError('prefsProvider 必须在 ProviderScope 中 override');
});

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

/// 会话状态。
enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final UserProfile? user;
  final bool busy;
  final String? error;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.busy = false,
    this.error,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserProfile? user,
    bool? busy,
    String? error,
    bool clearError = false,
    bool clearUser = false,
  }) =>
      AuthState(
        status: status ?? this.status,
        user: clearUser ? null : (user ?? this.user),
        busy: busy ?? this.busy,
        error: clearError ? null : (error ?? this.error),
      );

  bool get isLoggedIn => status == AuthStatus.authenticated && user != null;
}

/// 网络客户端：会话过期回调清理本地令牌并通知状态机。
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    tokenStore: ref.read(tokenStoreProvider),
    onSessionExpired: () async {
      // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
      ref.read(authControllerProvider.notifier).forceLogout();
    },
  );
});

// ---- Repositories ----
final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(
    ref.watch(apiClientProvider), ref.watch(tokenStoreProvider)));
final postRepositoryProvider = Provider<PostRepository>(
    (ref) => PostRepository(ref.watch(apiClientProvider)));
final commentRepositoryProvider = Provider<CommentRepository>(
    (ref) => CommentRepository(ref.watch(apiClientProvider)));
final likeRepositoryProvider = Provider<LikeRepository>(
    (ref) => LikeRepository(ref.watch(apiClientProvider)));
final userRepositoryProvider = Provider<UserRepository>(
    (ref) => UserRepository(ref.watch(apiClientProvider)));
final searchRepositoryProvider = Provider<SearchRepository>(
    (ref) => SearchRepository(ref.watch(apiClientProvider)));
final notificationRepositoryProvider = Provider<NotificationRepository>(
    (ref) => NotificationRepository(ref.watch(apiClientProvider)));
final pollRepositoryProvider = Provider<PollRepository>(
    (ref) => PollRepository(ref.watch(apiClientProvider)));
final danmakuRepositoryProvider = Provider<DanmakuRepository>(
    (ref) => DanmakuRepository(ref.watch(apiClientProvider)));
final musicRepositoryProvider = Provider<MusicRepository>(
    (ref) => MusicRepository(ref.watch(apiClientProvider)));
final walletRepositoryProvider = Provider<WalletRepository>(
    (ref) => WalletRepository(ref.watch(apiClientProvider)));
final vipRepositoryProvider = Provider<VipRepository>(
    (ref) => VipRepository(ref.watch(apiClientProvider)));
final shopRepositoryProvider = Provider<ShopRepository>(
    (ref) => ShopRepository(ref.watch(apiClientProvider)));
final uploadRepositoryProvider = Provider<UploadRepository>(
    (ref) => UploadRepository(ref.watch(apiClientProvider)));
final adRepositoryProvider =
    Provider<AdRepository>((ref) => AdRepository(ref.watch(apiClientProvider)));

/// 全局登录态控制器。本身即 [Listenable]，供 go_router refreshListenable 使用。
final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref);
});

class AuthController extends StateNotifier<AuthState> {
  final Ref _ref;

  AuthController(this._ref) : super(const AuthState());

  /// 启动时判断本地是否有有效会话。
  Future<void> bootstrap() async {
    final tokenStore = _ref.read(tokenStoreProvider);
    // 安全读取本地令牌：模拟器上 flutter_secure_storage 首次读取可能抛异常，
    // 此时按未登录处理，避免状态卡在 unknown 使 Splash 无法退出。
    bool hasToken;
    try {
      hasToken = await tokenStore.hasSession;
    } catch (_) {
      hasToken = false;
    }
    if (!hasToken) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }
    try {
      final user = await _ref.read(authRepositoryProvider).fetchMe();
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (_) {
      try {
        await tokenStore.clear();
      } catch (_) {}
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> login(String userId, String password) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final user =
          await _ref.read(authRepositoryProvider).login(userId, password);
      state =
          AuthState(status: AuthStatus.authenticated, user: user, busy: false);
      return true;
    } catch (e) {
      state = state.copyWith(busy: false, error: _msg(e));
      return false;
    }
  }

  Future<bool> register({
    required String userId,
    required String nickname,
    required String password,
    String? email,
    String? emailCode,
  }) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final user = await _ref.read(authRepositoryProvider).register(
            userId: userId,
            nickname: nickname,
            password: password,
            email: email,
            emailCode: emailCode,
          );
      state =
          AuthState(status: AuthStatus.authenticated, user: user, busy: false);
      return true;
    } catch (e) {
      state = state.copyWith(busy: false, error: _msg(e));
      return false;
    }
  }

  /// 更新内存中的用户资料（编辑资料后）。
  void setUser(UserProfile user) {
    state = state.copyWith(user: user, status: AuthStatus.authenticated);
  }

  Future<void> logout() async {
    try {
      await _ref.read(authRepositoryProvider).logout();
    } catch (_) {}
    forceLogout();
  }

  /// 令牌失效 / 刷新失败：清理本地令牌并复位内存态。
  void forceLogout() {
    _ref.read(tokenStoreProvider).clear();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  static String _msg(Object e) {
    if (e is ApiException) return e.message;
    return '操作失败，请稍后重试';
  }
}
