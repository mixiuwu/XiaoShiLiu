<template>
  <div class="video-upload">
    <!-- 第 1 层：单集 / 多集合集 切换 -->
    <div class="series-tabs">
      <button
        type="button"
        class="series-tab"
        :class="{ active: !isSeries }"
        @click="switchSeries(false)"
      >
        单集视频
      </button>
      <button
        type="button"
        class="series-tab"
        :class="{ active: isSeries }"
        @click="switchSeries(true)"
      >
        多集合集
      </button>
    </div>

    <!-- ======== 单集模式 ======== -->
    <template v-if="!isSeries">
      <!-- 第 2 层：本地上传 / 视频链接 切换 -->
      <div class="mode-tabs">
        <button
          type="button"
          class="mode-tab"
          :class="{ active: mode === 'file' }"
          @click="switchMode('file')"
        >
          <SvgIcon name="publish" width="16" height="16" />
          <span>本地上传</span>
        </button>
        <button
          type="button"
          class="mode-tab"
          :class="{ active: mode === 'url' }"
          @click="switchMode('url')"
        >
          <SvgIcon name="link" width="16" height="16" />
          <span>视频链接</span>
        </button>
      </div>

      <!-- 本地文件上传 -->
      <div v-if="mode === 'file'">
        <div class="upload-area" @click="!isUploading && !videoData && triggerFileInput()"
          :class="{ 'drag-over': isDragOver, 'uploading': isUploading, 'has-video': videoData }"
          @dragover.prevent="!isUploading && (isDragOver = true)" @dragleave.prevent="isDragOver = false"
          @drop.prevent="!isUploading && handleFileDrop($event)">
          <input ref="fileInput" type="file" accept="video/*" @change="handleFileSelect" style="display: none" :disabled="isUploading" />
          <input ref="coverInput" type="file" accept="image/*" @change="handleCoverSelect" style="display: none" />

          <div v-if="videoData && !isUploading" class="video-success" @click="triggerFileInput()">
            <div class="video-thumbnail" @click.stop="triggerCoverInput($event)" :class="{ 'custom-cover': customCover }">
              <img v-if="customCover || videoData.thumbnailDataUrl || videoData.coverUrl"
                :src="customCover || videoData.thumbnailDataUrl || videoData.coverUrl" class="thumbnail-image" />
              <div v-else class="thumbnail-placeholder"><SvgIcon name="publish" width="24" height="24" /></div>
              <div class="cover-overlay"><SvgIcon name="edit" width="16" height="16" /><span>自定义封面</span></div>
            </div>
            <div class="video-info">
              <div class="success-text"><div class="success-icon"><SvgIcon name="tick" width="14" height="14" /></div>上传成功</div>
              <div class="video-name" v-if="videoData.name">{{ videoData.name }}</div>
            </div>
            <button type="button" class="remove-btn" @click.stop="removeVideo"><SvgIcon name="close" width="14" height="14" /></button>
          </div>

          <div v-else-if="!isUploading" class="upload-placeholder">
            <SvgIcon name="publish" class="upload-icon" />
            <p>添加视频</p>
            <p class="upload-hint">支持 MP4、MOV、AVI 格式</p>
            <p class="upload-hint">文件大小不超过100MB</p>
            <p class="drag-hint">或拖拽视频到此处</p>
          </div>

          <div v-if="isUploading" class="upload-progress">
            <div class="progress-bar"><div class="progress-fill" :style="{ width: uploadProgress + '%' }"></div></div>
            <p class="progress-text">{{ Math.floor(uploadProgress) }}%</p>
          </div>
        </div>
      </div>

      <!-- URL 输入 -->
      <div v-else class="url-mode">
        <div v-if="!videoData" class="url-input-wrapper">
          <input v-model="urlInput" type="url" class="url-input" placeholder="请输入视频链接（如 https://example.com/video.mp4）" @keyup.enter="handleUrlSubmit" />
          <button type="button" class="url-submit-btn" :disabled="!urlInput.trim()" @click="handleUrlSubmit">确认</button>
        </div>

        <div v-if="videoData && !isUploading" class="video-success url-success">
          <div class="video-thumbnail">
            <video v-if="videoData.url" :src="videoData.url" class="video-preview" muted preload="metadata" />
            <img v-else-if="videoData.coverUrl" :src="videoData.coverUrl" class="thumbnail-image" />
            <div v-else class="thumbnail-placeholder"><SvgIcon name="link" width="24" height="24" /></div>
          </div>
          <div class="video-info">
            <div class="success-text"><div class="success-icon"><SvgIcon name="tick" width="14" height="14" /></div>视频链接已添加</div>
            <div class="video-url-display" :title="videoData.url">{{ videoData.url }}</div>
          </div>
          <button type="button" class="remove-btn" @click="removeVideo"><SvgIcon name="close" width="14" height="14" /></button>
        </div>
      </div>

      <div v-if="error" class="error-message">{{ error }}</div>
    </template>

    <!-- ======== 多集合集模式 ======== -->
    <template v-else>
      <div class="series-tip">
        <SvgIcon name="link" width="14" height="14" />
        合集模式建议使用视频链接，每一集对应一个地址
      </div>

      <div class="episodes-list">
        <div v-for="(ep, idx) in episodes" :key="idx" class="episode-item">
          <div class="episode-sort">
            <span class="episode-num">{{ String(idx + 1).padStart(2, '0') }}</span>
          </div>
          <div class="episode-inputs">
            <input v-model="ep.title" type="text" class="episode-title" :placeholder="`第${idx + 1}集`" @input="emitEpisodes" />
            <input v-model="ep.url" type="url" class="episode-url" placeholder="视频地址（MP4/m3u8）" @input="emitEpisodes" />
          </div>
          <div class="episode-actions">
            <button v-if="idx > 0" type="button" class="ep-btn ep-up" @click="moveEpisode(idx, -1)" title="上移">
              <SvgIcon name="close" width="14" height="14" style="transform: rotate(-90deg)" />
            </button>
            <button v-if="idx < episodes.length - 1" type="button" class="ep-btn ep-down" @click="moveEpisode(idx, 1)" title="下移">
              <SvgIcon name="close" width="14" height="14" style="transform: rotate(90deg)" />
            </button>
            <button type="button" class="ep-btn ep-del" @click="removeEpisode(idx)" title="删除">
              <SvgIcon name="close" width="14" height="14" />
            </button>
          </div>
        </div>
      </div>

      <button type="button" class="add-episode-btn" @click="addEpisode">
        <SvgIcon name="close" width="16" height="16" style="transform: rotate(45deg)" />
        添加一集
      </button>

      <div v-if="episodes.length === 0" class="empty-tip">点击上方"添加一集"开始创建合集</div>
    </template>

    <!-- 提示信息 -->
    <div class="upload-tips">
      <template v-if="isSeries">
        <p>• 合集模式支持多集视频，按排序播放</p>
        <p>• 每集填标题（如 第01集）和视频链接</p>
        <p>• 建议使用 CDN 加速的视频直链</p>
      </template>
      <template v-else-if="mode === 'file'">
        <p>• 支持 MP4、MOV、AVI 格式</p>
        <p>• 文件大小不超过{{ formatFileSize(apiConfig.upload.video.maxFileSize) }}</p>
        <p>• 建议视频时长不超过5分钟</p>
      </template>
      <template v-else>
        <p>• 支持 MP4、WebM 等直链视频地址</p>
        <p>• 推荐使用 CDN 加速的视频链接</p>
      </template>
    </div>

    <MessageToast v-if="showToast" :message="toastMessage" :type="toastType" @close="handleToastClose" />
  </div>
