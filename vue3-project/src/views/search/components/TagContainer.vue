<script setup>
import { ref, watch, onMounted, onUnmounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useScroll } from '@vueuse/core'
import { useNavigationStore } from '@/stores/navigation'
import TabContainer from '@/components/TabContainer.vue'

const route = useRoute()
const router = useRouter()
const navigationStore = useNavigationStore()

// 获取滚动信息
const { y: scrollY } = useScroll(window)

// 定义props
const props = defineProps({
  tagStats: {
    type: Array,
    default: () => []
  },
  activeTag: {
    type: String,
    default: ''
  },
  activeTab: {
    type: String,
    default: 'all'
  }
})

// 定义emit事件
const emit = defineEmits(['tag-reload'])

// 防抖相关状态
const isAnimating = ref(false)
const pendingTagId = ref(null)
const currentRequestTagId = ref(null)
const animationTimer = ref(null)

// 标签选项卡数据
const tagTabs = computed(() => {
  const tabs = [
    { id: '', label: '全部', count: 0 }
  ]

  if (props.tagStats && props.tagStats.length > 0) {
    tabs.push(...props.tagStats.map(tag => ({
      id: tag.id,
      label: tag.label,
      count: tag.count
    })))
  }

  return tabs
})

// 是否显示标签选项卡
const shouldShowTags = computed(() => {
  return tagTabs.value.length > 1 && (props.activeTab === 'all' || props.activeTab === 'posts' || props.activeTab === 'videos')
})

function handleTagChange(item) {
  if (props.activeTag === item.id) return
  navigationStore.scrollToTop('instant')

  const query = { ...route.query }
  if (item.id) {
    query.tag = item.id
  } else {
    delete query.tag
  }

  router.replace({
    name: 'search_result_tab',
    params: { tab: route.params.tab || 'all' },
    query
  })
}

// 组件卸载时清理计时器
onUnmounted(() => {
  if (animationTimer.value) {
    clearTimeout(animationTimer.value)
  }
})
</script>

<template>

  <template v-if="shouldShowTags">

    <div class="tag-container">
      <TabContainer :tabs="tagTabs" :activeTab="activeTag" :enableDrag="true" @tab-change="handleTagChange" />
    </div>


    <div class="fixed-tag-container" :class="{ hidden: scrollY < 100 }">
      <TabContainer :tabs="tagTabs" :activeTab="activeTag" :enableDrag="true" @tab-change="handleTagChange" />
    </div>
  </template>
</template>

<style scoped>
/* 普通的标签容器 */
.tag-container {
  background: var(--bg-color-primary);
  width: 100%;
  border-bottom: none;
  transition: background 0.2s ease;
}

/* 固定的标签容器 - 吸顶效果 */
.fixed-tag-container {
  position: fixed;
  top: 72px;
  left: 50%;
  transform: translateX(-50%);
  width: 100%;
  max-width: 1200px;
  padding: 0 10px;
  background: var(--bg-color-primary);
  z-index: 50;
  transition: background-color 0.2s ease;
}

.hidden {
  display: none;
}

@media (min-width: 961px) {
  .fixed-tag-container {
    left: calc(50% + 114px);
    width: calc(100% - 228px);
  }
}
</style>
