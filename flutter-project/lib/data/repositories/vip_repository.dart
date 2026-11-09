import '../../core/network/api_client.dart';
import '../../core/network/endpoints.dart';
import '../models/vip.dart';
import '_paged.dart';

/// VIP：套餐 / 会员状态 / 金币开通。
class VipRepository {
  final ApiClient client;

  VipRepository(this.client);

  Future<List<VipPlan>> plans() async {
    final data = await client.get(Endpoints.vipPlans);
    return parseList(data, VipPlan.fromJson);
  }

  Future<VipStatus> status() async {
    final data = await client.get(Endpoints.vipStatus);
    return VipStatus.fromJson(asDataMap(data));
  }

  Future<VipPurchaseResult> purchase(int planId) async {
    final data =
        await client.post(Endpoints.vipPurchase, data: {'plan_id': planId});
    return VipPurchaseResult.fromJson(asDataMap(data));
  }
}
