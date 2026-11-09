<template>
  <div class="wallet-page">
    <div class="wallet-container">
      <router-link class="back-link" to="/user">← 返回个人主页</router-link>

      <div v-if="!userStore.isLoggedIn" class="state-tip">请先登录后查看钱包</div>

      <template v-else>
        <div class="balance-card">
          <div class="balance-main">
            <p class="balance-label">金币余额</p>
            <h2 class="balance-value">{{ balance }}</h2>
            <p class="balance-hint">
              可提现 ¥{{ withdrawable }} · {{ coinPerYuan }} 金币 = 1 元
            </p>
          </div>
          <button class="withdraw-btn" @click="openWithdraw">提现</button>
        </div>

        <div class="earn-section" v-if="earnRules.length > 0">
          <div class="section-header">
            <h3>金币任务</h3>
            <span class="section-count">完成任务即可获得金币</span>
          </div>
          <ul class="earn-list">
            <li v-for="rule in earnRules" :key="rule.code" class="earn-item">
              <div class="earn-info">
                <span class="earn-name">{{ rule.name }}</span>
                <span class="earn-desc">{{ rule.description || '' }}</span>
                <span class="earn-limit">
                  每日{{ rule.daily_limit > 0 ? `${rule.daily_limit} 次` : '不限次数' }}
                  <template v-if="rule.daily_limit > 0"> · 今日剩余 {{ rule.remaining }} 次</template>
                </span>
              </div>
              <div class="earn-right">
                <span class="earn-reward">+{{ rule.reward_coin }}</span>
                <button v-if="!rule.auto_reward" class="earn-btn"
                  :disabled="rule.remaining === 0 || claiming === rule.code" @click="claimEarn(rule)">
                  {{ rule.remaining === 0 ? '已完成' : (claiming === rule.code ? '领取中' : '领取') }}
                </button>
                <span v-else class="earn-auto">自动发放</span>
              </div>
            </li>
          </ul>
        </div>

        <div class="transaction-section">
          <div class="section-header">
            <h3>金币明细</h3>
            <span class="section-count">共 {{ total }} 条</span>
          </div>

          <div v-if="loading && transactions.length === 0" class="state-tip">加载中...</div>
          <div v-else-if="transactions.length === 0" class="state-tip">暂无金币明细</div>
          <ul v-else class="transaction-list">
            <li v-for="item in transactions" :key="item.id" class="transaction-item">
              <div class="transaction-info">
                <div class="transaction-title">
                  <span class="transaction-scene">{{ sceneLabel(item.scene) }}</span>
                  <span class="transaction-type" :class="item.type === 1 ? 'income' : 'expense'">
                    {{ item.type === 1 ? '收入' : '支出' }}
                  </span>
                </div>
                <span class="transaction-time">{{ formatTime(item.created_at) }}</span>
              </div>
              <div class="transaction-right">
                <span class="transaction-amount" :class="item.amount > 0 ? 'income' : 'expense'">
                  {{ item.amount > 0 ? '+' : '' }}{{ item.amount }}
                </span>
                <span class="transaction-balance">余额 {{ item.balance_after }}</span>
              </div>
            </li>
          </ul>

          <button v-if="hasMore" class="load-more" :disabled="loading" @click="loadTransactions">
            {{ loading ? '加载中...' : '加载更多' }}
          </button>
        </div>
      </template>
    </div>

    <div v-if="withdrawVisible" class="modal-mask" @click.self="closeWithdraw">
      <div class="modal-card">
        <h3>金币提现</h3>
        <p class="modal-hint">当前可提现 ¥{{ withdrawable }}，最低提现 100 金币</p>
        <input v-model="withdrawAmount" class="withdraw-input" type="number" min="100" placeholder="请输入提现金币数" />
        <div class="modal-actions">
          <button class="btn-cancel" @click="closeWithdraw">取消</button>
          <button class="btn-confirm" :disabled="submitting" @click="submitWithdraw">
            {{ submitting ? '提交中...' : '确认提现' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { onMounted, ref } from 'vue'
import { walletApi } from '@/api/index.js'
import { useUserStore } from '@/stores/user'
import messageManager from '@/utils/messageManager.js'

const userStore = useUserStore()

const balance = ref(0)
const withdrawable = ref(0)
const coinPerYuan = ref(100)
const transactions = ref([])
const total = ref(0)
const page = ref(0)
const pageSize = 20
const loading = ref(false)
const hasMore = ref(false)

const withdrawVisible = ref(false)
const withdrawAmount = ref('')
const submitting = ref(false)

const earnRules = ref([])
const claiming = ref('')

const sceneLabels = {
  register: '注册奖励',
  post: '发布笔记',
  like: '点赞奖励',
  follow: '关注奖励',
  publish_note: '发表内容',
  publish_video: '发布视频',
  watch_ad: '看广告',
  watch_video: '看视频',
  danmaku: '发弹幕',
  comment: '发表评论',
  vip: 'VIP开通',
  vip_renew: 'VIP续费',
  shop: '商城消费',
  withdraw: '金币提现',
  admin_adjust: '管理员调整',
  sign_in: '每日签到'
}

function sceneLabel(scene) {
  return sceneLabels[scene] || scene || '金币变动'
}

function formatTime(value) {
  if (!value) return ''
  const date = new Date(value)
  return Number.isNaN(date.getTime()) ? '' : date.toLocaleString('zh-CN')
}

async function loadWallet() {
  try {
    const res = await walletApi.getWallet()
    if (res.success && res.data) {
      balance.value = res.data.coin_balance || 0
      withdrawable.value = res.data.withdrawable_yuan || 0
      coinPerYuan.value = res.data.coin_per_yuan || 100
    }
  } catch (err) {
    console.error('加载钱包失败:', err)
  }
}

async function loadTransactions() {
  if (loading.value) return
  loading.value = true
  try {
    const nextPage = page.value + 1
    const res = await walletApi.getTransactions({ page: nextPage, limit: pageSize })
    if (res.success && res.data) {
      const list = res.data.transactions || []
      transactions.value = nextPage === 1 ? list : transactions.value.concat(list)
      page.value = nextPage
      const pagination = res.data.pagination || {}
      total.value = pagination.total || transactions.value.length
      hasMore.value = nextPage < (pagination.pages || 1)
    }
  } catch (err) {
    console.error('加载金币明细失败:', err)
  } finally {
    loading.value = false
  }
}

function openWithdraw() {
  if (balance.value < coinPerYuan.value) {
    messageManager.info(`至少需要 ${coinPerYuan.value} 金币（1 元）才能提现`)
    return
  }
  withdrawAmount.value = ''
  withdrawVisible.value = true
}

function closeWithdraw() {
  withdrawVisible.value = false
}

async function submitWithdraw() {
  const amount = Number(withdrawAmount.value)
  if (!Number.isInteger(amount) || amount <= 0) {
    messageManager.error('请输入正整数的提现金币数')
    return
  }
  if (amount < coinPerYuan.value) {
    messageManager.error(`最低提现 ${coinPerYuan.value} 金币（1 元）`)
    return
  }
  if (amount > balance.value) {
    messageManager.error('提现金币数超过当前余额')
    return
  }
  submitting.value = true
  try {
    const res = await walletApi.withdraw(amount)
    if (res.success) {
      messageManager.success(res.message || '提现申请已提交（模拟）')
      withdrawVisible.value = false
      transactions.value = []
      page.value = 0
      await Promise.all([loadWallet(), loadTransactions()])
    } else {
      messageManager.error(res.message || '提现失败')
    }
  } catch (err) {
    messageManager.error(err?.message || '提现失败')
  } finally {
    submitting.value = false
  }
}

async function loadEarnRules() {
  try {
    const res = await walletApi.getEarnRules()
    if (res.success) {
      earnRules.value = res.data || []
    }
  } catch (err) {
    console.error('加载金币任务失败:', err)
  }
}

async function claimEarn(rule) {
  claiming.value = rule.code
  try {
    const res = await walletApi.earn(rule.code)
    if (res.success) {
      messageManager.success(res.message || `获得 ${rule.reward_coin} 金币`)
      transactions.value = []
      page.value = 0
      await Promise.all([loadWallet(), loadEarnRules(), loadTransactions()])
    } else {
      messageManager.error(res.message || '领取失败')
    }
  } catch (err) {
    messageManager.error(err?.message || '领取失败')
  } finally {
    claiming.value = ''
  }
}

onMounted(async () => {
  if (!userStore.isLoggedIn) return
  await Promise.all([loadWallet(), loadEarnRules()])
  await loadTransactions()
})
</script>

<style scoped>
.wallet-page {
  min-height: 100vh;
  padding: 96px 16px 60px;
  background: var(--bg-color-primary);
}

.wallet-container {
  max-width: 720px;
  margin: 0 auto;
}

.back-link {
  display: inline-block;
  margin-bottom: 18px;
  color: var(--text-color-secondary);
  font-size: 13px;
}

.balance-card {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 26px 28px;
  border-radius: 16px;
  background: linear-gradient(135deg, #2b1a12, #5a2a1c);
  color: #f7d08a;
}

.balance-label {
  margin: 0;
  font-size: 13px;
  color: rgba(255, 255, 255, 0.7);
}

.balance-value {
  margin: 8px 0 6px;
  font-size: 36px;
  line-height: 1;
}

.balance-hint {
  margin: 0;
  font-size: 12px;
  color: rgba(255, 255, 255, 0.65);
}

.withdraw-btn {
  height: 38px;
  padding: 0 24px;
  border: 1px solid #f7d08a;
  border-radius: 19px;
  background: transparent;
  color: #f7d08a;
  font-size: 14px;
  cursor: pointer;
}

.earn-section {
  margin-top: 26px;
}

.earn-list {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.earn-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  padding: 14px 18px;
  border-radius: 12px;
  background: var(--bg-color-secondary, #f7f8fa);
  border: 1px solid var(--border-color, #eee);
}

.earn-info {
  display: flex;
  flex-direction: column;
  gap: 3px;
  min-width: 0;
}

.earn-name {
  font-size: 14px;
  font-weight: 600;
  color: var(--text-color-primary);
}

.earn-desc,
.earn-limit {
  font-size: 12px;
  color: var(--text-color-secondary, #888);
}

.earn-right {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-shrink: 0;
}

.earn-reward {
  font-size: 15px;
  font-weight: 700;
  color: #d97706;
}

.earn-btn {
  padding: 6px 16px;
  border: none;
  border-radius: 16px;
  background: linear-gradient(135deg, #f7d08a, #c9963a);
  color: #3b2410;
  font-size: 13px;
  cursor: pointer;
}

.earn-btn:disabled {
  opacity: 0.55;
  cursor: default;
}

.earn-auto {
  font-size: 12px;
  color: var(--text-color-secondary, #888);
}

.transaction-section {
  margin-top: 26px;
}

.section-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 12px;
}

.section-header h3 {
  margin: 0;
  font-size: 16px;
  color: var(--text-color-primary);
}

.section-count {
  font-size: 12px;
  color: var(--text-color-secondary);
}

.transaction-list {
  margin: 0;
  padding: 0;
  list-style: none;
  background: var(--bg-color-secondary);
  border-radius: 12px;
  overflow: hidden;
}

.transaction-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 14px 18px;
  border-bottom: 1px solid var(--border-color-primary);
}

.transaction-item:last-child {
  border-bottom: none;
}

.transaction-info {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.transaction-title {
  display: flex;
  align-items: center;
  gap: 6px;
}

.transaction-scene {
  font-size: 14px;
  color: var(--text-color-primary);
}

.transaction-type {
  font-size: 11px;
  line-height: 16px;
  padding: 0 5px;
  border-radius: 4px;
  border: 1px solid currentColor;
}

.transaction-type.income {
  color: #34c759;
}

.transaction-type.expense {
  color: #ff3b30;
}

.transaction-time {
  font-size: 12px;
  color: var(--text-color-secondary);
}

.transaction-right {
  text-align: right;
}

.transaction-amount {
  font-size: 16px;
  font-weight: 600;
}

.transaction-amount.income {
  color: #34c759;
}

.transaction-amount.expense {
  color: #ff3b30;
}

.transaction-balance {
  display: block;
  margin-top: 4px;
  font-size: 12px;
  color: var(--text-color-secondary);
}

.load-more {
  width: 100%;
  height: 38px;
  margin-top: 14px;
  border: 1px solid var(--border-color-secondary);
  border-radius: 10px;
  background: var(--bg-color-secondary);
  color: var(--text-color-primary);
  cursor: pointer;
}

.load-more:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.state-tip {
  padding: 40px 0;
  text-align: center;
  color: var(--text-color-secondary);
}

.modal-mask {
  position: fixed;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(0, 0, 0, 0.5);
  z-index: 2000;
}

.modal-card {
  width: 320px;
  padding: 22px;
  border-radius: 14px;
  background: var(--bg-color-primary);
}

.modal-card h3 {
  margin: 0;
  font-size: 17px;
  color: var(--text-color-primary);
}

.modal-hint {
  margin: 8px 0 14px;
  font-size: 12px;
  color: var(--text-color-secondary);
}

.withdraw-input {
  width: 100%;
  height: 38px;
  padding: 0 12px;
  border: 1px solid var(--border-color-secondary);
  border-radius: 8px;
  background: var(--bg-color-secondary);
  color: var(--text-color-primary);
  outline: none;
  box-sizing: border-box;
}

.modal-actions {
  display: flex;
  gap: 10px;
  margin-top: 18px;
}

.btn-cancel,
.btn-confirm {
  flex: 1;
  height: 38px;
  border-radius: 8px;
  cursor: pointer;
}

.btn-cancel {
  border: 1px solid var(--border-color-secondary);
  background: var(--bg-color-secondary);
  color: var(--text-color-primary);
}

.btn-confirm {
  border: none;
  background: var(--primary-color);
  color: #fff;
}

.btn-confirm:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}
</style>
