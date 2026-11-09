/**
 * 数据库连通性探测脚本（临时）
 * 依次尝试「非 SSL -> SSL」两种连接，打印版本/当前库/账号/已有表，用于确认公网+白名单+账号是否通畅
 */
const mysql = require('mysql2/promise');
const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '..', '.env') });

async function tryConnect(ssl) {
  const conn = await mysql.createConnection({
    host: process.env.DB_HOST,
    port: process.env.DB_PORT || 3306,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    connectTimeout: 15000,
    ...(ssl ? { ssl: { rejectUnauthorized: false } } : {})
  });

  const [[v]] = await conn.query('SELECT VERSION() as v');
  const [[u]] = await conn.query('SELECT DATABASE() as db, USER() as usr, CURRENT_USER() as cu');
  const [priv] = await conn.query('SHOW GRANTS FOR CURRENT_USER()');
  const [tables] = await conn.query('SHOW TABLES');

  console.log(`\n===== 连接成功 (ssl=${ssl}) =====`);
  console.log('MySQL 版本 :', v.v);
  console.log('当前数据库 :', u.db);
  console.log('登录账号   :', u.usr, '/ ', u.cu);
  console.log('权限       :', priv.map(r => Object.values(r)[0]).join(' | '));
  const names = tables.flatMap(t => Object.values(t));
  console.log('已有表数量 :', names.length);
  if (names.length) console.log('已有表     :', names.join(', '));

  await conn.end();
  return true;
}

(async () => {
  console.log('目标:', process.env.DB_USER + '@' + process.env.DB_HOST + ':' + (process.env.DB_PORT || 3306) + '/' + process.env.DB_NAME);
  for (const ssl of [false, true]) {
    try {
      await tryConnect(ssl);
      console.log('\n>>> 可用连接方式: ssl=' + ssl);
      return;
    } catch (e) {
      console.error('\n--- 连接失败 (ssl=' + ssl + ') ---');
      console.error('  code:', e.code);
      console.error('  message:', e.message);
    }
  }
  console.log('\n>>> 两种方式都失败，请检查：端口/白名单(本机公网IP)/安全组/账号密码/是否强制SSL。');
  process.exitCode = 1;
})();
