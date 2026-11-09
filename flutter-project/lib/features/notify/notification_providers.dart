import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/models/notification.dart';
import '../../data/repositories/notification_repository.dart';

class NotifyState {
  final List<AppNotification> items;
  final int page;
  final bool hasMore;
  final bool loading;
  const NotifyState({
    this.items = const [],
    this.page = 0,
    this.hasMore = true,
    this.loading = false,
  });

  NotifyState copyWith({
    List<AppNotification>? items,
    int? page,
    bool? hasMore,
    bool? loading,
  }) =>
      NotifyState(
        items: items ?? this.items,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        loading: loading ?? this.loading,
      );
}

class NotifyController extends StateNotifier<NotifyState> {
  final NotificationRepository repo;
  final String kind;

  NotifyController(this.repo, this.kind) : super(const NotifyState());

  Future<void> load() async {
    if (state.loading || state.page > 0) return;
    state = state.copyWith(loading: true);
    try {
      final p = await repo.group(kind, page: 1);
      state = state.copyWith(
        items: p.items,
        page: 1,
        hasMore: p.pagination.hasNext,
        loading: false,
      );
    } catch (_) {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> loadMore() async {
    if (state.loading || !state.hasMore || state.page == 0) return;
    state = state.copyWith(loading: true);
    try {
      final p = await repo.group(kind, page: state.page + 1);
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

  /// 乐观标记已读（本地置灰，失败忽略——已读状态非关键）。
  Future<void> markRead(int id) async {
    final items = state.items.map((n) => n.id == id ? _asRead(n) : n).toList();
    state = state.copyWith(items: items);
    try {
      await repo.markRead('$id');
    } catch (_) {}
  }

  static AppNotification _asRead(AppNotification n) {
    return AppNotification(
      id: n.id,
      type: n.type,
      title: n.title,
      targetId: n.targetId,
      commentId: n.commentId,
      isRead: true,
      createdAt: n.createdAt,
      fromUserId: n.fromUserId,
      fromAccount: n.fromAccount,
      fromNickname: n.fromNickname,
      fromAvatar: n.fromAvatar,
      fromVerified: n.fromVerified,
      postTitle: n.postTitle,
      postType: n.postType,
      postImage: n.postImage,
      commentContent: n.commentContent,
      parentCommentContent: n.parentCommentContent,
    );
  }
}

final notifyGroupProvider = StateNotifierProvider.autoDispose
    .family<NotifyController, NotifyState, String>((ref, kind) {
  final ctrl =
      NotifyController(ref.watch(notificationRepositoryProvider), kind);
  ctrl.load();
  return ctrl;
});

final unreadByTypeProvider = FutureProvider.autoDispose<UnreadCounts>(
    (ref) => ref.watch(notificationRepositoryProvider).unreadByType());
