<template>
  <div class="vip-management">
    <div class="page-tabs">
      <button class="tab-btn" :class="{ active: activeTab === 'plans' }" @click="activeTab = 'plans'">
        VIP套餐设置
      </button>
      <button class="tab-btn" :class="{ active: activeTab === 'members' }" @click="switchToMembers">
        会员记录
      </button>
    </div>

    <CrudTable v-if="activeTab === 'plans'" title="VIP套餐设置" :columns="columns" :form-fields="formFields"
      :search-fields="searchFields" :api-endpoint="apiEndpoint" entity-name="VIP套餐" />

    <div v-else class="member-panel">
      <div class="member-toolbar">
        <input v-model="memberKeyword" class="member-input" placeholder="搜索昵称 / 小石榴号"
          @keyup.enter="loadMembers(1)" />
        <select v-model="memberStatus" class="member-select" @change="loadMembers(1)">
          <option value="">全部状态</option>
          <option value="active">生效中</option>
          <option value="expired">已过期</option>
        </select>
        <button class="btn-primary" @click="loadMembers(1)">搜索</button>
      </div>

      <div v-if="memberLoading" class="member-empty">加载中...</div>
      <div v-else-if="members.length === 0" class="member-empty">暂无会员记录</div>
      <table v-else class="member-table">
        <thead>
          <tr>
            <th>ID</th>
            <th>用户</th>
            <th>小石榴号</th>
            <th>等级</th>
            <th>套餐</th>
            <th>开通时间</th>
            <th>到期时间</th>
            <th>状态</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="item in members" :key="item.id">
            <td>{{ item.id }}</td>
            <td>{{ item.nickname || '用户' }}</td>
            <td>{{ item.account }}</td>
            <td>Lv.{{ item.level }}</td>
            <td>{{ item.plan_name || '-' }}</td>
            <td>{{ formatTime(item.start_at) }}</td>
            <td>{{ formatTime(item.expire_at) }}</td>
            <td>
              <span class="status-badge" :class="item.is_active ? 'active' : 'expired'">
                {{ item.is_active ? '生效中' : '已过期' }}
              </span>
            </td>
          </tr>
        </tbody>
      </table>

      <div v-if="memberPagination.total > 0" class="member-pagination">
        <span>共 {{ memberPagination.total }} 条，第 {{ memberPagination.page }} / {{ memberPagination.pages }} 页</span>
        <div class="pagination-actions">
          <button class="btn-outline" :disabled="memberPagination.page <= 1" @click="loadMembers(memberPagination.page - 1)">
            上一页
          </button>
          <button class="btn-outline" :disabled="memberPagination.page >= memberPagination.pages"
            @click="loadMembers(memberPagination.page + 1)">
            下一页
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { onMounted, reactive, ref } from 'vue'
import CrudTable from '@/views/admin/components/CrudTable.vue'
import apiConfig from '@/config/api.js'

const activeTab = ref('plans')
const apiEndpoint = '/admin/vip-plans'

const columns = [
  { key: 'id', label: 'ID', sortable: true },
  { key: 'name', label: '套餐名称', sortable: false },
  { key: 'level', label: '等级', sortable: true },
  { key: 'price_coin', label: '所需金币', sortable: true },
  { key: 'duration_days', label: '有效天数', sortable: true },
  { key: 'perks_json', label: '权益说明(JSON)', sortable: false }
]

const formFields = [
  { key: 'name', label: '套餐名称', type: 'text', required: true, placeholder: '如：月卡会员', maxlength: 50 },
  { key: 'level', label: '会员等级', type: 'number', required: true, placeholder: '请输入等级数字', min: 1 },
  { key: 'price_coin', label: '所需金币', type: 'number', required: true, placeholder: '请输入金币数量', min: 0 },
  { key: 'duration_days', label: '有效天数', type: 'number', required: true, placeholder: '请输入有效天数', min: 1 },
  {
    key: 'perks_json',
    label: '权益说明',
    type: 'textarea-with-emoji',
    required: false,
    placeholder: '请输入 JSON 数组，如：["专属标识","评论置顶"]',
    rows: 4
  }
]

