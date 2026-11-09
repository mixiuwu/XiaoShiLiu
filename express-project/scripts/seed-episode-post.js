// 剧集帖种子脚本：创建一条 type=2、status=0 的「剧集」帖（归入首页推荐流），
// 主视频取第 01 集，并在 post_episodes 表写入 37 条分集（第01集~第37集）。
// 幂等：重复执行会先删除同名旧帖再重建。
// 用法：node scripts/seed-episode-post.js
const { pool } = require('../config/config');

const TITLE = '剧集合集（示例）';

// 37 个分集播放地址（按用户给定出现顺序，重新编号第01~第37集）。
const EPISODE_URLS = [
  'https://svip.xgplay17.com/2026-07-15/31410_GqemisZ3lT17B6e2Nn/index.m3u8',
  'https://svip.xgplay17.com/2026-07-15/31412_X7U7yZOF1YAHMNf0_H/index.m3u8',
  'https://svip.xgplay17.com/2026-07-15/31413_b-cAHOarT2oCxQ2PYE/index.m3u8',
  'https://svip.xgplay20.com/2026-07-16/42847_-FOgAIuHC00Ismnr0S/index.m3u8',
  'https://svip.xgplay17.com/2026-07-22/32301_ir4vVqrwhPuukr8nhC/index.m3u8',
  'https://svip.xgplay17.com/2026-07-23/32478_Fon_TH4w3R1ysbHuFf/index.m3u8',
  'https://svip.xgplay17.com/2026-07-29/33176_xjROLi6CIUTaKn5lqz/index.m3u8',
  'https://svip.xgplay17.com/2026-08-05/34126_pXxRcaCfLHNe6uDuYP/index.m3u8',
  'https://svip.xgplay17.com/2026-08-05/34121_7fUR4Q5RCZboNkPU69/index.m3u8',
  'https://svip.xgplay17.com/2026-08-06/34264_AZ3xFpHfZ9KOzGd1MY/index.m3u8',
  'https://svip.xgplay17.com/2026-08-12/35113_DWrCpoyYKxrKCK3edE/index.m3u8',
  'https://svip.xgplay17.com/2026-08-13/35246_9hVuxc4GOZI558_Lpx/index.m3u8',
  'https://svip.xgplay20.com/2026-08-19/45376_9C3HXeCN1bdBQC50-L/index.m3u8',
  'https://svip.xgplay17.com/2026-08-20/36225_zHfnl3cvN_TEvsmsEA/index.m3u8',
  'https://svip.xgplay20.com/2026-08-26/46467_Avun1zBQEjOL1mX285/index.m3u8',
  'https://svip.xgplay20.com/2026-08-27/46611_1XgGV-GfY-4OwE6UFj/index.m3u8',
  'https://svip.xgplay17.com/2026-09-02/37748_OwSAi1Upmu2BqdM8wT/index.m3u8',
  'https://svip.xgplay17.com/2026-09-03/37885_gHlTme5uqsDAQgKIn3/index.m3u8',
  'https://svip.xgplay17.com/2026-09-09/38616_KB2FCBFZTuSGS1Cs76/index.m3u8',
  'https://svip.xgplay17.com/2026-09-10/38767_0k9z0fxDWg3I2GxrBq/index.m3u8',
  'https://svip.xgplay17.com/2026-09-16/39517_enssgAem6Bzs18VuXj/index.m3u8',
  'https://svip.xgplay17.com/2026-09-17/39618_Ekgo0InJ_dNcqLGndD/index.m3u8',
  'https://svip.xgplay17.com/2026-09-23/40372_JW6gz2_W5ww3DP7soj/index.m3u8',
  'https://svip.xgplay17.com/2026-09-24/40490_1RGgzEerC2-XyAhcyP/index.m3u8',
  'https://svip.xgplay17.com/2026-09-30/41238_r-a5qTPs87w9hv7jwx/index.m3u8',
  'https://svip.xgplay17.com/2026-10-01/41393_aYe0DCGjtAHr5aw9BA/index.m3u8',
  'https://svip.xgplay17.com/2026-10-07/42282_pZvozEvybJjrtXv83X/index.m3u8',
  'https://svip.xgplay17.com/2026-10-08/42390_H1-Oy1J28WQFYxL5wh/index.m3u8',
  'https://svip.xgplay17.com/2026-10-14/43089_7rpPZeIc5bnJobpeT1/index.m3u8',
  'https://svip.xgplay17.com/2026-10-15/43242_PsxOC9jtHwV5PXT4QB/index.m3u8',
  'https://svip.xgplay17.com/2026-10-21/44114_Xj5y0rKNkh6AExOPDG/index.m3u8',
  'https://svip.xgplay17.com/2026-10-22/44214_8aDMLP8k1jhn6biJmJ/index.m3u8',
  'https://svip.xgplay17.com/2026-10-28/44992_6cxr1-EaWLzrsjPNVk/index.m3u8',
  'https://svip.xgplay17.com/2026-10-29/45117_AYnls3VLekNnn6TEV1/index.m3u8',
  'https://svip.xgplay17.com/2026-11-04/45950_62EBNidOtwkOr5IFDE/index.m3u8',
  'https://svip.xgplay17.com/2026-11-04/45951_EHTXjR_RITKGK4KduM/index.m3u8',
  'https://svip.xgplay17.com/2026-11-05/46049_L2YKwfMrT3k_k3Bjyn/index.m3u8',
];