</template>

<script setup>
import { ref, watch, computed } from 'vue'
import SvgIcon from './SvgIcon.vue'
import MessageToast from './MessageToast.vue'
import { videoApi } from '@/api/video.js'
import { uploadImage } from '@/api/upload.js'
import { generateVideoThumbnail, blobToFile, generateThumbnailFilename } from '@/utils/videoThumbnail.js'
import { apiConfig } from '@/config/api'
import { formatFileSize } from '@/utils/fileSize'

const props = defineProps({
  modelValue: { type: [String, Object], default: '' },
  maxSize: { type: Number, default: apiConfig.upload.video.maxFileSize },
  episodes: { type: Array, default: () => [] } // 外部传入的多集数据
})

const emit = defineEmits(['update:modelValue', 'update:episodes', 'error', 'change'])

// ===== 状态 =====
const isSeries = ref(false)  // false=单集, true=多集合集
const mode = ref('file')     // 单集时：file / url

// 单集模式
const fileInput = ref(null)
const coverInput = ref(null)
const videoData = ref(null)
const customCover = ref(null)
const customCoverFile = ref(null)
const isUploading = ref(false)
const uploadProgress = ref(0)
const isDragOver = ref(false)
const error = ref('')
const showToast = ref(false)
const toastMessage = ref('')
const toastType = ref('success')
const urlInput = ref('')

