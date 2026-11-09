import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../data/models/post.dart';
import '../../data/models/search.dart';
import '../../data/models/user.dart';

final _hotProvider = FutureProvider.autoDispose<List<HotKeyword>>(
    (ref) => ref.watch(searchRepositoryProvider).hot(limit: 10));

/// 发现 / 搜索页：热搜 + 本地历史 + 结果 tabs（笔记 / 用户）。
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  late final TabController _tabController;
  String? _keyword;
  int _tab = 0;

  List<Post> _posts = [];
  List<UserProfile> _users = [];
  int _postsPage = 0;
  int _usersPage = 0;
  bool _postsHasMore = true;
  bool _usersHasMore = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (_tabController.index != _tab) {
          setState(() => _tab = _tabController.index);
        }
      });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _run(String keyword) async {
    final k = keyword.trim();
    if (k.isEmpty) return;
    _ctrl.text = k;
    _ctrl.selection =
        TextSelection.fromPosition(TextPosition(offset: k.length));
    ref.read(prefsProvider).addSearchHistory(k);
    setState(() {
      _keyword = k;
      _posts = [];
      _users = [];
      _postsPage = 0;
      _usersPage = 0;
      _postsHasMore = true;
      _usersHasMore = true;
      _loading = true;
    });
    await _loadFirst();
    setState(() => _loading = false);
  }

  Future<void> _loadFirst() async {
    final kw = _keyword!;
    try {
      final p = await ref
          .read(searchRepositoryProvider)
          .searchPosts(kw, type: 'all', page: 1);
      final u =
          await ref.read(searchRepositoryProvider).searchUsers(kw, page: 1);
      setState(() {
        _posts = p.posts;
        _postsPage = 1;
        _postsHasMore = p.pagination.hasNext;
        _users = u.items;
        _usersPage = 1;
        _usersHasMore = u.pagination.hasNext;
      });
    } catch (_) {
      // 保持空结果
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _keyword == null) return;
    setState(() => _loading = true);
    try {
      if (_tab == 0 && _postsHasMore) {
        final p = await ref
            .read(searchRepositoryProvider)
            .searchPosts(_keyword!, type: 'all', page: _postsPage + 1);
        setState(() {
          _posts = [..._posts, ...p.posts];
          _postsPage++;
          _postsHasMore = p.pagination.hasNext;
        });
      } else if (_tab == 1 && _usersHasMore) {
        final u = await ref
            .read(searchRepositoryProvider)
            .searchUsers(_keyword!, page: _usersPage + 1);
        setState(() {
          _users = [..._users, ...u.items];
          _usersPage++;
          _usersHasMore = u.pagination.hasNext;
        });
      }
    } catch (_) {
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: _searchBar(),
        automaticallyImplyLeading: false,
      ),
      body: _keyword == null ? _landing() : _results(),
    );
  }

  Widget _searchBar() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            textInputAction: TextInputAction.search,
            onSubmitted: _run,
            decoration: InputDecoration(
              isDense: true,
              hintText: '搜索笔记、用户',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _ctrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _ctrl.clear();
                        setState(() => _keyword = null);
                      },
                    )
                  : null,
            ),
          ),
        ),
        TextButton(
          onPressed: () => _run(_ctrl.text),
          child: const Text('搜索', style: TextStyle(color: AppColors.primary)),
        ),
      ],
    );
  }

  Widget _landing() {
    final history = ref.watch(prefsProvider).searchHistory;
    final hot = ref.watch(_hotProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (history.isNotEmpty) ...[
          Row(
            children: [
              const Text('搜索历史',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 20, color: AppColors.textTertiary),
                onPressed: () => ref.read(prefsProvider).clearSearchHistory(),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: history
                .map((h) => Chip(
                      label: Text(h,
                          style:
                              const TextStyle(color: AppColors.textSecondary)),
                      backgroundColor: AppColors.surface,
                      onDeleted: () =>
                          ref.read(prefsProvider).removeSearchHistory(h),
                    ))
                .toList(),
          ),
          const SizedBox(height: 24),
        ],
        const Text('热搜榜',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        hot.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
                child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(AppColors.primary))),
          ),
          error: (e, _) => const Padding(
            padding: EdgeInsets.all(24),
            child:
                Text('热搜加载失败', style: TextStyle(color: AppColors.textTertiary)),
          ),
          data: (list) => Column(
            children: List.generate(
              list.length,
              (i) => ListTile(
                dense: true,
                onTap: () => _run(list[i].keyword),
                leading: Text(
                  '${i + 1}',
                  style: TextStyle(
                    color: i < 3 ? AppColors.primary : AppColors.textTertiary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                title: Text(list[i].keyword,
                    style: const TextStyle(color: AppColors.textPrimary)),
                trailing: Text('${list[i].count}',
                    style: const TextStyle(
                        color: AppColors.textTertiary, fontSize: 12)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _results() {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          isScrollable: false,
          indicatorWeight: 2.5,
          tabs: const [Tab(text: '笔记'), Tab(text: '用户')],
        ),
        Expanded(
          child: _loading &&
                  ((_tab == 0 && _posts.isEmpty) ||
                      (_tab == 1 && _users.isEmpty))
              ? const Center(
                  child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(AppColors.primary)))
              : (_tab == 0
                  ? (_posts.isEmpty ? _empty() : _postGrid())
                  : (_users.isEmpty ? _empty() : _userList())),
        ),
      ],
    );
  }

  Widget _empty() => const Center(
        child:
            Text('没有找到相关内容', style: TextStyle(color: AppColors.textTertiary)),
      );

  Widget _postGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _posts.length + (_postsHasMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (i >= _posts.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
          return const Center(
              child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(AppColors.primary)));
        }
        final p = _posts[i];
        return _PostGridTile(post: p);
      },
    );
  }

  Widget _userList() {
    return ListView.builder(
      itemCount: _users.length + (_usersHasMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (i >= _users.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
                child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(AppColors.primary))),
          );
        }
        final u = _users[i];
        return ListTile(
          onTap: () => context.push('/user/${u.account}'),
          leading: ClipOval(
            child: CachedNetworkImage(
              imageUrl: u.avatar,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => const ColoredBox(
                  color: AppColors.surface, child: Icon(Icons.person)),
            ),
          ),
          title: Text(u.nickname,
              style: const TextStyle(color: AppColors.textPrimary)),
          subtitle: Text(u.account,
              style: const TextStyle(color: AppColors.textTertiary)),
        );
      },
    );
  }
}

class _PostGridTile extends StatelessWidget {
  final Post post;
  const _PostGridTile({required this.post});

  @override
  Widget build(BuildContext context) {
    final cover = post.thumbnail;
    return GestureDetector(
      onTap: () => context
          .push(post.type == 2 ? '/player/${post.id}' : '/post/${post.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: cover != null
                  ? CachedNetworkImage(
                      imageUrl: cover,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorWidget: (_, __, ___) =>
                          const Icon(Icons.broken_image_outlined),
                    )
                  : const Center(
                      child: Icon(Icons.image_outlined,
                          color: AppColors.textTertiary)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Text(
                post.title.isEmpty ? post.content : post.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
