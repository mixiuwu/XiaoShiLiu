const express = require('express');
const router = express.Router();
const { HTTP_STATUS, RESPONSE_CODES, ERROR_MESSAGES } = require('../constants');
const { pool } = require('../config/config');
const { optionalAuth, authenticateToken } = require('../middleware/auth');

/**
 * 组装投票详情（选项、百分比、参与人数、当前用户是否已投、剩余时间）
 */
async function buildPollDetail(pollId, currentUserId) {
  const [pollRows] = await pool.execute(
    'SELECT id, post_id, question, ends_at, created_at FROM polls WHERE id = ?',
    [pollId.toString()]
  );
  if (pollRows.length === 0) return null;
  const poll = pollRows[0];

  const [options] = await pool.execute(
    'SELECT id, content, vote_count, sort_order FROM poll_options WHERE poll_id = ? ORDER BY sort_order ASC, id ASC',
    [pollId.toString()]
  );

  const totalVotes = options.reduce((sum, o) => sum + o.vote_count, 0);

  let myOptionId = null;
  if (currentUserId) {
    const [mine] = await pool.execute(
      'SELECT option_id FROM poll_votes WHERE poll_id = ? AND user_id = ?',
      [pollId.toString(), currentUserId.toString()]
    );
    if (mine.length > 0) myOptionId = mine[0].option_id;
  }

  const expired = poll.ends_at ? new Date(poll.ends_at).getTime() < Date.now() : false;
  const remainingSeconds = poll.ends_at
    ? Math.max(0, Math.floor((new Date(poll.ends_at).getTime() - Date.now()) / 1000))
    : null;

  return {
    id: poll.id,
    post_id: poll.post_id,
    question: poll.question,
    ends_at: poll.ends_at,
    expired,
    remaining_seconds: remainingSeconds,
    total_votes: totalVotes,
    voted: myOptionId !== null,
    my_choice: myOptionId,
    options: options.map(o => ({
      id: o.id,
      content: o.content,
      vote_count: o.vote_count,
      percentage: totalVotes > 0 ? Math.round((o.vote_count / totalVotes) * 1000) / 10 : 0,
      selected: o.id === myOptionId
    }))
  };
}

// 获取投票详情
router.get('/:id', optionalAuth, async (req, res) => {
  try {
    const currentUserId = req.user ? req.user.id : null;
    const detail = await buildPollDetail(req.params.id, currentUserId);
    if (!detail) {
      return res.status(HTTP_STATUS.NOT_FOUND).json({ code: RESPONSE_CODES.NOT_FOUND, message: '投票不存在' });
    }
    res.json({ code: RESPONSE_CODES.SUCCESS, message: 'success', data: detail });
  } catch (error) {
    console.error('获取投票详情失败:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({ code: RESPONSE_CODES.ERROR, message: ERROR_MESSAGES.INTERNAL_SERVER_ERROR });
  }
});

// 投票
router.post('/:id/vote', authenticateToken, async (req, res) => {
  const conn = await pool.getConnection();
  try {
    const pollId = req.params.id;
    const userId = req.user.id;
    const optionId = parseInt(req.body.option_id);

    if (!optionId) {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({ code: RESPONSE_CODES.VALIDATION_ERROR, message: '请选择投票选项' });
    }

    await conn.beginTransaction();

    const [pollRows] = await conn.query('SELECT id, ends_at FROM polls WHERE id = ? FOR UPDATE', [pollId.toString()]);
    if (pollRows.length === 0) {
      await conn.rollback();
      return res.status(HTTP_STATUS.NOT_FOUND).json({ code: RESPONSE_CODES.NOT_FOUND, message: '投票不存在' });
    }
    const poll = pollRows[0];
    if (poll.ends_at && new Date(poll.ends_at).getTime() < Date.now()) {
      await conn.rollback();
      return res.status(HTTP_STATUS.BAD_REQUEST).json({ code: RESPONSE_CODES.VALIDATION_ERROR, message: '投票已结束' });
    }

    // 选项必须属于该投票
    const [optRows] = await conn.query('SELECT id FROM poll_options WHERE id = ? AND poll_id = ?', [optionId.toString(), pollId.toString()]);
    if (optRows.length === 0) {
      await conn.rollback();
      return res.status(HTTP_STATUS.BAD_REQUEST).json({ code: RESPONSE_CODES.VALIDATION_ERROR, message: '无效的投票选项' });
    }

    // 每人只能投一次
    const [existing] = await conn.query('SELECT id FROM poll_votes WHERE poll_id = ? AND user_id = ?', [pollId.toString(), userId.toString()]);
    if (existing.length > 0) {
      await conn.rollback();
      return res.status(HTTP_STATUS.CONFLICT).json({ code: RESPONSE_CODES.CONFLICT, message: '你已参与过该投票' });
    }

    await conn.execute('INSERT INTO poll_votes (poll_id, option_id, user_id) VALUES (?, ?, ?)', [pollId.toString(), optionId.toString(), userId.toString()]);
    await conn.execute('UPDATE poll_options SET vote_count = vote_count + 1 WHERE id = ?', [optionId.toString()]);

    await conn.commit();

    const currentUserId = userId;
    const detail = await buildPollDetail(pollId, currentUserId);
    res.json({ code: RESPONSE_CODES.SUCCESS, message: '投票成功', data: detail });
  } catch (error) {
    await conn.rollback();
    console.error('投票失败:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({ code: RESPONSE_CODES.ERROR, message: ERROR_MESSAGES.INTERNAL_SERVER_ERROR });
  } finally {
    conn.release();
  }
});

module.exports = router;
module.exports.buildPollDetail = buildPollDetail;