// 多集合集模式
const localEpisodes = ref([])

// ===== 多集 =====
watch(() => props.episodes, (val) => {
  if (val && val.length > 0 && localEpisodes.value.length === 0) {
    localEpisodes.value = val.map(ep => ({
      title: ep.title || '',
      url: ep.video_url || ep.url || '',
      coverUrl: ep.cover_url || ep.coverUrl || ''
    }))
    isSeries.value = true
  }
}, { immediate: true, deep: true })

function switchSeries(series) {
  isSeries.value = series
  emitEpisodes()
}

function addEpisode() {
  localEpisodes.value.push({ title: '', url: '', coverUrl: '' })
  emitEpisodes()
}

function removeEpisode(idx) {
  localEpisodes.value.splice(idx, 1)
  emitEpisodes()
}

function moveEpisode(idx, dir) {
  const target = idx + dir
  if (target < 0 || target >= localEpisodes.value.length) return
  const arr = localEpisodes.value
  ;[arr[idx], arr[target]] = [arr[target], arr[idx]]
  emitEpisodes()
}

function emitEpisodes() {
  emit('update:episodes', localEpisodes.value.map((ep, i) => ({
    title: ep.title || `第${String(i + 1).padStart(2, '0')}集`,
    video_url: ep.url,
    cover_url: ep.coverUrl || null,
    sort: i
  })))
}

// ===== 单集 =====
watch(() => props.modelValue, (newValue) => {
  if (!newValue && videoData.value) {
    videoData.value = null
    customCover.value = null
    customCoverFile.value = null
    error.value = ''
  } else if (newValue && !videoData.value) {
    if (typeof newValue === 'object' && newValue.url) {
      videoData.value = { preview: newValue.url, url: newValue.url, coverUrl: newValue.coverUrl, uploaded: true, name: newValue.name || '已上传的视频', size: 0 }
    } else if (typeof newValue === 'string') {
      videoData.value = { preview: newValue, url: newValue, uploaded: true, name: '已上传的视频', size: 0 }
    }
  }
})

const switchMode = (newMode) => {
  if (mode.value === newMode) return
  mode.value = newMode
  error.value = ''
}

const triggerFileInput = () => fileInput.value?.click()
const triggerCoverInput = (event) => {
  if (event) { event.preventDefault(); event.stopPropagation() }
  coverInput.value?.click()
}

const handleFileSelect = (event) => {
  const files = event.target.files
  if (files?.length > 0) handleFile(files[0])
}

const handleFileDrop = (event) => {
  isDragOver.value = false
  const files = event.dataTransfer.files
  if (files?.length > 0) handleFile(files[0])
}

const handleCoverSelect = async (event) => {
  const files = event.target.files
  if (files?.length > 0) await handleCoverFile(files[0])
}

const validateVideoFile = (file) => {
  if (!file.type.startsWith('video/')) return { valid: false, message: '请选择视频文件' }
  if (file.size > props.maxSize) return { valid: false, message: `文件大小不能超过${formatFileSize(props.maxSize)}` }
  return { valid: true }
}

const validateUrl = (url) => {
  if (!url?.trim()) return { valid: false, message: '请输入视频链接' }
  try {
    const parsed = new URL(url.trim())
    if (!['http:', 'https:'].includes(parsed.protocol)) return { valid: false, message: '请输入 http 或 https 开头的链接' }
    return { valid: true, url: url.trim(), name: parsed.pathname.split('/').pop().split('?')[0] || '在线视频' }
  } catch { return { valid: false, message: '请输入有效的视频链接' } }
}

const validateCoverFile = (file) => {
  if (!file.type.startsWith('image/')) return { valid: false, message: '请选择图片文件' }
  const maxCoverSize = apiConfig.upload.image.maxFileSize
  if (file.size > maxCoverSize) return { valid: false, message: `封面图片大小不能超过${formatFileSize(apiConfig.upload.image.maxFileSize)}` }
  return { valid: true }
}

const handleFile = async (file) => {
  if (!file) return
  const validation = validateVideoFile(file)
  if (!validation.valid) { error.value = validation.message; emit('error', validation.message); return }

  const preview = URL.createObjectURL(file)
  videoData.value = { file, preview, name: file.name, size: file.size, uploaded: false, url: null, thumbnail: null, thumbnailDataUrl: null }
  error.value = ''
  emit('update:modelValue', file.name)
  emit('change', { type: 'video', hasChanges: true })
  await generateThumbnail(file)
}

