const express = require('express');
const router = express.Router();
const { HTTP_STATUS, RESPONSE_CODES, ERROR_MESSAGES } = require('../constants');
const { pool } = require('../config/config');
const { optionalAuth, authenticateToken } = require('../middleware/auth');
const { grantRuleReward } = require('../utils/coinEarnHelper');

// 获取某笔记的弹幕列表（按视频时间点排序）
router.get('/:postId', optionalAuth, async (req, res) => {
  try {
    const postId = req.params.postId;
    const [rows] = await pool.execute(
      `SELECT d.id, d.post_id, d.content, d.offset_sec, d.color, d.created_at,
              u.id as user_id, u.nickname, u.avatar
       FROM danmaku d
       LEFT JOIN users u ON d.user_id = u.id
       WHERE d.post_id = ?
       ORDER BY d.offset_sec ASC, d.created_at ASC`,
      [postId.toString()]
    );
    res.json({ code: RESPONSE_CODES.SUCCESS, message: 'success', data: rows });
  } catch (error) {
    console.error('获取弹幕列表失败:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({ code: RESPONSE_CODES.ERROR, message: ERROR_MESSAGES.INTERNAL_SERVER_ERROR });
  }
});

// 发送弹幕
router.post('/:postId', authenticateToken, async (req, res) => {
  try {
    const postId = req.params.postId;
    const userId = req.user.id;
    const { content, offset_sec = 0, color = '#FFFFFF' } = req.body;

    if (!content || !content.trim()) {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({ code: RESPONSE_CODES.VALIDATION_ERROR, message: '弹幕内容不能为空' });
    }
    if (content.length > 100) {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({ code: RESPONSE_CODES.VALIDATION_ERROR, message: '弹幕内容不能超过100字' });
    }

    // 验证笔记存在
    const [postRows] = await pool.execute('SELECT id FROM posts WHERE id = ?', [postId.toString()]);
    if (postRows.length === 0) {
      return res.status(HTTP_STATUS.NOT_FOUND).json({ code: RESPONSE_CODES.NOT_FOUND, message: '笔记不存在' });
    }

    const offset = Math.max(0, parseInt(offset_sec) || 0);

    const [result] = await pool.execute(
      'INSERT INTO danmaku (post_id, user_id, content, offset_sec, color) VALUES (?, ?, ?, ?, ?)',
      [postId.toString(), userId.toString(), content.trim(), offset, color]
    );

    // 弹幕金币奖励（按后台配置的金币获取方式发放，不影响主流程）
    try {
      await grantRuleReward(userId, 'danmaku');
    } catch (coinErr) {
      console.error('弹幕金币奖励发放失败:', coinErr);
    }

    res.json({
      code: RESPONSE_CODES.SUCCESS,
      message: '发送成功',
      data: { id: result.insertId, post_id: Number(postId), content: content.trim(), offset_sec: offset, color }
    });
  } catch (error) {
    console.error('发送弹幕失败:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({ code: RESPONSE_CODES.ERROR, message: ERROR_MESSAGES.INTERNAL_SERVER_ERROR });
  }
});

module.exports = router;
