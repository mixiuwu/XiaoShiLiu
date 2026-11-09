const express = require('express');
const router = express.Router();
const { HTTP_STATUS, RESPONSE_CODES, ERROR_MESSAGES } = require('../constants');
const { pool } = require('../config/config');
const { authenticateToken } = require('../middleware/auth');
const { deductCoin, InsufficientCoinError } = require('../utils/coinHelper');

// VIP 套餐列表
router.get('/plans', async (req, res) => {
  try {
    const [rows] = await pool.execute(
      'SELECT id, name, level, price_coin, duration_days, perks_json FROM vip_plans ORDER BY level ASC'
    );
    const data = rows.map(r => ({
      ...r,
      perks: typeof r.perks_json === 'string' ? JSON.parse(r.perks_json) : (r.perks_json || [])
    }));
    res.json({ code: RESPONSE_CODES.SUCCESS, message: 'success', data });
  } catch (error) {
    console.error('获取VIP套餐失败:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({ code: RESPONSE_CODES.ERROR, message: ERROR_MESSAGES.INTERNAL_SERVER_ERROR });
  }
});

// 当前用户会员状态
router.get('/status', authenticateToken, async (req, res) => {
  try {
    const [rows] = await pool.execute(
      `SELECT v.level, v.start_at, v.expire_at, p.name as plan_name
       FROM user_vip v LEFT JOIN vip_plans p ON v.plan_id = p.id
       WHERE v.user_id = ?`,
      [req.user.id.toString()]
    );

    if (rows.length === 0) {
      return res.json({ code: RESPONSE_CODES.SUCCESS, message: 'success', data: { is_vip: false, level: 0 } });
    }

    const vip = rows[0];
    const active = vip.expire_at && new Date(vip.expire_at).getTime() > Date.now();
    res.json({
      code: RESPONSE_CODES.SUCCESS,
      message: 'success',
      data: {
        is_vip: !!active,
        level: active ? vip.level : 0,
        plan_name: active ? vip.plan_name : null,
        expire_at: vip.expire_at,
        remaining_days: active
          ? Math.max(0, Math.ceil((new Date(vip.expire_at).getTime() - Date.now()) / 86400000))
          : 0
      }
    });
  } catch (error) {
    console.error('获取会员状态失败:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({ code: RESPONSE_CODES.ERROR, message: ERROR_MESSAGES.INTERNAL_SERVER_ERROR });
  }
});

// 用金币开通/续费 VIP（mock 支付）
router.post('/purchase', authenticateToken, async (req, res) => {
  try {
    const planId = parseInt(req.body.plan_id);
    if (!planId) {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({ code: RESPONSE_CODES.VALIDATION_ERROR, message: '请选择要开通的套餐' });
    }

    const [planRows] = await pool.execute('SELECT id, level, price_coin, duration_days FROM vip_plans WHERE id = ?', [planId.toString()]);
    if (planRows.length === 0) {
      return res.status(HTTP_STATUS.NOT_FOUND).json({ code: RESPONSE_CODES.NOT_FOUND, message: '套餐不存在' });
    }
    const plan = planRows[0];

    // 扣金币（余额不足会抛错）
    await deductCoin(req.user.id, plan.price_coin, 'vip');

    // 读取当前会员记录，计算到期时间（未过期则续期叠加）
    const [cur] = await pool.execute('SELECT expire_at FROM user_vip WHERE user_id = ?', [req.user.id.toString()]);
    let base = Date.now();
    if (cur.length > 0 && cur[0].expire_at && new Date(cur[0].expire_at).getTime() > base) {
      base = new Date(cur[0].expire_at).getTime();
    }
    const expireAt = new Date(base + plan.duration_days * 86400000);

    await pool.execute(
      `INSERT INTO user_vip (user_id, plan_id, level, start_at, expire_at)
       VALUES (?, ?, ?, NOW(), ?)
       ON DUPLICATE KEY UPDATE plan_id = VALUES(plan_id), level = VALUES(level), expire_at = VALUES(expire_at)`,
      [req.user.id.toString(), planId.toString(), plan.level, expireAt]
    );
    await pool.execute('UPDATE users SET is_vip = 1 WHERE id = ?', [req.user.id.toString()]);

    res.json({
      code: RESPONSE_CODES.SUCCESS,
      message: '开通成功',
      data: { level: plan.level, expire_at: expireAt, cost_coin: plan.price_coin }
    });
  } catch (error) {
    if (error instanceof InsufficientCoinError) {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({ code: RESPONSE_CODES.VALIDATION_ERROR, message: error.message });
    }
    console.error('开通VIP失败:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({ code: RESPONSE_CODES.ERROR, message: ERROR_MESSAGES.INTERNAL_SERVER_ERROR });
  }
});

module.exports = router;
