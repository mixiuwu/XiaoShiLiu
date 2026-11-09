<template>
  <div class="coin-earn-management">
    <div class="page-intro">
      <h3>金币获取方式</h3>
      <p>配置用户可获取金币的途径、每次奖励数量与每日次数上限。行为自动发放的方式在用户完成对应操作后即时到账，用户手动领取的方式可在前端“钱包-金币任务”中领取。</p>
    </div>

    <CrudTable title="金币获取方式" entity-name="方式" api-endpoint="/admin/coin-earn-rules" :columns="columns"
      :form-fields="formFields" :search-fields="searchFields" default-sort-field="sort_order" default-sort-order="asc">
      <template #cell-daily_limit="{ item }">{{ item.daily_limit > 0 ? item.daily_limit : '不限' }}</template>
      <template #cell-auto_reward="{ item }">{{ item.auto_reward ? '自动发放' : '手动领取' }}</template>
    </CrudTable>
  </div>
</template>

<script setup>
import CrudTable from '@/views/admin/components/CrudTable.vue'

const columns = [
  { key: 'id', label: 'ID', sortable: true },
  { key: 'code', label: '规则编码', sortable: false },
  { key: 'name', label: '获取方式', sortable: false },
  { key: 'description', label: '说明', sortable: false },
  { key: 'reward_coin', label: '奖励金币', sortable: true },
  { key: 'daily_limit', label: '每日上限', type: 'slot', sortable: true },
  { key: 'auto_reward', label: '发放方式', type: 'slot', sortable: false },
  {
    key: 'enabled',
    label: '状态',
    type: 'status',
    sortable: true,
    statusMap: {
      1: { text: '启用', class: 'status-active' },
      0: { text: '停用', class: 'status-inactive' }
    }
  },
  { key: 'sort_order', label: '排序', sortable: true }
]

const formFields = [
  {
    key: 'code',
    label: '规则编码',
    type: 'text',
    required: true,
    placeholder: '如：watch_ad（字母/数字/下划线，创建后建议不再修改）',
    maxlength: 50
  },
  { key: 'name', label: '获取方式', type: 'text', required: true, placeholder: '如：看广告', maxlength: 50 },
  {
    key: 'description',
    label: '说明',
    type: 'textarea-with-emoji',
    required: false,
    placeholder: '展示给用户的说明，如：观看一段激励广告即可领取金币',
    maxLength: 255
  },
  { key: 'reward_coin', label: '每次奖励金币', type: 'number', required: true, placeholder: '请输入正整数', min: 1 },
  { key: 'daily_limit', label: '每日次数上限', type: 'number', required: false, placeholder: '0 表示不限制' },
  {
    key: 'auto_reward',
    label: '发放方式',
    type: 'select',
    required: false,
    options: [
      { label: '行为自动发放', value: 1 },
      { label: '用户手动领取', value: 0 }
    ]
  },
  {
    key: 'enabled',
    label: '状态',
    type: 'select',
    required: false,
    options: [
      { label: '启用', value: 1 },
      { label: '停用', value: 0 }
    ]
  },
  { key: 'sort_order', label: '排序', type: 'number', required: false, placeholder: '数值越小越靠前' }
]

const searchFields = [
  { key: 'name', label: '获取方式', type: 'text', placeholder: '请输入名称' },
  { key: 'code', label: '规则编码', type: 'text', placeholder: '请输入编码' },
  {
    key: 'enabled',
    label: '状态',
    type: 'select',
    placeholder: '全部状态',
    options: [
      { label: '全部状态', value: '' },
      { label: '启用', value: 1 },
      { label: '停用', value: '0' }
    ]
  }
]
</script>

<style scoped>
.coin-earn-management {
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

:deep(.status-active) {
  color: #16a34a;
}

:deep(.status-inactive) {
  color: #9ca3af;
}
</style>
