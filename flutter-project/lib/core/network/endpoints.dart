/// 后端 API 端点常量（路径前缀见 express-project/app.js 的挂载）。
/// 均为相对 [AppConfig.apiBase] 的路径，不含域名。
class Endpoints {
  Endpoints._();

  // ---- Auth ----
  static const String captcha = '/api/auth/captcha';
  static const String checkUserId = '/api/auth/check-user-id';
  static const String emailConfig = '/api/auth/email-config';
  static const String register = '/api/auth/register';
  static const String login = '/api/auth/login';
  static const String refresh = '/api/auth/refresh';
  static const String logout = '/api/auth/logout';
  static const String me = '/api/auth/me';
  static const String bindEmail = '/api/auth/bind-email';
  static const String sendEmailCode = '/api/auth/send-email-code';
  static const String sendResetCode = '/api/auth/send-reset-code';
  static const String verifyResetCode = '/api/auth/verify-reset-code';
  static const String resetPassword = '/api/auth/reset-password';

  static String passwordUpdate(String userId) => '/api/users/$userId/password';

  // ---- Users ----
  static String user(String id) => '/api/users/$id';
  static const String userSearch = '/api/users/search';
  static String userPosts(String id) => '/api/users/$id/posts';
  static String userCollections(String id) => '/api/users/$id/collections';
  static String userLikes(String id) => '/api/users/$id/likes';
  static String follow(String id) => '/api/users/$id/follow';
  static String followStatus(String id) => '/api/users/$id/follow-status';
  static String following(String id) => '/api/users/$id/following';
  static String followers(String id) => '/api/users/$id/followers';
  static String userStats(String id) => '/api/users/$id/stats';
  static String updateProfile(String id) => '/api/users/$id';

  // ---- Posts ----
  static const String posts = '/api/posts';
  static String post(String id) => '/api/posts/$id';
  static String postComments(String id) => '/api/posts/$id/comments';
  static String postCollect(String id) => '/api/posts/$id/collect';
  static String postPoll(String id) => '/api/posts/$id/poll';

  // ---- Comments ----
  static const String comments = '/api/comments';
  static String commentReplies(String id) => '/api/comments/$id/replies';
  static String comment(String id) => '/api/comments/$id';

  // ---- Likes ----
  static const String likes = '/api/likes';

  // ---- Danmaku ----
  static String danmaku(String postId) => '/api/danmaku/$postId';

  // ---- Polls ----
  static String poll(String pollId) => '/api/polls/$pollId';
  static String pollVote(String pollId) => '/api/polls/$pollId/vote';

  // ---- Musics ----
  static const String musics = '/api/musics';
  static const String musicsHot = '/api/musics/hot';
  static String music(String id) => '/api/musics/$id';

  // ---- Search ----
  static const String search = '/api/search';
  static const String searchHot = '/api/search/hot';

  // ---- Tags ----
  static const String tags = '/api/tags';
  static const String tagsHot = '/api/tags/hot';

  // ---- Categories ----
  static const String categories = '/api/categories';

  // ---- Notifications ----
  static const String notifications = '/api/notifications';
  static const String unreadCount = '/api/notifications/unread-count';
  static const String unreadCountByType =
      '/api/notifications/unread-count-by-type';
  static const String readAllNotifications = '/api/notifications/read-all';
  static String readNotification(String id) => '/api/notifications/$id/read';
  static String notification(String id) => '/api/notifications/$id';
  static String notificationsByType(String type) => '/api/notifications/$type';

  // ---- Wallet ----
  static const String wallet = '/api/wallet';
  static const String walletTransactions = '/api/wallet/transactions';
  static const String walletWithdraw = '/api/wallet/withdraw';

  // ---- VIP ----
  static const String vipPlans = '/api/vip/plans';
  static const String vipStatus = '/api/vip/status';
  static const String vipPurchase = '/api/vip/purchase';

  // ---- Shop ----
  static const String shopProducts = '/api/shop/products';
  static const String shopOrders = '/api/shop/orders';

  // ---- Ads ----
  static const String ads = '/api/ads';

  // ---- Upload ----
  static const String uploadSingle = '/api/upload/single';
  static const String uploadMultiple = '/api/upload/multiple';
  static const String uploadVideo = '/api/upload/video';
}