const searchFields = [
  { key: 'name', label: '套餐名称', type: 'text', placeholder: '请输入套餐名称' },
  { key: 'level', label: '等级', type: 'number', placeholder: '请输入等级' }
]

const members = ref([])
const memberLoading = ref(false)
const memberKeyword = ref('')
const memberStatus = ref('')
const memberPagination = reactive({ total: 0, page: 1, limit: 20, pages: 0 })

function switchToMembers() {
  activeTab.value = 'members'
  if (members.value.length === 0) loadMembers(1)
}

function formatTime(value) {
  if (!value) return '-'
  const date = new Date(value)
  return Number.isNaN(date.getTime()) ? '-' : date.toLocaleString('zh-CN')
}

async function loadMembers(page = 1) {
  memberLoading.value = true
  try {
    const params = new URLSearchParams({
      page,
      limit: memberPagination.limit
    })
    if (memberKeyword.value.trim()) params.append('keyword', memberKeyword.value.trim())
    if (memberStatus.value) params.append('status', memberStatus.value)

    const response = await fetch(`${apiConfig.baseURL}/admin/vip-members?${params}`, {
      headers: { Authorization: `Bearer ${localStorage.getItem('admin_token') || ''}` }
    })
    const result = await response.json()
    if (result.code === 200) {
      members.value = result.data.data || []
      Object.assign(memberPagination, result.data.pagination || {})
    } else {
      members.value = []
    }
  } catch (err) {
    console.error('加载会员记录失败:', err)
    members.value = []
  } finally {
    memberLoading.value = false
  }
}

onMounted(() => {
  if (activeTab.value === 'members') loadMembers(1)
})
</script>

<style scoped>
.vip-management {
  padding: 0;
}

.page-tabs {
  display: flex;
  gap: 8px;
  margin-bottom: 16px;
}

.tab-btn {
  padding: 8px 18px;
  border-radius: 8px;
  border: 1px solid var(--border-color-secondary);
  background: var(--bg-color-secondary);
  color: var(--text-color-secondary);
  cursor: pointer;
  transition: all 0.2s;
}

.tab-btn.active {
  border-color: var(--primary-color);
  color: var(--primary-color);
  font-weight: 600;
}

.member-toolbar {
  display: flex;
  gap: 10px;
  margin-bottom: 14px;
  flex-wrap: wrap;
}

.member-input,
.member-select {
  height: 36px;
  padding: 0 12px;
  border-radius: 8px;
  border: 1px solid var(--border-color-secondary);
  background: var(--bg-color-secondary);
  color: var(--text-color-primary);
  outline: none;
}

.member-input {
  flex: 1;
  min-width: 200px;
  max-width: 320px;
}

.btn-primary,
.btn-outline {
  height: 36px;
  padding: 0 16px;
  border-radius: 8px;
  cursor: pointer;
}

.btn-primary {
  border: none;
  background: var(--primary-color);
  color: #fff;
}

.btn-outline {
  border: 1px solid var(--border-color-secondary);
  background: var(--bg-color-secondary);
  color: var(--text-color-primary);
}

.btn-outline:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.member-table {
  width: 100%;
  border-collapse: collapse;
  background: var(--bg-color-primary);
  border-radius: 10px;
  overflow: hidden;
}

.member-table th,
.member-table td {
  padding: 12px 14px;
  text-align: left;
  font-size: 13px;
  border-bottom: 1px solid var(--border-color-primary);
}

.member-table th {
  background: var(--bg-color-secondary);
  color: var(--text-color-secondary);
  font-weight: 600;
}

.member-table td {
  color: var(--text-color-primary);
}

.status-badge {
  padding: 2px 10px;
  border-radius: 10px;
  font-size: 12px;
}

.status-badge.active {
  background: rgba(52, 199, 89, 0.15);
  color: #34c759;
}

.status-badge.expired {
  background: rgba(142, 142, 147, 0.15);
  color: var(--text-color-secondary);
}

.member-empty {
  padding: 50px 0;
  text-align: center;
  color: var(--text-color-secondary);
}

.member-pagination {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-top: 14px;
  font-size: 13px;
  color: var(--text-color-secondary);
}

.pagination-actions {
  display: flex;
  gap: 8px;
}
</style>
