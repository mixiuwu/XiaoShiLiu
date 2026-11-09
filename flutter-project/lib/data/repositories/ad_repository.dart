import '../../core/network/api_client.dart';
import '../../core/network/endpoints.dart';
import '../models/ad.dart';
import '_paged.dart';

/// 前台广告位。
class AdRepository {
  final ApiClient client;

  AdRepository(this.client);

  Future<List<AdItem>> fetch({
    String position = 'home_banner',
    int limit = 3,
  }) async {
    final data = await client.get(
      Endpoints.ads,
      queryParameters: {'position': position, 'limit': limit},
    );
    return parseList(data, AdItem.fromJson);
  }
}
