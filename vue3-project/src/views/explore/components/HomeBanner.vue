<template>
  <div v-if="ads.length > 0" class="home-banner">
    <component :is="linkTag(ad)" v-for="(ad, index) in ads" :key="ad.id" v-show="index === currentIndex"
      v-bind="linkProps(ad)" class="banner-item" :aria-label="ad.title">
      <img :src="ad.image_url" :alt="ad.title" class="banner-image" />
      <span v-if="ad.title" class="banner-title">{{ ad.title }}</span>
    </component>

    <div v-if="ads.length > 1" class="banner-dots">
      <span v-for="(ad, index) in ads" :key="ad.id" class="dot" :class="{ active: index === currentIndex }"
        @click="goTo(index)"></span>
    </div>
  </div>
</template>

<script setup>
import { computed, onMounted, onUnmounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { getAds } from '@/api/ads'

const router = useRouter()
const ads = ref([])
const currentIndex = ref(0)
let timer = null

const position = computed(() => 'home_banner')

function linkTag(ad) {
  return ad.link_url ? 'a' : 'div'
}

function linkProps(ad) {
  if (!ad.link_url) return {}
  if (isExternal(ad.link_url)) {
    return { href: ad.link_url, target: '_blank', rel: 'noopener noreferrer' }
  }
  return {
    href: ad.link_url,
    onClick: (event) => {
      event.preventDefault()
      router.push(ad.link_url)
    }
  }
}

function isExternal(url) {
  return /^https?:\/\//i.test(url)
}

function goTo(index) {
  currentIndex.value = index
  restartTimer()
}

function startTimer() {
  if (ads.value.length <= 1) return
  timer = setInterval(() => {
    currentIndex.value = (currentIndex.value + 1) % ads.value.length
  }, 5000)
}

function restartTimer() {
  stopTimer()
  startTimer()
}

function stopTimer() {
  if (timer) {
    clearInterval(timer)
    timer = null
  }
}

async function loadAds() {
  const response = await getAds({ position: position.value, limit: 5 })
  if (response.success !== false && Array.isArray(response.data)) {
    ads.value = response.data
    currentIndex.value = 0
    startTimer()
  }
}

onMounted(loadAds)
onUnmounted(stopTimer)
</script>

<style scoped>
.home-banner {
  position: relative;
  width: 100%;
  margin-bottom: 12px;
  border-radius: 12px;
  overflow: hidden;
  background: var(--bg-color-secondary);
}

.banner-item {
  display: block;
  position: relative;
  width: 100%;
  text-decoration: none;
}

.banner-image {
  display: block;
  width: 100%;
  max-height: 220px;
  object-fit: cover;
}

.banner-title {
  position: absolute;
  left: 0;
  right: 0;
  bottom: 0;
  padding: 20px 16px 12px;
  color: #fff;
  font-size: 14px;
  background: linear-gradient(180deg, transparent, rgba(0, 0, 0, 0.55));
}

.banner-dots {
  position: absolute;
  right: 12px;
  bottom: 8px;
  display: flex;
  gap: 6px;
}

.dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.5);
  cursor: pointer;
  transition: background 0.2s ease;
}

.dot.active {
  background: #fff;
}
</style>
