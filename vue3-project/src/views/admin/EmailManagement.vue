<template>
  <div class="email-management">
    <div class="page-intro">
      <h3>邮箱验证管理</h3>
      <p>开启后，用户注册、绑定邮箱与找回密码都需要先通过邮箱验证码验证。配置使用 SMTP 发信，保存后立即生效，无需重启服务。</p>
    </div>

    <div class="settings-card">
      <div class="card-header">
        <div>
          <h4>邮件服务状态</h4>
          <p class="sub-text">仅当配置完整且开关打开时，前台才会显示邮箱验证入口。</p>
        </div>
        <label class="switch">
          <input v-model="form.enabled" type="checkbox" />
          <span class="slider"></span>
        </label>
      </div>

      <div class="status-row">
        <span class="status-tag" :class="statusClass">{{ statusText }}</span>
        <span v-if="settings.configured" class="hint-text">SMTP 账号已配置</span>
        <span v-else class="hint-text warning">尚未填写 SMTP 账号与密码</span>
      </div>

      <div class="form-grid">
        <div class="form-item">
          <label>SMTP 服务器</label>
          <input v-model.trim="form.host" type="text" placeholder="如 smtp.qq.com" />
        </div>
        <div class="form-item">
          <label>端口</label>
          <input v-model.number="form.port" type="number" placeholder="465 / 587" />
        </div>
        <div class="form-item">
          <label>加密方式</label>
          <select v-model="form.secure">
            <option :value="true">SSL（常用 465 端口）</option>
            <option :value="false">STARTTLS / 普通（常用 587 端口）</option>
          </select>
        </div>
        <div class="form-item">
          <label>SMTP 账号</label>
          <input v-model.trim="form.user" type="text" placeholder="发信邮箱账号" />
        </div>
        <div class="form-item span-2">
          <label>SMTP 密码 / 授权码</label>
          <input v-model="form.password" type="password" autocomplete="new-password"
            :placeholder="settings.hasPassword ? '已设置，留空则不修改' : 'QQ 邮箱需填写授权码'" />
        </div>
        <div class="form-item">
          <label>发件人邮箱</label>
          <input v-model.trim="form.fromEmail" type="text" placeholder="留空则使用 SMTP 账号" />
        </div>
        <div class="form-item">
          <label>发件人名称</label>
          <input v-model.trim="form.fromName" type="text" maxlength="100" placeholder="小石榴校园图文社区" />
        </div>
      </div>

      <div class="actions">
        <button type="button" class="primary-btn" :disabled="saving" @click="save">
          {{ saving ? '保存中...' : '保存配置' }}
        </button>
        <span class="hint-text">修改后对后续发信立即生效</span>
      </div>
    </div>

    <div class="settings-card">
      <div class="card-header">
        <div>
          <h4>发送测试邮件</h4>
          <p class="sub-text">使用已保存的 SMTP 配置发送一封测试邮件，用于确认配置是否正确。</p>
        </div>
      </div>
      <div class="test-row">
        <input v-model.trim="testEmail" type="text" placeholder="输入接收测试邮件的邮箱" />
        <button type="button" class="primary-btn" :disabled="testing" @click="sendTest">
          {{ testing ? '发送中...' : '发送测试邮件' }}
        </button>
      </div>
    </div>

    <div v-if="message.text" class="message" :class="message.type">{{ message.text }}</div>
  </div>
</template>

<script setup>
import { computed, onMounted, reactive, ref } from 'vue'
import { adminApi } from '@/api'

const settings = reactive({
  configured: false,
  hasPassword: false
})

const form = reactive({
  enabled: false,
  host: '',
  port: 465,
  secure: true,
  user: '',
  password: '',
  fromEmail: '',
  fromName: ''
})

const loading = ref(false)
const saving = ref(false)
const testing = ref(false)
const testEmail = ref('')
const message = reactive({ text: '', type: 'success' })

const statusText = computed(() => {
  if (form.enabled && settings.configured) return '已启用'
  if (form.enabled && !settings.configured) return '配置不完整'
  return '已关闭'
})

const statusClass = computed(() => {
  if (form.enabled && settings.configured) return 'ok'
  if (form.enabled) return 'warn'
  return 'off'
})

function showMessage(text, type = 'success') {
  message.text = text
  message.type = type
  if (type === 'success') {
    setTimeout(() => {
      message.text = ''
    }, 3000)
  }
}

async function loadSettings() {
  loading.value = true
  try {
    const response = await adminApi.getEmailSettings()
    if (!response.success) {
      showMessage(response.message || '获取邮箱配置失败', 'error')
      return
    }
    const data = response.data || {}
    settings.configured = Boolean(data.configured)
    settings.hasPassword = Boolean(data.hasPassword)
    form.enabled = Boolean(data.enabled)
    form.host = data.host || ''
    form.port = data.port || 465
    form.secure = Boolean(data.secure)
    form.user = data.user || ''
    form.password = ''
    form.fromEmail = data.fromEmail || ''
    form.fromName = data.fromName || ''

    if (!testEmail.value) {
      testEmail.value = data.fromEmail || data.user || ''
    }
  } catch (error) {
    console.error('获取邮箱配置失败:', error)
    showMessage('获取邮箱配置失败', 'error')
  } finally {
    loading.value = false
  }
}

