import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/models/post.dart';
import '../../data/repositories/post_repository.dart';

/// Feed 列表状态。
class FeedState {
  final List<Post> posts;
  final int page;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final String? error;

  const FeedState({
    this.posts = const [],
    this.page = 0,
    this.loading = false,
    this.loadingMore = false,
    this.hasMore = true,
    this.error,
  });

  FeedState copyWith({
    List<Post>? posts,
    int? page,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    String? error,
    bool clearError = false,
  }) =>
      FeedState(
        posts: posts ?? this.posts,
        page: page ?? this.page,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        hasMore: hasMore ?? this.hasMore,
        error: clearError ? null : (error ?? this.error),
      );
}

/// 推荐竖滑视频流控制器：分页拉取 type=2、category=recommend。
class FeedController extends StateNotifier<FeedState> {
  final PostRepository _repo;
  FeedController(this._repo) : super(const FeedState());

  Future<void> loadFirst() async {
    if (state.loading) return;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final res = await _repo.list(page: 1, type: 2, category: 'recommend');
      state = state.copyWith(
        posts: res.items,
        page: 1,
        loading: false,
        hasMore: res.hasNext,
      );
    } catch (_) {
      state = state.copyWith(loading: false, error: '加载失败，请稍后重试');
    }
  }

  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore || state.loading) return;
    state = state.copyWith(loadingMore: true);
    try {
      final next = state.page + 1;
      final res = await _repo.list(page: next, type: 2, category: 'recommend');
      state = state.copyWith(
        posts: [...state.posts, ...res.items],
        page: next,
        loadingMore: false,
        hasMore: res.hasNext,
      );
    } catch (_) {
      state = state.copyWith(loadingMore: false);
    }
  }
}

final feedControllerProvider =
    StateNotifierProvider.autoDispose<FeedController, FeedState>((ref) {
  return FeedController(ref.watch(postRepositoryProvider));
});
