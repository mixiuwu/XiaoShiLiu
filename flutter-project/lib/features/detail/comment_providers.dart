import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/models/comment.dart';
import '../../data/repositories/comment_repository.dart';
import '../../data/repositories/like_repository.dart';

class CommentsState {
  final List<Comment> items;

  /// 顶级评论 id -> 其子回复列表（已加载）；未加载则 key 不存在。
  final Map<int, List<Comment>> replies;

  /// 正在加载回复的顶级评论 id 集合。
  final Set<int> loadingRepliesFor;

  /// 评论总数（含子回复），发帖/回复时实时 +1。
  final int total;
  final int page;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final String? error;

  const CommentsState({
    this.items = const [],
    this.replies = const {},
    this.loadingRepliesFor = const {},
    this.total = 0,
    this.page = 0,
    this.loading = false,
    this.loadingMore = false,
    this.hasMore = true,
    this.error,
  });

  CommentsState copyWith({
    List<Comment>? items,
    Map<int, List<Comment>>? replies,
    Set<int>? loadingRepliesFor,
    int? total,
    int? page,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    String? error,
    bool clearError = false,
  }) =>
      CommentsState(
        items: items ?? this.items,
        replies: replies ?? this.replies,
        loadingRepliesFor: loadingRepliesFor ?? this.loadingRepliesFor,
        total: total ?? this.total,
        page: page ?? this.page,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        hasMore: hasMore ?? this.hasMore,
        error: clearError ? null : (error ?? this.error),
      );
}

class CommentController extends StateNotifier<CommentsState> {
  final CommentRepository _repo;
  final LikeRepository _likeRepo;
  final int postId;

  CommentController(this.postId, this._repo, this._likeRepo)
      : super(const CommentsState());

  /// 首次加载是否已发起：用于「详情页提前并发触发」与「CommentSection 挂载再调」去重，
  /// 避免同一帖子重复拉取列表。
  bool _started = false;

  Future<void> load({int? initialTotal}) async {
    // 已发起过：不再重复请求，仅在拿到帖子后回填评论总数（作为实时 +1 起点）。
    if (_started) {
      if (initialTotal != null) state = state.copyWith(total: initialTotal);
      return;
    }
    _started = true;
    state = state.copyWith(
        loading: true, clearError: true, total: initialTotal ?? state.total);
    try {
      final res = await _repo.listByPost(postId, page: 1);
      if (!mounted) return; // 弹层关闭后 provider 可能已 dispose
      state = state.copyWith(
        items: res.items,
        page: 1,
        loading: false,
        hasMore: res.hasNext,
        // 未拿到帖子时（提前并发加载）用后端分页总数兜底，评论计数即时正确。
        total: initialTotal ?? res.pagination.total,
      );
    } catch (_) {
      _started = false; // 允许失败后重试
      if (!mounted) return;
      state = state.copyWith(loading: false, error: '评论加载失败');
    }
  }

  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore) return;
    state = state.copyWith(loadingMore: true);
    try {
      final next = state.page + 1;
      final res = await _repo.listByPost(postId, page: next);
      if (!mounted) return;
      state = state.copyWith(
        items: [...state.items, ...res.items],
        page: next,
        loadingMore: false,
        hasMore: res.hasNext,
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(loadingMore: false);
    }
  }

  /// 发表评论 / 回复；顶级评论置顶插入，回复追加到父评论的子列表。
  Future<bool> send(String content, {int? parentId}) async {
    try {
      final c = await _repo.create(
          postId: postId, content: content, parentId: parentId);
      if (!mounted) return true; // 已发送成功，仅跳过本地状态更新
      if (parentId == null) {
        state =
            state.copyWith(items: [c, ...state.items], total: state.total + 1);
      } else {
        final cur = List<Comment>.from(state.replies[parentId] ?? const []);
        cur.add(c);
        state = state.copyWith(
            replies: {...state.replies, parentId: cur}, total: state.total + 1);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 按需加载某顶级评论的子回复。
  Future<void> loadReplies(int rootId) async {
    if (state.replies.containsKey(rootId) ||
        state.loadingRepliesFor.contains(rootId)) {
      return;
    }
    state =
        state.copyWith(loadingRepliesFor: {...state.loadingRepliesFor, rootId});
    try {
      final res = await _repo.replies(rootId);
      if (!mounted) return;
      state = state.copyWith(
        replies: {...state.replies, rootId: res.items},
        loadingRepliesFor: state.loadingRepliesFor.difference({rootId}),
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        loadingRepliesFor: state.loadingRepliesFor.difference({rootId}),
      );
    }
  }

  /// 评论点赞（乐观），顶级评论与子回复均支持。
  Future<void> like(Comment comment) async {
    final rootId = comment.parentId;
    if (rootId == null) {
      final idx = state.items.indexWhere((e) => e.id == comment.id);
      if (idx < 0) return;
      final prev = state.items[idx];
      final optimistic = _flip(prev);
      _replaceTop(idx, optimistic);
      try {
        final res = await _likeRepo.toggleComment(comment.id);
        _replaceTop(
            idx,
            optimistic.copyWithLike(
                liked: res, likeCount: prev.likeCount + (res ? 1 : -1)));
      } catch (_) {
        _replaceTop(idx, prev);
      }
    } else {
      final base = state.replies[rootId];
      if (base == null) return;
      final idx = base.indexWhere((e) => e.id == comment.id);
      if (idx < 0) return;
      final prev = base[idx];
      final optimistic = _flip(prev);
      _replaceReply(rootId, idx, optimistic);
      try {
        final res = await _likeRepo.toggleComment(comment.id);
        _replaceReply(
            rootId,
            idx,
            optimistic.copyWithLike(
                liked: res, likeCount: prev.likeCount + (res ? 1 : -1)));
      } catch (_) {
        _replaceReply(rootId, idx, prev);
      }
    }
  }

  Comment _flip(Comment c) => c.copyWithLike(
      liked: !c.liked, likeCount: c.likeCount + (c.liked ? -1 : 1));

  void _replaceTop(int idx, Comment c) {
    final list = List<Comment>.from(state.items);
    if (idx < 0 || idx >= list.length) return;
    list[idx] = c;
    state = state.copyWith(items: list);
  }

  void _replaceReply(int rootId, int idx, Comment c) {
    final base = List<Comment>.from(state.replies[rootId] ?? const []);
    if (idx < 0 || idx >= base.length) return;
    base[idx] = c;
    state = state.copyWith(replies: {...state.replies, rootId: base});
  }
}

final commentsControllerProvider = StateNotifierProvider.autoDispose
    .family<CommentController, CommentsState, int>((ref, postId) {
  return CommentController(
    postId,
    ref.watch(commentRepositoryProvider),
    ref.watch(likeRepositoryProvider),
  );
});
