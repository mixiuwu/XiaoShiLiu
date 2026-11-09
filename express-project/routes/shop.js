const express = require('express');
const router = express.Router();
const { HTTP_STATUS, RESPONSE_CODES, ERROR_MESSAGES } = require('../constants');
const { pool } = require('../config/config');
const { authenticateToken } = require('../middleware/auth');
const { deductCoin, InsufficientCoinError } = require('../utils/coinHelper');

// 商品列表
router.get('/products', async (req, res) => {
  try {
    const [rows] = await pool.execute(
      'SELECT id, name, cover_url, price_coin, stock, created_at FROM products ORDER BY id ASC'
    );
    res.json({ code: RESPONSE_CODES.SUCCESS, message: 'success', data: rows });
  } catch (error) {
    console.error('获取商品列表失败:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({ code: RESPONSE_CODES.ERROR, message: ERROR_MESSAGES.INTERNAL_SERVER_ERROR });
  }
});

// 下单（用金币购买，mock 支付）
router.post('/orders', authenticateToken, async (req, res) => {
  try {
    const productId = parseInt(req.body.product_id);
    const quantity = parseInt(req.body.quantity) || 1;

    if (!productId || quantity <= 0) {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({ code: RESPONSE_CODES.VALIDATION_ERROR, message: '请选择商品和数量' });
    }

    const [productRows] = await pool.execute('SELECT id, name, price_coin, stock FROM products WHERE id = ?', [productId.toString()]);
    if (productRows.length === 0) {
      return res.status(HTTP_STATUS.NOT_FOUND).json({ code: RESPONSE_CODES.NOT_FOUND, message: '商品不存在' });
    }
    const product = productRows[0];
    if (product.stock < quantity) {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({ code: RESPONSE_CODES.VALIDATION_ERROR, message: '商品库存不足' });
    }

    const totalCoin = product.price_coin * quantity;

    // 先扣金币（余额不足抛错）
    try {
      await deductCoin(req.user.id, totalCoin, 'order');
    } catch (e) {
      if (e instanceof InsufficientCoinError) {
        return res.status(HTTP_STATUS.BAD_REQUEST).json({ code: RESPONSE_CODES.VALIDATION_ERROR, message: e.message });
      }
      throw e;
    }

    // 扣库存 + 生成订单
    await pool.execute('UPDATE products SET stock = stock - ? WHERE id = ?', [quantity, productId.toString()]);
    const [orderResult] = await pool.execute(
      'INSERT INTO orders (user_id, product_id, quantity, total_coin, status) VALUES (?, ?, ?, ?, 0)',
      [req.user.id.toString(), productId.toString(), quantity, totalCoin]
    );

    res.json({
      code: RESPONSE_CODES.SUCCESS,
      message: '下单成功',
      data: { order_id: orderResult.insertId, product_name: product.name, quantity, total_coin: totalCoin, status: 0 }
    });
  } catch (error) {
    console.error('下单失败:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({ code: RESPONSE_CODES.ERROR, message: ERROR_MESSAGES.INTERNAL_SERVER_ERROR });
  }
});

// 我的订单
router.get('/orders', authenticateToken, async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;

    const [rows] = await pool.execute(
      `SELECT o.id, o.product_id, o.quantity, o.total_coin, o.status, o.created_at, p.name as product_name, p.cover_url
       FROM orders o LEFT JOIN products p ON o.product_id = p.id
       WHERE o.user_id = ? ORDER BY o.created_at DESC LIMIT ? OFFSET ?`,
      [req.user.id.toString(), limit.toString(), offset.toString()]
    );
    const [countRows] = await pool.execute('SELECT COUNT(*) as total FROM orders WHERE user_id = ?', [req.user.id.toString()]);
    const total = countRows[0].total;

    res.json({
      code: RESPONSE_CODES.SUCCESS,
      message: 'success',
      data: { orders: rows, pagination: { page, limit, total, pages: Math.ceil(total / limit) } }
    });
  } catch (error) {
    console.error('获取订单列表失败:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({ code: RESPONSE_CODES.ERROR, message: ERROR_MESSAGES.INTERNAL_SERVER_ERROR });
  }
});

module.exports = router;