const handleCoverFile = async (file) => {
  if (!file) return
  const validation = validateCoverFile(file)
  if (!validation.valid) { error.value = validation.message; showMessage(validation.message, 'error'); return }
  try {
    customCover.value = URL.createObjectURL(file)
    customCoverFile.value = file
    emit('change', { type: 'cover', hasChanges: true })
  } catch (err) {
    error.value = '处理封面图片失败'
    showMessage('处理封面图片失败', 'error')
  }
}

const handleUrlSubmit = () => {
  const validation = validateUrl(urlInput.value)
  if (!validation.valid) { error.value = validation.message; emit('error', validation.message); return }
  error.value = ''
  videoData.value = { file: null, preview: validation.url, url: validation.url, coverUrl: null, name: validation.name, size: 0, uploaded: true, fromUrl: true }
  emit('update:modelValue', validation.url)
  emit('change', { type: 'video', hasChanges: true })
  showMessage('视频链接已添加', 'success')
  urlInput.value = ''
}

const generateThumbnail = async (file) => {
  try {
    const result = await generateVideoThumbnail(file, { useOriginalSize: true, quality: 0.8, seekTime: 1 })
    if (result.success && videoData.value) {
      videoData.value.thumbnail = blobToFile(result.blob, generateThumbnailFilename(file.name))
      videoData.value.thumbnailDataUrl = result.dataUrl
    }
  } catch (error) { console.error('生成缩略图异常:', error) }
}

const uploadCustomCover = async () => {
  if (!customCoverFile.value) return null
  try {
    const result = await uploadImage(customCoverFile.value)
    return result.success ? result.data.url : null
  } catch (error) { return null }
}

const startUpload = async () => {
  if (isSeries.value) {
    // 多集模式不需要单集上传
    return { success: true, data: { episodes: localEpisodes.value.map((ep, i) => ({
      title: ep.title || `第${String(i + 1).padStart(2, '0')}集`,
      video_url: ep.url, cover_url: ep.coverUrl || null, sort: i
    })) }}
  }

  if (videoData.value?.fromUrl) {
    return { success: true, data: { url: videoData.value.url, coverUrl: videoData.value.coverUrl, originalname: videoData.value.name, size: 0 } }
  }
  if (!videoData.value?.file) return { success: false, message: '没有视频文件' }

  isUploading.value = true
  uploadProgress.value = 0
  try {
    let thumbnailToUpload = customCoverFile.value || videoData.value.thumbnail || null
    const result = await videoApi.uploadVideo(videoData.value.file, (p) => uploadProgress.value = p, thumbnailToUpload)
    if (result.success) {
      isUploading.value = false
      if (videoData.value) {
        videoData.value.uploaded = true
        videoData.value.url = result.data.url
        videoData.value.coverUrl = result.data.coverUrl
        if (customCoverFile.value && result.data.coverUrl) customCover.value = result.data.coverUrl
        emit('update:modelValue', videoData.value.url)
        showMessage('视频上传成功', 'success')
      }
      return result
    } else {
      isUploading.value = false
      error.value = result.message || '视频上传失败'
      emit('error', error.value)
      showMessage(error.value, 'error')
      return result
    }
  } catch (err) {
    isUploading.value = false
    error.value = '视频上传失败，请重试'
    emit('error', error.value)
    showMessage(error.value, 'error')
    return { success: false, message: '视频上传失败，请重试' }
  }
}

const removeVideo = () => {
  if (videoData.value?.preview?.startsWith('blob:')) URL.revokeObjectURL(videoData.value.preview)
  if (customCover.value?.startsWith('blob:')) URL.revokeObjectURL(customCover.value)
  videoData.value = null
  customCover.value = null
  customCoverFile.value = null
  error.value = ''
  uploadProgress.value = 0
  urlInput.value = ''
  emit('update:modelValue', '')
  if (fileInput.value) fileInput.value.value = ''
  if (coverInput.value) coverInput.value.value = ''
}

const showMessage = (message, type = 'success') => { toastMessage.value = message; toastType.value = type; showToast.value = true }
const handleToastClose = () => { showToast.value = false }

const getVideoData = () => ({ ...videoData.value, customCover: customCover.value, customCoverFile: customCoverFile.value })
const getEpisodes = () => localEpisodes.value
const reset = () => { removeVideo(); localEpisodes.value = []; isSeries.value = false }

defineExpose({ getVideoData, getEpisodes, reset, removeVideo, startUpload, customCoverFile, uploadCustomCover, isSeries })
</script>

