/**
 * 云端建表脚本（针对 flash_aodde_com 这类共享/托管单库环境）
 *
 * 与 init-database.sql 的差异：
 * - 不含 CREATE DATABASE / USE（很多托管账号没有建库权限，只能往已存在的库里建表）
 * - 不依赖存储过程，改在 JS 里用 information_schema 做幂等判断
 * - 直接连接 .env 中配置的目标库执行
 *
 * 用法：node scripts/deploy-cloud-schema.js
 */
const fs = require('fs');
const path = require('path');
const mysql = require('mysql2/promise');
require('dotenv').config({ path: path.resolve(__dirname, '..', '.env') });

const DB = process.env.DB_NAME;

function buildBaseSql(rawSql) {
  return rawSql
    // 移除建库/切库语句（直接连到目标库即可）
    .replace(/^\s*CREATE\s+DATABASE[^;]*;?\s*$/im, '')
    .replace(/^\s*USE\s+[^;]*;\s*$/im, '')
    // 移除唯一那条非幂等的外键 ALTER（改由本脚本幂等处理）
    .replace(/^\s*ALTER\s+TABLE\s+`posts`\s+ADD\s+CONSTRAINT\s+`fk_posts_music`[^;]*;?\s*$/im, '')
    // 末尾统计 SQL 里写死的 schema 名替换为当前库
    .replace(/'xiaoshiliu'/g, `'${DB}'`)
    .trim();
}

// 移除依赖存储过程的动态 ALTER（本环境可能无建存储过程权限；对应列/外键已在下方幂等补齐）
function stripProcedures(sql) {
  return sql
    .replace(/CREATE\s+PROCEDURE[\s\S]*?\nEND;\s*/gim, '')
    .replace(/DROP\s+PROCEDURE\s+IF\s+EXISTS\s+[`\w]+;\s*/gim, '')
    .replace(/CALL\s+add_[^;]*;\s*/gim, '');
}

async function runSqlFile(conn, fileName, label) {
  const rawSql = fs.readFileSync(path.resolve(__dirname, fileName), 'utf8');
  const sql = stripProcedures(buildBaseSql(rawSql));
  console.log(label);
  await conn.query(sql);
}

async function columnExists(conn, table, column) {
  const [rows] = await conn.query(
    `SELECT 1 FROM information_schema.COLUMNS
     WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ? AND COLUMN_NAME = ? LIMIT 1`,
    [DB, table, column]
  );
  return rows.length > 0;
}

async function constraintExists(conn, table, constraint) {
  const [rows] = await conn.query(
    `SELECT 1 FROM information_schema.TABLE_CONSTRAINTS
     WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ? AND CONSTRAINT_NAME = ? LIMIT 1`,
    [DB, table, constraint]
  );
  return rows.length > 0;
}

async function main() {
  console.log(`连接目标库：${process.env.DB_USER}@${process.env.DB_HOST}:${process.env.DB_PORT || 3306}/${DB}`);

  const conn = await mysql.createConnection({
    host: process.env.DB_HOST,
    port: process.env.DB_PORT || 3306,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: DB,
    connectTimeout: 20000,
    multipleStatements: true,
    charset: 'utf8mb4'
  });

  // 1) 执行基础建表 + 扩展建表（幂等：CREATE IF NOT EXISTS + INSERT IGNORE）
  await runSqlFile(conn, 'init-database.sql', '执行建表脚本 init-database.sql ...');
  await runSqlFile(conn, 'migrate-ui-features.sql', '执行扩展脚本 migrate-ui-features.sql ...');
  console.log('✅ 基础表 + 扩展表 + 种子数据完成');

  // 2) 幂等补齐 posts.music_id（若历史库缺失）
  if (!(await columnExists(conn, 'posts', 'music_id'))) {
    await conn.query('ALTER TABLE `posts` ADD COLUMN `music_id` bigint(20) DEFAULT NULL COMMENT \'关联音乐ID\'');
    console.log('✅ 已补齐列 posts.music_id');
  }
  // 3) 幂等补齐 users.is_vip
  if (!(await columnExists(conn, 'users', 'is_vip'))) {
    await conn.query("ALTER TABLE `users` ADD COLUMN `is_vip` tinyint(1) DEFAULT 0 COMMENT '是否VIP'");
    console.log('✅ 已补齐列 users.is_vip');
  }
  // 4) 幂等添加 posts -> musics 外键
  if (!(await constraintExists(conn, 'posts', 'fk_posts_music'))) {
    await conn.query('ALTER TABLE `posts` ADD CONSTRAINT `fk_posts_music` FOREIGN KEY (`music_id`) REFERENCES `musics` (`id`) ON DELETE SET NULL');
    console.log('✅ 已添加外键 fk_posts_music');
  }

  // 5) 汇总
  const [tables] = await conn.query(
    'SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA = ? ORDER BY TABLE_NAME',
    [DB]
  );
  console.log(`\n当前库共有 ${tables.length} 张表：`);
  console.log(tables.map(t => Object.values(t)[0]).join(', '));

  const expect = ['musics', 'polls', 'poll_options', 'poll_votes', 'danmaku', 'search_logs',
    'user_wallets', 'coin_transactions', 'vip_plans', 'user_vip', 'products', 'orders'];
  const names = tables.map(t => Object.values(t)[0]);
  const missing = expect.filter(t => !names.includes(t));
  if (missing.length) {
    console.log('\n⚠️ 以下扩展表缺失（请检查）:', missing.join(', '));
  } else {
    console.log('\n🎉 全部 12 张扩展表均已就绪，可以启动后端 node app.js');
  }

  await conn.end();
}

main().catch(err => {
  console.error('\n❌ 部署失败:', err.code || '', err.message);
  if (err.code === 'ETIMEDOUT' || err.code === 'ECONNREFUSED') {
    console.error('提示：数据库端口不可达，请先在云端安全组/防火墙放行 3306，并允许你的公网IP远程访问。');
  }
  process.exitCode = 1;
});
