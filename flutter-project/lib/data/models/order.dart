import '../../core/config/app_config.dart';
import '_json.dart';

/// 订单。status: 0-待发货 1-已发货 2-已完成。
class Order {
  final int id;
  final int productId;
  final int quantity;
  final int totalCoin;
  final int status;
  final String? createdAt;
  final String productName;
  final String? coverUrl;

  const Order({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.totalCoin,
    required this.status,
    this.createdAt,
    required this.productName,
    this.coverUrl,
  });

  String get statusText {
    switch (status) {
      case 1:
        return '已发货';
      case 2:
        return '已完成';
      default:
        return '待发货';
    }
  }

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: asInt(json['id']),
        productId: asInt(json['product_id']),
        quantity: asInt(json['quantity'], 1),
        totalCoin: asInt(json['total_coin']),
        status: asInt(json['status']),
        createdAt: asStringOrNull(json['created_at']),
        productName: asString(json['product_name']),
        coverUrl: AppConfig.resolveMedia(asStringOrNull(json['cover_url'])),
      );
}

/// 下单返回结果。
class OrderResult {
  final int orderId;
  final String productName;
  final int quantity;
  final int totalCoin;
  final int status;

  const OrderResult({
    required this.orderId,
    required this.productName,
    required this.quantity,
    required this.totalCoin,
    required this.status,
  });

  factory OrderResult.fromJson(Map<String, dynamic> json) => OrderResult(
        orderId: asInt(json['order_id']),
        productName: asString(json['product_name']),
        quantity: asInt(json['quantity'], 1),
        totalCoin: asInt(json['total_coin']),
        status: asInt(json['status']),
      );
}