<style scoped>
.video-upload { width: 100%; }

/* 第 1 层：单集/多集合集 */
.series-tabs {
  display: flex;
  margin-bottom: 12px;
  border-bottom: 2px solid var(--border-color-primary);
  gap: 0;
}
.series-tab {
  padding: 10px 20px;
  border: none;
  background: transparent;
  color: var(--text-color-secondary);
  font-size: 14px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s ease;
  border-bottom: 2px solid transparent;
  margin-bottom: -2px;
}
.series-tab:hover { color: var(--text-color-primary); }
.series-tab.active { color: var(--primary-color); border-bottom-color: var(--primary-color); }

/* 第 2 层：file/url */
.mode-tabs {
  display: flex;
  margin-bottom: 12px;
  border-bottom: 1px solid var(--border-color-primary);
  gap: 4px;
}
.mode-tab {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 10px 16px;
  border: none;
  background: transparent;
  color: var(--text-color-secondary);
  font-size: 13px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s ease;
  border-bottom: 2px solid transparent;
  margin-bottom: -1px;
}
.mode-tab:hover { color: var(--text-color-primary); }
.mode-tab.active { color: var(--primary-color); border-bottom-color: var(--primary-color); }

/* ===== URL 模式 ===== */
.url-mode { margin-bottom: 8px; }
.url-input-wrapper { display: flex; gap: 8px; }
.url-input {
  flex: 1;
  padding: 12px 14px;
  border: 1px solid var(--border-color-primary);
  border-radius: 8px;
  background: var(--bg-color-primary);
  color: var(--text-color-primary);
  font-size: 14px;
  transition: border-color 0.2s ease;
  box-sizing: border-box;
}
.url-input:focus { outline: none; border-color: var(--primary-color); }
.url-input::placeholder { color: var(--text-color-secondary); }
.url-submit-btn {
  padding: 12px 24px;
  border: none;
  border-radius: 8px;
  background: var(--primary-color);
  color: white;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s ease;
  white-space: nowrap;
}
.url-submit-btn:hover:not(:disabled) { background: var(--primary-color-dark); }
.url-submit-btn:disabled { opacity: 0.5; cursor: not-allowed; }
.url-success .video-url-display {
  font-size: 11px;
  color: var(--text-color-tertiary);
  margin-top: 4px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  max-width: 200px;
}
.video-preview { width: 100%; height: 100%; object-fit: cover; }

/* ===== 本地上传 ===== */
.upload-area {
  width: 100%;
  min-height: 200px;
  border: 2px dashed var(--border-color-primary);
  border-radius: 8px;
  background: var(--bg-color-primary);
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: all 0.2s ease;
  position: relative;
  overflow: hidden;
}
.upload-area:hover { border-color: var(--primary-color); background: var(--bg-color-secondary); }
.upload-area.drag-over { border-color: var(--primary-color); background: var(--bg-color-secondary); transform: scale(1.02); }
.upload-area.has-video { min-height: 100px; cursor: default; border: none; background: transparent; }

