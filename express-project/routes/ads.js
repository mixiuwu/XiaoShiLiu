const express = require('express')
const router = express.Router()
const { HTTP_STATUS, RESPONSE_CODES, ERROR_MESSAGES } = require('../constants')
const { pool } = require('../config/config')

/**
 * 获取正在投放的广告位
 * GET /api/ads?position=home_banner&limit=5
 */
router.get('/', async (req, res) => {
  try {
    const position = String(req.query.position || '').trim()
    const limit = Math.min(Math.max(parseInt(req.query.limit, 10) || 5, 1), 20)

    const conditions = [
      'status = 1',
      '(start_at IS NULL OR start_at <= NOW())',
      '(end_at IS NULL OR end_at >= NOW())'
    ]
    const params = []

    if (position) {
      conditions.push('position = ?')
      params.push(position)
    }

    const [rows] = await pool.execute(
      `SELECT id, title, image_url, link_url, position, sort_order, start_at, end_at
       FROM ads
       WHERE ${conditions.join(' AND ')}
       ORDER BY sort_order ASC, id DESC
       LIMIT ${limit}`,
      params
    )

    res.json({ code: RESPONSE_CODES.SUCCESS, message: 'success', data: rows })
  } catch (error) {
    console.error('获取广告位失败:', error)
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      code: RESPONSE_CODES.ERROR,
      message: ERROR_MESSAGES.INTERNAL_SERVER_ERROR
    })
  }
})

module.exports = router
