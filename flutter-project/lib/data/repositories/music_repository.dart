import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/network/endpoints.dart';
import '../models/_json.dart';
import '../models/music.dart';
import '../models/page.dart';
import '_paged.dart';

/// 背景音乐：列表（可搜索）/ 热门 / 新增。
class MusicRepository {
  final ApiClient client;

  MusicRepository(this.client);

  Future<Paged<Music>> list({
    String? keyword,
    int page = 1,
    int? limit,
  }) async {
    final data = await client.get(Endpoints.musics, queryParameters: {
      'page': page,
      'limit': limit ?? AppConfig.defaultPageSize,
      if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
    });
    return parsePaged(data, 'musics', Music.fromJson);
  }

  Future<List<Music>> hot({int limit = 10}) async {
    final data = await client
        .get(Endpoints.musicsHot, queryParameters: {'limit': limit});
    return parseList(data, Music.fromJson);
  }

  Future<int> create({
    required String title,
    required String audioUrl,
    String? author,
    String? coverUrl,
    int duration = 0,
  }) async {
    final data = await client.post(Endpoints.musics, data: {
      'title': title,
      'audio_url': audioUrl,
      if (author != null) 'author': author,
      if (coverUrl != null) 'cover_url': coverUrl,
      'duration': duration,
    });
    return asInt(asDataMap(data)['id']);
  }
}
