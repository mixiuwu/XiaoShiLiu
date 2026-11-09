/**
 * 金币获取方式（任务规则）工具
 * 规则由管理后台维护，用户完成行为或手动领取时按规则发放金币，并按每日上限去重
 */
const { pool } = require('../config/config')
const { addCoin } = require('./coinHelper')

class CoinEarnError extends Error {
  constructor(message, code = 'COIN_EARN_ERROR') {
    super(message)
    this.name = 'CoinEarnError'
    this.code = code
  }
}

async function getEnabledRule(code) {
  const [rows] = await pool.execute(
    'SELECT id, code, name, reward_coin, daily_limit, auto_reward FROM coin_earn_rules WHERE code = ? AND enabled = 1',
    [code]
  )
  return rows[0] || null
}

async function countToday(userId, code) {
  const [rows] = await pool.execute(
    'SELECT COUNT(*) AS total FROM coin_transactions WHERE user_id = ? AND scene = ? AND type = 1 AND created_at >= CURDATE()',
    [userId.toString(), code]
  )
  return rows[0].total
}

/**
 * 按规则发放金币
 * @param {number|string} userId 用户ID
 * @param {string} code 规则编码
 * @param {Object} options throwOnLimit=true 时达到上限/规则不存在会抛错（供手动领取接口使用）
 * @returns {Promise<{amount:number, balance:number, name:string}|null>} 未发放时返回 null
 */
async function grantRuleReward(userId, code, { throwOnLimit = false } = {}) {
  const rule = await getEnabledRule(code)
  if (!rule) {
    if (throwOnLimit) throw new CoinEarnError('该金币获取方式未开放', 'RULE_NOT_FOUND')
    return null
  }
  if (rule.daily_limit > 0) {
    const used = await countToday(userId, code)
    if (used >= rule.daily_limit) {
      if (throwOnLimit) throw new CoinEarnError('今日奖励次数已用完', 'LIMIT_REACHED')
      return null
    }
  }

  const balance = await addCoin(userId, rule.reward_coin, code)
  return { amount: rule.reward_coin, balance, name: rule.name }
}

/**
 * 用户可见的金币获取方式列表（含今日已领取次数）
 */
async function listEarnRules(userId) {
  const [rows] = await pool.execute(
    `SELECT r.code, r.name, r.description, r.reward_coin, r.daily_limit, r.auto_reward, r.sort_order,
            (SELECT COUNT(*) FROM coin_transactions ct
              WHERE ct.user_id = ? AND ct.scene = r.code AND ct.type = 1 AND ct.created_at >= CURDATE()) AS today_count
     FROM coin_earn_rules r
     WHERE r.enabled = 1
     ORDER BY r.sort_order ASC, r.id ASC`,
    [userId.toString()]
  )
  return rows.map((row) => ({
    ...row,
    remaining: row.daily_limit > 0 ? Math.max(0, row.daily_limit - row.today_count) : null
  }))
}

module.exports = {
  grantRuleReward,
  listEarnRules,
  CoinEarnError
}
