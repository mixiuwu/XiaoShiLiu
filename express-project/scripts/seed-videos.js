// 视频笔记种子脚本：向数据库插入若干 type=2（视频）、status=0（已发布）的帖子，
// 并写入 post_videos（video_url + cover_url），用于填充首页竖滑推荐流。
// 用法：node scripts/seed-videos.js [数量，默认20]
const fs = require('fs');
const path = require('path');
const { pool } = require('../config/config');

// 已验证可公网访问的示例视频（本机网络下可达，模拟器同网络）。
const VIDEO_URLS = [
  'https://www.w3schools.com/html/mov_bbb.mp4',
  'https://www.w3schools.com/html/movie.mp4',
  'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4',
  'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/friday.mp4',
  'https://mdn.github.io/shared-assets/videos/flower.mp4',
  'https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/360/Big_Buck_Bunny_360_10s_1MB.mp4',
];

const TITLES = [
  '今日份快乐，看完心情都变好了',
  '这个操作太秀了，忍不住分享',
  '记录生活里的小确幸',
  '第一次尝试，欢迎大家指点',
  '治愈系瞬间，建议戴上耳机',
  '这波操作我给满分',
  '生活需要一点仪式感',
  '没想到还能这样玩',
  '随手一拍都是大片',
  '坚持第30天，变化真的很大',
];

function rand(n) {
  return Math.floor(Math.random() * n);
}

function pick(arr) {
  return arr[rand(arr.length)];
}

async function main() {
  const count = parseInt(process.argv[2]) || 20;

  // 封面统一用可公网访问的 picsum 图床（按 postId 生成，稳定多样），
  // 不再读取失效的 tc.alcy.cc 链接文件。

  // 取现有用户
  const [users] = await pool.query('SELECT id FROM users ORDER BY id LIMIT 200');
  if (users.length === 0) {
    console.error('users 表为空，请先运行 generate-data 生成用户。');
    process.exit(1);
  }
  const userIds = users.map((u) => u.id);

  console.log(`准备插入 ${count} 条视频笔记，候选作者 ${userIds.length} 人...`);

  let inserted = 0;
  for (let i = 0; i < count; i++) {
    const userId = pick(userIds);
    const title = TITLES[i % TITLES.length];
    const content = `${title}。#小石榴 #推荐`;
    const videoUrl = VIDEO_URLS[i % VIDEO_URLS.length];
    const viewCount = 50 + rand(5000);
    const likeCount = rand(Math.max(1, Math.floor(viewCount / 5)));

    const [res] = await pool.execute(
      'INSERT INTO posts (user_id, title, content, category_id, type, view_count, like_count, collect_count, comment_count, created_at, status) VALUES (?, ?, ?, NULL, 2, ?, ?, 0, 0, NOW(), 0)',
      [
        userId.toString(),
        title,
        content,
        viewCount.toString(),
        likeCount.toString(),
      ]
    );
    const postId = res.insertId;

    // 竖版封面，按 postId 生成稳定 seed
    const coverUrl = `https://picsum.photos/seed/v${postId}/720/1280`;
    await pool.execute(
      'INSERT INTO post_videos (post_id, cover_url, video_url) VALUES (?, ?, ?)',
      [postId.toString(), coverUrl, videoUrl]
    );
    inserted++;
  }

  console.log(`完成：已插入 ${inserted} 条视频笔记。`);
  await pool.end();
}

main().catch((err) => {
  console.error('种子脚本执行失败：', err);
  process.exit(1);
});
