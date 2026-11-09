import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/network/endpoints.dart';
import '../models/_json.dart';
import '../models/notification.dart';
import '../models/page.dart';
import '_paged.dart';

/// 消息分组。
class NotifyGroup {
  static const String comments = 'comments';
  static const String likes = 'likes';
  static const String collections = 'collections';
  static const String follows = 'follows';
}

/// 消息中心：分组列表 / 未读数 / 已读。
class NotificationRepository {
  final ApiClient client;

  NotificationRepository(this.client);

  /// 按分组获取通知（comments/likes/collections/follows）。
  Future<Paged<AppNotification>> group(
    String kind, {
    int page = 1,
    int? limit,
  }) async {
    final data =
        await client.get(Endpoints.notificationsByType(kind), queryParameters: {
      'page': page,
      'limit': limit ?? AppConfig.defaultPageSize,
    });
    return parsePaged(data, 'notifications', AppNotification.fromJson);
  }

  Future<int> unreadCount() async {
    final data = await client.get(Endpoints.unreadCount);
    return asInt(asDataMap(data)['count']);
  }

  Future<UnreadCounts> unreadByType() async {
    final data = await client.get(Endpoints.unreadCountByType);
    return UnreadCounts.fromJson(asDataMap(data));
  }

  Future<void> markRead(String id) =>
      client.put(Endpoints.readNotification(id));

  Future<void> markAllRead() => client.put(Endpoints.readAllNotifications);

  Future<void> delete(String id) => client.delete(Endpoints.notification(id));
}
