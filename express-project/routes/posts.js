const express = require('express');
const router = express.Router();
const { HTTP_STATUS, RESPONSE_CODES, ERROR_MESSAGES } = require('../constants');
const { pool } = require('../config/config');
const { optionalAuth, authenticateToken } = require('../middleware/auth');
const NotificationHelper = require('../utils/notificationHelper');
const { extractMentionedUsers, hasMentions } = require('../utils/mentionParser');
const { batchCleanupFiles } = require('../utils/fileCleanup');
const { sanitizeContent } = require('../utils/contentSecurity');
const { buildPollDetail } = require('./polls');
const { grantRuleReward } = require('../utils/coinEarnHelper');

// 获取笔记列表
router.get('/', optionalAuth, async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;
    const category = req.query.category;
    const status = req.query.status !== undefined ? parseInt(req.query.status) : 0;
    const userId = req.query.user_id ? parseInt(req.query.user_id) : null;
    const type = req.query.type ? parseInt(req.query.type) : null;
    const currentUserId = req.user ? req.user.id : null;

    if (status === 1) {
      if (!currentUserId) {
        return res.status(HTTP_STATUS.UNAUTHORIZED).json({ code: RESPONSE_CODES.UNAUTHORIZED, message: '查看草稿需要登录' });
      }
      const forcedUserId = currentUserId;

      let query = `
        SELECT p.*, u.nickname, u.avatar as user_avatar, u.user_id as author_account, u.id as author_auto_id, u.location, u.verified, c.name as category
        FROM posts p
        LEFT JOIN users u ON p.user_id = u.id
        LEFT JOIN categories c ON p.category_id = c.id
        WHERE p.status = ? AND p.user_id = ?
      `;
      let queryParams = [status.toString(), forcedUserId.toString()];

      if (category) {
        query += ` AND p.category_id = ?`;
        queryParams.push(category);
      }

      if (type) {
        query += ` AND p.type = ?`;
        queryParams.push(type);
      }

      query += ` ORDER BY p.created_at DESC LIMIT ? OFFSET ?`;
      queryParams.push(limit.toString(), offset.toString());


      const [rows] = await pool.execute(query, queryParams);

      if (rows.length > 0) {
        const postIds = rows.map(p => p.id);
        
        // 批量获取视频信息
        const [videos] = await pool.query('SELECT post_id, video_url, cover_url FROM post_videos WHERE post_id IN (?)', [postIds]);
        const videoMap = {};
        videos.forEach(v => { videoMap[v.post_id] = v; });

        // 批量获取图片信息
        const [images] = await pool.query('SELECT post_id, image_url FROM post_images WHERE post_id IN (?)', [postIds]);
        const imageMap = {};
        images.forEach(img => {
          if (!imageMap[img.post_id]) imageMap[img.post_id] = [];
          imageMap[img.post_id].push(img.image_url);
        });

        // 批量获取标签信息
        const [tags] = await pool.query(
          'SELECT pt.post_id, t.id, t.name FROM tags t JOIN post_tags pt ON t.id = pt.tag_id WHERE pt.post_id IN (?)',
          [postIds]
        );
        const tagMap = {};
        tags.forEach(t => {
          if (!tagMap[t.post_id]) tagMap[t.post_id] = [];
          tagMap[t.post_id].push({ id: t.id, name: t.name });
        });

        // 组装数据
        for (let post of rows) {
          if (post.type === 2) {
            const video = videoMap[post.id];
            post.images = video && video.cover_url ? [video.cover_url] : [];
            post.video_url = video ? video.video_url : null;
            post.image = video && video.cover_url ? video.cover_url : null;
          } else {
            const postImages = imageMap[post.id] || [];
            post.images = postImages;
            post.image = postImages.length > 0 ? postImages[0] : null;
          }
          post.tags = tagMap[post.id] || [];
          post.liked = false;
          post.collected = false;
        }
      }

      // 获取草稿总数
      const [countResult] = await pool.execute(
        'SELECT COUNT(*) as total FROM posts p WHERE p.status = ? AND p.user_id = ?' +
        (category ? ' AND p.category_id = ?' : '') +
        (type ? ' AND p.type = ?' : ''),
        [status.toString(), forcedUserId.toString(), ...(category ? [category] : []), ...(type ? [type] : [])]
      );
      const total = countResult[0].total;
      const pages = Math.ceil(total / limit);

      return res.json({
        code: RESPONSE_CODES.SUCCESS,
        message: 'success',
        data: {
          posts: rows,
          pagination: {
            page,
            limit,
            total,
            pages
          }
        }
      });
    }

    let query = `
      SELECT p.*, u.nickname, u.avatar as user_avatar, u.user_id as author_account, u.id as author_auto_id, u.location, u.verified, c.name as category
      FROM posts p
      LEFT JOIN users u ON p.user_id = u.id
      LEFT JOIN categories c ON p.category_id = c.id
      WHERE p.status = ?
    `;
    let queryParams = [status.toString()];

    // 特殊处理推荐频道：热度新鲜度评分前20%的笔记按分数排序
    if (category === 'recommend') {
      // 先获取总笔记数计算20%的数量
      let countQuery = 'SELECT COUNT(*) as total FROM posts WHERE status = ?';
      let countParams = [status.toString()];

      if (type) {
        countQuery += ' AND type = ?';
        countParams.push(type);
      }
      const [totalCountResult] = await pool.execute(countQuery, countParams);
      const totalPosts = totalCountResult[0].total;
      const recommendLimit = Math.ceil(totalPosts * 0.2);
      // 推荐算法：70%热度+30%新鲜度评分，新发布24小时内的笔记获得新鲜度加分，筛选前20%按分数排序
      let innerWhere = 'p.status = ?';
      let innerParams = [status.toString()];
      if (type) {
        innerWhere += ' AND p.type = ?';
        innerParams.push(type);
      }
      query = `
        SELECT 
          p.*, 
          u.nickname, 
          u.avatar as user_avatar, 
          u.user_id as author_account, 
          u.id as author_auto_id, 
          u.location, 
          u.verified,
          c.name as category
        FROM (
          SELECT 
            p.*,
            (p.view_count * 0.7 + (24 - LEAST(TIMESTAMPDIFF(HOUR, p.created_at, NOW()), 24)) * 0.3) as score
          FROM posts p 
          WHERE ${innerWhere}
          ORDER BY score DESC
          LIMIT ?
        ) p
        LEFT JOIN users u ON p.user_id = u.id 
        LEFT JOIN categories c ON p.category_id = c.id 
        ORDER BY p.score DESC
        LIMIT ? OFFSET ? 
      `;

      // 参数设置
      queryParams = [
        ...innerParams,
        recommendLimit.toString(),
        limit.toString(),
        offset.toString()
      ];
    } else {
      let whereConditions = [];
      let additionalParams = [];

      if (category) {
        whereConditions.push('p.category_id = ?');
        additionalParams.push(category);
      }

      if (userId) {
        whereConditions.push('p.user_id = ?');
        additionalParams.push(userId);
      }

      if (type) {
        whereConditions.push('p.type = ?');
        additionalParams.push(type);
      }

      if (whereConditions.length > 0) {
        query += ` AND ${whereConditions.join(' AND ')}`;
      }

      query += ` ORDER BY p.created_at DESC LIMIT ? OFFSET ?`;
      queryParams = [status.toString(), ...additionalParams, limit.toString(), offset.toString()];
    }
    const [rows] = await pool.execute(query, queryParams);


    // 获取每个笔记的图片、标签和用户点赞收藏状态
    if (rows.length > 0) {
      const postIds = rows.map(p => p.id);
      
      // 批量获取视频信息
      const [videos] = await pool.query('SELECT post_id, video_url, cover_url FROM post_videos WHERE post_id IN (?)', [postIds]);
      const videoMap = {};
      videos.forEach(v => { videoMap[v.post_id] = v; });

      // 批量获取图片信息
      const [images] = await pool.query('SELECT post_id, image_url FROM post_images WHERE post_id IN (?)', [postIds]);
      const imageMap = {};
      images.forEach(img => {
        if (!imageMap[img.post_id]) imageMap[img.post_id] = [];
        imageMap[img.post_id].push(img.image_url);
      });

      // 批量获取标签信息
      const [tags] = await pool.query(
        'SELECT pt.post_id, t.id, t.name FROM tags t JOIN post_tags pt ON t.id = pt.tag_id WHERE pt.post_id IN (?)',
        [postIds]
      );
      const tagMap = {};
      tags.forEach(t => {
        if (!tagMap[t.post_id]) tagMap[t.post_id] = [];
        tagMap[t.post_id].push({ id: t.id, name: t.name });
      });

      // 批量获取点赞状态
      let likedPostIds = new Set();
      if (currentUserId) {
        const [likes] = await pool.query(
          'SELECT target_id FROM likes WHERE user_id = ? AND target_type = 1 AND target_id IN (?)',
          [currentUserId.toString(), postIds]
        );
        likedPostIds = new Set(likes.map(l => l.target_id.toString()));
      }

      // 批量获取收藏状态
      let collectedPostIds = new Set();
      if (currentUserId) {
        const [collections] = await pool.query(
          'SELECT post_id FROM collections WHERE user_id = ? AND post_id IN (?)',
          [currentUserId.toString(), postIds]
        );
        collectedPostIds = new Set(collections.map(c => c.post_id.toString()));
      }

      // 组装数据
      for (let post of rows) {
        if (post.type === 2) {
          const video = videoMap[post.id];
          post.images = video && video.cover_url ? [video.cover_url] : [];
          post.video_url = video ? video.video_url : null;
          post.image = video && video.cover_url ? video.cover_url : null;
        } else {
          const postImages = imageMap[post.id] || [];
          post.images = postImages;
          post.image = postImages.length > 0 ? postImages[0] : null;
        }
        post.tags = tagMap[post.id] || [];
        post.liked = likedPostIds.has(post.id.toString());
        post.collected = collectedPostIds.has(post.id.toString());
      }
    }

    // 获取总数
    let total;
    if (category === 'recommend') {
      // 推荐频道的总数限制为总笔记数的20%
      let countQuery = 'SELECT COUNT(*) as total FROM posts WHERE status = ?';
      let countParams = [status.toString()];

      if (type) {
        countQuery += ' AND type = ?';
        countParams.push(type);
      }

      const [totalCountResult] = await pool.execute(countQuery, countParams);
      const totalPosts = totalCountResult[0].total;
      total = Math.ceil(totalPosts * 0.2);
    } else {
      let countQuery = 'SELECT COUNT(*) as total FROM posts WHERE status = ?';
      let countParams = [status.toString()];
      let countWhereConditions = [];

      if (category) {
        countQuery = 'SELECT COUNT(*) as total FROM posts p LEFT JOIN categories c ON p.category_id = c.id WHERE p.status = ?';
        countWhereConditions.push('p.category_id = ?');
        countParams.push(category);
      }

      if (userId) {
        countWhereConditions.push('user_id = ?');
        countParams.push(userId);
      }

      if (type) {
        countWhereConditions.push('type = ?');
        countParams.push(type);
      }

      if (countWhereConditions.length > 0) {
        countQuery += ` AND ${countWhereConditions.join(' AND ')}`;
      }

      const [countResult] = await pool.execute(countQuery, countParams);
      total = countResult[0].total;
    }

    res.json({
      code: RESPONSE_CODES.SUCCESS,
      message: 'success',
      data: {
        posts: rows,
        pagination: {
          page,
          limit,
          total,
          pages: Math.ceil(total / limit)
        }
      }
    });
  } catch (error) {
    console.error('获取笔记列表失败:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({ code: RESPONSE_CODES.ERROR, message: ERROR_MESSAGES.INTERNAL_SERVER_ERROR });
  }
});