async function save() {
  if (form.enabled && (!form.host || !form.user)) {
    showMessage('启用邮箱验证前请填写 SMTP 服务器与账号', 'error')
    return
  }

  saving.value = true
  try {
    const response = await adminApi.saveEmailSettings({
      enabled: form.enabled,
      host: form.host,
      port: Number(form.port) || 465,
      secure: form.secure,
      user: form.user,
      password: form.password,
      fromEmail: form.fromEmail,
      fromName: form.fromName
    })
    if (response.success) {
      showMessage('邮箱配置已保存')
      form.password = ''
      await loadSettings()
    } else {
      showMessage(response.message || '保存失败', 'error')
    }
  } catch (error) {
    console.error('保存邮箱配置失败:', error)
    showMessage('保存邮箱配置失败', 'error')
  } finally {
    saving.value = false
  }
}

async function sendTest() {
  if (!testEmail.value) {
    showMessage('请输入接收测试邮件的邮箱', 'error')
    return
  }

  testing.value = true
  try {
    const response = await adminApi.testEmailSettings({ to: testEmail.value })
    if (response.success) {
      showMessage('测试邮件已发送，请查收')
    } else {
      showMessage(response.message || '测试邮件发送失败', 'error')
    }
  } catch (error) {
    console.error('发送测试邮件失败:', error)
    showMessage('测试邮件发送失败，请检查 SMTP 配置', 'error')
  } finally {
    testing.value = false
  }
}

onMounted(loadSettings)
</script>

<style scoped>
.email-management {
  padding: 0;
}

.page-intro {
  margin-bottom: 16px;
  padding: 16px 20px;
  border-radius: 12px;
  background: var(--bg-color-secondary, #f7f8fa);
}

.page-intro h3 {
  margin: 0 0 6px;
  font-size: 16px;
  color: var(--text-color-primary);
}

.page-intro p {
  margin: 0;
  font-size: 13px;
  line-height: 1.7;
  color: var(--text-color-secondary, #666);
}

.settings-card {
  margin-bottom: 16px;
  padding: 20px;
  border: 1px solid var(--border-color-primary, #ebeef5);
  border-radius: 12px;
  background: var(--bg-color-primary, #fff);
}

.card-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 16px;
  margin-bottom: 12px;
}

.card-header h4 {
  margin: 0 0 4px;
  font-size: 15px;
  color: var(--text-color-primary);
}

.sub-text {
  margin: 0;
  font-size: 12px;
  color: var(--text-color-secondary, #888);
  line-height: 1.6;
}

.status-row {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 16px;
}

.status-tag {
  padding: 2px 10px;
  border-radius: 999px;
  font-size: 12px;
}

.status-tag.ok {
  color: #16a34a;
  background: rgba(22, 163, 74, 0.12);
}

.status-tag.warn {
  color: #d97706;
  background: rgba(217, 119, 6, 0.12);
}

.status-tag.off {
  color: #9ca3af;
  background: rgba(156, 163, 175, 0.15);
}

.form-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 14px 18px;
}

.form-item {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.form-item.span-2 {
  grid-column: span 2;
}

.form-item label {
  font-size: 13px;
  color: var(--text-color-secondary, #666);
}

.form-item input,
.form-item select,
.test-row input {
  height: 38px;
  padding: 0 12px;
  border: 1px solid var(--border-color-primary, #dcdfe6);
  border-radius: 8px;
  background: var(--bg-color-primary, #fff);
  color: var(--text-color-primary);
  font-size: 13px;
  outline: none;
  transition: border-color 0.2s ease;
}

.form-item input:focus,
.form-item select:focus,
.test-row input:focus {
  border-color: var(--primary-color, #409eff);
}

.actions {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-top: 18px;
}

.primary-btn {
  height: 38px;
  padding: 0 18px;
  border: none;
  border-radius: 8px;
  background: var(--primary-color, #409eff);
  color: #fff;
  font-size: 13px;
  cursor: pointer;
  transition: opacity 0.2s ease;
}

.primary-btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.hint-text {
  font-size: 12px;
  color: var(--text-color-secondary, #888);
}

.hint-text.warning {
  color: #d97706;
}

.test-row {
  display: flex;
  gap: 12px;
}

.test-row input {
  flex: 1;
}

.switch {
  position: relative;
  display: inline-block;
  width: 46px;
  height: 24px;
  flex-shrink: 0;
}

.switch input {
  opacity: 0;
  width: 0;
  height: 0;
}

.slider {
  position: absolute;
  inset: 0;
  border-radius: 999px;
  background: #cbd5e1;
  cursor: pointer;
  transition: background 0.2s ease;
}

.slider::before {
  content: '';
  position: absolute;
  top: 3px;
  left: 3px;
  width: 18px;
  height: 18px;
  border-radius: 50%;
  background: #fff;
  transition: transform 0.2s ease;
}

.switch input:checked + .slider {
  background: var(--primary-color, #409eff);
}

.switch input:checked + .slider::before {
  transform: translateX(22px);
}

.message {
  padding: 10px 14px;
  border-radius: 8px;
  font-size: 13px;
}

.message.success {
  color: #16a34a;
  background: rgba(22, 163, 74, 0.1);
}

.message.error {
  color: #dc2626;
  background: rgba(220, 38, 38, 0.1);
}

@media (max-width: 768px) {
  .form-grid {
    grid-template-columns: 1fr;
  }

  .form-item.span-2 {
    grid-column: span 1;
  }

  .test-row {
    flex-direction: column;
  }
}
</style>
