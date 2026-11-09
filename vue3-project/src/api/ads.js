import request from './request.js'

// 获取前台展示的广告位
export async function getAds(params = {}) {
  try {
    const response = await request.get('/ads', { params })
    return response
  } catch (error) {
    console.error('获取广告位失败:', error)
    return {
      success: false,
      data: [],
      message: error.message || '获取广告位失败'
    }
  }
}
