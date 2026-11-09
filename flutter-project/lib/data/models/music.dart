import '../../core/config/app_config.dart';
import '_json.dart';

/// 背景音乐（musics）。
class Music {
  final int id;
  final String title;
  final String? author;
  final String audioUrl;
  final String? coverUrl;
  final int duration;
  final int useCount;

  const Music({
    required this.id,
    required this.title,
    this.author,
    required this.audioUrl,
    this.coverUrl,
    this.duration = 0,
    this.useCount = 0,
  });

  factory Music.fromJson(Map<String, dynamic> json) {
    return Music(
      id: asInt(json['id']),
      title: asString(json['title']),
      author: asStringOrNull(json['author']),
      audioUrl: AppConfig.resolveMedia(asStringOrNull(json['audio_url'])),
      coverUrl: json['cover_url'] == null
          ? null
          : AppConfig.resolveMedia(asStringOrNull(json['cover_url'])),
      duration: asInt(json['duration']),
      useCount: asInt(json['use_count']),
    );
  }
}
