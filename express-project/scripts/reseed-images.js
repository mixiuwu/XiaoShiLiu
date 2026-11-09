// 图片源重灌脚本：把数据库中失效的 tc.alcy.cc 图片链接（头像 / 笔记图片 / 视频封面）
// 批量替换为可公网访问的稳定图床：
//   - 头像   → https://api.dicebear.com/7.x/avataaars/png?seed=<小石榴号>   (PNG 卡通头像)
//   - 笔记图 → https://picsum.photos/seed/p<id>/800/600                     (JPEG 随机风景图)
//   - 视频封面→ https://picsum.photos/seed/v<post_id>/720/1280               (JPEG 竖版封面)
// 说明：视频流本身(video_url)不动，仅换封面。seed 取自各自主键，结果确定、可重复执行。
// 用法：node scripts/reseed-images.js
const { pool } = require('../config/config');

const AVATAR_STYLE = 'avataaars'; // dicebear 风格
const POST_IMG_SIZE = '800/600'; // 笔记图尺寸
const COVER_SIZE = '720/1280'; // 视频封面尺寸（竖版）

function avatarUrl(seed) {
  return `https://api.dicebear.com/7.x/${AVATAR_STYLE}/png?seed=${encodeURIComponent(seed)}&size=200`;
}
function postImgUrl(id) {
  return `https://picsum.photos/seed/p${id}/${POST_IMG_SIZE}`;
}
function coverUrl(postId) {
  return `https://picsum.photos/seed/v${postId}/${COVER_SIZE}`;
}

async function reseedAvatars() {
  const [rows] = await pool.query(
    "SELECT id, user_id, avatar FROM users WHERE avatar IS NOT NULL AND avatar LIKE '%tc.alcy.cc%'"
  );
  console.log(`发现 ${rows.length} 个失效头像，开始替换...`);
  let n = 0;
  for (const u of rows) {
    // 用小石榴号(user_id)作 seed；缺失则退回自增 id，保证稳定且多样
    const seed = (u.user_id && String(u.user_id)) || `uid${u.id}`;
    await pool.execute('UPDATE users SET avatar = ? WHERE id = ?', [avatarUrl(seed), u.id]);
    n++;
  }
  console.log(`  ✔ 已更新头像 ${n} 个`);
}

async function reseedPostImages() {
  const [rows] = await pool.query(
    "SELECT id FROM post_images WHERE image_url LIKE '%tc.alcy.cc%'"
  );
  console.log(`发现 ${rows.length} 张失效笔记图片，开始替换...`);
  let n = 0;
  for (const r of rows) {
    await pool.execute('UPDATE post_images SET image_url = ? WHERE id = ?', [postImgUrl(r.id), r.id]);
    n++;
  }
  console.log(`  ✔ 已更新笔记图片 ${n} 张`);
}

async function reseedVideoCovers() {
  const [rows] = await pool.query(
    "SELECT id, post_id FROM post_videos WHERE cover_url LIKE '%tc.alcy.cc%'"
  );
  console.log(`发现 ${rows.length} 张失效视频封面，开始替换...`);
  let n = 0;
  for (const r of rows) {
    await pool.execute('UPDATE post_videos SET cover_url = ? WHERE id = ?', [coverUrl(r.post_id), r.id]);
    n++;
  }
  console.log(`  ✔ 已更新视频封面 ${n} 张`);
}

async function main() {
  console.log('=== 图片源重灌开始（tc.alcy.cc → dicebear/picsum）===\n');
  await reseedAvatars();
  await reseedPostImages();
  await reseedVideoCovers();

  // 残留统计：确认没有漏网的 tc.alcy.cc
  const [left] = await pool.query(
    `SELECT
      (SELECT COUNT(*) FROM users WHERE avatar LIKE '%tc.alcy.cc%') AS av,
      (SELECT COUNT(*) FROM post_images WHERE image_url LIKE '%tc.alcy.cc%') AS pi,
      (SELECT COUNT(*) FROM post_videos WHERE cover_url LIKE '%tc.alcy.cc%') AS vc`
  );
  const s = left[0];
  console.log(`\n残留 tc.alcy.cc：头像 ${s.av} / 笔记图 ${s.pi} / 视频封面 ${s.vc}`);
  console.log('\n=== 重灌完成，回到 App 下拉刷新或重进页面即可看到真实图片 ===');
  await pool.end();
}

main().catch((err) => {
  console.error('重灌脚本执行失败：', err);
  process.exit(1);
});