// 获取笔记详情
router.get('/:id', optionalAuth, async (req, res) => {
  try {
    const postId = req.params.id;
    const currentUserId = req.user ? req.user.id : null;

    // 获取笔记基本信息
    const [rows] = await pool.execute(
      `SELECT p.*, u.nickname, u.avatar as user_avatar, u.user_id as author_account, u.id as author_auto_id, u.location, u.verified, c.name as category
       FROM posts p
       LEFT JOIN users u ON p.user_id = u.id
       LEFT JOIN categories c ON p.category_id = c.id
       WHERE p.id = ?`,
      [postId]
    );

    if (rows.length === 0) {
      return res.status(HTTP_STATUS.NOT_FOUND).json({ code: RESPONSE_CODES.NOT_FOUND, message: '笔记不存在' });
    }

    const post = rows[0];

    // 检查笔记状态权限
    // status: 0=已发布, 1=草稿, 2=待审核, 3=未过审
    // 只有已发布的笔记可以公开访问，其他状态的笔记只有作者本人可以查看
    if (post.status !== 0) {
      // 未发布的笔记，检查是否是作者本人
      if (!currentUserId || currentUserId !== post.user_id) {
        return res.status(HTTP_STATUS.NOT_FOUND).json({ code: RESPONSE_CODES.NOT_FOUND, message: '笔记不存在' });
      }
    }

    // 并发获取各类附加信息（彼此独立，减少云端往返）：媒体 / 标签 / 投票 / 音乐 / 点赞 / 收藏 / 剧集分集
    const [mediaResult, tagsResult, pollDetail, musicResult, likeResult, collectResult, episodesResult] =
      await Promise.all([
        post.type === 1
          ? pool.execute('SELECT image_url FROM post_images WHERE post_id = ?', [postId]).catch(() => [[], []])
          : post.type === 2
            ? pool.execute('SELECT video_url, cover_url FROM post_videos WHERE post_id = ?', [postId]).catch(() => [[], []])
            : Promise.resolve([[], []]),
        pool.execute(
          'SELECT t.id, t.name FROM tags t JOIN post_tags pt ON t.id = pt.tag_id WHERE pt.post_id = ?',
          [postId]
        ).catch(() => [[], []]),
        pool
          .execute('SELECT id FROM polls WHERE post_id = ?', [postId])
          .then(([pr]) => (pr.length > 0 ? buildPollDetail(pr[0].id, currentUserId) : null))
          .catch((pollErr) => {
            console.error('获取笔记投票信息失败:', pollErr);
            return null;
          }),
        post.music_id
          ? pool
              .execute(
                'SELECT id, title, author, audio_url, cover_url, duration, use_count FROM musics WHERE id = ?',
                [post.music_id.toString()]
              )
              .catch((musicErr) => {
                console.error('获取笔记音乐信息失败:', musicErr);
                return [[], []];
              })
          : Promise.resolve([[], []]),
        currentUserId
          ? pool.execute(
              'SELECT id FROM likes WHERE user_id = ? AND target_type = 1 AND target_id = ?',
              [currentUserId, postId]
            ).catch(() => [[], []])
          : Promise.resolve([[], []]),
        currentUserId
          ? pool.execute('SELECT id FROM collections WHERE user_id = ? AND post_id = ?', [currentUserId, postId]).catch(() => [[], []])
          : Promise.resolve([[], []]),
        // 剧集分集列表（仅视频帖有；表缺失/无数据时回退空数组，不影响主流程）
        post.type === 2
          ? pool
              .execute(
                'SELECT id, title, video_url, cover_url, sort FROM post_episodes WHERE post_id = ? ORDER BY sort ASC',
                [postId]
              )
              .catch(() => [[], []])
          : Promise.resolve([[], []]),
      ]);

    // 组装媒体
    const mediaRows = mediaResult[0];
    if (post.type === 1) {
      post.images = mediaRows.map((img) => img.image_url);
    } else if (post.type === 2) {
      post.videos = mediaRows;
      if (mediaRows.length > 0) {
        post.video_url = mediaRows[0].video_url;
        post.cover_url = mediaRows[0].cover_url;
      }
    }

    // 标签 / 投票 / 音乐
    post.tags = tagsResult[0];
    post.poll = pollDetail;
    post.music = musicResult[0].length > 0 ? musicResult[0][0] : null;

    // 点赞 / 收藏状态（未登录时均为 false）
    post.liked = likeResult[0].length > 0;
    post.collected = collectResult[0].length > 0;

    // 剧集分集（有则附带，无则为空数组）
    post.episodes = episodesResult[0];

    // 浏览量自增：不阻塞响应（fire-and-forget），失败仅记录日志
    if (req.query.skipViewCount !== 'true') {
      post.view_count = (post.view_count || 0) + 1;
      pool
        .execute('UPDATE posts SET view_count = view_count + 1 WHERE id = ?', [postId])
        .catch((err) => console.error('更新浏览量失败:', err));
    }


    res.json({
      code: RESPONSE_CODES.SUCCESS,
      message: 'success',
      data: post
    });
  } catch (error) {
    console.error('获取笔记详情失败:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({ code: RESPONSE_CODES.ERROR, message: ERROR_MESSAGES.INTERNAL_SERVER_ERROR });
  }
});

// 创建笔记
router.post('/', authenticateToken, async (req, res) => {
  try {
    const { title, content, category_id, images, video, tags, status, type, music_id, poll } = req.body;
    const userId = req.user.id;
    const postType = type || 1; // 默认为图文类型

    console.log('=== 创建笔记请求 ===');
    console.log('用户ID:', userId);
    console.log('标题:', title);
    console.log('内容长度:', content ? content.length : 0);
    console.log('分类ID:', category_id);
    console.log('发布类型:', postType);
    console.log('笔记状态:', status);
    console.log('图片数量:', images ? images.length : 0);
    console.log('视频数据:', video ? JSON.stringify(video) : 'null');
    console.log('标签:', tags);

    // 验证必填字段：发布时要求标题和内容，草稿时不强制要求
    if (status !== 1 && (!title || !content)) {
      console.log('❌ 验证失败: 标题或内容为空');
      return res.status(HTTP_STATUS.BAD_REQUEST).json({ code: RESPONSE_CODES.VALIDATION_ERROR, message: '发布时标题和内容不能为空' });
    }

    // 对内容进行安全过滤，防止XSS攻击
    const sanitizedContent = content ? sanitizeContent(content) : '';

    // 验证发布类型
    if (postType !== 1 && postType !== 2) {
      console.log('❌ 验证失败: 无效的发布类型');
      return res.status(HTTP_STATUS.BAD_REQUEST).json({ code: RESPONSE_CODES.VALIDATION_ERROR, message: '无效的发布类型' });
    }

    // 插入笔记
    console.log('📝 开始插入笔记到数据库...');
    const [result] = await pool.execute(
      'INSERT INTO posts (user_id, title, content, category_id, status, type, music_id) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [userId, title || '', sanitizedContent, category_id || null, (status !== undefined ? status : 2).toString(), postType, music_id || null]
    );

    const postId = result.insertId;
    console.log('✅ 笔记插入成功，ID:', postId);

    // 关联背景音乐：使用次数 +1
    if (music_id) {
      try {
        await pool.execute('UPDATE musics SET use_count = use_count + 1 WHERE id = ?', [music_id.toString()]);
      } catch (musicErr) {
        console.error('更新音乐使用次数失败:', musicErr);
      }
    }

    // 内联创建投票（若传入了 poll：{ question, options, duration_hours }）
    if (poll && poll.question && Array.isArray(poll.options) && poll.options.length >= 2) {
      try {
        const durationHours = parseInt(poll.duration_hours) || 0;
        const endsAt = durationHours > 0 ? new Date(Date.now() + durationHours * 3600000) : null;
        const [pollResult] = await pool.execute(
          'INSERT INTO polls (post_id, question, ends_at) VALUES (?, ?, ?)',
          [postId.toString(), poll.question, endsAt]
        );
        const pollId = pollResult.insertId;
        let sortOrder = 0;
        for (const opt of poll.options) {
          const text = typeof opt === 'string' ? opt : (opt && opt.content);
          if (!text) continue;
          await pool.execute(
            'INSERT INTO poll_options (poll_id, content, vote_count, sort_order) VALUES (?, ?, 0, ?)',
            [pollId.toString(), text, sortOrder.toString()]
          );
          sortOrder++;
        }
        console.log('✅ 投票创建成功，ID:', pollId);
      } catch (pollErr) {
        console.error('创建投票失败:', pollErr);
      }
    }

    // 处理图片（图文类型）
    if (postType === 1 && images && images.length > 0) {
      const validUrls = []

      // 处理所有有效的URL
      for (const imageUrl of images) {
        if (imageUrl && typeof imageUrl === 'string') {
          validUrls.push(imageUrl)
        }
      }

      // 插入所有有效的图片URL
      for (const imageUrl of validUrls) {
        await pool.execute(
          'INSERT INTO post_images (post_id, image_url) VALUES (?, ?)',
          [postId.toString(), imageUrl]
        );
      }
    }

    // 处理视频（视频类型）- 修改为单个视频
    if (postType === 2 && video && video.url && typeof video.url === 'string') {
      console.log('🎥 开始处理视频数据...');
      console.log('视频URL:', video.url);
      console.log('封面URL:', video.coverUrl);

      let coverUrl = video.coverUrl || null;
      let duration = null;

      // 如果提供了视频缓冲区，提取封面
      if (video.buffer) {
        try {
          console.log('🖼️ 开始提取视频封面...');
          const thumbnailResult = await extractVideoThumbnail(video.buffer, video.filename || 'video.mp4');
          if (thumbnailResult.success) {
            coverUrl = thumbnailResult.coverUrl;
            console.log('✅ 视频封面提取成功:', coverUrl);
          } else {
            console.log('❌ 视频封面提取失败:', thumbnailResult.error);
          }
        } catch (error) {
          console.error('❌ 处理视频封面失败:', error);
        }
      }

      // 插入视频记录
      console.log('💾 插入视频记录到数据库...');
      await pool.execute(
        'INSERT INTO post_videos (post_id, video_url, cover_url) VALUES (?, ?, ?)',
        [postId.toString(), video.url, coverUrl]
      );
      console.log('✅ 视频记录插入成功');
    }

    // 处理标签
    if (tags && tags.length > 0) {
      for (const tagName of tags) {
        // 检查标签是否存在，不存在则创建
        let [tagRows] = await pool.execute('SELECT id FROM tags WHERE name = ?', [tagName]);
        let tagId;

        if (tagRows.length === 0) {
          const [tagResult] = await pool.execute('INSERT INTO tags (name) VALUES (?)', [tagName]);
          tagId = tagResult.insertId;
        } else {
          tagId = tagRows[0].id;
        }

        // 关联笔记和标签
        await pool.execute('INSERT INTO post_tags (post_id, tag_id) VALUES (?, ?)', [postId.toString(), tagId.toString()]);

        // 更新标签使用次数
        await pool.execute('UPDATE tags SET use_count = use_count + 1 WHERE id = ?', [tagId.toString()]);
      }
    }

    // 处理@用户通知（仅在已发布状态时）
    if (status === 0 && content && hasMentions(content)) {
      const mentionedUsers = extractMentionedUsers(content);

      for (const mentionedUser of mentionedUsers) {
        try {
          // 根据小石榴号查找用户的自增ID
          const [userRows] = await pool.execute('SELECT id FROM users WHERE user_id = ?', [mentionedUser.userId]);

          if (userRows.length > 0) {
            const mentionedUserId = userRows[0].id;

            // 不给自己发通知
            if (mentionedUserId !== userId) {
              // 创建@用户通知
              const mentionNotificationData = NotificationHelper.createNotificationData({
                userId: mentionedUserId,
                senderId: userId,
                type: NotificationHelper.TYPES.MENTION,
                targetId: postId
              });

              await NotificationHelper.insertNotification(pool, mentionNotificationData);
            }
          }
        } catch (error) {
          console.error('处理@用户通知失败 - 用户: %s:', mentionedUser.userId, error);
        }
      }
    }

    console.log(`✅ 创建笔记成功 - 用户ID: ${userId}, 笔记ID: ${postId}, 类型: ${postType}`);

    // 如果笔记状态为待审核(status=2)，在audit表中添加审核记录
    if (status === 2) {
      try {
        await pool.execute(
          'INSERT INTO audit (type, target_id, status) VALUES (?, ?, ?)',
          [3, postId, 0]
        );
        console.log(`✅ 审核记录创建成功 - 笔记ID: ${postId}`);
      } catch (error) {
        console.error('❌ 创建审核记录失败:', error);
      }
    }

    // 发布成功赠送激励金币（按后台配置的金币获取方式发放，不影响主流程）
    if (status === 0) {
      try {
        await grantRuleReward(userId, postType === 2 ? 'publish_video' : 'publish_note');
      } catch (coinErr) {
        console.error('发布金币奖励发放失败:', coinErr);
      }
    }

    res.json({
      code: RESPONSE_CODES.SUCCESS,
      message: '发布成功',
      data: { id: postId }
    });
  } catch (error) {
    console.error('❌ 创建笔记失败:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({ code: RESPONSE_CODES.ERROR, message: ERROR_MESSAGES.INTERNAL_SERVER_ERROR });
  }
});

// 为已有笔记创建投票（仅作者）
router.post('/:id/poll', authenticateToken, async (req, res) => {
  try {
    const postId = req.params.id;
    const userId = req.user.id;
    const { question, options, duration_hours } = req.body;

    if (!question || !Array.isArray(options) || options.length < 2) {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({ code: RESPONSE_CODES.VALIDATION_ERROR, message: '投票问题和至少两个选项不能为空' });
    }

    const [postRows] = await pool.execute('SELECT id, user_id FROM posts WHERE id = ?', [postId]);
    if (postRows.length === 0) {
      return res.status(HTTP_STATUS.NOT_FOUND).json({ code: RESPONSE_CODES.NOT_FOUND, message: '笔记不存在' });
    }
    if (postRows[0].user_id !== userId) {
      return res.status(HTTP_STATUS.FORBIDDEN).json({ code: RESPONSE_CODES.FORBIDDEN, message: '只有作者可以添加投票' });
    }

    const [existing] = await pool.execute('SELECT id FROM polls WHERE post_id = ?', [postId]);
    if (existing.length > 0) {
      return res.status(HTTP_STATUS.CONFLICT).json({ code: RESPONSE_CODES.CONFLICT, message: '该笔记已存在投票' });
    }

    const durHours = parseInt(duration_hours) || 0;
    const endsAt = durHours > 0 ? new Date(Date.now() + durHours * 3600000) : null;
    const [pollResult] = await pool.execute(
      'INSERT INTO polls (post_id, question, ends_at) VALUES (?, ?, ?)',
      [postId.toString(), question, endsAt]
    );
    const pollId = pollResult.insertId;

    let sortOrder = 0;
    for (const opt of options) {
      const text = typeof opt === 'string' ? opt : (opt && opt.content);
      if (!text) continue;
      await pool.execute(
        'INSERT INTO poll_options (poll_id, content, vote_count, sort_order) VALUES (?, ?, 0, ?)',
        [pollId.toString(), text, sortOrder.toString()]
      );
      sortOrder++;
    }

    const detail = await buildPollDetail(pollId, userId);
    res.json({ code: RESPONSE_CODES.SUCCESS, message: '投票创建成功', data: detail });
  } catch (error) {
    console.error('创建投票失败:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({ code: RESPONSE_CODES.ERROR, message: ERROR_MESSAGES.INTERNAL_SERVER_ERROR });
  }
});

// 搜索笔记
router.get('/search', optionalAuth, async (req, res) => {
  try {
    const keyword = req.query.keyword;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;
    const currentUserId = req.user ? req.user.id : null;

    if (!keyword) {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({ code: RESPONSE_CODES.VALIDATION_ERROR, message: '请输入搜索关键词' });
    }

    console.log(`🔍 搜索笔记 - 关键词: ${keyword}, 页码: ${page}, 每页: ${limit}, 当前用户ID: ${currentUserId}`);

    // 搜索笔记：支持标题和内容搜索（只搜索已通过的笔记）
    const [rows] = await pool.execute(
      `SELECT p.*, u.nickname, u.avatar as user_avatar, u.user_id as author_account, u.id as author_auto_id, u.location, u.verified
       FROM posts p
       LEFT JOIN users u ON p.user_id = u.id
       WHERE p.status = 0 AND (p.title LIKE ? OR p.content LIKE ?)
       ORDER BY p.created_at DESC
       LIMIT ? OFFSET ?`,
      [`%${keyword}%`, `%${keyword}%`, limit.toString(), offset.toString()]
    );

    // 获取每个笔记的图片、标签和用户点赞收藏状态
    if (rows.length > 0) {
      const postIds = rows.map(p => p.id);

      // 批量获取图片信息
      const [images] = await pool.query('SELECT post_id, image_url FROM post_images WHERE post_id IN (?)', [postIds]);
      const imageMap = {};
      images.forEach(img => {
        if (!imageMap[img.post_id]) imageMap[img.post_id] = [];
        imageMap[img.post_id].push(img.image_url);
      });

      // 批量获取标签信息
      const [tags] = await pool.query(
        'SELECT pt.post_id, t.id, t.name FROM tags t JOIN post_tags pt ON t.id = pt.tag_id WHERE pt.post_id IN (?)',
        [postIds]
      );
      const tagMap = {};
      tags.forEach(t => {
        if (!tagMap[t.post_id]) tagMap[t.post_id] = [];
        tagMap[t.post_id].push({ id: t.id, name: t.name });
      });

      // 批量获取点赞状态
      let likedPostIds = new Set();
      if (currentUserId) {
        const [likes] = await pool.query(
          'SELECT target_id FROM likes WHERE user_id = ? AND target_type = 1 AND target_id IN (?)',
          [currentUserId.toString(), postIds]
        );
        likedPostIds = new Set(likes.map(l => l.target_id.toString()));
      }

      // 批量获取收藏状态
      let collectedPostIds = new Set();
      if (currentUserId) {
        const [collections] = await pool.query(
          'SELECT post_id FROM collections WHERE user_id = ? AND post_id IN (?)',
          [currentUserId.toString(), postIds]
        );
        collectedPostIds = new Set(collections.map(c => c.post_id.toString()));
      }

      // 组装数据
      for (let post of rows) {
        const postImages = imageMap[post.id] || [];
        post.images = postImages;
        post.tags = tagMap[post.id] || [];
        post.liked = likedPostIds.has(post.id.toString());
        post.collected = collectedPostIds.has(post.id.toString());
      }
    }

    // 获取总数（只统计已通过的笔记）
    const [countResult] = await pool.execute(
      `SELECT COUNT(*) as total FROM posts 
       WHERE status = 0 AND (title LIKE ? OR content LIKE ?)`,
      [`%${keyword}%`, `%${keyword}%`]
    );
    const total = countResult[0].total;

    console.log(`  搜索笔记结果 - 找到 ${total} 个笔记，当前页 ${rows.length} 个`);

    res.json({
      code: RESPONSE_CODES.SUCCESS,
      message: 'success',
      data: {
        posts: rows,
        keyword,
        pagination: {
          page,
          limit,
          total,
          pages: Math.ceil(total / limit)
        }
      }
    });
  } catch (error) {
    console.error('搜索笔记失败:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({ code: RESPONSE_CODES.ERROR, message: ERROR_MESSAGES.INTERNAL_SERVER_ERROR });
  }
});

// 获取笔记评论列表
router.get('/:id/comments', optionalAuth, async (req, res) => {
  try {
    const postId = req.params.id;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 20;
    const offset = (page - 1) * limit;
    const sort = req.query.sort || 'desc'; // 排序方式：desc（降序）或 asc（升序）
    const currentUserId = req.user ? req.user.id : null;

    console.log(`获取笔记评论列表 - 笔记ID: ${postId}, 页码: ${page}, 每页: ${limit}, 排序: ${sort}, 当前用户ID: ${currentUserId}`);

    // 并发：帖子存在性+评论总数 与 顶级评论列表（二者互不依赖）
    const orderBy = sort === 'asc' ? 'ASC' : 'DESC';
    const [postRows, commentsResult] = await Promise.all([
      pool.execute('SELECT id, comment_count FROM posts WHERE id = ?', [postId]),
      pool.execute(
        `SELECT c.*, u.nickname, u.avatar as user_avatar, u.id as user_auto_id, u.user_id as user_display_id, u.location as user_location, u.verified
         FROM comments c
         LEFT JOIN users u ON c.user_id = u.id
         WHERE c.post_id = ? AND c.parent_id IS NULL
         ORDER BY c.created_at ${orderBy}
         LIMIT ? OFFSET ?`,
        [postId, limit.toString(), offset.toString()]
      ),
    ]);

    if (postRows.length === 0) {
      return res.status(HTTP_STATUS.NOT_FOUND).json({ code: RESPONSE_CODES.NOT_FOUND, message: '笔记不存在' });
    }
    const rows = commentsResult[0];
    const total = postRows[0].comment_count;

    // 并发：点赞状态 与 子评论数量（均依赖 commentIds）
    if (rows.length > 0) {
      const commentIds = rows.map(c => c.id);
      const [likesResult, replyCountsResult] = await Promise.all([
        currentUserId
          ? pool.query(
              'SELECT target_id FROM likes WHERE user_id = ? AND target_type = 2 AND target_id IN (?)',
              [currentUserId.toString(), commentIds]
            )
          : Promise.resolve([[], []]),
        pool.query(
          'SELECT parent_id, COUNT(*) as count FROM comments WHERE parent_id IN (?) GROUP BY parent_id',
          [commentIds]
        ),
      ]);
      const likedCommentIds = new Set(likesResult[0].map(l => l.target_id.toString()));
      const replyCountMap = {};
      replyCountsResult[0].forEach(r => {
        replyCountMap[r.parent_id] = r.count;
      });

      // 组装数据
      for (let comment of rows) {
        comment.liked = likedCommentIds.has(comment.id.toString());
        comment.reply_count = replyCountMap[comment.id] || 0;
      }
    }

    res.json({
      code: RESPONSE_CODES.SUCCESS,
      message: 'success',
      data: {
        comments: rows,
        pagination: {
          page,
          limit,
          total,
          pages: Math.ceil(total / limit)
        }
      }
    });
  } catch (error) {
    console.error('获取笔记评论列表失败:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({ code: RESPONSE_CODES.ERROR, message: ERROR_MESSAGES.INTERNAL_SERVER_ERROR });
  }
});



// 收藏/取消收藏笔记
router.post('/:id/collect', authenticateToken, async (req, res) => {
  try {
    const postId = req.params.id;
    const userId = req.user.id;

    // 验证笔记是否存在
    const [postRows] = await pool.execute('SELECT id FROM posts WHERE id = ?', [postId]);
    if (postRows.length === 0) {
      return res.status(HTTP_STATUS.NOT_FOUND).json({ code: RESPONSE_CODES.NOT_FOUND, message: '笔记不存在' });
    }

    // 检查是否已经收藏
    const [existingCollection] = await pool.execute(
      'SELECT id FROM collections WHERE user_id = ? AND post_id = ?',
      [userId.toString(), postId.toString()]
    );

    if (existingCollection.length > 0) {
      // 已收藏，执行取消收藏
      await pool.execute(
        'DELETE FROM collections WHERE user_id = ? AND post_id = ?',
        [userId.toString(), postId.toString()]
      );

      // 更新笔记收藏数
      await pool.execute('UPDATE posts SET collect_count = collect_count - 1 WHERE id = ?', [postId.toString()]);

      console.log(`取消收藏成功 - 用户ID: ${userId}, 笔记ID: ${postId}`);
      res.json({ code: RESPONSE_CODES.SUCCESS, message: '取消收藏成功', data: { collected: false } });
    } else {
      // 未收藏，执行收藏
      await pool.execute(
        'INSERT INTO collections (user_id, post_id) VALUES (?, ?)',
        [userId.toString(), postId.toString()]
      );

      // 更新笔记收藏数
      await pool.execute('UPDATE posts SET collect_count = collect_count + 1 WHERE id = ?', [postId.toString()]);

      // 获取笔记作者ID，用于创建通知
      const [postResult] = await pool.execute('SELECT user_id FROM posts WHERE id = ?', [postId.toString()]);
      if (postResult.length > 0) {
        const targetUserId = postResult[0].user_id;

        // 创建通知（不给自己发通知）
        if (targetUserId && targetUserId !== userId) {
          const notificationData = NotificationHelper.createCollectPostNotification(targetUserId, userId, postId);
          const notificationResult = await NotificationHelper.insertNotification(pool, notificationData);
        }
      }

      console.log(`收藏成功 - 用户ID: ${userId}, 笔记ID: ${postId}`);
      res.json({ code: RESPONSE_CODES.SUCCESS, message: '收藏成功', data: { collected: true } });
    }
  } catch (error) {
    console.error('笔记收藏操作失败:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({ code: RESPONSE_CODES.ERROR, message: ERROR_MESSAGES.INTERNAL_SERVER_ERROR });
  }
});

// 更新笔记
router.put('/:id', authenticateToken, async (req, res) => {
  try {
    const postId = req.params.id;
    const { title, content, category_id, images, video, tags, status } = req.body;
    const userId = req.user.id;

    // 验证必填字段：如果不是草稿（status=2），则要求标题、内容和分类不能为空
    if (status !== 1 && (!title || !content || !category_id)) {
      console.log('验证失败 - 必填字段缺失:', { title, content, category_id, status });
      return res.status(HTTP_STATUS.BAD_REQUEST).json({ code: RESPONSE_CODES.VALIDATION_ERROR, message: '发布时标题、内容和分类不能为空' });
    }
    const sanitizedContent = content ? sanitizeContent(content) : '';

    // 检查笔记是否存在且属于当前用户
    const [postRows] = await pool.execute(
      'SELECT user_id, type FROM posts WHERE id = ?',
      [postId.toString()]
    );

    if (postRows.length === 0) {
      return res.status(HTTP_STATUS.NOT_FOUND).json({ code: RESPONSE_CODES.NOT_FOUND, message: '笔记不存在' });
    }

    if (postRows[0].user_id !== userId) {
      return res.status(HTTP_STATUS.FORBIDDEN).json({ code: RESPONSE_CODES.FORBIDDEN, message: '无权限修改此笔记' });
    }

    const postType = postRows[0].type;

    // 在更新之前获取原始笔记信息（用于对比@用户变化）
    const [originalPostRows] = await pool.execute('SELECT status, content FROM posts WHERE id = ?', [postId.toString()]);
    const wasOriginallyDraft = originalPostRows.length > 0 && originalPostRows[0].status === 1;
    const originalContent = originalPostRows.length > 0 ? originalPostRows[0].content : '';

    // 更新笔记基本信息
    await pool.execute(
      'UPDATE posts SET title = ?, content = ?, category_id = ?, status = ? WHERE id = ?',
      [title || '', sanitizedContent, category_id || null, (status !== undefined ? status : 2).toString(), postId.toString()]
    );

    // 根据笔记类型处理媒体文件
    if (postType === 2) {
      // 视频笔记：检查是否有视频相关更新
      const hasVideoUpdate = video !== undefined || video_url !== undefined || cover_url !== undefined;

      if (hasVideoUpdate) {
        // 获取原有视频记录
        const [oldVideoRows] = await pool.execute('SELECT video_url, cover_url FROM post_videos WHERE post_id = ?', [postId.toString()]);
        const oldVideoData = oldVideoRows.length > 0 ? oldVideoRows[0] : null;

        let newVideoUrl = null;
        let newCoverUrl = null;
        let shouldCleanupVideo = false;

        if (video && video.url) {
          // 有完整的video对象，说明是新上传的视频
          newVideoUrl = video.url;
          newCoverUrl = video.coverUrl || null;
          shouldCleanupVideo = oldVideoData && oldVideoData.video_url !== newVideoUrl;
        } else if (video_url !== undefined) {
          // 有分离的video_url字段
          newVideoUrl = video_url;
          newCoverUrl = cover_url !== undefined ? cover_url : (oldVideoData ? oldVideoData.cover_url : null);
          shouldCleanupVideo = oldVideoData && oldVideoData.video_url !== newVideoUrl;
        } else if (cover_url !== undefined && oldVideoData) {
          // 仅更新封面，保持原视频URL不变
          newVideoUrl = oldVideoData.video_url;
          newCoverUrl = cover_url;
          shouldCleanupVideo = false; // 仅更新封面，不清理视频文件
        }

        // 更新数据库记录
        if (newVideoUrl) {
          // 删除原有记录
          await pool.execute('DELETE FROM post_videos WHERE post_id = ?', [postId.toString()]);

          // 插入新记录
          await pool.execute(
            'INSERT INTO post_videos (post_id, video_url, cover_url) VALUES (?, ?, ?)',
            [postId.toString(), newVideoUrl, newCoverUrl]
          );

          // 只有在视频URL发生变化时才清理旧视频文件
          if (shouldCleanupVideo && oldVideoData) {
            const oldVideoUrls = [oldVideoData.video_url].filter(url => url);
            const oldCoverUrls = [oldVideoData.cover_url].filter(url => url && url !== newCoverUrl);

            if (oldVideoUrls.length > 0 || oldCoverUrls.length > 0) {
              // 异步清理文件，不阻塞响应
              batchCleanupFiles(oldVideoUrls, oldCoverUrls).catch(error => {
                console.error('清理废弃视频文件失败:', error);
              });
            }
          }
        }
      }
    } else {
      // 图文笔记：删除原有图片并插入新的
      await pool.execute('DELETE FROM post_images WHERE post_id = ?', [postId.toString()]);

      if (images && images.length > 0) {
        const validUrls = []

        // 处理所有有效的URL
        for (const imageUrl of images) {
          if (imageUrl && typeof imageUrl === 'string') {
            validUrls.push(imageUrl)
          }
        }

        // 插入所有有效的图片URL
        for (const imageUrl of validUrls) {
          await pool.execute(
            'INSERT INTO post_images (post_id, image_url) VALUES (?, ?)',
            [postId, imageUrl]
          );
        }
      }
    }

    // 获取原有标签列表（在删除前）
    const [oldTagsResult] = await pool.execute(
      'SELECT t.id, t.name FROM tags t JOIN post_tags pt ON t.id = pt.tag_id WHERE pt.post_id = ?',
      [postId.toString()]
    );
    const oldTags = oldTagsResult.map(tag => tag.name);
    const oldTagIds = new Map(oldTagsResult.map(tag => [tag.name, tag.id]));

    // 新标签列表
    const newTags = tags || [];

    // 找出需要删除的标签（在旧标签中但不在新标签中）
    const tagsToRemove = oldTags.filter(tagName => !newTags.includes(tagName));

    // 找出需要新增的标签（在新标签中但不在旧标签中）
    const tagsToAdd = newTags.filter(tagName => !oldTags.includes(tagName));

    // 删除原有标签关联
    await pool.execute('DELETE FROM post_tags WHERE post_id = ?', [postId.toString()]);

    // 减少已删除标签的使用次数
    for (const tagName of tagsToRemove) {
      const tagId = oldTagIds.get(tagName);
      if (tagId) {
        await pool.execute('UPDATE tags SET use_count = GREATEST(use_count - 1, 0) WHERE id = ?', [tagId]);
      }
    }

    // 处理新标签
    if (newTags.length > 0) {
      for (const tagName of newTags) {
        // 检查标签是否存在，不存在则创建
        let [tagRows] = await pool.execute('SELECT id FROM tags WHERE name = ?', [tagName]);
        let tagId;

        if (tagRows.length === 0) {
          const [tagResult] = await pool.execute('INSERT INTO tags (name) VALUES (?)', [tagName]);
          tagId = tagResult.insertId;
        } else {
          tagId = tagRows[0].id;
        }

        // 关联笔记和标签
        await pool.execute('INSERT INTO post_tags (post_id, tag_id) VALUES (?, ?)', [postId, tagId]);

        // 只对新增的标签增加使用次数（不在旧标签列表中的）
        if (tagsToAdd.includes(tagName)) {
          await pool.execute('UPDATE tags SET use_count = use_count + 1 WHERE id = ?', [tagId]);
        }
      }
    }

    // 处理@用户通知的逻辑
    if (status === 0 && content) { // 只有在已发布状态下才处理@通知
      // 获取新内容中的@用户
      const newMentionedUsers = hasMentions(content) ? extractMentionedUsers(content) : [];
      const newMentionedUserIds = new Set(newMentionedUsers.map(user => user.userId));

      // 获取原内容中的@用户（如果不是从草稿变为发布）
      let oldMentionedUserIds = new Set();
      if (!wasOriginallyDraft && originalContent && hasMentions(originalContent)) {
        const oldMentionedUsers = extractMentionedUsers(originalContent);
        oldMentionedUserIds = new Set(oldMentionedUsers.map(user => user.userId));
      }

      // 找出需要删除通知的用户（在旧列表中但不在新列表中）
      const usersToRemoveNotification = [...oldMentionedUserIds].filter(userId => !newMentionedUserIds.has(userId));

      // 找出需要添加通知的用户（在新列表中但不在旧列表中）
      const usersToAddNotification = [...newMentionedUserIds].filter(userId => !oldMentionedUserIds.has(userId));

      // 删除不再需要的@通知
      for (const mentionedUserId of usersToRemoveNotification) {
        try {
          // 根据小石榴号查找用户的自增ID
          const [userRows] = await pool.execute('SELECT id FROM users WHERE user_id = ?', [mentionedUserId]);

          if (userRows.length > 0) {
            const mentionedUserAutoId = userRows[0].id;

            // 删除该用户的@通知
            await NotificationHelper.deleteNotifications(pool, {
              type: NotificationHelper.TYPES.MENTION,
              targetId: postId,
              senderId: userId,
              userId: mentionedUserAutoId
            });
          }
        } catch (error) {
          console.error('删除@用户通知失败 - 用户: %s:', mentionedUserId, error);
        }
      }

      // 添加新的@通知
      for (const mentionedUserId of usersToAddNotification) {
        try {
          // 根据小石榴号查找用户的自增ID
          const [userRows] = await pool.execute('SELECT id FROM users WHERE user_id = ?', [mentionedUserId]);

          if (userRows.length > 0) {
            const mentionedUserAutoId = userRows[0].id;

            // 不给自己发通知
            if (mentionedUserAutoId !== userId) {
              // 创建@用户通知
              const mentionNotificationData = NotificationHelper.createNotificationData({
                userId: mentionedUserAutoId,
                senderId: userId,
                type: NotificationHelper.TYPES.MENTION,
                targetId: postId
              });

              await NotificationHelper.insertNotification(pool, mentionNotificationData);

              console.log('添加@通知 - 笔记ID: %s, 用户: %s', postId, mentionedUserId);
            }
          }
        } catch (error) {
          console.error('处理@用户通知失败 - 用户: %s:', mentionedUserId, error);
        }
      }
    }

    console.log(`更新笔记成功 - 用户ID: ${userId}, 笔记ID: ${postId}`);

    res.json({
      code: RESPONSE_CODES.SUCCESS,
      message: '更新成功',
      data: { id: postId }
    });
  } catch (error) {
    console.error('更新笔记失败:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({ code: RESPONSE_CODES.ERROR, message: ERROR_MESSAGES.INTERNAL_SERVER_ERROR });
  }
});

// 删除笔记
router.delete('/:id', authenticateToken, async (req, res) => {
  try {
    const postId = req.params.id;
    const userId = req.user.id;

    // 检查笔记是否存在且属于当前用户
    const [postRows] = await pool.execute(
      'SELECT user_id FROM posts WHERE id = ?',
      [postId.toString()]
    );

    if (postRows.length === 0) {
      return res.status(HTTP_STATUS.NOT_FOUND).json({ code: RESPONSE_CODES.NOT_FOUND, message: '笔记不存在' });
    }

    if (postRows[0].user_id !== userId) {
      return res.status(HTTP_STATUS.FORBIDDEN).json({ code: RESPONSE_CODES.FORBIDDEN, message: '无权限删除此笔记' });
    }

    // 获取笔记关联的标签，减少标签使用次数
    const [tagResult] = await pool.execute(
      'SELECT tag_id FROM post_tags WHERE post_id = ?',
      [postId.toString()]
    );

    // 减少标签使用次数
    for (const tag of tagResult) {
      await pool.execute('UPDATE tags SET use_count = GREATEST(use_count - 1, 0) WHERE id = ?', [tag.tag_id.toString()]);
    }

    // 获取笔记关联的视频文件，用于清理
    const [videoRows] = await pool.execute('SELECT video_url, cover_url FROM post_videos WHERE post_id = ?', [postId.toString()]);

    // 删除相关数据（由于外键约束，需要按顺序删除）
    await pool.execute('DELETE FROM post_images WHERE post_id = ?', [postId.toString()]);
    await pool.execute('DELETE FROM post_videos WHERE post_id = ?', [postId.toString()]);
    await pool.execute('DELETE FROM post_tags WHERE post_id = ?', [postId.toString()]);
    await pool.execute('DELETE FROM likes WHERE target_type = 1 AND target_id = ?', [postId.toString()]);
    await pool.execute('DELETE FROM collections WHERE post_id = ?', [postId.toString()]);
    await pool.execute('DELETE FROM comments WHERE post_id = ?', [postId.toString()]);
    await pool.execute('DELETE FROM notifications WHERE target_id = ?', [postId.toString()]);

    // 清理关联的视频文件
    if (videoRows.length > 0) {
      const videoUrls = videoRows.map(row => row.video_url).filter(url => url);
      const coverUrls = videoRows.map(row => row.cover_url).filter(url => url);

      // 异步清理文件，不阻塞响应
      batchCleanupFiles(videoUrls, coverUrls).catch(error => {
        console.error('清理笔记关联视频文件失败:', error);
      });
    }

    // 最后删除笔记
    await pool.execute('DELETE FROM posts WHERE id = ?', [postId.toString()]);

    console.log(`删除笔记成功 - 用户ID: ${userId}, 笔记ID: ${postId}`);

    res.json({
      code: RESPONSE_CODES.SUCCESS,
      message: '删除成功'
    });
  } catch (error) {
    console.error('删除笔记失败:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({ code: RESPONSE_CODES.ERROR, message: ERROR_MESSAGES.INTERNAL_SERVER_ERROR });
  }
});

// 取消收藏笔记
router.delete('/:id/collect', authenticateToken, async (req, res) => {
  try {
    const postId = req.params.id;
    const userId = req.user.id;

    console.log(`取消收藏 - 用户ID: ${userId}, 笔记ID: ${postId}`);

    // 删除收藏记录
    const [result] = await pool.execute(
      'DELETE FROM collections WHERE user_id = ? AND post_id = ?',
      [userId.toString(), postId.toString()]
    );

    if (result.affectedRows === 0) {
      return res.status(HTTP_STATUS.NOT_FOUND).json({ code: RESPONSE_CODES.NOT_FOUND, message: '收藏记录不存在' });
    }

    // 更新笔记收藏数
    await pool.execute('UPDATE posts SET collect_count = collect_count - 1 WHERE id = ?', [postId.toString()]);

    console.log(`取消收藏成功 - 用户ID: ${userId}, 笔记ID: ${postId}`);
    res.json({ code: RESPONSE_CODES.SUCCESS, message: '取消收藏成功', data: { collected: false } });
  } catch (error) {
    console.error('取消笔记收藏失败:', error);
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({ code: RESPONSE_CODES.ERROR, message: ERROR_MESSAGES.INTERNAL_SERVER_ERROR });
  }
});

module.exports = router;