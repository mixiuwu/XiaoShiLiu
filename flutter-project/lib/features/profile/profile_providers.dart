import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/models/follow.dart';
import '../../data/models/post.dart';
import '../../data/models/stats.dart';
import '../../data/models/user.dart';

final userDetailProvider = FutureProvider.autoDispose
    .family<UserProfile, String>(
        (ref, account) => ref.watch(userRepositoryProvider).detail(account));

final userStatsProvider = FutureProvider.autoDispose.family<UserStats, String>(
    (ref, account) => ref.watch(userRepositoryProvider).stats(account));

final followStatusProvider = FutureProvider.autoDispose
    .family<FollowStatus, String>((ref, account) =>
        ref.watch(userRepositoryProvider).followStatus(account));

final userWorksProvider = FutureProvider.autoDispose.family<List<Post>, String>(
    (ref, account) => ref
        .watch(userRepositoryProvider)
        .posts(account, status: '0')
        .then((p) => p.items));

final userLikesProvider = FutureProvider.autoDispose.family<List<Post>, String>(
    (ref, account) =>
        ref.watch(userRepositoryProvider).likes(account).then((p) => p.items));

final userCollectionsProvider = FutureProvider.autoDispose
    .family<List<Post>, String>((ref, account) => ref
        .watch(userRepositoryProvider)
        .collections(account)
        .then((p) => p.items));

final followingUsersProvider = FutureProvider.autoDispose
    .family<List<UserProfile>, String>((ref, account) => ref
        .watch(userRepositoryProvider)
        .following(account)
        .then((p) => p.items));

final followersUsersProvider = FutureProvider.autoDispose
    .family<List<UserProfile>, String>((ref, account) => ref
        .watch(userRepositoryProvider)
        .followers(account)
        .then((p) => p.items));
