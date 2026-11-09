import '../../core/config/app_config.dart';
import '_json.dart';

/// 商城商品。
class Product {
  final int id;
  final String name;
  final String? coverUrl;
  final int priceCoin;
  final int stock;
  final String? createdAt;

  const Product({
    required this.id,
    required this.name,
    this.coverUrl,
    required this.priceCoin,
    required this.stock,
    this.createdAt,
  });

  bool get inStock => stock > 0;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: asInt(json['id']),
        name: asString(json['name']),
        coverUrl: AppConfig.resolveMedia(asStringOrNull(json['cover_url'])),
        priceCoin: asInt(json['price_coin']),
        stock: asInt(json['stock']),
        createdAt: asStringOrNull(json['created_at']),
      );
}
