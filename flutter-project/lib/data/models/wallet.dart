import '_json.dart';

/// 钱包余额。
class Wallet {
  final int coinBalance;
  final double withdrawableYuan;
  final int coinPerYuan;

  const Wallet({
    this.coinBalance = 0,
    this.withdrawableYuan = 0,
    this.coinPerYuan = 100,
  });

  factory Wallet.fromJson(Map<String, dynamic> json) => Wallet(
        coinBalance: asInt(json['coin_balance']),
        withdrawableYuan: asDouble(json['withdrawable_yuan']),
        coinPerYuan: asInt(json['coin_per_yuan'], 100),
      );
}

/// 金币流水。type: 1-收入 2-支出。
class CoinTransaction {
  final int id;
  final int amount;
  final int type;
  final String scene;
  final int balanceAfter;
  final String? createdAt;

  const CoinTransaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.scene,
    required this.balanceAfter,
    this.createdAt,
  });

  bool get isIncome => type == 1;

  factory CoinTransaction.fromJson(Map<String, dynamic> json) =>
      CoinTransaction(
        id: asInt(json['id']),
        amount: asInt(json['amount']),
        type: asInt(json['type']),
        scene: asString(json['scene']),
        balanceAfter: asInt(json['balance_after']),
        createdAt: asStringOrNull(json['created_at']),
      );
}

/// 提现申请结果。
class WithdrawResult {
  final int withdrawnCoin;
  final double yuan;
  final int coinBalance;
  final String status;

  const WithdrawResult({
    required this.withdrawnCoin,
    required this.yuan,
    required this.coinBalance,
    required this.status,
  });

  factory WithdrawResult.fromJson(Map<String, dynamic> json) => WithdrawResult(
        withdrawnCoin: asInt(json['withdrawn_coin']),
        yuan: asDouble(json['yuan']),
        coinBalance: asInt(json['coin_balance']),
        status: asString(json['status'], 'pending'),
      );
}
