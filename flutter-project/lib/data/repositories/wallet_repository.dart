import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/network/endpoints.dart';
import '../models/page.dart';
import '../models/wallet.dart';
import '_paged.dart';

/// 钱包：余额 / 金币流水 / 提现。
class WalletRepository {
  final ApiClient client;

  WalletRepository(this.client);

  Future<Wallet> get() async {
    final data = await client.get(Endpoints.wallet);
    return Wallet.fromJson(asDataMap(data));
  }

  Future<Paged<CoinTransaction>> transactions(
      {int page = 1, int? limit}) async {
    final data =
        await client.get(Endpoints.walletTransactions, queryParameters: {
      'page': page,
      'limit': limit ?? AppConfig.defaultPageSize,
    });
    return parsePaged(data, 'transactions', CoinTransaction.fromJson);
  }

  /// 提现（金币数），返回模拟受理结果。
  Future<WithdrawResult> withdraw(int amount) async {
    final data =
        await client.post(Endpoints.walletWithdraw, data: {'amount': amount});
    return WithdrawResult.fromJson(asDataMap(data));
  }
}
