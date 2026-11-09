const express = require('express');
const router = express.Router();
const { HTTP_STATUS, RESPONSE_CODES, ERROR_MESSAGES } = require('../constants');
const { pool } = require('../config/config');
const { authenticateToken } = require('../middleware/auth');
const { deductCoin, getBalance, InsufficientCoinError } = require('../utils/coinHelper');
const { grantRuleReward, listEarnRules, CoinEarnError } = require('../utils/coinEarnHelper');

// 金币提现汇率：100 金币 = 1 元（仅用于展示，mock 提现）
const COIN_PER_YUAN = 100;

// 查询钱包余额
router.get('/', authenticateToken, async (req, res) => {
  try {
    const balance = await getBalance(req.user.id);
    res.json({
      code: RESPONSE_CODES.SUCCESS,
      message: 'success',
      data: {
        coin_balance: balance,
        withdrawable_yuan: Math.floor(balance / COIN_PER_YUAN * 100) / 100,
        coin_per_yuan: COIN_PER_YUAN
      }
    });
  } catch (error) {
    console.error('查询钱包失败:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({ code: RESPONSE_CODES.ERROR, message: ERROR_MESSAGES.INTERNAL_SERVER_ERROR });
  }
});

// 金币流水明细
router.get('/transactions', authenticateToken, async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;

    const [rows] = await pool.execute(
      'SELECT id, amount, type, scene, balance_after, created_at FROM coin_transactions WHERE user_id = ? ORDER BY created_at DESC, id DESC LIMIT ? OFFSET ?',
      [req.user.id.toString(), limit.toString(), offset.toString()]
    );
    const [countRows] = await pool.execute(
      'SELECT COUNT(*) as total FROM coin_transactions WHERE user_id = ?',
      [req.user.id.toString()]
    );
    const total = countRows[0].total;

    res.json({
      code: RESPONSE_CODES.SUCCESS,
      message: 'success',
      data: { transactions: rows, pagination: { page, limit, total, pages: Math.ceil(total / limit) } }
    });
  } catch (error) {
    console.error('查询金币流水失败:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({ code: RESPONSE_CODES.ERROR, message: ERROR_MESSAGES.INTERNAL_SERVER_ERROR });
  }
});

// 金币获取方式列表（含今日已领取次数）
router.get('/earn-rules', authenticateToken, async (req, res) => {
  try {
    const rules = await listEarnRules(req.user.id);
    res.json({ code: RESPONSE_CODES.SUCCESS, message: 'success', data: rules });
  } catch (error) {
    console.error('查询金币获取方式失败:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({ code: RESPONSE_CODES.ERROR, message: ERROR_MESSAGES.INTERNAL_SERVER_ERROR });
  }
});

// 手动领取金币（仅限后台配置为“手动领取”的方式，如看广告/看视频）
router.post('/earn', authenticateToken, async (req, res) => {
  try {
    const code = String(req.body.code || '').trim();
    if (!code) {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({ code: RESPONSE_CODES.VALIDATION_ERROR, message: '缺少金币获取方式编码' });
    }

    const [ruleRows] = await pool.execute('SELECT auto_reward FROM coin_earn_rules WHERE code = ? AND enabled = 1', [code]);
    if (ruleRows.length === 0) {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({ code: RESPONSE_CODES.VALIDATION_ERROR, message: '该金币获取方式未开放' });
    }
    if (ruleRows[0].auto_reward) {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({ code: RESPONSE_CODES.VALIDATION_ERROR, message: '该奖励在完成行为后自动发放' });
    }

    const result = await grantRuleReward(req.user.id, code, { throwOnLimit: true });
    res.json({
      code: RESPONSE_CODES.SUCCESS,
      message: `领取成功，获得 ${result.amount} 金币`,
      data: { amount: result.amount, coin_balance: result.balance, name: result.name }
    });
  } catch (error) {
    if (error instanceof CoinEarnError) {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({ code: RESPONSE_CODES.VALIDATION_ERROR, message: error.message });
    }
    console.error('领取金币失败:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({ code: RESPONSE_CODES.ERROR, message: ERROR_MESSAGES.INTERNAL_SERVER_ERROR });
  }
});

// 提现申请（mock：扣减金币并记录流水，不产生真实资金流转）
router.post('/withdraw', authenticateToken, async (req, res) => {
  try {
    const amount = parseInt(req.body.amount);
    if (!Number.isInteger(amount) || amount <= 0) {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({ code: RESPONSE_CODES.VALIDATION_ERROR, message: '提现金币数必须为正整数' });
    }
    if (amount < COIN_PER_YUAN) {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({ code: RESPONSE_CODES.VALIDATION_ERROR, message: `最低提现 ${COIN_PER_YUAN} 金币（1 元）` });
    }

    const balanceAfter = await deductCoin(req.user.id, amount, 'withdraw');

    res.json({
      code: RESPONSE_CODES.SUCCESS,
      message: '提现申请已提交（模拟）',
      data: {
        withdrawn_coin: amount,
        yuan: Math.floor((amount / COIN_PER_YUAN) * 100) / 100,
        coin_balance: balanceAfter,
        status: 'pending'
      }
    });
  } catch (error) {
    if (error instanceof InsufficientCoinError) {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({ code: RESPONSE_CODES.VALIDATION_ERROR, message: error.message });
    }
    console.error('提现失败:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({ code: RESPONSE_CODES.ERROR, message: ERROR_MESSAGES.INTERNAL_SERVER_ERROR });
  }
});

module.exports = router;