async function main() {
  // 建表（幂等），确保在未跑新版 init-database 的线上库上也能落库。
  await pool.query(`CREATE TABLE IF NOT EXISTS \`post_episodes\` (
    \`id\` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '分集ID',
    \`post_id\` bigint(20) NOT NULL COMMENT '所属剧集笔记ID',
    \`title\` varchar(200) NOT NULL COMMENT '分集标题（如 第01集）',
    \`video_url\` varchar(500) NOT NULL COMMENT '分集播放地址（m3u8/mp4）',
    \`cover_url\` varchar(500) DEFAULT NULL COMMENT '分集封面URL（可空，回退帖子封面）',
    \`sort\` int(11) NOT NULL DEFAULT 0 COMMENT '集序，升序排列',
    PRIMARY KEY (\`id\`),
    KEY \`idx_post_id_sort\` (\`post_id\`, \`sort\`),
    CONSTRAINT \`post_episodes_ibfk_1\` FOREIGN KEY (\`post_id\`) REFERENCES \`posts\` (\`id\`) ON DELETE CASCADE
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='笔记剧集分集表'`);

  // 幂等：删除同名旧剧集帖（CASCADE 会一并清理 post_videos / post_episodes）。
  await pool.execute('DELETE FROM posts WHERE title = ? AND type = 2', [TITLE]);

  // 取一个已发布内容的现有用户作为作者（优先 user004，回退任意用户）。
  const [users] = await pool.query(
    `SELECT p.user_id AS uid FROM posts p
       JOIN users u ON u.id = p.user_id
      WHERE u.user_id = 'user004' LIMIT 1`
  );
  let userId = users.length ? users[0].uid : null;
  if (!userId) {
    const [fallback] = await pool.query('SELECT id AS uid FROM users ORDER BY id LIMIT 1');
    if (!fallback.length) {
      console.error('users 表为空，无法创建剧集帖。');
      process.exit(1);
    }
    userId = fallback[0].uid;
  }

  const content = `${TITLE}。全集共 ${EPISODE_URLS.length} 集，点击右侧「选集」切换播放。#小石榴 #推荐`;
  // 高浏览量确保进入推荐算法（score=view*0.7+新鲜度*0.3）前 20%，稳定出现在首页第一页。
  const viewCount = 300000;
  const likeCount = 42000;

  const [res] = await pool.execute(
    'INSERT INTO posts (user_id, title, content, category_id, type, view_count, like_count, collect_count, comment_count, created_at, status) VALUES (?, ?, ?, NULL, 2, ?, ?, 0, 0, NOW(), 0)',
    [userId.toString(), TITLE, content, viewCount.toString(), likeCount.toString()]
  );
  const postId = res.insertId;

  const coverUrl = `https://picsum.photos/seed/episode${postId}/720/1280`;
  // 主视频取第 01 集：Feed 与详情页初始播放用。
  await pool.execute('INSERT INTO post_videos (post_id, cover_url, video_url) VALUES (?, ?, ?)', [
    postId.toString(),
    coverUrl,
    EPISODE_URLS[0],
  ]);

  for (let i = 0; i < EPISODE_URLS.length; i++) {
    const title = `第${String(i + 1).padStart(2, '0')}集`;
    await pool.execute(
      'INSERT INTO post_episodes (post_id, title, video_url, cover_url, sort) VALUES (?, ?, ?, ?, ?)',
      [postId.toString(), title, EPISODE_URLS[i], coverUrl, String(i + 1)]
    );
  }

  console.log(`完成：剧集帖 #${postId}「${TITLE}」已创建，含 ${EPISODE_URLS.length} 集。`);
  await pool.end();
}

main().catch((err) => {
  console.error('剧集帖种子脚本执行失败：', err);
  process.exit(1);
});