.video-success {
  width: 100%;
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px;
  background: var(--bg-color-secondary);
  border-radius: 8px;
  border: 1px solid var(--success-color);
  cursor: pointer;
  box-sizing: border-box;
}
.video-thumbnail {
  width: 60px;
  height: 60px;
  border-radius: 6px;
  overflow: hidden;
  background: var(--bg-color-tertiary);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  position: relative;
  cursor: pointer;
  transition: all 0.2s ease;
}
.video-thumbnail:hover { transform: scale(1.05); }
.cover-overlay {
  position: absolute; top: 0; left: 0; right: 0; bottom: 0;
  background: rgba(0,0,0,0.6);
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  opacity: 0; transition: opacity 0.2s ease; color: white; font-size: 10px; gap: 2px;
}
.video-thumbnail:hover .cover-overlay { opacity: 1; }
.thumbnail-image { width: 100%; height: 100%; object-fit: cover; }
.thumbnail-placeholder { color: var(--text-color-secondary); display: flex; align-items: center; justify-content: center; }
.success-icon { width: 16px; height: 16px; background: #2abc3b; border-radius: 50%; display: inline-flex; align-items: center; justify-content: center; color: white; margin-right: 6px; vertical-align: middle; }
.video-info { flex: 1; min-width: 0; color: var(--text-color-primary); }
.success-text { font-size: 13px; margin: 0; color: var(--success-color); font-weight: 500; display: flex; align-items: center; }
.video-name { font-size: 12px; color: var(--text-color-secondary); margin-top: 4px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; max-width: 250px; }
.remove-btn { width: 28px; height: 28px; border: none; background: rgba(255,255,255,0.15); color: var(--text-color-secondary); border-radius: 50%; cursor: pointer; display: flex; align-items: center; justify-content: center; transition: all 0.2s ease; flex-shrink: 0; }
.remove-btn:hover { background: var(--danger-color); color: white; }
.upload-placeholder { display: flex; flex-direction: column; align-items: center; justify-content: center; text-align: center; color: var(--text-color-secondary); }
.upload-placeholder .upload-icon { width: 40px; height: 40px; }
.upload-placeholder p { margin: 4px 0; font-size: 14px; }
.upload-hint { font-size: 12px; color: var(--text-color-tertiary); }
.drag-hint { font-size: 12px; color: var(--text-color-quaternary); margin-top: 8px; }
.upload-progress { position: absolute; bottom: 20px; left: 20px; right: 20px; text-align: center; }
.progress-bar { width: 100%; height: 4px; background: var(--bg-color-tertiary); border-radius: 2px; overflow: hidden; margin-bottom: 8px; }
.progress-fill { height: 100%; background: var(--primary-color); transition: width 0.2s ease; }
.progress-text { font-size: 12px; color: var(--text-color-secondary); margin: 0; }

/* ===== 多集合集 ===== */
.series-tip {
  display: flex; align-items: center; gap: 6px;
  padding: 8px 12px; margin-bottom: 12px;
  background: rgba(102,126,234,0.1); border-radius: 6px;
  font-size: 12px; color: var(--primary-color);
}

.episodes-list { display: flex; flex-direction: column; gap: 10px; }
.episode-item {
  display: flex; align-items: center; gap: 10px;
  padding: 12px; background: var(--bg-color-secondary);
  border-radius: 8px; border: 1px solid var(--border-color-primary);
}
.episode-sort { flex-shrink: 0; }
.episode-num {
  display: inline-flex; align-items: center; justify-content: center;
  width: 32px; height: 32px; border-radius: 50%;
  background: var(--primary-color); color: white;
  font-size: 13px; font-weight: 600;
}
.episode-inputs { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 6px; }
.episode-title, .episode-url {
  width: 100%; padding: 8px 10px;
  border: 1px solid var(--border-color-primary); border-radius: 6px;
  background: var(--bg-color-primary); color: var(--text-color-primary);
  font-size: 13px; transition: border-color 0.2s ease; box-sizing: border-box;
}
.episode-title:focus, .episode-url:focus { outline: none; border-color: var(--primary-color); }
.episode-title::placeholder, .episode-url::placeholder { color: var(--text-color-tertiary); }
.episode-actions { display: flex; flex-direction: column; gap: 4px; flex-shrink: 0; }
.ep-btn {
  width: 28px; height: 28px; border: none; border-radius: 50%;
  background: var(--bg-color-primary); color: var(--text-color-secondary);
  cursor: pointer; display: flex; align-items: center; justify-content: center;
  transition: all 0.2s ease;
}
.ep-btn:hover { background: var(--primary-color); color: white; }
.ep-del:hover { background: var(--danger-color); color: white; }

.add-episode-btn {
  display: flex; align-items: center; justify-content: center; gap: 6px;
  width: 100%; padding: 14px; margin-top: 10px;
  border: 2px dashed var(--border-color-primary); border-radius: 8px;
  background: transparent; color: var(--primary-color);
  font-size: 14px; font-weight: 500; cursor: pointer;
  transition: all 0.2s ease;
}
.add-episode-btn:hover { border-color: var(--primary-color); background: rgba(102,126,234,0.08); }

.empty-tip { text-align: center; padding: 20px; color: var(--text-color-tertiary); font-size: 13px; }

/* ===== 通用 ===== */
.error-message { color: var(--danger-color); font-size: 12px; margin-top: 8px; }
.upload-tips { font-size: 12px; color: var(--text-color-secondary); line-height: 1.4; margin-top: 8px; }
.upload-tips p { margin: 2px 0; }

@media (max-width: 768px) {
  .upload-area { min-height: 150px; }
  .upload-area.has-video { min-height: 100px; }
  .video-name { max-width: 150px; }
  .series-tab, .mode-tab { padding: 8px 12px; font-size: 12px; }
  .episode-item { flex-wrap: wrap; }
  .episode-inputs { order: 3; flex-basis: 100%; }
}
</style>
