<template>
  <img
    class="vip-badge"
    :src="badgeSrc"
    :alt="`VIP${badgeLevel}`"
    :title="`VIP${badgeLevel}会员`"
    draggable="false"
    @click.stop="goVip" />
</template>

<script setup>
import { computed } from 'vue'
import { useRouter } from 'vue-router'

import vip1 from '@/assets/vip/vip1.png'
import vip2 from '@/assets/vip/vip2.png'
import vip3 from '@/assets/vip/vip3.png'
import vip4 from '@/assets/vip/vip4.png'
import vip5 from '@/assets/vip/vip5.png'
import vip6 from '@/assets/vip/vip6.png'
import vip7 from '@/assets/vip/vip7.png'

// 等级徽章图：VIP1 ~ VIP7
const VIP_BADGES = { 1: vip1, 2: vip2, 3: vip3, 4: vip4, 5: vip5, 6: vip6, 7: vip7 }

const props = defineProps({
  level: {
    type: [Number, String],
    default: 1
  }
})

// 等级统一收敛到 1~7，越界时回退到边界等级
const badgeLevel = computed(() => {
  const n = Number(props.level)
  if (!Number.isFinite(n) || n < 1) return 1
  return Math.min(7, Math.round(n))
})

const badgeSrc = computed(() => VIP_BADGES[badgeLevel.value])

const router = useRouter()
const goVip = () => router.push('/vip')
</script>

<style scoped>
.vip-badge {
  display: inline-block;
  height: 22px;
  width: auto;
  vertical-align: middle;
  cursor: pointer;
  user-select: none;
  transition: transform 0.15s ease;
}

.vip-badge:hover {
  transform: scale(1.08);
}
</style>
