import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/network/endpoints.dart';
import '../models/order.dart';
import '../models/page.dart';
import '../models/product.dart';
import '_paged.dart';

/// 商城：商品 / 下单 / 我的订单。
class ShopRepository {
  final ApiClient client;

  ShopRepository(this.client);

  Future<List<Product>> products() async {
    final data = await client.get(Endpoints.shopProducts);
    return parseList(data, Product.fromJson);
  }

  Future<OrderResult> createOrder(int productId, {int quantity = 1}) async {
    final data = await client.post(Endpoints.shopOrders, data: {
      'product_id': productId,
      'quantity': quantity,
    });
    return OrderResult.fromJson(asDataMap(data));
  }

  Future<Paged<Order>> orders({int page = 1, int? limit}) async {
    final data = await client.get(Endpoints.shopOrders, queryParameters: {
      'page': page,
      'limit': limit ?? AppConfig.defaultPageSize,
    });
    return parsePaged(data, 'orders', Order.fromJson);
  }
}
