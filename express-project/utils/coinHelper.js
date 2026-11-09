/**
 * 金币账本工具
 * 统一管理用户金币的增减与流水记录，供钱包/VIP/商城等模块复用
 *
 * 约定：
 * - 所有金币变动都在事务内完成，保证余额与流水一致
 * - deductCoin 在余额不足时抛出 InsufficientCoinError
 */
const { pool } = require('../config/config');

/** 余额不足错误 */
class InsufficientCoinError extends Error {
  constructor(message = '金币余额不足') {
    super(message);
    this.name = 'InsufficientCoinError';
    this.code = 'INSUFFICIENT_COIN';
  }
}

/**
 * 确保用户有钱包记录（不存在则创建，余额0）
 * 使用传入的 connection，便于在事务内调用
 */
async function ensureWallet(conn, userId) {
  await conn.execute(
    'INSERT IGNORE INTO user_wallets (user_id, coin_balance) VALUES (?, 0)',
    [userId.toString()]
  );
}

/**
 * 增加金币
 * @param {number|string} userId 用户ID
 * @param {number} amount 增加数量（正整数）
 * @param {string} scene 场景标识（register/post/like/follow 等）
 * @returns {Promise<number>} 变动后余额
 */
async function addCoin(userId, amount, scene) {
  const amt = Math.floor(Number(amount));
  if (!Number.isInteger(amt) || amt <= 0) {
    throw new Error('addCoin: amount 必须为正整数');
  }

  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    await ensureWallet(conn, userId);

    await conn.execute(
      'UPDATE user_wallets SET coin_balance = coin_balance + ? WHERE user_id = ?',
      [amt, userId.toString()]
    );

    const [rows] = await conn.query(
      'SELECT coin_balance FROM user_wallets WHERE user_id = ?',
      [userId.toString()]
    );
    const balanceAfter = rows[0].coin_balance;

    await conn.execute(
      'INSERT INTO coin_transactions (user_id, amount, type, scene, balance_after) VALUES (?, ?, 1, ?, ?)',
      [userId.toString(), amt, scene, balanceAfter]
    );

    await conn.commit();
    return balanceAfter;
  } catch (err) {
    await conn.rollback();
    throw err;
  } finally {
    conn.release();
  }
}

/**
 * 扣减金币（余额不足抛 InsufficientCoinError）
 * @param {number|string} userId 用户ID
 * @param {number} amount 扣减数量（正整数）
 * @param {string} scene 场景标识
 * @returns {Promise<number>} 变动后余额
 */
async function deductCoin(userId, amount, scene) {
  const amt = Math.floor(Number(amount));
  if (!Number.isInteger(amt) || amt <= 0) {
    throw new Error('deductCoin: amount 必须为正整数');
  }

  const conn = await pool.getConnection();
  try {
    await conn.beginTransaction();
    await ensureWallet(conn, userId);

    // 行锁读取当前余额
    const [rows] = await conn.query(
      'SELECT coin_balance FROM user_wallets WHERE user_id = ? FOR UPDATE',
      [userId.toString()]
    );
    const current = rows[0].coin_balance;
    if (current < amt) {
      throw new InsufficientCoinError();
    }

    const balanceAfter = current - amt;
    await conn.execute(
      'UPDATE user_wallets SET coin_balance = ? WHERE user_id = ?',
      [balanceAfter, userId.toString()]
    );

    await conn.execute(
      'INSERT INTO coin_transactions (user_id, amount, type, scene, balance_after) VALUES (?, ?, 2, ?, ?)',
      [userId.toString(), -amt, scene, balanceAfter]
    );

    await conn.commit();
    return balanceAfter;
  } catch (err) {
    await conn.rollback();
    throw err;
  } finally {
    conn.release();
  }
}

/**
 * 查询用户金币余额（无钱包记录返回0）
 * @param {number|string} userId 用户ID
 * @returns {Promise<number>}
 */
async function getBalance(userId) {
  const [rows] = await pool.execute(
    'SELECT coin_balance FROM user_wallets WHERE user_id = ?',
    [userId.toString()]
  );
  return rows.length > 0 ? rows[0].coin_balance : 0;
}

module.exports = {
  addCoin,
  deductCoin,
  getBalance,
  ensureWallet,
  InsufficientCoinError
};
