<template>
  <div class="ads-management">
    <div class="page-intro">
      <h3>广告位管理</h3>
      <p>配置首页轮播广告的图片、跳转链接、投放时间与排序。仅「上线」且在投放时间内的广告会展示在 Web 与 APP 前台。广告位标识 home_banner 对应首页顶部横幅，其他标识可用于后续扩展。</p>
    </div>

    <CrudTable title="广告位" entity-name="广告" api-endpoint="/admin/ads" :columns="columns" :form-fields="formFields"
      :search-fields="searchFields" default-sort-field="sort_order" default-sort-order="asc" />
  </div>
</template>

<script setup>
import CrudTable from '@/views/admin/components/CrudTable.vue'

const columns = [
  { key: 'id', label: 'ID', sortable: true },
  { key: 'image_url', label: '广告图', type: 'image', sortable: false },
  { key: 'title', label: '标题', sortable: false },
  { key: 'position', label: '广告位', sortable: false },
  { key: 'link_url', label: '跳转链接', sortable: false },
  {
    key: 'status',
    label: '状态',
    type: 'status',
    sortable: true,
    statusMap: {
      1: { text: '上线', class: 'status-active' },
      0: { text: '下线', class: 'status-inactive' }
    }
  },
  { key: 'sort_order', label: '排序', sortable: true },
  { key: 'start_at', label: '开始时间', type: 'date', sortable: false },
  { key: 'end_at', label: '结束时间', type: 'date', sortable: false }
]

const formFields = [
  { key: 'title', label: '广告标题', type: 'text', required: true, placeholder: '展示用标题，如：秋季校园摄影大赛', maxlength: 100 },
  {
    key: 'image_url',
    label: '广告图片',
    type: 'image-upload',
    required: true,
    placeholder: '点击或拖拽上传广告图，建议尺寸 16:9'
  },
  { key: 'link_url', label: '跳转链接', type: 'text', required: false, placeholder: '如：/explore 或 https://example.com', maxlength: 500 },
  {
    key: 'position',
    label: '广告位标识',
    type: 'select',
    required: true,
    options: [
      { label: '首页顶部横幅（home_banner）', value: 'home_banner' }
    ]
  },
  {
    key: 'status',
    label: '状态',
    type: 'select',
    required: false,
    options: [
      { label: '上线', value: 1 },
      { label: '下线', value: 0 }
    ]
  },
  { key: 'sort_order', label: '排序', type: 'number', required: false, placeholder: '数值越小越靠前' },
  { key: 'start_at', label: '开始时间', type: 'text', required: false, placeholder: '留空表示立即生效，格式：2026-11-08 00:00:00' },
  { key: 'end_at', label: '结束时间', type: 'text', required: false, placeholder: '留空表示长期有效，格式：2026-12-31 23:59:59' }
]

const searchFields = [
  { key: 'title', label: '标题', type: 'text', placeholder: '请输入广告标题' },
  { key: 'position', label: '广告位', type: 'text', placeholder: '如：home_banner' },
  {
    key: 'status',
    label: '状态',
    type: 'select',
    placeholder: '全部状态',
    options: [
      { label: '全部状态', value: '' },
      { label: '上线', value: 1 },
      { label: '下线', value: '0' }
    ]
  }
]
</script>

<style scoped>
.ads-management {
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
