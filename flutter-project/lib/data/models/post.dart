import '../../core/config/app_config.dart';
import '_json.dart';
import 'music.dart';
import 'poll.dart';

/// 标签。
class Tag {
  final int id;
  final String name;
  const Tag({required this.id, required this.name});

  factory Tag.fromJson(Map<String, dynamic> json) =>
      Tag(id: asInt(json['id']), name: asString(json['name']));
}

/// 剧集分集（一部剧集帖下的一条可播放单元）。
class Episode {
  final int id;
  final String title;
  final String videoUrl;
  final String? coverUrl;
  final int sort;
  const Episode({
    required this.id,
    required this.title,
    required this.videoUrl,
    this.coverUrl,
    this.sort = 0,
  });

  factory Episode.fromJson(Map<String, dynamic> json) => Episode(
        id: asInt(json['id']),
        title: asString(json['title']),
        videoUrl: AppConfig.resolveMedia(asStringOrNull(json['video_url'])),
        coverUrl: AppConfig.resolveMedia(asStringOrNull(json['cover_url'])),
        sort: asInt(json['sort']),
      );
}

/// 笔记（图文/视频）。适配列表项与详情两种返回形态。
class Post {
  final int id;
  final int authorId; // 作者数字主键
  final String authorAccount; // 作者小石榴号（跳转主页/关注用）
  final String authorName;
  final String authorAvatar;
  final String? authorLocation;
  final bool authorVerified;

  final String title;
  final String content;
  final int categoryId;
  final String? category;
  final int type; // 1-图文 2-视频
  final int status; // 0-发布 1-草稿 2-待审核 3-未过审
  final int musicId;

  final int viewCount;
  final int likeCount;
  final int collectCount;
  final int commentCount;
  final String? createdAt;

  final List<String> images;
  final String? videoUrl;
  final String? coverUrl;

  final List<Tag> tags;
  final bool liked;
  final bool collected;
  final Poll? poll;
  final Music? music;
  final List<Episode> episodes;

  const Post({
    required this.id,
    required this.authorId,
    required this.authorAccount,
    required this.authorName,
    required this.authorAvatar,
    this.authorLocation,
    this.authorVerified = false,
    required this.title,
    required this.content,
    this.categoryId = 0,
    this.category,
    required this.type,
    required this.status,
    this.musicId = 0,
    this.viewCount = 0,
    this.likeCount = 0,
    this.collectCount = 0,
    this.commentCount = 0,
    this.createdAt,
    this.images = const [],
    this.videoUrl,
    this.coverUrl,
    this.tags = const [],
    this.liked = false,
    this.collected = false,
    this.poll,
    this.music,
    this.episodes = const [],
  });

  /// 网格/封面展示的第一张可用图（视频取封面）。
  String? get thumbnail => images.isNotEmpty ? images.first : coverUrl;

  factory Post.fromJson(Map<String, dynamic> json) {
    final images = asStringList(json['images'])
        .map((u) => AppConfig.resolveMedia(u.isEmpty ? null : u))
        .toList();

    // 详情视频形态：videos: [{video_url, cover_url}]
    String? videoUrl = json['video_url'] == null
        ? null
        : AppConfig.resolveMedia(asStringOrNull(json['video_url']));
    String? coverUrl = json['cover_url'] == null
        ? null
        : AppConfig.resolveMedia(asStringOrNull(json['cover_url']));
    if (videoUrl == null) {
      final videos = asMapList(json['videos']);
      if (videos.isNotEmpty) {
        videoUrl =
            AppConfig.resolveMedia(asStringOrNull(videos.first['video_url']));
        coverUrl ??=
            AppConfig.resolveMedia(asStringOrNull(videos.first['cover_url']));
      }
    }

    final pollMap = asMap(json['poll']);
    final musicMap = asMap(json['music']);

    return Post(
      id: asInt(json['id']),
      authorId: asInt(json['author_auto_id'] ?? json['user_id']),
      authorAccount: asString(json['author_account']),
      authorName: asString(json['nickname']),
      authorAvatar: AppConfig.resolveMedia(asStringOrNull(json['user_avatar'])),
      authorLocation: asStringOrNull(json['location']),
      authorVerified: asBool(json['verified']),
      title: asString(json['title']),
      content: asString(json['content']),
      categoryId: asInt(json['category_id']),
      category: asStringOrNull(json['category']),
      type: asInt(json['type'], 1),
      status: asInt(json['status'], 2),
      musicId: asInt(json['music_id']),
      viewCount: asInt(json['view_count']),
      likeCount: asInt(json['like_count']),
      collectCount: asInt(json['collect_count']),
      commentCount: asInt(json['comment_count']),
      createdAt: asStringOrNull(json['created_at']),
      images: images,
      videoUrl: videoUrl,
      coverUrl: coverUrl,
      tags: asMapList(json['tags']).map(Tag.fromJson).toList(),
      liked: asBool(json['liked']),
      collected: asBool(json['collected']),
      poll: pollMap == null ? null : Poll.fromJson(pollMap),
      music: musicMap == null ? null : Music.fromJson(musicMap),
      episodes: asMapList(json['episodes']).map(Episode.fromJson).toList(),
    );
  }
}
