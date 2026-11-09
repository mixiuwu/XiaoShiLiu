<template>
  <div class="vip-page">
    <div class="vip-container">
      <div class="vip-header">
        <router-link class="back-link" to="/user">← 返回个人主页</router-link>
        <h1>VIP 会员中心</h1>
        <p>使用金币开通会员，解锁专属权益</p>
      </div>

      <div class="coin-bar">
        <span>我的金币</span>
        <strong>{{ coinBalance }}</strong>
        <router-link class="coin-bar-link" to="/wallet">查看钱包 ›</router-link>
      </div>

      <div class="vip-status-card" :class="{ active: status.is_vip }">
        <div class="status-main">
          <div class="status-title">
            <span class="status-badge" :class="{ active: status.is_vip }">
              {{ status.is_vip ? 'VIP会员' : '未开通' }}
            </span>
            <span v-if="status.is_vip" class="status-level">Lv.{{ status.level }}</span>
          </div>
          <p v-if="status.is_vip" class="status-desc">
            {{ status.plan_name || '会员套餐' }} · 剩余 {{ status.remaining_days }} 天
          </p>
          <p v-else class="status-desc">
            {{ userStore.isLoggedIn ? '开通会员即可享受专属权益' : '请先登录后再开通会员' }}
          </p>
        </div>
        <div v-if="status.is_vip" class="status-expire">
          <span>到期时间</span>
          <strong>{{ formatTime(status.expire_at) }}</strong>
        </div>
      </div>

      <div v-if="plansLoading" class="state-tip">套餐加载中...</div>
      <div v-else-if="plans.length === 0" class="state-tip">暂无可开通套餐，请等待管理员配置</div>
      <div v-else class="plan-grid">
        <div v-for="plan in plans" :key="plan.id" class="plan-card">
          <div class="plan-top">
            <h3>{{ plan.name }}</h3>
            <span class="plan-level">Lv.{{ plan.level }}</span>
          </div>
          <div class="plan-price">
            <span class="coin">{{ plan.price_coin }}</span>
            <span class="unit">金币</span>
          </div>
          <div class="plan-duration">有效期 {{ plan.duration_days }} 天</div>
          <ul class="perks">
            <li v-for="(perk, index) in plan.perks || []" :key="index">{{ perk }}</li>
            <li v-if="!(plan.perks || []).length" class="perk-empty">暂无权益说明</li>
          </ul>
          <button class="buy-btn" :disabled="!userStore.isLoggedIn || purchasingId === plan.id"
            @click="buy(plan)">
            {{ purchasingId === plan.id ? '处理中...' : (status.is_vip ? '续费' : '立即开通') }}
          </button>
        </div>
      </div>

      <p class="vip-tip">开通后立即生效；若当前会员未过期，续费时长会自动叠加。</p>
    </div>
  </div>
</template>

<script setup>
import { onMounted, ref } from 'vue'
import { vipApi, walletApi } from '@/api/index.js'
import { useUserStore } from '@/stores/user'
import messageManager from '@/utils/messageManager.js'

const userStore = useUserStore()
const plans = ref([])
const plansLoading = ref(true)
const purchasingId = ref(null)
const coinBalance = ref(0)
const status = ref({ is_vip: false, level: 0, remaining_days: 0, expire_at: null, plan_name: null })

function formatTime(value) {
  if (!value) return '-'
  const date = new Date(value)
  return Number.isNaN(date.getTime()) ? '-' : date.toLocaleString('zh-CN')
}

async function loadPlans() {
  plansLoading.value = true
  try {
    const res = await vipApi.getPlans()
    plans.value = res.success ? (res.data || []) : []
  } catch (err) {
    console.error('加载VIP套餐失败:', err)
    plans.value = []
  } finally {
    plansLoading.value = false
  }
}

async function loadCoinBalance() {
  if (!userStore.isLoggedIn) return
  try {
    const res = await walletApi.getWallet()
    if (res.success && res.data) coinBalance.value = res.data.coin_balance || 0
  } catch (err) {
    console.error('加载金币余额失败:', err)
  }
}

async function loadStatus() {
  if (!userStore.isLoggedIn) return
  try {
    const res = await vipApi.getStatus()
    if (res.success && res.data) status.value = res.data
  } catch (err) {
    console.error('加载VIP状态失败:', err)
  }
}

