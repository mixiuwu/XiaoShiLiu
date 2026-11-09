const express = require('express');
const router = express.Router();
const { HTTP_STATUS, RESPONSE_CODES, ERROR_MESSAGES } = require('../constants');
const { pool } = require('../config/config');
const { authenticateToken } = require('../middleware/auth');

// 音乐列表（支持关键词搜索、分页）
router.get('/', async (req, res) => {
  try {
    const keyword = req.query.keyword || '';
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;

    let where = '';
    const params = [];
    if (keyword.trim()) {
      where = 'WHERE title LIKE ? OR author LIKE ?';
      params.push(`%${keyword}%`, `%${keyword}%`);
    }

    const [rows] = await pool.query(
      `SELECT id, title, author, audio_url, cover_url, duration, use_count, created_at
       FROM musics ${where} ORDER BY use_count DESC, created_at DESC LIMIT ? OFFSET ?`,
      [...params, limit.toString(), offset.toString()]
    );
    const [countRows] = await pool.query(
      `SELECT COUNT(*) as total FROM musics ${where}`,
      params
    );
    const total = countRows[0].total;

    res.json({
      code: RESPONSE_CODES.SUCCESS,
      message: 'success',
      data: { musics: rows, pagination: { page, limit, total, pages: Math.ceil(total / limit) } }
    });
  } catch (error) {
    console.error('获取音乐列表失败:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({ code: RESPONSE_CODES.ERROR, message: ERROR_MESSAGES.INTERNAL_SERVER_ERROR });
  }
});

// 热门音乐
router.get('/hot', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 10;
    const [rows] = await pool.execute(
      'SELECT id, title, author, audio_url, cover_url, duration, use_count FROM musics ORDER BY use_count DESC, created_at DESC LIMIT ?',
      [String(limit)]
    );
    res.json({ code: RESPONSE_CODES.SUCCESS, message: 'success', data: rows });
  } catch (error) {
    console.error('获取热门音乐失败:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({ code: RESPONSE_CODES.ERROR, message: ERROR_MESSAGES.INTERNAL_SERVER_ERROR });
  }
});

// 新增音乐（登录用户，audio_url 由客户端上传后传入）
router.post('/', authenticateToken, async (req, res) => {
  try {
    const { title, author = null, audio_url, cover_url = null, duration = 0 } = req.body;

    if (!title || !audio_url) {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({ code: RESPONSE_CODES.VALIDATION_ERROR, message: '歌曲名和音频URL不能为空' });
    }

    const [result] = await pool.execute(
      'INSERT INTO musics (title, author, audio_url, cover_url, duration) VALUES (?, ?, ?, ?, ?)',
      [title, author, audio_url, cover_url, parseInt(duration) || 0]
    );

    res.json({ code: RESPONSE_CODES.SUCCESS, message: '创建成功', data: { id: result.insertId } });
  } catch (error) {
    console.error('创建音乐失败:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({ code: RESPONSE_CODES.ERROR, message: ERROR_MESSAGES.INTERNAL_SERVER_ERROR });
  }
});

module.exports = router;
