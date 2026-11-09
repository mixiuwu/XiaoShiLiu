/**
 * 邮箱验证配置读写（后台可管理，数据库优先，未配置时回退环境变量）
 */
const { pool, email: envEmail } = require('../config/config');

function envFallback() {
  return {
    enabled: envEmail.enabled,
    host: envEmail.smtp.host,
    port: envEmail.smtp.port,
    secure: envEmail.smtp.secure,
    user: envEmail.smtp.auth.user,
    password: envEmail.smtp.auth.pass,
    fromEmail: envEmail.from.email,
    fromName: envEmail.from.name
  };
}

/**
 * 读取邮件配置。数据库无记录时使用 .env 配置。
 */
async function getEmailSettings() {
  try {
    const [rows] = await pool.execute('SELECT * FROM email_settings WHERE id = 1');
    if (rows.length === 0) {
      return envFallback();
    }

    const row = rows[0];
    const settings = {
      enabled: row.enabled === 1,
      host: row.host || '',
      port: Number(row.port) || 465,
      secure: row.secure === 1,
      user: row.user || '',
      password: row.password || '',
      fromEmail: row.from_email || row.user || '',
      fromName: row.from_name || '小石榴校园图文社区'
    };

    // 配置不完整时视为未启用，避免发信直接报错
    if (settings.enabled && (!settings.host || !settings.user || !settings.password)) {
      settings.enabled = false;
    }

    return settings;
  } catch (error) {
    console.error('读取邮件配置失败，回退环境变量:', error.message);
    return envFallback();
  }
}

/**
 * 保存邮件配置（单行 upsert）。
 * @param {Object} data
 */
async function saveEmailSettings(data) {
  const [rows] = await pool.execute('SELECT password FROM email_settings WHERE id = 1');
  const oldPassword = rows.length > 0 ? rows[0].password : '';

  const password = data.password === undefined || data.password === '' ? oldPassword : data.password;
  const fromEmail = data.fromEmail || data.user || '';

  await pool.execute(
    `INSERT INTO email_settings (id, enabled, host, port, secure, user, password, from_email, from_name)
     VALUES (1, ?, ?, ?, ?, ?, ?, ?, ?)
     ON DUPLICATE KEY UPDATE
       enabled = VALUES(enabled),
       host = VALUES(host),
       port = VALUES(port),
       secure = VALUES(secure),
       user = VALUES(user),
       password = VALUES(password),
       from_email = VALUES(from_email),
       from_name = VALUES(from_name)`,
    [
      data.enabled ? 1 : 0,
      data.host || '',
      Number(data.port) || 465,
      data.secure ? 1 : 0,
      data.user || '',
      password,
      fromEmail,
      data.fromName || '小石榴校园图文社区'
    ]
  );
}

async function isEmailEnabled() {
  const settings = await getEmailSettings();
  return settings.enabled;
}

module.exports = {
  getEmailSettings,
  saveEmailSettings,
  isEmailEnabled
};