async function buy(plan) {
  if (!userStore.isLoggedIn) {
    messageManager.info('请先登录后再开通会员')
    return
  }
  if (!window.confirm(`确认使用 ${plan.price_coin} 金币${status.value.is_vip ? '续费' : '开通'}「${plan.name}」？`)) {
    return
  }
  purchasingId.value = plan.id
  try {
    const res = await vipApi.purchase(plan.id)
    if (res.success) {
      messageManager.success(res.message || '开通成功')
      await Promise.all([loadStatus(), loadCoinBalance(), userStore.getCurrentUser()])
    } else {
      messageManager.error(res.message || '开通失败')
    }
  } catch (err) {
    messageManager.error(err?.message || '开通失败，请检查金币余额')
  } finally {
    purchasingId.value = null
  }
}

onMounted(() => {
  loadPlans()
  loadStatus()
  loadCoinBalance()
})
</script>

<style scoped>
.vip-page {
  min-height: 100vh;
  padding: 96px 16px 60px;
  background: var(--bg-color-primary);
}

.vip-container {
  max-width: 760px;
  margin: 0 auto;
}

.vip-header {
  text-align: center;
  margin-bottom: 24px;
}

.back-link {
  display: inline-block;
  margin-bottom: 14px;
  color: var(--text-color-secondary);
  font-size: 13px;
}

.vip-header h1 {
  margin: 0;
  font-size: 24px;
  color: var(--text-color-primary);
}

.vip-header p {
  margin: 8px 0 0;
  font-size: 13px;
  color: var(--text-color-secondary);
}

.coin-bar {
  display: flex;
  align-items: center;
  gap: 10px;
  margin-bottom: 14px;
  padding: 10px 16px;
  border-radius: 10px;
  background: var(--bg-color-secondary);
  border: 1px solid var(--border-color-secondary);
  font-size: 13px;
  color: var(--text-color-secondary);
}

.coin-bar strong {
  font-size: 17px;
  color: #c9963a;
}

.coin-bar-link {
  margin-left: auto;
  font-size: 12px;
  color: var(--text-color-secondary);
}

.vip-status-card {
  display: flex;
  justify-content: space-between;
  gap: 16px;
  padding: 22px 24px;
  border-radius: 16px;
  background: var(--bg-color-secondary);
  border: 1px solid var(--border-color-secondary);
  margin-bottom: 24px;
}

.vip-status-card.active {
  background: linear-gradient(135deg, #2b1a12, #5a2a1c);
  border-color: #c9963a;
}

.status-title {
  display: flex;
  align-items: center;
  gap: 10px;
}

.status-badge {
  padding: 3px 12px;
  border-radius: 12px;
  font-size: 12px;
  background: rgba(142, 142, 147, 0.15);
  color: var(--text-color-secondary);
}

.status-badge.active {
  background: linear-gradient(90deg, #f7d08a, #c9963a);
  color: #3b2410;
  font-weight: 700;
}

.status-level {
  font-size: 13px;
  color: #f7d08a;
}

.status-desc {
  margin: 10px 0 0;
  font-size: 13px;
  color: var(--text-color-secondary);
}

.vip-status-card.active .status-desc {
  color: rgba(255, 255, 255, 0.75);
}

.status-expire {
  text-align: right;
  font-size: 12px;
  color: rgba(255, 255, 255, 0.7);
}

.status-expire strong {
  display: block;
  margin-top: 6px;
  font-size: 13px;
  color: #f7d08a;
  font-weight: 600;
}

.plan-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(210px, 1fr));
  gap: 16px;
}

.plan-card {
  display: flex;
  flex-direction: column;
  padding: 18px;
  border-radius: 14px;
  background: var(--bg-color-secondary);
  border: 1px solid var(--border-color-secondary);
}

.plan-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.plan-top h3 {
  margin: 0;
  font-size: 16px;
  color: var(--text-color-primary);
}

.plan-level {
  font-size: 12px;
  color: #c9963a;
}

.plan-price {
  margin-top: 14px;
  color: #c9963a;
}

.plan-price .coin {
  font-size: 26px;
  font-weight: 700;
}

.plan-price .unit {
  font-size: 12px;
  margin-left: 4px;
}

.plan-duration {
  margin-top: 4px;
  font-size: 12px;
  color: var(--text-color-secondary);
}

.perks {
  flex: 1;
  margin: 14px 0;
  padding-left: 18px;
  font-size: 12px;
  color: var(--text-color-secondary);
  line-height: 1.8;
}

.perk-empty {
  list-style: none;
  padding-left: 0;
}

.buy-btn {
  height: 38px;
  border: none;
  border-radius: 19px;
  background: var(--primary-color);
  color: #fff;
  font-size: 14px;
  cursor: pointer;
}

.buy-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.state-tip {
  padding: 40px 0;
  text-align: center;
  color: var(--text-color-secondary);
}

.vip-tip {
  margin-top: 20px;
  text-align: center;
  font-size: 12px;
  color: var(--text-color-secondary);
}
</style>
