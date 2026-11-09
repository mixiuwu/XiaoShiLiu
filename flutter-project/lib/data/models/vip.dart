import '_json.dart';

/// VIP 套餐。
class VipPlan {
  final int id;
  final String name;
  final int level;
  final int priceCoin;
  final int durationDays;
  final List<String> perks;

  const VipPlan({
    required this.id,
    required this.name,
    required this.level,
    required this.priceCoin,
    required this.durationDays,
    this.perks = const [],
  });

  factory VipPlan.fromJson(Map<String, dynamic> json) => VipPlan(
        id: asInt(json['id']),
        name: asString(json['name']),
        level: asInt(json['level'], 1),
        priceCoin: asInt(json['price_coin']),
        durationDays: asInt(json['duration_days']),
        perks: asStringList(json['perks']),
      );
}

/// 当前用户会员状态。
class VipStatus {
  final bool isVip;
  final int level;
  final String? planName;
  final String? expireAt;
  final int remainingDays;

  const VipStatus({
    this.isVip = false,
    this.level = 0,
    this.planName,
    this.expireAt,
    this.remainingDays = 0,
  });

  factory VipStatus.fromJson(Map<String, dynamic> json) => VipStatus(
        isVip: asBool(json['is_vip']),
        level: asInt(json['level']),
        planName: asStringOrNull(json['plan_name']),
        expireAt: asStringOrNull(json['expire_at']),
        remainingDays: asInt(json['remaining_days']),
      );
}

/// 开通/续费结果。
class VipPurchaseResult {
  final int level;
  final String? expireAt;
  final int costCoin;

  const VipPurchaseResult({
    required this.level,
    this.expireAt,
    required this.costCoin,
  });

  factory VipPurchaseResult.fromJson(Map<String, dynamic> json) =>
      VipPurchaseResult(
        level: asInt(json['level']),
        expireAt: asStringOrNull(json['expire_at']),
        costCoin: asInt(json['cost_coin']),
      );
}
